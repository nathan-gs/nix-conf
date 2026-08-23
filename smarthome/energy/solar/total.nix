{ config, pkgs, lib, ha, ... }:
let
  # Reconstructs a high-precision, never-resetting lifetime total by adding
  # a Modbus daily counter (1 decimal, resets at local midnight) onto a
  # `till_yesterday` baseline - rather than reading the inverter's own
  # lifetime register directly, which is whole-units-only and once had a
  # same-day continuity gap when the solis_modbus entity was recreated
  # during the cloud retirement.
  #
  # Pattern carried over from the retired solis_local.nix .cgi scrape
  # (solar_delivery_total / _till_yesterday): a helper holds the running
  # total as of yesterday, and the running total itself is
  # till_yesterday + today.
  #
  # till_yesterday is a trigger-based template sensor that accumulates on its
  # own previous state each time the daily counter resets - triggering off
  # the counter's own transition to "0" (not a "00:00:00" clock trigger)
  # means `today` is already 0 at trigger time, so there's no gap for the
  # reconstructed total to dip through and no dependency on the reset
  # happening at exactly midnight (observed ~23:59:28 in practice, not
  # 00:00:00 - a fixed clock trigger raced this by up to ~2 minutes and
  # produced a real, if small, negative-looking dip; confirmed 2026-08-22 in
  # the recorder's compiled hourly statistics).
  #
  # This used to be an input_number, recomputed from `lifetimeSource` (the
  # inverter's own lifetime register) rather than self-accumulating, because
  # input_number's restore across HA restarts once proved unreliable
  # (2026-08-21: came back pinned at its `initial` of 0 after a crash-loop
  # restart) and trigger-based template sensors were believed not to restore
  # their state at all. Neither belief holds up: HA's template integration
  # (`TriggerSensorEntity` / `AbstractTemplateSensor`, checked against the
  # 2026.8.2 source) extends `RestoreSensor` and restores its last value on
  # startup same as any other sensor - so the input_number/automation
  # indirection wasn't needed. Worse, recomputing from `lifetimeSource` on
  # every reset silently truncated up to ~1 kWh of precision each night
  # (the register is whole-units-only, and only rolls over once a full kWh
  # has accumulated - it routinely lags the true fractional total at exactly
  # the moment `today` resets to 0), and on the one night the reset
  # automation didn't fire at all (mode: single, silently no-opped), only
  # a 2-minute-delayed HA-restart fallback caught it hours later, publishing
  # a real -0.6 kWh dip in the Energy dashboard's compiled statistics
  # (2026-08-23). Self-accumulating from the daily counter's own precise
  # value at reset time (`trigger.from_state.state`, 1-decimal resolution)
  # avoids the truncation entirely, and dropping the automation/input_number
  # pair in favor of one self-contained trigger sensor removes the
  # mode:single failure mode along with it.
  mkReconstructedTotal = { name, dailySource, lifetimeSource, icon }:
    let
      tillYesterdayName = "${name}_till_yesterday";
      entityId = "sensor.${ha.genId name}";
      tillYesterdayEntityId = "sensor.${ha.genId tillYesterdayName}";
    in {
      inherit entityId;
      tillYesterdayTemplate = {
        trigger = ha.trigger.state_to dailySource "0";
        sensor = [
          {
            name = tillYesterdayName;
            unique_id = ha.genId tillYesterdayName;
            icon = icon;
            state = ''
              {% set previous = states('${tillYesterdayEntityId}') | float(0) %}
              {% set from_state = trigger.from_state.state if trigger.from_state else 'unknown' %}
              {% set yesterday = from_state | float(0) if from_state not in ['unknown', 'unavailable', 'none'] else 0 %}
              {{ previous + yesterday }}
            '';
            unit_of_measurement = "kWh";
            device_class = "energy";
            state_class = "total_increasing";
          }
        ];
      };
      sensorEntry = {
        inherit name icon;
        unique_id = ha.genId name;
        state = ''
          {% set till_yesterday = states('${tillYesterdayEntityId}') | float(0) %}
          {% set today = states('${dailySource}') | float(0) %}
          {{ till_yesterday + today }}
        '';
        # `till_yesterday` starts unknown on a fresh entity (e.g. right after
        # this config is deployed) and only gets seeded at the next local
        # midnight reset - cross-check against `lifetimeSource` (always a
        # live Modbus read, no restore step to fail) so a not-yet-seeded or
        # otherwise wrong total goes unavailable instead of publishing a
        # too-low number for a `total_increasing` sensor to "fix" later by
        # inventing a huge fake jump.
        availability = ''
          {% set lifetime = states('${lifetimeSource}') %}
          {% if lifetime in ['unknown', 'unavailable', 'none'] %}
            false
          {% else %}
            {% set till_yesterday = states('${tillYesterdayEntityId}') | float(0) %}
            {% set today = states('${dailySource}') | float(0) %}
            {{ ((till_yesterday + today) - (lifetime | float(0))) | abs < 5 }}
          {% endif %}
        '';
        unit_of_measurement = "kWh";
        device_class = "energy";
        state_class = "total_increasing";
      };
    };

  # `solar/total_energy_generation` is the sum across inverters (today just
  # the one house plant) - this is the entity the Energy dashboard should
  # point at. Add a second `solar/<name>/...` pair here and extend the
  # matching sum when a second inverter shows up.
  #
  # Battery charge/discharge totals do NOT use this reconstruction: the
  # Solis registers they'd anchor to (system_house_pv_total_battery_charge/
  # discharge_energy) are the inverter's own BMS accounting, and on
  # 2026-08-22 that accounting showed lifetime discharge (6844 kWh) exceeding
  # lifetime charge (4700 kWh) - impossible for a battery, so the registers
  # themselves drift/misreport over time. This is the same failure mode
  # that motivated the old %-SoC-delta trick (removed 2026-08-20, commit
  # 39d0772) before that. Battery totals are integrated directly from
  # `electricity_battery_power` instead - see batteryCharge/batteryDischarge
  # below.
  solarGeneration = mkReconstructedTotal {
    name = "solar/house/total_energy_generation";
    dailySource = "sensor.system_house_pv_pv_today_energy_generation";
    lifetimeSource = "sensor.system_house_pv_pv_total_energy_generation";
    icon = "mdi:solar-panel";
  };

  perInverter = [ solarGeneration ];

  # `electricity_battery_power` (smarthome/energy/legacy.nix) is signed:
  # negative while charging, positive while discharging. Split it into two
  # always-nonnegative power sensors and Riemann-integrate each separately
  # (HA core `integration` platform) rather than trusting either the Solis
  # BMS lifetime registers (see above) or a fixed Wh/% SoC-delta estimate.
  # The Modbus poll is now 10s (was 5min), so the integral tracks real power
  # swings closely - "trapezoidal" is accurate at that resolution. The
  # `integration` sensor restores its accumulated state across HA restarts
  # natively (RestoreEntity), unlike a bare trigger-based template sensor.
  mkBatteryPowerSplit = { name, icon, isCharge }:
    let
      sign = if isCharge then "-1" else "1";
    in {
      name = "${name}_power";
      unique_id = ha.genId "${name}_power";
      icon = icon;
      state = ''
        {% set battery_power = states('sensor.electricity_battery_power') | float(0) %}
        {% set power = ${sign} * battery_power %}
        {{ [power, 0] | max }}
      '';
      device_class = "power";
      unit_of_measurement = "W";
      state_class = "measurement";
    };

  batteryChargingPower = mkBatteryPowerSplit {
    name = "battery/house/charging";
    icon = "mdi:battery-plus";
    isCharge = true;
  };
  batteryDischargingPower = mkBatteryPowerSplit {
    name = "battery/house/discharging";
    icon = "mdi:battery-minus";
    isCharge = false;
  };

  mkBatteryEnergyIntegral = { name, icon, source }: {
    platform = "integration";
    name = name;
    unique_id = ha.genId name;
    source = "sensor.${ha.genId source}";
    method = "trapezoidal";
    unit_time = "h";
    unit_prefix = "k";
  };

  batteryHouseChargeTotal = mkBatteryEnergyIntegral {
    name = "battery/house/charge_total_energy";
    icon = "mdi:battery-plus";
    source = batteryChargingPower.name;
  };
  batteryHouseDischargeTotal = mkBatteryEnergyIntegral {
    name = "battery/house/discharge_total_energy";
    icon = "mdi:battery-minus";
    source = batteryDischargingPower.name;
  };

  # Mirrors must propagate the source's availability too, not just its state -
  # `states(x) | float(0)` silently turns "unavailable" into 0, which would
  # reintroduce the exact false-reset problem the availability guard above
  # exists to prevent, just one hop downstream.
  mkAggregate = { name, icon, source }: {
    inherit name icon;
    unique_id = ha.genId name;
    state = "{{ states('${source}') | float(0) }}";
    availability = "{{ states('${source}') not in ['unknown', 'unavailable', 'none'] }}";
    unit_of_measurement = "kWh";
    device_class = "energy";
    state_class = "total_increasing";
  };

  aggregates = [
    (mkAggregate {
      name = "solar/total_energy_generation";
      icon = "mdi:solar-panel";
      source = solarGeneration.entityId;
    })
    (mkAggregate {
      name = "battery/charge_total_energy";
      icon = "mdi:battery-plus";
      source = "sensor.${ha.genId batteryHouseChargeTotal.name}";
    })
    (mkAggregate {
      name = "battery/discharge_total_energy";
      icon = "mdi:battery-minus";
      source = "sensor.${ha.genId batteryHouseDischargeTotal.name}";
    })
  ];

  # hourly/daily/monthly utility_meter helpers per source, following the
  # <base>_<cycle> naming used for gas/electricity in energy/legacy.nix.
  mkUtilityMeters = { base, source }:
    builtins.listToAttrs (map (cycle: {
      name = "${base}_${cycle}";
      value = { inherit source cycle; };
    }) [ "hourly" "daily" "monthly" ]);

  batteryUtilityMeters =
    (mkUtilityMeters {
      base = ha.genId batteryHouseChargeTotal.name;
      source = "sensor.${ha.genId batteryHouseChargeTotal.name}";
    })
    // (mkUtilityMeters {
      base = ha.genId batteryHouseDischargeTotal.name;
      source = "sensor.${ha.genId batteryHouseDischargeTotal.name}";
    });
in
{
  services.home-assistant.config = {
    template = [
      {
        sensor = (map (x: x.sensorEntry) perInverter)
          ++ [ batteryChargingPower batteryDischargingPower ]
          ++ aggregates;
      }
    ] ++ (map (x: x.tillYesterdayTemplate) perInverter);

    sensor = [ batteryHouseChargeTotal batteryHouseDischargeTotal ];

    utility_meter = batteryUtilityMeters;
  };
}

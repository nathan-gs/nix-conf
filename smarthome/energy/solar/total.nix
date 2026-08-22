{ config, pkgs, lib, ha, ... }:
let
  # Reconstructs a high-precision, never-resetting lifetime total by adding
  # a Modbus daily counter (1 decimal, resets at local midnight) onto a
  # `till_yesterday` baseline - rather than reading the inverter's own
  # lifetime register directly, which is whole-units-only and once had a
  # same-day continuity gap when the solis_modbus entity was recreated
  # during the cloud retirement. The lifetime register is still used, just
  # only as a periodic anchor for `till_yesterday` (see below) rather than
  # as the live-updating total itself.
  #
  # Pattern carried over from the retired solis_local.nix .cgi scrape
  # (solar_delivery_total / _till_yesterday): a helper holds the running
  # total as of yesterday, and the running total itself is
  # till_yesterday + today. The .cgi sensor briefly re-reported the previous
  # day's total for hours after midnight, so this used to freeze 23:00-03:00
  # as a precaution - but the Modbus daily counter resets cleanly to 0 at
  # local midnight (verified across multiple nights, no stale re-reporting),
  # and the freeze itself was the bug: it held the total flat all night and
  # then jumped by the whole overnight discharge/charge in one step at 03:00,
  # which read as "sensor stopped updating, then caught up".
  #
  # till_yesterday is an input_number, not a trigger-based template sensor -
  # trigger-based template sensors don't restore their state across HA
  # restarts (there's no "restore" option in this HA version's template
  # schema; setting one makes the whole template block fail validation).
  #
  # input_number's own restore is not reliable enough to trust on its own -
  # after a crash-loop restart (2026-08-21, electrolux_status integration)
  # it came back pinned at its `initial` of 0 instead of its last value, and
  # sat there for 45+ minutes (previously it self-healed within ~30 min of a
  # restart; this time it didn't), dragging the whole reconstructed total
  # down to just that day's fraction. So till_yesterday is never trusted
  # in-place: `lifetimeSource` is the inverter's own lifetime register
  # (whole kWh, always live off Modbus - no restore involved at all) and
  # till_yesterday is *recomputed* from it (lifetime minus today's already-
  # counted fraction) both when the daily counter itself resets and on every
  # HA start, so a bad restore self-heals within seconds of startup instead
  # of waiting up to a day for the next reset. lifetimeSource is only ever
  # read at those two moments - `today`'s finer 1-decimal resolution is
  # still what drives the total through the rest of the day.
  #
  # The recompute used to be a "00:00:00" clock trigger with a flat 2-minute
  # delay before applying (to give Modbus time to reconnect on the HA-start
  # path). That delay applied to the midnight path too, and the daily
  # counter doesn't reset at exactly local midnight (observed ~23:59:28, not
  # 00:00:00) - so for up to ~2 minutes each night `today` had already reset
  # to 0 while `till_yesterday` was still yesterday's value, and the
  # reconstructed total (till_yesterday + today) dipped below what it had
  # shown a moment earlier. The `availability` guard below only catches a
  # dip larger than 5 units, so small dips (a night with well under 5 kWh of
  # battery charge, say) sailed through as a real-looking negative reading -
  # confirmed 2026-08-22 in the recorder's compiled hourly statistics (a
  # 1.8 kWh drop in `sum` for battery/house/charge_total_energy in the hour
  # spanning midnight), which the Energy dashboard rendered as a negative
  # bar. Triggering off the daily counter's own transition to "0" instead of
  # a clock removes the race outright: `today` is already 0 at trigger time,
  # so `till_yesterday` is set to `lifetimeSource` with no gap to fall
  # through, no delay needed, and no dependency on the reset happening at
  # exactly midnight. The delay is now only applied on the HA-start path,
  # where it's still needed for Modbus to come back up.
  mkReconstructedTotal = { name, dailySource, lifetimeSource, icon }:
    let
      tillYesterdayName = "${name}_till_yesterday";
      entityId = "sensor.${ha.genId name}";
      tillYesterdayObjectId = ha.genId tillYesterdayName;
      tillYesterdayEntityId = "input_number.${tillYesterdayObjectId}";
      tillYesterdayFromLifetime = ''
        {{ (states('${lifetimeSource}') | float(0)) - (states('${dailySource}') | float(0)) }}
      '';
    in {
      inherit entityId tillYesterdayObjectId;
      tillYesterdayHelper = {
        name = tillYesterdayName;
        min = 0;
        max = 1000000;
        step = 0.1;
        mode = "box";
        unit_of_measurement = "kWh";
        icon = icon;
        initial = 0;
      };
      snapshotAutomation = ha.automation "${name}.snapshot_till_yesterday" {
        triggers = [
          ((ha.trigger.state_to dailySource "0") // { id = "reset"; })
          { platform = "homeassistant"; event = "start"; id = "ha_start"; }
        ];
        actions = [
          # Modbus/solis_modbus setup can take well over a minute after HA
          # starts (seen taking 60s+ in practice) - give it time to connect
          # before trusting its readings. Not needed on the reset trigger:
          # Modbus is already live there, and today has already read 0 by
          # the time this fires, so delaying would only reopen the gap this
          # trigger exists to close.
          (ha.action.conditional
            [ (ha.condition.template "{{ trigger.id == 'ha_start' }}") ]
            [ (ha.action.delay "00:02:00") ]
            [ ]
          )
          (ha.action.conditional
            [ (ha.condition.template ''
                {{ states('${lifetimeSource}') not in ['unknown', 'unavailable', 'none']
                   and states('${dailySource}') not in ['unknown', 'unavailable', 'none'] }}
              '')
            ]
            [ (ha.action.set_value tillYesterdayEntityId tillYesterdayFromLifetime) ]
            [ ]
          )
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
        # A bad till_yesterday restore isn't just "unavailable" - it comes
        # back as a plausible-looking number (its `initial` of 0), so a
        # not-unknown/unavailable check on the inputs alone doesn't catch it
        # (2026-08-21: this happened twice, each time producing a huge false
        # total_increasing "reset" followed by an equally huge false
        # "recovery" once corrected - which the Energy dashboard statistics
        # read as genuine energy and had to be corrected by hand). Cross-check
        # instead against `lifetimeSource`, which has no restore step to fail
        # (always a live Modbus read) and tracks the true total to within
        # ~1 kWh at all times - if the reconstructed total disagrees with it
        # by more than a real day's worth of activity ever could, something
        # upstream is wrong and this entity should go unavailable rather than
        # publish a number and let a `total_increasing` sensor "fix" it later.
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
    input_number = builtins.listToAttrs (map (x: {
      name = x.tillYesterdayObjectId;
      value = x.tillYesterdayHelper;
    }) perInverter);

    automation = map (x: x.snapshotAutomation) perInverter;

    template = [
      {
        sensor = (map (x: x.sensorEntry) perInverter)
          ++ [ batteryChargingPower batteryDischargingPower ]
          ++ aggregates;
      }
    ];

    sensor = [ batteryHouseChargeTotal batteryHouseDischargeTotal ];

    utility_meter = batteryUtilityMeters;
  };
}

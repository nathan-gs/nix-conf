{ config, pkgs, lib, ha, ... }:
let
  # Solar production feeds the Energy dashboard directly from
  # `sensor.system_house_pv_pv_today_energy_generation` (the Solis daily
  # counter) - it's already `device_class: energy` /
  # `state_class: total_increasing`, which is exactly what HA's own
  # long-term-statistics compiler needs to reconstruct a never-resetting
  # lifetime total from a daily-reset counter: on each reset it detects the
  # decrease and adds the new (low) reading instead of the delta, which is
  # the same accumulation this file used to hand-roll via a `till_yesterday`
  # helper sensor and a from-scratch reconstruction.
  #
  # That reconstruction (till_yesterday + a derived house-total + a
  # multi-inverter sum, still just one inverter today) was removed
  # 2026-08-23 after it corrupted an hour of statistics: its availability
  # guard raced during an HA restart and briefly published `today` alone as
  # if it were the lifetime total (fixed in commit 26d9b98), and separately
  # `till_yesterday` itself failed to restore across a later restart and sat
  # `unknown` for over an hour. Both failure modes were specific to the
  # custom reconstruction layer - the underlying daily counter never
  # glitched through any of it. HA's native reset-detection isn't perfectly
  # clean either (a handful of sub-kWh dips found in its multi-year history,
  # right at the daily reset boundary), but it doesn't depend on any
  # restart-sensitive template/restore machinery, and it's what every other
  # `total_increasing` sensor in this config already relies on.
  #
  # The tradeoff: there's no live entity exposing "current lifetime solar
  # kWh" for dashboards/automations/multi-inverter summing - only the
  # compiled statistics (queryable via the recorder, same as any other
  # sensor's long-term stats). Nothing in this config currently needs that
  # as a live value; if a second inverter or such a consumer shows up,
  # revisit combining multiple inverters' statistics rather than reviving
  # per-entity reconstruction.
  #
  # The Energy dashboard's solar source is UI-configured (Settings ->
  # Dashboards -> Energy), not something this file can set declaratively.

  # `electricity_battery_power` (smarthome/energy/legacy.nix) is signed:
  # negative while charging, positive while discharging. Split it into two
  # always-nonnegative power sensors and Riemann-integrate each separately
  # (HA core `integration` platform) rather than trusting either the Solis
  # BMS lifetime registers or a fixed Wh/% SoC-delta estimate: on
  # 2026-08-22 the Solis BMS registers
  # (system_house_pv_total_battery_charge/discharge_energy) showed lifetime
  # discharge (6844 kWh) exceeding lifetime charge (4700 kWh) - impossible
  # for a battery, so those registers drift/misreport over time. Same
  # failure mode that motivated the old %-SoC-delta trick (removed
  # 2026-08-20, commit 39d0772) before that. The Modbus poll is now 10s
  # (was 5min), so the integral tracks real power swings closely -
  # "trapezoidal" is accurate at that resolution. The `integration` sensor
  # restores its accumulated state across HA restarts natively
  # (RestoreEntity), unlike a bare trigger-based template sensor.
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
  # publish a false reset one hop downstream.
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
        sensor = [ batteryChargingPower batteryDischargingPower ] ++ aggregates;
      }
    ];

    sensor = [ batteryHouseChargeTotal batteryHouseDischargeTotal ];

    utility_meter = batteryUtilityMeters;
  };
}

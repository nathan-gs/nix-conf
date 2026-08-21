{ config, pkgs, lib, ha, ... }:
let
  # Reconstructs a high-precision, never-resetting lifetime total from a
  # Modbus daily counter (1 decimal, resets at local midnight) instead of the
  # inverter's own lifetime register (whole units only, and it got a
  # same-day continuity gap when the solis_modbus entity was recreated during
  # the cloud retirement).
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
  # input_number restores natively, same as every other input_number in
  # this repo, so an automation just snapshots into it at midnight.
  mkReconstructedTotal = { name, dailySource, icon }:
    let
      tillYesterdayName = "${name}_till_yesterday";
      entityId = "sensor.${ha.genId name}";
      tillYesterdayObjectId = ha.genId tillYesterdayName;
      tillYesterdayEntityId = "input_number.${tillYesterdayObjectId}";
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
        triggers = [ (ha.trigger.at "00:00:00") ];
        actions = [
          (ha.action.set_value tillYesterdayEntityId
            "{{ states('${entityId}') | float(0) }}")
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
        unit_of_measurement = "kWh";
        device_class = "energy";
        state_class = "total_increasing";
      };
    };

  # `solar/total_energy_generation`, `battery/charge_total_energy` and
  # `battery/discharge_total_energy` are the sums across inverters/battery
  # banks (today just the one house plant) - these are the entities the
  # Energy dashboard should point at. Add a second `solar/<name>/...` /
  # `battery/<name>/...` pair here and extend the matching sum when a
  # second inverter shows up.
  solarGeneration = mkReconstructedTotal {
    name = "solar/house/total_energy_generation";
    dailySource = "sensor.system_house_pv_pv_today_energy_generation";
    icon = "mdi:solar-panel";
  };
  batteryCharge = mkReconstructedTotal {
    name = "battery/house/charge_total_energy";
    dailySource = "sensor.system_house_pv_today_battery_charge_energy";
    icon = "mdi:battery-plus";
  };
  batteryDischarge = mkReconstructedTotal {
    name = "battery/house/discharge_total_energy";
    dailySource = "sensor.system_house_pv_today_battery_discharge_energy";
    icon = "mdi:battery-minus";
  };

  perInverter = [ solarGeneration batteryCharge batteryDischarge ];

  aggregates = [
    {
      name = "solar/total_energy_generation";
      icon = "mdi:solar-panel";
      unique_id = ha.genId "solar/total_energy_generation";
      state = "{{ states('${solarGeneration.entityId}') | float(0) }}";
      unit_of_measurement = "kWh";
      device_class = "energy";
      state_class = "total_increasing";
    }
    {
      name = "battery/charge_total_energy";
      icon = "mdi:battery-plus";
      unique_id = ha.genId "battery/charge_total_energy";
      state = "{{ states('${batteryCharge.entityId}') | float(0) }}";
      unit_of_measurement = "kWh";
      device_class = "energy";
      state_class = "total_increasing";
    }
    {
      name = "battery/discharge_total_energy";
      icon = "mdi:battery-minus";
      unique_id = ha.genId "battery/discharge_total_energy";
      state = "{{ states('${batteryDischarge.entityId}') | float(0) }}";
      unit_of_measurement = "kWh";
      device_class = "energy";
      state_class = "total_increasing";
    }
  ];
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
        sensor = (map (x: x.sensorEntry) perInverter) ++ aggregates;
      }
    ];
  };
}

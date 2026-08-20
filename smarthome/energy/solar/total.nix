{ config, pkgs, lib, ha, ... }:
let
  # Reconstructs a high-precision, never-resetting lifetime total from a
  # Modbus daily counter (1 decimal, resets at local midnight) instead of the
  # inverter's own lifetime register (whole units only, and it got a
  # same-day continuity gap when the solis_modbus entity was recreated during
  # the cloud retirement).
  #
  # Pattern carried over from the retired solis_local.nix .cgi scrape
  # (solar_delivery_total / _till_yesterday): a trigger sensor snapshots the
  # running total at midnight, and the running total itself is
  # till_yesterday + today. Frozen 23:00-03:00 because the original .cgi
  # sensor briefly re-reported the previous day's total for hours after
  # midnight; kept as a precaution even though the Modbus registers haven't
  # shown the same quirk yet.
  mkReconstructedTotal = { name, dailySource, icon }:
    let
      tillYesterdayName = "${name}_till_yesterday";
      entityId = "sensor.${ha.genId name}";
      tillYesterdayEntityId = "sensor.${ha.genId tillYesterdayName}";
    in {
      inherit entityId;
      triggerBlock = {
        trigger = ha.trigger.at "00:00:00";
        sensor = [
          {
            name = tillYesterdayName;
            unique_id = ha.genId tillYesterdayName;
            state = "{{ states('${entityId}') | float(0) }}";
            unit_of_measurement = "kWh";
            device_class = "energy";
            icon = icon;
            state_class = "total";
            # Trigger-based template sensors don't restore across HA
            # restarts by default - without this the running total drops
            # back to just "today" on every restart until the next midnight
            # trigger fires.
            restore = true;
          }
        ];
      };
      sensorEntry = {
        inherit name icon;
        unique_id = ha.genId name;
        state = ''
          {% set hour = now().hour %}
          {% set till_yesterday = states('${tillYesterdayEntityId}') | float(0) %}
          {% set today = states('${dailySource}') | float(0) %}
          {% set previous = states('${entityId}') | float(0) %}
          {% if hour < 3 or hour >= 23 %}
            {{ previous }}
          {% else %}
            {{ till_yesterday + today }}
          {% endif %}
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
    template = (map (x: x.triggerBlock) perInverter) ++ [
      {
        sensor = (map (x: x.sensorEntry) perInverter) ++ aggregates;
      }
    ];
  };
}

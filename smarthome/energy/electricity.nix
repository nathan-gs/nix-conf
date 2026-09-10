{ config, pkgs, lib, ha, ... }:

let 

  statistics = name: function: minutes: {
    unique_id = (ha.genId "${name}/${(builtins.replaceStrings [ "value_" ] [ "" ] function)}_${toString minutes}m");
    platform = "statistics";
    name = "${name}/${(builtins.replaceStrings [ "value_" ] [ "" ] function)}_${toString minutes}m";
    entity_id = "sensor.${(ha.genId name)}";
    state_characteristic = function;
    max_age.minutes = minutes;
    sampling_size = minutes * 60;
    keep_last_sample = true;
  };

in
{

  services.home-assistant.config = {

    template = [
      {
        sensor = [
          {
            # House load with the car charger subtracted out — the baseload the home battery
            # actually has to carry on its own. Used by the car charger's morning battery boost
            # to size how much charge must be held back to bridge to sunrise (see
            # smarthome/car/car_charger/tuya.nix); the raw household_load_power is useless there
            # because it includes the very car draw the boost creates.
            name = "electricity/house/baseload/power";
            unique_id = "electricity_house_baseload_power";
            state = ''
              {% set house = states('sensor.system_house_pv_household_load_power') | float(0) %}
              {% set car = states('sensor.car_charger_power') | float(0) %}
              {{ [0, house - car] | max | round(0) }}
            '';
            unit_of_measurement = "W";
            device_class = "power";
            state_class = "measurement";
          }
        ];
      }
    ];

    sensor = [
      # 60-min mean: the boost runs pre-dawn, so this samples a quiet house and is a floor on
      # the real daytime load, not an average of it. The consumer applies its own uplift.
      (statistics "electricity/house/baseload/power" "mean" 60)
      (statistics "electricity/grid/consumed/power" "mean" 1)
      (statistics "electricity/grid/consumed/power" "value_max" 1)
      (statistics "electricity/grid/consumed/power" "value_min" 1)
      (statistics "electricity/grid/returned/power" "value_min" 1)
      (statistics "electricity/grid/consumed/power" "mean" 15)
      (statistics "electricity/solar/power" "mean" 15)
    ];


  };

}
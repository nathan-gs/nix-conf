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

    sensor = [
      (statistics "electricity/grid/consumed/power" "mean" 1)
      (statistics "electricity/grid/consumed/power" "value_max" 1)
      (statistics "electricity/grid/consumed/power" "value_min" 1)
      (statistics "electricity/grid/returned/power" "value_min" 1)
    ];


    recorder.include.entity_globs = [
      "sensor.electricity_grid_consumed_power_*"
      "sensor.electricity_grid_returned_power_*"
    ];

  };

}
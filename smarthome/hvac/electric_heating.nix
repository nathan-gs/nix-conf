{ config, pkgs, lib, ... }:

{

  services.home-assistant.config = {

    template = [
      {
        binary_sensor = [
          {
            name = "system_wtw_metering_plug_verwarming_target";
            state = ''
              {% set sensor = states('sensor.system_wtw_metering_plug_verwarming_power') | float(0) %}
              {% set house_return = states('sensor.electricity_grid_returned_power') | float(0) %}
              {% set indoor_temp = states('sensor.indoor_temperature') | float(21) %}
              {% set not_overheating = (states('sensor.system_wtw_air_quality_to_house_temperature') | int(50) < 41) %}
              {% set power_available = (house_return - sensor) %}
              {% if power_available > 530 and indoor_temp < 24 and not_overheating %}
                true  
              {% else %}
                false
              {% endif %}
            '';
            device_class = "plug";
            delay_on.minutes = 1;
            delay_off.minutes = 1;
          }
        ];
      }
    ];

    "automation manual" = [
      {
        id = "system_wtw_metering_plug_verwarming_turn_on";
        alias = "system_wtw_metering_plug_verwarming.turn_on";
        trigger = [
          {
            platform = "state";
            entity_id = "binary_sensor.system_wtw_metering_plug_verwarming_target";
            to = "on";
          }
        ];
        action = [
          {
            service = "switch.turn_on";
            target.entity_id = "switch.system_wtw_metering_plug_verwarming";
          }
        ];
        mode = "single";
      }
      {
        id = "system_wtw_metering_plug_verwarming_turn_off";
        alias = "system_wtw_metering_plug_verwarming.turn_off";
        trigger = [
          {
            platform = "state";
            entity_id = "binary_sensor.system_wtw_metering_plug_verwarming_target";
            to = "off";
          }
        ];
        action = [
          {
            service = "switch.turn_off";
            target.entity_id = "switch.system_wtw_metering_plug_verwarming";
          }
        ];
        mode = "single";
      }
    ];
  };
}

{ config, pkgs, lib, ... }:

let

  automateTurnOn = v:
    {
      id = "${v}_turn_on";
      alias = "${v}.turn_on";
      trigger = [
        {
          platform = "state";
          entity_id = "binary_sensor.${v}_target";
          to = "on";
        }
      ];
      action = [
        {
          service = "switch.turn_on";
          target.entity_id = "switch.${v}";
        }
      ];
      mode = "single";
    };

  automateTurnOff = v:
    {
      id = "${v}_turn_off";
      alias = "${v}.turn_off";
      trigger = [
        {
          platform = "state";
          entity_id = "binary_sensor.${v}_target";
          to = "off";
        }
      ];
      action = [
        {
          service = "switch.turn_off";
          target.entity_id = "switch.${v}";
        }
      ];
      mode = "single";
    };

in
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
              {% set power_available = (house_return + sensor) %}
              {% if power_available > 530 and indoor_temp < 24 and not_overheating %}
                true  
              {% else %}
                false
              {% endif %}
            '';
            device_class = "heat";
            delay_on.minutes = 5;
            delay_off.minutes = 1;
          }
          {
            name = "floor0_living_metering_plug_verwarming_target";
            state = ''
              {% set sensor = states('sensor.floor0_living_metering_plug_verwarming_power') | float(0) %}
              {% set house_return = states('sensor.electricity_grid_returned_power') | float(0) %}
              {% set indoor_temp = states('sensor.floor0_living_temperature_na_temperature') | float(21) %}
              {% set power_available = (house_return + sensor) %}
              {% if power_available > 750 and indoor_temp < 21 %}
                true  
              {% else %}
                false
              {% endif %}
            '';
            device_class = "heat";
            delay_on.minutes = 1;
            delay_off.minutes = 2;
          }
          {
            name = "floor0_bureau_metering_plug_verwarming_target";
            state = ''
              {% set sensor = states('sensor.floor0_bureau_metering_plug_verwarming_power') | float(0) %}
              {% set house_return = states('sensor.electricity_grid_returned_power') | float(0) %}
              {% set indoor_temp = states('sensor.floor0_bureau_temperature_na_temperature') | float(21) %}
              {% set power_available = (house_return + sensor) %}
              {% if power_available > 650 and indoor_temp < 21 %}
                true  
              {% else %}
                false
              {% endif %}
            '';
            device_class = "heat";
            delay_on.minutes = 2;
            delay_off.minutes = 3;
          }
        ];
      }
    ];

    "automation manual" = []
      ++ map (v: automateTurnOn v) [ "system_wtw_metering_plug_verwarming" "floor0_living_metering_plug_verwarming" "floor0_bureau_metering_plug_verwarming" ]
      ++ map (v: automateTurnOff v) [ "system_wtw_metering_plug_verwarming" "floor0_living_metering_plug_verwarming" "floor0_bureau_metering_plug_verwarming" ];

  };
}

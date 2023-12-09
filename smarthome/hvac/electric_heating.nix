{ config, pkgs, lib, ha, ... }:

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
              {% if power_available > 550 and indoor_temp < 24 and not_overheating %}
                true  
              {% else %}
                false
              {% endif %}
            '';
            device_class = "heat";
            delay_on.seconds = 90;
            delay_off.seconds = 60;
          }
          {
            name = "floor0_living_metering_plug_verwarming_target";
            state = ''
              {% set sensor = states('floor0_living_metering_plug_verwarming_power') | float(0) %}
              {% set house_return = states('sensor.electricity_grid_returned_power') | float(0) %}
              {% set indoor_temp = states('sensor.floor0_living_temperature') | float(21) %}
              {% set power_available = (house_return + sensor) %}
              {% if power_available > 835 and indoor_temp < 21 %}
                true  
              {% else %}
                false
              {% endif %}
            '';
            device_class = "heat";
            delay_on = ''
              {% set in_use = states('input_boolean.floor0_living_in_use') | bool(false) %}
              {% if in_use %}
                00:00:30
              {% else %}
                00:02:00
              {% endif %}
            '';            
            delay_off.seconds = 60;
          }
          {
            name = "floor1_nikolai_metering_plug_verwarming_target";
            state = ''
              {% set sensor = states('sensor.floor1_nikolai_metering_plug_verwarming_power') | float(0) %}
              {% set house_return = states('sensor.electricity_grid_returned_power') | float(0) %}
              {% set indoor_temp = states('sensor.floor1_nikolai_temperature') | float(21) %}
              {% set power_available = (house_return + sensor) %}              
              {% if power_available > 760 and indoor_temp < 22 %}
                true  
              {% else %}
                false
              {% endif %}
            '';
            device_class = "heat";
            delay_on = ''
              {% set in_use = states('input_boolean.floor1_nikolai_in_use') | bool(false) %}
              {% if in_use %}
                00:00:45
              {% else %}
                00:02:00
              {% endif %}
            '';
            delay_off.seconds = 60;
          }
          {
            name = "floor0_bureau_metering_plug_verwarming_target";
            state = ''
              {% set sensor = states('sensor.floor0_bureau_metering_plug_verwarming_power') | float(0) %}
              {% set house_return = states('sensor.electricity_grid_returned_power') | float(0) %}
              {% set indoor_temp = states('sensor.floor0_bureau_temperature') | float(21) %}
              {% set power_available = (house_return + sensor) %}
              {% if power_available > 685 and indoor_temp < 21 %}
                true  
              {% else %}
                false
              {% endif %}
            '';
            device_class = "heat";
            delay_on = ''
              {% set in_use = states('input_boolean.floor0_bureau_in_use') | bool(false) %}
              {% if in_use %}
                00:01:00
              {% else %}
                00:02:30
              {% endif %}
            '';
            delay_off.seconds = 60;
          }
        ];
      }
    ];

    "automation manual" = []
      ++ map (v: automateTurnOn v) [ "system_wtw_metering_plug_verwarming" "floor0_living_metering_plug_verwarming" "floor0_bureau_metering_plug_verwarming" "floor1_nikolai_metering_plug_verwarming" ]
      ++ map (v: automateTurnOff v) [ "system_wtw_metering_plug_verwarming" "floor0_living_metering_plug_verwarming" "floor0_bureau_metering_plug_verwarming" "floor1_nikolai_metering_plug_verwarming" ];

  };
}

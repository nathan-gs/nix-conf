{config, pkgs, lib, ...}:

{

  services.home-assistant.config = {

    template = [
      {
        binary_sensor = [        
          {
            name = "system_wtw_metering_plug_verwarming_target";
            state = ''
              {% set sensor = states('sensor.system_wtw_metering_plug_verwarming_power') | float(0) %}
              {% set not_far_away = states('binary_sensor.far_away') | bool(false) == false %}
              {% set house_return = states('sensor.electricity_grid_returned_power') | float(0) %}
              {% set indoor_temp = states('sensor.indoor_temperature') | float(21) %}
              {% set not_overheating = (states('sensor.system_wtw_air_quality_to_house_temperature') | int(50) < 41) %}
              {% set power_available = (house_return - sensor) %}
              {% if power_available > 550 and indoor_temp < 24 and not_far_away and not_overheating %}
                true  
              {% else %}
                false
              {% endif %}
            '';
            device_class = "plug";
            delay_on.minutes = 5;
            delay_off.minutes = 5;
          }
        ];
      }
    ];
  };
}
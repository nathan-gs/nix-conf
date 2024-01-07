{ config, lib, pkgs, ha, ... }:

{

  services.home-assistant.config = {
    template = [
      {
        trigger = {
          platform = "time";
          at = "23:59:01";          
        };
        sensor = [
          {
            name = "degree_day_daily";
            state = ''
              {% set regularized_temp = 18.0 | float %}
              {% set average_outside_temp = states('sensor.outdoor_temperature_24h_avg') | float %}
              {% set dd = regularized_temp - average_outside_temp %}
              {% if dd > 0 %}
                {{ dd }}
              {% else %}
                0
              {% endif %}    
            '';
            unit_of_measurement = "DD";
          }
        ];
      }
      {
        trigger = {
          platform = "time";
          at = "23:59:59";          
        };
        sensor = [
          {
            name = "gas_m3_per_degree_day";
            state = ''
              {% set gas_usage = states('sensor.gas_delivery_daily') | float %}
              {% set dd = states('sensor.degree_day_daily') | float %}
              {% if dd > 0 %}
                {{ gas_usage / dd }}
              {% else %}
                0
              {% endif %}      
            '';
            unit_of_measurement = "m³/DD";
          }
        ];
      }
    ];
  };
}
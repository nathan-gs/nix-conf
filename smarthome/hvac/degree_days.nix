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
            state_class = "measurement";
          }
        ];
      }
      {
        trigger = {
          platform = "time";
          at = "23:59:30";          
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
            state_class = "measurement";
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
            name = "gas_m3_per_degree_day_occupancy_adjusted";
            state = ''
              {% set gas_m3_per_degree_day = states('sensor.gas_m3_per_degree_day') | float(0) %}
              {% set occupancy_rate = (1 + (states('sensor.occupancy_anyone_home_daily') | float(0)) / (1 + 24)) %}
              {{ gas_m3_per_degree_day * occupancy_rate }}
            '';
            unit_of_measurement = "(m³/DD)*O";
            state_class = "measurement";
          }
        ];
      }
    ];

    
  };
}
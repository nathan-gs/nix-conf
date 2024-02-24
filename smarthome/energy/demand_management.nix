{ config, pkgs, lib, ha, ... }:
{
    services.home-assistant.config = {

    template = [  
      {
        binary_sensor = [
          {
            name = "electricity/demand_management/run_now";
            state = ''
              {% set offpeak = states('binary_sensor.electricity_is_offpeak') | bool(false) %}
              {% set battery_sufficiently_charged = (states('sensor.solis_remaining_battery_capacity') | int(0)) > 60 %}
              {% set solar_sufficient_power = (states('sensor.electricity_solar_power') | int(0)) > 2000 %}
              {% set demand = 1 %}
              {% set solar_sufficient_remaining_energy = (states('sensor.energy_production_today_remaining') | float(0)) > demand %}
              {% if solar_sufficient_power and solar_sufficient_remaining_energy %}
                true
              {% elif offpeak %}
                true
              {% else %}
                false
              {% endif %}
            '';
          }
        ];
      }
    ];
  };


}
{ config, pkgs, lib, ... }:

{

  services.home-assistant.config = {


    powercalc = {
      sensors = [
        {
          name = "battery_charging";
          entity_id = "sensor.dummy";
          standby_power = 0;
          fixed.power = ''
            {% set battery_power = states('sensor.solis_battery_power') | float(0) %}
            {% if battery_power > 0 %}
              {{ battery_power}}
            {% else %}
              0
            {% endif %}
          '';
        }
        {
          name = "battery_discharging";
          entity_id = "sensor.dummy";
          standby_power = 0;
          fixed.power = ''
            {% set battery_power = states('sensor.solis_battery_power') | float(0) %}
            {% if battery_power < 0 %}
              {{ battery_power * -1 }}
            {% else %}
              0
            {% endif %}
          '';
        }
      ];
    };


  };
}

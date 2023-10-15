{config, pkgs, lib, ...}:
let 
  carName = config.secrets.nathan-car.name;
in
{

  services.home-assistant.config = {
    powercalc = {
      sensors = [
        {
          name = "car_charger";
          entity_id = "binary_sensor.${carName}_battery_charging";
          fixed.power = ''
            {% set car_charging = states('binary_sensor.${carName}_battery_charging') | bool (false) %}
            {% set charger = states('switch.garden_garden_plug_laadpaal') | bool (false) %}
            {% set position = states('device_tracker.${carName}_position') == "home" %}
            {% set power = 0 %}
            {% if car_charging and charger and position %}
              {% set power = 1995 %}
            {% endif %}
            {{ power }}
          '';
        }
      ];
    };
  };
}

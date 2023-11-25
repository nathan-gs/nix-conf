{ config, pkgs, lib, ... }:

let
  ha = import ../../helpers/ha.nix { lib = lib; };
  carName = config.secrets.nathan-car.name;

in

{

  services.home-assistant.config = {

    template = [
      {
        sensor = [
        ];

        binary_sensor = [
          {
            name = "car_charger_can_load";
            device_class = "plug";
            icon = ''
              {% if states('binary_sensor.car_charger_can_load') %}
              mdi:car-electric
              {% else %}
              mdi:car-electric-outline
              {% endif %}
            '';
            state = ''
              {% set solar_remaining = states('sensor.energy_production_today_remaining') | float(0)  %}
              {% set battery_remaining = states('sensor.solis_remaining_battery_capacity') | float(0) %}
              {% set car_charged = states('sensor.${carName}_battery_level') | float(10) %}
              {% set solar_now = states('sensor.solar_currently_produced') | float(0) %}
              {% set current_usage = states('sensor.electricity_total_power') | float(5) / 1000 %}
              {% set charger_in_use = states('switch.garden_garden_plug_laadpaal') | bool(false) %}
              {% set charger_consumption = 2.2 %}
              {#
              {% set solar_remaining = 8.1  %}
              {% set solar_now = 2.6 | float(0) %}
              {% set current_usage = 3.0 %}
              {% set charger_in_use = true %}
              #}
              {# calculations #}
              {% set car_kwh_needed = ((11 * (100 - car_charged))/100) %}
              {% set battery_needed = (5 * (100 - battery_remaining))/100 %}
              {% set house_needed = 0.3 * (24 - now().hour) %}
              {% set total_needed = house_needed + car_kwh_needed + battery_needed %}
              {% set production_needed = current_usage + charger_consumption %}
              {% if charger_in_use %}
              {% set production_needed = production_needed - charger_consumption %}
              {% endif %}
              {#
              {{ current_usage }}kWh
              {{ solar_remaining }}kWh
              {{ battery_remaining }}%
              {{ solar_now }} kW
              {{ car_charged }}%
              {{ car_kwh_needed}}kWh
              {{ battery_needed }}kWH
              {{ total_needed }}kWh
              {{ production_needed }}kW
              #}
              {% if solar_now > production_needed %}
                {% if solar_remaining > total_needed %}
                  true
                {% else %}
                  false
                {% endif %}
              {% else %}
                false
              {% endif %}
            '';
          }
        ];
      }
    ];

    "automation manual" = [
      (
        ha.automation "system/car_charger.charging_stopped"
          {
            triggers = [ (ha.trigger.state_to "binary_sensor.${carName}_plug_status" "off") ];
            actions = [
              (ha.action.delay "00:05:00")
              (ha.action.off "switch.garden_garden_plug_laadpaal")
            ];
          }
      )
      (
        ha.automation "system/car_charger.turn_on"
          {
            triggers = [ (ha.trigger.at "01:30:00") ];
            actions = [
              (ha.action.on "switch.garden_garden_plug_laadpaal")
            ];
          }
      )
    ];
  };
}

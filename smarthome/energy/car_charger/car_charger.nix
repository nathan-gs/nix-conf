{ config, pkgs, lib, ... }:

let
  ha = import ../../helpers/ha.nix { lib = lib; };
  carName = config.secrets.nathan-car.name;
  consumptionPower = "2010";

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

    input_boolean = {
      car_charger_charge_at_night = {
        icon = "mdi:ev-station";
      };
      car_charger_charge_offpeak = {
        icon = "mdi:ev-station";
      };
    };

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
            triggers = [(
              ha.trigger.template_for 
                ''
                  {% set is_offpeak = states('binary_sensor.electricity_is_offpeak') | bool(false) %}
                  {% set not_high_usage = not(states('binary_sensor.electricity_high_usage') | bool(true)) %}
                  {% set plugged_in = states('binary_sensor.${carName}_plug_status') | bool(true) %}
                  {% set is_home = states('device_tracker.${carName}_position') == "home" %}
                  {{ is_offpeak and not_high_usage and plugged_in and is_home }}
                ''
                "00:30:00"
            )];
            conditions = [
              (ha.condition.on "input_boolean.car_charger_charge_offpeak")
            ];
            actions = [
              (ha.action.on "switch.garden_garden_plug_laadpaal")
            ];
          }
      )
    ];

    powercalc = {
      sensors = [
        {
          name = "car_charger";
          unique_id = "car_charger";
          entity_id = "binary_sensor.${carName}_battery_charging";
          fixed.power = ''
            {% set car_charging = states('binary_sensor.${carName}_battery_charging') | bool (false) %}
            {% set charger = states('switch.garden_garden_plug_laadpaal') | bool (false) %}
            {% set position = states('device_tracker.${carName}_position') == "home" %}
            {% set power = 0 %}
            {% if car_charging and charger and position %}
              {% set power = ${consumptionPower} %}
            {% endif %}
            {{ power }}
          '';
        }
        {
          name = "car_charger_solar";
          unique_id = "car_charger_solar";
          entity_id = "binary_sensor.${carName}_battery_charging";
          fixed.power = ''
            {% set car_charging = states('binary_sensor.${carName}_battery_charging') | bool (false) %}
            {% set charger = states('switch.garden_garden_plug_laadpaal') | bool (false) %}
            {% set position = states('device_tracker.${carName}_position') == "home" %}
            {% set import_from_grid = states('sensor.electricity_grid_consumed_power') | float(1500) %}
            {% set power = 0 %}
            {% if car_charging and charger and position %}              
              {% set power = min((${consumptionPower} - import_from_grid), ${consumptionPower}) %}
              {% if power < 0 %}
                {% set power = 0 %}
              {% endif %}
            {% endif %}
            {{ power }}
          '';
        }
        {
          name = "car_charger_grid";
          entity_id = "binary_sensor.${carName}_battery_charging";
          unique_id = "car_charger_grid";
          fixed.power = ''
            {% set car_charging = states('binary_sensor.${carName}_battery_charging') | bool (false) %}
            {% set charger = states('switch.garden_garden_plug_laadpaal') | bool (false) %}
            {% set position = states('device_tracker.${carName}_position') == "home" %}
            {% set import_from_grid = states('sensor.electricity_grid_consumed_power') | float(1500) %}
            {% set power = 0 %}
            {% if car_charging and charger and position %}
              {% set power = min(import_from_grid, ${consumptionPower}) %}
            {% endif %}
            {{ power }}
          '';
        }
      ];
    };
  };
}

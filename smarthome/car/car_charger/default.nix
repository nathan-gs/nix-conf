{ config, pkgs, lib, ha, ... }:

let
  carName = config.secrets.nathan-car.name;
  consumptionPower = "2050";
  utilityMeter = name: cycle: {
    "${name}_${cycle}" = {
      source = "sensor.${name}";
      cycle = cycle;
    };
  };
  
in

{

  services.home-assistant.config = {

    template = [
      {
        trigger = {
          platform = "time_pattern";
          hours = "*";
          minutes = "59";
          seconds = "50";
        };
        sensor = [
          {
            name = "car_charger_solar_revenue_previous";
            state = ''        
            {{ states('sensor.car_charger_solar_revenue')| float(0) }}
          '';
            unit_of_measurement = "€";
            device_class = "monetary";
            state_class = "total";
            icon = "mdi:car-electric-outline";
          }
          {
            name = "car_charger_grid_revenue_previous";
            state = ''        
            {{ states('sensor.car_charger_grid_revenue')| float(0) }}
          '';
            unit_of_measurement = "€";
            device_class = "monetary";
            state_class = "total";
            icon = "mdi:car-electric-outline";
          }
        ];
      }
      {
        trigger = {
          platform = "time_pattern";
          hours = "*";
          minutes = "*";
          seconds = "1";
        };
        sensor = [
          {
            name = "car_charger_solar_revenue";
            state = ''              
              {% set hourly = states('sensor.car_charger_solar_revenue_hourly') %}
              {% set previous = states('sensor.car_charger_solar_revenue_previous') | float(0) %}
              {% if hourly not in ['unavailable', 'unknown', 'none'] %}
                {{ previous + (hourly | float) | round(2) }}       
              {% else %}
                {{ this.state | float }}
              {% endif %}                     
            '';
            unit_of_measurement = "€";
            device_class = "monetary";
            state_class = "total";
            icon = "mdi:car-electric-outline";
          }
          {
            name = "car_charger_grid_revenue";
            state = ''              
              {% set hourly = states('sensor.car_charger_grid_revenue_hourly') %}
              {% set previous = states('sensor.car_charger_grid_revenue_previous') | float(0) %}
              {% if hourly not in ['unavailable', 'unknown', 'none'] %}
                {{ previous + (hourly | float) | round(2) }}       
              {% else %}
                {{ this.state | float }}
              {% endif %}              
            '';
            unit_of_measurement = "€";
            device_class = "monetary";
            state_class = "total";
            icon = "mdi:car-electric-outline";
          }          
        ];
      }
      {
        sensor = [
          {
            name = "car_charger_solar_revenue_hourly";
            device_class = "monetary";
            state = ''
              {% set energy = states('sensor.car_charger_solar_energy_hourly') %}
              {% set injection_rev = states('sensor.electricity_injection_creg_kwh') %}
              {% if energy not in ['unavailable', 'unknown', 'none'] or injection_rev not in ['unavailable', 'unknown', 'none', 0] %}
                {{ (energy | float * injection_rev | float) | round(2) }}
              {% else %}
                {{ this.state | float }}
              {% endif %}
            '';
            unit_of_measurement = "€";
            icon = "mdi:car-electric-outline";
            state_class = "total";
          }
          {
            name = "car_charger_grid_revenue_hourly";
            device_class = "monetary";
            state = ''
              {% set energy = states('sensor.car_charger_grid_energy_hourly') %}
              {% set injection_rev = states('sensor.electricity_injection_creg_kwh')  %}
              {% set energy_cost = states('sensor.energy_electricity_cost') %}
              {% if (energy not in ['unavailable', 'unknown', 'none']) or (injection_rev not in ['unavailable', 'unknown', 'none', 0]) or (energy_cost not in ['unavailable', 'unknown', 'none', 0]) %}
               {% set rev = (injection_rev | float) - (energy_cost | float) %}
                {{ (energy | float * rev) | round(2) }}
              {% else %}
                {{ this.state | float }}
              {% endif %}
            '';
            unit_of_measurement = "€";
            icon = "mdi:car-electric-outline";
            state_class = "total";
          }
          {
            name = "car_charger_revenue_hourly";
            device_class = "monetary";
            state = ''
              {% set grid = states('sensor.car_charger_grid_revenue_hourly') | float(0) %}
              {% set solar = states('sensor.car_charger_solar_revenue_hourly') | float(0) %}
              {{ grid + solar | round(2) }}
            '';
            unit_of_measurement = "€";
            icon = "mdi:car-electric-outline";
            state_class = "total";
          }
          {
            name = "car_charger_revenue";
            state = ''              
              {% set grid = states('sensor.car_charger_grid_revenue') | float(0) %}
              {% set solar = states('sensor.car_charger_solar_revenue') | float(0) %}
              {{ grid + solar | round(2) }}
            '';
            unit_of_measurement = "€";
            device_class = "monetary";
            state_class = "total";
            icon = "mdi:car-electric-outline";
          }
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

    utility_meter = {} 
      // utilityMeter "car_charger_grid_revenue" "daily"
      // utilityMeter "car_charger_grid_revenue" "monthly"
      // utilityMeter "car_charger_solar_revenue" "daily"
      // utilityMeter "car_charger_solar_revenue" "monthly"
      // utilityMeter "car_charger_revenue" "daily"
      // utilityMeter "car_charger_revenue" "monthly"
    ;

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
                  {% set is_home = states('binary_sensor.anyone_home') | bool(true) %}
                  {{ is_offpeak and not_high_usage and plugged_in and is_home }}
                ''
                "00:01:00"
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
            {% set l3_usage = states('sensor.dsmr_reading_phase_currently_delivered_l3') | int(0) %}
            {% set power = 0 %}
            {% if car_charging and charger and position %}
              {% set power = min(${consumptionPower}, l3_usage) %}
            {% endif %}
            {{ power }}
          '';
          create_utility_meters = true;
          utility_meter_types = [ "hourly" "daily" "monthly" ];
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
            {% set l3_usage = states('sensor.dsmr_reading_phase_currently_delivered_l3') | int(0) %}
            {% set consumptionPower = min(${consumptionPower}, l3_usage) %}
            {% set power = 0 %}
            {% if car_charging and charger and position %}              
              {% set power = min((consumptionPower - import_from_grid), consumptionPower) %}
              {% if power < 0 %}
                {% set power = 0 %}
              {% endif %}
            {% endif %}
            {{ power }}
          '';
          create_utility_meters = true;
          utility_meter_types = [ "hourly" "daily" "monthly" ];
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
            {% set l3_usage = states('sensor.dsmr_reading_phase_currently_delivered_l3') | int(0) %}
            {% set consumptionPower = min(${consumptionPower}, l3_usage) %}
            {% set power = 0 %}
            {% if car_charging and charger and position %}
              {% set power = min(import_from_grid, consumptionPower) %}
            {% endif %}
            {{ power }}
          '';
          create_utility_meters = true;
          utility_meter_types = [ "hourly" "daily" "monthly" ];
        }
      ];
    };

    recorder = {
      include = {
        entities = [
          "binary_sensor.car_charger_can_load"
          "input_boolean.car_charger_charge_at_night"
          "input_boolean.car_charger_charge_offpeak"
        ];

        entity_globs = [
          "sensor.car_charger_*"
        ];
      };
    };
  };
}

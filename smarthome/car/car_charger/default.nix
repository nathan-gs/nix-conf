{ config, pkgs, lib, ha, ... }:

let
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
              false
            '';
          }
          {
            name = "car_charger_automation_should_charge";
            device_class = "plug";
            icon = ''
              {% if is_state('binary_sensor.car_charger_automation_should_charge', "on") %}
              mdi:car-electric
              {% else %}
              mdi:car-electric-outline
              {% endif %}
            '';
            state = ''
              {% set charge_offpeak = is_state("input_boolean.car_charger_charge_offpeak", "on") %}
              {% set charge_at = is_state("input_boolean.car_charger_charge_at", "on") %}
              {{ charge_offpeak or charge_at }}
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
      car_charger_charge_at = {
        icon = "mdi:ev-station";
      };
    };

    input_datetime = {
      car_charger_charge_at = {
        has_date = false;
        has_time = true;
        icon = "mdi:ev-station";
        initial = "23:00";
      };
    };

    "automation manual" = [
      (
        ha.automation "system/car_charger.charging_stopped"
          {
            triggers = [ 
              (ha.trigger.state_to "binary_sensor.nphone_android_auto" "on") 
              (ha.trigger.state_to "binary_sensor.fphone_a55_android_auto" "on") 
            ];
            actions = [
              (ha.action.delay "00:05:00")
              (ha.action.off "switch.garden_garden_metering_plug_laadpaal")
            ];
          }
      )
      (
        ha.automation "system/car_charger.turn_on"
          {
            triggers = [
              (
                ha.trigger.template 
                  ''
                    {% set is_offpeak = states('binary_sensor.electricity_is_offpeak') | bool(false) %}
                    {% set should_charge = states('input_boolean.car_charger_charge_offpeak') | bool(false) %}
                    {{ should_charge and is_offpeak }}
                  ''
              )
              (ha.trigger.at "input_datetime.car_charger_charge_at")
            ];
            conditions = [
              (ha.condition.off "binary_sensor.electricity_high_usage")
              (ha.condition.on "binary_sensor.car_charger_automation_should_charge")
            ];
            actions = [
              (
                ha.action.conditional 
                  [(ha.condition.below "sensor.solis_remaining_battery_capacity" 20)]
                  [
                    (ha.action.automation "solar_battery_charge")
                    (ha.action.delay "00:02:00")
                    (ha.action.delay ''{{ (states('sensor.solar_battery_charging_remaining_minutes_till_overdischargesoc') | int(0)) * 60 }}'')
                  ]
                  []
              )
              (ha.action.set_value "number.solar_battery_maxgridpower" 300)
              (ha.action.on "switch.garden_garden_metering_plug_laadpaal")
              (ha.action.off "input_boolean.car_charger_charge_offpeak")
              (ha.action.off "input_boolean.car_charger_charge_at")
            ];
          }
      )
    ];

    powercalc = {
      sensors = [
        {
          name = "car_charger";
          unique_id = "car_charger";
          entity_id = "switch.garden_garden_metering_plug_laadpaal";
          fixed.power = ''            
            {% set power = states('sensor.garden_garden_metering_plug_laadpaal_power') | float(0) %}
            {{ power }}
          '';
          create_utility_meters = true;
          utility_meter_types = [ "hourly" "daily" "monthly" ];
        }
        {
          name = "car_charger_solar";
          unique_id = "car_charger_solar";
          entity_id = "switch.garden_garden_metering_plug_laadpaal";
          fixed.power = ''            
            {% set import_from_grid = states('sensor.electricity_grid_consumed_power') | float(1500) %}
            {% set consumptionPower = states('sensor.garden_garden_metering_plug_laadpaal_power') | float(0) %}
            {% set power = (consumptionPower - import_from_grid) %}
            {% if power < 0 %}
              {% set power = 0 %}
            {% endif %}
            {{ power }}
          '';
          create_utility_meters = true;
          utility_meter_types = [ "hourly" "daily" "monthly" ];
        }
        {
          name = "car_charger_grid";
          entity_id = "switch.garden_garden_metering_plug_laadpaal";
          unique_id = "car_charger_grid";
          fixed.power = ''
            {% set import_from_grid = states('sensor.electricity_grid_consumed_power') | float(1500) %}
            {% set consumptionPower = states('sensor.garden_garden_metering_plug_laadpaal_power') | float(0) %}
            {% set power = min(import_from_grid, consumptionPower) %}
            {% if power < 0 %}
              {% set power = 0 %}
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
          "sensor.garden_garden_metering_plug_power"
          "sensor.garden_garden_metering_plug_energy"
        ];

        entity_globs = [
          "sensor.car_charger_*"
        ];
      };
    };
  };
}

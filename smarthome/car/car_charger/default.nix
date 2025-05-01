{ config, pkgs, lib, ha, ... }:

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
            name = "car_charger_charging";
            device_class = "plug";
            state = ''
              {{ is_state('sensor.ohme_home_go_status', 'charging')  }}
            '';
          }
        ];
      }
    ];

    utility_meter = {} 
      // ha.utility_meter "car_charger_grid_revenue" "sensor.car_charger_grid_revenue" "daily"
      // ha.utility_meter "car_charger_grid_revenue" "sensor.car_charger_grid_revenue" "monthly"
      // ha.utility_meter "car_charger_solar_revenue" "sensor.car_charger_solar_revenue" "daily"
      // ha.utility_meter "car_charger_solar_revenue" "sensor.car_charger_solar_revenue" "monthly"
      // ha.utility_meter "car_charger_revenue" "sensor.car_charger_revenue" "daily"
      // ha.utility_meter "car_charger_revenue" "sensor.car_charger_revenue" "monthly"
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

    input_number = {
      car_charger_automation_attempt = {
        icon = "mdi:ev-station";
        min = 0;
        max = 15;
        step = 1;
      };
      car_charger_charge_target = {
        icon = "mdi:ev-station";
        min = 0;
        max = 100;
        step = 5;
        unit_of_measurement = "%";
        mode = "slider";
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
        ha.automation "system/car_charger.night_turn_on"
          {
            triggers = [
              (ha.trigger.time_pattern_minutes "10")
            ];
            conditions = [
              (ha.condition.on "binary_sensor.calendar_night")
              (ha.condition.state "device_tracker.x1_xdrive30e" "home")
              (ha.condition.below "sensor.x1_xdrive30e_remaining_battery_percent" "input_number.car_charger_charge_target")
            ];
            actions = [
              (ha.action.set_value "select.x1_xdrive30e_ac_charging_limit" "9")
              (
                ha.action.conditional 
                  [
                    (ha.condition.off "switch.x1_xdrive30e_charging")
                  ]
                  [
                    (ha.action.delay "00:01:00")
                    (ha.action.on "switch.x1_xdrive30e_charging")
                  ]
                  []
              )
            ];
          }
      )
      (
        ha.automation "system/car_charger.night_completed"
          {
            triggers = [
              (ha.trigger.above "sensor.x1_xdrive30e_remaining_battery_percent" "input_number.car_charger_charge_target")
              (ha.trigger.at "06:55:00")
            ];
            conditions = [
              (ha.condition.state "device_tracker.x1_xdrive30e" "home")
              (ha.condition.on "binary_sensor.calendar_night")
            ];
            actions = [
              (ha.action.off "switch.x1_xdrive30e_charging")
              (ha.action.delay "00:01:00")
              (ha.action.set_value "select.x1_xdrive30e_ac_charging_limit" "32")
              (ha.action.set_value "input_number.car_charger_charge_target" "0")
            ];
          }
      )
      (
        ha.automation "system/car_charger.sunny"
          {
            triggers = [
              (ha.trigger.state "sensor.electricity_solar_power")
              (
                ha.trigger.template 
                  ''
                    {% set battery_remaining = states('sensor.solis_remaining_battery_capacity') | int(0) %}
                    {% set solar_remaining = states('sensor.energy_production_today_remaining') | float(0) %}
                    {% set solar = (states('sensor.electricity_solar_power') | int(0)) - 300 %}
                    {{ (battery_remaining > 40) and (solar > 800) or (solar_remaining > 12) }}
                  ''
              )
            ];
            conditions = [
              (ha.condition.state "device_tracker.x1_xdrive30e" "home")
              (
                ha.condition.template 
                  ''
                    {% set battery_remaining = states('sensor.solis_remaining_battery_capacity') | int(0) %}
                    {% set solar_remaining = states('sensor.energy_production_today_remaining') | float(0) %}
                    {% set solar = states('sensor.electricity_solar_power') | int(0) %}
                    {{ (battery_remaining > 90) or (solar > 1300) or ((battery_remaining > 40) and (solar > 800) and (solar_remaining > 12)) }}
                  ''
              )
            ];
            actions = [
              (
                ha.action.conditional 
                  [
                    (
                      ha.condition.template
                        # Keep consistent with below! (to avoid BMW limits) 
                        ''
                          {% set sun = (states('sensor.electricity_solar_power') | int(0)) - 300 %}
                          {% set battery_remaining = states('sensor.solis_remaining_battery_capacity') | int(0) %}
                          {% set solar_remaining = states('sensor.energy_production_today_remaining') | float(0) %}
                          {% set grid_consumed = states('sensor.electricity_grid_consumed_power_max_1m') | int(0) %}
                          {% set available_a = sun / 230 %}
                          {% set a = available_a | round(0) %}
                          {% if grid_consumed > 300 %}
                              {% set target = 6 %}
                          {% elif solar_remaining > 8 and battery_remaining > 50 %}
                              {% set target = 11 %}
                          {% elif solar_remaining < 3.5 and battery_remaining <= 90 %}
                              {% set target = 6 %}
                          {% else %}
                              {% set target = max(min(a, 11), 6) %}
                          {% endif %}
                          {{ target == states('select.x1_xdrive30e_ac_charging_limit') | int(32) }}
                        ''
                    )
                  ]
                  []
                  [
                    (ha.action.delay "00:03:00")
                    (
                      ha.action.set_value 
                        "select.x1_xdrive30e_ac_charging_limit"
                        ''
                          {% set sun = (states('sensor.electricity_solar_power') | int(0)) - 300 %}
                          {% set battery_remaining = states('sensor.solis_remaining_battery_capacity') | int(0) %}
                          {% set solar_remaining = states('sensor.energy_production_today_remaining') | float(0) %}
                          {% set grid_consumed = states('sensor.electricity_grid_consumed_power_max_1m') | int(0) %}
                          {% set available_a = sun / 230 %}
                          {% set a = available_a | round(0) %}
                          {% if grid_consumed > 300 %}
                              {% set target = 6 %}
                          {% elif solar_remaining > 8 and battery_remaining > 50 %}
                              {% set target = 11 %}
                          {% elif solar_remaining < 3.5 and battery_remaining <= 90 %}
                              {% set target = 6 %}
                          {% else %}
                              {% set target = max(min(a, 11), 6) %}
                          {% endif %}
                          {{ target }}
                        ''
                    )
                  ]
              )
              (
                ha.action.conditional 
                  [
                    (ha.condition.off "switch.x1_xdrive30e_charging")
                  ]
                  [
                    (ha.action.delay "00:03:00")
                    (ha.action.on "switch.x1_xdrive30e_charging")
                  ]
                  []
              )
            ];
            mode = "queued";
          }
      )
      (
        ha.automation "system/car_charger.charging_elsewhere"
          {
            triggers = [
              (ha.trigger.on "binary_sensor.x1_xdrive30e_charging_status")
            ];
            conditions = [
              (ha.condition.state "device_tracker.x1_xdrive30e" "away")
            ];
            actions = [
              (ha.action.set_value "select.x1_xdrive30e_ac_charging_limit" "32")
            ];
          }
      )
      (
        ha.automation "system/car_charger.turn_off"
          {
            triggers = [
              (ha.trigger.on "binary_sensor.electricity_delivery_power_max_threshold")
              (ha.trigger.below "sensor.electricity_solar_power" 1000)
            ];
            conditions = [
              (ha.condition.state "device_tracker.x1_xdrive30e" "home")
              (ha.condition.on "switch.x1_xdrive30e_charging")
            ];
            actions = [
              (ha.action.off "switch.x1_xdrive30e_charging")     
              (ha.action.delay "00:02:00")
            ];
            mode = "restart";
          }
      )
      (
        ha.automation "system/car_charger.ask"
          {
            triggers = [
              (ha.trigger.at "21:30")
            ];
            conditions = [
              (ha.condition.state "device_tracker.x1_xdrive30e" "home")
            ];
            actions = [
              (ha.action.set_value "input_number.car_charger_charge_target" "0")
              {
                service = "notify.mobile_app_nphone";
                data = {
                  title = "Charge Car?";
                  message = "Charge option?";
                  data = {
                    tag = "car_charger_ask";
                    persistent = true;
                    sticky = true;
                    actions = [
                      {
                        action = "CAR_CHARGE_CHARGE_TO_30";
                        title = "Charge to 30%";
                      }
                      {
                        action = "CAR_CHARGE_CHARGE_TO_60";
                        title = "Charge to 60%";
                      }
                      {
                        action = "CAR_CHARGE_CHARGE_TO_95";
                        title = "Charge to 95%";
                      }
                    ];
                  };
                };
              }
            ];
          }
      )
      (
        ha.automation "system/car_charger.ask_action"
          {
            triggers = [
              {
                platform = "event";
                event_type = "mobile_app_notification_action";
                event_data.action = "CAR_CHARGE_CHARGE_TO_30";
              }
              {
                platform = "event";
                event_type = "mobile_app_notification_action";
                event_data.action = "CAR_CHARGE_CHARGE_TO_60";
              }
              {
                platform = "event";
                event_type = "mobile_app_notification_action";
                event_data.action = "CAR_CHARGE_CHARGE_TO_95";
              }
            ];            
            actions = [
              {
                service = "notify.mobile_app_nphone";
                data = {
                  message = "clear_notification";
                  data = {
                    tag = "car_charger_ask";                    
                  };
                };
              }
              (
                ha.action.set_value "input_number.car_charger_charge_target"
                  ''
                  {{ 30 if trigger.event.data.action == 'CAR_CHARGE_CHARGE_TO_30' else 60 if trigger.event.data.action == 'CAR_CHARGE_CHARGE_TO_60' else 95 }}
                  ''
              )
            ];
          }
      )
    ];

    powercalc = {
      sensors = [
        {
          name = "car_charger";
          unique_id = "car_charger";
          entity_id = "binary_sensor.car_charger_charging";
          fixed.power = ''            
            {% set power = (states('sensor.ohme_home_go_power') | float(0)) * 1000 %}
            {{ power }}
          '';
          create_utility_meters = true;
          utility_meter_types = [ "hourly" "daily" "monthly" ];
        }
        {
          name = "car_charger_solar";
          unique_id = "car_charger_solar";
          entity_id = "binary_sensor.car_charger_charging";
          fixed.power = ''            
            {% set import_from_grid = states('sensor.electricity_grid_consumed_power') | float(1500) %}
            {% set consumptionPower = (states('sensor.ohme_home_go_power') | float(0)) * 1000 %}
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
          entity_id = "binary_sensor.car_charger_charging";
          unique_id = "car_charger_grid";
          fixed.power = ''
            {% set import_from_grid = states('sensor.electricity_grid_consumed_power') | float(1500) %}
            {% set consumptionPower = (states('sensor.ohme_home_go_power') | float(0)) * 1000 %}
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
          "input_number.car_charger_charge_target"
        ];

        entity_globs = [
          "sensor.car_charger_*"
          "binary_sensor.ohme_*"
          "sensor.ohme_*"
          "switch.ohme_*"
          "number.ohme_*"
        ];
      };
    };
  };
}

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
              
              (ha.trigger.off "binary_sensor.ohme_home_go_car_connected") 
              (ha.trigger.off "switch.garden_garden_plug_laadpaal_repeater")
            ];
            actions = [
              (ha.action.on "switch.ohme_home_go_pause_charge")
              (ha.action.off "switch.garden_garden_plug_laadpaal_repeater")
              (ha.action.off "input_boolean.car_charger_charge_offpeak")
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
              (ha.trigger.state_to "switch.garden_garden_plug_laadpaal_repeater" "on")
              (ha.trigger.off "binary_sensor.electricity_delivery_power_near_max_threshold")
            ];
            conditions = [
              (
                ha.condition.template 
                ''
                  {% set charge_offpeak = is_state("input_boolean.car_charger_charge_offpeak", "on") %}
                  {% set laadpaal_repeater_on = is_state("switch.garden_garden_plug_laadpaal_repeater", "on") %}
                  {% set charge_at = is_state("input_boolean.car_charger_charge_at", "on") %}
                  {{ charge_offpeak or charge_at or laadpaal_repeater_on }}
                ''
              )
            ];
            actions = [     
              (
                ha.action.conditional 
                  [(ha.condition.below "input_number.car_charger_automation_attempt" 5)]
                  [
                    (
                      ha.action.conditional
                        [(ha.condition.off "binary_sensor.electricity_high_usage")]
                        [
                          (
                            ha.action.conditional 
                              [
                                (ha.condition.below "sensor.solis_remaining_battery_capacity" 18)
                                (ha.condition.below "sensor.electricity_solar_power" 1200)
                              ]
                              [                                
                                (ha.action.automation "solar_battery_charge")
                                (ha.action.delay "00:02:00")
                                (ha.action.delay ''{{ (states('sensor.solar_battery_charging_remaining_minutes_till_overdischargesoc') | int(0)) * 60 }}'')                            
                              ]
                              []
                          )
                          (ha.action.set_value "number.solar_battery_maxgridpower" 300)
                          (ha.action.off "switch.ohme_home_go_pause_charge")     
                          # Avoid retriggering
                          (
                            ha.action.conditional
                              [(ha.condition.off "switch.garden_garden_plug_laadpaal_repeater")]
                              [(ha.action.on "switch.garden_garden_plug_laadpaal_repeater")]
                              []
                          )                          
                          (ha.action.set_value "input_number.car_charger_automation_attempt" 0)                          
                          (ha.action.off "input_boolean.car_charger_charge_at")
                        ]
                        [
                          (ha.action.increment "input_number.car_charger_automation_attempt")
                          (
                            # Exponential back-off
                            ha.action.delay 
                              ''
                                {% set attempt = states("input_number.car_charger_automation_attempt") | int(1) %}
                                {{ (3**attempt * 60) |timestamp_custom('%H:%M:%S', false) }}
                              ''
                          )
                          (ha.action.automation "system_car_charger_turn_on")
                        ]
                    )
                  ]
                  [
                    (
                      ha.action.notify 
                        ''
                          {% set attempt = states("input_number.car_charger_automation_attempt") | int(1) %}
                          {% set delay = (3**attempt * 60) |timestamp_custom('%H:%M:%S', false) %}
                          car_charger: cannot charge, max attempts reached ({{attempt}}), for a delay of {{ delay }}
                        ''
                        ""
                    )
                  ]
              )         
              
            ];
          }
      )
      (
        ha.automation "system/car_charger.turn_off"
        {
          triggers = [
            (ha.trigger.off "binary_sensor.electricity_is_offpeak")
            (ha.trigger.off "switch.garden_garden_plug_laadpaal_repeater")
            (ha.trigger.on "binary_sensor.electricity_delivery_power_max_threshold")
          ];
          conditions = [
            (ha.condition.on "binary_sensor.ohme_home_go_car_connected")
          ];
          actions = [
            (ha.action.on "switch.ohme_home_go_pause_charge") 
          ];
        }
      )
      (
        ha.automation "system/car_charger.ask"
          {
            triggers = [
              (ha.trigger.at "21:30")
            ];
            conditions = [
              (ha.condition.on "binary_sensor.ohme_home_go_car_connected")
            ];
            actions = [
              {
                service = "notify.mobile_app_nphone";
                data = {
                  title = "Enable car charger during off peak?";
                  message = "Enable car charger during off peak?";
                  data = {
                    tag = "car_charger_ask";
                    persistent = true;
                    sticky = true;
                    actions = [
                      {
                        action = "CAR_CHARGE_CHARGE_AT_ON";
                        title = "Yes, charge at";
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
                event_data.action = "CAR_CHARGE_CHARGE_AT_ON";
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
              (ha.action.on "input_boolean.car_charger_charge_offpeak")
            ];
          }
      )
    ];

    powercalc = {
      sensors = [
        {
          name = "car_charger";
          unique_id = "car_charger";
          entity_id = "binary_sensor.ohme_home_go_car_connected";
          fixed.power = ''            
            {% set power = states('sensor.ohme_home_go_power_draw') | float(0) %}
            {{ power }}
          '';
          create_utility_meters = true;
          utility_meter_types = [ "hourly" "daily" "monthly" ];
        }
        {
          name = "car_charger_solar";
          unique_id = "car_charger_solar";
          entity_id = "binary_sensor.ohme_home_go_car_connected";
          fixed.power = ''            
            {% set import_from_grid = states('sensor.electricity_grid_consumed_power') | float(1500) %}
            {% set consumptionPower = states('sensor.ohme_home_go_power_draw') | float(0) %}
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
          entity_id = "binary_sensor.ohme_home_go_car_connected";
          unique_id = "car_charger_grid";
          fixed.power = ''
            {% set import_from_grid = states('sensor.electricity_grid_consumed_power') | float(1500) %}
            {% set consumptionPower = states('sensor.ohme_home_go_power_draw') | float(0) %}
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
          "binary_sensor.ohme_*"
          "sensor.ohme_*"
          "switch.ohme_*"
          "number.ohme_*"
        ];
      };
    };
  };
}

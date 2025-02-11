{ config, pkgs, lib, ha, ... }:
{

  services.home-assistant.config = {


    powercalc = {
      sensors = [ ];
    };

    #
    # The idea is every percentage represents a fixed kWh (dis)charging energy. 
    # The US5000 has 4800Wh, the US3000C has 3552Wh.
    #

    template = [
      {
        trigger = [
          {
            platform = "state";
            entity_id = "sensor.battery_percentage_change";        
          }
        ];
        sensor = [
          {
            name = "battery_charging_energy";
            state = ''
              {% set battery_change = states('sensor.battery_percentage_change') | float(0) %}
              {% if battery_change > 0 %}
                {{ (( this.state | float ) + ((battery_change * (48 + 35)) / 1000)) | round(2) }}
              {% else %}
                {{ this.state | float }}
              {% endif %}
            '';
            device_class = "energy";
            state_class = "total_increasing";
            unit_of_measurement = "kWh";
          }
          {
            name = "battery_discharging_energy";
            state = ''
              {% set battery_change = states('sensor.battery_percentage_change') | float(0) %}
              {% if battery_change < 0 %}
                {{ ((this.state | float) + ((battery_change * -1 * ((48 + 35) * 0.98)) / 1000)) | round(2) }}
              {% else %}
                {{ this.state | float }}
              {% endif %}
            '';
            device_class = "energy";
            state_class = "total_increasing";
            unit_of_measurement = "kWh";
          }
        ];
        binary_sensor = [
          {
            name = "solar/battery/is_charging";
            device_class = "battery_charging";
            state = ''
              {% set battery_change = states('sensor.battery_percentage_change') | float(0) %}
              {% if battery_change > 0 %}
                on
              {% else %}
                off
              {% endif %}
            '';
          }
          {
            name = "solar/battery/is_grid_charging";
            device_class = "battery_charging";
            state = ''
              {% set battery_change = states('sensor.battery_percentage_change') | float(0) %}
              {% set grid_power = states('sensor.electricity_grid_consumed_power_avg_1m') | float(0) %}
              {% if battery_change > 0 and grid_power > 150 %}
                on
              {% else %}
                off
              {% endif %}
            '';
          }
        ];
      }
      {
        sensor = [
          {
            name = "solar/battery/charging/remaining_minutes_till_overdischargesoc";
            state = '' 
              {% set max_grid_power = states('number.solar_battery_maxgridpower') | int(0) %}
              {% set battery_target = states('number.solar_battery_overdischargesoc') | int(0) %}
              {% set battery = states('sensor.solis_remaining_battery_capacity') | int(0) %}
              {% set to_charge = battery_target - battery %}
              {% if to_charge > 0 %}
                {% set percent_in_wh = (48 + 35) %}
                {% set wh_needed = to_charge * percent_in_wh %}
                {% set charge_time = wh_needed / max_grid_power if max_grid_power > 0 else 'N/A' %}
                {{ (charge_time * 60) | round(0) }}
              {% else %}
                0
              {% endif %}
            '';
          }
          {
            name = "solar/battery/overdischargesoc_target";
            unit_of_measurement = "%";
            device_class = "battery";
            state = ''
              {% set power15m = states('sensor.electricity_delivery_power_15m') | float(0) %}
              {% set power15m_estimated = states('sensor.electricity_delivery_power_15m_estimated') | float(0) %}
              {% set overdischargesoc = states('number.solar_battery_overdischargesoc') | int(20) %}
              {% set battery = states('sensor.solis_remaining_battery_capacity') | int(20) %}
              {% set is_car_charging = states('sensor.car_charger_power') | int(0) > 20 %}
              {% set is_solar_left = ((states('sensor.energy_production_today_remaining') | float(0) > 4) and now().hour >= 5) %}
              {% set overdischargesoc_default = 20 %}
              {% set overdischargesoc_charge_to = 15 %}
              {% set overdischargesoc_with_car_charger_on = 40 %}              
              {# min is 10 #}
              {% set overdischargesoc_min = 10 %}
              {#
              Test values
              {% set power15m = 2.1 %}
              {% set power15m_estimated = 2.8 %}

              Echo's
              {{ power15m }}
              {{ power15m_estimated }}
              {{ overdischargesoc }}
              #}
              {# Capacity Tweaks #}
              {% if (power15m > 1.95) and (power15m_estimated > 2.45) %}
                {{ overdischargesoc_min }}
              {# If car charging #}
              {% elif is_car_charging and is_solar_left == false %}
                {{ overdischargesoc_with_car_charger_on }}
              {% else %}
                {% if battery < 12 %}
                  {{ overdischargesoc_charge_to }}
                {% else %}
                  {{ overdischargesoc_default }}
                {% endif %}
              {% endif %}
            '';
          }
          {
            name = "solar/battery/forcechargesoc_target";
            unit_of_measurement = "%";
            device_class = "battery";
            state = ''
              {% set power15m = states('sensor.electricity_delivery_power_15m') | float(2) %}
              {% set power15m_estimated = states('sensor.electricity_delivery_power_15m_estimated') | float(2) %}
              {% set is_solar_left = ((states('sensor.energy_production_today_remaining') | float(0) > 3) and now().hour >= 5) %}
              {% set forcechargesoc = states('number.solar_battery_forcechargesoc') | int(10) %}
              {% set is_offpeak = states('binary_sensor.electricity_is_offpeak') | bool(false) %}
              {% set forcechargesoc_high = 19 %}
              {% set forcechargesoc_low = 10 %}
              {% set forcechargesoc_min = 7 %}

              {% set forcechargesoc_target = forcechargesoc_low %}
              {#
                {% if is_solar_left %}
                  {% set forcechargesoc_target = forcechargesoc_low %}
                {% elif is_offpeak %}
                  {% set forcechargesoc_target = forcechargesoc_high %}
                {% else %}
                  {% set forcechargesoc_target = forcechargesoc_low %}
                {% endif %}
              #}
              {% if (power15m < 1.5) and (power15m_estimated < 1.5) %}
                {{ forcechargesoc_target }}
              {% elif (power15m_estimated > 2) %}
                {{ forcechargesoc_min }}
              {% else %}
                {{ forcechargesoc }}
              {% endif %}
            '';
          }
        ];
      }
    ];

    input_boolean = {
      solar_battery_charge_offpeak = {
        name = "solar/battery/charge_offpeak";
        icon = "mdi:battery";
      };
    };

    

    mqtt.sensor = [
      {
        name = "battery_percentage_change";
        state_topic = "solar/battery/change";
        value_template = "{{ value_json.value }}";
        unit_of_measurement = "%";
        json_attributes_topic = "solar/battery/change";
        json_attributes_template = "{{ value_json | tojson }}";
        state_class = "measurement";
      }
    ];

    "automation manual" = [
      {
        id = "battery_change";
        alias = "battery_change";
        trigger = [
          {
            platform = "state";
            entity_id = "sensor.solis_remaining_battery_capacity";
          }
        ];
        condition = ''
          {{ not (is_state('sensor.solis_remaining_battery_capacity', 'unknown') or is_state('sensor.solis_remaining_battery_capacity', 'unavailable') or trigger.from_state.state | int(0) == 0) }}
        '';
        action = [
          (
            ha.action.mqtt_publish "solar/battery/change" 
              ''
                {
                  "from":{{ trigger.from_state.state | int(0) }},
                  "to": {{ trigger.to_state.state | int(0) }},
                  "value": {{ (trigger.to_state.state | int(0)) - (trigger.from_state.state | int(0)) }}
                }
              ''
              true
          )          
        ];
        mode = "single";
      }
      (ha.automation "solar/battery/charge" {
        triggers = [(ha.trigger.at "05:00:00")];
        conditions = [
          (ha.condition.on "input_boolean.solar_battery_charge_offpeak")
          (ha.condition.off "binary_sensor.electricity_high_usage")
        ];
        actions = [
          (ha.action.set_value "number.solar_battery_maxgridpower" 1200)
          (ha.action.delay "00:00:30")
          (ha.action.set_value "number.solar_battery_forcechargesoc" ''{{ states('number.solar_battery_overdischargesoc') | float(10) - 1 }}'')
          (ha.action.delay "00:00:30")
          (
            ha.action.conditional 
            [
              (ha.condition.template ''{{ states('sensor.energy_production_today_remaining') | int(0) > 8 }}'')
            ]
            [
              (ha.action.set_value "number.solar_battery_overdischargesoc" ''20'')
            ]
            [
              (ha.action.set_value "number.solar_battery_overdischargesoc" ''20'')
            ]
          )
        ];
        mode = "queued";
      })
      (ha.automation "solar/battery/max_charge" {
        triggers = [
          (ha.trigger.at "07:00:00")
        ];
        actions = [
          (ha.action.set_value "number.solar_battery_maxgridpower" 300)     
          (ha.action.delay "00:00:30")
          (ha.action.set_value "number.solar_battery_overdischargesoc" ''{{ states('sensor.solar_battery_overdischargesoc_target') | int(20) }}'')
        ];
        mode = "queued";
      })
      (ha.automation "solar/battery/overdischarge.control" {
        triggers = [(ha.trigger.state "sensor.solar_battery_overdischargesoc_target")];
        actions = [
          (ha.action.set_value "number.solar_battery_overdischargesoc" ''{{ states('sensor.solar_battery_overdischargesoc_target') | int }}'')
        ];
        mode = "queued";
      })
      (ha.automation "solar/battery/forcechargesoc.control" {
        triggers = [(ha.trigger.state_for "sensor.solar_battery_forcechargesoc_target" "00:00:15")];
        actions = [
          (ha.action.set_value "number.solar_battery_forcechargesoc" ''{{ states('sensor.solar_battery_forcechargesoc_target') | int }}'')
        ];
        mode = "queued";
      })
    ];

    recorder = {
      include = {
        entities = [
          "sensor.solar_battery_overdischargesoc_target"
          "sensor.solar_battery_forcechargesoc_target"
        ];
        entity_globs = [
          "sensor.solar_battery_*"
          "binary_sensor.solar_battery_*"
          "number.solar_*"
        ];
      };
    };


  };
}

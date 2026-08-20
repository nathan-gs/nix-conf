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
            unique_id = "battery_charging_energy";
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
            unique_id = "battery_discharging_energy";
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
            unique_id = "solar_battery_is_charging";
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
            unique_id = "solar_battery_is_grid_charging";
            device_class = "battery_charging";
            state = ''
              {% set battery_change = states('sensor.battery_percentage_change') | float(0) %}
              {% set grid_power = states('sensor.electricity_grid_consumed_power_mean_1m') | float(0) %}
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
        binary_sensor = [
          {
            name = "solar/battery/sufficient";
            unique_id = "solar_battery_sufficient";
            icon = "mdi:battery-high";
            state = ''
              {% set battery = states('sensor.system_house_pv_battery_soc') | int(10) %}
              {{ battery > 10 }}
            '';
          }          
        ];
      }
      {
        sensor = [
          {
            name = "solar/battery/charging/remaining_minutes_till_overdischargesoc";
            unique_id = "solar_battery_charging_remaining_minutes_till_overdischargesoc";
            state = '' 
              {% set max_grid_power = states('number.system_house_pv_force_charge_power_limitation') | int(0) %}
              {% set battery_target = states('number.system_house_pv_overdischarge_soc') | int(0) %}
              {% set battery = states('sensor.system_house_pv_battery_soc') | int(0) %}
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
            state_class = "measurement";
          }
          {
            name = "solar/battery/overdischargesoc_target";
            unique_id = "solar_battery_overdischargesoc_target";
            unit_of_measurement = "%";
            device_class = "battery";
            state = ''
              {% set power15m = states('sensor.electricity_delivery_power_15m') | float(0) %}
              {% set power15m_estimated = states('sensor.electricity_delivery_power_15m_estimated') | float(0) %}
              {# Capaciteitstarief floor is 2.5 kW — never deep-discharge to shave below that. #}
              {% set monthly_peak = states('sensor.electricity_delivery_power_monthly_15m_max') | float(2.5) %}
              {% set capacity_threshold = [2.5, monthly_peak - 0.1] | max %}
              {% set capacity_near = [2.2, monthly_peak - 0.3] | max %}
              {% set overdischargesoc = states('number.system_house_pv_overdischarge_soc') | int(20) %}
              {% set battery = states('sensor.system_house_pv_battery_soc') | int(20) %}
              {% set is_car_charging = states('sensor.car_charger_power') | int(0) > 20 %}
              {% set is_solar_left = ((states('sensor.energy_production_today_remaining') | float(0) > 4) and now().hour >= 5) %}
              {% set overdischargesoc_default = 20 %}
              {% set overdischargesoc_charge_to = 15 %}
              {% set overdischargesoc_with_car_charger_on = 40 %}
              {% set overdischargesoc_solar_left = 15 %}
              {# min is 10 #}
              {% set overdischargesoc_min = 8 %}
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
              {# Deep-discharge the battery to shave a peak only once it is imminent. Note the TWO
                 guards: it arms only if power15m > capacity_near AND power15m_estimated >
                 capacity_threshold. The car's charge control (system/car_charger/target_current)
                 keeps its projected 15-min average (power15m_estimated) below capacity_threshold —
                 the current steps snap down under the cap — so this second guard is never met while
                 the car is charging, and the battery never discharges to mask the car (which is what
                 drained it to 10% on 2026-07-03 ~04:00). This branch then fires only as a backstop
                 for real peaks the car alone cannot hold (and only in the billable band ≥ 2.5 kW).
                 See docs/ev-battery-peak-coordination.md. #}
              {% if (power15m > capacity_near) and (power15m_estimated > capacity_threshold) %}
                {{ overdischargesoc_min }}
              {# If solar left, prioritize to min even if car charging #}
              {% elif is_solar_left %}
                {{ overdischargesoc_solar_left }}
              {# If car charging and no solar left #}
              {% elif is_car_charging and is_solar_left == false %}
                {{ overdischargesoc_default }}
              {% else %}
                {% if battery < 12 %}
                  {{ overdischargesoc_charge_to }}
                {% else %}
                  {{ overdischargesoc_default }}
                {% endif %}
              {% endif %}
            '';
            state_class = "measurement";
          }
          {
            name = "solar/battery/forcechargesoc_target";
            unique_id = "solar_battery_forcechargesoc_target";
            unit_of_measurement = "%";
            device_class = "battery";
            state = ''
              {% set power15m = states('sensor.electricity_delivery_power_15m') | float(2) %}
              {% set power15m_estimated = states('sensor.electricity_delivery_power_15m_estimated') | float(2) %}
              {% set monthly_peak = states('sensor.electricity_delivery_power_monthly_15m_max') | float(2.5) %}
              {% set capacity_threshold = [2.5, monthly_peak - 0.4] | max %}
              {% set capacity_safe = [2.0, monthly_peak - 1.0] | max %}
              {% set is_solar_left = ((states('sensor.energy_production_today_remaining') | float(0) > 3) and now().hour >= 5) %}
              {% set forcechargesoc = states('number.system_house_pv_force_charge_soc') | int(10) %}
              {% set is_offpeak = states('binary_sensor.electricity_is_offpeak') | bool(false) %}
              {% set forcechargesoc_high = 19 %}
              {% set forcechargesoc_low = 10 %}
              {% set forcechargesoc_min = 7 %}

              {% set forcechargesoc_target = forcechargesoc_min %}
              {{ forcechargesoc_target }}              
            '';
            state_class = "measurement";
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
        unique_id = "battery_percentage_change";
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
            entity_id = "sensor.system_house_pv_battery_soc";
          }
        ];
        condition = ''
          {{ not (is_state('sensor.system_house_pv_battery_soc', 'unknown') or is_state('sensor.system_house_pv_battery_soc', 'unavailable') or trigger.from_state.state | int(0) == 0) }}
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
          (ha.action.set_value "number.system_house_pv_force_charge_power_limitation" 1200)
          (ha.action.delay "00:00:30")
          (ha.action.set_value "number.system_house_pv_force_charge_soc" ''{{ states('number.system_house_pv_overdischarge_soc') | float(10) - 1 }}'')
          (ha.action.delay "00:00:30")
          (
            ha.action.conditional 
            [
              (ha.condition.template ''{{ states('sensor.energy_production_today_remaining') | int(0) > 8 }}'')
            ]
            [
              (ha.action.set_value "number.system_house_pv_overdischarge_soc" ''20'')
            ]
            [
              (ha.action.set_value "number.system_house_pv_overdischarge_soc" ''20'')
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
          (ha.action.set_value "number.system_house_pv_force_charge_power_limitation" 300)     
          (ha.action.delay "00:00:30")
          (ha.action.set_value "number.system_house_pv_overdischarge_soc" ''{{ states('sensor.solar_battery_overdischargesoc_target') | int(20) }}'')
        ];
        mode = "queued";
      })
      (ha.automation "solar/battery/overdischarge.control" {
        triggers = [(ha.trigger.state "sensor.solar_battery_overdischargesoc_target")];
        actions = [
          (ha.action.set_value "number.system_house_pv_overdischarge_soc" ''{{ states('sensor.solar_battery_overdischargesoc_target') | int }}'')
        ];
        mode = "queued";
      })
      (ha.automation "solar/battery/forcechargesoc.control" {
        triggers = [(ha.trigger.state_for "sensor.solar_battery_forcechargesoc_target" "00:00:15")];
        actions = [
          (ha.action.set_value "number.system_house_pv_force_charge_soc" ''{{ states('sensor.solar_battery_forcechargesoc_target') | int }}'')
        ];
        mode = "queued";
      })
    ];

  };
}

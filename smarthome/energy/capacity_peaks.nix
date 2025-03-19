{ config, pkgs, lib, ha, ... }:
{

  services.home-assistant.config = {

    utility_meter = {
      electricity_delivery_15m = {
        source = "sensor.electricity_delivery";
        cron = "*/15 * * * *";
      };
    };

    mqtt.sensor = [    
      {
        name = "electricity_delivery_power_monthly_15m_max";
        state_topic = "dsmr/consumption/peak/running_month";
        unit_of_measurement = "kW";
        device_class = "power";
        force_update = true;
        icon = "mdi:meter-electric";
        state_class = "measurement";
      }
    ];

    template = [  
      {
        sensor = [
          {
            name = "electricity_delivery_power_15m";
            state = "{{ states('sensor.dsmr_consumption_quarter_hour_peak_electricity_average_delivered') | float(0) }}";
            unit_of_measurement = "kW";
            state_class = "measurement";
            device_class = "power";
          }
          {
            name = "electricity_delivery_power_daily_15m_max";
            state = ''
              {% set electricity_delivery_power_15m = states('sensor.electricity_delivery_power_15m') | float(0) %}
              {% set electricity_delivery_power_daily_15m_max = this.state | float(0) %}
              {% if ((now().hour == 0) and (now().minute < 15)) %}
                {{ electricity_delivery_power_15m }}
              {% else %}
                {% if electricity_delivery_power_daily_15m_max < electricity_delivery_power_15m %}
                  {{ electricity_delivery_power_15m }}
                {% else %}
                  {{ electricity_delivery_power_daily_15m_max }} 
                {% endif %}
              {% endif %}
            '';
            unit_of_measurement = "kW";
            state_class = "measurement";
            device_class = "power";
          }
          {
            name = "electricity_delivery_power_15m_estimated";
            unit_of_measurement = "kW";
            state = ''
              {% set seconds_left = (15 - now().minute % 15) * 60 - now().second % 60 %}
              {# workaround because power_15m reports the previous value for ~ 10s after the quarter #}
              {% if seconds_left < (15 * 60 - 30)  %}
                {% set power_15m = states('sensor.electricity_delivery_power_15m') | float(0) %}
              {% else %}
                {% set power_15m = 0 %}
              {% endif %}
              {% set current_power = (states('sensor.electricity_grid_consumed_power_mean_1m') | float(states('sensor.electricity_grid_consumed_power') | float(0))) / 1000 %}
              {% set current_power_till_end = (current_power * seconds_left) / (3600 / 4) %}
              {{ ((current_power_till_end + power_15m)) | round(2) }}
            '';
            state_class = "measurement";
            device_class = "power";
          }
        ];
        binary_sensor = [
          {
            name = "electricity_high_usage";
            state = ''
              {% set is_high = false %}
              {# Wasmachine #}
              {% set is_washing = is_state('sensor.aeg_wasmachine_cyclephase', "Wash") %}
              {% if is_washing %}
                {% set is_high = true %}
              {% endif %}
              {# oven #}
              {% set oven_on = states('sensor.floor0_keuken_metering_plug_oven_power') | int(0) > 1000 %}
              {% if oven_on %}
                {% set is_high = true %}
              {% endif %}
              {# Bathroom Heating #}
              {% set bathroom_heating_on = states('switch.floor1_badkamer_metering_plug_verwarming') | bool(false) %}
              {% if bathroom_heating_on %}
                {% set is_high = true %}
              {% endif %}
              {# car charger #}
              {% set car_charger_on = states('sensor.car_charger_power') | int(0) > 20 %}
              {% if car_charger_on %}
                {% set is_high = true %}
              {% endif %}
              {% if states('sensor.electricity_grid_consumed_power') | int(0) < 1000 %}
                {% set is_high = false %}
              {% endif %}
              {% if states('sensor.electricity_delivery_power_15m_estimated') | float(0) > 1.5 %}
                {% set is_high = true %}
              {% endif %}
              {% if is_state('binary_sensor.electricity_delivery_power_near_max_threshold', "on") %}
                {% set is_high = true %}
              {% endif %}
              {{ is_high }}
            '';
            delay_off.seconds = 120;
            device_class = "running";
          }       
          {
            name = "electricity_delivery_power_max_threshold";
            state = ''
              {% set power15m_estimated = states('sensor.electricity_delivery_power_15m_estimated') | float(0) %}
              {% set power15m = states('sensor.electricity_delivery_power_15m') | float(0) %}
              {{ (power15m > 1.25) and (power15m_estimated > 2.48) }}              
            '';
          }
          {
            name = "electricity_delivery_power_near_max_threshold";
            state = ''
              {% set electricity_delivery_power_15m_estimated = states('sensor.electricity_delivery_power_15m_estimated') | float(0) %}
              {{ electricity_delivery_power_15m_estimated > 1.9 }}
            '';
          }
        ];
      }
    ];



    "automation manual" = [
      {
        id = "electricity_delivery_power_max_threshold_notify";
        alias = "electricity_delivery_power_max_threshold.notify";
        trigger = [
          {
            platform = "state";
            entity_id = "binary_sensor.electricity_delivery_power_max_threshold";
            to = "on";
          }
        ];
        condition = [];
        action = [
          {
            service = "notify.notify";
            data = {
              title = "Electricity Peak";
              message = ''
                {% set electricity_delivery_power_15m = states('sensor.electricity_delivery_power_15m') | float(0) %}
                {% set electricity_delivery_power_15m_estimated = states('sensor.electricity_delivery_power_15m_estimated') | float(0) %}
                {% set currently_delivered = states('sensor.dsmr_reading_electricity_currently_delivered') | float(0) * 1000 %}
                {% set minutes_remaining = (now().minute // 15 + 1) * 15 - now().minute %}
                {% set battery = states('sensor.solis_remaining_battery_capacity') %}
                {% set overdischargesoc = states('number.solar_battery_overdischargesoc') %}
                Currently at capacity peak {{ electricity_delivery_power_15m }}kW, estimated to be {{ electricity_delivery_power_15m_estimated }}kW with {{ minutes_remaining }}m remaining, current power {{ currently_delivered }}W, battery at {{battery}} ({{overdischargesoc}})%.
              '';
            };
          }
          (ha.action.delay "00:01:00")
        ];
        mode = "single";
      }
      {
        id = "electricity_delivery_power_max_threshold_light";
        alias = "electricity_delivery_power_max_threshold.light";
        trigger = [
          {
            platform = "numeric_state";
            entity_id = "sensor.electricity_delivery_power_15m_estimated";
            above = "2.4";
          }
        ];
        condition = [];
        action = [
          {
            service = "light.turn_on";
            target.entity_id = "light.floor0_keuken_light_consumptionindicator";
            data = {
              rgb_color = [255 0 0];
              effect = "blink";
              transition = 10;
            };
          }
        ];
        mode = "single";
      }
      {
        id = "electricity_delivery_power_near_max_threshold_light";
        alias = "electricity_delivery_power_near_max_threshold.light";
        trigger = [
          {
            platform = "numeric_state";
            entity_id = "sensor.electricity_delivery_power_15m_estimated";
            above = "1.9";
          }
        ];
        condition = [];
        action = [
          {
            service = "light.turn_on";
            target.entity_id = "light.floor0_keuken_light_consumptionindicator";
            data = {
              rgb_color = [255 200 0];
              effect = "blink";
              transition = 10;
            };
          }
        ];
        mode = "single";
      }
      {
        id = "electricity_delivery_power_normal_light";
        alias = "electricity_delivery_power_normal.light";
        trigger = [
          {
            platform = "numeric_state";
            entity_id = "sensor.electricity_delivery_power_15m_estimated";
            below = "1.8";
          }
        ];
        condition = [];
        action = [
          {
            service = "light.turn_off";
            target.entity_id = "light.floor0_keuken_light_consumptionindicator";
          }
        ];
        mode = "single";
      }
      
    ];

    recorder = {
      include = {
        

        entity_globs = [
                    
        ];
      };
    };

  };
}

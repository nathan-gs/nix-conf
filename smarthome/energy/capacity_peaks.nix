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
              {% set current_power = (states('sensor.electricity_grid_consumed_power_avg_1m') | float(states('sensor.electricity_grid_consumed_power') | float(0))) / 1000 %}
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
              {# vaatwas #}
              {% set dishwasher_remaining_time = states('sensor.dishwasher_remaining_time') | int(0) %}
              {% set is_dishwasher_on = states('binary_sensor.dishwasher_status') | bool(false) %}
              {% if is_dishwasher_on and dishwasher_remaining_time > 75 %}
                {% set is_high = true %}
              {% endif %}
              {# Wasmachine #}
              {% set wasmachine_cycle = states('sensor.aeg_wasmachine_wm1_cyclephase') | string %}
              {% if wasmachine_cycle == "Washing" %}
                {% set is_high = true %}
              {% endif %}
              {# oven #}
              {% set oven_on = states('sensor.floor0_keuken_metering_plug_oven_power') | int(0) > 20 %}
              {% if oven_on %}
                {% set is_high = true %}
              {% endif %}
              {# Airfryer #}
              {% set airfryer_on = states('sensor.floor0_keuken_metering_plug_airfryer_power') | int(0) > 20 %}
              {% if airfryer_on %}
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
              {% set battery_charging = 5 <= now().hour < 7 %}
              {% if battery_charging %}
                {% set is_high = true %}
              {% endif %}
              {{ is_high }}
            '';
          }
        ];
      }
      {
        binary_sensor = [
          {
            name = "electricity_delivery_power_max_threshold";
            state = ''
              {% set electricity_delivery_power_15m_estimated = states('sensor.electricity_delivery_power_15m_estimated') | float(0) %}
              {{ electricity_delivery_power_15m_estimated > 2.45 }}
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

    sensor = [
      {
        platform = "statistics";
        name = "electricity_grid_consumed_power_avg_1m";
        entity_id = "sensor.electricity_grid_consumed_power";
        state_characteristic = "average_linear";
        max_age.minutes = 1;
        sampling_size = 60;
        keep_last_sample = true;
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
                Currently at capacity peak {{ electricity_delivery_power_15m }}kW, estimated to be {{ electricity_delivery_power_15m_estimated }}kW with {{ minutes_remaining }}m remaining, current power {{ currently_delivered }}W
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
            platform = "state";
            entity_id = "binary_sensor.electricity_delivery_power_max_threshold";
            to = "on";
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
            platform = "state";
            entity_id = "binary_sensor.electricity_delivery_power_near_max_threshold";
            to = "on";
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
            platform = "state";
            entity_id = "binary_sensor.electricity_delivery_power_near_max_threshold";
            to = "off";
          }
        ];
        condition = [];
        action = [
          {
            service = "light.turn_off";
            target.entity_id = "light.floor0_keuken_light_consumptionindicator";
            data = {              
            };
          }
        ];
        mode = "single";
      }
    ];

  };
}

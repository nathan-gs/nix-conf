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
          {
            name = "solar/battery/overdischargesoc_target";
            unit_of_measurement = "%";
            device_class = "battery";
            state = ''
              {% set power15m = states('sensor.electricity_delivery_power_15m') | float(0) %}
              {% set power15m_estimated = states('sensor.electricity_delivery_power_15m_estimated') | float(0) %}
              {% set overdischargesoc = states('number.solar_battery_overdischargesoc') | int(20) %}
              {% set car_charger_on = states('sensor.car_charger_power') | int(0) > 20 %}
              {% set overdischargesoc_default = 25 %}
              {% set overdischargesoc_with_car_charger_on = 40 %}
              {% set overdischarge_min = 8 %}
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
              {% if (power15m > 2.0) and (power15m_estimated > 2.45) %}
                {{ overdischarge_min }}
              {# If car charging #}
              {% elif car_charger_on %}
                {{ overdischargesoc_with_car_charger_on }}
              {% else %}
                {{ overdischargesoc_default }}
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
              {% set is_solar_left = ((states('sensor.energy_production_today_remaining') | float(0) > 1) and now().hour >= 5) %}
              {% set forcechargesoc = states('number.solar_battery_forcechargesoc') | int(10) %}
              {% set is_offpeak = states('binary_sensor.electricity_is_offpeak') | bool(false) %}
              {% set forcechargesoc_high = 20 %}
              {% set forcechargesoc_low = 15 %}
              {% set overdischarge_min = 8 %}

              {% if is_solar_left %}
                {% set forcechargesoc_target = forcechargesoc_low %}
              {% elif is_offpeak %}
                {% set forcechargesoc_target = forcechargesoc_high %}
              {% else %}
                {% set forcechargesoc_target = forcechargesoc_low %}
              {% endif %}

              {% if (power15m < 1.5) and (power15m_estimated < 1.5) %}
                {{ forcechargesoc_target }}
              {% elif (power15m_estimated > 2) %}
                {{ overdischarge_min }}
              {% else %}
                {{ forcechargesoc }}
              {% endif %}
            '';
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
      (ha.automation "solar/battery/overdischarge.control" {
        triggers = [(ha.trigger.state "sensor.solar_battery_overdischargesoc_target")];
        actions = [
          (ha.action.set_value "number.solar_battery_overdischargesoc" ''{{ states('sensor.solar_battery_overdischargesoc_target') | int }}'')
        ];
        mode = "queued";
      })
      (ha.automation "solar/battery/forcechargesoc.control" {
        triggers = [(ha.trigger.state "sensor.solar_battery_forcechargesoc_target")];
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
          "number.solar_*"          
        ];
      };
    };

  };
}

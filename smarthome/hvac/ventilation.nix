{ config, pkgs, lib, ha, ... }:
{

  services.home-assistant.config = {

    template = [
      {
        trigger = [
          {
            trigger = "state";
            entity_id = [
              "binary_sensor.anyone_home"
              "input_boolean.floor0_wc_in_use"
              "sensor.indoor_dewpoint"
              "sensor.indoor_temperature"
              "sensor.outdoor_temperature"
              "binary_sensor.itho_wtw_bypass"
              "sensor.weather_tomorrow_temperature_max"
              "sensor.outdoor_dewpoint"
              "sensor.indoor_humidity_max"
              "binary_sensor.electricity_delivery_power_max_threshold"
              "binary_sensor.house_co2_high"
              "binary_sensor.wtw_high_cooldown"
            ];
          }
        ];
        variables = {
          is_home = ''{{ states('binary_sensor.anyone_home') | bool(true) }}'';
          is_cooking = ''{{ false }}'';
          is_using_sanitary = ''{{ states('input_boolean.floor0_wc_in_use') | bool(false) }}'';
          dewpoint_high = ''{{ states('sensor.indoor_dewpoint') | float(15.0) > 15.0 }}'';
          indoor_temperature = ''{{ states('sensor.indoor_temperature') | float(19) }}'';
          outdoor_temperature = ''{{ states('sensor.outdoor_temperature') | float(19) }}'';
          house_needs_cooling = ''{{ states('sensor.indoor_temperature') | float(19) > 23.5 }}'';
          bypass = ''{{ states('binary_sensor.itho_wtw_bypass') | bool(false) }}'';
          tomorrow_max_temp = ''{{ states('sensor.weather_tomorrow_temperature_max') | float(30) }}'';
          mild_day_ahead_and_house_still_cool = ''{{ states('sensor.weather_tomorrow_temperature_max') | float(30) <= 25 and states('sensor.indoor_temperature') | float(19) < 23 }}'';
          house_needs_cooling_and_temp_outside_lower = ''{{ (states('binary_sensor.itho_wtw_bypass') | bool(false)) and (states('sensor.indoor_temperature') | float(19) > 23.5) and (states('sensor.outdoor_temperature') | float(19) + 2.5) < states('sensor.indoor_temperature') | float(19) and not (states('sensor.weather_tomorrow_temperature_max') | float(30) <= 25 and states('sensor.indoor_temperature') | float(19) < 23) }}'';
          dewpoint_outdoor_smaller_then_indoor = ''{{ (states('sensor.outdoor_dewpoint') | float + 1) < (states('sensor.indoor_dewpoint') | float) }}'';
          dewpoint_high_and_dewpoint_outdoor_lower = ''{{ ((states('sensor.indoor_dewpoint') | float(15.0) > 15.0) and ((states('sensor.outdoor_dewpoint') | float + 1) < (states('sensor.indoor_dewpoint') | float))) | bool }}'';
          humidity_max_over_80 = ''{{ states('sensor.indoor_humidity_max') | float(100) > 80 }}'';
          electricity_delivery_power_near_max_threshold = ''{{ states('binary_sensor.electricity_delivery_power_max_threshold') | bool(false) }}'';
          is_not_electricity_delivery_power_max_threshold = ''{{ not (states('binary_sensor.electricity_delivery_power_max_threshold') | bool(false)) }}'';
          is_hot_outside = ''{{ states('sensor.outdoor_temperature') | float(19) > 27 }}'';
          is_high_co2 = ''{{ is_state('binary_sensor.house_co2_high', 'on') }}'';
          cooldown = ''{{ is_state('binary_sensor.wtw_high_cooldown', 'on') }}'';
        };
        sensor = [
          {
            name = "wtw_target_fan";
            unique_id = "wtw_target_fan";
            state = ''
              {% if is_not_electricity_delivery_power_max_threshold %}
                {% if house_needs_cooling_and_temp_outside_lower %}
                  high
                {% elif is_hot_outside %}
                  {% if (humidity_max_over_80 or is_high_co2 or is_using_sanitary) and not cooldown %}
                    high
                  {% else %}
                    low
                  {% endif %}
                {% elif cooldown %}
                  medium
                {% elif humidity_max_over_80 or is_high_co2 %}
                  high
                {% elif is_cooking or is_using_sanitary %}
                  high
                {% elif dewpoint_high_and_dewpoint_outdoor_lower %}
                  high
                {% elif is_home %}
                  medium
                {% else %}
                  low
                {% endif %}
              {% else %}
                low
              {% endif %}
            '';
            attributes = {
              is_cooking = ''{{ is_cooking }}'';
              is_home = ''{{ is_home }}'';
              is_using_sanitary = ''{{ is_using_sanitary }}'';
              dewpoint_high_and_dewpoint_outdoor_lower = ''{{ dewpoint_high_and_dewpoint_outdoor_lower }}'';
              humidity_max_over_80 = ''{{ humidity_max_over_80 }}'';
              house_needs_cooling_and_temp_outside_lower = ''{{ house_needs_cooling_and_temp_outside_lower }}'';
              is_hot_outside = ''{{ is_hot_outside }}'';
              electricity_delivery_power_near_max_threshold = ''{{ electricity_delivery_power_near_max_threshold }}'';
              icon = ''
                {% set am = states('sensor.wtw_target_fan') %}
                {% if am == "low" %}
                  mdi:fan-speed-1
                {% elif am == "medium" %}
                  mdi:fan-speed-2
                {% elif am == "high" %}
                  mdi:fan-speed-3
                {% else %}
                  mdi:fan
                {% endif %}
              '';
            };
          }
        ];
      }
      {
        sensor = [
          (
            ha.sensor.max_from_list "house/co2/max"
              (
                map(v: "states('${v}')") 
                [
                  "sensor.floor0_bureau_switchbot_carbon_dioxide"
                  "sensor.floor0_living_switchbot_carbon_dioxide"
                  "sensor.floor1_fen_switchbot_carbon_dioxide"
                ]
              )
              {
                unit_of_measurement = "ppm";
                device_class = "carbon_dioxide";
                icon = ''
                  {% if states('sensor.house_co2_max') | float(100) > 100 %}
                    mdi:molecule-co2
                  {% else %}
                    mdi:molecule-co2
                  {% endif %}
                '';
              }
          )
          (
            ha.sensor.temperature "itho_wtw_inlet_temperature_correction" 
            ''
              {% set raw = states('sensor.itho_wtw_inlet_temperature_raw') | float(0) %}
              {% set outdoor = states('sensor.outdoor_temperature') | float(0) %}
              {% set prev = states('sensor.itho_wtw_inlet_temperature_correction') | float(none) %}
              {% if outdoor > 0.5 %}
                {{ (outdoor - raw) | round(2) }}
              {% else %}
                {% if prev is not none %}
                  {{ prev | round(2) }}
                {% else %}
                  {{ (raw - 15.0) | round(2) }}
                {% endif %}
              {% endif %}
            ''
          )
        ];
      }
      {
        trigger = [
          {
            trigger = "numeric_state";
            entity_id = "sensor.house_co2_max";
            above = 1000;
          }
        ];
        binary_sensor = [
          {
            name = "house/co2/high";
            unique_id = "house_co2_high";
            state = ''{{ states('sensor.house_co2_max') | int(700) >= 1000 }}'';
            auto_off.minutes = 15;
            device_class = "safety";
          }
        ];
      }
      {
        # Caps non-cooling "high" runs: when wtw_target_fan stays high for 10
        # minutes, this flips on for 20 minutes, during which the target
        # template downgrades non-cooling high requests to medium. Cooling
        # clauses (bypass + outside cooler, or dewpoint-driven) bypass the
        # cooldown and stay high.
        trigger = [
          {
            trigger = "state";
            entity_id = "sensor.wtw_target_fan";
            to = "high";
            for.minutes = 10;
          }
        ];
        binary_sensor = [
          {
            name = "wtw_high_cooldown";
            unique_id = "wtw_high_cooldown";
            state = "true";
            auto_off.minutes = 20;
          }
        ];
      }
    ];

    "automation manual" = [
      {
        id = "itho_wtw_target";
        alias = "itho_wtw_target";
        trigger = [
          {
            platform = "state";
            entity_id = "sensor.wtw_target_fan";
            for.minutes = 1;
          }
        ];
        # Leave the WTW alone while a fire alarm is active - it is powered down on
        # purpose, so that smoke is not distributed to the bedrooms. See
        # smarthome/air_quality/fire_alarm.nix and docs/fire-alarms.md.
        condition = [
          {
            condition = "state";
            entity_id = "input_boolean.fire_alarm_active";
            state = "off";
          }
        ];
        action = [
          {
            service = "fan.set_preset_mode";
            data = {
              preset_mode = ''{{ states('sensor.wtw_target_fan') }}'';
            };
            target = {
              entity_id = "fan.itho_wtw_fan";
            };
          }
        ];
        mode = "queued";
      }
    ];

    mqtt = {
      fan = [
        {
          name = "itho_wtw_fan";
          unique_id = "itho_wtw_fan";
          state_topic = "itho/lwt";
          state_value_template = "{% if value == 'online' %}ON{% else %}OFF{% endif %}";
          command_topic = "itho/cmd";
          preset_mode_state_topic = "itho/ithostatus";
          preset_mode_command_template = "{ vremote: '{{ value }}'}";
          preset_mode_value_template = ''
            {% set am = value_json['Actual Mode'] | int %}
            {% if am == 1 %}
              low
            {% elif am == 2 %}
              medium 
            {% elif am == 3 %}
              high
            {% elif am == 13 %}
               timer
            {% elif am == 24 %}
              auto
            {% elif am == 25 %}
              autonight
            {% else %}
              {{ am }}
            {% endif %}
          '';
          preset_mode_command_topic = "itho/cmd";
          preset_modes = [
            "low"
            "medium"
            "high"
            "auto"
            "autonight"
            "timer1"
            "timer2"
            "timer3"
            "timer"
          ];
          # icon_template = ''
          #   {% set am = value_json['Actual Mode'] | int %}
          #   {% if am == 1 %}
          #      mdi:fan-speed-1
          #    {% elif am == 2 %}
          #      mdi:fan-speed-2
          #    {% elif am == 3 %}
          #      mdi:fan-speed-3
          #    {% else %}
          #      mdi:fan
          #    {% endif %}
          # '';
          icon = "mdi:fan";
        }
      ];

      binary_sensor = [
        {
          name = "itho_wtw_bypass";
          state_topic = "itho/ithostatus";
          value_template = "{{ value_json['Bypass position'] }}";
          unique_id = "itho_wtw_bypass_status";
          device_class = "opening";
          payload_on = "1";
          payload_off = "0";
          icon = "mdi:valve";
          # icon_template = ''
          #   {% if value_json['Bypass position'] | int == 1 %}
          #      mdi:valve-open
          #   {% else %}
          #      mdi:valve-closed
          #   {% endif %}
          # '';
        }
        {
          name = "itho_wtw_valve";
          state_topic = "itho/ithostatus";
          value_template = "{{ value_json['Valve position'] }}";
          unique_id = "itho_wtw_valve_status";
          device_class = "opening";
          payload_on = "1";
          payload_off = "0";
          icon = "mdi:valve";
        }
        {
          name = "itho_wtw_is_summerday";
          state_topic = "itho/ithostatus";
          value_template = "{{ value_json['Summerday (K_min)'] }}";
          unique_id = "itho_wtw_is_summerday";
          payload_on = "1";
          payload_off = "0";
          icon = "mdi:weather-sunny";
          # icon_template = ''
          #   {% if value_json['Summerday (K_min)'] | int == 1 %}
          #      mdi:weather-sunny
          #   {% else %}
          #      mdi:weather-sunny-off
          #   {% endif %}
          # '';
        }
      ];

      sensor = [
        {
          name = "itho_wtw_inlet_fan";
          state_topic = "itho/ithostatus";
          value_template = "{{ value_json['Supply fan actual (RPM)'] }}";
          unit_of_measurement = "rpm";
          unique_id = "itho_wtw_inlet_fan";
          state_class = "measurement";
          icon = "mdi:fan-chevron-down";
        }
        {
          name = "itho_wtw_outlet_fan";
          state_topic = "itho/ithostatus";
          value_template = "{{ value_json['Exhaust fan actual (RPM)'] }}";
          unit_of_measurement = "rpm";
          unique_id = "itho_wtw_outlet_fan";
          state_class = "measurement";
          icon = "mdi:fan-chevron-up";
        }
        {
          name = "itho_wtw_inlet_temperature";
          state_topic = "itho/ithostatus";
          # Correction based on: https://chatgpt.com/c/6741c1b6-0cf4-800a-a77b-38ffac6e98c6
          #value_template = ''            
          #  {% set raw = value_json['Outdoor temp (°C)'] | float %}
          #  {#{{ (0.84 * raw - 1.85) | round(2) }}#}
          #  {% set correction = states('sensor.itho_wtw_inlet_temperature_correction') | float(-13) %}
          #  {{ ((raw + correction) - 0.5) | round(2) }}
          #'';
          value_template = ''            
            {% set raw = value_json['Outdoor temp (°C)'] | float %}
            {{ raw }}
          '';
          unit_of_measurement = "°C";
          unique_id = "itho_wtw_inlet_temperature";
          state_class = "measurement";
          device_class = "temperature";
          icon = "mdi:thermometer-chevron-down";
        }
        {
          name = "itho_wtw_inlet_temperature_raw";
          state_topic = "itho/ithostatus";
          value_template = ''            
            {% set raw = value_json['Outdoor temp (°C)'] | float %}
            {{ raw }}
          '';
          unit_of_measurement = "°C";
          unique_id = "itho_wtw_inlet_temperature_raw";
          state_class = "measurement";
          device_class = "temperature";
          icon = "mdi:thermometer-chevron-down";
        }
        {
          name = "itho_wtw_outlet_temperature";
          state_topic = "itho/ithostatus";
          value_template = ''
            {{ value_json['Room temp (°C)'] | float }}            
          '';
          unit_of_measurement = "°C";
          unique_id = "itho_wtw_outlet_temperature";
          state_class = "measurement";
          icon = "mdi:thermometer-chevron-up";
          device_class = "temperature";
        }
        {
          name = "itho_wtw_outlet_temperature_raw";
          state_topic = "itho/ithostatus";
          value_template = ''
            {{ value_json['Room temp (°C)'] | float }}            
          '';
          unit_of_measurement = "°C";
          unique_id = "itho_wtw_outlet_temperature_raw";
          state_class = "measurement";
          icon = "mdi:thermometer-chevron-up";
          device_class = "temperature";
        }
        {
          name = "itho_wtw_airfilter";
          state_topic = "itho/ithostatus";
          value_template = "{{ value_json['Airfilter counter'] }}";
          unit_of_measurement = "h";
          unique_id = "itho_wtw_airfilter";
          state_class = "measurement";
          icon = "mdi:air-filter";
        }
        {
          name = "itho_wtw_actual_mode";
          state_topic = "itho/ithostatus";
          value_template = ''
            {% set am = value_json['Actual Mode'] | int %}
            {% if am == 1 %}
               low
             {% elif am == 2 %}
               medium 
             {% elif am == 3 %}
               high
            {% elif am == 25 %}
              autonight
             {% elif am == 24 %}
               auto
             {% else %}
               {{ am }}
             {% endif %}
          '';
          unique_id = "itho_wtw_actual_mode";
          icon = "mdi:fan";
          # icon_template = ''
          #   {% set am = value_json['Actual Mode'] | int %}
          #   {% if am == 1 %}
          #      mdi:fan-speed-1
          #    {% elif am == 2 %}
          #      mdi:fan-speed-2
          #    {% elif am == 3 %}
          #      mdi:fan-speed-3
          #    {% else %}
          #      mdi:fan
          #    {% endif %}
          # '';
        }
      ];
    };
    
  };

}

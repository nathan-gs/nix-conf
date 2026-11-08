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
              "binary_sensor.house_co2_boost"
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
          is_high_co2 = ''{{ is_state('binary_sensor.house_co2_boost', 'on') or is_state('binary_sensor.house_co2_high', 'on') }}'';
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
              {# The pre-heater sits upstream of the Itho's intake NTC, so
                 while it runs (and while the duct cools down after) the
                 Itho reads heated air. Learning from that would inflate
                 the offset, raise the frost setpoint written back by
                 itho_temperature_offset.nix and run the heater longer: a
                 positive feedback loop. Hold the last value instead. #}
              {% set heater = states.switch.system_wtw_metering_plug_verwarming %}
              {% set heater_quiet = heater is not none and heater.state == 'off'
                   and (now() - heater.last_changed).total_seconds() > 900 %}
              {% if outdoor > 0.5 and heater_quiet %}
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
        # One stuffy episode per rise through 1000 ppm. It stays latched
        # until the house maximum falls under 900, so a bureau hovering
        # around 980–1050 does not count as a new episode.
        trigger = [
          {
            trigger = "numeric_state";
            entity_id = "sensor.house_co2_max";
            above = 1000;
          }
          {
            trigger = "numeric_state";
            entity_id = "sensor.house_co2_max";
            below = 900;
          }
        ];
        binary_sensor = [
          {
            name = "house/co2/episode";
            unique_id = "house_co2_episode";
            state = ''{{ states('sensor.house_co2_max') | float(0) >= 1000 }}'';
          }
        ];
      }
      {
        # The first response to an episode: high for 40 minutes, then
        # medium, even if CO2 is still between 1000 and 1200. A new episode
        # (CO2 fell under 900, then crossed 1000 again) may boost once more.
        trigger = [
          {
            id = "start";
            trigger = "state";
            entity_id = "binary_sensor.house_co2_episode";
            to = "on";
          }
          {
            id = "stop";
            trigger = "state";
            entity_id = "binary_sensor.house_co2_episode";
            to = "off";
          }
        ];
        binary_sensor = [
          {
            name = "house/co2/boost";
            unique_id = "house_co2_boost";
            state = ''{{ trigger.id == 'start' }}'';
            auto_off.minutes = 40;
          }
        ];
      }
      {
        # Repeating high/medium cycles are only for a house maximum that
        # has reached 1200 ppm. Below that, house_co2_boost is the one
        # 40-minute attempt.
        binary_sensor = [
          {
            name = "house/co2/high";
            unique_id = "house_co2_high";
            state = ''{{ states('sensor.house_co2_max') | float(0) >= 1200 }}'';
            device_class = "safety";
          }
        ];
      }
      {
        # Duty-cycles a non-cooling "high". After wtw_target_fan has been
        # high for 40 minutes this stays on for 20, and the template above
        # drops the target to medium. When it releases, a still-on
        # house_co2_high (CO2 at or above 1200) starts another 40 minutes
        # on high. The one-shot 1000 ppm boost has already turned off by
        # then, so it does not. Cooling (bypass and outside cooler) is
        # decided before this and stays high.
        trigger = [
          {
            trigger = "state";
            entity_id = "sensor.wtw_target_fan";
            to = "high";
            for.minutes = 40;
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
          # The Itho's intake NTC reads ~2-3 °C warm (it picks up heat from
          # the unit; more so in the cold). Corrected with the smoothed
          # offset from itho_temperature_offset.nix. Anything that must be
          # compared against the Itho's own setpoints uses _raw instead.
          value_template = ''
            {% set raw = value_json['Outdoor temp (°C)'] | float %}
            {% set offset = states('sensor.itho_wtw_inlet_temperature_offset') | float(0) %}
            {{ (raw + offset) | round(2) }}
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

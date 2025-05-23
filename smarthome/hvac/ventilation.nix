{ config, pkgs, lib, ha, ... }:
{

  services.home-assistant.config = {

    template = [
      {
        sensor = [
          {
            name = "wtw_target_fan";
            state = ''
              {% set is_home = states('binary_sensor.anyone_home') | bool(true) %}
              {% set is_cooking = false %}
              {% set is_using_sanitary = states('input_boolean.floor0_wc_in_use') | bool(false) %}
              {% set dewpoint_high = (states('sensor.indoor_dewpoint') | float(15.0) > 15.0) %}
              {% set indoor_temperature = states('sensor.indoor_temperature') | float(19) %}
              {% set outdoor_temperature = states('sensor.outdoor_temperature') | float(19) %}
              {% set house_needs_cooling = indoor_temperature > 22 %}
              {% set house_needs_cooling_and_temp_outside_lower = false %}
              {% set bypass = states('binary_sensor.itho_wtw_bypass') | bool(false) %}
              {% if bypass and house_needs_cooling and (outdoor_temperature + 2.5) < indoor_temperature %}
                {% set house_needs_cooling_and_temp_outside_lower = true %}
              {% endif %}
              {% set dewpoint_outdoor_smaller_then_indoor = ((states('sensor.outdoor_dewpoint') | float) +1) < (states('sensor.indoor_dewpoint') | float) %}
              {% set dewpoint_high_and_dewpoint_outdoor_lower = (dewpoint_high and dewpoint_outdoor_smaller_then_indoor) | bool %}
              {% set humidity_max_over_80 = (states('sensor.indoor_humidity_max') | float(100) > 80) %}
              {% set is_not_electricity_delivery_power_max_threshold = states('binary_sensor.electricity_delivery_power_max_threshold') | bool(false) == false %}
              {% set is_hot_outside = outdoor_temperature > 27 %}
              {% set is_high_co2 = is_state('binary_sensor.house_co2_high', 'on') %}
              {% if is_not_electricity_delivery_power_max_threshold %}
                {% if humidity_max_over_80 or is_high_co2 %}
                  high
                {% elif is_cooking or is_using_sanitary %}
                  high
                {% elif is_hot_outside %}
                  low
                {% elif dewpoint_high_and_dewpoint_outdoor_lower or house_needs_cooling_and_temp_outside_lower %}
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
              is_cooking = ''false'';
              is_home = ''{{ states('binary_sensor.anyone_home') | bool(true) }}'';
              is_using_sanitary = ''
                {{ states('input_boolean.floor0_wc_in_use') | bool(false) }}
              '';
              dewpoint_high_and_dewpoint_outdoor_lower = ''
                {% set dewpoint_over_17 = (states('sensor.indoor_dewpoint') | float(15.0) > 15.0) %}
                {% set dewpoint_outdoor_smaller_then_indoor = ((states('sensor.outdoor_dewpoint') | float) +1) < (states('sensor.indoor_dewpoint') | float) %}
                {{ (dewpoint_over_17 and dewpoint_outdoor_smaller_then_indoor) | bool }}
              '';
              humidity_max_over_80 = ''{{ (states('sensor.indoor_humidity_max') | float(100) > 80) }}'';
              house_needs_cooling_and_temp_outside_lower = ''
                {% set bypass = states('binary_sensor.itho_wtw_bypass') | bool(false) %}
                {% set indoor_temperature = states('sensor.indoor_temperature') | float(19) %}
                {% set outdoor_temperature = states('sensor.outdoor_temperature') | float(19) %}
                {% set house_needs_cooling = indoor_temperature > 22 %}
                {% set house_needs_cooling_and_temp_outside_lower = false %}
                {% if bypass and house_needs_cooling and (outdoor_temperature + 2.5) < indoor_temperature %}
                  {% set house_needs_cooling_and_temp_outside_lower = true %}
                {% endif %}
                {{ house_needs_cooling_and_temp_outside_lower }}
              '';
              is_hot_outside = ''
                {% set is_hot_outside = states('sensor.outdoor_temperature') | float(19) > 27 %}
                {{ is_hot_outside }}
              '';
              electricity_delivery_power_near_max_threshold = ''{{ states('binary_sensor.electricity_delivery_power_max_threshold') | bool(false) }}'';
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
        ];
      }
      {
        binary_sensor = [
          {
            name = "house/co2/high";
            state = ''{{ states('sensor.house_co2_max') | int(700) >= 1000 }}'';
            auto_off.minutes = 15;
            device_class = "safety";
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
          value_template = "{{ value_json['Supply fan (RPM)'] }}";
          unit_of_measurement = "rpm";
          unique_id = "itho_wtw_inlet_fan";
          state_class = "measurement";
          icon = "mdi:fan-chevron-down";
        }
        {
          name = "itho_wtw_outlet_fan";
          state_topic = "itho/ithostatus";
          value_template = "{{ value_json['Exhaust fan (RPM)'] }}";
          unit_of_measurement = "rpm";
          unique_id = "itho_wtw_outlet_fan";
          state_class = "measurement";
          icon = "mdi:fan-chevron-up";
        }
        {
          name = "itho_wtw_inlet_temperature";
          state_topic = "itho/ithostatus";
          # Correction based on: https://chatgpt.com/c/6741c1b6-0cf4-800a-a77b-38ffac6e98c6
          value_template = ''            
            {% set raw = value_json['Outdoor temp (°C)'] | float %}
            {#{{ (0.84 * raw - 1.85) | round(2) }}#}
            {% set correction = -5 %}
            {{ (raw + correction) | round(2) }}
          '';
          unit_of_measurement = "°C";
          unique_id = "itho_wtw_inlet_temperature";
          state_class = "measurement";
          device_class = "temperature";
          icon = "mdi:thermometer-chevron-down";
        }{
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
    recorder = {
      include = {
        entities = [
          "binary_sensor.itho_wtw_bypass"
          "binary_sensor.itho_wtw_is_summerday"
          "binary_sensor.itho_wtw_valve"
          "sensor.itho_wtw_actual_mode"
          "sensor.wtw_target_fan"
          "switch.system_wtw_metering_plug_verwarming"
          "binary_sensor.house_co2_high"
          "sensor.house_co2_max"
        ];
        entity_globs = [
          "sensor.itho_wtw_inlet_*"
          "sensor.itho_wtw_outlet_*"
        ];

      };
      exclude = {
        entities = [
          "device_tracker.wtw_itho"
          "switch.wtw_itho_internet_access"
          "automation.itho_wtw_target"
          "fan.wtw_itho_fan"
        ];
        entity_globs = [
          "button.system_wtw_air_quality_*_identify"
        ];
      };
    };
  };

}

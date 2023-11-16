{ config, pkgs, lib, ... }:

let

  rooms = import ../rooms.nix;

  roomsDiffWanted = map (v: "states('sensor.${v}_temperature_diff_wanted')") rooms.heated;

  autoWantedHeader = import ./temperature_sets.nix;

in
{

  services.home-assistant.config = {

    template = [
      {
        sensor = [
          {
            name = "heating_temperature_diff_wanted";
            unit_of_measurement = "°C";
            device_class = "temperature";
            state = ''
              {% 
              set v = (
                ${builtins.concatStringsSep "," roomsDiffWanted}
              )
              %}
              {% set valid_temp = v | select('!=','unknown') | map('float') | list %}
              {{ max(valid_temp) | round(2) }}
            '';
            icon = "mdi:thermometer-auto";
          }
          {
            name = "heating_temperature_desired";
            unit_of_measurement = "°C";
            device_class = "temperature";
            state = ''
              ${autoWantedHeader}
              {% set cv_temp = state_attr("climate.cv", "temperature") | float(15.5) %}
              {% set current_temp = state_attr("climate.cv", "current_temperature") | float(19.5) %}
              {% set temperature_diff_wanted = states("sensor.heating_temperature_diff_wanted") | float(0) %}
              {% set max_desired_temp = 21 %}
              {% set target_temp = current_temp + temperature_diff_wanted %}
              {% set new_temp = cv_temp %}
              {% set is_anyone_home_or_coming = states('binary_sensor.anyone_home_or_coming_home') | bool(true) %}
              {% set is_travelling = states('binary_sensor.far_away') | bool(false) %}
              {% set forecast_temp = states('sensor.weather_forecast_temperature_max_4h') | float(15) %}
              {% set is_large_deviation_between_forecast_and_target = not ((forecast_temp + 2) >= target_temp and (forecast_temp - 3) <= target_temp) %}
              {% set is_heating_needed = target_temp >= current_temp %}
              {% if is_anyone_home_or_coming %}
                {% if is_heating_needed and is_large_deviation_between_forecast_and_target %}
                  {# Gradually increase temperature #}
                  {% set new_temp = (current_temp + 1) %}
                  {% set new_temp = min(new_temp, max_desired_temp, target_temp) %}
                {% else %}          
                  {% set new_temp = (target_temp - 0.5) %}
                  {% set new_temp = max(new_temp, temperature_eco) %}
                {% endif %}
              {% elif is_travelling %}
                {% set new_temp = temperature_minimal %}
              {% else %}
                {% set new_temp = temperature_away %}
              {% endif %}
              {% set new_temp = ((new_temp * 2) | round(0) / 2) %}
              {{ new_temp }}
            '';
            icon = ''
              {% if (state_attr("climate.cv", "current_temperature") | float(19.5)) < (states('sensor.heating_temperature_desired') | float(19.5)) %}
                mdi:thermometer-chevron-up
              {% else %}
                mdi:thermometer-chevron-down
              {% endif %}
            '';
          }
        ];
      }
      
    ];

    "automation manual" = [
      {
        id = "cv_temperature_set";
        alias = "cv.temperature_set";
        trigger = [
          {
            platform = "state";
            entity_id = "sensor.heating_temperature_desired";
          }
        ];
        condition = ''
          {{ 
            (states('sensor.heating_temperature_desired') | float(0) != state_attr('climate.cv', 'temperature') | float(0)) and ( states('climate.cv') == "heat" )
          }}
        '';
        action = [
          {
            service = "climate.set_temperature";
            target.entity_id = "climate.cv";
            data = {
              target_temp_high = "{{ states('sensor.heating_temperature_desired') | float(15.5) }}";
              target_temp_low = "10";
            };
          }
          {
            delay = "0:00:15";
          }
          # Workaround to update desired temperature
          {
            service = "mqtt.publish";
            data = {
              topic = "ebusd/370/DisplayedHc1RoomTempDesired/get";
              payload_template = "?1";
              retain = false;
            };
          }
          {
            delay = "0:00:05";
          }
          {
            service = "mqtt.publish";
            data = {
              topic = "ebusd/370/Hc1DayTemp/get";
              payload_template = "?1";
              retain = false;
            };
          }
        ];
        mode = "single";
      }
      {
        id = "cv_query";
        alias = "cv.query";
        trigger = [
          {
            platform = "time_pattern";
            minutes = "/5";
          }
        ];
        action = lib.lists.forEach [
          "ebusd/370/DisplayedHc1RoomTempDesired"
          "ebusd/370/DisplayedRoomTemp"
          "ebusd/bai/FlowTemp"
          "ebusd/bai/FlowTempDesired"
          "ebusd/bai/ReturnTemp"
          "ebusd/bai/ModulationTempDesired"
        ]
          (x: {
            service = "mqtt.publish";
            data = {
              topic = "${x}/get";
              payload_template = "?3";
              retain = false;
            };
          });
        mode = "single";
      }
    ];

    # https://fromeijn.nl/connected-vaillant-to-home-assistant/
    mqtt.climate = [
      {
        name = "CV";
        max_temp = 25;
        min_temp = 5.5;
        precision = 0.1;
        temp_step = 0.5;
        modes = [ "auto" "heat" "cool" "off" ];
        # Quite an ugly regex workaround due to 0 not being findable...
        mode_state_template = ''
          {% set values = { 'auto':'auto', 'on':'heat',  'night':'cool', 'summer':'off'} %}
          {% set v = value | regex_findall_index( '"value"\s?:\s?"(.*)"')  %}
          {{ values[v] if v in values.keys() else 'auto' }}
        '';
        mode_state_topic = "ebusd/370/Hc1OPMode";
        mode_command_template = ''
          {% set values = { 'auto':'auto', 'heat':'on',  'cool':'night', 'off':'summer'} %}
          {{ values[value] if value in values.keys() else 'off' }}
        '';
        mode_command_topic = "ebusd/370/Hc1OPMode/set";
        temperature_state_topic = "ebusd/370/DisplayedHc1RoomTempDesired";
        temperature_state_template = "{{ value_json.temp1.value }}";
        temperature_low_state_topic = "ebusd/370/Hc1NightTemp";
        temperature_low_state_template = "{{ value_json.temp1.value }}";
        temperature_high_state_topic = "ebusd/370/Hc1DayTemp";
        temperature_high_state_template = "{{ value_json.temp1.value }}";
        temperature_low_command_topic = "ebusd/370/Hc1NightTemp/set";
        temperature_low_command_template = ''
          {{ value }}
        '';
        temperature_high_command_topic = "ebusd/370/Hc1DayTemp/set";
        temperature_high_command_template = ''
          {{ value }}
        '';
        current_temperature_topic = "ebusd/370/DisplayedRoomTemp";
        current_temperature_template = "{{ value_json.temp.value }}";
        temperature_unit = "C";
      }
      {
        name = "boiler";
        max_temp = 90;
        min_temp = 0;
        precision = 0.1;
        temp_step = 0.5;
        # unfortunately mapping is not correct (Yet)
        modes = [ "off" "on" "auto" "party" "load" "holiday" ];
        mode_state_template = ''
          {% set values = { 0:'off', 1:'on',  2:'auto', 3:'autosunday', 4:'party', 5: 'load', 7: 'holiday'} %}
          {{ values[value] if value in values.keys() else 'auto' }}
        '';
        mode_state_topic = "ebusd/370/HwcOPMode";
        mode_command_template = ''
          {% set values = { 'off':0, 'on':1,  'auto':2, 'autosunday':3, 'party':4, 'load':5, 'holiday':7} %}
          {{ values[value] if value in values.keys() else 2 }}
        '';
        mode_command_topic = "ebusd/370/HwcOPMode/set";
        temperature_state_topic = "ebusd/370/HwcTempDesired";
        temperature_state_template = "{{ value_json.temp1.value }}";
        current_temperature_topic = "ebusd/370/DisplayedHwcStorageTemp";
        current_temperature_template = "{{ value_json.temp1.value }}";
        temperature_unit = "C";
      }
    ];

    recorder.exclude.entity_globs = [ ];
  };

}

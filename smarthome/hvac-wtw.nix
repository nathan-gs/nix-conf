{config, pkgs, ...}:

let
  aqSensors = [
    {      
      name = "inlet";
      ieee = "0xbc026efffea63649";
    }
    {      
      name = "to_house";
      ieee = "0x3425b4fffe974ccd";
    }
    {
      name = "outlet";
      ieee = "0x3425b4fffe970e3d";
    }
  ];

in
{

  scrape = [];

  template = [
    {
      sensor = [
        {
          name = "wtw_target_fan";
          state = ''
            {% set is_home = states('binary_sensor.is_anyone_home') | bool(true) %}
            {% set is_cooking = false %}
            {% set is_using_sanitary = false %}
            {% set dewpoint_over_17 = (states('sensor.indoor_dewpoint') | float(17.0) > 17.0) %}
            {% set is_using_dryer = (states('sensor.floor1_waskot_metering_plug_droogkast_power') | float(0) > 100)  %}
            {% set indoor_temperature = states('sensor.indoor_temperature') | float(19) %}
            {% set outdoor_temperature = states('sensor.garden_garden_temperature_noordkant_temperature') | float(19) %}
            {% set house_needs_cooling = indoor_temperature > 25 %}
            {% set house_needs_cooling_and_temp_outside_lower = false %}
            {% if house_needs_cooling and outdoor_temperature < indoor_temperature %}
              {% set house_needs_cooling_and_temp_outside_lower = true %}
            {% endif %}
            {% set dewpoint_outdoor_smaller_then_indoor = ((states('sensor.outdoor_dewpoint') | float) +1) < (states('sensor.indoor_dewpoint') | float) %}
            {% set dewpoint_over_17_and_dewpoint_outdoor_lower = (dewpoint_over_17 and dewpoint_outdoor_smaller_then_indoor) | bool %}
            {% set humidity_max_over_80 = (states('sensor.indoor_humidity_max') | float(100) > 80) %}

            {% if is_cooking or is_using_sanitary or dewpoint_over_17_and_dewpoint_outdoor_lower or is_using_dryer or house_needs_cooling_and_temp_outside_lower or humidity_max_over_80 %}
              high
            {% elif is_home %}
              medium
            {% else %}
              low
            {% endif %}
          '';
          attributes = {
            is_cooking = ''false'';
            is_home = ''{{ states('binary_sensor.is_anyone_home') | bool(true) }}'';
            is_using_sanitary = ''false'';
            is_using_dryer = ''{{ (states('sensor.floor1_waskot_metering_plug_droogkast_power') | float(0) > 100) }}'';
            dewpoint_over_17_and_dewpoint_outdoor_lower = ''
              {% set dewpoint_over_17 = (states('sensor.indoor_dewpoint') | float(17.0) > 17.0) %}
              {% set dewpoint_outdoor_smaller_then_indoor = ((states('sensor.outdoor_dewpoint') | float) +1) < (states('sensor.indoor_dewpoint') | float) %}
              {{ (dewpoint_over_17 and dewpoint_outdoor_smaller_then_indoor) | bool }}
            '';
            humidity_max_over_80 = ''{{ (states('sensor.indoor_humidity_max') | float(100) > 80) }}'';
            house_needs_cooling_and_temp_outside_lower = ''
              {% set indoor_temperature = states('sensor.indoor_temperature') | float %}
              {% set outdoor_temperature = states('sensor.garden_garden_temperature_noordkant_temperature') | float %}
              {% set house_needs_cooling = indoor_temperature > 25 %}
              {% set house_needs_cooling_and_temp_outside_lower = false %}
              {% if house_needs_cooling and outdoor_temperature < indoor_temperature %}
                {% set house_needs_cooling_and_temp_outside_lower = true %}
              {% endif %}
              {{ house_needs_cooling_and_temp_outside_lower }}
            '';
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
        {
          name = "indoor_dewpoint";
          state = ''
            {% set rh = states('sensor.indoor_humidity') | float(60) / 100 %}
            {% set temp = states('sensor.indoor_temperature') | float(20) %}
            {{ (temp - ((100 - (rh * 100)) / 5)) | round(2) }}
          '';
          unit_of_measurement = "°C";
          icon = "mdi:water-percent";
        }
        {
          name = "outdoor_dewpoint";
          state = ''
            {% set rh = states('sensor.outdoor_humidity') | float(60) / 100 %}
            {% set temp = states('sensor.outdoor_temperature') | float(16) %}
            {{ (temp - ((100 - (rh * 100)) / 5)) | round(2) }}
          '';
          unit_of_measurement = "°C";
          icon = "mdi:water-percent";
        }
        {
          name = "outdoor_humidity";
          state = ''
            {% set rh1 = states('sensor.system_wtw_air_quality_inlet_humidity') | float(60) %}
            {% set rh2 = states('sensor.openweathermap_humidity') | float(60) %}
            {% set rh = (rh1 + rh2) / 2 %}
            {{ rh | round(2) }}
          '';
          unit_of_measurement = "%";
          icon = "mdi:water-percent";
        }
        {
          name = "outdoor_temperature";
          state = ''
            {% set itho_wtw = states('sensor.itho_wtw_inlet_temperature') | float(16) %}
            {% set inlet = states('sensor.system_wtw_air_quality_inlet_temperature') | float(16) %}
            {% set garden = states('sensor.garden_garden_temperature_noordkant_temperature') | float(16) %}
            {% set openweather = states('sensor.openweathermap_temperature') | float(itho_wtw) %}
            {% set sum = itho_wtw + garden + openweather %}
            {{ (sum / 3) | round(2) }}
          '';
          unit_of_measurement = "°C";
          icon = "mdi:home-thermometer-outline";
        }
        {
          name = "indoor_humidity";
          state = ''
            {% set v = (
              states("sensor.floor0_bureau_temperature_na_humidity"),
              states("sensor.floor0_keuken_temperature_na_humidity"),
              states("sensor.floor0_living_temperature_na_humidity"),
              states("sensor.floor1_badkamer_temperature_na_humidity"),
              states("sensor.floor1_fen_temperature_na_humidity"),
              states("sensor.floor1_morgane_temperature_na_humidity"),
              states("sensor.floor1_nikolai_temperature_na_humidity")
            )  
            %}
            {% set valid_humidities = v | select('!=','unknown') | map('float') | list %}
            {{ (valid_humidities | sum / valid_humidities | length) | round(2) }}
          '';
          icon = ''
            {% if states('sensor.indoor_humidity') | float(100) > 70 %}
                mdi:water-percent-alert
            {% else %}
                mdi:water-percent
            {% endif %}
          '';
          unit_of_measurement = "%";
        }
        {
          name = "indoor_humidity_max";
          state = ''
            {% set v = (
              states("sensor.floor0_bureau_temperature_na_humidity"),
              states("sensor.floor0_keuken_temperature_na_humidity"),
              states("sensor.floor0_living_temperature_na_humidity"),
              states("sensor.floor1_badkamer_temperature_na_humidity"),
              states("sensor.floor1_fen_temperature_na_humidity"),
              states("sensor.floor1_morgane_temperature_na_humidity"),
              states("sensor.floor1_nikolai_temperature_na_humidity")
            )  
            %}
            {% set valid_humidities = v | select('!=','unknown') | map('float') | list %}
            {{ max(valid_humidities) | round(2) }}
          '';
          icon = ''
            {% if states('sensor.indoor_humidity') | float(100) > 70 %}
                mdi:water-percent-alert
            {% else %}
                mdi:water-percent
            {% endif %}
          '';
          unit_of_measurement = "%";
        }
        {
          name = "indoor_temperature";
          state = ''
            {% set sensors = [
              states('sensor.floor0_bureau_temperature_na_temperature'),
              states('sensor.floor0_keuken_temperature_na_temperature'),
              states('sensor.floor0_living_temperature_na_temperature'),
              states('sensor.floor1_badkamer_temperature_na_temperature'),
              states('sensor.floor1_fen_temperature_na_temperature'),
              states('sensor.floor1_morgane_temperature_na_temperature'),
              states('sensor.floor1_nikolai_temperature_na_temperature'),
              states('sensor.ebusd_370_displayedroomtemp_temp')
            ] %}
            {% set valid_temperatures = sensors | select('!=','unknown') | map('float') | list %}
            {{ (valid_temperatures | sum / valid_temperatures | length) | round(2) }}
          '';
          icon = "mdi:home-thermometer";
          unit_of_measurement = "°C";
        }

      ];
    }
  ];

  sensor = [];

  utility_meter = {};
  customize = {};

  automations = [
    {
      id = "itho_wtw_target";
      alias = "itho_wtw_target";      
      trigger = [        
        {
          platform = "state";
          entity_id = "sensor.wtw_target_fan";
          for.minutes = 2;
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
      mode = "single";
    }
  ];

  binary_sensor = [];

  zigbeeDevices = { };
  
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
        value_template = "{{ value_json['Supply temp (°C)'] }}";
        unit_of_measurement = "°C";
        unique_id = "itho_wtw_inlet_temperature";
        state_class = "measurement";
        icon = "mdi:thermometer-chevron-down";
      }
      {
        name = "itho_wtw_outlet_temperature";
        state_topic = "itho/ithostatus";
        value_template = "{{ value_json['Exhaust temp (°C)'] }}";
        unit_of_measurement = "°C";
        unique_id = "itho_wtw_outlet_temperature";
        state_class = "measurement";
        icon = "mdi:thermometer-chevron-up";
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

  devices = []
    ++ map (v: v // { 
      type = "air_quality";
      zone = "wtw";
      floor = "system";
    }) aqSensors;

  climate = [];

  recorder_excludes = [ ];
}

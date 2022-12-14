let

  rtv = [
    {      
      zone = "living";
      name = "vooraan";
      ieee = "0x0c4314fffe639db0";
      floor = "floor0";
    }
    {      
      zone = "living";
      name = "achteraan";
      ieee = "0x0c4314fffe73c3ab";
      floor = "floor0";
    }
    {
      zone = "bureau";
      name = "na";
      ieee = "0x0c4314fffe62fd84";
      floor = "floor0";
    }
    {
      zone = "keuken";
      name = "na";
      ieee = "0x0c4314fffe63c110";
      floor = "floor0";
    }
    {
      zone = "morgane";
      name = "na";
      ieee = "0x0c4314fffe73c020";
      floor = "floor1";
    }
    {
      zone = "nikolai";
      name = "na";
      ieee = "0x0c4314fffe6188ea";
      floor = "floor1";
    }
    {
      zone = "fen";
      name = "na";
      ieee = "0x0c4314fffe62df15";
      floor = "floor1";
    }
    {
      zone = "badkamer";
      name = "na";
      ieee = "0x0c4314fffe62e681";
      floor = "floor1";
    }
  ];

  windows = [
    {
      zone = "morgane";
      name = "na";
      ieee = "0x847127fffead504a";
      floor = "floor1";
    }
    {
      zone = "nikolai";
      name = "na";
      ieee = "0x847127fffed3d47e";
      floor = "floor1";
    }
    {
      zone = "fen";
      name = "na";
      ieee = "0xa4c1382fd78a278a";
      floor = "floor1";
    }
    {
      zone = "badkamer";
      name = "na";
      ieee = "0x847127fffeaf3190";
      floor = "floor1";
    }
    {
      zone = "roaming";
      name = "sonoff0";
      ieee = "0x00124b002397596e";
      floor = "roaming";
    }
  ];

  tempSensors = [
    {
      zone = "living";
      name = "na";
      ieee = "0x00124b0029113b83";
      floor = "floor0";
    }
    {
      zone = "roaming";
      name = "sonoff2";
      ieee = "0x00124b0029113a29";
      floor = "roaming";
    }
  ];

  rtvDevices = builtins.listToAttrs ( 
    (
      map (v: { name = "${v.ieee}"; value = { 
      friendly_name = "${v.floor}/${v.zone}/${v.type}/${v.name}";
      homeassistant = { };
      filtered_attributes = [
        "comfort_temperature"
        "eco_temperature"
        "voltage"
        "detectwindow_temperature"
        "detectwindow_timeminute"
        "binary_one"
        "binary_two"
        "away_mode"
        "away_preset_days"
        "away_preset_temperature"
        "away_preset_year"
        "away_preset_month"
        "away_preset_day"
        "away_preset_hour"
        "away_preset_minute"

        "monday_hour_1"
        "monday_hour_2"
        "monday_hour_3"
        "monday_hour_4"
        "monday_hour_5"
        "monday_hour_6"
        "monday_hour_7"
        "monday_hour_8"
        "monday_minute_1"
        "monday_minute_2"
        "monday_minute_3"
        "monday_minute_4"
        "monday_minute_5"
        "monday_minute_6"
        "monday_minute_7"
        "monday_minute_8"
        "monday_temp_1"
        "monday_temp_2"
        "monday_temp_3"
        "monday_temp_4"
        "monday_temp_5"
        "monday_temp_6"
        "monday_temp_7"
        "monday_temp_8"

        "tuesday_hour_1"
        "tuesday_hour_2"
        "tuesday_hour_3"
        "tuesday_hour_4"
        "tuesday_hour_5"
        "tuesday_hour_6"
        "tuesday_hour_7"
        "tuesday_hour_8"
        "tuesday_minute_1"
        "tuesday_minute_2"
        "tuesday_minute_3"
        "tuesday_minute_4"
        "tuesday_minute_5"
        "tuesday_minute_6"
        "tuesday_minute_7"
        "tuesday_minute_8"
        "tuesday_temp_1"
        "tuesday_temp_2"
        "tuesday_temp_3"
        "tuesday_temp_4"
        "tuesday_temp_5"
        "tuesday_temp_6"
        "tuesday_temp_7"
        "tuesday_temp_8"

        "wednesday_hour_1"
        "wednesday_hour_2"
        "wednesday_hour_3"
        "wednesday_hour_4"
        "wednesday_hour_5"
        "wednesday_hour_6"
        "wednesday_hour_7"
        "wednesday_hour_8"
        "wednesday_minute_1"
        "wednesday_minute_2"
        "wednesday_minute_3"
        "wednesday_minute_4"
        "wednesday_minute_5"
        "wednesday_minute_6"
        "wednesday_minute_7"
        "wednesday_minute_8"
        "wednesday_temp_1"
        "wednesday_temp_2"
        "wednesday_temp_3"
        "wednesday_temp_4"
        "wednesday_temp_5"
        "wednesday_temp_6"
        "wednesday_temp_7"
        "wednesday_temp_8"

        "thursday_hour_1"
        "thursday_hour_2"
        "thursday_hour_3"
        "thursday_hour_4"
        "thursday_hour_5"
        "thursday_hour_6"
        "thursday_hour_7"
        "thursday_hour_8"
        "thursday_minute_1"
        "thursday_minute_2"
        "thursday_minute_3"
        "thursday_minute_4"
        "thursday_minute_5"
        "thursday_minute_6"
        "thursday_minute_7"
        "thursday_minute_8"
        "thursday_temp_1"
        "thursday_temp_2"
        "thursday_temp_3"
        "thursday_temp_4"
        "thursday_temp_5"
        "thursday_temp_6"
        "thursday_temp_7"
        "thursday_temp_8"

        "friday_hour_1"
        "friday_hour_2"
        "friday_hour_3"
        "friday_hour_4"
        "friday_hour_5"
        "friday_hour_6"
        "friday_hour_7"
        "friday_hour_8"
        "friday_minute_1"
        "friday_minute_2"
        "friday_minute_3"
        "friday_minute_4"
        "friday_minute_5"
        "friday_minute_6"
        "friday_minute_7"
        "friday_minute_8"
        "friday_temp_1"
        "friday_temp_2"
        "friday_temp_3"
        "friday_temp_4"
        "friday_temp_5"
        "friday_temp_6"
        "friday_temp_7"
        "friday_temp_8"

        "saturday_hour_1"
        "saturday_hour_2"
        "saturday_hour_3"
        "saturday_hour_4"
        "saturday_hour_5"
        "saturday_hour_6"
        "saturday_hour_7"
        "saturday_hour_8"
        "saturday_minute_1"
        "saturday_minute_2"
        "saturday_minute_3"
        "saturday_minute_4"
        "saturday_minute_5"
        "saturday_minute_6"
        "saturday_minute_7"
        "saturday_minute_8"
        "saturday_temp_1"
        "saturday_temp_2"
        "saturday_temp_3"
        "saturday_temp_4"
        "saturday_temp_5"
        "saturday_temp_6"
        "saturday_temp_7"
        "saturday_temp_8"

        "sunday_hour_1"
        "sunday_hour_2"
        "sunday_hour_3"
        "sunday_hour_4"
        "sunday_hour_5"
        "sunday_hour_6"
        "sunday_hour_7"
        "sunday_hour_8"
        "sunday_minute_1"
        "sunday_minute_2"
        "sunday_minute_3"
        "sunday_minute_4"
        "sunday_minute_5"
        "sunday_minute_6"
        "sunday_minute_7"
        "sunday_minute_8"
        "sunday_temp_1"
        "sunday_temp_2"
        "sunday_temp_3"
        "sunday_temp_4"
        "sunday_temp_5"
        "sunday_temp_6"
        "sunday_temp_7"
        "sunday_temp_8"
      ];      
      optimistic = false;
      availability = true;
    };})
    )
    (
      map (v: v // { type = "rtv";}) rtv 
    )
  );


  windowOpenAutomations = 
    map (v: {
      id = "${v.floor}/${v.zone}/${v.type}/${v.name}.opened";
      alias = "${v.floor}/${v.zone}/${v.type}/${v.name} opened";
      trigger = [
        {
          to = "on";
          platform = "state";
          entity_id = "binary_sensor.${v.floor}_${v.zone}_${v.type}_${v.name}_contact";
        }
      ];
      condition = [];
      action = [
        {
          service = "input_boolean.turn_off";
          data.entity_id = "input_boolean.${v.floor}_${v.zone}_rtv_is_auto";
        }
        {
          service = "climate.turn_off";
          target.entity_id = "climate.${v.floor}_${v.zone}_rtv_${v.name}";
        }
      ];
      mode = "single";
    })
  
    (map (v: v //  { type = "window";}) windows);  

  windowClosedAutomations = 
    map (v: {
      id = "${v.floor}/${v.zone}/${v.type}/${v.name}.closed";
      alias = "${v.floor}/${v.zone}/${v.type}/${v.name} closed";
      trigger = [
        {
          platform = "state";
          entity_id = "binary_sensor.${v.floor}_${v.zone}_${v.type}_${v.name}_contact";
          to = "off";
        }
      ];
      condition = [];
      action = [
        {
          service = "input_boolean.turn_on";
          data.entity_id = "input_boolean.${v.floor}_${v.zone}_rtv_is_auto";
        }
      ];
      mode = "single";
    })
    (map (v: v //  { type = "window";}) windows);

  temperatureSetWorkaroundAutomations = 
    map (v: {
      id = "${v.floor}/${v.zone}/${v.type}/${v.name}.temperature_set_workaround";
      alias = "${v.floor}/${v.zone}/${v.type}/${v.name} temperature_set_workaround";
      trigger = [
        {
          platform = "state";
          entity_id = "number.${v.floor}_${v.zone}_${v.type}_${v.name}_current_heating_setpoint_auto";
        }
      ];
      condition = ''{{ ( states('climate.${v.floor}_${v.zone}_${v.type}_${v.name}') == "auto" ) }}'';
      action = [
        {
	        service = "climate.set_temperature";
          target.entity_id = "climate.${v.floor}_${v.zone}_${v.type}_${v.name}";
          data = {
            temperature = "{{ states('number.${v.floor}_${v.zone}_${v.type}_${v.name}_current_heating_setpoint_auto') }}";
          };
        }        
      ];
      mode = "single";
    })
    (map (v: v //  { type = "rtv";}) rtv);
  
  temperatureRtvAutomations = 
    map (v: {
      id = "${v.floor}/${v.zone}/${v.type}/${v.name}.temperature_sync";
      alias = "${v.floor}/${v.zone}/${v.type}/${v.name} temperature_sync";
      trigger = [
        {
          platform = "state";
          entity_id = "sensor.${v.floor}_${v.zone}_temperature_auto_wanted";
        }
        {
          platform = "state";
          entity_id = "input_boolean.${v.floor}_${v.zone}_rtv_is_auto";
          to = "on";
        }
        {
          platform = "time";
          at = "08:00:00";
        }
        {
          platform = "time";
          at = "17:00:00";
        }
        {
          platform = "time";
          at = "23:00:00";
        }
      ];
      condition = ''{{ states('input_boolean.${v.floor}_${v.zone}_rtv_is_auto') | bool }}'';
      action = [
        {
	        service = "climate.set_preset_mode";
          target.entity_id = "climate.${v.floor}_${v.zone}_${v.type}_${v.name}";
          data.preset_mode = "manual";
        }
        {
          delay = "0:00:10";
        }
        {
	        service = "climate.set_hvac_mode";
          target.entity_id = "climate.${v.floor}_${v.zone}_${v.type}_${v.name}";
          data = {
            hvac_mode = "heat";
          };
        }
        {
          delay = "0:00:10";
        }
        {
	        service = "climate.set_temperature";
          target.entity_id = "climate.${v.floor}_${v.zone}_${v.type}_${v.name}";
          data = {
            temperature = "{{ states('sensor.${v.floor}_${v.zone}_temperature_auto_wanted') }}";
          };
        }
      ];
      mode = "queue";
    })
    (map (v: v //  { type = "rtv";}) rtv);
  
  temperatureAutoWanted = [
    {
      trigger = {
        platform = "time_pattern";
        minutes = "/5";
      };
      sensor = [
        {
          name = "floor1_nikolai_temperature_auto_wanted";
          state = ''
            {% set is_workday = states('binary_sensor.is_workday') | bool %}
            {% set is_anyone_home = states('binary_sensor.is_anyone_home') | bool %}
            {% set temperature_eco = states('input_number.temperature_eco') | float %}
            {% set temperature_night = states('input_number.temperature_night') | float %}
            {% set temperature_comfort_low = states('input_number.temperature_comfort_low') | float %}
            {% set temperature_comfort = states('input_number.temperature_comfort') | float %}

            {% if is_workday %}
              {% if now().hour >= 6 and now().hour < 17 %}
                {{ temperature_eco }}
              {% else %}
                {{ temperature_night }}
              {% endif %}
            {% else %}
              {% if now().hour >= 7 and now().hour < 9 %}
                {{ temperature_eco }}
              {% elif now().hour >= 9 and now().hour < 18 %}
                {% if is_anyone_home %}
                  {{ temperature_comfort_low }}
                {% else %}
                  {{ temperature_night }}
                {% endif %}
              {% else %}
                {{ temperature_night }}
              {% endif %}
            {% endif %}
          '';
          unit_of_measurement = "°C";
        }
        {
          name = "floor1_morgane_temperature_auto_wanted";
          state = ''
            {% set is_workday = states('binary_sensor.is_workday') | bool %}
            {% set is_anyone_home = states('binary_sensor.is_anyone_home') | bool %}
            {% set temperature_eco = states('input_number.temperature_eco') | float %}
            {% set temperature_night = states('input_number.temperature_night') | float %}
            {% set temperature_comfort_low = states('input_number.temperature_comfort_low') | float %}
            {% set temperature_comfort = states('input_number.temperature_comfort') | float %}

            {% if is_workday %}
              {% if now().hour >= 6 and now().hour < 17 %}
                {{ temperature_eco }}
              {% else %}
                {{ temperature_night }}
              {% endif %}
            {% else %}
              {% if now().hour >= 7 and now().hour < 9 %}
                {{ temperature_eco }}
              {% elif now().hour >= 9 and now().hour < 18 %}
                {% if is_anyone_home %}
                  {{ temperature_comfort_low }}
                {% else %}
                  {{ temperature_night }}
                {% endif %}
              {% else %}
                {{ temperature_night }}
              {% endif %}
            {% endif %}
          '';
          unit_of_measurement = "°C";
        }
        {
          name = "floor1_fen_temperature_auto_wanted";
          state = ''
            {% set is_workday = states('binary_sensor.is_workday') | bool %}
            {% set is_anyone_home = states('binary_sensor.is_anyone_home') | bool %}
            {% set temperature_eco = states('input_number.temperature_eco') | float %}
            {% set temperature_night = states('input_number.temperature_night') | float %}
            {% set temperature_comfort_low = states('input_number.temperature_comfort_low') | float %}
            {% set temperature_comfort = states('input_number.temperature_comfort') | float %}

            {% if is_workday %}
              {% if now().hour >= 6 and now().hour < 17 %}
                {{ temperature_eco }}
              {% else %}
                {{ temperature_night }} 
              {% endif %}
            {% else %}
              {% if now().hour >= 7 and now().hour < 9 %}
                {{ temperature_eco }}        
              {% else %}
                {{ temperature_night }}
              {% endif %}
            {% endif %}
          '';
          unit_of_measurement = "°C";
        }
        {
          name = "floor1_badkamer_temperature_auto_wanted";
          state = ''
            {% set is_workday = states('binary_sensor.is_workday') | bool %}
            {% set is_anyone_home = states('binary_sensor.is_anyone_home') | bool %}
            {% set temperature_eco = states('input_number.temperature_eco') | float %}
            {% set temperature_night = states('input_number.temperature_night') | float %}
            {% set temperature_comfort_low = states('input_number.temperature_comfort_low') | float %}
            {% set temperature_comfort = states('input_number.temperature_comfort') | float %}

            {% if is_workday %}
              {% if now().hour >= 6 and now().hour < 7 %}
                {{ temperature_comfort }}
              {% else %}
                {{ temperature_night }}
              {% endif %}
            {% else %}
              {{ temperature_night }}
            {% endif %}
          '';
          unit_of_measurement = "°C";
        }
        {
          name = "floor0_keuken_temperature_auto_wanted";
          state = ''
            {% set is_workday = states('binary_sensor.is_workday') | bool %}
            {% set is_anyone_home = states('binary_sensor.is_anyone_home') | bool %}
            {% set temperature_eco = states('input_number.temperature_eco') | float %}
            {% set temperature_night = states('input_number.temperature_night') | float %}
            {% set temperature_comfort_low = states('input_number.temperature_comfort_low') | float %}
            {% set temperature_comfort = states('input_number.temperature_comfort') | float %}

            {{ temperature_eco }} 
          '';
          unit_of_measurement = "°C";
        }
        {
          name = "floor0_bureau_temperature_auto_wanted";
          state = ''
            {% set is_workday = states('binary_sensor.is_workday') | bool %}
            {% set is_anyone_home = states('binary_sensor.is_anyone_home') | bool %}
            {% set temperature_eco = states('input_number.temperature_eco') | float %}
            {% set temperature_night = states('input_number.temperature_night') | float %}
            {% set temperature_comfort_low = states('input_number.temperature_comfort_low') | float %}
            {% set temperature_comfort = states('input_number.temperature_comfort') | float %}

            {% if is_workday %}
              {{ temperature_eco }}
            {% else %}
              {% if now().hour >= 9 and now().hour < 18 %}
                {% if is_anyone_home %}
                  {{ temperature_comfort_low }}
                {% else %}
                  {{ temperature_eco }}
                {% endif %}
              {% else %}
                {{ temperature_eco }}
              {% endif %}
            {% endif %}
          '';
          unit_of_measurement = "°C";
        }
        {
          name = "floor0_living_temperature_auto_wanted";
          state = ''
            {% set is_workday = states('binary_sensor.is_workday') | bool %}
            {% set is_anyone_home = states('binary_sensor.is_anyone_home') | bool %}
            {% set temperature_eco = states('input_number.temperature_eco') | float %}
            {% set temperature_night = states('input_number.temperature_night') | float %}
            {% set temperature_comfort_low = states('input_number.temperature_comfort_low') | float %}
            {% set temperature_comfort = states('input_number.temperature_comfort') | float %}

            {% if is_workday %}
              {% if now().hour >= 17 and now().hour < 22 %}
                {{ temperature_comfort }}
              {% else %}
                {{ temperature_eco }}
              {% endif %}
            {% else %}
              {% if now().hour >= 7 and now().hour < 22 %}
                {{ temperature_comfort }}
              {% else %}
                {{ temperature_eco }}
              {% endif %}
            {% endif %}
          '';
          unit_of_measurement = "°C";
        }
      ];
    }
  ];

in
{
  devices = [] 
    ++ map (v: v //  { type = "window";}) windows
    ++ map (v: v //  { type = "temperature";}) tempSensors;
  zigbeeDevices = {} // rtvDevices;
  automations = []
    ++ windowOpenAutomations
    ++ windowClosedAutomations
    ++ temperatureRtvAutomations;

  template = [] ++ temperatureAutoWanted;

}
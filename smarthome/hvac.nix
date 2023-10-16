{config, pkgs, lib, ...}:

let

  autoWantedHeader = ''
    {% set workday = states('binary_sensor.workday') | bool(true) %}    
    {% set anyone_home = states('binary_sensor.anyone_home') | bool(true) %}
    {% set temperature_eco = 15.0 %}
    {% set temperature_night = 16.5 %}
    {% set temperature_comfort_low = 17.5 %}
    {% set temperature_comfort = 18.5 %}
    {% set temperature_minimal = 5.5 %}
  '';

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
      zone = "keuken";
      name = "na";
      ieee = "0x00124b0029114a89";
      floor = "floor0";
    }
    {
      zone = "bureau";
      name = "na";
      ieee = "0x00124b0029113a29";
      floor = "floor0";
    }
    {
      ieee = "0x00124b002910edd6";
      zone = "badkamer";
      name = "na";
      floor = "floor1";
    }
    {
      ieee = "0x00124b002910d106";
      zone = "fen";
      name = "na";
      floor = "floor1";
    }
    {
      ieee = "0x00124b00291149da";
      zone = "nikolai";
      name = "na";
      floor = "floor1";
    }
    {
      ieee = "0x00124b00291150db";
      zone = "morgane";
      name = "na";
      floor = "floor1";
    }
    {
      ieee = "0x00124b002910ed8a";
      zone = "basement";
      name = "na";
      floor = "basement";
    }
    {
      ieee = "0x00124b002910ce57";
      zone = "garden";
      name = "noordkant";
      floor = "garden";
    }
  ];

  rtvFilteredAttributes = import ./rtvFilteredAttributes.nix;
  

  rtvDevices = builtins.listToAttrs ( 
    (
      map (v: { name = "${v.ieee}"; value = { 
      friendly_name = "${v.floor}/${v.zone}/${v.type}/${v.name}";
      homeassistant = { } // builtins.listToAttrs (map (vf: { name = vf; value = null;}) rtvFilteredAttributes);
      filtered_attributes = rtvFilteredAttributes;      
      optimistic = false;
      availability = true;
    };})
    )
    (
      map (v: v // { type = "rtv";}) rtv 
    )
  );

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
          platform = "time";
          at = "08:00:00";
        }
        {
          platform = "time";
          at = "13:00:00";
        }
        {
          platform = "time";
          at = "17:00:00";
        }
        {
          platform = "time";
          at = "20:00:00";
        }
        {
          platform = "time";
          at = "23:00:00";
        }
      ];
      condition = ''
        {{ 
          (states('sensor.${v.floor}_${v.zone}_temperature_auto_wanted') | float(0) != state_attr('climate.${v.floor}_${v.zone}_${v.type}_${v.name}', 'temperature') | float(0))
        }}
      '';
      action = [
        {
	        service = "climate.set_temperature";
          target.entity_id = "climate.${v.floor}_${v.zone}_${v.type}_${v.name}";
          data = {
            temperature = "{{ states('sensor.${v.floor}_${v.zone}_temperature_auto_wanted') }}";
          };
        }
      ];
      mode = "queued";
    })
    (map (v: v //  { type = "rtv";}) rtv);

  temperatureCalibrationAutomations = 
    map (v: {
      id = "${v.floor}/${v.zone}/${v.type}/${v.name}.temperature_calibration";
      alias = "${v.floor}/${v.zone}/${v.type}/${v.name} temperature_calibration";
      trigger = [        
        {
          platform = "time_pattern";
          minutes = "/15";
        }
      ];
      condition = ''
        {{ states('sensor.${v.floor}_${v.zone}_temperature_na_temperature') != "unknown" }}
      '';
      action = [
        {
	        service = "mqtt.publish";
          data = {
            topic = "zigbee2mqtt/${v.floor}/${v.zone}/${v.type}/${v.name}/set";
            payload_template = ''
              {% set sensor_temp = states('sensor.${v.floor}_${v.zone}_temperature_na_temperature') | float(0) %}
              {% set rtv_temp = state_attr('climate.${v.floor}_${v.zone}_rtv_${v.name}', 'local_temperature') | float(0) %}
              {% set rtv_calibration = state_attr('climate.${v.floor}_${v.zone}_rtv_${v.name}', 'local_temperature_calibration') | float(0) %}
              { "local_temperature_calibration": {{ (sensor_temp - (rtv_temp - rtv_calibration))  | round(1) }} }
            '';
          };
        }        
      ];
      mode = "single";
    })
    (map (v: v //  { type = "rtv";}) rtv);
  
  temperatureAutoWanted = [
    {
      sensor = [
        {
          name = "floor1_nikolai_temperature_auto_wanted";
          state = ''
            ${autoWantedHeader}
            {% set is_window_closed = states('binary_sensor.floor1_nikolai_window_na_contact') | bool(false) == false %}
            {% if is_window_closed %}
              {% if workday %}
                {% if now().hour >= 6 and now().hour < 17 %}
                  {{ temperature_eco }}
                {% else %}
                  {{ temperature_night }}
                {% endif %}
              {% else %}
                {% if now().hour >= 7 and now().hour < 9 %}
                  {{ temperature_eco }}
                {% elif now().hour >= 9 and now().hour < 18 %}
                  {% if anyone_home %}
                    {{ temperature_comfort_low }}
                  {% else %}
                    {{ temperature_night }}
                  {% endif %}
                {% else %}
                  {{ temperature_night }}
                {% endif %}
              {% endif %}
            {% else %}
              {{ temperature_minimal }}
            {% endif %}
          '';
          unit_of_measurement = "°C";
        }
        {
          name = "floor1_morgane_temperature_auto_wanted";
          state = ''
            ${autoWantedHeader}
            {% set is_window_closed = states('binary_sensor.floor1_morgane_window_na_contact') | bool(false) == false %}
            {% if is_window_closed %}
              {% if workday %}
                {% if now().hour >= 6 and now().hour < 17 %}
                  {{ temperature_eco }}
                {% else %}
                  {{ temperature_night }}
                {% endif %}
              {% else %}
                {% if now().hour >= 7 and now().hour < 9 %}
                  {{ temperature_eco }}
                {% elif now().hour >= 9 and now().hour < 18 %}
                  {% if anyone_home %}
                    {{ temperature_comfort_low }}
                  {% else %}
                    {{ temperature_night }}
                  {% endif %}
                {% else %}
                  {{ temperature_night }}
                {% endif %}
              {% endif %}
            {% else %}
              {{ temperature_minimal }}
            {% endif %}
          '';
          unit_of_measurement = "°C";
        }
        {
          name = "floor1_fen_temperature_auto_wanted";
          state = ''
            ${autoWantedHeader}
            {% set is_window_closed = states('binary_sensor.floor1_fen_window_na_contact') | bool(false) == false %}
            {% if is_window_closed %}
              {% if workday %}
                {% if now().hour >= 6 and now().hour < 17 %}
                  {{ temperature_eco }}
                {% else %}
                  {{ temperature_night }} 
                {% endif %}
              {% else %}                
                {{ temperature_night }}
              {% endif %}
            {% else %}
              {{ temperature_minimal }}
            {% endif %}
          '';
          unit_of_measurement = "°C";
        }
        {
          name = "floor1_badkamer_temperature_auto_wanted";
          state = ''
            ${autoWantedHeader}
            {% set is_window_closed = states('binary_sensor.floor1_badkamer_window_na_contact') | bool(false) == false %}
            {% if is_window_closed %}
              {% if workday %}
                {% if now().hour >= 6 and now().hour < 7 %}
                  {{ temperature_comfort }}
                {% else %}
                  {{ temperature_night }}
                {% endif %}
              {% else %}
                {{ temperature_night }}
              {% endif %}
            {% else %}
              {{ temperature_minimal }}
            {% endif %}
          '';
          unit_of_measurement = "°C";
        }
        {
          name = "floor0_keuken_temperature_auto_wanted";
          state = ''
            ${autoWantedHeader}
            {{ temperature_eco }} 
          '';
          unit_of_measurement = "°C";
        }
        {
          name = "floor0_bureau_temperature_auto_wanted";
          state = ''
            ${autoWantedHeader}
            {% set bureau_in_use = states('binary_sensor.floor0_bureau_in_use') | bool(false) %}
            {% if bureau_in_use %}
              {{ temperature_comfort }}
            {% else %}
              {% if workday %}
                {{ temperature_eco }}
              {% else %}
                {% if now().hour >= 9 and now().hour < 18 %}
                  {% if anyone_home %}
                    {{ temperature_comfort_low }}
                  {% else %}
                    {{ temperature_eco }}
                  {% endif %}
                {% else %}
                  {{ temperature_eco }}
                {% endif %}
              {% endif %}
            {% endif %}
          '';
          unit_of_measurement = "°C";
        }
        {
          name = "floor0_living_temperature_auto_wanted";
          state = ''
            ${autoWantedHeader}
            {% if workday %}
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

  roomTemperatureDifferenceWanted = map (v: 
    {
      name = "${v.floor}_${v.zone}_rtv_${v.name}_temperature_diff_wanted";
      unit_of_measurement = "°C";
      device_class = "temperature";
      state = ''
        {% set temperature_wanted = state_attr("climate.${v.floor}_${v.zone}_rtv_${v.name}", "temperature") | float(15.5) %}
        {% set temperature_actual = states("sensor.${v.floor}_${v.zone}_temperature_na_temperature") | float(15.5) %}
        {{ (temperature_wanted - temperature_actual) | round(2) }}
      '';
      icon = "mdi:thermometer-auto";
    }) rtv;
  
  heatingNeededRtvSensors = map(v: "states('sensor.${v.floor}_${v.zone}_rtv_${v.name}_temperature_diff_wanted')") rtv;

  heatingNeeded = [
    {
      name = "heating_temperature_diff_wanted";
      unit_of_measurement = "°C";
      device_class = "temperature";
      state = ''
        {% 
        set v = (
          ${builtins.concatStringsSep "," heatingNeededRtvSensors}
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
        {% set desired_temp = state_attr("climate.cv", "temperature") | float(15.5) %}
        {% set current_temp = state_attr("climate.cv", "current_temperature") | float(19.5) %}
        {% set temperature_diff_wanted = states("sensor.heating_temperature_diff_wanted") | float(0) %}
        {% set max_desired_temp = 21 %}
        {% set target_temp = current_temp + temperature_diff_wanted %}
        {% set new_temp = desired_temp %}
        {% set is_anyone_home_or_coming = states('binary_sensor.anyone_home_or_coming_home') | bool(true) %}
        {% set is_travelling = states('binary_sensor.far_away') | bool(false) %}        
        {% if is_anyone_home_or_coming %}          
          {% if target_temp > (current_temp + 0.5) %}
            {% if temperature_diff_wanted > 0.5 %}
              {# Gradually increase temperature #}
              {% set new_temp = (((current_temp + 0.5) * 2) | round(0) / 2) %}
              {% set new_temp = min(new_temp, max_desired_temp) %}
            {% endif %}
          {% elif target_temp < current_temp %}
            {% set new_temp = ((target_temp * 2) | round(0) / 2) %}
            {% set new_temp = max(new_temp, temperature_eco) %}
          {% endif %}
        {% elif is_travelling %}
          {% set new_temp = temperature_minimal %}
        {% else %}
          {% set new_temp = temperature_eco %}
        {% endif %}
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

in
{
  devices = [] 
    ++ map (v: v //  { type = "window";}) windows
    ++ map (v: v //  { type = "temperature";}) tempSensors;
  zigbeeDevices = {} // rtvDevices;
  automations = []
    ++ temperatureRtvAutomations
    ++ temperatureCalibrationAutomations;

  template = []
   ++ temperatureAutoWanted 
   ++ [{ sensor = roomTemperatureDifferenceWanted; }]
   ++ [{ sensor = heatingNeeded; }];


  recorder_excludes = [
    "binary_sensor.*_window_*_tamper"
    "binary_sensor.*_rtv_*_away_mode"
  ];
}

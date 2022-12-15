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
          (states('input_boolean.${v.floor}_${v.zone}_rtv_is_auto') | bool)
          and
          (states('sensor.${v.floor}_${v.zone}_temperature_auto_wanted') | float(0) != state_attr('climate.${v.floor}_${v.zone}_${v.type}_${v.name}', 'temperature') | float(0))
        }}
      '';
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
      mode = "queued";
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
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
      homeassistant = {
        filtered_attributes = [
          "comfort_temperature"
          "eco_temperature"
          #"current_heating_setpoint_auto"
          "local_temperature_calibration"
          "detectwindow_temperature"
          "detectwindow_timeminute"
          "binary_one"
          "binary_two"
          "away_setting"
        ];
      };
      #optimistic = true;
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
	        service = "climate.set_temperature";
          target.entity_id = "climate.${v.floor}_${v.zone}_rtv_${v.name}";
          data = {
            hvac_mode = "auto";
            temperature = "{{ states('number.${v.floor}_${v.zone}_rtv_${v.name}_current_heating_setpoint_auto') }}";
          };
        }

        {
	        service = "climate.set_preset_mode";
          target.entity_id = "climate.${v.floor}_${v.zone}_rtv_${v.name}";
          data.preset_mode = "schedule";
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

in
{
  devices = [] 
    ++ map (v: v //  { type = "window";}) windows
    ++ map (v: v //  { type = "temperature";}) tempSensors;
  zigbeeDevices = {} // rtvDevices;
  automations = []
    ++ windowOpenAutomations
    ++ windowClosedAutomations
    ++ temperatureSetWorkaroundAutomations;

}
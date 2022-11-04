{ config, lib, pkgs, ... }:
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

  lightPlugs = [
    {
      zone = "living";
      name = "kattenlamp";
      ieee = "0x0c4314fffee9dcd3";
      floor = "floor0";      
    }
    {
      zone = "living";
      name = "bollamp";
      ieee = "0x50325ffffe5ebbec";
      floor = "floor0";
    }
  ];

  plugs = [
       
    {
      zone = "garden";
      name = "laadpaal";
      ieee = "0x842e14fffe3b8777";
      floor = "garden";
    }    
    {
      zone = "living";
      name = "sonos_rear";
      ieee = "0x5c0272fffe88e39f";
      floor = "floor0";
    }
  ] ++ metering_plugs;

  metering_plugs = [
    {
      zone = "waskot";
      name = "droogkast";
      ieee = "0xa4c138163459950e";
      floor = "floor1";
    }
    {
      zone = "keuken";
      name = "oven";
      ieee = "0xa4c1381f8ccf7230";
      floor = "floor0";
    }
    {
      zone = "basement";
      name = "network";
      ieee = "0xa4c138ae189cf8bd";
      floor = "basement";
    }
    {
      zone = "waskot";
      name = "wasmachine";
      ieee = "0xa4c1383c42598ec3";
      floor = "floor1";
    }
  ];

  zigbeeDevices = 
    lightPlugDevices // rtvDevices // zigbeeDevicesWithIeeeAsKey;

  lightPlugDevices = 
    builtins.listToAttrs ( 
      (
        map (v: { name = "${v.ieee}"; value = { 
        friendly_name = "${v.floor}/${v.zone}/${v.type}/${v.name}";
        homeassistant = {
#          name = "${v.zone} Light ${v.name}";
#          switch = {
#            type = "light";
#            object_id = "light";            
#          };
#          light = {
#            name = "${v.floor}/${v.zone}/${v.type}/${v.name}";
#            value_template = "";
#            state_value_template = "'{{ value_json.state }}'";
#          };
        };
      };})
      )
      (
        map (v: v // { type = "light_plug";}) lightPlugs
      )
    );
  
  rtvDevices = builtins.listToAttrs ( 
      (
        map (v: { name = "${v.ieee}"; value = { 
        friendly_name = "${v.floor}/${v.zone}/${v.type}/${v.name}";
        homeassistant = {
         filtered_attributes = [
            "comfort_temperature"
            "eco_temperature"
            "current_heating_setpoint_auto"
            "local_temperature_calibration"
            "detectwindow_temperature"
            "detectwindow_timeminute"
            "binary_one"
            "binary_two"
            "away_setting"
          ];
        };
      };})
      )
      (
        map (v: v // { type = "rtv";}) rtv 
      )
    );

  zigbeeDevicesWithIeeeAsKey = 
    builtins.listToAttrs ( 
      (
        map (v: { name = "${v.ieee}"; value = { friendly_name = "${v.floor}/${v.zone}/${v.type}/${v.name}";};})
      )
      (
        map (v: v //  { type = "window";}) windows 
        ++ map (v: v // { type = "plug";}) plugs
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

  



water = import ./water.nix;
energy = import ./energy.nix;
media = import ./media.nix;
wfh = import ./wfh.nix;

in 

with lib;
{
  # Workaround for HG
  system.activationScripts.lidl-HG08673-FR-converter.text = ''
    ln -sf "${./lidl-HG08673-FR-converter.js}" "${config.services.zigbee2mqtt.dataDir}/lidl-HG08673-FR-converter.js"
  '';

  services.zigbee2mqtt.settings = {
    devices = zigbeeDevices;
    external_converters = [
      "lidl-HG08673-FR-converter.js"
    ];
  };

  services.home-assistant = {
    config."automation manual" = 
      windowOpenAutomations 
      ++ windowClosedAutomations 
      ++ wfh.automations
      ++ media.automations;

    config.binary_sensor = [
      {
        platform = "group";
        name = "floor1/windows_contact";
        entities = [
          #"binary_sensor.floor1_*_window_na_contact"
        ];
      }
    ] 
    ++ media.binary_sensor
    ++ wfh.binary_sensor;

    config.mqtt = {
      binary_sensor = [] 
        ++ water.mqtt.binary_sensor;

      sensor = []
        ++ water.mqtt.sensor;

    };

    config.homeassistant.customize = {} 
      // energy.customize;

    config.sensor = []
      ++ energy.sensor;

    config.utility_meter = { } 
      // water.utility_meter;

    config.template = [] 
      ++ energy.template;

    config.device_tracker = [
      {
        platform = "ping";
        hosts = {
          "fphone" = "fphone";
          "nphone" = "nphone";
        };
      }
    ];

    config.person = [
      {
        name = "Femke";
        id = "femke";
        device_trackers = ["device_tracker.fphone"];
      }
      {
        name = "Nathan";
        id = "nathan";
        device_trackers = ["device_tracker.nphone"];
      }
    ];
  };
}

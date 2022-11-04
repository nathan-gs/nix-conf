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
      zone = "roaming";
      name = "meter0";
      ieee = "0xa4c138163459950e";
      floor = "roaming";
    }    
    {
      zone = "garden";
      name = "laadpaal";
      ieee = "0x842e14fffe3b8777";
      floor = "garden";
    }
    {
      zone = "keuken";
      name = "oven";
      ieee = "0xa4c1381f8ccf7230";
      floor = "floor0";
    }
    {
      zone = "living";
      name = "sonos_rear";
      ieee = "0x5c0272fffe88e39f";
      floor = "floor0";
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

  workFromHomeAutomations = [
    {
      id = "ndesk_on_turn_on_heating_in_bureau";
      alias = "ndesk:on turn on heating in bureau";
      trigger = [
        {
          platform = "state";
          entity_id = "binary_sensor.ndesk";
          to = "on";
        }
      ];
      condition = [];
      action = [
        {
	        service = "climate.set_preset_mode";
          target.entity_id = "climate.floor0_bureau_rtv_na";
          data.preset_mode = "manual";
        }
        {
          delay = "0:00:01";
        }
        {
	        service = "climate.set_hvac_mode";
          target.entity_id = "climate.floor0_bureau_rtv_na";
          data = {
            hvac_mode = "heat";
          };
        }
        {
          delay = "0:00:01";
        }
        {
	        service = "climate.set_temperature";
          target.entity_id = "climate.floor0_bureau_rtv_na";
          data = {
            temperature = 19.5;
          };
        }
      ];
      mode = "single";
    }
    {
      id = "flaptop_on_turn_on_heating_in_nikolai";
      alias = "flaptop:on turn on heating in Nikolaï's room";
      trigger = [
        {
          platform = "state";
          entity_id = "binary_sensor.flaptop";
          to = "on";
        }
      ];
      condition = [];
      action = [
        {
	        service = "climate.set_preset_mode";
          target.entity_id = "climate.floor1_nikolai_rtv_na";
          data.preset_mode = "manual";
        }
        {
          delay = "0:00:01";
        }
        {
	        service = "climate.set_hvac_mode";
          target.entity_id = "climate.floor0_nikolai_rtv_na";
          data = {
            hvac_mode = "heat";
          };
        }
        {
          delay = "0:00:01";
        }
        {
	        service = "climate.set_temperature";
          target.entity_id = "climate.floor0_nikolai_rtv_na";
          data = {
            temperature = 19.5;
          };
        }
      ];
      mode = "single";
    }
    {
      id = "ndesk_off_heating_auto_in_bureau";
      alias = "ndesk:off heating auto in bureau";
      trigger = [
        {
          platform = "state";
          entity_id = "binary_sensor.ndesk";
          to = "off";
        }
      ];
      condition = [];
      action = [
        {
	        service = "climate.set_temperature";
          target.entity_id = "climate.floor0_bureau_rtv_na";
          data = {
            hvac_mode = "auto";
            temperature = "{{ states('number.floor0_bureau_rtv_na_current_heating_setpoint_auto') }}";
          };
        }
        {
	        service = "climate.set_preset_mode";
          target.entity_id = "climate.floor0_bureau_rtv_na";
          data.preset_mode = "schedule";
        }
      ];
      mode = "single";
    }
    {
      id = "flaptop_off_heating_auto_in_nikolai";
      alias = "flaptop:off heating auto in nikolai's room";
      trigger = [
        {
          platform = "state";
          entity_id = "binary_sensor.flaptop";
          to = "off";
        }
      ];
      condition = [];
      action = [
        {
	        service = "climate.set_temperature";
          target.entity_id = "climate.floor1_nikolai_rtv_na";
          data = {
            hvac_mode = "auto";
            temperature = "{{ states('number.floor1_nikolai_rtv_na_current_heating_setpoint_auto') }}";
          };
        }
        {
	        service = "climate.set_preset_mode";
          target.entity_id = "climate.floor1_nikolai_rtv_na";
          data.preset_mode = "schedule";
        }
      ];
      mode = "single";
    }
  ];

tvAutomations = [
  {
    id = "floor0_living_media_appletv:on";
    alias = "floor0/living/media/appletv:on";
    trigger = [
      {
        platform = "state";
        to = "on";        
        entity_id = "binary_sensor.floor0_living_appletv_woonkamer";        
      }
    ];
    condition = [];
    action = [
      {
        service = "switch.turn_on";
        data = {};
        target.entity_id = "switch.floor0_living_plug_sonos_rear";
      }
    ];
    mode = "single";
  }
  {
    id = "floor0_living_media_appletv:off";
    alias = "floor0/living/media/appletv:off";
    trigger = [
      {
        platform = "state";
        to = "off";        
        entity_id = "binary_sensor.floor0_living_appletv_woonkamer";
      }
    ];
    condition = [];
    action = [
      {
        service = "switch.turn_off";
        data = {};
        target.entity_id = "switch.floor0_living_plug_sonos_rear";
      }
    ];
    mode = "single";
  }
];

water.mqtt = {
  binary_sensor = [
    {
      name = "watermeter_leak_detect";
      state_topic = "watermeter/reading/watermeter_leak_detect";
    }
  ];

  sensor = [
    {
      name = "watermeter_total";
      state_topic = "watermeter/reading/current_value";
      unit_of_measurement = "L";
      force_update = true;
    }
    {
      name = "watermeter_usage_last_minute";
      state_topic = "watermeter/reading/water_used_last_minute";
      unit_of_measurement = "L";
    }
  ];

};

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
      ++ workFromHomeAutomations
      ++ tvAutomations;

    config.binary_sensor = [
      {
        platform = "ping";
        host = "ndesk";
        name = "ndesk";
        count = 2;
        scan_interval = 30;
      }
      {
        platform = "ping";
        host = "flaptop-CP80173";
        name = "flaptop";
        count = 2;
        scan_interval = 30;
      }
      {
        platform = "ping";
        host = "appletv-woonkamer";
        name = "floor0_living_appletv_woonkamer";
        count = 2;
        scan_interval = 30;
      }
      {
        platform = "group";
        name = "floor1/windows_contact";
        entities = [
          #"binary_sensor.floor1_*_window_na_contact"
        ];
      }
    ];

    config.mqtt = {
      binary_sensor = [] 
        ++ water.mqtt.binary_sensor;

      sensor = []
        ++ water.mqtt.sensor;

    };

    config.sensor = [
      {
        platform = "scrape";
        resource = "https://callmepower.be/nl/energie/leveranciers/octaplus/tarieven";
        name = "energy_electricity_cost_peak_kwh_energycomponent";
        select = "table :has(> th:contains(Dagtarief)) td";
        unit_of_measurement = "€/kWh";
        value_template = "{{ (value | float) / 100 }}";
        scan_interval = 3600;
      }
      {
        platform = "scrape";
        resource = "https://callmepower.be/nl/energie/leveranciers/octaplus/tarieven";
        name = "energy_electricity_cost_offpeak_kwh_energycomponent";
        select = "table :has(> th:contains(Nachttarief)) td";
        unit_of_measurement = "€/kWh";
        value_template = "{{ (value | float) / 100 }}";
        scan_interval = 3600;
      }
      {
        platform = "scrape";
        resource = "https://callmepower.be/nl/energie/leveranciers/octaplus/tarieven";
        name = "energy_gas_cost_kwh_energycomponent";
        select = "table :has(> th:contains(per)) td";
        unit_of_measurement = "€/kWh";
        value_template = "{{ (value | float) / 100 }}";
        scan_interval = 3600;
      }      
    ];

    config.utility_meter = {
      water_usage = {
        source = "sensor.watermeter_total";
      };
      # water_usage_daily = {
      #   source = "sensor.watermeter_total";
      #   cycle = "daily";
      # };
      # water_usage_hourly = {
      #   source = "sensor.watermeter_total";
      #   cycle = "hourly";
      # };

    };

    config.template = 
    [
    
      {
        sensor = [
          {
            name = "energy_gas_cost_kwh";
            unit_of_measurement = "€/kWh";
            # Cost = vendor + federal tax + federal accijns + nettarifs + transport
            state = "{{ ( states('sensor.energy_gas_cost_kwh_energycomponent') | float ) + (0.1058 / 100) + (0.0572 / 100) + (2.07 / 100) + (1.41 / 1000) }}";
          }
          {
            name = "energy_gas_cost_m3";
            unit_of_measurement = "€/m³";
            state = "{{ ( states('sensor.energy_gas_cost_kwh') | float ) * 11.60}}";
          }            
          {
            name = "energy_electricity_cost_peak_kwh";
            unit_of_measurement = "€/kWh";
            # Cost = vendor + federal accijns + nettarifs + transport + bijdrage energie + groene stroom + wkk
            state = "{{ ( states('sensor.energy_electricity_cost_peak_kwh_energycomponent') | float ) + (1.44160 / 100) + (9.42 / 100) + (1.26 / 100) + (0.2942 / 100) + (2.233 / 100) + (0.344 / 100) }}";      
          }
          {
            name = "energy_electricity_cost_offpeak_kwh";
            unit_of_measurement = "€/kWh";
            # Cost = vendor + federal accijns + nettarifs + transport + bijdrage energie + groene stroom + wkk
            state = "{{ ( states('sensor.energy_electricity_cost_offpeak_kwh_energycomponent') | float ) + (1.44160 / 100) + (6.87 / 100) + (1.26 / 100) + (0.2942 / 100) + (2.233 / 100) + (0.344 / 100) }}";      
          }
        ];
      }
    ];

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

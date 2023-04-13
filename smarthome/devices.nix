{ config, lib, pkgs, ... }:
let

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
  ];

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
    {
      zone = "fen";
      name = "deken";
      ieee = "0xa4c138bd0cf23138";
      floor = "floor1";
    }
  ];

  zigbeeDevices = 
    hvac.zigbeeDevices // zigbeeDevicesWithIeeeAsKey // lights.zigbeeDevices;
  
  zigbeeDevicesWithIeeeAsKey = 
    builtins.listToAttrs ( 
      (
        map (v: { name = "${v.ieee}"; value = { 
          friendly_name = "${v.floor}/${v.zone}/${v.type}/${v.name}";
          homeassistant.update = null;
        };})
      )
      (
        hvac.devices 
        ++ lights.devices
        ++ map (v: v // { type = "plug";}) plugs
        ++ map (v: v // { type = "metering_plug";}) metering_plugs        
      )
    );


  

solar = import ./solar.nix {config = config;};
bluecorner = import ./bluecorner.nix {config = config; pkgs = pkgs;};
water = import ./water.nix;
energy = import ./energy.nix;
media = import ./media.nix;
wfh = import ./wfh.nix;
lights = import ./lights.nix;
hvac = import ./hvac.nix;
plugsFile = import ./plugs.nix;
general = import ./general.nix;

in 

with lib;
{
  system.activationScripts.lidl-368308_2010-converter.text = ''
    ln -sfn "${./lidl-368308_2010-converter.js}" "${config.services.zigbee2mqtt.dataDir}/lidl-368308_2010-converter.js"
  '';

  services.zigbee2mqtt.settings = {
    devices = zigbeeDevices;
    external_converters = [
      #"tuya.js"- not working for now
      "lidl-368308_2010-converter.js"
    ];
    availability = true;
  };

  services.home-assistant = {
    config."automation manual" = 
      lights.automations
      ++ hvac.automations
      ++ wfh.automations
      ++ media.automations
      ++ plugsFile.automations
      ++ energy.automations
      ++ bluecorner.automations;

    config.binary_sensor = [ ] 
    ++ wfh.binary_sensor
    ++ solar.binary_sensor
    ++ bluecorner.binary_sensor;


    config.mqtt = {
      binary_sensor = [] 
        ++ water.mqtt.binary_sensor;

      sensor = []
        ++ water.mqtt.sensor
        ++ bluecorner.mqtt_sensor;

    };

    config.homeassistant.customize = {} 
      // energy.customize
      // solar.customize
      // bluecorner.customize;

    config.sensor = []
      ++ energy.sensor
      ++ solar.sensor
      ++ bluecorner.sensor;

    config.utility_meter = { } 
      // water.utility_meter
      // energy.utility_meter
      // solar.utility_meter
      // bluecorner.utility_meter;

    config.template = [] 
      ++ energy.template
      ++ water.template
      ++ general.template
      ++ hvac.template
      ++ media.template
      ++ solar.template
      ++ bluecorner.template;

    config.device_tracker = [
      {
        platform = "ping";
        hosts = {
          "fphone" = "fphone";
          "nphone" = "nphone-s22";
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

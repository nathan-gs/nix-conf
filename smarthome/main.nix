{ config, lib, pkgs, ... }:
let

  zigbeeDevices = 
    hvac.zigbeeDevices // zigbeeDevicesWithIeeeAsKey // lights.zigbeeDevices;
  
  zigbeeDevicesWithIeeeAsKey = 
    builtins.listToAttrs ( 
      (
        map (v: { name = "${v.ieee}"; value = { 
          friendly_name = "${v.floor}/${v.zone}/${v.type}/${v.name}";
          homeassistant = {
            update = null;
            expire_after = 3600;
            object_id = "${v.floor}_${v.zone}_${v.type}_${v.name}";
            device.suggested_area = "${v.floor}/${v.zone}";
          };
        };})
      )
      (
        hvac.devices 
        ++ lights.devices
        ++ plugs.devices
        ++ hvac-wtw.devices
      )
    );

solar = import ./solar.nix {config = config;};
charger-bluecorner = import ./charger-bluecorner.nix {config = config; pkgs = pkgs;};
charger = import ./charger.nix {config = config; pkgs = pkgs;};
garden = import ./garden.nix {config = config; pkgs = pkgs;};
hvac-vaillant = import ./hvac-vaillant.nix {config = config; pkgs = pkgs;};
hvac-wtw = import ./hvac-wtw.nix {config = config; pkgs = pkgs;};
water = import ./water.nix;
energy = import ./energy.nix;
media = import ./media.nix;
wfh = import ./wfh.nix;
lights = import ./lights.nix;
hvac = import ./hvac.nix {config = config; pkgs = pkgs; lib = lib;};
plugs = import ./plugs.nix;

in 

with lib;
{

  imports = [
    ./people.nix
  ];

  services.zigbee2mqtt.settings = {
    devices = zigbeeDevices;
    external_converters = [
    ];
    availability = true;
  };

  services.home-assistant = {
    config."automation manual" = 
      lights.automations
      ++ hvac.automations
      ++ hvac-vaillant.automations
      ++ hvac-wtw.automations
      ++ wfh.automations
      ++ media.automations
      ++ plugs.automations
      ++ energy.automations
      ++ charger-bluecorner.automations
      ++ charger.automations
      ++ garden.automations;

    config.binary_sensor = [ ] 
    ++ wfh.binary_sensor
    ++ solar.binary_sensor
    ++ charger-bluecorner.binary_sensor
    ++ charger.binary_sensor
    ++ garden.binary_sensor
    ++ hvac-vaillant.binary_sensor
    ++ hvac-wtw.binary_sensor;


    config.mqtt = {
      binary_sensor = [] 
        ++ water.mqtt.binary_sensor
        ++ hvac-wtw.mqtt.binary_sensor;

      sensor = []
        ++ water.mqtt.sensor
        ++ charger-bluecorner.mqtt_sensor
        ++ garden.mqtt_sensor
        ++ hvac-wtw.mqtt.sensor;
      
      climate = []
        ++ hvac-vaillant.mqtt.climate;

      fan = []
        ++ hvac-wtw.mqtt.fan;


    };

    config.homeassistant.customize = {} 
      // energy.customize
      // solar.customize
      // charger-bluecorner.customize
      // charger.customize
      // garden.customize;

    config.sensor = []
      ++ energy.sensor
      ++ solar.sensor
      ++ charger-bluecorner.sensor
      ++ charger.sensor
      ++ garden.sensor        
      ++ hvac-vaillant.sensor
      ++ hvac-wtw.sensor;

    config.scrape = []
      ++ energy.scrape
      ++ garden.scrape;      

    config.utility_meter = { } 
      // water.utility_meter
      // energy.utility_meter
      // solar.utility_meter
      // charger-bluecorner.utility_meter
      // garden.utility_meter;

    config.template = [] 
      ++ energy.template
      ++ water.template
      ++ hvac.template
      ++ media.template
      ++ solar.template
      ++ charger-bluecorner.template
      ++ charger.template
      ++ garden.template
      ++ hvac-wtw.template 
      ++ hvac-vaillant.template;

    config.recorder.exclude.entity_globs = []
      ++ charger-bluecorner.recorder_excludes
      ++ charger.recorder_excludes
      ++ hvac.recorder_excludes
      ++ solar.recorder_excludes
      ++ garden.recorder_excludes
      ++ hvac-vaillant.recorder_excludes
      ++ hvac-wtw.recorder_excludes;

    config.climate = []
      ++ hvac-vaillant.climate
      ++ hvac-wtw.climate;



  };
}

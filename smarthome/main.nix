{ config, lib, pkgs, ... }:
let

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
        ++ plugs.devices
      )
    );

solar = import ./solar.nix {config = config;};
bluecorner = import ./bluecorner.nix {config = config; pkgs = pkgs;};
garden = import ./garden.nix {config = config; pkgs = pkgs;};
hvac-vaillant = import ./hvac-vaillant.nix {config = config; pkgs = pkgs;};
water = import ./water.nix;
energy = import ./energy.nix;
media = import ./media.nix;
wfh = import ./wfh.nix;
lights = import ./lights.nix;
hvac = import ./hvac.nix;
plugs = import ./plugs.nix;
general = import ./general.nix;

in 

with lib;
{

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
      ++ wfh.automations
      ++ media.automations
      ++ plugs.automations
      ++ energy.automations
      ++ bluecorner.automations
      ++ garden.automations;

    config.binary_sensor = [ ] 
    ++ wfh.binary_sensor
    ++ solar.binary_sensor
    ++ bluecorner.binary_sensor
    ++ garden.binary_sensor
    ++ hvac-vaillant.binary_sensor;


    config.mqtt = {
      binary_sensor = [] 
        ++ water.mqtt.binary_sensor

      sensor = []
        ++ water.mqtt.sensor
        ++ bluecorner.mqtt_sensor
        ++ garden.mqtt_sensor;

    };

    config.homeassistant.customize = {} 
      // energy.customize
      // solar.customize
      // bluecorner.customize
      // garden.customize;

    config.sensor = []
      ++ energy.sensor
      ++ solar.sensor
      ++ bluecorner.sensor
      ++ garden.sensor;

    config.scrape = []
      ++ energy.scrape
      ++ garden.scrape;      

    config.utility_meter = { } 
      // water.utility_meter
      // energy.utility_meter
      // solar.utility_meter
      // bluecorner.utility_meter
      // garden.utility_meter;

    config.template = [] 
      ++ energy.template
      ++ water.template
      ++ general.template
      ++ hvac.template
      ++ media.template
      ++ solar.template
      ++ bluecorner.template
      ++ garden.template;

    config.recorder.exclude.entity_globs = []
      ++ bluecorner.recorder_excludes
      ++ hvac.recorder_excludes
      ++ solar.recorder_excludes
      ++ garden.recorder_excludes
      ++ hvac-vaillant.recorder_excludes;

    config.climate = []
      ++ hvac-vaillant.climate;

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

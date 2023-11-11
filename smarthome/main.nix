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
hvac-wtw = import ./hvac-wtw.nix {config = config; pkgs = pkgs;};
water = import ./water.nix;
energy = import ./energy.nix;
media = import ./media.nix;
lights = import ./lights.nix;
hvac = import ./hvac.nix {config = config; pkgs = pkgs; lib = lib;};
plugs = import ./plugs.nix;

in 

with lib;
{

  imports = [
    ./location.nix
    ./calendar.nix
    ./weather.nix
    ./air_quality.nix
    ./doorbell.nix
    ./hvac/vaillant.nix
    ./hvac/temperature.nix
    ./hvac/electric_heating.nix
    ./hvac/rtv.nix
    ./energy/powercalc.nix
    ./energy/tariffs.nix
    ./energy/car_charger/volvo.nix
    ./energy/car_charger/car_charger.nix
    ./energy/appliances/dishwasher.nix
    ./energy/solar/battery.nix
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
      ++ hvac-wtw.automations
      ++ media.automations
      ++ plugs.automations
      ++ energy.automations;

    config.binary_sensor = [ ] 
    ++ solar.binary_sensor
    ++ hvac-wtw.binary_sensor;


    config.mqtt = {
      binary_sensor = [] 
        ++ water.mqtt.binary_sensor
        ++ hvac-wtw.mqtt.binary_sensor;

      sensor = []
        ++ water.mqtt.sensor
        ++ hvac-wtw.mqtt.sensor;

      fan = []
        ++ hvac-wtw.mqtt.fan;


    };

    config.homeassistant.customize = {} 
      // energy.customize
      // solar.customize;

    config.sensor = []
      ++ energy.sensor
      ++ solar.sensor      
      ++ hvac-wtw.sensor;

    config.utility_meter = { } 
      // water.utility_meter
      // energy.utility_meter
      // solar.utility_meter;

    config.template = [] 
      ++ energy.template
      ++ water.template
      ++ hvac.template
      ++ media.template
      ++ solar.template
      ++ hvac-wtw.template;

    config.recorder.exclude.entity_globs = []
      ++ hvac.recorder_excludes
      ++ solar.recorder_excludes
      ++ hvac-wtw.recorder_excludes;

    config.climate = []
      ++ hvac-wtw.climate;

  };
}

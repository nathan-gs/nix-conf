{ config, lib, pkgs, ... }:
let

solar = import ./solar.nix {config = config;};
water = import ./water.nix;
energy = import ./energy.nix;
media = import ./media.nix;
plugs = import ./plugs.nix;

in 

with lib;
{

  imports = [
    ./zigbee.nix
    ./occupancy/location.nix
    ./calendar.nix
    ./weather.nix
    ./air_quality.nix
    ./doorbell.nix
    ./waste.nix
    ./lights.nix
    ./occupancy/rooms.nix
    ./hvac/vaillant.nix
    ./hvac/room_temperature.nix
    ./hvac/temperature.nix
    ./hvac/ventilation.nix
    ./hvac/electric_heating.nix
    ./hvac/rtv.nix
    ./energy/powercalc.nix
    ./energy/tariffs.nix
    ./energy/capacity_peaks.nix
    ./energy/car_charger/volvo.nix
    ./energy/car_charger/car_charger.nix
    ./energy/appliances/dishwasher.nix
    ./energy/solar/battery.nix
  ];


  services.home-assistant = {
    config."automation manual" = 
      media.automations
      ++ plugs.automations
      ++ energy.automations;

    config.binary_sensor = [ ] 
    ++ solar.binary_sensor;

    config.mqtt = {
      binary_sensor = [] 
        ++ water.mqtt.binary_sensor;

      sensor = []
        ++ water.mqtt.sensor;

      fan = [];


    };

    config.homeassistant.customize = {} 
      // energy.customize
      // solar.customize;

    config.sensor = []
      ++ energy.sensor
      ++ solar.sensor;

    config.utility_meter = { } 
      // water.utility_meter
      // energy.utility_meter
      // solar.utility_meter;

    config.template = [] 
      ++ energy.template
      ++ water.template
      ++ media.template
      ++ solar.template;

    config.recorder.exclude.entity_globs = []
      ++ solar.recorder_excludes;

    config.climate = [];

  };
}

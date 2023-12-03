{ config, lib, pkgs, ... }:
let

solar = import ./solar.nix {config = config;};
energy = import ./energy.nix;

in 

with lib;
{

  imports = [
    ./air_quality.nix
    ./appliances/deken.nix
    ./appliances/dishwasher.nix
    ./appliances/tv.nix
    ./calendar.nix
    ./doorbell.nix
    ./energy/capacity_peaks.nix
    ./energy/car_charger/car_charger.nix
    ./energy/powercalc.nix
    ./energy/solar/battery.nix
    ./energy/tariffs.nix
    ./hvac/electric_heating.nix
    ./hvac/room_temperature.nix
    ./hvac/rtv.nix
    ./hvac/temperature.nix
    ./hvac/vaillant.nix
    ./hvac/ventilation.nix
    ./lights.nix
    ./occupancy/location.nix
    ./occupancy/rooms.nix
    ./waste.nix
    ./water.nix
    ./weather.nix
    ./zigbee.nix
  ];


  services.home-assistant = {
    config."automation manual" = 
      ++ energy.automations;

    config.binary_sensor = [ ] 
    ++ solar.binary_sensor;

    config.homeassistant.customize = {} 
      // energy.customize
      // solar.customize;

    config.sensor = []
      ++ energy.sensor
      ++ solar.sensor;

    config.utility_meter = { } 
      // energy.utility_meter
      // solar.utility_meter;

    config.template = [] 
      ++ energy.template
      ++ solar.template;

    config.recorder.exclude.entity_globs = []
      ++ solar.recorder_excludes;

  };
}

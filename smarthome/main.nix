{ config, lib, pkgs, ... }:
let

energy = import ./energy.nix;

in 

with lib;
{

  imports = [
    ./air_quality.nix
    ./appliances/deken.nix
    ./appliances/dishwasher.nix
    ./appliances/lights.nix
    ./appliances/tv.nix
    ./calendar.nix
    ./doorbell.nix
    ./energy/capacity_peaks.nix
    ./energy/car_charger/car_charger.nix
    ./energy/powercalc.nix
    ./energy/solar/battery.nix
    ./energy/solar/solis_local.nix
    ./energy/tariffs.nix
    ./hvac/electric_heating.nix
    ./hvac/room_temperature.nix
    ./hvac/rtv.nix
    ./hvac/temperature.nix
    ./hvac/vaillant.nix
    ./hvac/ventilation.nix
    ./occupancy/location.nix
    ./occupancy/rooms.nix
    ./waste.nix
    ./water.nix
    ./weather.nix
    ./zigbee.nix
  ];


  services.home-assistant = {
    config."automation manual" = []
      ++ energy.automations;

    config.homeassistant.customize = {} 
      // energy.customize;

    config.sensor = []
      ++ energy.sensor;

    config.utility_meter = { } 
      // energy.utility_meter;

    config.template = [] 
      ++ energy.template;

  };
}

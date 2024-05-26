{ config, lib, pkgs, ... }:

{

  imports = [
    ./air_quality
    ./appliances
    ./calendar.nix
    ./doorbell.nix
    ./energy
    ./ha
    ./hvac
    ./occupancy
    ./waste.nix
    ./water.nix
    ./weather.nix
    ./zigbee.nix
  ];
}

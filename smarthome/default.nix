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
    ./recorder.nix
    ./waste.nix
    ./water.nix
    ./weather.nix
    ./zigbee.nix
  ];
}

{ config, lib, pkgs, ... }:

{

  imports = [
    ./air_quality
    ./appliances
    ./calendar.nix
    ./car
    ./dashboards.nix
    ./doorbell.nix
    ./energy
    ./ha
    ./hvac
    ./occupancy
    ./recorder.nix
    ./system
    ./waste.nix
    ./water.nix
    ./weather.nix
    ./zigbee.nix
  ];
}

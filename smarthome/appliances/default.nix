{ config, lib, pkgs, ... }:

{

  imports = [
    ./always_on.nix
    ./deken.nix
    ./dishwasher.nix
    ./kiosk.nix
    ./lights.nix
    ./pump.nix
    ./sonos.nix
    ./tv.nix
    ./vacuum.nix
  ];

  
}
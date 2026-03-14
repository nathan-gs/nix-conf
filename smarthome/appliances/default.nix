{ config, lib, pkgs, ... }:

{

  imports = [
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
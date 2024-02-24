{ config, lib, pkgs, ... }:

{

  imports = [
    ./car_charger
    ./solar
    ./capacity_peaks.nix
    ./demand_management.nix
    ./legacy.nix
    ./powercalc.nix
    ./tariffs.nix
  ];
}
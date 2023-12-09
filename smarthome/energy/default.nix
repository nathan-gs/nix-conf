{ config, lib, pkgs, ... }:

{

  imports = [
    ./car_charger
    ./solar
    ./capacity_peaks.nix
    ./legacy.nix
    ./powercalc.nix
    ./tariffs.nix
  ];
}
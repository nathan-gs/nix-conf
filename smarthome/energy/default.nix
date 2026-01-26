{ config, lib, pkgs, ... }:

{

  imports = [
    ./solar
    ./capacity_peaks.nix
    ./demand_management.nix
    ./electricity.nix
    ./legacy.nix
    ./powercalc.nix
    ./tariffs.nix
  ];


}
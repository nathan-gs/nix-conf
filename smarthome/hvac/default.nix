{ config, lib, pkgs, ... }:

{

  imports = [
    ./degree_days.nix
    ./electric_heating.nix
    ./room.nix
    ./rtv.nix
    ./temperature.nix
    ./vaillant.nix
    ./ventilation.nix
    ./ventilation_valve.nix
  ];
}
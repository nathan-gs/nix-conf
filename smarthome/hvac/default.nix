{ config, lib, pkgs, ... }:

{

  imports = [
    ./degree_days.nix
    ./electric_heating.nix
    ./room_temperature.nix
    ./rtv.nix
    ./temperature.nix
    ./vaillant.nix
    ./ventilation.nix
  ];
}
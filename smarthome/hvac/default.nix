{ config, lib, pkgs, ... }:

{

  imports = [
    ./electric_heating.nix
    ./room_temperature.nix
    ./rtv.nix
    ./temperature.nix
    ./vaillant.nix
    ./ventilation.nix
  ];
}
{ config, lib, pkgs, ... }:

{

  imports = [
    ./battery.nix
    ./solis_local.nix
  ];
}
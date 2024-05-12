{ config, lib, pkgs, ... }:

{

  imports = [
    ./deken.nix
    ./dishwasher.nix
    ./lights.nix
    ./pump.nix
    ./tv.nix
  ];
}
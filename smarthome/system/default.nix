{ config, lib, pkgs, ... }:

{
  imports = [
    ./servers.nix
    ./network.nix
  ];
}

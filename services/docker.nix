{ config, pkgs, lib, ... }:
{
  virtualisation.docker = {
    enable = true;
  };

  environment.systemPackages = [
    pkgs.docker-compose
  ];
}
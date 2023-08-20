{ config, pkgs, lib, ... }:
{
  imports = [
    ./smarthome/main.nix
    ./services/mosquitto.nix
    ./services/ebusd.nix
    ./services/zigbee2mqtt.nix
    ./services/home-assistant.nix
  ];

}

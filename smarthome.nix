{ config, pkgs, lib, ... }:
{
  imports = [
    ./smarthome
    ./services/mosquitto.nix
    ./services/ebusd.nix
    ./services/zigbee2mqtt.nix
    ./services/home-assistant.nix
  ];

}

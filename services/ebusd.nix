{ config, pkgs, lib, ... }:
{
  imports = [
    ../apps/ebusd-module.nix
  ];

  services.ebusd = {
    enable = true;
    device = "ebus:3333";
    mqtt = {
      enable = true;
      host = "localhost";
      user = "ebus";
      password = config.secrets.mqtt.users.ebus.password;
      home-assistant = true;
      retain = true;
    };
    logs = {
      main = "info";
      network = "notice";
      bus = "error";
      update = "error";
      other = "notice";
      all = "error";
    };
  };

}

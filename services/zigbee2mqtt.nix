{ config, pkgs, lib, ... }:
{
  networking.firewall.allowedTCPPorts = [ 8080 ];
  
  services.zigbee2mqtt = {
    enable = true;
    package = pkgs.zigbee2mqtt;
    settings = {
      homeassistant =  {
        # otherwise RTVs don't report temp + calibration 
        legacy_entity_attributes = true;
        legacy_triggers = false;
      };
      permit_join = false;
      serial.port = "/dev/ttyUSB0";
      frontend = true;
      device_options = {
        retain = true;
      };
      advanced = {
        channel = 25;
        network_key = config.secrets.zigbee2mqtt.networkKey;
        log_output = [ "console" ];
        log_level = "warn";
      };
      mqtt = {
        version = 5;
        server = "mqtt://localhost:1883";
        user = "zigbee2mqtt";
        password =  config.secrets.mqtt.users.zigbee2mqtt.password;
      };
    };
  };

}

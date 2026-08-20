{ config, pkgs, lib, ... }:
{
  networking.firewall.allowedTCPPorts = [ 8080 ];
  
  systemd.services.zigbee2mqtt = {
    after = [ "mosquitto.service" ];
    wants = [ "mosquitto.service" ];
  };

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
      serial = {
        port = "/dev/serial/by-id/usb-ITead_Sonoff_Zigbee_3.0_USB_Dongle_Plus_72b6fe6b0c86ec1183d1591719c2d21c-if00-port0";
        adapter = "ember";
      };
      frontend = true;
      device_options = {
        retain = true;
      };
      advanced = {
        channel = 25;
        network_key = config.secrets.zigbee2mqtt.networkKey;
        log_output = [ "console" ];
        log_level = "warning";
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

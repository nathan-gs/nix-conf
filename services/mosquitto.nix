{ config, pkgs, lib, ... }:
{
  services.mosquitto = {
    enable = true;
    listeners = 
    [
      {
        users = {
          homeassistant = {
            acl = ["readwrite #"];
              password = config.secrets.mqtt.users.homeassistant.password;
            };
            zigbee2mqtt = {
              acl = ["readwrite zigbee2mqtt/#" "readwrite homeassistant/#" ];
              password = config.secrets.mqtt.users.zigbee2mqtt.password;
            };
            smartgatewayp1 = {
              acl = ["readwrite dsmr/#"];
              password = config.secrets.mqtt.users.smartgatewayp1.password;
            };
            smartgatewaywater = {
              acl = ["readwrite watermeter/#"];
              password = config.secrets.mqtt.users.smartgatewaywater.password;
            };
            ebus = {
              acl = ["readwrite ebusd/#" "readwrite homeassistant/#" ];
              password = config.secrets.mqtt.users.ebus.password;
            };
            tasmota = {
              acl = ["readwrite tasmota/#"];
              password = config.secrets.mqtt.users.tasmota.password;
            };
            itho = {
              acl = ["readwrite itho/#" "readwrite homeassistant/#" ];
              password = config.secrets.mqtt.users.itho.password;
            };
            sos2mqtt = {
              acl = ["readwrite irceline/#" "readwrite homeassistant/#" ];
              password = config.secrets.mqtt.users.sos2mqtt.password;
            };
            soliscontrol = {
              acl = ["readwrite solar/#" "readwrite homeassistant/#" ];
              password = config.secrets.mqtt.users.soliscontrol.password;
            };
        };
        
        port = 1883;
      }            
    ];
  };
  
  networking.firewall.allowedTCPPorts = [ 1883 ];
}

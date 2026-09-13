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
            freekiosk = {
              acl = ["readwrite kiosk/#" "readwrite homeassistant/#" ];
              password = config.secrets.mqtt.users.freekiosk.password;
            };
            pylontech2mqtt = {
              acl = ["readwrite pylontech/#"];
              password = config.secrets.mqtt.users.pylontech2mqtt.password;
            };
            # Both nhtpc and nnas publish here; nnas connects over WireGuard.
            # Needs homeassistant/# for the MQTT discovery configs it registers.
            server-health2mqtt = {
              acl = ["readwrite system/network/server/#" "readwrite homeassistant/#" ];
              password = config.secrets.mqtt.users.server-health2mqtt.password;
            };
        };
        
        port = 1883;
      }            
    ];
  };
  
  networking.firewall.allowedTCPPorts = [ 1883 ];
}

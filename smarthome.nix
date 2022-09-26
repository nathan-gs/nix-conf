
{ config, pkgs, ... }:

{
    services.mosquitto = {
        enable = true;
        listeners.smarthome = {
            users = {
                homeassistant = {
                    acl = ["readwrite /#"];
                    password = config.secrets.mosquitto.users.homeassistant.password;
                };
                zigbee2mqtt = {
                    acl = ["readwrite zigbee2mqtt/#"];
                    password = config.secrets.mosquitto.users.zigbee2mqtt.password;
                };
            };
            port = 1883;
            
        };

    };

    networking.firewall.allowedTCPPorts = [ 1883 8080 ];

    services.home-assistant = {
        enable  = true;
        openFirewall = true;
        config = {
            name = "SXW";
            latitude = config.secrets.home-assistant.latitude;
            longitude = config.secrets.home-assistant.longitude;
            unit_system = "metric";            
        };
        extraComponents = [
            "analytics"
            "api"
            "apple_tv"
            "buienradar"
            "command_line"
            "default_config"
            "dsmr"
            "forecast_solar"
            "fritzbox"
            "mqtt"
            "sonos"
            "worxlandroid"
        ];
    };

    services.zigbee2mqtt = {
        enable = false;
        settings = {
            homeassistant =  config.services.home-assistant.enable;
            permit_join = true;
            serial.port = "/dev/ttyACM1";
            frontend = true;

            mqtt = {
                server = "mqtt://localhost:1883";
                user = "zigbee2mqtt";
                password =  config.secrets.mosquitto.users.zigbee2mqtt.password;
            };
        };
    };
}
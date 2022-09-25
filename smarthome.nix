
{ config, pkgs, ... }:

{
    services.mosquitto = {
        enable = true;
    };

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
        };
    };
}
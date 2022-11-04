
{ config, pkgs, ... }:

{
  imports = [
    ./smarthome/devices.nix
  ];

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
        };
        
        port = 1883;
      }            
    ];
  };
  
  networking.firewall.allowedTCPPorts = [ 1400 1883 8080 ];

  services.home-assistant = {
    enable  = true;
    openFirewall = true;
    configWritable = false;
    config = {
      default_config = {};
      met = {};
      backup = {};
      homeassistant = {
        name = "SXW";
        latitude = config.secrets.home-assistant.latitude;
        longitude = config.secrets.home-assistant.longitude;
        unit_system = "metric";            
        time_zone = "Europe/Brussels";
        packages = "!include_dir_named packages";
      };
      prometheus = {
        namespace = "ha";
      };
     
      mqtt = {};
      lovelace = {
        resources = [
          {
            url = "/local/apexcharts-card.js?v=2.0.1";
            type = "module";
          }
        ];
      };
      "automation ui" = "!include automations.yaml";
    };
    lovelace = {};
        
    extraComponents = [
      "apple_tv"
      "backup"
      "command_line"
      "default_config"
      "dsmr"
      "ffmpeg"      
      "my"            
      "mqtt"
      "plex"
      "ping"
      "prometheus"
      "sensor"
      "sonos"
      "scrape"
      "volvooncall"
      "radio_browser"
      "utility_meter"
    ];

    extraPackages = python3Packages: with python3Packages; [
      spotipy
      pyipp
      soco
      pyatv
      croniter
    ];

    package = pkgs.nixpkgs-unstable.home-assistant;

  };
  

  services.zigbee2mqtt = {
    enable = true;
    package = pkgs.nixpkgs-unstable.zigbee2mqtt;
    settings = {
      homeassistant =  config.services.home-assistant.enable;
      permit_join = true;
      serial.port = "/dev/ttyUSB0";
      frontend = true;
      advanced = {
        channel = 25;
        network_key = config.secrets.zigbee2mqtt.networkKey;
        log_output = [ "console" ];
      };
      mqtt = {
        server = "mqtt://localhost:1883";
        user = "zigbee2mqtt";
        password =  config.secrets.mqtt.users.zigbee2mqtt.password;
      };
    };
  };
}

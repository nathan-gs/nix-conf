
{ config, pkgs, lib, ... }:
{
  imports = [
    ./smarthome/main.nix
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
        country = "BE";
        #packages = "!include_dir_named packages";
      };
      prometheus = {
        namespace = "ha";
        filter.include_domains = [
          "sensor"
          "binary_sensor"
          "switch"
          "weather"
          "sun"
          "person"
        ];
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

    #lovelaceConfig = {};
        
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
      "http"
      "api"
      "forecast_solar"
      "openweathermap"
    ];

    extraPackages = python311Packages: with python311Packages; [
      spotipy
      pyipp
      soco
      pyatv
      croniter
      aiohttp
      aiohttp-cors
      zha-quirks
      hap-python
      pyqrcode
      bellows
      zigpy-deconz
      zigpy-xbee
      (python311Packages.callPackage apps/pyelectroluxconnect.nix {})
    ];

    #package = pkgs.nixpkgs-unstable.home-assistant;
  };

  systemd.services.home-assistant-backup = {
    description = "home-assistant-backup"; 
    path = [ ];
    script = ''
      mv /var/lib/hass/backups/* /media/documents/nathan/onedrive_nathan_personal/backup/homeassistant/
      chown nathan:users /media/documents/nathan/onedrive_nathan_personal/backup/homeassistant/*
    '';
    startAt = "*-*-* 03:42:00";
  };

  
  system.activationScripts.ha-custom_components.text = ''
    mkdir -p "/var/lib/hass/custom_components"
    ln -snf "${(pkgs.callPackage ./apps/ha-solis-sensor.nix {})}" "/var/lib/hass/custom_components/solis"
    ln -snf "${(pkgs.callPackage ./apps/ha-hon.nix {})}" "/var/lib/hass/custom_components/hon"
    ln -snf "${(pkgs.callPackage ./apps/ha-electrolux-status.nix {})}" "/var/lib/hass/custom_components/electrolux_status"
  '';  

  services.zigbee2mqtt = {
    enable = true;
    package = pkgs.nixpkgs-unstable.zigbee2mqtt;
    settings = {
      homeassistant =  config.services.home-assistant.enable;
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

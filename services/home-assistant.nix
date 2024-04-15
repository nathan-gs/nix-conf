{ config, pkgs, lib, ... }:
{

  _module.args.ha = import ../lib/ha.nix { lib = lib; };

  networking.firewall.allowedTCPPorts = [ 1400 ];

  services.nginx.virtualHosts."ha.nathan.gs" = {
    forceSSL = true;
    enableACME = true;
    locations."/" = {
      proxyPass = "http://127.0.0.1:8123";
      proxyWebsockets = true; # needed if you need to use WebSocket
      extraConfig =
        # required when the target is also TLS server with multiple hosts
        "proxy_ssl_server_name on;" +
        # required when the server wants to use HTTP Authentication
        "proxy_pass_header Authorization;"
        ;
    };
  };

  services.home-assistant = {
    enable  = true;
    openFirewall = true;
    configWritable = false;
    config = {
      default_config = {};
      backup = {};
      homeassistant = {
        name = "SXW";
        latitude = config.secrets.home-assistant.latitude;
        longitude = config.secrets.home-assistant.longitude;
        unit_system = "metric";            
        time_zone = "Europe/Brussels";
        country = "BE";
        #packages = "!include_dir_named packages";
        external_url = "https://ha.nathan.gs";
        internal_url = "https://ha.nathan.gs";
      };
      http = {
        use_x_forwarded_for = true;
        trusted_proxies = [ "127.0.0.1" ];
        ip_ban_enabled = true;
        login_attempts_threshold = 5;
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
            url = "/local/apexcharts-card.js?v=2.0.4";
            type = "module";
          }
          {
            url = "/local/fan-mode-button-row.js";
            type = "module";
          }
          {
            url = "/local/auto-entities.js";
            type = "module";
          }
        ];
      };
      "automation ui" = "!include automations.yaml";
      recorder = {
        purge_keep_days = 365;
      };
    };

    #lovelaceConfig = {};
        
    extraComponents = [
      "api"
      "apple_tv"
      "auth"
      "backup"
      "command_line"
      "default_config"
      "dsmr"
      "ebusd"
      "ffmpeg"      
      "fritz"
      "forecast_solar"
      "homekit_controller"
      "homekit"
      "http"
      "met"
      "mqtt"
      "my"            
      "openweathermap"
      "ping"
      "plex"
      "prometheus"
      "proximity"
      "radio_browser"
      "scrape"
      "sensor"
      "smartthings"
      "sonos"
      "tasmota"
      "utility_meter"
      "volvooncall"
    ];

    extraPackages = ps: with ps; [
      aiohomekit
      aiohttp
      bellows
      croniter
      getmac
      hap-python
      pyipp
      pyotp
      pyqrcode
      soco
      spotipy
      zha-quirks
      zigpy-deconz
      zigpy-xbee
      zigpy-zigate
      zigpy-znp
    ];

    customComponents = [
      (pkgs.callPackage ../pkgs/home-assistant/custom_components/solis-sensor.nix {})
      (pkgs.callPackage ../pkgs/home-assistant/custom_components/hon.nix {})
      (pkgs.callPackage ../pkgs/home-assistant/custom_components/electrolux-status.nix {})
      (pkgs.callPackage ../pkgs/home-assistant/custom_components/indego.nix {})
      (pkgs.callPackage ../pkgs/home-assistant/custom_components/powercalc.nix {})
      (pkgs.callPackage ../pkgs/home-assistant/custom_components/afvalbeheer.nix {})
    ];
  };

  systemd.services.home-assistant-backup = {
    description = "home-assistant-backup"; 
    path = [ pkgs.gnutar pkgs.gzip pkgs.sqlite ];
    unitConfig = {
      RequiresMountsFor = "/media/documents";
    };
    script = ''
      mkdir -pm 0775 /media/documents/nathan/onedrive_nathan_personal/backup/
      target='/media/documents/nathan/onedrive_nathan_personal/backup/'
      
      tar \
        --exclude automations.yaml \
        --exclude backups \
        --exclude blueprints \
        --exclude configuration.yaml \
        --exclude custom_components \
        --exclude 'home-assistant_v2*' \
        --exclude ui-lovelace.yaml \
        -czf \
        /tmp/hass.tar.gz \
        -C /var/lib \
        hass
      
      chown nathan /tmp/hass.tar.gz
      mv /tmp/hass.tar.gz "$target/hass.tar.gz"

      sqlite3 /var/lib/hass/home-assistant_v2.db .dump | gzip -c > /tmp/home-assistant_v2.db.gz
      
      chown nathan /tmp/home-assistant_v2.db.gz
      mv /tmp/home-assistant_v2.db.gz "$target/home-assistant_v2.db.gz"
      '';

    startAt = "*-*-* 03:42:00";
  };

  # needs copy, HA does not follow symlinks
  # https://github.com/home-assistant/core/pull/42295
  system.activationScripts.ha-www.text = ''
    mkdir -p "/var/lib/hass/www"
    cp "${(pkgs.callPackage ../pkgs/home-assistant/ui/fan-mode-button-row.nix {})}" "/var/lib/hass/www/fan-mode-button-row.js"
    cp "${(pkgs.callPackage ../pkgs/home-assistant/ui/apexcharts-card.nix {})}" "/var/lib/hass/www/apexcharts-card.js"
    cp "${(pkgs.callPackage ../pkgs/home-assistant/ui/auto-entities.nix {})}" "/var/lib/hass/www/auto-entities.js"
  '';
}

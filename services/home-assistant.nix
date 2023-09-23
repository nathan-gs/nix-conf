{ config, pkgs, lib, ... }:
{

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
            url = "/local/apexcharts-card.js?v=2.0.1";
            type = "module";
          }
        ];
      };
      "automation ui" = "!include automations.yaml";
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
      "forecast_solar"
      "homekit_controller"
      "homekit"
      "http"
      "mqtt"
      "my"            
      "openweathermap"
      "ping"
      "plex"
      "prometheus"
      "radio_browser"
      "scrape"
      "sensor"
      "smartthings"
      "sonos"
      "utility_meter"
      "volvooncall"
    ];

    extraPackages = ps: with ps; [
      (callPackage ../apps/pyelectroluxconnect.nix {})
      (callPackage ../apps/pyindego.nix {})
      #(callPackage ../apps/pyworxcloud.nix {})
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

  
  system.activationScripts.ha-custom_components.text = ''
    mkdir -p "/var/lib/hass/custom_components"
    ln -snf "${(pkgs.callPackage ../apps/ha-solis-sensor.nix {})}" "/var/lib/hass/custom_components/solis"
    ln -snf "${(pkgs.callPackage ../apps/ha-hon.nix {})}" "/var/lib/hass/custom_components/hon"
    ln -snf "${(pkgs.callPackage ../apps/ha-electrolux-status.nix {})}" "/var/lib/hass/custom_components/electrolux_status"
    ln -snf "${(pkgs.callPackage ../apps/ha-indego.nix {})}" "/var/lib/hass/custom_components/indego"
  '';  

}
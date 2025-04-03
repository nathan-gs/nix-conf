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
        "proxy_pass_header Authorization;";
    };
  };

  environment.etc."fail2ban/filter.d/home-assistant.conf".source = ./fail2ban/home-assistant.conf;

  services.fail2ban.jails = {
    home-assistant = {
      filter = "home-assistant";
      enabled = true;
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
        db_url = "mysql://hass:${config.secrets.mariadb.hass}@localhost/hass?unix_socket=/run/mysqld/mysqld.sock&charset=utf8mb4";
        purge_keep_days = 3650;
        auto_purge = true;
        auto_repack = true;
      };
    };

    #lovelaceConfig = {};
        
    extraComponents = [
      "api"
      "apple_tv"
      "application_credentials"
      "auth"
      "backup"
      "bayesian"
      "bluetooth"
      "buienradar"
      "camera"
      "command_line"
      "conversation"
      "default_config"
      "dsmr"
      "ebusd"
      "ffmpeg"      
      "forecast_solar"
      "fritz"
      "homekit_controller"
      "homekit"
      "http"
      "ibeacon"
      "lawn_mower"
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
      "spotify"
      "sun"
      "switchbot"
      "switchbot_cloud"
      "tasmota"
      "template"
      "utility_meter"
      "vacuum"
      "valve"
      "zha"
    ];

    extraPackages = ps: with ps; [
      mysqlclient
      aiohomekit
      aiohttp
      aiohttp-zlib-ng      
      bellows
      croniter
      isal
      getmac
      hap-python
      pyipp
      pyotp
      pyqrcode
      (ps.callPackage ../pkgs/python/pyswitchbot.nix {})
      soco
      #spotipy
      universal-silabs-flasher
      zha-quirks
      zigpy-deconz
      zigpy-xbee
      zigpy-zigate
      zigpy-znp
    ];

    customComponents = [
      # pkgs.nixosUnstable.home-assistant-custom-components.indego
      (pkgs.callPackage ../pkgs/home-assistant/custom_components/indego.nix {pyindego = pkgs.python312Packages.pyindego;})
      pkgs.home-assistant-custom-components.solis-sensor
      (pkgs.callPackage ../pkgs/home-assistant/custom_components/hon.nix {})
      (pkgs.callPackage ../pkgs/home-assistant/custom_components/electrolux-status.nix {})
      (pkgs.callPackage ../pkgs/home-assistant/custom_components/powercalc.nix {})
      (pkgs.callPackage ../pkgs/home-assistant/custom_components/afvalbeheer.nix {})
      (pkgs.callPackage ../pkgs/home-assistant/custom_components/volvo-cars.nix {})
    ];

    customLovelaceModules = with pkgs.home-assistant-custom-lovelace-modules; [
      apexcharts-card
    ];
  };

  systemd.services.home-assistant-backup = {
    description = "home-assistant-backup"; 
    path = [ pkgs.gnutar pkgs.gzip ];
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
        --exclude home-assistant.log* \
        --exclude www \
        -czf \
        /tmp/hass.tar.gz \
        -C /var/lib \
        hass
      
      chown nathan /tmp/hass.tar.gz
      mv /tmp/hass.tar.gz "$target/hass.tar.gz"
      '';

    startAt = "*-*-* 03:42:00";
  };

  # needs copy, HA does not follow symlinks
  # https://github.com/home-assistant/core/pull/42295
  system.activationScripts.ha-www.text = ''
    mkdir -p "/var/lib/hass/www"
    cp "${(pkgs.callPackage ../pkgs/home-assistant/ui/fan-mode-button-row.nix {})}" "/var/lib/hass/www/fan-mode-button-row.js"
    cp "${(pkgs.callPackage ../pkgs/home-assistant/ui/auto-entities.nix {})}" "/var/lib/hass/www/auto-entities.js"
  '';

}

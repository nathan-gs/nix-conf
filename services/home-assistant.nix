{ config, pkgs, channels, nixpkgs-unstable, lib, ... }:
{

  imports = [
    "${channels.nixpkgs-unstable}/nixos/modules/services/home-automation/home-assistant.nix"
  ];
  disabledModules = [
    "services/home-automation/home-assistant.nix"
  ];

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

    package = pkgs.nixpkgs-unstable.home-assistant;

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
      "bmw_connected_drive"
      "buienradar"
      "camera"
      "command_line"
      "conversation"
      "default_config"
      "dsmr"
      "ebusd"
      "esphome"
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
      "ohme"
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
      aiohttp-fast-zlib      
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

    customComponents = with pkgs.nixpkgs-unstable.home-assistant-custom-components; [
      # pkgs.nixosUnstable.home-assistant-custom-components.indego
      (pkgs.nixpkgs-unstable.callPackage ../pkgs/home-assistant/custom_components/indego.nix {pyindego = pkgs.nixpkgs-unstable.python313Packages.pyindego;})
      solis-sensor
      (pkgs.nixpkgs-unstable.callPackage ../pkgs/home-assistant/custom_components/hon.nix { pkgs = pkgs.nixpkgs-unstable; })
      #(pkgs.callPackage ../pkgs/home-assistant/custom_components/ohme.nix {})
      (pkgs.nixpkgs-unstable.callPackage ../pkgs/home-assistant/custom_components/electrolux-status.nix { pkgs = pkgs.nixpkgs-unstable; })
      (pkgs.nixpkgs-unstable.callPackage ../pkgs/home-assistant/custom_components/powercalc.nix { pkgs = pkgs.nixpkgs-unstable; })
      (pkgs.nixpkgs-unstable.callPackage ../pkgs/home-assistant/custom_components/afvalbeheer.nix { pkgs = pkgs.nixpkgs-unstable; })
      #(pkgs.callPackage ../pkgs/home-assistant/custom_components/volvo-cars.nix {})
    ];

    customLovelaceModules = with pkgs.nixpkgs-unstable.home-assistant-custom-lovelace-modules; [
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

  systemd.services.home-assistant-states-cleanup = {
    description = "home-assistant-states-cleanup"; 
    path = [ pkgs.mariadb ];
    unitConfig = {
      RequiresMountsFor = "/media/documents";
    };
    environment = {
      DB_USER="hass";
      DB_PASS=config.secrets.mariadb.hass;
      DB_NAME="hass";
    };
    script = ''


      # SQL queries to clean states and statistics_short_term, and optimize tables
      SQL_QUERIES=$(cat << 'EOF'

      -- Delete from states table (excluding latitude/longitude attributes and all binary entity types)
      DELETE s
      FROM states s
      LEFT JOIN state_attributes ON s.attributes_id = state_attributes.attributes_id
      LEFT JOIN states_meta sm ON s.metadata_id = sm.metadata_id
      WHERE s.last_updated_ts < UNIX_TIMESTAMP(DATE_SUB(NOW(), INTERVAL 10 DAY))
        AND (state_attributes.shared_attrs IS NULL
            OR (state_attributes.shared_attrs NOT LIKE '%latitude%'
                AND state_attributes.shared_attrs NOT LIKE '%longitude%'))
        AND (sm.entity_id NOT LIKE 'binary_sensor.%'
            AND sm.entity_id NOT LIKE 'switch.%'
            AND sm.entity_id NOT LIKE 'input_boolean.%'
            AND sm.entity_id NOT LIKE 'lock.%'
            AND sm.entity_id NOT LIKE 'alarm_control_panel.%'
            AND sm.entity_id NOT LIKE 'cover.%'
            AND sm.entity_id NOT LIKE 'light.%'
            AND sm.entity_id NOT LIKE 'fan.%'
            AND sm.entity_id NOT LIKE 'climate.%'
            AND sm.entity_id NOT LIKE 'vacuum.%'
            AND sm.entity_id NOT LIKE 'media_player.%');
        
      -- Delete from statistics_short_term table (older than 60 days)
      DELETE FROM statistics_short_term
      WHERE start_ts < UNIX_TIMESTAMP(DATE_SUB(NOW(), INTERVAL 60 DAY));    

      -- Delete orphaned rows from state_attributes table
      DELETE sa
      FROM state_attributes sa
      LEFT JOIN states s ON s.attributes_id = sa.attributes_id
      WHERE s.attributes_id IS NULL;

      COMMIT;
      EOF
      )

      # Execute SQL queries
      echo "Starting database cleanup for $DB_NAME"
      echo "$SQL_QUERIES" | mariadb -u "$DB_USER" -p"$DB_PASS" "$DB_NAME"      
      if [ $? -eq 0 ]; then
          echo "Database cleanup completed successfully"
      else
          echo "ERROR: Database cleanup failed"
          exit 1
      fi
      
      echo "Starting database optimize for $DB_NAME"
      echo "OPTIMIZE TABLE states, state_attributes, statistics_short_term;" | mariadb -u "$DB_USER" -p"$DB_PASS" "$DB_NAME"
      if [ $? -eq 0 ]; then
          echo "Database cleanup optimize successfully"
      else
          echo "ERROR: Database optimize failed"
          exit 1
      fi
    '';

    startAt = "*-*-* 00:01:00";
  };

  # needs copy, HA does not follow symlinks
  # https://github.com/home-assistant/core/pull/42295
  system.activationScripts.ha-www.text = ''
    mkdir -p "/var/lib/hass/www"
    cp "${(pkgs.callPackage ../pkgs/home-assistant/ui/fan-mode-button-row.nix {})}" "/var/lib/hass/www/fan-mode-button-row.js"
    cp "${(pkgs.callPackage ../pkgs/home-assistant/ui/auto-entities.nix {})}" "/var/lib/hass/www/auto-entities.js"
  '';

}

{ config, pkgs, lib, ... }:

{

  services.photoprism = {
    enable = true;
    storagePath = "/var/lib/photoprism";
    originalsPath = "/media/documents/nathan/onedrive_nathan_personal/fn-fotos";
    importPath = "${config.services.photoprism.storagePath}/import";
    settings = {
      PHOTOPRISM_DISABLE_BACKUPS = "true";
      PHOTOPRISM_FACE_SCORE = "5";
      PHOTOPRISM_AUTH_MODE = "public";
      PHOTOPRISM_ORIGINALS_LIMIT = "-1";
      PHOTOPRISM_DETECT_NSFW = "false";
      PHOTOPRISM_SITE_URL = "https://photoprism.nathan.gs/";
      PHOTOPRISM_LOG_LEVEL = "info";
    };
  };

  services.nginx.virtualHosts."photoprism.nathan.gs" = {
    forceSSL = true;
    enableACME = true;
    locations."/" = {
      proxyPass = "http://127.0.0.1:2342";
      proxyWebsockets = true; # needed if you need to use WebSocket
      extraConfig =
        ''
          # required when the target is also TLS server with multiple hosts
          proxy_ssl_server_name on;
          # required when the server wants to use HTTP Authentication
          proxy_pass_header Authorization;
          # PAM Auth
          auth_pam "Password Required";
          auth_pam_service_name nginx;
        '';
    };
    locations."/slideshow" = {
      proxyPass = "http://127.0.0.1:${toString config.services.photoprism-slideshow.port}";
      extraConfig =
        ''
          # required when the target is also TLS server with multiple hosts
          proxy_ssl_server_name on;
          # required when the server wants to use HTTP Authentication
          proxy_pass_header Authorization;
          # PAM Auth
          auth_pam "Password Required";
          auth_pam_service_name nginx;
        '';
    };
  };

  services.photoprism-slideshow = {
    enable = true;
    preload = true;
  };

  systemd.services.photoprism.serviceConfig = {
    DynamicUser = lib.mkOverride 0 false;
    User = lib.mkOverride 0 "nathan";
    Group = lib.mkOverride 0 "media";
  };

  # https://docs.photoprism.app/user-guide/backups/restore/
  systemd.services.photoprism-backup = {
    description = "Photoprism Backup";
    path = [ pkgs.gnutar pkgs.gzip pkgs.sqlite ];
    unitConfig = {
      RequiresMountsFor = "/media/documents";
    };
    serviceConfig = {
      User = "nathan";
    };
    script = ''
       mkdir -pm 0775 /media/documents/nathan/onedrive_nathan_personal/backup/
       target='/media/documents/nathan/onedrive_nathan_personal/backup/photoprism-index.db.gz'
       
       sqlite3 /var/lib/photoprism/index.db .dump | gzip -c > /tmp/photoprism-index.db.gz

       mv /tmp/photoprism-index.db.gz $target
      '';
    startAt = "*-*-* 01:00:00";
  };

  systemd.services.photoprism-prioritize = {
    description = "Power Save scripts";
    wantedBy = [ "multi-user.target" ];
    path = [ pkgs.gawk pkgs.busybox ];
    script =
      ''
      # Function to convert month abbreviations to numbers
      function month_to_num() {
        case "$1" in
          Jan) echo 1 ;;
          Feb) echo 2 ;;
          Mar) echo 3 ;;
          Apr) echo 4 ;;
          May) echo 5 ;;
          Jun) echo 6 ;;
          Jul) echo 7 ;;
          Aug) echo 8 ;;
          Sep) echo 9 ;;
          Oct) echo 10 ;;
          Nov) echo 11 ;;
          Dec) echo 12 ;;
        esac
      }

      function ts() {
        date_string=$1
        # Extract date components using awk
        day=$(echo "$date_string" | awk -F'[][/: ]+' '{print $2}')
        month=$(month_to_num $(echo "$date_string" | awk -F'[][/: ]+' '{print $3}'))
        year=$(echo "$date_string" | awk -F'[][/: ]+' '{print $4}')
        hour=$(echo "$date_string" | awk -F'[][/: ]+' '{print $5}')
        minute=$(echo "$date_string" | awk -F'[][/: ]+' '{print $6}')
        second=$(echo "$date_string" | awk -F'[][/: ]+' '{print $7}')

        # Create a timestamp for the given date
        timestamp=$(date -d "$year-$month-$day $hour:$minute:$second" '+%s')
        echo $timestamp
      }

      function get_last_log() {
        grep 'photoprism' /var/log/nginx/access.log |
        grep -v '/slideshow' |
        tail -n 1 |
        awk -v FPAT='\\[[^][]*]|"[^"]*"|\\S+' '{ print $4}'
      }

      current_prio=0
      function photoprism_prioritize() {
        if [ "$current_prio" != "300" ]; then
          current_prio=300
          systemctl set-property --runtime photoprism.service CPUQuota=300%
          echo "systemctl set-property --runtime photoprism.service CPUQuota=300%"
        fi
      }

      function photoprism_deprioritize() {
        if [ "$current_prio" != "20" ]; then
          current_prio=20
          systemctl set-property --runtime photoprism.service CPUQuota=20%
          echo "systemctl set-property --runtime photoprism.service CPUQuota=20%"
        fi
      }

      while true; do

        ts_from_log=$(ts $(get_last_log))
        current_timestamp=$(date '+%s')

        # Calculate the difference in seconds
        seconds_ago=$((current_timestamp - ts_from_log))

        if [ "$seconds_ago" -gt 360 ]; then
          photoprism_deprioritize
          sleep 10
        else
          photoprism_prioritize
          sleep 360
        fi

      done
  
      '';
  }; 

}

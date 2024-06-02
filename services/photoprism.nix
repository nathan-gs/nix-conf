{ config, pkgs, lib, ... }:

{

  users.groups.media.members = [ "photoprism" ];
  users.groups.users.members = ["photoprism" ];

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
    package = pkgs.nixpkgs-unstable.photoprism;
  };

  services.nginx.virtualHosts."photoprism.nathan.gs" = {
    forceSSL = true;
    enableACME = true;
    basicAuth = config.secrets.nginx.basicAuth;
    locations."/" = {
      proxyPass = "http://127.0.0.1:2342";
      proxyWebsockets = true; # needed if you need to use WebSocket
      extraConfig =
        ''
          # required when the target is also TLS server with multiple hosts
          proxy_ssl_server_name on;
          # required when the server wants to use HTTP Authentication
          proxy_pass_header Authorization;
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
        '';
    };

    locations."/db" = {
      proxyPass = "http://127.0.0.1:2344";
      extraConfig =
        ''
          # required when the target is also TLS server with multiple hosts
          proxy_ssl_server_name on;
          # required when the server wants to use HTTP Authentication
          proxy_pass_header Authorization;
        '';
    };
  };

  services.photoprism-slideshow = {
    enable = true;
    preload = true;
    interval = 60;
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
    script = ''source ${./photoprism-prioritize.sh}'';
  };

  systemd.services.photoprism-db = {
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    unitConfig = {
      RequiresMountsFor = "/media/documents";
    };
    serviceConfig = {
      ExecStart = ''
          ${pkgs.sqlite-web}/bin/sqlite_web \
            --port 2344 \
            --no-browser \
            --url-prefix "/db" \
            /var/lib/photoprism/index.db
        '';
      User = "nathan";      
    };
    environment.SSL_CERT_FILE = "/etc/ssl/certs/ca-bundle.crt";
    wantedBy = ["multi-user.target"];
  };

}

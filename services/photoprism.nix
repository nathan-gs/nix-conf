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
    script = ''source ${./photoprism-prioritize.sh}'';
  }; 

}

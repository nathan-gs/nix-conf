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
      PHOTOPRISM_FACE_SCORE = "5";
      PHOTOPRISM_AUTH_MODE = "public";
      PHOTOPRISM_ORIGINALS_LIMIT = "-1";
      PHOTOPRISM_DETECT_NSFW = "false";
      PHOTOPRISM_SITE_URL = "https://photoprism.nathan.gs/";
      PHOTOPRISM_LOG_LEVEL = "info";
      PHOTOPRISM_DATABASE_DRIVER = "mysql";
      PHOTOPRISM_DATABASE_NAME = "photoprism";
      PHOTOPRISM_DATABASE_USER = "photoprism";
      PHOTOPRISM_DATABASE_PASSWORD = config.secrets.mariadb.photoprism;
      PHOTOPRISM_DATABASE_SERVER = "/run/mysqld/mysqld.sock";
      PHOTOPRISM_SIDECAR_YAML = "false";
      PHOTOPRISM_WORKERS = "2";
      PHOTOPRISM_DISABLE_BACKUPS = "true";
      PHOTOPRISM_DISABLE_RESTART = "true";
      PHOTOPRISM_DISABLE_WEBDAV = "true";
      PHOTOPRISM_DEBUG = "true";
      PHOTOPRISM_DISABLE_TLS = "true";
      PHOTOPRISM_DISABLE_VIPS = "true";
      PHOTOPRISM_THUMB_SIZE = "1280";
    };
    package = pkgs.photoprism;
  };

  # DNS-01 so the cert also covers photoprism.l.nathan.gs / photoprism.wg.nathan.gs, which
  # only resolve on the LAN/WireGuard and can't satisfy an HTTP-01 challenge.
  security.acme.certs."photoprism.nathan.gs" = {
    group = "nginx";
    dnsProvider = "cloudflare";
    environmentFile = pkgs.writeText "acme-photoprism-cloudflare-env" ''
      CLOUDFLARE_EMAIL=${config.secrets.cloudflare.authEmail}
      CLOUDFLARE_API_KEY=${config.secrets.cloudflare.authKey}
    '';
    extraDomainNames = [ "photoprism.l.nathan.gs" "photoprism.wg.nathan.gs" ];
  };

  services.nginx.virtualHosts."photoprism.nathan.gs" = {
    forceSSL = true;
    useACMEHost = "photoprism.nathan.gs";
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

  };

  # LAN/WireGuard names: no basic auth, reachable over both http and https.
  # addSSL (not forceSSL) so port 80 keeps serving instead of redirecting; useACMEHost
  # alone does not create a TLS listener - hasSSL is set only by addSSL/onlySSL/forceSSL.
  services.nginx.virtualHosts."photoprism.l.nathan.gs" = {
    addSSL = true;
    useACMEHost = "photoprism.nathan.gs";
    serverAliases = [ "photoprism.wg.nathan.gs" ];
    # This vhost has no basicAuth and PHOTOPRISM_AUTH_MODE is "public", so the
    # source ACL is the only gate. It serves no public name, so deny outright
    # rather than using the $homenet_reject guard.
    extraConfig = config.homeNetwork.nginxLanOnly;
    locations."/" = {
      proxyPass = "http://127.0.0.1:2342";
      proxyWebsockets = true; # needed if you need to use WebSocket
      extraConfig =
        ''
          # required when the target is also TLS server with multiple hosts
          proxy_ssl_server_name on;
          # required when the server wants to use HTTP Authentication
        '';
    };
    locations."/slideshow" = {
      proxyPass = "http://127.0.0.1:${toString config.services.photoprism-slideshow.port}";
      extraConfig =
        ''
          # required when the target is also TLS server with multiple hosts
          proxy_ssl_server_name on;
          # required when the server wants to use HTTP Authentication
        '';
    };

  };

  services.photoprism-slideshow = {
    enable = true;
    dsn = "jdbc:mysql://photoprism:${config.secrets.mariadb.photoprism}@localhost/photoprism?unix_socket=/run/mysqld/mysqld.sock&charset=utf8mb4";
    interval = 60;
  };

  # JVM exits with 143 (128+SIGTERM) on normal shutdown; treat as success
  systemd.services.photoprism-slideshow.serviceConfig.SuccessExitStatus = "143";

  systemd.services.photoprism = {
    unitConfig.RequiresMountsFor = "/media/documents";
    after = [ "media-documents.mount" ];
    wants = [ "media-documents.mount" ];
    serviceConfig = {
      DynamicUser = lib.mkOverride 0 false;
      User = lib.mkOverride 0 "nathan";
      Group = lib.mkOverride 0 "media";
    };
  };



  systemd.services.photoprism-prioritize = {
    description = "Power Save scripts";
    wantedBy = [ "multi-user.target" ];
    path = [ pkgs.gawk pkgs.busybox ];
    script = ''source ${./photoprism-prioritize.sh}'';
  };

  services.mysql = {
    ensureDatabases = [ "photoprism" ];
    ensureUsers = [
      {
        name = "photoprism";
        ensurePermissions = {
          "photoprism.*" = "ALL PRIVILEGES";
        };
      }
    ];
  };


}

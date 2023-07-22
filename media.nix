{ config, pkgs, lib, ... }:

{

  imports = [
    ./apps/calibre-economist.nix
    #./apps/media-scraper.nix
    #./apps/photoprism.nix
  ];
#  services.calibre-server.enable = true;

  nixpkgs.config.allowUnfree = true;

  services.plex = {
    enable = true;
    openFirewall = true;
  };
 
  users.groups.media.members = ["plex" "photoprism" ];
  users.groups.users.members = ["photoprism" ];


  systemd.services.plex = {
    unitConfig = {
      RequiresMountsFor = "/media/media";
    };
    serviceConfig.ExecStart = lib.mkOverride 0 "${config.services.plex.package}/bin/plexmediaserver > /dev/null";
  };

  services.nginx.virtualHosts."plex.nathan.gs" = {
    forceSSL = true;
    enableACME = true;
    locations."/" = {
      proxyPass = "http://127.0.0.1:32400";
      proxyWebsockets = true; # needed if you need to use WebSocket
      extraConfig =
        ''
          # required when the target is also TLS server with multiple hosts
          proxy_ssl_server_name on;
          # required when the server wants to use HTTP Authentication
          proxy_pass_header Authorization;
          
          proxy_buffering off;          
        '';
    };
  };


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
  };

  systemd.services.photoprism.serviceConfig = {
    DynamicUser = lib.mkOverride 0 false;
    User = lib.mkOverride 0 "nathan";
    Group = lib.mkOverride 0 "media";
  };

  systemd.services.photoprism-backup = {
    description = "Photoprism Backup";
    path = [ pkgs.gnutar pkgs.gzip ];
    unitConfig = {
      RequiresMountsFor = "/media/documents";
    };
    serviceConfig = {
      User = "nathan";
    };
    script = ''
       mkdir -pm 0775 /media/documents/nathan/onedrive_nathan_personal/backup/
       target='/media/documents/nathan/onedrive_nathan_personal/backup/photoprism-fn-fotos.tar.gz'
       tar \
         --exclude "import" \
         --exclude "backup" \
         --exclude "cache" \
         --exclude "originals" \
         -czf \
         /tmp/photoprism-fn-fotos.tar.gz \
         -C /var/lib \
         photoprism

       mv /tmp/photoprism-fn-fotos.tar.gz $target
      '';
    startAt = "*-*-* 01:00:00";
  };
  
  # Plex Monitoring
  services.tautulli.enable = false;
 
}

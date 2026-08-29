{ config, pkgs, lib, ... }:

{

  services.komga = {
    enable = true;
    user = "nathan";
    settings.server.port = 32142;
    openFirewall = true;
  };

  systemd.services.komga.environment.LD_LIBRARY_PATH = lib.mkAfter (lib.makeLibraryPath [
    pkgs.libarchive
    pkgs.libjxl
    pkgs.libheif
  ]);

  # DNS-01 so the cert also covers read.l.nathan.gs / read.wg.nathan.gs, which
  # only resolve on the LAN/WireGuard and can't satisfy an HTTP-01 challenge.
  security.acme.certs."read.nathan.gs" = {
    group = "nginx";
    dnsProvider = "cloudflare";
    environmentFile = pkgs.writeText "acme-read-cloudflare-env" ''
      CLOUDFLARE_EMAIL=${config.secrets.cloudflare.authEmail}
      CLOUDFLARE_API_KEY=${config.secrets.cloudflare.authKey}
    '';
    extraDomainNames = [ "read.l.nathan.gs" "read.wg.nathan.gs" ];
  };

  services.nginx.virtualHosts."read.nathan.gs" = {
    forceSSL = true;
    useACMEHost = "read.nathan.gs";
    serverAliases = [ "read.l.nathan.gs" "read.wg.nathan.gs" ];
    extraConfig = ''
      proxy_buffering off;
    '';
    basicAuth = config.secrets.nginx.basicAuth;
    locations."/" = {
      proxyPass = "http://127.0.0.1:32142";
      proxyWebsockets = true; # needed if you need to use WebSocket
      extraConfig = ''
        # required when the target is also TLS server with multiple hosts
        proxy_ssl_server_name on;
        # required when the server wants to use HTTP Authentication
        proxy_pass_header Authorization;

        proxy_set_header X-Real-IP          $remote_addr;
        proxy_set_header X-Forwarded-For    $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto  $scheme;
      '';
    };
  };

}

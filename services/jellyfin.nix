{ config, pkgs, lib, ... }:

{

  nixpkgs.config.allowUnfree = true;

  services.jellyfin = {
    enable = true;
    openFirewall = true;
    group = "media";
  };

  users.groups.media.members = [ "jellyfin" ];


  # DNS-01 so the cert also covers m.l.nathan.gs / m.wg.nathan.gs, which only
  # resolve on the LAN/WireGuard and can't satisfy an HTTP-01 challenge.
  security.acme.certs."m.nathan.gs" = {
    group = "nginx";
    dnsProvider = "cloudflare";
    environmentFile = pkgs.writeText "acme-m-cloudflare-env" ''
      CLOUDFLARE_EMAIL=${config.secrets.cloudflare.authEmail}
      CLOUDFLARE_API_KEY=${config.secrets.cloudflare.authKey}
    '';
    extraDomainNames = [ "m.l.nathan.gs" "m.wg.nathan.gs" ];
  };

  services.nginx.virtualHosts."m.nathan.gs" = {
    forceSSL = true;
    useACMEHost = "m.nathan.gs";
    serverAliases = [ "m.l.nathan.gs" "m.wg.nathan.gs" ];
    locations."/" = {
      proxyPass = "http://127.0.0.1:8096";
      proxyWebsockets = true; # needed if you need to use WebSocket
      extraConfig =
        ''
          # required when the target is also TLS server with multiple hosts
          proxy_ssl_server_name on;
          # required when the server wants to use HTTP Authentication
          proxy_pass_header Authorization;

          client_max_body_size 0;
          proxy_redirect off;
          proxy_buffering off;
        '';
    };
  };

  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      intel-media-driver
      intel-vaapi-driver
      intel-compute-runtime
      vpl-gpu-rt
    ];
  };

}

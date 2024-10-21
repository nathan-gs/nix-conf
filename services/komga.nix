{ config, pkgs, lib, ... }:

{

  services.komga = {
    enable = true;
    user = "nathan";
    port = 32142;
    openFirewall = true;
  };

  services.nginx.virtualHosts."read.nathan.gs" = {
    forceSSL = true;
    enableACME = true;
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

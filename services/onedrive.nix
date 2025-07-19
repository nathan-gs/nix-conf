
{ config, pkgs, ... }:

{

  systemd.services.onedrive_nathan_personal = {
    description = "Onedrive Nathan";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    unitConfig = {
      RequiresMountsFor = "/media/documents";
    };
    path = [pkgs.openssl];
    serviceConfig = {
      ExecStart = "${(pkgs.callPackage ../pkgs/onedrive-2.5.nix {})}/bin/onedrive --monitor --confdir=/var/lib/onedrive/onedrive_nathan_personal --verbose";
      #ExecStart = "${pkgs.onedrive}/bin/onedrive --monitor --confdir=/var/lib/onedrive/onedrive_nathan_personal";
      User = "nathan";
    };
    environment.SSL_CERT_FILE = "/etc/ssl/certs/ca-bundle.crt";
    wantedBy = ["multi-user.target"];
  };

  services.nginx.virtualHosts."onedrive.nathan.gs" = {
    forceSSL = true;
    enableACME = true;
    locations."/webhooks/onedrive" = {
      proxyPass = "http://127.0.0.1:8888";
      proxyWebsockets = true; # needed if you need to use WebSocket
      extraConfig =
        ''
          # required when the target is also TLS server with multiple hosts
          proxy_ssl_server_name on;
          # required when the server wants to use HTTP Authentication
        '';
    };

    locations."/" = {
      extraConfig = "return 403;";
    };

  };

}



{ config, lib, pkgs, ... }:

{
  systemd.services.onedrive_nathan_personal = {
    description = "Onedrive Nathan";
    after = [ "network-online.target" "media-documents.mount" ];
    wants = [ "network-online.target" "media-documents.mount" ];
    unitConfig = {
      RequiresMountsFor = "/media/documents";
    };
    path = [ pkgs.openssl ];
    serviceConfig = {
      ExecStart = "${pkgs.onedrive}/bin/onedrive --monitor --confdir=/var/lib/onedrive/onedrive_nathan_personal";
      User = "nathan";
      Restart = "on-failure";
      RestartSec = "60s";
    };
    environment.SSL_CERT_FILE = "/etc/ssl/certs/ca-bundle.crt";
    wantedBy = [ "multi-user.target" ];
  };

  # Webhook endpoint only needed on the interactive sync host (nhtpc).
  # nnas runs download_only and does not expose nginx for this.
  services.nginx.virtualHosts = lib.mkIf (config.networking.hostName == "nhtpc") {
    "onedrive.nathan.gs" = {
      forceSSL = true;
      enableACME = true;
      locations."/webhooks/onedrive" = {
        proxyPass = "http://127.0.0.1:8888";
        proxyWebsockets = true;
        extraConfig = ''
          proxy_ssl_server_name on;
        '';
      };
      locations."/" = {
        extraConfig = "return 403;";
      };
    };
  };
}

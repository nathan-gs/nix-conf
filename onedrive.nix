
{ config, pkgs, ... }:

{

  systemd.services.onedrive_nathan_personal = {
    description = "Onedrive Nathan";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    unitConfig = {
      RequiresMountsFor = "/media/documents";
    };
    serviceConfig = {
      ExecStart = "${pkgs.onedrive}/bin/onedrive --monitor --verbose --confdir=/media/documents/nathan/.config/onedrive_nathan_personal";
      User = "nathan";
    };
    environment.SSL_CERT_FILE = "/etc/ssl/certs/ca-bundle.crt";
    wantedBy = ["multi-user.target"];
  };


}



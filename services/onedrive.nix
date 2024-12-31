
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
      ExecStart = "${(pkgs.callPackage ../pkgs/onedrive-2.4.nix {})}/bin/onedrive --monitor --confdir=/var/lib/onedrive/onedrive_nathan_personal";
      User = "nathan";
    };
    environment.SSL_CERT_FILE = "/etc/ssl/certs/ca-bundle.crt";
    wantedBy = ["multi-user.target"];
  };


}



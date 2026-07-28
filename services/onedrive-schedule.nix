{ config, lib, pkgs, ... }:

{
  # Scheduled oneshot sync for low-power backup hosts (nnas).
  # Avoids a permanent --monitor process burning CPU/RAM on Atom + SMR.
  systemd.services.onedrive_nathan_personal = {
    description = "Onedrive Nathan (scheduled sync)";
    after = [ "network-online.target" "media-documents.mount" ];
    wants = [ "network-online.target" "media-documents.mount" ];
    unitConfig = {
      RequiresMountsFor = "/media/documents";
    };
    path = [ pkgs.openssl ];
    serviceConfig = {
      Type = "oneshot";
      # --synchronize: one full pass then exit (download_only set in confdir).
      ExecStart = "${pkgs.onedrive}/bin/onedrive --synchronize --confdir=/var/lib/onedrive/onedrive_nathan_personal";
      User = "nathan";
      Nice = 15;
      IOSchedulingClass = "idle";
      IOSchedulingPriority = 7;
      # Large tree walk on slow disks can take a while.
      TimeoutStartSec = "6h";
    };
    environment.SSL_CERT_FILE = "/etc/ssl/certs/ca-bundle.crt";
  };

  systemd.timers.onedrive_nathan_personal = {
    description = "Scheduled Onedrive sync";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*-*-* 09:00:00";
      Persistent = true;
      RandomizedDelaySec = "15m";
    };
  };
}

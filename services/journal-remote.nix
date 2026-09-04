# Receives nnas's journald over the existing nhtpc<->nnas WireGuard link
# (services/wireguard.nix) and stores it under /var/log/journal/remote/.
#
# No TLS: the wg0 tunnel is already encrypted/authenticated, and the
# journal-remote port is firewalled to wg0 only below, so plain HTTP is fine
# here and avoids managing a second set of certs.
{ config, pkgs, lib, ... }:

let
  port = config.services.journald.remote.port;

  # journal-remote doesn't hook into journald's own SystemMaxUse/vacuuming —
  # files under /var/log/journal/remote/ just accumulate forever otherwise.
  vacuumScript = pkgs.writeShellScript "journal-remote-vacuum" ''
    set -euo pipefail
    ${pkgs.systemd}/bin/journalctl --directory=/var/log/journal/remote \
      --vacuum-size=5G --vacuum-time=60d
  '';
in
{
  services.journald.remote = {
    enable = true;
    listen = "http";
    settings.Remote.SplitMode = "host"; # one file per source host
  };

  # Only nnas (over wg0) may reach this port — not the LAN or internet.
  networking.firewall.interfaces.wg0.allowedTCPPorts = [ port ];

  systemd.services.journal-remote-vacuum = {
    description = "Vacuum old remote journal files (nnas forwarding)";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = vacuumScript;
      User = "root";
    };
  };

  systemd.timers.journal-remote-vacuum = {
    description = "Vacuum old remote journal files (nnas forwarding) timer";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "daily";
      RandomizedDelaySec = "1h";
      Persistent = true;
    };
  };

  environment.systemPackages = [
    (pkgs.writeShellScriptBin "journalctl-nnas" ''
      exec ${pkgs.systemd}/bin/journalctl --directory=/var/log/journal/remote "$@"
    '')
    (pkgs.writeShellScriptBin "journalctl-all" ''
      # --directory only covers one dir, and default (no --directory) search
      # doesn't descend into remote/ — so glob both explicitly via --file.
      exec ${pkgs.systemd}/bin/journalctl \
        --file=/var/log/journal/*/*.journal \
        --file=/var/log/journal/remote/*.journal \
        "$@"
    '')
  ];
}

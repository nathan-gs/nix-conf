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
      --vacuum-size=2G
  '';
in
{
  services.journald.remote = {
    enable = true;
    listen = "http";
    settings.Remote = {
      SplitMode = "host"; # one file per source host

      # Without explicit limits journal-remote never rotates and the single
      # remote-<ip>.journal just grows, so keep these set.
      #
      # They are not, however, what causes the recurring "microhttpd:
      # Application reported internal error" here (and "Empty reply from
      # server" on nnas). That was blamed on a 32M ceiling; running
      # journal-remote at SYSTEMD_LOG_LEVEL=debug on 2026-09-13 showed the real
      # error, which the default log level hides entirely:
      #
      #   ZSTD decoded less data than indicated, probably corrupted stream.
      #   Queueing response 400: Decompression of received blob failed.
      #   microhttpd: Application reported internal error, closing connection.
      #
      # journald compresses data objects over ~512 B with zstd; journal-remote
      # intermittently fails to decompress one, answers 400 and drops the
      # connection. Both hosts run the same systemd (260.2), the wg link
      # measured 0% loss / 31 ms RTT, MaxFileSize is applied correctly and the
      # file was nowhere near any ceiling — so this is a systemd bug, not a
      # limit or a network problem. Entries are not lost: journal-upload
      # resumes from its saved cursor and the retry succeeds (verified by
      # shipping 300, 3000 and 4000 entries, all of which arrived). Rate scales
      # with the volume of large entries: ~10/day normally, far more under load.
      #
      # Journal-file corruption is ruled out too, though it looked promising:
      # the then-active file failed `journalctl --verify` ("Bad message"), so it
      # was rotated out to corrupt-nnas-20260913.journal.bak and journal-remote
      # opened a fresh one that PASSes. Replaying the identical 4000-entry burst
      # against that clean file still produced the same errors, and the file
      # still PASSed afterwards. So corruption is neither the cause nor an
      # immediate consequence — rotating the file does not fix this.
      #
      # Do not put a reverse proxy in front of this hoping to fix it: the
      # failure is journal-remote's own handling of the payload, after a
      # complete and successful HTTP receive. journal-upload does no HTTP
      # compression at all (no Content-Encoding/gzip/zstd in the binary), so
      # there is no transport-level encoding for a proxy to normalise, and an
      # extra hop on a long-lived streaming PUT only adds its own timeouts.
      MaxFileSize = "128M";
      MaxUse = "2G";
      MaxFiles = 20;
    };
  };

  # Only nnas (over wg0) may reach this port — not the LAN or internet.
  networking.firewall.interfaces.wg0.allowedTCPPorts = [ port ];

  # Files land 0640 systemd-journal-remote:systemd-journal-remote — unlike
  # the local journal dir, which grants wheel/adm read via ACL, journal-remote
  # sets none.
  users.users.nathan.extraGroups = [ "systemd-journal-remote" ];

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

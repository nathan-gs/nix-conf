{ config, pkgs, lib, ... }:

let
  stateDir = "/var/lib/media-rsync";
  identityFile = "${stateDir}/id_ed25519";
  knownHostsFile = "${stateDir}/known_hosts";
  remoteHost = "nnas.wg";
  remoteUser = "nathan";
  source = "/media/media/";
  dest = "${remoteUser}@${remoteHost}:/media/media/";

  # Key material from secrets (same pattern as wireguard private keys).
  identitySource = pkgs.writeText "media-rsync-id_ed25519" config.secrets.ssh.nhtpc-backup.private;

  # nnas host keys (ed25519) — pinned for non-interactive StrictHostKeyChecking
  knownHostsSource = pkgs.writeText "media-rsync-known_hosts" ''
    nnas.wg ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINuzacgoV7F8Ep4qwnovJZIDOoSea2mrghb7E2LNWFJz
    10.73.221.2 ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINuzacgoV7F8Ep4qwnovJZIDOoSea2mrghb7E2LNWFJz
  '';

  sshOpts = lib.concatStringsSep " " [
    "-i ${identityFile}"
    "-o IdentitiesOnly=yes"
    "-o UserKnownHostsFile=${knownHostsFile}"
    "-o StrictHostKeyChecking=yes"
    "-o BatchMode=yes"
    "-o ServerAliveInterval=60"
    "-o ServerAliveCountMax=5"
    "-o ConnectTimeout=30"
  ];

  rsyncScript = pkgs.writeShellScript "media-rsync" ''
    set -euo pipefail

    echo "=== media-rsync $(date -Is) ==="
    echo "Source: ${source}"
    echo "Dest:   ${dest}"

    # Mirror /media/media → nnas. Videos are already compressed; skip -z.
    # --partial/--partial-dir: resume multi-day first sync over a slow link.
    # --delete-after: only remove dest files after the transfer succeeds.
    # --bwlimit intentionally below the ~22 Mbit router-WG path (~12 Mbit) so
    # this backup cannot saturate the inter-site link.
    #
    # It is NOT a kcompactd mitigation, despite what this comment used to say.
    # Measured 2026-09-13: nnas's soft lockups are proactive memory compaction
    # (vm.compaction_proactiveness in low-ram.nix) triggered by the onedrive
    # sync (services/onedrive-schedule.nix), not by this job. On an in-sync tree
    # this transfers 0 bytes and exits in ~10 s — the 06:04 run that day
    # finished at 06:04:19, nearly four hours before the 09:50 lockup — and
    # 1500 KB/s cannot fill an ST8000DM004's CMR cache anyway, so it never
    # reaches the SMR write cliff. Keep the limit for the link's sake; do not
    # tune it hoping to fix lockups.
    ${pkgs.rsync}/bin/rsync \
      --archive \
      --human-readable \
      --info=stats2 \
      --partial \
      --partial-dir=.rsync-partial \
      --delete-after \
      --timeout=600 \
      --bwlimit=1500 \
      --exclude='.rsync-partial/' \
      --exclude='lost+found/' \
      --exclude='tmp/' \
      -e "${pkgs.openssh}/bin/ssh ${sshOpts}" \
      ${source} \
      ${dest}

    echo "=== media-rsync finished $(date -Is) ==="
  '';
in
{
  system.activationScripts.media-rsync-credentials = lib.stringAfter [ "users" ] ''
    mkdir -p ${stateDir}
    chmod 700 ${stateDir}
    ${pkgs.coreutils}/bin/install -m 0600 ${identitySource} ${identityFile}
    ${pkgs.coreutils}/bin/install -m 0644 ${knownHostsSource} ${knownHostsFile}
  '';

  systemd.services.media-rsync = {
    description = "rsync /media/media from nhtpc to nnas (backup)";
    after = [ "network-online.target" "media-media.mount" ];
    wants = [ "network-online.target" ];
    unitConfig = {
      RequiresMountsFor = "/media/media";
    };
    path = [ pkgs.rsync pkgs.openssh pkgs.util-linux pkgs.coreutils ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${rsyncScript}";
      # First catch-up over ~22 Mbit/s can run for many days
      TimeoutStartSec = "0";
      Nice = 10;
      IOSchedulingClass = "best-effort";
      IOSchedulingPriority = 6;
    };
  };

  systemd.timers.media-rsync = {
    description = "Daily media rsync to nnas";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      # After local btrfs snapshots (03:00) and auto-upgrade (04:00/05:00)
      OnCalendar = "*-*-* 06:00:00";
      Persistent = true;
      RandomizedDelaySec = "10m";
    };
  };
}

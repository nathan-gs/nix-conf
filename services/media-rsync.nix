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
    192.168.1.201 ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINuzacgoV7F8Ep4qwnovJZIDOoSea2mrghb7E2LNWFJz
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

    if ! ${pkgs.util-linux}/bin/mountpoint -q /media/media; then
      echo "ERROR: /media/media is not mounted" >&2
      exit 1
    fi

    ${pkgs.openssh}/bin/ssh ${sshOpts} ${remoteUser}@${remoteHost} \
      '${pkgs.util-linux}/bin/mountpoint -q /media/media && test -w /media/media'

    # Mirror /media/media → nnas. Videos are already compressed; skip -z.
    # --partial/--partial-dir: resume multi-day first sync over a slow link.
    # --delete-after: only remove dest files after the transfer succeeds.
    # --bwlimit: cap at ~3 MiB/s so nnas (Atom D2701, 4 GiB RAM, SMR HDDs)
    # does not soft-lockup under write storms / kcompactd pressure.
    ${pkgs.rsync}/bin/rsync \
      --archive \
      --human-readable \
      --info=stats2 \
      --partial \
      --partial-dir=.rsync-partial \
      --delete-after \
      --timeout=600 \
      --bwlimit=3000 \
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

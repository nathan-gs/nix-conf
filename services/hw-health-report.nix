{ config, pkgs, lib, ... }:

let
  disks = config.disks;
  dataDisks = lib.imap (n: v: "/dev/disk/by-id/${v}") disks.data;
  dataPartitions = lib.imap (n: v: "/dev/disk/by-id/${v}-part1") disks.data;
  rootDisk = "/dev/disk/by-id/${disks.root}";
  allDisks = [ rootDisk ] ++ dataDisks;
  dataVolumes = disks.btrfs.volumes;

  reportScript = pkgs.writeShellScript "hw-health-report" ''
    set -euo pipefail

    HOSTNAME="${config.networking.hostName}"
    EMAIL="${config.secrets.email}"
    SUBJECT="[$HOSTNAME] Monthly Hardware Health Report - $(date '+%Y-%m')"

    body() {
      echo "Hardware Health Report for $HOSTNAME"
      echo "Generated: $(date)"
      echo ""

      # ── System ──────────────────────────────────────────────────────
      echo "=== System ==="
      echo "Uptime:  $(${pkgs.procps}/bin/uptime -p)"
      echo "Load:    $(${pkgs.coreutils}/bin/cat /proc/loadavg)"
      echo "Kernel:  $(${pkgs.coreutils}/bin/uname -r)"
      echo ""

      # ── Disk usage ──────────────────────────────────────────────────
      echo "=== Disk Usage ==="
      ${pkgs.coreutils}/bin/df -h --output=target,fstype,size,used,avail,pcent \
        | ${pkgs.gnugrep}/bin/grep -v -E '^(tmpfs|devtmpfs|/dev$|/run|/sys|/proc|/boot|Filesystem)' \
        | ${pkgs.gnugrep}/bin/grep -v '^/$' \
        || true
      echo ""
      ${pkgs.coreutils}/bin/df -h /
      echo ""

      # ── BTRFS device stats (errors) ─────────────────────────────────
      echo "=== BTRFS Device Stats (error counters) ==="
      ${lib.concatStringsSep "\n" (map (dev: ''
        echo "--- ${dev} ---"
        ${pkgs.btrfs-progs}/bin/btrfs device stats ${dev} 2>&1 || true
        echo ""
      '') dataPartitions)}

      # ── BTRFS filesystem health ──────────────────────────────────────
      echo "=== BTRFS Filesystem Usage ==="
      ${lib.concatStringsSep "\n" (map (vol: ''
        if ${pkgs.util-linux}/bin/mountpoint -q /media/${vol} 2>/dev/null; then
          echo "--- /media/${vol} ---"
          ${pkgs.btrfs-progs}/bin/btrfs filesystem usage /media/${vol} 2>&1 || true
          echo ""
        fi
      '') dataVolumes)}

      # ── SMART health summary ─────────────────────────────────────────
      echo "=== SMART Health Summary ==="
      ${lib.concatStringsSep "\n" (map (disk: ''
        echo "--- ${disk} ---"
        ${pkgs.smartmontools}/bin/smartctl -H ${disk} 2>&1 \
          | ${pkgs.gnugrep}/bin/grep -E 'SMART overall|result' || true
        ${pkgs.smartmontools}/bin/smartctl -A ${disk} 2>&1 \
          | ${pkgs.gnugrep}/bin/grep -iE \
            'Reallocated_Sector|Reported_Uncorrect|Current_Pending|Offline_Uncorrectable|Temperature_Celsius|Airflow_Temp|Power_On_Hours|Power_Cycle' \
          || true
        echo ""
      '') allDisks)}

      # ── Smartd journal errors (last 35 days) ─────────────────────────
      echo "=== Smartd Journal Errors (last 35 days) ==="
      ${pkgs.systemd}/bin/journalctl -u smartd \
        --since "35 days ago" \
        --no-pager \
        -p warning \
        2>&1 || true
      echo ""

      # ── systemd failed units ─────────────────────────────────────────
      echo "=== Failed Systemd Units ==="
      ${pkgs.systemd}/bin/systemctl list-units --state=failed --no-legend --no-pager 2>&1 || true
      echo ""

      # ── Memory ──────────────────────────────────────────────────────
      echo "=== Memory ==="
      ${pkgs.procps}/bin/free -h
      echo ""

      # ── Last scrub result ────────────────────────────────────────────
      echo "=== BTRFS Last Scrub ==="
      ${lib.concatStringsSep "\n" (map (vol: ''
        if ${pkgs.util-linux}/bin/mountpoint -q /media/${vol} 2>/dev/null; then
          echo "--- /media/${vol} ---"
          ${pkgs.btrfs-progs}/bin/btrfs scrub status /media/${vol} 2>&1 || true
          echo ""
        fi
      '') dataVolumes)}
    }

    REPORT=$(body)

    printf "From: %s\nTo: %s\nSubject: %s\nContent-Type: text/plain; charset=UTF-8\n\n%s\n" \
      "${config.networking.hostName}@nathan.gs" \
      "$EMAIL" \
      "$SUBJECT" \
      "$REPORT" \
      | ${pkgs.system-sendmail}/bin/sendmail "$EMAIL"
  '';
in
{
  systemd.services.hw-health-report = {
    description = "Monthly hardware health report email";
    path = [ pkgs.btrfs-progs pkgs.smartmontools pkgs.systemd pkgs.procps pkgs.coreutils pkgs.gnugrep pkgs.util-linux ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${reportScript}";
    };
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
  };

  systemd.timers.hw-health-report = {
    description = "Monthly hardware health report timer";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*-*-01 08:00:00";
      Persistent = true;
      RandomizedDelaySec = "30min";
    };
  };
}

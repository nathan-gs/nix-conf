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

      # This sync is what drives nnas into multi-second soft lockups. Measured
      # over 2026-09-09/10/12/13 it burns ~30 min of CPU and reads 40-42 GB from
      # disk in a ~1 h pass, to download only ~1.5 GB — i.e. it re-hashes the
      # local tree. On a 3.8 GiB host that recycles the entire page cache about
      # ten times in an hour, which fragments memory badly enough that kcompactd
      # starts migrating folios and spins in TLB-shootdown IPIs (see
      # vm.compaction_proactiveness in low-ram.nix). Every soft lockup on those
      # four days falls inside a run window of this unit.
      #
      # Nice/IOSchedulingClass above were already set and did not prevent it:
      # the problem is memory pressure, not CPU or IO share. MemoryHigh is the
      # lever that matters — it keeps the cgroup near 800M by reclaiming *inside*
      # this cgroup, so the churn no longer drives global reclaim and the
      # fragmentation that follows it. Almost all of the measured peak
      # (672M-2.3G) is reclaimable page cache from that 40 GB of reads, so this
      # throttles rather than starves.
      MemoryAccounting = true;
      MemoryHigh = "800M";
      # Hard backstop only; MemoryHigh should keep us far below it. Set well
      # above the anonymous working set so a genuine spike stalls rather than
      # gets OOM-killed mid-sync.
      MemoryMax = "1500M";
      # Yield CPU to everything else when they compete; does not cap throughput
      # when the box is otherwise idle.
      CPUWeight = 20;

      # Cap absolute CPU, which on this box is really a heat cap.
      #
      # Measured 2026-09-13: the residual soft lockups / RCU stalls that survived
      # the compaction fix are gated on temperature. The CPU's thermal threshold
      # interrupt fires in a storm — ~316/s, all on CPU0 — whenever the package
      # is above roughly 64 C, and stops dead below it:
      #
      #   65-70 C  ->  ~316 TRM/s      (counter climbing continuously)
      #   60-63 C  ->  0 TRM in 20 s   (counter completely frozen)
      #
      # Nothing is actually overheating: crit is 100 C and core_throttle_count
      # stays 0. It is a threshold-crossing storm, not throttling, most likely
      # because the kernel cannot read TjMax on this CPU ("coretemp.0: Unable to
      # read TjMax from CPU 0") and there are no ACPI thermal zones. CPU0 is the
      # HT sibling of CPU1, and CPU1 is named in every single stall — all nine
      # RCU stalls and both soft lockups of the 17:06-17:59 run fell inside the
      # hot window (17:36-17:52) and stopped when the box cooled.
      #
      # There is no software fan control to reach for: the only hwmon device is
      # coretemp, with no fan tachometers and no PWM. So the one lever left in
      # software is to generate less heat. CPUWeight alone cannot do it — weights
      # only bite under contention, and this job is usually the only heavy thing
      # running, so it happily takes a whole core and cooks the package.
      #
      # 40% is chosen from the measured profile: the run consumed 28m57s of CPU
      # over 53m12s wall, i.e. ~0.55 CPU sustained. Holding it to 0.4 should keep
      # the package under the threshold, at the cost of stretching the run to
      # roughly 70-75 min. That is fine for a 09:00 nightly job. If stalls
      # persist, lower this before reaching for anything else, and watch
      #   grep TRM /proc/interrupts
      # during the run — if that counter stays flat, the heat problem is solved
      # and any remaining stalls have a different cause.
      CPUQuota = "40%";
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

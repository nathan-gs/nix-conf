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

      # Ceiling on peak CPU so this job cannot take the whole machine. It was
      # briefly set to 40% as a *heat* cap; that rationale did not survive
      # testing and the number was far too low. Both corrections are recorded
      # here so nobody re-derives the wrong conclusion from the git history.
      #
      # The theory was that the residual stalls were gated on temperature: the
      # thermal threshold interrupt appeared to storm (~316/s, all on CPU0)
      # above ~64 C and stop dead below it. That held within a single boot, and
      # not afterwards. The 2026-09-13 22:00 run spent 32 samples at or above
      # 64 C, peaked at 66 C, and TRM stayed at exactly 0 the entire time —
      # while also logging 0 soft lockups, 0 RCU stalls and 0 clocksource
      # stalls across 3 h 20 m. So temperature was not the mechanism, or not all
      # of it; the likelier candidates are the reboot itself (which would reset
      # the thermal interrupt configuration) or nosmt (computers/nnas.nix).
      # Treat "CPU heat causes the stalls" as unproven.
      #
      # 40% was also simply a bad trade, measured on the same run:
      #
      #   quota   peak CPU   write rate   periods throttled
      #    40%      57 C      2901 KB/s        80%
      #    75%      57-58 C   4077 KB/s        51%
      #   100%      59 C      -                -
      #
      # i.e. going from 40% to a full core cost about 2 C out of a ~9 C working
      # range, while 40% blocked the job for 5452 s against 2744 s of actual
      # runtime — more than twice as long throttled as running. Note the trap in
      # judging this: average CPU usage over wall clock looked like ~0.33 and
      # suggested the cap was not binding. It was binding hard. nr_throttled /
      # nr_periods in cpu.stat is the number that answers it, not the average.
      #
      # 75% still throttles ~51% of periods, so this remains a real ceiling
      # rather than a formality, and the completed run at 75% moved 21.5 GB of
      # downloads, 26.4 GB written and 53.8 GB read with no disruption. Raising
      # it further is defensible on the thermal evidence; it has not been tested
      # against a CPU-saturating re-hash phase, which is the shape that
      # originally drove the package to 69 C.
      CPUQuota = "75%";
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

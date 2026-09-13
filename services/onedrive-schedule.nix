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

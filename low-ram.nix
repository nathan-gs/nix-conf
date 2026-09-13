{ config, pkgs, lib, ... }:

{
  # Profile for small / low-RAM hosts (nnas: Atom + ~4 GiB + small root SSD).
  # Distinct from powersave.nix (nhtpc power/ASPM); this is survival under
  # memory + disk pressure, not maximizing battery life.

  # Skip bulky generated docs in the system closure.
  documentation.enable = false;
  documentation.nixos.enable = false;
  documentation.man.enable = false;
  documentation.info.enable = false;
  documentation.doc.enable = false;

  # Cap journal on small root filesystems.
  services.journald.extraConfig = ''
    SystemMaxUse=200M
    MaxRetentionSec=1week
  '';

  # Serialized builds (follower switch / GC) — avoid thrashing weak CPUs.
  nix.settings.max-jobs = 1;
  nix.settings.cores = 1;

  # Compressed RAM swap ahead of disk swap under page-cache pressure.
  zramSwap = {
    enable = true;
    memoryPercent = 40;
  };

  # Memory policy for a 4 GiB, zram-only, spinning-disk fileserver.
  boot.kernel.sysctl = {
    # Steady writeback during bulk I/O so a burst cannot park the box in
    # writeback. Note the original rationale here ("so kcompactd does not
    # soft-lockup ... under SMR stalls") was wrong on both halves: the kcompactd
    # lockups are proactive compaction (see below), and media-rsync runs with
    # --bwlimit=1500, i.e. ~1.5 MB/s, which cannot fill the CMR cache of an
    # ST8000DM004 and so never reaches the SMR write cliff. Keeping the values
    # anyway — bounded writeback is still right on a box this small.
    "vm.dirty_background_bytes" = 64 * 1024 * 1024;   # 64 MiB
    "vm.dirty_bytes" = 256 * 1024 * 1024;              # 256 MiB

    # Swap is zram only (disk swap was removed to spare the root DOM), so a
    # swap-out is a compress-into-RAM, not a write to the slow SATA DOM. 10 was
    # correct when swapping meant touching that DOM; now it just tells the
    # kernel to avoid the cheap option and reclaim page cache instead, which on
    # this host means re-reading media metadata off spinning disks. 100 puts
    # anon and file reclaim on equal footing. Not pushed to the 150-180 often
    # suggested for zram: zstd compression is not free on a 2.13 GHz Atom, and
    # spare CPU is what this machine is shortest on.
    "vm.swappiness" = 100;

    # 200 evicts dentry/inode cache twice as eagerly as default. On a fileserver
    # that means re-stat-ing off spinning disks, and the extra reclaim churn
    # feeds the fragmentation that gave kcompactd work to do. Back to the
    # kernel default rather than the 50 usually suggested for fileservers:
    # media-rsync walks the whole tree nightly, and on 4 GiB an aggressively
    # retained dentry/inode slab from a multi-million-file traversal is its own
    # pressure problem. 100 is the middle ground; drop to 50 if metadata re-reads
    # still show up as iowait.
    "vm.vfs_cache_pressure" = 100;

    # Disable *proactive* memory compaction (default 20). This is the actual
    # cause of the recurring multi-second soft lockups on nnas, observed on
    # 2026-09-09/10/12/13. The trigger is the daily onedrive sync, which reads
    # 40+ GB in an hour on a 3.8 GiB host — see services/onedrive-schedule.nix,
    # where that is measured and capped. (Not media-rsync: every lockup falls
    # inside an onedrive run window, and media-rsync exits in ~10 s on an
    # in-sync tree.) The kcompactd stack is unambiguous:
    #
    #   kcompactd -> compact_node -> compact_zone -> migrate_pages
    #     -> migrate_pages_sync -> migrate_pages_batch -> try_to_unmap_flush
    #     -> arch_tlbbatch_flush -> on_each_cpu_cond_mask
    #     -> smp_call_function_many_cond      <- spins here, 20-75s
    #
    # compact_node called straight from kcompactd (rather than via
    # kcompactd_do_work) is the proactive path, and it migrates with
    # MIGRATE_SYNC_LIGHT. Each batch of migrated folios needs a TLB shootdown
    # broadcast to all 4 CPUs, and on this 2012 Atom D2701 an IPI round trip is
    # slow enough that the loop blows past the 10s watchdog threshold. The task
    # named in the log is usually just a bystander parked in the IPI handler
    # (curl, systemd and systemd-journald have all been blamed) — the whole
    # machine is unresponsive for the window.
    #
    # Proactive compaction exists only to keep huge pages cheaply available.
    # transparent_hugepage is "madvise" here and nothing on this host madvises
    # for them, so we pay the entire cost for no benefit. 0 disables it;
    # on-demand compaction (kcompactd_do_work) still runs when an allocation
    # actually needs it.
    "vm.compaction_proactiveness" = 0;
  };

  powerManagement = {
    enable = true;
    powertop.enable = true;
    scsiLinkPolicy = "med_power_with_dipm";
    # No cpuFreqGovernor: the Atom D2701 exposes no P-states under this BIOS,
    # so there is no cpufreq driver and no /sys/.../cpu0/cpufreq at all. Asking
    # for "schedutil" was inert — it only ever produced a boot-time
    # "Failed to find module 'cpufreq_schedutil'" from systemd-modules-load — so
    # it never delivered the better IPI latency it was added for. The soft
    # lockups it was meant to address are handled by vm.compaction_proactiveness
    # above instead.
  };
}

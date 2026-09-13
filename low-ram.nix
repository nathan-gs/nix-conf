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

  # Steady writeback during bulk I/O (media-rsync) so kcompactd does not
  # soft-lockup migrating buffer-backed folios under SMR stalls.
  boot.kernel.sysctl = {
    "vm.dirty_background_bytes" = 64 * 1024 * 1024;   # 64 MiB
    "vm.dirty_bytes" = 256 * 1024 * 1024;              # 256 MiB
    "vm.swappiness" = 10;
    "vm.vfs_cache_pressure" = 200;

    # Disable *proactive* memory compaction (default 20). This is the actual
    # cause of the recurring multi-second soft lockups on nnas, observed on
    # 2026-09-09/10/12/13, always mid-morning while media-rsync is still
    # running. The kcompactd stack is unambiguous:
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

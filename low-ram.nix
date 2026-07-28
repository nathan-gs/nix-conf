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
  };

  powerManagement = {
    enable = true;
    powertop.enable = true;
    scsiLinkPolicy = "med_power_with_dipm";
    # Better IPI latency under write load than powersave (soft lockups).
    cpuFreqGovernor = "schedutil";
  };
}

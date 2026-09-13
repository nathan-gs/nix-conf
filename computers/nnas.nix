# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, modulesPath, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      (modulesPath + "/installer/scan/not-detected.nix")
      ../headless.nix
      ../system.nix
      ../low-ram.nix
      ../users.nix
      ../users-servers.nix
      ../software-servers.nix
      ../disks.nix
     ../apps/cloudflare-dyndns.nix
     #../services/smb.nix
     ../services/onedrive-schedule.nix
      ../gc.nix
      ../services/auto-upgrade.nix
      ../services/journal-upload.nix
      ../services/server-health2mqtt.nix
    ];

  # Health goes to the broker on nhtpc over WireGuard. This host had no health
  # reporting at all before (hw-health-report.nix is imported only by nhtpc),
  # which is backwards — the 8 TB SMR spinners live here.
  #
  # The intervals are deliberately slack: this box is underpowered, its data
  # disks are asleep most of the time, and the fast tier is the only one that
  # runs often (it reads /proc and /sys only, so it costs no IO).
  serverHealth2mqtt = {
    enable = true;
    broker = "nhtpc.wg";
    password = config.secrets.mqtt.users.server-health2mqtt.password;
    hostInterval = "10min";
    # disksInterval inherits the 30min default: a run costs nothing while the
    # disks sleep, and this box's disks sleep nearly all the time — a long
    # interval mostly meant missing the rare window when one is awake.
    hostExpireSeconds = 3600;

    # Root DOM (ata-SDV-32_987032400115) has carried 10 reallocated sectors
    # since at least 2026-09-13, with SMART overall still PASSED. Accept that
    # count so it is not a permanent alert, and alert the moment it grows —
    # on a 32 GB DOM holding root, 11 means replace it.
    #
    # The sensor still reports the real number; only the problem threshold
    # moves. Per-serial, so the two Seagates here still alert from 0.
    baselineReallocated."987032400115" = 10;
  };

  # Follower: never runs `nix flake update` (nhtpc is the leader). nhtpc pushes
  # the repos after its own upgrade; this host then builds and switches itself
  # at 05:00/05:45 from whatever flake.lock it finds, and mails its own
  # failures. nhtpc does not switch us — see autoUpgrade.syncRemotes.
  autoUpgrade.updateFlake = false;

  disks = {
    root = "ata-SDV-32_987032400115";
    data = [
     "ata-ST8000DM004-2CX188_ZCT3QSTM"
     "ata-ST8000DM004-2CX188_ZCT3R4CQ"
    ];
    smartd.rootDiskOptions = "-a -f -p -t -o on -n standby,q -s (S/../.././02|L/../../6/03) -W 4,45,50";

    btrfs = {
      volumes = [
       "documents"
       "media"
       "archive"
 #       "apps"
      ];
      # Weaker/busier box than nhtpc; keep scrub gentler so it doesn't
      # starve wg0/ssh again.
      scrubLimit = "30M";
      snapshots = {
        monthly.volumes = [
         "documents"
         "archive"
        ];
      };
    };
  };

  fileSystems."/" = {
    device = "/dev/disk/by-id/ata-SDV-32_987032400115-part1";
    fsType = "ext4";
    options = ["noatime" "discard" ];
  };

  # No disk swap: zram only (low-ram.nix, 40% of RAM).
  #
  # Swap used to live on -part2 of the root DOM, which is the flash module now
  # carrying 10 reallocated sectors. Paging onto a small DOM is write
  # amplification aimed squarely at the one device whose failure takes this
  # host down, and it was barely earning its keep — 0.6% used in steady state.
  #
  # There is nowhere else to put it: the data array is multi-device btrfs
  # (RAID1), and btrfs does not support swapfiles on multi-device filesystems.
  # So this is a removal, not a move, and it is a real trade-off: under memory
  # starvation the OOM killer now fires instead of the box thrashing the DOM.
  # That is arguably the better failure — a starvation episode is what produced
  # the ~9400 btrfs device errors, and thrashing swap only prolongs it.
  #
  # -part2 is left in place on the disk, unused; reclaim it if the DOM is ever
  # replaced (see baselineReallocated above).
  swapDevices = [ ];

  # Use the GRUB 2 boot loader.
  boot.loader.grub.enable = true;
  
  networking.interfaces.enp1s0.useDHCP = true;
  # Second NIC unused — skip DHCP chatter.
  networking.interfaces.enp2s0.useDHCP = false;
  

 networking = {
    hostName = "nnas"; # Define your hostname.
    
    enableIPv6 = false;
    resolvconf.dnsSingleRequest = true;

    # No local SMB/Syncthing/etc. SSH (22) comes from services/ssh.nix.
    firewall = {
      enable = true;
      allowPing = true;
      allowedTCPPorts = [ ];
      allowedUDPPorts = [ ];
    };

  };
  
  # NOT YET APPLIED: router is being replaced and its built-in WG (endpoint
  # h.nathan.gs:58578, peer "home") will stop working. This switches nnas to
  # peer directly with nhtpc, which now runs the WG server itself (port
  # 51820, forwarded on the new router). Only switch this in once the router
  # swap has happened — until then the old fritzbox WG is still what's live.
  networking.wireguard.interfaces.wg0 = {
    ips = [ "10.73.221.2/24" ];
    privateKey = config.secrets.wireguard.nnas.private;

    peers = [
      {
        name = "nhtpc";
        publicKey = config.secrets.wireguard.nhtpc.public;
        presharedKey = config.secrets.wireguard.nnas.preshared;
        # nhtpc's wg0 address only; only nhtpc talks to nnas, no need to
        # route the rest of the LAN through the tunnel.
        allowedIPs = [ "10.73.221.1/32" ];
        endpoint = "h.nathan.gs:51820";
        persistentKeepalive = 25;
        # Was 60s; less DNS under load. Keepalive holds the tunnel.
        dynamicEndpointRefreshSeconds = 300;
      }
    ];
  };

  # Allow nhtpc media-rsync (services/media-rsync.nix) to push as nathan
  users.users.nathan.openssh.authorizedKeys.keys = [
    config.secrets.ssh.nhtpc-backup.pub
  ];

  # The NixOS release to be compatible with for stateful data such as databases.
  system.stateVersion = "20.09";

  services.cloudflare-dyndns-nathan = {
    enable = true;
    authEmail = config.secrets.cloudflare.authEmail;
    authKey = config.secrets.cloudflare.authKey;
    zoneId = config.secrets.cloudflare.zoneId;
    recordId = config.secrets.cloudflare.nnas.recordId;
    recordName = config.secrets.cloudflare.nnas.recordName;
  };   

  boot.initrd.availableKernelModules = [ "uhci_hcd" "ehci_pci" "ahci" "xhci_pci" "usb_storage" "sd_mod" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ ];
  boot.extraModulePackages = [ ];

  # EXPERIMENT (2026-09-13) — remove if it does not help, see below for how to judge.
  #
  # After vm.compaction_proactiveness=0 killed the compaction-driven lockups
  # (verified: compact_daemon_wake / compact_stall / pgmigrate_success all stayed
  # at 0 through a full onedrive run), nnas still stalled 20-25 s — but via a
  # different path: RCU/timer starvation rather than page migration.
  #
  #   rcu: INFO: rcu_preempt detected stalls on CPUs/tasks: 1-...0
  #   rcu: rcu_preempt kthread timer wakeup didn't happen for 22070 jiffies!
  #   rcu:         Possible timer handling issue on cpu=1
  #   watchdog: BUG: soft lockup - CPU#1 stuck for 25s!
  #
  # Every occurrence names CPU#1, with victims that are merely whatever ran
  # there (systemctl in exit_mmap, journalctl and nsncd in an IPI handler).
  # This box is a 2-core/4-thread in-order Atom D2701 where cpu0+cpu1 are HT
  # siblings of core 0 and cpu2+cpu3 of core 1 — so CPU#1 shares execution
  # resources with CPU#0, which carries a thermal-interrupt storm measured at
  # ~316/s (TRM in /proc/interrupts, all on CPU0). Temperatures are fine at
  # 65-70 C against a 100 C crit and core_throttle_count is 0, so nothing is
  # actually throttling; the threshold interrupt just fires continuously,
  # plausibly because the kernel cannot read TjMax on this CPU ("platform
  # coretemp.0: Unable to read TjMax from CPU 0" at boot) and there are no ACPI
  # thermal zones at all. The 0x19B/0x19C thermal MSRs return EIO here, so that
  # could not be confirmed directly.
  #
  # nosmt drops the two siblings, leaving 2 physical cores, so one thread can no
  # longer starve the other. Ruled out first, by counters rather than argument:
  # compaction (all zero), memory pressure (memory PSI avg300=0.03, cgroup
  # reclaim absorbed it, pgscan_direct=0), C-states (only POLL and C1E at 10 us
  # exit latency), intel_powerclamp (cur_state=0) and thermal throttling.
  #
  # Trade-off: 4 logical CPUs become 2. HT on an in-order Atom buys maybe
  # 20-30% throughput, so expect the onedrive sync to run somewhat longer in
  # exchange for worst-case latency. Judge it on the next onedrive run:
  #   journalctl -k | grep -cE "soft lockup|rcu_preempt detected stalls"
  # If that is still non-zero, SMT was not the mechanism — drop this parameter
  # again rather than leaving a halved CPU count in place for nothing.
  boot.kernelParams = [ "nosmt" ];
  
  # Use the GRUB 2 boot loader.
  boot.loader.grub.memtest86.enable = true;
  boot.loader.grub.device = "/dev/disk/by-id/ata-SDV-32_987032400115";

  boot.blacklistedKernelModules = [ 
    "gma500_gfx"
  ];

}

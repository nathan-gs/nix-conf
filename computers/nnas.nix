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
      ../users.nix
      ../users-servers.nix
      ../software-servers.nix
      ../disks.nix
     ../apps/cloudflare-dyndns.nix
     #../services/smb.nix
     ../services/onedrive.nix
      ../gc.nix
      ../services/auto-upgrade.nix
    ];

  # Follower: never runs `nix flake update` (nhtpc is the leader). Safety-net
  # timer at 06:00/06:30 (after leader remote apply at 04:00) applies an
  # already-present flake.lock if the leader push/switch missed.
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

  swapDevices = [
    { device = "/dev/disk/by-id/ata-SDV-32_987032400115-part2"; }
  ];   

  # Use the GRUB 2 boot loader.
  boot.loader.grub.enable = true;
  
  networking.interfaces.enp1s0.useDHCP = true;
  networking.interfaces.enp2s0.useDHCP = true;
  

 networking = {
    hostName = "nnas"; # Define your hostname.
    
    enableIPv6 = false;
    resolvconf.dnsSingleRequest = true;

    firewall = {
      enable = true;
      allowPing = true;
      allowedTCPPorts = [ 53 445 139 4444 8445 6789 8384 8385 ];
      allowedUDPPorts = [ 53 137 138 4444 8445 21027 ];
    };

  };
  
  networking.wireguard.interfaces.wg0 = {
    ips = [ "192.168.1.201/24" ];
    privateKey = config.secrets.wireguard.nnas.private;

    peers = [
      {
        name = "home";
        # NHTPC
        publicKey = config.secrets.wireguard.home.public;
        presharedKey = config.secrets.wireguard.home.preshared;
        allowedIPs = [ "192.168.1.0/24" ];
        endpoint = "h.nathan.gs:58578";
        persistentKeepalive = 25;
        dynamicEndpointRefreshSeconds = 60;
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
  
  # Use the GRUB 2 boot loader.
  boot.loader.grub.memtest86.enable = true;
  boot.loader.grub.device = "/dev/disk/by-id/ata-SDV-32_987032400115";

  boot.blacklistedKernelModules = [ 
    "gma500_gfx"
  ];

  powerManagement = {
    enable = true;
    powertop.enable = true;
    scsiLinkPolicy = "med_power_with_dipm";
    cpuFreqGovernor = "powersave";
  };

  # Low-RAM NAS (3.8 GiB) + SMR btrfs under bulk writes (media-rsync): keep
  # dirty page-cache small so writeback is steady and kcompactd does not
  # soft-lockup migrating buffer-backed folios under I/O stalls.
  boot.kernel.sysctl = {
    "vm.dirty_background_bytes" = 64 * 1024 * 1024;   # 64 MiB
    "vm.dirty_bytes" = 256 * 1024 * 1024;              # 256 MiB
    "vm.swappiness" = 10;
    "vm.vfs_cache_pressure" = 200;
  };

}

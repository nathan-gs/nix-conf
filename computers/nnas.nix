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

  swapDevices = [
    { device = "/dev/disk/by-id/ata-SDV-32_987032400115-part2"; }
  ];

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
  
  # Use the GRUB 2 boot loader.
  boot.loader.grub.memtest86.enable = true;
  boot.loader.grub.device = "/dev/disk/by-id/ata-SDV-32_987032400115";

  boot.blacklistedKernelModules = [ 
    "gma500_gfx"
  ];

}

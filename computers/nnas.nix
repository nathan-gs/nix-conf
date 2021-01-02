# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      <nixpkgs/nixos/modules/installer/scan/not-detected.nix>
      ../headless.nix
      ../system.nix
      ../disks.nix
      ../powersave.nix
     ../apps/cloudflare-dyndns.nix
     ../smb.nix
     ../onedrive.nix
    ];


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
  
  networking.wg-quick.interfaces.wg0 = {
    address = [ "172.16.8.2/24" ];
        
    privateKey = builtins.readFile ../secrets/wireguard.nnas.private;
    
    peers = [
      {
        # NHTPC
        publicKey = builtins.readFile ../secrets/wireguard.nhtpc.public;
        allowedIPs = [ "172.16.8.0/24" ];
        endpoint = "h.nathan.gs:51820";
        persistentKeepalive = 25;
      }
      
    ];
  };

  services.ssmtp = {
      enable = true;
      domain = "nathan.gs";
      hostName = "relay.proximus.be";
      root = "nathan@nathan.gs";    
  };

  # The NixOS release to be compatible with for stateful data such as databases.
  system.stateVersion = "20.09";

  services.cloudflare-dyndns = {
    enable = true;
    authEmail = "nathan@nathan.gs";
    authKey = builtins.readFile ../secrets/cloudflare.auth_key;
    zoneId = "7f71decfc86e8bb13d756d903005bb42";
    recordId = "be166852584f230578f28fd50f29825e";
    recordName = "nnas.nathan.gs";
  };   

  boot.initrd.availableKernelModules = [ "uhci_hcd" "ehci_pci" "ahci" "xhci_pci" "usb_storage" "sd_mod" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ ];
  boot.extraModulePackages = [ ];
  
  # Use the GRUB 2 boot loader.
  boot.loader.grub.memtest86.enable = true;
  boot.loader.grub.version = 2;
  boot.loader.grub.device = "/dev/disk/by-id/ata-SDV-32_987032400115";

  boot.blacklistedKernelModules = [ 
    "gma500_gfx"
  ];
  
}

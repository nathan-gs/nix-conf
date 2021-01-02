# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, modulesPath, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      (modulesPath + "/installer/scan/not-detected.nix")
      ../disks.nix
      ../headless.nix
      ../system.nix
      ../powersave.nix
      ../apps/cloudflare-dyndns.nix
      ../onedrive.nix
      ../media.nix
    ];

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  
  boot.initrd.availableKernelModules = [ "xhci_pci" "ahci" "nvme" "usb_storage" "usbhid" "sd_mod" ];
  boot.kernelModules = [ "kvm-intel" ];

  networking.hostName = "nhtpc"; # Define your hostname.
  networking.wireless.enable = false;  # Enables wireless support via wpa_supplicant.
  
  disks = {
    root = "nvme-Force_MP300_1822818000012437015A";
    data = [
     "ata-ST5000LM000-2AN170_WCJ0NK0L"
     "ata-ST5000LM000-2AN170_WCJ0QDGW"
     "ata-ST5000LM000-2AN170_WCJ19YAA"
     "ata-ST5000LM000-2AN170_WCJ1WXQ7"
    ];
    smartd.rootDiskOptions = "-a -f -p -t -o on -n standby,q -s (S/../.././02|L/../../6/03) -W 4,45,50";

    btrfs = {
      volumes = [ 
       "documents"
       "media"
       "archive"
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
    device = "/dev/disk/by-id/nvme-Force_MP300_1822818000012437015A-part2";
    fsType = "ext4";
    options = ["noatime" "discard" ];
  };
  
  fileSystems."/boot" = {
    device = "/dev/disk/by-id/nvme-Force_MP300_1822818000012437015A-part1";
    fsType = "vfat";
  };

  
  swapDevices = [
    { device = "/dev/disk/by-id/nvme-Force_MP300_1822818000012437015A-part3"; }
  ];  

  # The global useDHCP flag is deprecated, therefore explicitly set to false here.
  # Per-interface useDHCP will be mandatory in the future, so this generated config
  # replicates the default behaviour.
  networking.useDHCP = false;
  networking.interfaces.eno1.useDHCP = true;
  networking.interfaces.enp1s0.useDHCP = true;
  networking.interfaces.wlp2s0.useDHCP = true;
  
  networking.wg-quick.interfaces.wg0 = {
    address = [ "172.16.8.1/24" ];
    
    listenPort = 51820;
    privateKey = builtins.readFile ../secrets/wireguard.nhtpc.private;
    
    peers = [
      {
        # NNAS
        publicKey = builtins.readFile ../secrets/wireguard.nnas.public;
        allowedIPs = [ "172.16.8.0/24" ];
        persistentKeepalive = 25;
      }
      
    ];
    
  };

  services.cloudflare-dyndns = {
    enable = true;
    authEmail = "nathan@nathan.gs";
    authKey = builtins.readFile ../secrets/cloudflare.auth_key;
    zoneId = "7f71decfc86e8bb13d756d903005bb42";
    recordId = "e5487e3b8afcc8b0768e4dedcd6b9ca4";
    recordName = "h.nathan.gs";
  };

  # Enable sound.
  # sound.enable = true;
  # hardware.pulseaudio.enable = true;

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "20.09"; # Did you read the comment?

}


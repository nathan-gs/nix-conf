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
      ../services/onedrive.nix
      ../services/photoprism.nix
      ../services/plex.nix
      ../services/vscode.nix
      ../services/nginx.nix
      ../services/smb.nix
      ../monitoring.nix
      ../smarthome.nix
    ];


  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  
  boot.initrd.availableKernelModules = [ "xhci_pci" "ahci" "nvme" "usb_storage" "usbhid" "sd_mod" ];
  boot.kernelModules = [ "kvm-intel" "coretemp" "nct6775" ];

  networking.hostName = "nhtpc"; # Define your hostname.
  networking.wireless.enable = false;  # Enables wireless support via wpa_supplicant.
  
  disks = {
    root = "nvme-CT1000P5PSSD8_221036718144";
    data = [
     "ata-ST5000LM000-2AN170_WCJ0NK0L"
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
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
    options = ["noatime" "discard" ];
  };
  
  fileSystems."/boot" = {
    device = "/dev/disk/by-label/boot";
    fsType = "vfat";
  };

  
  swapDevices = [
    { device = "/dev/disk/by-label/swap"; }
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
    privateKey = config.secrets.wireguard.nhtpc.private;
    
    peers = [
      {
        # NNAS
        publicKey = config.secrets.wireguard.nnas.public;
        allowedIPs = [ "172.16.8.0/24" ];
        persistentKeepalive = 25;
      }
      
    ];
    
  };

  services.cloudflare-dyndns-nathan = {
    enable = true;
    authEmail = config.secrets.cloudflare.authEmail;
    authKey = config.secrets.cloudflare.authKey;
    zoneId = config.secrets.cloudflare.zoneId;
    recordId = config.secrets.cloudflare.nhtpc.recordId;
    recordName = config.secrets.cloudflare.nhtpc.recordName;
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


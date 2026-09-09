# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, modulesPath, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      (modulesPath + "/installer/scan/not-detected.nix")
      ../disks.nix
      ../home-network.nix
      ../headless.nix
      ../system.nix
      ../services/fail2ban.nix
      ../software-servers.nix
      ../software.nix
      ../users.nix
      ../users-servers.nix
      ../powersave.nix
      ../apps/cloudflare-dyndns.nix
      ../services/onedrive.nix
      ../services/mariadb.nix
      ../services/photoprism.nix
      #../services/plex.nix
      #../services/vscode.nix
      ../services/vscode-server.nix
      #../services/autogenstudio.nix
      ../services/nzb.nix
      ../services/komga.nix
      ../services/jellyfin.nix
      ../services/nginx.nix
      ../services/blocky.nix
      ../services/dhcp.nix
      #../services/smb.nix
      #../services/ollama.nix
      ../services/sos2mqtt.nix
      ../services/pylontech2mqtt.nix
      # ngo deleted -> no remote build clients; nixdist trusted-user removed.
      #../services/remote-build-host.nix
      ../services/matomo.nix
      ../monitoring.nix
      ../smarthome.nix
      ../gc.nix
      ../services/auto-upgrade.nix
      ../services/hw-health-report.nix
      ../services/media-rsync.nix
      ../services/wireguard.nix
      ../services/journal-remote.nix
    ];

  # Leader: sole `nix flake update` + commit; then apply the same lock on nnas.
  # After switch, wait for smarthome stack; rollback generation if still unhealthy.
  autoUpgrade = {
    updateFlake = true;
    applyRemotes = [
      { host = "nnas.wg"; flakeAttr = "nnas"; }
    ];
    healthCheck = {
      enable = true;
      units = [
        "home-assistant.service"
        "ebusd.service"
        "mosquitto.service"
        "zigbee2mqtt.service"
      ];
      httpProbes = [
        { url = "http://127.0.0.1:8123/"; } # Home Assistant UI
        { url = "http://127.0.0.1:8080/"; } # Zigbee2MQTT frontend
      ];
      # HA package upgrades often need several minutes to become ready.
      timeoutSec = 600;
      intervalSec = 15;
      rollback = true;
    };
  };


  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.memtest86.enable = true;

  boot.loader.efi.canTouchEfiVariables = true;

  boot.kernelParams = [
    "quiet"
    "splash"
    "apm=power_off"
    "acpi=force"
  ];
  
  boot.initrd.availableKernelModules = [ "xhci_pci" "ahci" "nvme" "usb_storage" "usbhid" "sd_mod" ];
  boot.kernelModules = [ "kvm-intel" "coretemp" "nct6775" ];

  hardware.cpu.intel.updateMicrocode = true;

  networking.hostName = "nhtpc"; # Define your hostname.
  networking.wireless.enable = false;  # Enables wireless support via wpa_supplicant.
  
  disks = {
    root = "nvme-CT1000P5PSSD8_221036718144";
    data = [
     "ata-ST5000LM000-2AN170_WCJ0NK0L"
     "ata-ST5000LM000-2AN170_WCJ19YAA" #-- priority: SMART long + surface scan, then btrfs replace of WD (see /tmp/drive-tests/WCJ19-PRIORITY.txt)
     "ata-ST5000LM000-2AN170_WCJ1WXQ7"
     # "ata-WDC_WD50NPJZ-00CBYT0_WD-WX22A93FCD83" # failing media; replace with WCJ19YAA when tests green
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
    options = [ "umask=0077" ];
  };

  
  swapDevices = [
    { device = "/dev/disk/by-label/swap"; }
  ];  

  nix.settings.max-jobs = 2;
  nix.settings.cores = 2;

  # The global useDHCP flag is deprecated, therefore explicitly set to false here.
  # Per-interface useDHCP will be mandatory in the future, so this generated config
  # replicates the default behaviour.
  networking.useDHCP = false;
  # eno1 is now static: nhtpc runs the LAN's DHCP server (services/dhcp.nix)
  # and can't be a DHCP client of itself.
  networking.interfaces.eno1 = {
    useDHCP = false;
    ipv4.addresses = [
      { address = "192.168.0.2"; prefixLength = 24; }
    ];
  };
  networking.defaultGateway = "192.168.0.1";
  networking.nameservers = [ "127.0.0.1" ]; # blocky
  # eno1 is static, not a DHCP client, so it never gets the domain-search
  # suffix kea hands out to everyone else — set it explicitly here too.
  networking.search = [ "l.nathan.gs" ];
  networking.interfaces.enp1s0.useDHCP = true;

  # Reject DHCP option 24 (path_mtu_aging_timeout) — router sends malformed values
  # causing constant "dhcp_envoption 24.0/3: malformed embedded option" errors
  networking.dhcpcd.extraConfig = ''
    nooption path_mtu_aging_timeout
  '';
  


  services.cloudflare-dyndns-nathan = {
    enable = true;
    authEmail = config.secrets.cloudflare.authEmail;
    authKey = config.secrets.cloudflare.authKey;
    zoneId = config.secrets.cloudflare.zoneId;
    recordId = config.secrets.cloudflare.nhtpc.recordId;
    recordName = config.secrets.cloudflare.nhtpc.recordName;
  };

  # WireGuard server. Replaces the fritzbox's built-in WG (router being
  # replaced with one that can't do WG). Port must be forwarded from the
  # router to nhtpc's LAN IP on UDP 51820 (chosen to differ from the
  # fritzbox's old port 58578).
  #
  # nnas + nhpone/nlaptop/fphone all live on the same 10.73.221.0/24 WG
  # subnet, NATed out to the LAN/internet via nhtpc. Only nhtpc talks to
  # nnas (no other LAN host needs to reach it), so it doesn't need a
  # LAN-shaped address or proxy-ARP — hosts.nix/media-rsync/auto-upgrade
  # address it via the "nnas.wg" name, updated to its new WG IP.
  boot.kernel.sysctl."net.ipv4.ip_forward" = 1;
  networking.nat = {
    enable = true;
    externalInterface = "eno1";
    internalInterfaces = [ "wg0" ];
  };

  networking.wireguard.interfaces.wg0 = {
    ips = [ "10.73.221.1/24" ];
    listenPort = 51820;
    privateKey = config.secrets.wireguard.nhtpc.private;

    peers = [
      {
        name = "nnas";
        publicKey = config.secrets.wireguard.nnas.public;
        presharedKey = config.secrets.wireguard.nnas.preshared;
        allowedIPs = [ "10.73.221.2/32" ];
      }
      {
        name = "nhpone";
        publicKey = config.secrets.wireguard.nhpone.public;
        presharedKey = config.secrets.wireguard.nhpone.preshared;
        allowedIPs = [ "10.73.221.10/32" ];
      }
      {
        name = "nlaptop";
        publicKey = config.secrets.wireguard.nlaptop.public;
        presharedKey = config.secrets.wireguard.nlaptop.preshared;
        allowedIPs = [ "10.73.221.11/32" ];
      }
      {
        name = "fphone";
        publicKey = config.secrets.wireguard.fphone.public;
        presharedKey = config.secrets.wireguard.fphone.preshared;
        allowedIPs = [ "10.73.221.12/32" ];
      }
    ];
  };

  hardware.bluetooth.enable = true;

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


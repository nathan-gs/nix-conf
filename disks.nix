{ config, lib, pkgs, ... }:

let
  disks = config.disks;
  dataDisks = lib.imap (n: v: ''/dev/disk/by-id/${v}'' ) disks.data;
  dataPartitions = lib.imap (n: v: ''/dev/disk/by-id/${v}-part1'' ) disks.data;
  #dataPartitions = [ "" ];
  rootDisk = ''/dev/disk/by-id/${disks.root}'';
  rootDiskSmartdOptions = disks.smartd.rootDiskOptions;

  allDisks = [ rootDisk ] ++ dataDisks;

  smartdDataDevices = lib.imap (n: v: { device = v; }) dataDisks;
  smartdDevices = smartdDataDevices ++ [{ device = rootDisk; options = rootDiskSmartdOptions; }];

  hdparmOptions = disks.hdparm.options;
  hdparmEnabled = disks.hdparm.enable;

  dataDisksLength = lib.length dataDisks;
  btrfsEnabled = if dataDisksLength == 0 then false else true;

  dataVolumes = disks.btrfs.volumes;
  dataVolumesTail = lib.tail dataVolumes;
  monthlySnapshotVolumes = disks.btrfs.snapshots.monthly.volumes;
  
  removeBackup = volume: ''
SNAPSHOTS_TO_KEEP=40

COUNT_SNAPSHOTS=0
COUNT_SNAPSHOTS=`${pkgs.btrfs-progs}/bin/btrfs subvolume \
  list \
  -r \
  --sort=path,gen \
  -o $BACKUP_PATH \
  | grep ${volume} \
  | grep nightly \
  | wc -l`

let "TO_DELETE=$COUNT_SNAPSHOTS - $SNAPSHOTS_TO_KEEP"
if [ $TO_DELETE -gt 0 ]
then
  for i in `${pkgs.btrfs-progs}/bin/btrfs subvolume \
       list \
       -r \
       --sort=path,gen \
       -o $BACKUP_PATH \
       | grep ${volume} \
       | grep nightly \
       | ${pkgs.gawk}/bin/gawk '{ print $9 }' \
       | head -n $TO_DELETE`;
  do
    ${pkgs.btrfs-progs}/bin/btrfs subvolume delete -c /media/disks/$i;
  done
fi      
  '';
in 

with lib;

{

  options = {
    disks = {
      data = mkOption {
        default = [];
        example = [
          "ata-ST4000LM016-1N2170_W801E6ES"
        ];
      };
      root = mkOption {
        example = "ata-KingSpec_KDM-44HS.2-008GMS_984071620123";
      };
      smartd = {
        rootDiskOptions = mkOption {
          example = "";
          default = "";
        };
      };
      hdparm = {
        options = mkOption {
          default = ''-S 128 -B 1'';
        };
        enable = mkOption {
          default = false;
        };
      };

      btrfs = {
        volumes = mkOption {
          default = [];
        };
        snapshots = {
          monthly = {
            volumes = mkOption {
              default = [];
            };
          };
        };
      };
    };
  };  

  config = {

    services.smartd = {
      enable = true;
      autodetect = false;
      notifications = {
        mail = {
          enable = true;
          mailer = "/run/current-system/sw/bin/sendmail";
          recipient = "nathan@nathan.gs";
        };
        test = true;
        wall.enable = false;
      };
    
      defaults.monitored = "-a -f -p -t -o on -S on -n standby,q -s (S/../.././02|L/../../6/03) -W 4,35,40";
      devices = smartdDevices;
    };

    systemd.services.smartd = {
      environment.HOSTNAME=config.networking.hostName;
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
    };

    
#    services.udev = {
#      extraRules = ''
#ACTION=="add|change", KERNEL=="sd*[!0-9]", ATTR{timeout}="600"
#ACTION=="add|change", KERNEL=="sd*[!0-9]", ATTR{eh_timeout}="600"
#
#
#ACTION=="add", SUBSYSTEM=="usb", TEST=="power/control", ATTR{power/control}="auto"
#ACTION=="add", SUBSYSTEM=="scsi_host", KERNEL=="host*", ATTR{link_power_management_policy}="min_power"
#DRIVER=="sd", SUBSYSTEM=="scsi", ENV{DEVTYPE}=="scsi_device", ATTR{timeout}="150"
#    '';
#  }; 

  systemd.services.prometheus-btrfs = {
    description = "Prometheus BTRFS device stats";
    path = [ pkgs.btrfs-progs pkgs.bash pkgs.busybox ];
    script = ''
       mkdir -pm 0775 /var/lib/prometheus-node-exporter/text-files
       F=/var/lib/prometheus-node-exporter/text-files/btrfs.prom
       cat /dev/null > $F.next
       ${concatStringsSep "\n" (lib.imap (n: v: ''
         bash ${./ext/prometheus-btrfs.sh} /dev/disk/by-id/${v}-part1 ${v} >> $F.next
       '') disks.data)}
       mv $F.next $F
      '';
    startAt = "*:0/15";
  };

  systemd.services.prometheus-smartd = {
    description = "Prometheus Smartd Exporter";
    path = [ pkgs.smartmontools pkgs.bash pkgs.gawk pkgs.busybox ];
    script = ''
       mkdir -pm 0775 /var/lib/prometheus-node-exporter/text-files
       bash ${./ext/prometheus-smartmon.sh} > /var/lib/prometheus-node-exporter/text-files/smartd.prom.next
       mv /var/lib/prometheus-node-exporter/text-files/smartd.prom.next /var/lib/prometheus-node-exporter/text-files/smartd.prom
    '';
    startAt = "*:0/15";
  };
  
  systemd.services.disks-smr = {
    description = "Disks: Set timeouts for SMR disks";
    wantedBy = [ "multi-user.target" ];

    script = concatStringsSep "\n" (lib.imap (n: v: ''      
      DEVICE="$(basename $(readlink -f ${v}))"
      echo 600 > /sys/block/$DEVICE/device/timeout
      echo 600 > /sys/block/$DEVICE/device/eh_timeout
    '') dataDisks);
  };

    systemd.services.btrfs-scrub = mkIf btrfsEnabled {
      description = "btrfs monthly scrub";
      after = [ "local-fs.target" ];
      script = ''
        ${pkgs.btrfs-progs}/bin/btrfs scrub start -c3 -B -d /media/${lib.head dataVolumes}
      '';
      startAt = "*-*-08 23:00:00";
    };



    systemd.services.btrfs-backup-nightly = mkIf btrfsEnabled {
      description = "btrfs nightly snapshot";
      after = [ "local-fs.target" ];
      script = ''
        DT=`date '+%Y%m%d-%H%M'`

        BACKUP_PATH="/media/disks/backup"

        IS_DISKS_MOUNTED=`${pkgs.gnugrep}/bin/grep -c /media/disks /proc/mounts || :`

        if [ $IS_DISKS_MOUNTED -eq 0 ]; then
          ${pkgs.utillinux}/bin/mount /media/disks
        else
          echo "/media/disks is mounted, not remounting."
        fi

        ${concatStringsSep "\n" (lib.imap (n: v: "mkdir -p /media/disks/backup/${v}") dataVolumes)}
        ${concatStringsSep "\n" (lib.imap (n: v: "${pkgs.btrfs-progs}/bin/btrfs subvolume snapshot -r /media/${v} /media/disks/backup/${v}/${v}_nightly_\$DT") dataVolumes)}

        ${concatStringsSep "\n" (lib.imap (n: v: removeBackup v) dataVolumes)}



        if [ $IS_DISKS_MOUNTED -eq 0 ]; then
          ${pkgs.utillinux}/bin/umount /media/disks
        fi
      '';
      startAt = "*-*-* 03:00:00";

    };

    systemd.services.btrfs-backup-monthly = mkIf btrfsEnabled {
      description = "btrfs monthly snapshot";
      after = [ "local-fs.target" "mount-btrfs-volumes.service" ];
      script = ''
        DT=`date '+%Y%m%d-%H%M'`

        BACKUP_PATH="/media/disks/backup"

        IS_DISKS_MOUNTED=`${pkgs.gnugrep}/bin/grep -c /media/disks /proc/mounts || :`

        if [ $IS_DISKS_MOUNTED -eq 0 ]; then
          ${pkgs.utillinux}/bin/mount /media/disks
        else
          echo "/media/disks is mounted, not remounting."
        fi

        ${concatStringsSep "\n" (lib.imap (n: v: "mkdir -p /media/disks/backup/${v}") monthlySnapshotVolumes)}
        ${concatStringsSep "\n" (lib.imap (n: v: "${pkgs.btrfs-progs}/bin/btrfs subvolume snapshot -r /media/${v} /media/disks/backup/${v}/${v}_monthly_\$DT") monthlySnapshotVolumes)}

        if [ $IS_DISKS_MOUNTED -eq 0 ]; then
          ${pkgs.utillinux}/bin/umount /media/disks
        fi
      '';
      startAt = "*-*-01 04:00:00";

    };


    systemd.services.mount-btrfs-volumes = mkIf false {
      after = [ "local-fs.target" ];
      serviceConfig = {
        Restart = "on-failure";
        RestartSec = 5;
      };
      script = concatStringsSep "\n" (lib.imap (n: v: ''
        if [ `${pkgs.gnugrep}/bin/grep -c /media/${v} /proc/mounts || :` -eq 0 ]; then
          mkdir -p /media/${v}
          ${pkgs.utillinux}/bin/mount /media/${v}
        fi
      '') dataVolumes);            
    };

    systemd.services.hdparm-setup = mkIf hdparmEnabled {
      after = [ "local-fs.target"];
      wantedBy = ["multi-user.target"];
      script = concatStringsSep "\n" (lib.imap (n: v: ''${pkgs.hdparm}/bin/hdparm ${hdparmOptions} ${v}'') dataDisks);
    };

    fileSystems = 
      listToAttrs (lib.imap (i: v: 
      { 
        name = ''/media/${v}''; 
        value = {
          device = lib.head dataPartitions;
          fsType = "btrfs";
          noCheck = true;
          options = [ 
            "compress=lzo" 
            "subvol=${v}" 
            "noatime" 
            "autodefrag" 
            "space_cache"
            "x-systemd.mount-timeout=5min"
            "x-systemd.device-timeout=5min"
            "nofail"
#            "noauto"
            "degraded"
          ];
        };
      }) dataVolumes) 
      // {
        "/media/disks" = {
           device = lib.head dataPartitions;
          fsType = "btrfs";
          noCheck = true;
          options = [ 
            "compress=lzo" 
            "subvolid=0" 
            "noauto" 
            "noatime" 
            "autodefrag" 
            "space_cache" 
            "x-systemd.mount-timeout=15min" 
            "degraded" 
          ];
        };
      };
    

  };
 
  

}

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

  hdparmEnabled = disks.hdparm.enable;
  # -S: idle spin-down; units of 5s for 1–240. 120 = 10 minutes (was 12 = 1 min).
  # -B: APM level; 127 mid (was 16 = very aggressive, thrashy on SMR under load).
  hdparmStandby = disks.hdparm.standby;
  hdparmApm = disks.hdparm.apm;

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
        enable = mkOption {
          default = true;
          type = types.bool;
        };
        # hdparm -S value (1–240 → ×5 seconds idle before standby).
        standby = mkOption {
          default = 120; # 10 minutes
          type = types.int;
        };
        # hdparm -B APM level (1–254; lower = more aggressive power saving).
        apm = mkOption {
          default = 127;
          type = types.int;
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
          recipient = config.secrets.email;
          sender = "${config.networking.hostName}@nathan.gs";
        };
        test = true;
        wall.enable = false;
      };
    
      defaults.monitored = "-a -f -p -t -o on -S on -n standby,q -s (S/../.././02|L/../../6/03) -W 4,40,50";
      devices = smartdDevices;
    };

    systemd.services.smartd = {
      environment.HOSTNAME=config.networking.hostName;
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
    };

    # When multi-device btrfs has a MISSING member, udev keeps SYSTEMD_READY=0
    # and fstab mounts (nofail) never come up. Do not force READY (avoids
    # racing SMR spin-up). Instead mail if expected volumes are still unmounted
    # after the device-timeout window. Only disks.btrfs.volumes (documents/media/
    # archive/…); /media/disks is noauto snapshot helper — never required.
    systemd.services.btrfs-mount-alert = mkIf btrfsEnabled {
      description = "Email if expected btrfs volumes are not mounted";
      after = [ "network-online.target" "local-fs.target" ];
      wants = [ "network-online.target" ];
      path = [ pkgs.btrfs-progs pkgs.gnugrep pkgs.coreutils pkgs.util-linux ];
      script = ''
        set -euo pipefail
        missing=""
        # dataVolumes only — not /media/disks
        ${concatStringsSep "\n" (map (v: ''
        if ! ${pkgs.util-linux}/bin/mountpoint -q /media/${v}; then
          missing="$missing /media/${v}"
        fi
        '') dataVolumes)}

        if [[ -z "$missing" ]]; then
          rm -f /var/lib/btrfs-mount-alert/last-mail-day
          exit 0
        fi

        mkdir -p /var/lib/btrfs-mount-alert
        stamp=/var/lib/btrfs-mount-alert/last-mail-day
        today="$(date -u +%F)"
        # At most one mail per day while mounts stay down (e.g. multi-day replace).
        if [[ -f "$stamp" && "$(cat "$stamp")" == "$today" ]]; then
          exit 0
        fi

        report="$(${pkgs.btrfs-progs}/bin/btrfs filesystem show 2>&1 || true)"
        {
          echo "Subject: [${config.networking.hostName}] btrfs volume(s) not mounted:$missing"
          echo "From: ${config.networking.hostName}@nathan.gs"
          echo "To: ${config.secrets.email}"
          echo
          echo "Expected btrfs volumes not mounted after boot:$missing"
          echo
          echo "Boot leaves them unmounted when systemd never sees the array as"
          echo "ready (often a MISSING member). Mount manually if needed; finish"
          echo "device replace/remove so auto-mount works again."
          echo
          echo "=== btrfs filesystem show ==="
          echo "$report"
          echo
          echo "=== findmnt -t btrfs ==="
          ${pkgs.util-linux}/bin/findmnt -t btrfs || true
        } | /run/wrappers/bin/sendmail -t

        echo "$today" > "$stamp"
      '';
      serviceConfig.Type = "oneshot";
    };

    systemd.timers.btrfs-mount-alert = mkIf btrfsEnabled {
      description = "Check expected btrfs volumes are mounted";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        # After x-systemd.device-timeout (2m) so we do not false-alarm mid-wait.
        OnBootSec = "3min";
        OnUnitActiveSec = "1d";
        Persistent = true;
      };
    };

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
    startAt = "0,3,6,9,12,15,18,21:0";
  };

  systemd.services.prometheus-smartd = {
    description = "Prometheus Smartd Exporter";
    path = [ pkgs.smartmontools pkgs.bash pkgs.gawk pkgs.busybox ];
    script = ''
       mkdir -pm 0775 /var/lib/prometheus-node-exporter/text-files
       bash ${./ext/prometheus-smartmon.sh} > /var/lib/prometheus-node-exporter/text-files/smartd.prom.next
       mv /var/lib/prometheus-node-exporter/text-files/smartd.prom.next /var/lib/prometheus-node-exporter/text-files/smartd.prom
    '';
    startAt = "0,3,6,9,12,15,18,21:0";
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
      serviceConfig.CPUQuota = "50%";
    };



    systemd.services.btrfs-backup-nightly = mkIf btrfsEnabled {
      description = "btrfs nightly snapshot";
      after = [ "local-fs.target" ];
      script = ''
        DT=`date '+%Y%m%d-%H%M'`

        BACKUP_PATH="/media/disks/backup"

        IS_DISKS_MOUNTED=`${pkgs.gnugrep}/bin/grep -c /media/disks /proc/mounts || :`

        if [ $IS_DISKS_MOUNTED -eq 0 ]; then
          ${pkgs.util-linux}/bin/mount /media/disks
        else
          echo "/media/disks is mounted, not remounting."
        fi

        ${concatStringsSep "\n" (lib.imap (n: v: "mkdir -p /media/disks/backup/${v}") dataVolumes)}
        ${concatStringsSep "\n" (lib.imap (n: v: "${pkgs.btrfs-progs}/bin/btrfs subvolume snapshot -r /media/${v} /media/disks/backup/${v}/${v}_nightly_\$DT") dataVolumes)}

        ${concatStringsSep "\n" (lib.imap (n: v: removeBackup v) dataVolumes)}



        if [ $IS_DISKS_MOUNTED -eq 0 ]; then
          ${pkgs.util-linux}/bin/umount /media/disks
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
          ${pkgs.util-linux}/bin/mount /media/disks
        else
          echo "/media/disks is mounted, not remounting."
        fi

        ${concatStringsSep "\n" (lib.imap (n: v: "mkdir -p /media/disks/backup/${v}") monthlySnapshotVolumes)}
        ${concatStringsSep "\n" (lib.imap (n: v: "${pkgs.btrfs-progs}/bin/btrfs subvolume snapshot -r /media/${v} /media/disks/backup/${v}/${v}_monthly_\$DT") monthlySnapshotVolumes)}

        if [ $IS_DISKS_MOUNTED -eq 0 ]; then
          ${pkgs.util-linux}/bin/umount /media/disks
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
          ${pkgs.util-linux}/bin/mount /media/${v}
        fi
      '') dataVolumes);            
    };

    systemd.services.hdparm-setup = mkIf hdparmEnabled {
      after = [ "local-fs.target"];
      wantedBy = ["multi-user.target"];
      script = concatStringsSep "\n" (lib.imap (n: v: ''
          ${pkgs.hdparm}/bin/hdparm -S${toString hdparmStandby} ${v}
          ${pkgs.hdparm}/bin/hdparm -B${toString hdparmApm} ${v}
        '') dataDisks);
      serviceConfig.Type = "oneshot";
    };

    fileSystems = 
      listToAttrs (lib.imap (i: v: 
      { 
        name = ''/media/${v}''; 
        value = {
          device = lib.head dataPartitions;
          fsType = "btrfs";
          noCheck = true;
          # archive only: zstd for compressible backups/text.
          # media (video) + documents (mostly JPEG): skip — already compressed.
          options = [
            "subvol=${v}"
            "noatime"
            "autodefrag"
            "space_cache=v2"
            "x-systemd.mount-timeout=2min"
            "x-systemd.device-timeout=2min"
            "nofail"
#            "noauto"
            "degraded"
          ] ++ lib.optional (v == "archive") "compress=zstd:1";
        };
      }) dataVolumes) 
      // {
        # Top-level FS for snapshot mgmt; no default compress (archive subvol has zstd:1).
        "/media/disks" = {
           device = lib.head dataPartitions;
          fsType = "btrfs";
          noCheck = true;
          options = [ 
            "subvolid=0" 
            "noauto" 
            "noatime" 
            "autodefrag" 
            "space_cache=v2" 
            "x-systemd.mount-timeout=2min" 
            "degraded" 
          ];
        };
      };
    

  };
 
  

}

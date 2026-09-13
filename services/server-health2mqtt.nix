# server-health2mqtt — live host/disk/btrfs health into Home Assistant over MQTT.
#
# Replaces the monthly hw-health-report email (services/hw-health-report.nix)
# as the *primary* channel. Keep a minimal mail path for the case this cannot
# cover: HA runs on nhtpc, so if nhtpc is down there is nobody to alert.
#
# Everything is published retained under:
#
#   system/network/server/<host>/host                 — fast tier
#   system/network/server/<host>/disk/<serial>        — slow tier
#   system/network/server/<host>/disk/<serial>/standby
#   system/network/server/<host>/btrfs                — slow tier
#
# Entities register themselves via MQTT discovery (homeassistant/…), generated
# below from this host's own `disks` config. That is deliberate: nnas publishes
# its own inventory, so nhtpc's HA config never has to know what disks nnas has.
#
# ── Why two tiers ────────────────────────────────────────────────────────────
# fast  (default 5m): /proc, /sys and /run only — literally zero disk IO, so it
#                     is safe to run often. Covers CPU + NVMe temperature (both
#                     come from hwmon, not smartctl), load, memory, root fs
#                     usage, failed units, reboot-required.
# slow  (default 2h): the only tier that forks smartctl/btrfs. Every smartctl
#                     call uses `-n standby`, so a sleeping disk is skipped
#                     rather than spun up — on a host whose disks are usually
#                     asleep, disk records legitimately stay stale for days and
#                     the "SMART updated" timestamp sensor is how you see that.
#
# Nothing here writes local state (MQTT retain is the state store) and the units
# run at LogLevelMax=warning so a 5-minute timer does not dribble journal
# writes onto the root flash.
{ config, lib, pkgs, ... }:

let
  cfg = config.serverHealth2mqtt;
  disks = config.disks;
  host = config.networking.hostName;

  prefix = "system/network/server/${host}";

  rootDisk = if disks.root == "" then "" else "/dev/disk/by-id/${disks.root}";
  dataDisks = map (d: "/dev/disk/by-id/${d}") disks.data;
  btrfsVolumes = disks.btrfs.volumes;
  # All volumes are subvolumes of one filesystem; the first mounted one is a
  # fine handle for filesystem-wide queries.
  btrfsMount = if btrfsVolumes == [ ] then "" else "/media/${lib.head btrfsVolumes}";

  script = ../ext/server-health2mqtt.sh;

  # Same label the script derives: the serial, i.e. what is printed on the
  # drive you would physically pull.
  diskLabel = dev:
    let base = lib.last (lib.splitString "/" dev);
    in lib.toLower (lib.last (lib.splitString "_" base));

  allDisks =
    (lib.optional (rootDisk != "") { dev = rootDisk; role = "root"; })
    ++ (map (d: { dev = d; role = "data"; }) dataDisks);

  # The bus prefix in /dev/disk/by-id tells us which SMART shape a device has,
  # at eval time. That matters for *which entities to create at all*: an
  # entity for a metric the hardware cannot report is unavailable forever,
  # which is indistinguishable from a fault in an unavailable-entities check.
  # So: wear only for NVMe (percentage_used); the Seagates here expose no
  # equivalent and would sit unavailable for the life of the disk.
  isNvme = dev: lib.hasPrefix "nvme-" (lib.last (lib.splitString "/" dev));
  anyNvme = lib.any (d: isNvme d.dev) allDisks;

  genId = id: lib.toLower (builtins.replaceStrings [ "/" "." " " "-" ] [ "_" "_" "_" "_" ] id);

  # One HA device per server, and one per physical disk hanging off it via
  # via_device. The disk model/serial are recoverable from the /dev/disk/by-id
  # name at eval time ("ata-ST8000DM004-2CX188_ZCT3QSTM"), so HA shows the same
  # identity that is printed on the drive you would pull out of the bay.
  serverDevice = {
    identifiers = [ "server_${host}" ];
    name = "server ${host}";
    manufacturer = "nathan.gs";
    model = "NixOS server";
  };

  # Strip the bus prefix: "ata-ST8000DM004-2CX188_ZCT3QSTM" -> "ST8000DM004-2CX188_ZCT3QSTM"
  diskIdBody = dev:
    let base = lib.last (lib.splitString "/" dev);
    in lib.concatStringsSep "-" (lib.tail (lib.splitString "-" base));

  diskModel = dev:
    let parts = lib.splitString "_" (diskIdBody dev);
    in if lib.length parts < 2 then diskIdBody dev
    else lib.concatStringsSep "_" (lib.init parts);

  # by-id gives us the bus ("ata", "nvme"), which is not a manufacturer. Infer
  # the real one from the model prefix and simply omit it when unrecognised —
  # a blank field beats labelling every drive "ata".
  vendorPrefixes = [
    { prefix = "ST"; vendor = "Seagate"; }
    { prefix = "WDC"; vendor = "Western Digital"; }
    { prefix = "WD"; vendor = "Western Digital"; }
    { prefix = "CT"; vendor = "Crucial"; }
    { prefix = "Samsung"; vendor = "Samsung"; }
    { prefix = "TOSHIBA"; vendor = "Toshiba"; }
    { prefix = "HGST"; vendor = "HGST"; }
    { prefix = "INTEL"; vendor = "Intel"; }
    { prefix = "KINGSTON"; vendor = "Kingston"; }
  ];

  diskVendor = dev:
    let
      model = diskModel dev;
      match = lib.findFirst (v: lib.hasPrefix v.prefix model) null vendorPrefixes;
    in
    if match == null then null else match.vendor;

  diskDevice = dev: {
    identifiers = [ "server_${host}_disk_${diskLabel dev}" ];
    name = "${host} disk ${diskLabel dev}";
    model = diskModel dev;
    serial_number = lib.toUpper (diskLabel dev);
    via_device = "server_${host}";
  } // lib.optionalAttrs (diskVendor dev != null) {
    manufacturer = diskVendor dev;
  };

  # ── discovery payload helpers ──────────────────────────────────────────────
  # `field` is a key in the topic's JSON payload. `nullable` fields get an
  # availability_template so a metric the hardware does not expose (ATA disks
  # have no wear_pct, NVMe has no reallocated count) goes unavailable instead
  # of spamming "unknown" states into the recorder.
  #
  # Two names, on purpose:
  #   `path`  the full topic-shaped identity ("…/disk/wcj0nk0l.wear"). Drives
  #           unique_id and entity_id, so the entity id is the topic with "_"
  #           instead of "/".
  #   `label` the short display name ("Wear"). HA prefixes the device name for
  #           display, so a full path here would read
  #           "nhtpc disk wcj0nk0l system/network/server/…/wear".
  #
  # entity_id comes from `default_entity_id`, NOT `object_id`: MQTT dropped
  # object_id, and without an explicit entity id HA derives one by slugifying
  # *device name + entity name*, which doubles the identity up into
  # sensor.nhtpc_disk_x_system_network_server_nhtpc_disk_x_wear.
  #
  # NOTE: default_entity_id only applies when the entity is first created (or
  # re-created after deletion). Changing it here does not rename entities that
  # are already in HA's registry — delete the MQTT device in HA and re-run
  # server-health2mqtt-discovery.service to have them come back renamed.
  mkEntity = { component, path, label, topic, extra ? { }, nullable ? false, valueTemplate ? null, field ? null, device ? serverDevice }:
    let id = genId path;
    in {
      topic = "homeassistant/${component}/${id}/config";
      payload = {
        inherit device;
        name = label;
        unique_id = id;
        default_entity_id = "${component}.${id}";
        state_topic = topic;
        value_template =
          if valueTemplate != null then valueTemplate
          else "{{ value_json.${field} }}";
      }
      // lib.optionalAttrs nullable {
        availability_topic = topic;
        # `is defined` matters as much as `is not none`: a retained payload
        # written by an older version of the publisher simply lacks the key,
        # and an undefined value would otherwise read as available and then
        # render as a garbage state.
        availability_template =
          "{{ 'online' if value_json.${field} is defined and value_json.${field} is not none else 'offline' }}";
      }
      // extra;
    };

  mkSensor = args: mkEntity (args // { component = "sensor"; });

  mkProblem = { path, label ? "Problem", topic, device ? serverDevice }: mkEntity {
    component = "binary_sensor";
    inherit path label topic device;
    valueTemplate = "{{ 'ON' if value_json.problem_count | int(0) > 0 else 'OFF' }}";
    extra = {
      device_class = "problem";
      payload_on = "ON";
      payload_off = "OFF";
      # The whole record hangs off the problem sensor as attributes, so the
      # detail (reallocated sectors, scrub summary, failed unit names) is one
      # click away without minting an entity per field.
      json_attributes_topic = topic;
    };
  };

  hostTopic = "${prefix}/host";
  btrfsTopic = "${prefix}/btrfs";

  # Silence for more than a few fast-tier intervals means the host is gone —
  # the one thing a monthly email can never tell you.
  hostExpire = { expire_after = cfg.hostExpireSeconds; };

  hostEntities = [
    (mkSensor {
      path = "${prefix}.cpu_temperature";
      label = "CPU temperature";
      topic = hostTopic;
      field = "cpu_temp_c";
      nullable = true;
      extra = hostExpire // {
        unit_of_measurement = "°C";
        device_class = "temperature";
        state_class = "measurement";
      };
    })
    # No chipset_temperature entity on purpose: whether a host exposes a
    # trustworthy platform sensor is not knowable at eval time, and on a host
    # without one the entity would be unavailable forever. The value is still
    # published and visible in the `temps` attribute map.
    (mkSensor {
      path = "${prefix}.cpu_used";
      label = "CPU used";
      topic = hostTopic;
      field = "cpu_used_pct";
      extra = hostExpire // {
        unit_of_measurement = "%";
        state_class = "measurement";
        icon = "mdi:cpu-64-bit";
      };
    })
    # iowait is the number that actually explains a sluggish NAS: the CPU is
    # idle but blocked on spinning rust.
    (mkSensor {
      path = "${prefix}.cpu_iowait";
      label = "CPU iowait";
      topic = hostTopic;
      field = "cpu_iowait_pct";
      extra = hostExpire // {
        unit_of_measurement = "%";
        state_class = "measurement";
        icon = "mdi:timer-sand";
      };
    })
    (mkSensor {
      path = "${prefix}.uptime";
      label = "Uptime";
      topic = hostTopic;
      field = "uptime_s";
      extra = hostExpire // {
        unit_of_measurement = "s";
        device_class = "duration";
        state_class = "measurement";
        icon = "mdi:clock-outline";
      };
    })
    (mkSensor {
      path = "${prefix}.load_1m";
      label = "Load 1m";
      topic = hostTopic;
      field = "load1";
      extra = hostExpire // {
        state_class = "measurement";
        icon = "mdi:gauge";
      };
    })
    (mkSensor {
      path = "${prefix}.memory_used";
      label = "Memory used";
      topic = hostTopic;
      field = "mem_used_pct";
      extra = hostExpire // {
        unit_of_measurement = "%";
        state_class = "measurement";
        icon = "mdi:memory";
      };
    })
    (mkSensor {
      path = "${prefix}.swap_used";
      label = "Swap used";
      topic = hostTopic;
      field = "swap_used_pct";
      extra = hostExpire // {
        unit_of_measurement = "%";
        state_class = "measurement";
        icon = "mdi:harddisk";
      };
    })
    (mkSensor {
      path = "${prefix}.root_fs_used";
      label = "Root filesystem used";
      topic = hostTopic;
      field = "root_used_pct";
      extra = hostExpire // {
        unit_of_measurement = "%";
        state_class = "measurement";
        icon = "mdi:harddisk";
      };
    })
    (mkSensor {
      path = "${prefix}.root_fs_free";
      label = "Root filesystem free";
      topic = hostTopic;
      valueTemplate = "{{ (value_json.root_free_b | float(0) / 1024**3) | round(1) }}";
      extra = hostExpire // {
        unit_of_measurement = "GB";
        device_class = "data_size";
        state_class = "measurement";
      };
    })
    (mkSensor {
      path = "${prefix}.failed_units";
      label = "Failed units";
      topic = hostTopic;
      field = "failed_units";
      extra = hostExpire // {
        state_class = "measurement";
        icon = "mdi:alert-circle-outline";
        json_attributes_topic = hostTopic;
      };
    })
    (mkSensor {
      path = "${prefix}.problem_count";
      label = "Problem count";
      topic = hostTopic;
      field = "problem_count";
      extra = hostExpire // { state_class = "measurement"; icon = "mdi:alert"; };
    })
    (mkEntity {
      component = "binary_sensor";
      path = "${prefix}.reboot_required";
      label = "Reboot required";
      topic = hostTopic;
      valueTemplate = "{{ 'ON' if value_json.reboot_required else 'OFF' }}";
      extra = hostExpire // {
        device_class = "problem";
        payload_on = "ON";
        payload_off = "OFF";
        icon = "mdi:restart-alert";
      };
    })
    (mkProblem { path = "${prefix}.problem"; topic = hostTopic; })
  ]
  # Only where there is an NVMe to report one. nnas boots off a SATA DOM, so
  # this entity would never have a value there.
  ++ lib.optional anyNvme (mkSensor {
    path = "${prefix}.nvme_temperature";
    label = "NVMe temperature";
    topic = hostTopic;
    field = "nvme_temp_c";
    nullable = true;
    extra = hostExpire // {
      unit_of_measurement = "°C";
      device_class = "temperature";
      state_class = "measurement";
    };
  });

  diskEntities = d:
    let
      label = diskLabel d.dev;
      topic = "${prefix}/disk/${label}";
      base = "${prefix}/disk/${label}";
      device = diskDevice d.dev;
    in
    [
      (mkSensor {
        path = "${base}.temperature";
        label = "Temperature";
        inherit topic device;
        field = "temperature_c";
        nullable = true;
        extra = {
          unit_of_measurement = "°C";
          device_class = "temperature";
          state_class = "measurement";
        };
      })
      (mkSensor {
        path = "${base}.power_on_hours";
        label = "Power-on hours";
        inherit topic device;
        field = "power_on_hours";
        nullable = true;
        extra = {
          unit_of_measurement = "h";
          state_class = "total_increasing";
          icon = "mdi:clock-outline";
        };
      })
      # How old the retained SMART record is. On a host whose disks sleep, this
      # is the sensor that tells you "not broken, just never awake". Driven by
      # smart_ts (when SMART was actually read) rather than ts (when we last
      # published): a never-yet-awake disk publishes a placeholder without
      # reading anything, and must not claim a fresh SMART read.
      (mkSensor {
        path = "${base}.smart_updated";
        label = "SMART updated";
        inherit topic device;
        field = "smart_ts";
        nullable = true;
        valueTemplate = "{{ value_json.smart_ts | int(0) | timestamp_local }}";
        extra = { device_class = "timestamp"; icon = "mdi:clock-check-outline"; };
      })
      (mkSensor {
        path = "${base}.problem_count";
        label = "Problem count";
        inherit topic device;
        field = "problem_count";
        extra = { state_class = "measurement"; icon = "mdi:alert"; };
      })
      (mkProblem { path = "${base}.problem"; inherit topic device; })
      (mkEntity {
        component = "binary_sensor";
        path = "${base}.standby";
        label = "Standby";
        topic = "${topic}/standby";
        valueTemplate = "{{ value }}";
        inherit device;
        extra = {
          payload_on = "ON";
          payload_off = "OFF";
          icon = "mdi:sleep";
        };
      })
    ]
    # NVMe reports percentage_used; the ATA disks here expose no equivalent,
    # so creating this for them would mean an entity that is unavailable for
    # the life of the drive.
    ++ lib.optional (isNvme d.dev) (mkSensor {
      path = "${base}.wear";
      label = "Wear";
      inherit topic device;
      field = "wear_pct";
      nullable = true;
      extra = {
        unit_of_measurement = "%";
        state_class = "measurement";
        icon = "mdi:chart-donut";
      };
    });

  btrfsEntities = lib.optionals (btrfsMount != "") [
    (mkSensor {
      path = "${prefix}/btrfs.used";
      label = "Btrfs used";
      topic = btrfsTopic;
      field = "used_pct";
      extra = { unit_of_measurement = "%"; state_class = "measurement"; icon = "mdi:harddisk"; };
    })
    (mkSensor {
      path = "${prefix}/btrfs.free";
      label = "Btrfs free";
      topic = btrfsTopic;
      valueTemplate = "{{ (value_json.free_b | float(0) / 1024**4) | round(2) }}";
      extra = {
        unit_of_measurement = "TB";
        device_class = "data_size";
        state_class = "measurement";
      };
    })
    (mkSensor {
      path = "${prefix}/btrfs.device_errors";
      label = "Btrfs device errors";
      topic = btrfsTopic;
      field = "err_total";
      extra = { state_class = "measurement"; icon = "mdi:alert-octagon-outline"; };
    })
    (mkSensor {
      path = "${prefix}/btrfs.devices_missing";
      label = "Btrfs devices missing";
      topic = btrfsTopic;
      field = "devices_missing";
      extra = { state_class = "measurement"; icon = "mdi:harddisk-remove"; };
    })
    (mkSensor {
      path = "${prefix}/btrfs.scrub_age";
      label = "Btrfs scrub age";
      topic = btrfsTopic;
      field = "scrub_age_days";
      nullable = true;
      extra = { unit_of_measurement = "d"; state_class = "measurement"; icon = "mdi:broom"; };
    })
    (mkSensor {
      path = "${prefix}/btrfs.scrub_status";
      label = "Btrfs scrub status";
      topic = btrfsTopic;
      field = "scrub_status";
      extra = { icon = "mdi:broom"; };
    })
    (mkSensor {
      path = "${prefix}/btrfs.problem_count";
      label = "Btrfs problem count";
      topic = btrfsTopic;
      field = "problem_count";
      extra = { state_class = "measurement"; icon = "mdi:alert"; };
    })
    (mkProblem { path = "${prefix}/btrfs.problem"; label = "Btrfs problem"; topic = btrfsTopic; })
  ];

  discovery = hostEntities ++ (lib.concatMap diskEntities allDisks) ++ btrfsEntities;

  discoveryFile = pkgs.writeText "server-health2mqtt-discovery.json" (builtins.toJSON discovery);

  commonEnv = {
    SH_HOST = host;
    SH_TOPIC_PREFIX = prefix;
    SH_BROKER = cfg.broker;
    SH_PORT = toString cfg.port;
    SH_MQTT_USER = cfg.user;
    SH_MQTT_PASS = cfg.password;
    SH_ROOT_DISK = rootDisk;
    SH_DATA_DISKS = lib.concatStringsSep " " dataDisks;
    SH_BTRFS_MOUNT = btrfsMount;
    SH_BTRFS_VOLUMES = lib.concatStringsSep " " btrfsVolumes;
    SH_CPU_TEMP_WARN_C = toString cfg.cpuTempWarnC;
    SH_DISK_TEMP_WARN_C = toString cfg.diskTempWarnC;
    SH_FS_WARN_PCT = toString cfg.fsWarnPct;
    SH_SCRUB_MAX_AGE_DAYS = toString cfg.scrubMaxAgeDays;
    SH_NVME_WEAR_WARN_PCT = toString cfg.wearWarnPct;
    SH_DISCOVERY_FILE = "${discoveryFile}";
  };

  runtimePath = [
    pkgs.bash
    pkgs.coreutils
    pkgs.gawk
    pkgs.gnugrep
    pkgs.jq
    pkgs.mosquitto
    pkgs.smartmontools
    pkgs.btrfs-progs
    pkgs.util-linux
    pkgs.systemd
  ];

  # quiet: suppress systemd's routine per-run chatter. Only worth it for the
  # frequent host timer, where "Started …" every few minutes is pure write
  # amplification on a small root flash. NOT for the others: it also swallows
  # the script's own stderr, and a silently failing disks run is exactly how a
  # broker outage turned into "all the disk entities are unavailable" with
  # nothing in the journal to say why.
  mkUnit = { description, mode, quiet ? false }: {
    inherit description;
    path = runtimePath;
    environment = commonEnv;
    # Needs root to talk to the disks; keep the blast radius small otherwise.
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.bash}/bin/bash ${script} ${mode}";
      Nice = 19;
      IOSchedulingClass = "idle";
      CPUSchedulingPolicy = "idle";
      # A monitor must never be the reason the box is unhealthy.
      TimeoutStartSec = "2min";
      PrivateTmp = true;
      ProtectHome = true;
      ProtectKernelModules = true;
      ProtectControlGroups = true;
      RestrictRealtime = true;
      RestrictSUIDSGID = true;
      MemoryDenyWriteExecute = true;
      SystemCallArchitectures = "native";
    } // lib.optionalAttrs quiet { LogLevelMax = "warning"; };
  };
in
{
  options.serverHealth2mqtt = with lib; {
    enable = mkEnableOption "publishing server health to MQTT for Home Assistant";

    broker = mkOption {
      type = types.str;
      default = "localhost";
      description = "MQTT broker host. Followers point at nhtpc over WireGuard.";
    };

    port = mkOption {
      type = types.port;
      default = 1883;
    };

    user = mkOption {
      type = types.str;
      default = "server-health2mqtt";
    };

    password = mkOption {
      type = types.str;
      description = "Broker password; set from config.secrets.mqtt.users.";
    };

    hostInterval = mkOption {
      type = types.str;
      default = "5min";
      description = ''
        Fast tier. Reads only /proc, /sys and /run, so this costs no disk IO and
        can be frequent.
      '';
    };

    disksInterval = mkOption {
      type = types.str;
      default = "2h";
      description = ''
        Slow tier (SMART + btrfs). Deliberately infrequent: it forks smartctl
        per disk. It still never wakes a sleeping disk (`-n standby`), so the
        cost of a lower value is CPU, not spin-ups.
      '';
    };

    hostExpireSeconds = mkOption {
      type = types.int;
      default = 1800;
      description = ''
        Mark the host's entities unavailable after this much silence. This is
        the "is the box alive" alert; keep it comfortably above hostInterval.
      '';
    };

    cpuTempWarnC = mkOption { type = types.int; default = 85; };
    diskTempWarnC = mkOption { type = types.int; default = 50; };
    fsWarnPct = mkOption { type = types.int; default = 90; };
    scrubMaxAgeDays = mkOption { type = types.int; default = 45; };
    wearWarnPct = mkOption {
      type = types.int;
      default = 85;
      description = "Flash wear (NVMe percentage_used) that counts as a problem.";
    };
  };

  config = lib.mkIf cfg.enable {

    # Discovery is retained and republished at boot / after a switch, so an HA
    # restart or a changed disk list converges without manual work.
    systemd.services.server-health2mqtt-discovery = lib.recursiveUpdate
      (mkUnit {
        description = "server-health2mqtt: publish Home Assistant MQTT discovery";
        mode = "discovery";
      })
      {
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" "mosquitto.service" ];
      wants = [ "network-online.target" ];
      # At boot the broker may not be accepting connections yet (and on nnas it
      # lives on the far end of a WireGuard tunnel that is still coming up).
      # Without discovery the entities never appear, so this one retries.
      serviceConfig = {
        Restart = "on-failure";
        RestartSec = "30s";
      };
    };

    # Manual, never timed: removes this host's HA discovery configs so the
    # entities are dropped and can be recreated (after an entity_id change, or
    # to clear out a disk that is no longer here). Follow it with
    # `systemctl start server-health2mqtt-discovery`.
    systemd.services.server-health2mqtt-purge = mkUnit {
      description = "server-health2mqtt: purge Home Assistant MQTT discovery";
      mode = "purge";
    };

    systemd.services.server-health2mqtt-host = mkUnit {
      description = "server-health2mqtt: host vitals";
      mode = "host";
      quiet = true;
    };

    systemd.timers.server-health2mqtt-host = {
      description = "server-health2mqtt: host vitals timer";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "3min";
        OnUnitActiveSec = cfg.hostInterval;
        # Not Persistent: a missed vitals sample is worthless after the fact,
        # and catch-up runs at boot are exactly when the box is busiest.
        AccuracySec = "30s";
      };
    };

    systemd.services.server-health2mqtt-disks = mkUnit {
      description = "server-health2mqtt: SMART and btrfs";
      mode = "disks";
    };

    systemd.timers.server-health2mqtt-disks = {
      description = "server-health2mqtt: SMART and btrfs timer";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "10min";
        OnUnitActiveSec = cfg.disksInterval;
        # Loose accuracy lets systemd coalesce this with other wakeups.
        AccuracySec = "5min";
      };
    };
  };
}

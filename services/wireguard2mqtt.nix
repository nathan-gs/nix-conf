{ config, pkgs, lib, ... }:
let
  cfg = config.wireguard2mqtt;

  script = ../ext/wireguard2mqtt.sh;

  # Peers come from the interface's own definition, so the hub's peer list is
  # declared exactly once (in computers/<host>.nix) and adding a peer needs no
  # change here, in the script, or on the dashboard.
  wgPeers = config.networking.wireguard.interfaces.${cfg.interface}.peers;

  # pubkey<TAB>name<TAB>alwaysOn. Public keys are not secret — they are already
  # in the interface's generated setup script in the store — but they are only
  # used to join the live `wg show` dump to a configured name, and are never
  # published to MQTT.
  peersFile = pkgs.writeText "wireguard2mqtt-peers" (
    lib.concatMapStrings
      (p: "${p.publicKey}\t${p.name}\t${if lib.elem p.name cfg.alwaysOnPeers then "1" else "0"}\n")
      wgPeers
  );

  genId = id: lib.toLower (builtins.replaceStrings [ "/" "." " " "-" ] [ "_" "_" "_" "_" ] id);

  ifaceDevice = {
    identifiers = [ "wireguard" ];
    name = "WireGuard";
    manufacturer = "nathan.gs";
    model = "VPN hub";
  };

  # Each peer is a child device of the hub, the same way server-health2mqtt
  # makes every physical disk a child of its host.
  peerDevice = name: {
    identifiers = [ "wireguard-peer-${name}" ];
    name = "WireGuard ${name}";
    manufacturer = "nathan.gs";
    model = "VPN peer";
    via_device = "wireguard";
  };

  # Same contract as the other publishers: entity_id comes from
  # default_entity_id, which HA only honours when the entity is *created*, so
  # changing a key means running wireguard2mqtt-purge then -discovery rather
  # than just switching.
  mkEntity =
    { component ? "sensor"
    , topic
    , device
    , key
    , label
    , valueTemplate ? "{{ value_json.${key} }}"
    , nullable ? false
    , extra ? { }
    }:
    let id = genId "${topic}.${key}";
    in {
      topic = "homeassistant/${component}/${id}/config";
      payload = {
        inherit device;
        name = label;
        unique_id = id;
        default_entity_id = "${component}.${id}";
        state_topic = topic;
        value_template = valueTemplate;
        expire_after = cfg.expireSeconds;
      }
      // lib.optionalAttrs nullable {
        availability_topic = topic;
        availability_template =
          "{{ 'online' if value_json.${key} is defined and value_json.${key} is not none else 'offline' }}";
      }
      // extra;
    };

  peerTopic = name: "${cfg.topic}/peer/${name}";

  # No entity is created for a value a peer may never have — the same rule
  # server-health2mqtt follows for per-disk metrics, and for the same reason:
  # `smarthome/ha/default.nix`'s unavailable_entities check cannot tell a
  # permanently-unavailable entity from a fault, and every exception has to be
  # hand-added to its reject list. A roaming phone that has not connected since
  # the interface last came up has no handshake time and no endpoint at all, so
  # those two ride along as *attributes* of its connectivity sensor (which is
  # never unavailable) rather than as entities of their own.
  #
  # The exception is an alwaysOnPeers member: it is expected to be connected at
  # all times, so its handshake timestamp is a first-class entity — that is the
  # number worth watching on the site-to-site link, and its unavailability is
  # only ever the few seconds after the interface is recreated.
  peerEntities = peer:
    let
      t = peerTopic peer.name;
      d = peerDevice peer.name;
      alwaysOn = lib.elem peer.name cfg.alwaysOnPeers;
      e = args: mkEntity ({ topic = t; device = d; } // args);
    in
    [
      (e {
        component = "binary_sensor";
        key = "online";
        label = "Connected";
        valueTemplate = "{{ 'ON' if value_json.online else 'OFF' }}";
        extra = {
          device_class = "connectivity";
          payload_on = "ON";
          payload_off = "OFF";
          # Carries handshake, handshake_age, endpoint and allowed_ips, so the
          # detail is one click away without minting an entity that could sit
          # unavailable for months.
          json_attributes_topic = t;
        };
      })
      (e {
        key = "rx_bytes";
        label = "Received";
        extra = {
          device_class = "data_size";
          unit_of_measurement = "B";
          # Resets to 0 whenever the interface is recreated, which is exactly
          # what total_increasing is for.
          state_class = "total_increasing";
          icon = "mdi:download";
        };
      })
      (e {
        key = "tx_bytes";
        label = "Sent";
        extra = {
          device_class = "data_size";
          unit_of_measurement = "B";
          state_class = "total_increasing";
          icon = "mdi:upload";
        };
      })
    ]
    ++ lib.optional alwaysOn (e {
      key = "handshake";
      label = "Last handshake";
      nullable = true;
      extra = {
        device_class = "timestamp";
        icon = "mdi:handshake";
      };
    });

  ifaceEntities =
    let e = args: mkEntity ({ topic = cfg.topic; device = ifaceDevice; } // args);
    in
    [
      # Never nullable: peers_total is a fact about the configuration and
      # peers_online is truthfully 0 when the interface is down, so neither ever
      # goes unavailable — see the note on peerEntities below.
      (e {
        key = "peers_online";
        label = "Peers online";
        extra = {
          state_class = "measurement";
          unit_of_measurement = "peers";
          icon = "mdi:lan-connect";
        };
      })
      (e {
        key = "peers_total";
        label = "Peers configured";
        extra = {
          state_class = "measurement";
          unit_of_measurement = "peers";
          icon = "mdi:account-multiple";
        };
      })
      # Only alwaysOn peers can set this — see the script. A roaming phone being
      # offline is the normal case and must never raise a notification.
      (e {
        component = "binary_sensor";
        key = "problem";
        label = "Problem";
        valueTemplate = "{{ 'ON' if value_json.problem_count | int(0) > 0 else 'OFF' }}";
        extra = {
          device_class = "problem";
          payload_on = "ON";
          payload_off = "OFF";
          json_attributes_topic = cfg.topic;
        };
      })
    ];

  discoveryFile = pkgs.writeText "wireguard2mqtt-discovery.json"
    (builtins.toJSON (ifaceEntities ++ lib.concatMap peerEntities wgPeers));

  mkUnit = { description, mode, quiet ? false }: {
    inherit description;
    path = [ pkgs.bash pkgs.coreutils pkgs.jq pkgs.mosquitto pkgs.wireguard-tools ];
    environment = {
      WG_IFACE = cfg.interface;
      WG_TOPIC = cfg.topic;
      WG_BROKER = cfg.broker;
      WG_PORT = toString cfg.port;
      WG_MQTT_USER = cfg.user;
      WG_MQTT_PASS = cfg.password;
      WG_PEERS_FILE = "${peersFile}";
      WG_DISCOVERY_FILE = "${discoveryFile}";
      WG_HANDSHAKE_MAX_AGE = toString cfg.handshakeMaxAgeSeconds;
    };
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.bash}/bin/bash ${script} ${mode}";
      Nice = 19;
      # A monitor must never be the reason the box is unhealthy.
      TimeoutStartSec = "2min";
      # `wg show` needs CAP_NET_ADMIN to read the interface, so this runs as
      # root — but nothing else does, hence the bounding set. Everything it
      # reads comes from the kernel and the store; it writes no state at all.
      CapabilityBoundingSet = [ "CAP_NET_ADMIN" ];
      PrivateTmp = true;
      ProtectHome = true;
      ProtectSystem = "strict";
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
  options.wireguard2mqtt = with lib; {
    enable = mkEnableOption "publishing WireGuard peer state to MQTT for Home Assistant";

    interface = mkOption {
      type = types.str;
      default = "wg0";
      description = "WireGuard interface to report on; its peer list drives the entities.";
    };

    topic = mkOption {
      type = types.str;
      default = "system/network/wireguard";
      description = "Base topic. Peers publish under <topic>/peer/<name>.";
    };

    broker = mkOption {
      type = types.str;
      default = "localhost";
    };

    port = mkOption {
      type = types.port;
      default = 1883;
    };

    user = mkOption {
      type = types.str;
      default = "wireguard2mqtt";
    };

    password = mkOption {
      type = types.str;
      description = "Broker password; set from config.secrets.mqtt.users.";
    };

    alwaysOnPeers = mkOption {
      type = types.listOf types.str;
      default = [ ];
      example = [ "nnas" ];
      description = ''
        Peers expected to be connected at all times — only these can raise a
        problem. WireGuard is silent when idle and phones/laptops roam, so
        alerting on every peer would mean a notification every time someone
        leaves the house. The site-to-site link is the one worth watching.
      '';
    };

    handshakeMaxAgeSeconds = mkOption {
      type = types.int;
      default = 900;
      description = ''
        A peer counts as connected if it handshaked within this window, and an
        `alwaysOnPeers` member older than it raises a problem. WireGuard rekeys
        about every 2 minutes while traffic flows and not at all when idle, so
        this is deliberately generous: a stale handshake is weak evidence of a
        fault, and a false "VPN down" alert is worse than a late one.
      '';
    };

    interval = mkOption {
      type = types.str;
      default = "5min";
      description = "How often to publish. Reads only the kernel — no disk IO.";
    };

    expireSeconds = mkOption {
      type = types.int;
      default = 3 * 300;
      description = "Entities go unavailable after ~3 missed runs.";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.wireguard2mqtt = lib.recursiveUpdate
      (mkUnit {
        description = "wireguard2mqtt: peer state to MQTT";
        mode = "state";
        quiet = true;
      })
      {
        after = [ "wireguard-${cfg.interface}.service" "mosquitto.service" ];
      };

    systemd.timers.wireguard2mqtt = {
      description = "wireguard2mqtt: peer state timer";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "3min";
        OnUnitActiveSec = cfg.interval;
        AccuracySec = "30s";
        # Every value published is absolute (handshake time, cumulative
        # counters), so unlike the blocky publisher there are no deltas that a
        # catch-up run would misattribute — but there is also nothing to gain
        # from one, since the next run is at most `interval` away.
        Persistent = false;
      };
    };

    # Retained discovery, republished at boot and after every switch so an HA
    # restart or a changed peer list converges without manual work.
    systemd.services.wireguard2mqtt-discovery = lib.recursiveUpdate
      (mkUnit {
        description = "wireguard2mqtt: publish Home Assistant MQTT discovery";
        mode = "discovery";
      })
      {
        wantedBy = [ "multi-user.target" ];
        after = [ "network-online.target" "mosquitto.service" ];
        wants = [ "network-online.target" ];
        serviceConfig = {
          Restart = "on-failure";
          RestartSec = "30s";
        };
      };

    # Manual, never timed. Needed after renaming a peer or changing an entity
    # key — and after *removing* a peer, whose retained discovery config would
    # otherwise keep its entities alive forever.
    systemd.services.wireguard2mqtt-purge = mkUnit {
      description = "wireguard2mqtt: purge Home Assistant MQTT discovery";
      mode = "purge";
    };
  };
}

{ config, pkgs, lib, ... }:
let
  devices = config.homeNetwork.devices;

  # Explicit per-device records under l.nathan.gs (home-network.nix).
  deviceZoneRecords = lib.concatMapStrings (
    d:
    "${d.name} 3600 IN A ${d.ip}\n"
    + lib.concatMapStrings (a: "${a} 3600 IN A ${d.ip}\n") d.aliases
  ) devices;

  # The catch-all group applied to devices with `internet = false`. Named once
  # here because three places have to agree on it: the deny/allow lists below,
  # the per-client group assignment, and blocky-stats2mqtt — which splits the
  # blocks this group produces out of the ad/tracker figures (see statsEntities).
  devicesWithoutInternetGroup = "everything";

  restrictedClientsBlock = lib.listToAttrs (
    map (d: lib.nameValuePair d.ip [ devicesWithoutInternetGroup ]) (lib.filter (d: !d.internet) devices)
  );

  # Bare (no .l.nathan.gs suffix) mapping for every device name + alias, so
  # e.g. "ping mqtt" works even for clients that don't apply the DHCP
  # domain-search suffix (see the smartgatewayp1/nhtpc issue this
  # generalizes). Checked for collisions against home-network.nix before
  # relying on this — same mechanism as the existing fritz.box override.
  bareDeviceMappings = lib.listToAttrs (
    lib.concatMap (d: map (n: lib.nameValuePair n d.ip) ([ d.name ] ++ d.aliases)) devices
  );

  # See blocking.allowlists below. Multi-line block, not a list of
  # single-line entries — same inline-vs-source gotcha as the denylists.
  googleFunctional = ''
    csi.gstatic.com
    firebaselogging.googleapis.com
    firebaselogging-pa.googleapis.com
    fcmatch.google.com
    fcmatch.youtube.com
    video-stats.video.google.com
  '';

  # ── blocky stats → MQTT ─────────────────────────────────────────────────────
  # blocky's own Prometheus endpoint, local-only (not exposed beyond nginx's
  # /dns-query proxy). Nothing scrapes it — the flake has no Prometheus at all
  # any more — it is read once an hour by blocky-stats2mqtt below and turned
  # into Home Assistant entities, the same way server-health2mqtt reports host
  # health. Same two rules as that module: the host judges its own health
  # (`problems` is computed here, not in HA), and every entity registers itself
  # through retained MQTT discovery so HA's config never enumerates blocky.
  httpPort = 65080;

  statsScript = ../ext/blocky-stats2mqtt.sh;
  statsTopic = "system/network/blocky";
  # Hourly timer, so ~3 missed runs before HA calls it stale. Blocky being dead
  # is the interesting case: its counters stop, and there is no per-metric
  # heartbeat that would otherwise keep the sensors looking fresh.
  statsExpire = 3 * 3600;

  blockyDevice = {
    identifiers = [ "blocky" ];
    name = "blocky";
    manufacturer = "nathan.gs";
    model = "DNS resolver";
  };

  genId = id: lib.toLower (builtins.replaceStrings [ "/" "." " " "-" ] [ "_" "_" "_" "_" ] id);

  # Same shape as server-health2mqtt's mkEntity, deliberately: entity_id comes
  # from default_entity_id (the topic with "_" for "/"), which HA only honours
  # when the entity is *created* — changing a key here means running
  # blocky-stats2mqtt-purge and then -discovery, not just a switch.
  mkEntity =
    { component ? "sensor"
    , key
    , label
    , valueTemplate ? "{{ value_json.${key} }}"
    , nullable ? false
    , extra ? { }
    }:
    let id = genId "${statsTopic}.${key}";
    in {
      topic = "homeassistant/${component}/${id}/config";
      payload = {
        device = blockyDevice;
        name = label;
        unique_id = id;
        default_entity_id = "${component}.${id}";
        state_topic = statsTopic;
        value_template = valueTemplate;
        expire_after = statsExpire;
      }
      // lib.optionalAttrs nullable {
        availability_topic = statsTopic;
        availability_template =
          "{{ 'online' if value_json.${key} is defined and value_json.${key} is not none else 'offline' }}";
      }
      // extra;
    };

  mkCount = { key, label, icon }: mkEntity {
    inherit key label;
    extra = {
      inherit icon;
      unit_of_measurement = "queries";
      state_class = "measurement";
    };
  };

  mkPct = { key, label, icon }: mkEntity {
    inherit key label;
    extra = {
      inherit icon;
      unit_of_measurement = "%";
      state_class = "measurement";
    };
  };

  # The hourly deltas are what you read day to day; the cumulative counters are
  # there so HA's statistics can draw a long-run graph across restarts —
  # total_increasing is exactly the state_class for a counter that resets to 0
  # when blocky restarts.
  mkTotal = { key, label, icon }: mkEntity {
    inherit key label;
    extra = {
      inherit icon;
      unit_of_measurement = "queries";
      state_class = "total_increasing";
    };
  };

  statsEntities = [
    (mkCount { key = "queries"; label = "Queries last hour"; icon = "mdi:dns"; })
    (mkCount { key = "cached"; label = "Cached last hour"; icon = "mdi:lightning-bolt"; })
    # `blocked` counts ad/tracker blocks only. The catch-all
    # `devicesWithoutInternetGroup` denylist is a deliberate internet cutoff for
    # `internet = false` devices, not filtering, and those devices retry their
    # unreachable cloud endpoints forever — the Tuya car charger alone produced
    # ~740 blocks/hour, ~90% of the raw blocked count, swamping the number this
    # sensor exists to show. Those are counted separately below and excluded
    # from the denominator of both percentages (see the script), so the
    # percentages describe the traffic actually subject to filtering.
    (mkCount { key = "blocked"; label = "Blocked last hour"; icon = "mdi:cancel"; })
    (mkCount {
      key = "devices_without_internet_blocked";
      label = "Devices without internet blocked last hour";
      icon = "mdi:lan-disconnect";
    })
    (mkCount { key = "resolved"; label = "Resolved last hour"; icon = "mdi:cloud-arrow-up-outline"; })
    (mkPct { key = "blocked_pct"; label = "Blocked share last hour"; icon = "mdi:shield-check"; })
    (mkPct { key = "cache_hit_pct"; label = "Cache hit rate last hour"; icon = "mdi:speedometer"; })
    (mkTotal { key = "queries_total"; label = "Queries total"; icon = "mdi:dns"; })
    (mkTotal { key = "blocked_total"; label = "Blocked total"; icon = "mdi:cancel"; })
    (mkTotal {
      key = "devices_without_internet_blocked_total";
      label = "Devices without internet blocked total";
      icon = "mdi:lan-disconnect";
    })
    (mkEntity {
      key = "cache_entries";
      label = "Cache entries";
      extra = {
        state_class = "measurement";
        icon = "mdi:database";
      };
    })
    (mkEntity {
      key = "denylist_entries";
      label = "Denylist entries";
      extra = {
        state_class = "measurement";
        icon = "mdi:playlist-remove";
      };
    })
    (mkEntity {
      key = "errors";
      label = "Errors last hour";
      extra = {
        state_class = "measurement";
        icon = "mdi:alert";
      };
    })
    # Nullable: blocky refreshes its lists at startup, so this is only unset in
    # the window before the first refresh completes — transient, unlike the
    # metrics a device can never report (which get no entity at all).
    (mkEntity {
      key = "list_refreshed";
      label = "Blocklists refreshed";
      nullable = true;
      extra = {
        device_class = "timestamp";
        icon = "mdi:playlist-check";
      };
    })
    # The whole record hangs off the problem sensor as attributes, so version,
    # allowlist size, failed downloads and the problem list itself are one click
    # away without minting an entity each.
    (mkEntity {
      component = "binary_sensor";
      key = "problem";
      label = "Problem";
      valueTemplate = "{{ 'ON' if value_json.problem_count | int(0) > 0 else 'OFF' }}";
      extra = {
        device_class = "problem";
        payload_on = "ON";
        payload_off = "OFF";
        json_attributes_topic = statsTopic;
      };
    })
  ];

  statsDiscoveryFile = pkgs.writeText "blocky-stats2mqtt-discovery.json"
    (builtins.toJSON statsEntities);

  mkStatsUnit = { description, mode }: {
    inherit description;
    path = [ pkgs.bash pkgs.coreutils pkgs.curl pkgs.gawk pkgs.jq pkgs.mosquitto ];
    environment = {
      BS_METRICS_URL = "http://127.0.0.1:${toString httpPort}/metrics";
      BS_TOPIC = statsTopic;
      BS_MQTT_USER = "blocky2mqtt";
      BS_MQTT_PASS = config.secrets.mqtt.users.blocky2mqtt.password;
      BS_DISCOVERY_FILE = "${statsDiscoveryFile}";
      # Blocks attributed to these denylist groups are reported as
      # `devices_without_internet_blocked` rather than `blocked`.
      # Comma-separated; a block whose reason names several groups counts as a
      # cutoff if any one of them matches.
      BS_DEVICES_WITHOUT_INTERNET_GROUPS = devicesWithoutInternetGroup;
      BS_STATE = "/var/lib/blocky-stats/state";
    };
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.bash}/bin/bash ${statsScript} ${mode}";
      StateDirectory = "blocky-stats";
      Nice = 19;
      TimeoutStartSec = "2min";
      PrivateTmp = true;
      ProtectHome = true;
      ProtectSystem = "strict";
      RestrictRealtime = true;
      RestrictSUIDSGID = true;
      SystemCallArchitectures = "native";
    };
  };
in
{
  # Local resolver + ad-blocker + split-horizon DNS.
  #
  # Router/DHCP (not managed by this flake) needs to hand LAN clients:
  #   - DNS server: nhtpc's LAN address (192.168.0.2)
  #   - domain suffix: l.nathan.gs
  # WireGuard peers need DNS = 10.73.221.1 (nhtpc's wg0 address) and search
  # domain wg.nathan.gs configured client-side in their tunnel config.
  networking.firewall.allowedUDPPorts = [ 53 ];
  networking.firewall.allowedTCPPorts = [ 53 ];

  services.blocky = {
    enable = true;
    settings = {
      ports = {
        dns = [ 53 ];
        # local-only; DoH is exposed publicly via nginx (see below) on
        # dns.l.nathan.gs / dns.wg.nathan.gs. High port deliberately picked
        # to stay clear of 4000, which nathan reserves for occasional
        # ad-hoc use.
        http = httpPort;
      };

      # DNS-over-HTTPS upstreams so blocky's outgoing queries aren't plain
      # UDP/TCP. bootstrapDns resolves the DoH hostnames themselves before
      # blocky has a working resolver of its own.
      upstreams.groups.default = [
        "https://cloudflare-dns.com/dns-query"
        "https://dns.quad9.net/dns-query"
      ];
      bootstrapDns = [
        "tcp+udp:1.1.1.1"
        "tcp+udp:9.9.9.9"
      ];

      caching = {
        minTime = "5m";
        maxTime = "30m";
        prefetching = true;
        prefetchExpires = "2h";
        prefetchThreshold = 5;
      };

      # Per-query logging ("query resolved ...") is very high volume and not
      # useful day-to-day — disabled. Periodic cached/resolved/blocked totals
      # are logged instead via the blocky-stats-log timer below, sourced from
      # the Prometheus metrics endpoint enabled here (local-only, not
      # exposed beyond nginx's /dns-query proxy).
      queryLog.type = "none";
      prometheus.enable = true;

      # Ads + trackers — no malware/social lists.
      blocking = {
        denylists = {
          ads = [
            "https://adaway.org/hosts.txt"
            "https://s3.amazonaws.com/lists.disconnect.me/simple_ad.txt"
            "https://raw.githubusercontent.com/anudeepND/blacklist/master/adservers.txt"
          ];
          trackers = [
            "https://v.firebog.net/hosts/Easyprivacy.txt"
          ];
          # Catch-all: matches every domain. Combined with the allowlist
          # below, this gives select smarthome devices DNS resolution for
          # l.nathan.gs only — best-effort internet cutoff for devices that
          # respect the DHCP-provided DNS server (not a hard network block;
          # a device that hardcodes its own resolver bypasses this).
          # Must be a multi-line block, not a single-line list item — a
          # bare single-line entry (even regex-looking) gets treated as a
          # source reference (file/URL) to fetch, not inline content, and
          # silently fails to load (confirmed empirically: 0 entries).
          "${devicesWithoutInternetGroup}" = [
            ''
              /.*/
            ''
          ];
        };
        allowlists = {
          # NTP hostnames, so restricted devices can still sync their clock
          # even though they otherwise only get l.nathan.gs. Domain entries
          # cover subdomains too (e.g. 0.pool.ntp.org, europe.pool.ntp.org).
          "${devicesWithoutInternetGroup}" = [
            ''
              l.nathan.gs
              pool.ntp.org
              ntp.org
              time.google.com
              time.windows.com
              time.apple.com
              time.cloudflare.com
            ''
          ];
          # Google/YouTube telemetry endpoints that the upstream lists flag as
          # trackers but that YouTube's own JS (watch page, Studio, upload,
          # sign-in) hard-depends on: failures surface as a flood of console
          # errors and can stall the sign-in/upload flows waiting on them.
          # These carry no ads — the actual ad domains (ads.youtube.com,
          # adservice.google.com, doubleclick, googlesyndication, …) stay
          # blocked. Listed under both groups since `default` clients get
          # ads + trackers and a domain may appear in either.
          ads = [ googleFunctional ];
          trackers = [ googleFunctional ];
        };
        clientGroupsBlock = { default = [ "ads" "trackers" ]; } // restrictedClientsBlock;
        # nxDomain, not zeroIp: on Linux a connect() to 0.0.0.0 targets
        # localhost rather than failing, so a blocked name turns into a
        # connection to whatever the client happens to be running (or a
        # hang) instead of a clean, immediate DNS failure. NXDOMAIN fails
        # fast, which is what browser fetch/XHR retry logic expects.
        blockType = "nxDomain";
        loading.refreshPeriod = "24h";
      };

      # Split-horizon local names: the same short hostname resolves
      # differently depending on which zone it's queried under, e.g.
      # ha.l.nathan.gs (LAN) vs ha.wg.nathan.gs (WireGuard) — matching the
      # ACME SANs already issued in home-assistant.nix and friends.
      #
      # l.nathan.gs has no apex ("@") record and no wildcard: blocky matches
      # customDNS entries the same way its blocklists do (domain + all
      # subdomains), so an "@" record for l.nathan.gs itself would make
      # ANY unlisted subdomain resolve too, same as "*" would (confirmed
      # empirically — removing "*" alone wasn't enough). Every name that
      # should resolve (home-network.nix devices + nhtpc's own aliases)
      # has its own explicit record, so unlisted/typo'd names properly
      # NXDOMAIN. wg.nathan.gs still has @ + a wildcard since
      # ha/photoprism/m/read's .wg. SANs aren't explicitly listed there —
      # nhtpc is the only host serving these, so it's harmless.
      customDNS = {
        filterUnmappedTypes = true;
        mapping =
          {
            # AVM publicly owns "fritz.box" (it resolves to a real internet
            # address via upstream DNS otherwise) — override it back to the
            # actual router so browsing to it doesn't silently hit AVM's
            # servers instead of the local admin UI.
            "fritz.box" = "192.168.0.1";
          }
          // bareDeviceMappings;
        zone = ''
          $ORIGIN l.nathan.gs.
          ${deviceZoneRecords}
          $ORIGIN wg.nathan.gs.
          @ 3600 IN A 10.73.221.1
          * 3600 IN A 10.73.221.1
          nnas 3600 IN A 10.73.221.2
          nphone 3600 IN A 10.73.221.10
          nlaptop 3600 IN A 10.73.221.11
          fphone 3600 IN A 10.73.221.12
        '';
      };

      logLevel = "info";
    };
  };

  # Hourly cached/uncached/blocked counts into MQTT (and one journal line),
  # since per-query logging is off above. Reads blocky's local Prometheus
  # endpoint (response_type label: CACHED / BLOCKED / RESOLVED / CUSTOMDNS) and
  # diffs against the previous run's cumulative counters for the per-hour
  # delta. Counters reset on blocky restart; a negative delta is clamped to 0
  # for that one run rather than reporting garbage.
  systemd.services.blocky-stats2mqtt = lib.recursiveUpdate
    (mkStatsUnit {
      description = "blocky-stats2mqtt: query counts to MQTT";
      mode = "stats";
    })
    {
      after = [ "blocky.service" "mosquitto.service" ];
    };

  systemd.timers.blocky-stats2mqtt = {
    description = "blocky-stats2mqtt: query counts timer";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "10min";
      OnUnitActiveSec = "1h";
      # Deliberately not Persistent: the counters are cumulative, so a catch-up
      # run after downtime would attribute hours of queries to a single "last
      # hour" bucket.
      AccuracySec = "1min";
    };
  };

  # Retained discovery, republished at boot and after every switch so an HA
  # restart or a changed entity list converges without manual work.
  systemd.services.blocky-stats2mqtt-discovery = lib.recursiveUpdate
    (mkStatsUnit {
      description = "blocky-stats2mqtt: publish Home Assistant MQTT discovery";
      mode = "discovery";
    })
    {
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" "mosquitto.service" ];
      wants = [ "network-online.target" ];
      # At boot the broker may not be accepting connections yet, and without
      # discovery the entities never appear at all — so this one retries.
      serviceConfig = {
        Restart = "on-failure";
        RestartSec = "30s";
      };
    };

  # Manual, never timed: clears the retained discovery configs so the entities
  # are dropped and can be recreated (needed after an entity_id change — HA only
  # honours default_entity_id on creation). Follow with
  # `systemctl start blocky-stats2mqtt-discovery`.
  systemd.services.blocky-stats2mqtt-purge = mkStatsUnit {
    description = "blocky-stats2mqtt: purge Home Assistant MQTT discovery";
    mode = "purge";
  };

  # DNS-over-HTTPS: nginx terminates TLS (same ACME-via-Cloudflare-DNS-01
  # pattern as the rest of the fleet) and proxies to blocky's plain-HTTP
  # DoH endpoint. DNS-01 works for dns.l.nathan.gs/dns.wg.nathan.gs even
  # though they're not publicly reachable, since the challenge is just a
  # TXT record under the nathan.gs zone.
  security.acme.certs."dns.nathan.gs" = {
    group = "nginx";
    dnsProvider = "cloudflare";
    environmentFile = pkgs.writeText "acme-dns-cloudflare-env" ''
      CLOUDFLARE_EMAIL=${config.secrets.cloudflare.authEmail}
      CLOUDFLARE_API_KEY=${config.secrets.cloudflare.authKey}
    '';
    extraDomainNames = [ "dns.l.nathan.gs" "dns.wg.nathan.gs" ];
  };

  services.nginx.virtualHosts."dns.nathan.gs" = {
    forceSSL = true;
    useACMEHost = "dns.nathan.gs";
    serverAliases = [ "dns.l.nathan.gs" "dns.wg.nathan.gs" ];
    # LAN/WireGuard only — DoH has no business being reachable from the
    # public internet, unlike the rest of the vhosts on this nginx.
    extraConfig = config.homeNetwork.nginxLanOnly;
    locations."/dns-query" = {
      proxyPass = "http://127.0.0.1:${toString httpPort}/dns-query";
    };
  };
}

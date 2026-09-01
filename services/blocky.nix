{ config, pkgs, lib, ... }:
let
  devices = config.homeNetwork.devices;

  # Explicit per-device records under l.nathan.gs (home-network.nix).
  deviceZoneRecords = lib.concatMapStrings (
    d:
    "${d.name} 3600 IN A ${d.ip}\n"
    + lib.concatMapStrings (a: "${a} 3600 IN A ${d.ip}\n") d.aliases
  ) devices;

  restrictedClientsBlock = lib.listToAttrs (
    map (d: lib.nameValuePair d.ip [ "everything" ]) (lib.filter (d: !d.internet) devices)
  );

  # Bare (no .l.nathan.gs suffix) mapping for every device name + alias, so
  # e.g. "ping mqtt" works even for clients that don't apply the DHCP
  # domain-search suffix (see the smartgatewayp1/nhtpc issue this
  # generalizes). Checked for collisions against home-network.nix before
  # relying on this — same mechanism as the existing fritz.box override.
  bareDeviceMappings = lib.listToAttrs (
    lib.concatMap (d: map (n: lib.nameValuePair n d.ip) ([ d.name ] ++ d.aliases)) devices
  );
in
{
  # Local resolver + ad-blocker + split-horizon DNS.
  #
  # Router/DHCP (not managed by this flake) needs to hand LAN clients:
  #   - DNS server: nhtpc's LAN address (192.168.1.2)
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
        # dns.l.nathan.gs / dns.wg.nathan.gs.
        http = 4000;
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
            "https://raw.githubusercontent.com/anudeepND/blacklist/master/facebook.txt"
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
          everything = [
            ''
              /.*/
            ''
          ];
        };
        # NTP hostnames, so restricted devices can still sync their clock
        # even though they otherwise only get l.nathan.gs. Domain entries
        # cover subdomains too (e.g. 0.pool.ntp.org, europe.pool.ntp.org).
        allowlists.everything = [
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
        clientGroupsBlock = { default = [ "ads" "trackers" ]; } // restrictedClientsBlock;
        blockType = "zeroIp";
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
            "fritz.box" = "192.168.1.1";
          }
          // bareDeviceMappings;
        zone = ''
          $ORIGIN l.nathan.gs.
          ${deviceZoneRecords}
          $ORIGIN wg.nathan.gs.
          @ 3600 IN A 10.73.221.1
          * 3600 IN A 10.73.221.1
          nnas 3600 IN A 10.73.221.2
          nhpone 3600 IN A 10.73.221.10
          nlaptop 3600 IN A 10.73.221.11
          fphone 3600 IN A 10.73.221.12
        '';
      };

      logLevel = "info";
    };
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
    extraConfig = ''
      allow 192.168.1.0/24;
      allow 10.73.221.0/24;
      allow 127.0.0.1;
      deny all;
    '';
    locations."/dns-query" = {
      proxyPass = "http://127.0.0.1:4000/dns-query";
    };
  };
}

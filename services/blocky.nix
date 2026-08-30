{ config, pkgs, lib, ... }:
let
  devices = config.homeNetwork.devices;

  # Explicit per-device records under l.nathan.gs (home-network.nix). An
  # explicit name always wins over the "*" wildcard below, so this doesn't
  # conflict with it.
  deviceZoneRecords = lib.concatMapStrings (
    d:
    "${d.name} 3600 IN A ${d.ip}\n"
    + lib.concatMapStrings (a: "${a} 3600 IN A ${d.ip}\n") d.aliases
  ) devices;

  restrictedClientsBlock = lib.listToAttrs (
    map (d: lib.nameValuePair d.ip [ "everything" ]) (lib.filter (d: !d.internet) devices)
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

      upstreams.groups.default = [
        "1.1.1.1"
        "1.0.0.1"
        "9.9.9.9"
      ];

      caching = {
        minTime = "5m";
        maxTime = "30m";
        prefetching = true;
        prefetchExpires = "2h";
        prefetchThreshold = 5;
      };

      # Ads only — no trackers/malware/social lists.
      blocking = {
        denylists = {
          ads = [
            "https://adaway.org/hosts.txt"
            "https://s3.amazonaws.com/lists.disconnect.me/simple_ad.txt"
            "https://raw.githubusercontent.com/anudeepND/blacklist/master/adservers.txt"
          ];
          # Catch-all: matches every domain. Combined with the allowlist
          # below, this gives select smarthome devices DNS resolution for
          # l.nathan.gs only — best-effort internet cutoff for devices that
          # respect the DHCP-provided DNS server (not a hard network block;
          # a device that hardcodes its own resolver bypasses this).
          everything = [ "/.*/" ];
        };
        allowlists.everything = [ "l.nathan.gs" ];
        clientGroupsBlock = { default = [ "ads" ]; } // restrictedClientsBlock;
        blockType = "zeroIp";
        loading.refreshPeriod = "24h";
      };

      # Split-horizon local names: the same short hostname resolves
      # differently depending on which zone it's queried under, e.g.
      # ha.l.nathan.gs (LAN) vs ha.wg.nathan.gs (WireGuard) — matching the
      # ACME SANs already issued in home-assistant.nix and friends. nhtpc
      # is currently the only host serving these web-facing names, so the
      # wildcards point everything at it; nginx routes further by Host
      # header. Devices from home-network.nix additionally get their own
      # explicit name(s) under l.nathan.gs.
      customDNS = {
        filterUnmappedTypes = true;
        # AVM publicly owns "fritz.box" (it resolves to a real internet
        # address via upstream DNS otherwise) — override it back to the
        # actual router so browsing to it doesn't silently hit AVM's
        # servers instead of the local admin UI.
        mapping."fritz.box" = "192.168.1.1";
        # Bare "nhtpc" (no .l.nathan.gs suffix) — some embedded/IoT clients
        # (e.g. smartgatewayp1) don't apply the DHCP domain-search suffix.
        mapping."nhtpc" = "192.168.1.2";
        zone = ''
          $ORIGIN l.nathan.gs.
          @ 3600 IN A 192.168.1.2
          * 3600 IN A 192.168.1.2
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

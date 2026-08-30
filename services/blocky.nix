{ config, pkgs, lib, ... }:
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
        clientGroupsBlock = {
          default = [ "ads" ];
          "192.168.1.30" = [ "everything" ]; # smartgatewayp1
          "192.168.1.31" = [ "everything" ]; # smartgatewaywater
          "192.168.1.33" = [ "everything" ]; # bluetooth-proxy-boven
          "192.168.1.34" = [ "everything" ]; # ebus
          "192.168.1.35" = [ "everything" ]; # car-charger
        };
        blockType = "zeroIp";
        loading.refreshPeriod = "24h";
      };

      # Split-horizon local names: the same short hostname resolves
      # differently depending on which zone it's queried under, e.g.
      # ha.l.nathan.gs (LAN) vs ha.wg.nathan.gs (WireGuard) — matching the
      # ACME SANs already issued in home-assistant.nix and friends. nhtpc
      # is currently the only host serving these, so both zones just point
      # everything at it; nginx routes further by Host header.
      customDNS = {
        filterUnmappedTypes = true;
        zone = ''
          $ORIGIN l.nathan.gs.
          @ 3600 IN A 192.168.1.2
          * 3600 IN A 192.168.1.2
          $ORIGIN wg.nathan.gs.
          @ 3600 IN A 10.73.221.1
          * 3600 IN A 10.73.221.1
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
    locations."/dns-query" = {
      proxyPass = "http://127.0.0.1:4000/dns-query";
    };
  };
}

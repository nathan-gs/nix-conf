{ config, pkgs, lib, ... }:
let
  # Cloudflare's published edge ranges, from https://www.cloudflare.com/ips-v4
  # and .../ips-v6, fetched 2026-09-19. They change rarely -- refresh by hand.
  # A stale list fails safe: a new Cloudflare range simply goes back to showing
  # the edge address, it never trusts something it shouldn't.
  cloudflareRanges = [
    "173.245.48.0/20"
    "103.21.244.0/22"
    "103.22.200.0/22"
    "103.31.4.0/22"
    "141.101.64.0/18"
    "108.162.192.0/18"
    "190.93.240.0/20"
    "188.114.96.0/20"
    "197.234.240.0/22"
    "198.41.128.0/17"
    "162.158.0.0/15"
    "104.16.0.0/13"
    "104.24.0.0/14"
    "172.64.0.0/13"
    "131.0.72.0/22"
    "2400:cb00::/32"
    "2606:4700::/32"
    "2803:f800::/32"
    "2405:b500::/32"
    "2405:8100::/32"
    "2a06:98c0::/29"
    "2c0f:f248::/32"
  ];
in
{

  networking.firewall.allowedTCPPorts = [ 80 443 ];
  services.nginx = {
    enable = true;

    # Use recommended settings
    recommendedGzipSettings = true;
    recommendedOptimisation = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;

    # Only allow PFS-enabled ciphers with AES256
    sslCiphers = "AES256+EECDH:AES256+EDH:!aNULL";
    
    commonHttpConfig = ''
      # Add HSTS header with preloading to HTTPS requests.
      # Adding this header to HTTP requests is discouraged
      map $scheme $hsts_header {
          https   "max-age=31536000; includeSubdomains; preload";
      }
      add_header Strict-Transport-Security $hsts_header;

      # Enable CSP for your services.
      add_header Content-Security-Policy "object-src 'self'; base-uri 'self';" always;

      # Minimize information leaked to other domains
      add_header 'Referrer-Policy' 'origin-when-cross-origin';

      # Disable embedding as a frame
      add_header X-Frame-Options SAMEORIGIN always;

      # Prevent injection of code in other mime types (XSS Attacks)
      add_header X-Content-Type-Options nosniff;

      # Enable XSS protection of the browser.
      # May be unnecessary when CSP is configured properly (see above)
      add_header X-XSS-Protection "1; mode=block";

      # This might create errors
      proxy_cookie_path / "/; secure; HttpOnly; SameSite=strict";

      proxy_headers_hash_max_size 1024;
      proxy_headers_hash_bucket_size 128;

      # Restore the real client address behind Cloudflare.
      #
      # Cloudflare proxies the public names, so without this every request that
      # arrives through it has $remote_addr set to a Cloudflare edge. The access
      # log, the geo block below and every fail2ban jail then see the edge and
      # never the client -- which is not merely blind but actively harmful: the
      # home-assistant jail has already banned 172.71.232.40, 141.101.96.3 and
      # 141.101.68.126, all Cloudflare edges. The first of those is the edge
      # that carries the Android companion app's webhooks, so that ban blocked
      # our own traffic while leaving the actual scanner untouched.
      #
      # Trusting CF-Connecting-IP from Cloudflare's ranges rewrites $remote_addr
      # in the post-read phase, before logging, geo/map and deny run, so:
      #   - the access log records the client instead of the edge;
      #   - fail2ban's nginx jails ban the client;
      #   - the X-Forwarded-For that recommendedProxySettings appends is
      #     $proxy_add_x_forwarded_for, whose last hop is $remote_addr, so it
      #     now ends with the client. Home Assistant trusts 127.0.0.1 and walks
      #     the chain from the right, so it lands on the client too rather than
      #     stopping at the edge (its own http settings live in HA's .storage,
      #     set through the UI, not here).
      #
      # Only Cloudflare's ranges are trusted, so a client hitting the public IP
      # directly cannot forge this: it is not in the list, so its
      # CF-Connecting-IP header is ignored entirely.
      #
      # This leaves the geo guard below intact. It reads $remote_addr and so
      # sees the rewritten value, but Cloudflare only ever forwards traffic
      # that reached it from the internet, so a rewritten address is always
      # public and can never match the LAN or WireGuard ranges.
      #
      # Note it does nothing for hairpinned LAN traffic: a browser on the LAN
      # resolving a public name exits to the router and comes back from our own
      # WAN address, direct rather than via Cloudflare. That address stays
      # untrusted here and is not in trustedSources, so a jail can still ban it
      # and lock the whole house out of the public names at once. Split-horizon
      # DNS for the public names is the fix for that, not real_ip.
      ${lib.concatMapStringsSep "\n      " (r: "set_real_ip_from ${r};") cloudflareRanges}
      real_ip_header CF-Connecting-IP;

      # Keep *.l.nathan.gs / *.wg.nathan.gs off the public internet.
      #
      # Those names share a server block (and therefore a listen socket) with
      # the public name of the same service, and nginx selects the block from
      # Host/SNI alone -- never from the address the connection arrived on.
      # The router also DNATs WAN traffic to nhtpc's LAN address, so binding
      # per-address cannot separate them either. That leaves the source IP as
      # the only usable signal: an internal name from an external client is a
      # spoofed Host header, so reject it.
      #
      # $homenet_reject is "1" only for (internal name, external client).
      # Vhosts opt in with `if ($homenet_reject) { return 403; }`; a vhost with
      # no public name at all uses homeNetwork.nginxLanOnly instead.
      geo $homenet_client {
        default 0;
        ${lib.concatMapStringsSep "\n        " (r: "${r} 1;") config.homeNetwork.trustedSources}
      }

      map $host $homenet_only_name {
        default 0;
        "~^.+\.(l|wg)\.nathan\.gs$" 1;
      }

      map "$homenet_only_name$homenet_client" $homenet_reject {
        default 0;
        "10" 1;
      }
    '';

  };

  security.acme = {
    acceptTerms = true;
    defaults.email = config.secrets.email;
  };

  environment.etc."fail2ban/filter.d/nginx-http-auth-custom.conf".source = ./fail2ban/nginx-http-auth-custom.conf;
  environment.etc."fail2ban/filter.d/nginx-forbidden-custom.conf".source = ./fail2ban/nginx-forbidden-custom.conf;

  services.fail2ban.jails = {
    nginx-http-auth-custom = {
      filter = "nginx-http-auth-custom";
      enabled = true;
    };

    # Scanners denied by an access rule (see the filter for why that is only
    # ever a scanner). A handful of hosts are the overwhelming majority of the
    # traffic -- one of them managed 2999 requests in 60 seconds -- so the
    # point of this jail is to cut a burst off after the first second rather
    # than to catch the long tail of one-shot drive-by probes, which no
    # maxretry can ever see. bantime-increment is on globally
    # (services/fail2ban.nix), so a host that comes back escalates from the
    # hour below.
    nginx-forbidden-custom = {
      settings = {
        enabled = true;
        filter = "nginx-forbidden-custom";
        maxretry = 5;
        findtime = 600;
        bantime = 3600;
      };
    };
  };

}

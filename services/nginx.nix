{ config, pkgs, lib, ... }:
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

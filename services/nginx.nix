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
    '';

  };

  security.acme = {
    acceptTerms = true;
    defaults.email = config.secrets.email;
  };

  environment.etc."fail2ban/filter.d/nginx-http-auth-custom.conf".source = ./fail2ban/nginx-http-auth-custom.conf;

  services.fail2ban.jails = {
    nginx-http-auth-custom = {
      filter = "nginx-http-auth-custom";
      enabled = true;
    };
  };

}

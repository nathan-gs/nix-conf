{ config, pkgs, lib, ... }:

let
  matomoDomain = "t.nathan.gs"; 
in
{
  services.matomo = {
    enable = true;

    hostname = matomoDomain;

    nginx = {
      serverName = matomoDomain;
      serverAliases = [ "t.scrydon.com" ];

      enableACME = true;
      forceSSL    = true;

      locations = {
        # Only this one location: /mt → /matomo.php (exact match, GET/POST allowed)
        "= /mt" = {
          priority = 100;  # higher than most defaults to catch it early
          extraConfig = ''
            # Rewrite the request URI so Matomo sees it as /matomo.php
            rewrite ^/mt$ /matomo.php last;

            # Important: tell Matomo the original requested path (helps with some internal logic)
            # (optional but recommended when rewriting the tracker endpoint)
            proxy_set_header X-Original-URI $request_uri;

            # Let it fall through to the existing PHP handler for /matomo.php
          '';
        };

        # Optional but useful: also support /mt? with query string (most tracking requests have ?idsite=...&...)
        "~ ^/mt(\\?.*)?$" = {
          priority = 100;
          extraConfig = ''
            rewrite ^/mt(.*)$ /matomo.php$1 last;
            proxy_set_header X-Original-URI $request_uri;
          '';
        };
      };
  
    };
  };

  services.mysql = {
    ensureDatabases = [ "matomo" ];
    ensureUsers = [
      {
        name = "matomo";
        ensurePermissions = {
          "matomo.*" = "ALL PRIVILEGES";
        };
      }
    ];
  };

  services.matomo.periodicArchiveProcessing = true;
}
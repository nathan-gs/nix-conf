{ config, pkgs, lib, ... }:

let
  matomoDomain = "t.nathan.gs";

  # Marketplace installs write into the Matomo tree; that is immutable in
  # the Nix store. Bake plugins into the package instead.
  mcpServer = pkgs.callPackage ../pkgs/matomo-plugin-mcp-server.nix { };
  provider = pkgs.callPackage ../pkgs/matomo-plugin-provider.nix { };
  matomoWithPlugins = pkgs.nixpkgs-unstable.matomo.overrideAttrs (old: {
    postInstall = (old.postInstall or "") + ''
      cp -a ${mcpServer}/share/plugins/McpServer $out/share/plugins/McpServer
      cp -a ${provider}/share/plugins/Provider $out/share/plugins/Provider
    '';
  });
in
{
  services.matomo = {
    enable = true;

    hostname = matomoDomain;

    package = matomoWithPlugins;

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

  # Archive every 5 minutes instead of the module's hourly default. A run on
  # nhtpc costs ~0.5s CPU for the four sites, and past days are archived once
  # and never again, so the cadence only changes how stale *today* is.
  # Matomo skips re-archiving today while the existing archive is younger
  # than time_before_today_archive_considered_outdated (default 900s), so
  # that is lowered to match below — otherwise 2 of every 3 runs are no-ops.
  systemd.timers.matomo-archive-processing.timerConfig.OnCalendar =
    lib.mkForce "*:0/5";

  # Increase PHP memory limit for Matomo archive processing
  # Default 128M causes empty responses on week/month/year report archiving
  services.phpfpm.pools.matomo.phpOptions = lib.mkAfter ''
    memory_limit = 512M
  '';

  # Files are in the package; activation writes Plugins[] into config.ini.php.
  systemd.services.matomo-setup-update.script = lib.mkAfter ''
    if test -f /var/lib/matomo/config/config.ini.php &&
       grep -q -F "[database]" /var/lib/matomo/config/config.ini.php; then
      matomo-console plugin:activate McpServer
      matomo-console plugin:activate Provider
      # Keep in step with the archive timer above.
      matomo-console config:set --section=General \
        --key=time_before_today_archive_considered_outdated --value=300
      # Keep archiving performance metrics forever (default: 180 days).
      # 0 disables the cleanup task entirely.
      matomo-console config:set --section=ArchivingMetrics \
        --key=retention_days --value=0
    fi
  '';
}
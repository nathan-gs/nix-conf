{ config, pkgs, lib, ... }:

{

  systemd.services.autogenstudio = {
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      serviceConfig = {
        ExecStart = ''${(pkgs.python312Packages.callPackage ../pkgs/python/autogen-studio.nix {})}/bin/autogenstudio ui --workers 2 --appdir /var/lib/autogenstudio --port 8081'';
        DynamicUser = true;
        Restart = "on-failure";
        StateDirectory = "autogenstudio";
        ReadWritePaths = ["/var/lib/autogenstudio"];
        WorkingDirectory = "/var/lib/autogenstudio";
        # Hardening
        CapabilityBoundingSet = "";
        DeviceAllow = [];
        DevicePolicy = "closed";
        LockPersonality = true;
        MemoryDenyWriteExecute = false;
        NoNewPrivileges = true;
        PrivateDevices = false;
        PrivateUsers = true;
        PrivateTmp = true;
        ProtectClock = true;
        ProtectControlGroups = true;
        ProtectHome = true;
        ProtectHostname = true;
        ProtectKernelLogs = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        ProtectProc = "invisible";
        ProcSubset = "pid";
        ProtectSystem = "strict";
        RemoveIPC = true;
        RestrictAddressFamilies = [
          "AF_INET"
          "AF_INET6"
        ];
        RestrictNamespaces = true;
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
        SupplementaryGroups = [];
        SystemCallArchitectures = "native";
        UMask = "0077";
      };
    };

  services.nginx.virtualHosts."autogen.nathan.gs" = {
    forceSSL = true;
    enableACME = true;
    extraConfig = ''
      proxy_buffering off;
    '';
    basicAuth = config.secrets.nginx.basicAuth;
    locations."/" = {
      proxyPass = "http://127.0.0.1:8081";
      proxyWebsockets = true; # needed if you need to use WebSocket
      extraConfig = ''
        # required when the target is also TLS server with multiple hosts
        proxy_ssl_server_name on;
        # required when the server wants to use HTTP Authentication
        proxy_pass_header Authorization;

        proxy_set_header X-Real-IP          $remote_addr;
        proxy_set_header X-Forwarded-For    $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto  $scheme;
      '';
    };
  };
  
}

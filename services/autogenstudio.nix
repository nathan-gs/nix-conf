{ config, pkgs, lib, ... }:

{

  systemd.services.autogenstudio = {
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      serviceConfig = {
        ExecStart = ''${(pkgs.python313Packages.callPackage ../pkgs/python/autogen-studio.nix {})}/bin/autogenstudio ui --workers 2 --appdir /var/lib/autogenstudio --port 8081'';
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

}

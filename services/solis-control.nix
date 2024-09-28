{ config, pkgs, lib, ... }:
{

  systemd.services.solis-control = {
    description = "Solis Control Service";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    serviceConfig = {
      ExecStart = lib.concatStringsSep " " [ 
        ''${(pkgs.callPackage ../pkgs/solis-control.nix {})}/bin/solis-control'' 
        ''--mqtt-user soliscontrol''
        ''--mqtt-password ${config.secrets.mqtt.users.soliscontrol.password}''
        ''--solis-inverter ${config.secrets.solis.inverter}''
        ''--solis-keyid ${config.secrets.solis.keyid}''
        ''--solis-secret ${config.secrets.solis.secret}''
      ];
      DynamicUser = true;
      Restart = "on-failure";
      # Hardening
      CapabilityBoundingSet = "";
      DeviceAllow = [];
      DevicePolicy = "closed";
      LockPersonality = true;
      MemoryDenyWriteExecute = false;
      NoNewPrivileges = true;
      PrivateDevices = true;
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
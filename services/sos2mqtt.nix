{ config, pkgs, lib, ... }:
{

  systemd.services.sos2mqtt = {
    description = "sos2mqtt Service";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    startAt = "*-*-* *:35:00";
    serviceConfig = {
      ExecStart = lib.concatStringsSep " " [ 
        ''${(pkgs.callPackage ../pkgs/sos2mqtt.nix {})}/bin/sos2mqtt'' 
        ''--base-url "https://geo.irceline.be/sos"''
        ''--mqtt-topic-prefix "irceline/"''
        ''--mqtt-user sos2mqtt''
        ''--mqtt-password ${config.secrets.mqtt.users.sos2mqtt.password}''
        ''--stations-list "linkeroever,rieme,uccle,moerkerke,idegem,gent,gent_carlierlaan,gent_lange_violettestraat,destelbergen,wondelgem,evergem,sint_kruiswinkel,zelzate,wachtebeke"''        
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
      Type = "oneshot";
    };
  };
}
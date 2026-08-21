{ config, pkgs, lib, ... }:
{

  systemd.services.pylontech2mqtt = {
    description = "pylontech2mqtt Service";
    after = [ "network.target" "mosquitto.service" ];
    serviceConfig = {
      ExecStart = lib.concatStringsSep " " [
        ''${(pkgs.callPackage ../pkgs/pylontech2mqtt.nix {})}/bin/pylontech2mqtt''
        ''--port "/dev/serial/by-id/usb-1a86_USB2.0-Ser_-if00-port0"''
        ''--addresses "2,3"''
        ''--mqtt-topic-prefix "pylontech/"''
        ''--mqtt-user pylontech2mqtt''
        ''--mqtt-password ${config.secrets.mqtt.users.pylontech2mqtt.password}''
      ];
      DynamicUser = true;
      SupplementaryGroups = [ "dialout" ];
      Restart = "on-failure";
      # Hardening
      CapabilityBoundingSet = "";
      DeviceAllow = [ "char-ttyUSB rw" ];
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
        "AF_UNIX"
      ];
      RestrictNamespaces = true;
      RestrictRealtime = true;
      RestrictSUIDSGID = true;
      SystemCallArchitectures = "native";
      UMask = "0077";
      Type = "oneshot";
    };
  };

  systemd.timers.pylontech2mqtt = {
    wantedBy = [ "timers.target" ];
    partOf = [ "pylontech2mqtt.service" ];
    timerConfig = {
      OnBootSec = "2m";
      OnUnitActiveSec = "5m";
      Unit = "pylontech2mqtt.service";
    };
  };
}

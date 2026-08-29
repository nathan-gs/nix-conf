{ channels, config, pkgs, lib, ... }:
let
  # OneDrive webhook already binds 8888 (see services/onedrive.nix).
  # ebusd's default command port collides, so ebusctl/HA TCP never work.
  ebusdPort = 8878;

  # mqtt-hassio.cfg defaults to filter-name matching status|temp|sensor|timer|…
  # which auto-polls (filter-seen=5) ~280 entities. On this boiler that includes
  # unimplemented registers (Status, Status16, VortexFlowSensor → ERR: invalid
  # position / 00 response) and 370 day-timers that time out on the bus.
  #
  # Scan (2026-08-19):
  #   08 BAI00 SW0518 HW7401 → vaillant/08.bai.csv + bai.308523.inc
  #   15 37000 SW0129 HW6002 → vaillant/15.370.csv
  #   26 37000 SW0129 HW6002 → no 26.370.csv (same ident as 15; 370's 2nd address;
  #     ebusd logs "unable to load scan config 26" every start, harmless — no
  #     entity depends on circuit 26 and nothing on the bus talks to it alone)
  #
  # Register rename vs older CSV / HA ebusd const.py:
  #   ModulationTempDesired does not exist; use ModulationDesired (b509/0d2e00).
  #
  # ./ebusd-csv mirrors https://ebus.github.io/en/{,vaillant/} for just these two
  # devices — verified byte-for-byte against `ebusctl find -f -v -a` on both
  # circuits (2026-08-29): every live register matches (only gap is the
  # install-level Clearerrorhistory write command, which needs auth to show up
  # in `find` but is present here too). 08.bai.csv's manufacturer-variant
  # !load branches for other BAI hardware revisions were trimmed to just
  # id_hw=7401 (this unit) — the untrimmed file's dead branches otherwise log
  # an "element not found" error every restart, since nothing local can fetch
  # them over HTTPS. Local files remove the runtime dependency on
  # ebus.github.io being reachable and stay pinned to what this exact
  # boiler/controller actually expose.
  ebusdConfigPath = ./ebusd-csv;
  haFilterName = lib.concatStringsSep "|" [
    # boiler (bai) — live operating data
    "^Status01$"
    "^Status02$"
    "^FlowTemp$"
    "^FlowTempDesired$"
    "^ReturnTemp$"
    "^HwcTemp$"
    "^HwcTempDesired$"
    "^StorageTemp$"
    "^StorageTempDesired$"
    "^OutdoorstempSensor$"
    "^WaterPressure$"
    "^Flame$"
    "^ModulationDesired$"
    "^WP$"
    "^PumpPower$"
    "^PumpPowerDesired$"
    "^FanSpeed$"
    "^TargetFanSpeed$"
    "^HeatingSwitch$"
    "^HwcDemand$"
    "^PartloadHcKW$"
    "^HcHours$"
    "^HwcHours$"
    "^HcStarts$"
    "^HwcStarts$"
    "^HoursTillService$"
    # calorMATIC 370
    "^DisplayedRoomTemp$"
    "^DisplayedHc1RoomTempDesired$"
    "^RoomTemp$"
    "^Hc1OPMode$"
    "^Hc1DayTemp$"
    "^Hc1NightTemp$"
    "^Hc1ActualFlowTempDesired$"
    "^HwcOPMode$"
    "^DisplayedHwcStorageTemp$"
    "^Hc1QuickVetoTemp$"
  ];

  haFilterNonName = lib.concatStringsSep "|" [
    "VortexFlowSensor"
    "^Status$"
    "^Status16$"
    "Timer"
    "HcPumpMode"
    "^SetMode$"
    "PrEnergy"
    "PrVortex"
    "PrAPS"
  ];
in
{

  services.ebusd = {
    enable = true;
    device = "enh:ebus:3335";
    port = ebusdPort;
    configpath = "${ebusdConfigPath}/";
    mqtt = {
      enable = true;
      host = "localhost";
      user = "ebus";
      password = config.secrets.mqtt.users.ebus.password;
      home-assistant = true;
      retain = true;
    };
    logs = {
      main = "info";
      network = "notice";
      bus = "error";
      update = "error";
      other = "info";
      all = "info";
    };
    extraArguments = [
      "--latency=100"
      "--acquiretimeout=100"
      "--acquireretries=3"
      "--receivetimeout=100"
      "--sendretries=3"
      # Default mqtt-hassio auto-poll (filter-seen=5) used to queue dozens of
      # unmatched registers. With the whitelist below, 15s is enough.
      "--pollinterval=15"
      "--mqttvar=filter-name=${haFilterName}"
      "--mqttvar=filter-non-name=${haFilterNonName}"
    ];
  };

  systemd.services.ebusd.serviceConfig.RestartSec = 10;

  environment.systemPackages = [
    # Default ebusctl talks to 8888 (now onedrive). Pin the real command port.
    (pkgs.writeShellScriptBin "ebusctl" ''
      exec ${config.services.ebusd.package}/bin/ebusctl -p ${toString ebusdPort} "$@"
    '')
  ];

}

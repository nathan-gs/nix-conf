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
  #
  # One deliberate deviation from upstream: PumpPower (bai, b509/0d7300,
  # "current" counterpart of PumpPowerDesired) ships with no unit/value map
  # upstream, which makes mqtt-hassio.cfg assign device_class=power from the
  # name alone and HA warn "native unit None is not valid for device class
  # power". Given PumpPowerDesired (same message family) uses
  # 0=auto;1=53;2=60;3=70;4=85;5=100 %, PumpPower was annotated to match —
  # plausible, not vendor-confirmed (only ever observed reading 0, i.e. idle,
  # same as PumpPowerDesired's auto). Revisit if a heating cycle shows a
  # PumpPower value outside 0-5.
  ebusdConfigPath = ./ebusd-csv;

  # Full-register probe (2026-08-30): read -f every "r," register in both
  # circuit CSVs live off the bus. 257/265 returned real data; only
  # DCFTimeDate/Errorhistory/FanPWMTest/Status/Status16/VortexFlowSensor/
  # MonitorCurrentIPart error (unimplemented on this hardware — matches the
  # scan-verification note above). Below adds everything from that probe
  # worth polling as a sensor, on top of the original operating-data set.
  # Deliberately left out (still readable, just not added):
  #   - CcTimer_*/HcTimer_*/HwcTimer_* + Hc1*HolidayPeriod/HolidayRoomTemp —
  #     schedules live in HA, not the controller.
  #   - Factory/installer statics that never change post-install (SerialNumber,
  #     PartnumberBox, ProductionByte, ParamToken, Testbyte, DSN/DSNOffset/
  #     DSNStart, ChangesDSN, KeyCodeforConfigMenu, LcdContrastValue,
  #     LanguageVariant, CountryVariant, HydraulicMap, BoilerType,
  #     InstallAssistant, EepromUpdateActive, FactoryTestActive,
  #     StartEepromUpdate, SetFactoryValues, TestVarActivateFunction,
  #     InitialisationEEPROM, HcName1, FlowSetPotmeter, HwcSetPotmeter,
  #     FanMinSpeedOperation, FanMaxSpeedOperation, FanSpeedOffsetMin/Max,
  #     DeltaFlowReturnMax, BlockTimeHcMax, FlowsetHcMax/HwcMax,
  #     StorageTempMax/HwcTempMax/FlowTempMax/StorageLoadTimeMax,
  #     Maintenancedata_HwcTempMax, ReturnTempMax).
  #   - Raw ASIC/ignition/hex diagnostics with no useful decode (FlameSensingASIC,
  #     IonisationVoltageLevel, AverageIgnitiontime, MinIgnitiontime,
  #     MaxIgnitiontime, GasvalveASICFeedback, GasvalveUCFeedback, PowerValue,
  #     DisplayMode, Statenumber, ValveMode, PositionValveSet,
  #     CounterStartattempts1-4, TargetFanSpeedOutput).
  #   - Solar/external-heat-source/heat-pump accessory registers, all
  #     permanently off/0 on this install (SHEMaxDeltaHwcFlow, SHEMaxFlowTemp,
  #     TempMaxDiffExtTFT, ExtFlowTempDesiredMin, ExtStorageModulCon,
  #     ExternalHwcSwitch, ExternGasvalve, ExternalFaultmessage, SolPostHeat,
  #     PumpHwcFlowNumber, PumpHwcFlowSum).
  #   - Bogus/unpopulated: PrEnergySum* (reads as the UINT32 overflow sentinel
  #     4294967294 on Hc1, 0 on the unused Hc2/Hc3/Hwc2/Hwc3 circuits),
  #     PrEnergyCountHc2/3+Hwc2/3 (0, unused circuits), PrVortexFlowSensorValue
  #     (0, tied to the nonexistent VortexFlowSensor), WaterpressureVariantSum/
  #     MeasureCounter/BranchControlOff, OverflowCounter, ContactName/
  #     PhoneNumber (blank), DcfState/DcfIsValid/StatusDcf/
  #     ClockSwitchSummerWinterDone/SummerWinterTimeAdjust/DateTime (DST/DCF
  #     clock sync, not heating), HcUnderHundredStarts/HwcUnderHundredStarts/
  #     HwcTypes (cryptic, undocumented codes).
  #   - Currenterror (tried 2026-08-30, removed 2026-08-31): reads as
  #     "-;-;-;-;-" on both circuits (5 placeholder fields, no active error) —
  #     ebusd can't decode "-" into a state, so all 5 sub-entities per circuit
  #     sat at unknown/unavailable in HA. Not worth it; use VolatileLockout/
  #     VolatileLockoutIFCGV for fault status instead.
  # ~110 registers auto-polled now (was 39) — bumped pollinterval to 30s
  # below so the extra volume doesn't starve the bus.
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
    # boiler (bai) — combustion/valve/pump live status
    "^CirPump$"
    "^Fluegasvalve$"
    "^FluegasvalveOpen$"
    "^Gasvalve$"
    "^Gasvalve3UC$"
    "^GasvalveUC$"
    "^Ignitor$"
    "^HcPumpMode$"
    "^ReturnRegulation$"
    "^RemainingBoilerblocktime$"
    "^VolatileLockout$"
    "^VolatileLockoutIFCGV$"
    "^WarmstartDemand$"
    "^WarmstartOffset$"
    "^HwcWaterflow$"
    "^HwcWaterflowMax$"
    "^PrimaryCircuitFlowrate$"
    "^Expertlevel_ReturnTemp$"
    "^ExternalFlowTempDesired$"
    "^FloorHeatingContact$"
    "^SecondPumpMode$"
    "^PumpEnergySaveCalculatedTimeMonitor$"
    "^PumpEnergySaveStateMonitor$"
    "^HwcImpellorSwitch$"
    "^HwcLoadingIn430Active$"
    "^HwcCircuitActive$"
    "^HwcSwitch$"
    "^HwcActualTempDesired$"
    "^Storageloadpump$"
    "^StoragereleaseClock$"
    "^ActoSTOROPMode$"
    "^ACTOstorDetected$"
    "^APCComStatus$"
    "^APCLegioProtection$"
    "^TempDiffBlock$"
    "^TempDiffFailure$"
    "^TempGradientFailure$"
    "^DeactivationsIFC$"
    "^DeactivationsTemplimiter$"
    "^EBusHeatcontrol$"
    "^EbusSourceOn$"
    "^EbusVoltage$"
    "^CPLPLast24started$"
    # boiler (bai) — service-life / maintenance counters
    "^FanHours$"
    "^FanStarts$"
    "^PumpHours$"
    "^HcPumpStarts$"
    "^StorageLoadPumpHours$"
    "^StorageloadPumpStarts$"
    "^ValveStarts$"
    "^PartloadHwcKW$"
    "^MaintenanceDate$"
    "^PrEnergyCountHc1$"
    "^PrEnergyCountHwc1$"
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
    # calorMATIC 370 — Legionella protection (see HwcLegioStartDay/Time for
    # schedule, LegioProtectActive for live status)
    "^LegioProtectActive$"
    "^HwcLegioStartDay$"
    "^HwcLegioStartTime$"
    # calorMATIC 370 — other live status/config
    "^ActualRoomTempDesiredHc1$"
    "^ActualWeekday$"
    "^Date$"
    "^Time$"
    "^GlobalSystemOff$"
    "^Hc12stepanalogCtrl$"
    "^Hc1LineMatchingAdaption$"
    "^Hc1SFMode$"
    "^ChimneySweepModeActive$"
    "^TimerInputHc$"
    "^RoomTempCorrection$"
    "^RoomTempLower$"
    "^RoomTempOffsetSelfWarming$"
    "^ACRoomthermostat$"
    "^DCRoomthermostat$"
    "^AccessoriesOne$"
    "^AccessoriesTwo$"
  ];

  haFilterNonName = lib.concatStringsSep "|" [
    "VortexFlowSensor"
    "^Status$"
    "^Status16$"
    # "Timer" alone would also veto TimerInputHc, which is whitelisted above.
    "Timer_"
    "^SetMode$"
    # PrEnergyCountHc1/Hwc1 are whitelisted above; only exclude the rest.
    "PrEnergySum"
    "PrEnergyCountHc2"
    "PrEnergyCountHc3"
    "PrEnergyCountHwc2"
    "PrEnergyCountHwc3"
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
      # unmatched registers. With ~110 whitelisted registers now, 30s keeps
      # the poll queue from backing up on this serial bus (15s was fine at 39).
      "--pollinterval=30"
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

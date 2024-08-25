{ config, lib, pkgs, ... }:

{

  imports = [
    ./battery.nix
    ./solis_local.nix
  ];

  services.home-assistant.config.recorder.exclude = {
    entities = [
      "device_tracker.solis_s3wifi"
      "device_tracker.smartgatewayp1"
      "automation.battery_change"
    ];
    entity_globs = [
    ];
  };
}
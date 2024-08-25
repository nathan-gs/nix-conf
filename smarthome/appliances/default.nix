{ config, lib, pkgs, ... }:

{

  imports = [
    ./deken.nix
    ./dishwasher.nix
    ./lights.nix
    ./pump.nix
    ./tv.nix
  ];

  services.home-assistant.config.recorder.exclude.entity_globs = [
    "select.*_metering_plug_*_indicator_mode"
    "select.*_metering_plug_*_power_outage_memory"
    "select.*_*_metering_plug_*_power_on_behavior"
    "select.*_plug_*_indicator_mode"
    "select.*_plug_*_power_outage_memory"
    "select.*_*_plug_*_power_on_behavior"
    "select.*_light_plug_*_indicator_mode"
    "select.*_light_plug_*_power_outage_memory"
    "select.*_*_light_plug_*_power_on_behavior"
    "switch.*_do_not_disturb"
    "number.*_*_metering_plug_*_countdown"
    "switch.*_*_light_switch_*_led_enable*"
    "switch.*_*_light_switch_*_operation_mode"
  ];
}
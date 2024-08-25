{ config, pkgs, lib, ha, ... }:

{
  imports = [
    ./fire_alarm.nix
  ];

  services.home-assistant.config = {

    # Replaced by sos2mqtt
    sensor = [];
    template = [
      
    ];

    recorder.exclude = {
      entity_globs = [
      
      ];
    };
  };

}

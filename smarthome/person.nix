{ config, lib, pkgs, ha, ... }:

{
  services.home-assistant.config = {

    recorder = {
      include = {
        entities = [
          "device_tracker.sm_g780g"
          "device_tracker.fphone"
          "device_tracker.nphone_s22"          
        ];

        entity_globs = [
          "person.*"
        ];
      };
    };
  };

}

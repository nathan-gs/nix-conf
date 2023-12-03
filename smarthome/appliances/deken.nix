{ config, pkgs, lib, ... }:
let
  ha = import ../helpers/ha.nix { lib = lib; };

in
{

  services.home-assistant.config = {
    "automation manual" = [ ]
      ++ (ha.automationOnOff "floor1/fen/deken"
      {
        triggersOn = [
          (ha.trigger.off "input_boolean.floor0_living_in_use")          
        ];
        conditionsOn = [
          (ha.condition.time_after "22:00:00")
        ];
        triggersOff = [
          (ha.trigger.on_for "switch.floor1_fen_metering_plug_deken" "00:20:00")
        ];
        entities = [ "switch.floor1_fen_metering_plug_deken" ];
      });
  };
}

{ config, lib, pkgs, ... }:

let
  ha = import ../helpers/ha.nix { lib = lib; };

in

{
  services.home-assistant.config = {
    "automation manual" =
      (ha.automationOnOff "kerstverlichting"
        {
          triggersOn = [
            {
              platform = "sun";
              event = "sunset";
              offset = "-00:30:00";
            }
            (ha.trigger.at "07:00:00")
          ];
          triggersOff = [
            (ha.trigger.at "23:00:00")
            {
              platform = "sun";
              event = "sunrise";
              offset = "00:30:00";
            }
          ];
          entities = [ "switch.garden_voordeur_light_plug_cirkel" "switch.floor0_living_light_plug_kerstboom" ];
        })
      ++
      (ha.automationOnOff "floor0/living/lights"
        {
          triggersOn = [
            {
              platform = "sun";
              event = "sunset";
              offset = "-00:30:00";
            }
          ];
          triggersOff = [
            (ha.trigger.at "23:59:00")
            (ha.trigger.state_to "input_boolean.floor0_living_in_use" "off")
          ];
          conditionsOff = [
            (ha.condition.time_after "22:00:00")
          ];
          entities = [ "switch.floor0_living_light_plug_kattenlamp" "light.floor0_living_light_bollamp" "light.floor0_living_light_booglamp" ];
        })
        ++
        (ha.automationOnOff "floor0/bureau/lights"
        {
          triggersOn = [
            (ha.trigger.on "input_boolean.floor0_bureau_in_use")
            {
              platform = "sun";
              event = "sunset";
              offset = "-00:30:00";
            }
          ];
          conditionsOn = [
            (ha.condition.on "input_boolean.floor0_bureau_in_use")
            { 
              condition = "sun";
              after = "sunset";
              after_offset = "-00:30:00";
              before = "sunrise";
              before_offset = "00:30:00";
            }
          ];
          triggersOff = [
            {
              platform = "sun";
              event = "sunrise";
              offset = "00:30:00";
            }
            (ha.trigger.off_for "input_boolean.floor0_bureau_in_use" "00:01:00")
          ];
          entities = [ "light.floor0_bureau_light_desk" ];
        });

  };
}

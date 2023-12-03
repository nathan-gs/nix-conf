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
        [
          # NDESK Light
          {
            id = "floor0_bureau_lights_on_before_sunrise";
            alias = "floor0_bureau_lights_on_before_sunrise";
            trigger = [
              {
                platform = "state";
                entity_id = [ "input_boolean.floor0_bureau_in_use" ];
                to = "on";
              }
            ];
            condition = [
              {
                condition = "sun";
                before = "sunrise";
              }
            ];
            action = [
              {
                service = "light.turn_on";
                target.entity_id = "light.floor0_bureau_light_desk";
              }
            ];
            mode = "single";
          }
          {
            id = "floor0_bureau_lights_on_at_sunset";
            alias = "floor0_bureau_lights_on_at_sunset";
            trigger = [
              {
                platform = "sun";
                event = "sunset";
                offset = "-00:30:00";
              }
            ];
            condition = [
              {
                condition = "state";
                entity_id = [ "input_boolean.floor0_bureau_in_use" ];
                state = "on";
              }
            ];
            action = [
              {
                service = "light.turn_on";
                target.entity_id = "light.floor0_bureau_light_desk";
              }
            ];
            mode = "single";
          }
          {
            id = "floor0_bureau_lights_off";
            alias = "floor0_bureau_lights_off";
            trigger = [
              {
                platform = "sun";
                event = "sunrise";
                offset = "00:30:00";
              }
              {
                platform = "state";
                entity_id = [ "input_boolean.floor0_bureau_in_use" ];
                to = "off";
              }
            ];
            condition = [ ];
            action = [
              {
                service = "light.turn_off";
                target.entity_id = "light.floor0_bureau_light_desk";
              }
            ];
            mode = "single";
          }
        ];

  };
}

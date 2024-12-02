{ config, lib, pkgs, ha, ... }:

{
  services.home-assistant.config = {
    "automation manual" = [ ]
      ++
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
          entities = [ "light.garden_voordeur_light_plug_cirkel_l1" "light.floor0_living_light_plug_kerstboom_l1" ];
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
          entities = [ "light.floor0_living_light_kattenlamp" "light.floor0_living_light_bollamp" "light.floor0_living_light_booglamp" ];
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
            (ha.trigger.off "input_boolean.floor0_bureau_in_use")
          ];
          entities = [ "light.floor0_bureau_light_desk" ];
        })
      ++
      (ha.automationOnOff "floor0/keuken/light/aanrecht" {
        triggersOn = [ (ha.trigger.on "light.floor0_keuken_light_switch_main_l2") ];
        triggersOff = [ (ha.trigger.off "light.floor0_keuken_light_switch_main_l2") ];
        entities = [ "light.floor0_keuken_light_plug_aanrecht_l1" ];
      })
      ++
      (ha.automationOnOff "floor1/badkamer/light/spiegel" {
        triggersOn = [ (ha.trigger.on "light.floor1_badkamer_light_switch_main_l2") ];
        triggersOff = [ (ha.trigger.off "light.floor1_badkamer_light_switch_main_l2") ];
        entities = [ "light.floor1_badkamer_light_switch_spiegel_l1" ];
      })
    ;

    recorder.exclude = {
      entities = [
      ];
      entity_globs = [
        "automation.*_turn_on"
        "automation.*_turn_off"
      ];
    };

  };
}

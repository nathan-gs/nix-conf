{ config, pkgs, lib, ha, ... }:
{

  services.home-assistant.config = {

    "automation manual" = [
      (ha.automation "floor0/living/wtw_valve" {
        triggers = [(ha.trigger.state "input_boolean.floor0_living_in_use")];
        actions = [
          (
            ha.action.conditional 
              [(ha.condition.on "input_boolean.floor0_living_in_use")]
              [(ha.action.on "switch.floor0_living_wtw_valve_main")]
              [(ha.action.off "switch.floor0_living_wtw_valve_main")]
          )
        ];
      })
    ];

    recorder = {
      include = {
        entity_globs = [
          "switch.*_wtw_valve_*"
        ];

      };      
    };

  };
}
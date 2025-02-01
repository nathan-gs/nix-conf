{ config, pkgs, lib, ha, ... }:
{

  services.home-assistant.config = {

    "automation manual" = [
      (ha.automation "floor0/living/wtw_valve" {
        triggers = [
          (ha.trigger.state "input_boolean.floor0_living_in_use")
          (ha.trigger.off "binary_sensor.anyone_home")
        ];
        actions = [
          (
            ha.action.conditional 
              [(
                ha.condition.template ''
                  {% set living_in_use = is_state('input_boolean.floor0_living_in_use', 'on') %}
                  {% set nobody_home = is_state('binary_sensor.anyone_home', 'off') %}
                  {{ living_in_use or nobody_home }}
                ''         
              )]
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
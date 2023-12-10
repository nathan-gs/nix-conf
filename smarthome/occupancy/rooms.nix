{ config, pkgs, lib, ha, ... }:

let
  rooms = import ../rooms.nix;

  automateRoomUse = { floor, room, triggers, action, extraActions ? [ ] }:
    {
      id = "${floor}_${room}_in_use_turn_${action}";
      alias = "${floor}/${room}/in_use.turn_${action}";
      trigger = [
      ] ++ triggers;
      action = [
        {
          service = "input_boolean.turn_${action}";
          target.entity_id = "input_boolean.${floor}_${room}_in_use";
        }
      ] ++ extraActions;
      mode = "single";
    };

in
{

  services.home-assistant.config = {

    template = [
      {
        sensor = [ ];
      }
      {
        binary_sensor = [
          {
            name = "floor0_bureau_scherm_in_use";
            state = ''
              {% set scherm_in_use = states('sensor.floor0_bureau_metering_plug_scherm_power') |float(0) > 12 %}
              {% set ndesk_in_use = states('binary_sensor.ndesk') | bool(false) %}
              {{ scherm_in_use or ndesk_in_use }}
            '';
            device_class = "occupancy";
            delay_off = "00:01:00";
          }
          {
            name = "floor1_nikolai_scherm_in_use";
            state = ''{{ states('sensor.floor1_nikolai_metering_plug_scherm_power') |float(0) > 10 }}'';
            device_class = "occupancy";
          }
          {
            name = "floor0_living_in_use_by_flaptop";
            state = ''
              {% set flaptop_on = states('binary_sensor.flaptop') |bool(false) %}
              {% set ndesk_on = states('binary_sensor.ndesk') | bool(false) %}
              {% set nstudio_on = states('binary_sensor.nstudio') | bool(false) %}
              {% set is_anyone_home = states('binary_sensor.anyone_home') |bool(false) %}
              {% set nikolai_not_in_use = states('binary_sensor.floor1_nikolai_scherm_in_use') | bool(false) == false %}
              {% set bureau_in_use = states('binary_sensor.floor0_bureau_scherm_in_use') | bool(false) %}
              {% if flaptop_on and nikolai_not_in_use %}
                {% if bureau_in_use and (ndesk_on or nstudio_on) %}
                  false
                {% else %}
                  {{ is_anyone_home }}
                {% endif %}
              {% else %}
                false
              {% endif %}
            '';
            device_class = "occupancy";
            delay_off = "00:01:00";
          }
          {
            name = "floor0_living_appletv_woonkamer";
            state = ''{{ states('sensor.living_audio_input_format') in ['DTS 5.1'] }}'';
            delay_off = "00:05:00";
          }
        ];
      }
    ];

    input_boolean = {
      floor0_bureau_in_use = {
        icon = "mdi:desk";
      };
      floor0_living_in_use = {
        icon = "mdi:sofa";
      };
      floor0_keuken_in_use = {
        icon = "mdi:countertop";
      };
      floor0_wc_in_use = {
        icon = "mdi:toilet";
      };
      floor1_badkamer_in_use = {
        icon = "mdi:shower-head";
      };
      floor1_nikolai_in_use = {
        icon = "mdi:bed";
      };
      floor1_morgane_in_use = {
        icon = "mdi:bed";
      };
      floor1_fen_in_use = {
        icon = "mdi:bed-double";
      };
      basement_basement_in_use = {
        icon = "mdi:home-floor-b";
      };
    };

    "automation manual" = [
      (
        automateRoomUse {
          floor = "floor0";
          room = "bureau";
          triggers = [
            {
              platform = "state";
              entity_id = "binary_sensor.floor0_bureau_scherm_in_use";
              to = "on";
            }
            (ha.trigger.tag "floor0_bureau")
          ];
          action = "on";
          extraActions = [
            (ha.action.on "switch.floor0_bureau_metering_plug_scherm")
          ];
        }
      )
      (
        automateRoomUse {
          floor = "floor0";
          room = "bureau";
          triggers = [
            {
              platform = "state";
              entity_id = "binary_sensor.floor0_bureau_scherm_in_use";
              to = "off";
            }
          ];
          action = "off";
          extraActions = [
            (ha.action.delay "00:01:00")
            (ha.action.off "switch.floor0_bureau_metering_plug_scherm")
          ];
        }
      )
      (
        automateRoomUse {
          floor = "floor1";
          room = "nikolai";
          triggers = [
            {
              platform = "state";
              entity_id = "binary_sensor.floor1_nikolai_scherm_in_use";
              to = "on";
            }
          ];
          action = "on";
        }
      )
      (
        automateRoomUse {
          floor = "floor1";
          room = "nikolai";
          triggers = [
            {
              platform = "state";
              entity_id = "binary_sensor.floor1_nikolai_scherm_in_use";
              to = "off";
            }
          ];
          action = "off";
        }
      )
      (
        automateRoomUse {
          floor = "floor0";
          room = "living";
          triggers = [
            {
              platform = "state";
              entity_id = "binary_sensor.floor0_living_in_use_by_flaptop";
              to = "on";
            }
            {
              platform = "state";
              entity_id = "binary_sensor.floor0_living_appletv_woonkamer";
              to = "on";
            }
          ];
          action = "on";
        }
      )
      (
        automateRoomUse {
          floor = "floor0";
          room = "living";
          triggers = [
            {
              platform = "template";
              value_template = ''
                {% set not_in_use_by_flaptop = states('binary_sensor.floor0_living_in_use_by_flaptop') | bool(false) == false %}
                {% set not_appletv_woonkamer = states('binary_sensor.floor0_living_appletv_woonkamer') | bool(false) == false %}
                {{ not_in_use_by_flaptop and not_appletv_woonkamer }}
              '';
            }
          ];
          action = "off";
        }
      )
      {
        id = "all_rooms_in_use_turn_off";
        alias = "all_rooms/in_use.turn_off";
        trigger = [
          {
            platform = "state";
            entity_id = "binary_sensor.anyone_home";
            to = "off";
          }
        ];
        action = map
          (v:
            {
              service = "input_boolean.turn_off";
              target.entity_id = "input_boolean.${v}";
            }
          )
          rooms.all;
        mode = "single";
      }
    ];

  };

}


{config, pkgs, lib, ...}:

let 
  rooms = import ../rooms.nix;

  automateRoomUse = {floor, room, triggers, action}:
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
      ];
      mode = "single";
    };

in 
{

  services.home-assistant.config = {

    template = [
      {
        sensor = [ ];          
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
              entity_id = "binary_sensor.ndesk";
              to = "on";
            }
          ];
          action = "on"; 
        }
      )    
      (
        automateRoomUse {floor = "floor0"; room = "bureau"; triggers = [
          {
            platform = "state";
            entity_id = "binary_sensor.ndesk";
            to = "off";
          }
        ]; action = "off"; }
      )
      (
        automateRoomUse {floor = "floor1"; room = "nikolai"; triggers = [
          {
            platform = "state";
            entity_id = "binary_sensor.flaptop";
            to = "on";
          }
        ]; action = "on"; }
      )
      (
        automateRoomUse {floor = "floor1"; room = "nikolai"; triggers = [
          {
            platform = "state";
            entity_id = "binary_sensor.flaptop";
            to = "off";
          }
        ]; action = "off"; }
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
        action = map(v: 
          {
            service = "input_boolean.turn_off";
            target.entity_id = "input_boolean.${v}";
          }
        ) rooms.all;
        mode = "single";
      }
    ];
  };

}


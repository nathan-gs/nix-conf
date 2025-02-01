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
            name = "floor0/bureau/pc_in_use";
            state = ''
              {% set pc_in_use = states('sensor.floor0_bureau_metering_plug_pc_power') |float(0) > 10 %}
              {% set ndesk_in_use = states('binary_sensor.ndesk') | bool(false) %}
              {{ pc_in_use or ndesk_in_use }}
            '';
            device_class = "occupancy";
            delay_off = "00:05:00";
          }
          {
            name = "floor1/nikolai/scherm_in_use";
            state = ''{{ states('sensor.floor1_nikolai_metering_plug_scherm_power') |float(0) > 10 }}'';
            device_class = "occupancy";
          }
          {
            name = "floor0/living/in_use_by_flaptop";
            state = ''
              {% set flaptop_on = states('binary_sensor.flaptop') |bool(false) %}
              {% set ndesk_on = states('binary_sensor.ndesk') | bool(false) %}
              {% set nstudio_on = states('binary_sensor.nstudio') | bool(false) %}
              {% set is_anyone_home = states('binary_sensor.anyone_home') |bool(false) %}
              {% set nikolai_not_in_use = states('binary_sensor.floor1_nikolai_scherm_in_use') | bool(false) == false %}
              {% set bureau_in_use = states('binary_sensor.floor0_bureau_pc_in_use') | bool(false) %}
              {% if flaptop_on and nikolai_not_in_use %}
                {% if bureau_in_use and (ndesk_on or nstudio_on) %}
                  true
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
            delay_off = "00:00:45";
          }
          {
            name = "occupancy/home_alone/bureau/in_use";
            state = ''
              {% set home_alone = (states.person | selectattr('state','eq','home') | list | count) == 1 %}
              {% set in_use = states('input_boolean.floor0_bureau_in_use') | bool(false) %}
              {{ home_alone and in_use }}
            '';
            device_class = "occupancy";
          }
          {
            name = "occupancy/home_alone/nikolai/in_use";
            state = ''
              {% set home_alone = (states.person | selectattr('state','eq','home') | list | count) == 1 %}
              {% set in_use = states('input_boolean.floor1_nikolai_in_use') | bool(false) %}
              {{ home_alone and in_use }}
            '';
            device_class = "occupancy";
          }
        ];
      }
    ];

    # https://community.home-assistant.io/t/how-bayes-sensors-work-from-a-statistics-professor-with-working-google-sheets/143177

    binary_sensor = [
      {
        platform = "bayesian";
        # 8h till 13h = 5h
        # 
        name = "floor0/living/in_use/weekend/morning_and_lunch";
        prior = 0.9;
        device_class = "occupancy";
        observations = [
          {
            platform = "state";
            entity_id = "binary_sensor.floor0_living_appletv_woonkamer";
            # TV is on for 2h out of 5h
            prob_given_true = 0.5;
            prob_given_false = 0.6;
            to_state = "on";
          }          
          {
            platform = "numeric_state";
            entity_id = "sensor.floor0_living_fire_alarm_main_co2";
            above = 700;
            # If CO2 is high in the living, its likely occupied
            prob_given_true = 0.30;
            prob_given_false = 0.60;
          }
          {
            platform = "state";
            entity_id = "binary_sensor.anyone_home";
            # We are likely at home during weekend mornings
            prob_given_true = 0.90;
            prob_given_false = 0.001;
            to_state = "on";
          }     
        ];
      }
      {
        platform = "bayesian";
        # 13h - 18h = 5h
        name = "floor0/living/in_use/weekend/afternoon";
        # We are out 60% of the time
        prior = 0.4;
        device_class = "occupancy";
        observations = [
          {
            platform = "state";
            entity_id = "binary_sensor.floor0_living_appletv_woonkamer";
            # TV is on for 30m out of 5h
            prob_given_true = 0.5 / 5;
            prob_given_false = 4.5 / 5;
            to_state = "on";
          }          
          {
            platform = "numeric_state";
            entity_id = "sensor.floor0_living_fire_alarm_main_co2";
            above = 700;
            # If CO2 is high in the living, its likely occupied
            prob_given_true = 0.30;
            prob_given_false = 0.60;
          }
          {
            platform = "state";
            entity_id = "binary_sensor.anyone_home";
            # There's a 85% chance we are in the living room if it's occupied
            prob_given_true = 0.85;
            prob_given_false = 0.001;
            to_state = "on";
          }                    
        ];
      }      
      {
        platform = "bayesian";
        # 18h - 23h
        name = "floor0/living/in_use/evening";
        prior = 0.9;
        device_class = "occupancy";
        observations = [
          {
            # 85% of the time somebody watches tv in the evening minus time to cook
            # 85% of 4/5th h
            platform = "state";
            entity_id = "binary_sensor.floor0_living_appletv_woonkamer";
            prob_given_true = 0.68; # 0.85 * (4 / 5)
            prob_given_false = 0.32;
            to_state = "on";
          }
          {
            platform = "numeric_state";
            entity_id = "sensor.floor0_living_fire_alarm_main_co2";
            above = 700;
            # If CO2 is high in the living, its likely occupied
            prob_given_true = 0.30;
            prob_given_false = 0.60;
          }
          {
            platform = "state";
            entity_id = "binary_sensor.anyone_home";
            # There's a 95% chance we are in the living room if it's occupied
            prob_given_true = 0.95;
            prob_given_false = 0.001;
            to_state = "on";
          }
          {
            platform = "state";
            entity_id = "binary_sensor.floor0_living_in_use_by_flaptop";
            prob_given_true = 0.95;
            prob_given_false = 0.99;
            to_state = "on";
          }
        ];
      }
      {
        platform = "bayesian";
        # 8h - 18h
        # very rarely (1%) the living is in use during the day
        name = "floor0/living/in_use/weekday/day";
        prior = 0.10;
        device_class = "occupancy";
        observations = [
          {
            platform = "state";
            entity_id = "binary_sensor.floor0_living_appletv_woonkamer";
            prob_given_true = 0.40; # 0.80 * (2 / 10)
            prob_given_false = 0.20;
            to_state = "on";
          }
          {
            platform = "numeric_state";
            entity_id = "sensor.floor0_living_fire_alarm_main_co2";
            above = 700;
            # If CO2 is high in the living, its likely occupied
            prob_given_true = 0.30;
            prob_given_false = 0.60;
          }
          {
            platform = "state";
            entity_id = "binary_sensor.anyone_home";
            # There's a 1% chance we are in the living room if it's occupied
            prob_given_true = 0.01;
            prob_given_false = 0.001;
            to_state = "on";
          }
          {
            platform = "state";
            entity_id = "binary_sensor.floor0_living_in_use_by_flaptop";
            prob_given_true = 0.90;
            prob_given_false = 0.99;
            to_state = "on";
          }
        ];
      }
    ];

    input_boolean = {
      floor0_bureau_in_use = {
        name = "floor0/bureau/in_use";
        icon = "mdi:desk";
      };
      floor0_living_in_use = {
        name = "floor0/living/in_use";
        icon = "mdi:sofa";
      };
      floor0_keuken_in_use = {
        name = "floor0/keuken/in_use";
        icon = "mdi:countertop";
      };
      floor0_wc_in_use = {
        name = "floor0/wc/in_use";
        icon = "mdi:toilet";
      };
      floor1_badkamer_in_use = {
        name = "floor1/badkamer/in_use";
        icon = "mdi:shower-head";
      };
      floor1_nikolai_in_use = {
        name = "floor1/nikolai/in_use";
        icon = "mdi:bed";
      };
      floor1_morgane_in_use = {
        name = "floor1/morgane/in_use";
        icon = "mdi:bed";
      };
      floor1_fen_in_use = {
        name = "floor1/fen/in_use";
        icon = "mdi:bed-double";
      };
      basement_basement_in_use = {
        name = "basement/basement/in_use";
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
              entity_id = "binary_sensor.floor0_bureau_pc_in_use";
              to = "on";
            }
            (ha.trigger.tag "floor0_bureau")
          ];
          action = "on";
          extraActions = [
            (ha.action.on "switch.floor0_bureau_metering_plug_pc")
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
              entity_id = "binary_sensor.floor0_bureau_pc_in_use";
              to = "off";
            }
          ];
          action = "off";
          extraActions = [
            (ha.action.off "switch.floor0_bureau_metering_plug_pc")
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
              platform = "template";
              value_template = ''
                {% set is_night = is_state('binary_sensor.calendar_night', 'on') %}
                {% set is_weekend_morning_and_lunch = is_state('binary_sensor.calendar_weekend_morning_and_lunch', 'on') %}
                {% set is_weekend_afternoon = is_state('binary_sensor.calendar_weekend_afternoon', 'on') %}
                {% set is_night = is_state('binary_sensor.calendar_night', 'on') %}
                {% set is_weekday_day = is_state('binary_sensor.calendar_weekday_day', 'on') %}
                {% set in_use_by_flaptop = is_state('binary_sensor.floor0_living_in_use_by_flaptop', 'on') %}
                {% set is_tv_on = is_state('binary_sensor.floor0_living_appletv_woonkamer', 'on') %}
                {% set is_femke_home = is_state('person.femke', 'home') %}
                {% set is_anybody_home = is_state('binary_sensor.anyone_home', 'on') %}
                {% if is_tv_on %}
                  true                
                {% elif is_weekend_morning_and_lunch %}
                  {{ is_anybody_home }}
                {% elif is_weekend_afternoon %}
                  {{ is_femke_home }}
                {% elif is_weekday_day %}
                  {{ is_tv_on or in_use_by_flaptop }}
                {% elif is_night %}
                  false
                {% else %}
                  false
                {% endif %}
              '';
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
                {% set is_night = is_state('binary_sensor.calendar_night', 'on') %}
                {% set is_weekend_morning_and_lunch = is_state('binary_sensor.calendar_weekend_morning_and_lunch', 'on') %}
                {% set is_weekend_afternoon = is_state('binary_sensor.calendar_weekend_afternoon', 'on') %}
                {% set is_night = is_state('binary_sensor.calendar_night', 'on') %}
                {% set is_weekday_day = is_state('binary_sensor.calendar_weekday_day', 'on') %}
                {% set in_use_by_flaptop = is_state('binary_sensor.floor0_living_in_use_by_flaptop', 'on') %}
                {% set is_tv_on = is_state('binary_sensor.floor0_living_appletv_woonkamer', 'on') %}
                {% set is_femke_home = is_state('person.femke', 'home') %}
                {% set is_anybody_home = is_state('binary_sensor.anyone_home', 'on') %}
                {% if is_tv_on %}
                  false                
                {% elif is_weekend_morning_and_lunch %}
                  {{ is_anybody_home == false }} 
                {% elif is_weekend_afternoon %}
                  {{ is_femke_home == false }}
                {% elif is_weekday_day %}
                  {{ is_tv_on == false or in_use_by_flaptop == false }}
                {% elif is_night %}
                  true
                {% else %}
                  true
                {% endif %}
              '';
            }
          ];
          action = "off";
        }
      )     
      (
        automateRoomUse {
          floor = "floor0";
          room = "wc";
          triggers = [
            (ha.trigger.on "light.floor0_wc_light_switch_main_l1")
          ];
          action = "on";
        }
      )
      (
        automateRoomUse {
          floor = "floor0";
          room = "wc";
          triggers = [
            (ha.trigger.off_for "light.floor0_wc_light_switch_main_l1" "00:05:00")
          ];
          action = "off";
        }
      ) 
    ];

    recorder = {
      include = {
        entities = [
          "binary_sensor.ndesk"
        ];
        entity_globs = [
          "binary_sensor.*_in_use*"
          "binary_sensor.occupancy_*"
          "input_boolean.*_in_use"
        ];
      };
      exclude = {
        entities = [
        ];
        entity_globs = [
          "automation.*_*_in_use_turn_on"
          "automation.*_*_in_use_turn_off"
        ];
      };
    };
  };

}


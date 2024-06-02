{ config, lib, pkgs, ha, ... }:
let
  rooms = import ../rooms.nix;
in
{
  imports = [
    ./rooms.nix
  ];

  services.home-assistant.config = {
    #device_tracker = [
    #  {
    #    platform = "ping";
    #    hosts = {
    #      #"fphone" = "fphone";
    #      #"nphone" = "nphone-s22";
    #    };
    #  }
    #];

    # TODO before HA 2024.03
    binary_sensor = [
      # {
      #   platform = "ping";
      #   host = "ndesk";
      #   name = "ndesk";
      #   count = 2;
      #   #scan_interval = 30;
      # }
      # {
      #   platform = "ping";
      #   host = "flaptop-CP113907";
      #   name = "flaptop";
      #   count = 2;
      #   #scan_interval = 30;
      # }
      # {
      #   platform = "ping";
      #   host = "nstudio";
      #   name = "nstudio";
      #   count = 2;
      #   #scan_interval = 30;
      # }
    ];

    input_boolean = {
      coming_home = {
        name = "coming_home";
        icon = "mdi:home";
      };
    };

    template = [
      {
        binary_sensor = [
          {
            name = "anyone_home";
            state = "{{ states.person | selectattr('state','eq','home') | list | count > 0 }}";
            device_class = "occupancy";
          }
          {
            name = "anyone_coming_home";
            state = ''
              {#
              {% set within_10km = states('sensor.sxw_nearest_distance') | float(0) <= 10 %}
              {% set sensor_based = within_10km and (states('sensor.sxw_nearest_direction_of_travel') == 'towards') %}
              {% set override = states('input_boolean.coming_home') | bool(false) %}            
              {{ sensor_based or override }}
              #}
              false
            '';
            device_class = "occupancy";
          }
          {
            name = "anyone_home_or_coming_home";
            state = ''
              {{ states('binary_sensor.anyone_home') | bool(true) or states('binary_sensor.anyone_coming_home') | bool(false) }}
            '';
            device_class = "occupancy";
          }
          {
            name = "far_away";
            state = ''
              {{ states('sensor.sxw_nearest_distance') | float(0) >= 200 }}
            '';
            device_class = "occupancy";
            delay_on.minutes = 10;
            delay_off.minutes = 10;
          }
        ];
      }
    ];

    "automation manual" = [
      (ha.automation "occupancy/anyone_home.turn_on" {
        triggers = [ (ha.trigger.on "binary_sensor.anyone_home") ];
        actions = [ (ha.action.off "input_boolean.coming_home") ];
      })
      (ha.automation "occupancy/anyone_home.turn_off" {
        triggers = [ (ha.trigger.off "binary_sensor.anyone_home") ];
        actions = map
          (v:
            {
              service = "input_boolean.turn_off";
              target.entity_id = "input_boolean.${v}";
            }
          )
          rooms.all;
      })
      (ha.automation "occupancy/anyone_coming_home.turn_on" {
        triggers = [ (ha.trigger.on "input_boolean.coming_home") ];
        actions = [ 
          (ha.action.on "input_boolean.floor0_living_in_use")
        ];
      })
    ];

    sensor = [
      {
        platform = "history_stats";
        name = "occupancy/anyone_home daily";
        entity_id = "binary_sensor.anyone_home";
        state = "on";
        type = "time";
        start = "{{ now().replace(hour=0, minute=0, second=0, microsecond=0) }}";
        end = "{{ now() }}";
      }
    ];
  };


}

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
      occupancy_somebody_home = {
        name = "occupancy/somebody_home";
        icon = "mdi:vacuum";
      };
    };

    template = [
      {
        binary_sensor = [
          {
            name = "anyone_home";
            state = ''
              {% if is_state('input_boolean.occupancy_somebody_home', 'on') %}
                true
              {% else %}
                {{ states.person | selectattr('state','eq','home') | list | count > 0 }}
              {% endif %}
            '';
            device_class = "occupancy";
          }
          {
            name = "anyone_coming_home";
            state = ''              
              {% set closeby = states('sensor.sxw_nearest_distance') | float(0) <= 12000 %}
              {% set sensor_based = closeby and is_state('sensor.sxw_nearest_direction_of_travel', 'towards') %}
              {% set override = states('input_boolean.coming_home') | bool(false) %}            
              {% set is_workday = is_state('binary_sensor.calendar_workday', 'on') %}
              {% set femke_in_wittewalle = is_state('person.femke', 'wittewalle') %}
              {% if is_workday and now().hour >= 17 and femke_in_wittewalle %}
                true
              {% else %}
                {{ sensor_based or override }}
              {% endif %}
            '';
            device_class = "occupancy";
          }
          {
            name = "anyone_home_or_coming_home";
            state = ''
              {{ is_state('binary_sensor.anyone_home', 'on') or is_state('binary_sensor.anyone_coming_home', 'on') }}
            '';
            device_class = "occupancy";
          }
          {
            name = "far_away";
            state = ''
              {% set override = is_state('input_boolean.coming_home', 'on') %}
              {{ not(override) and states('sensor.sxw_nearest_distance') | float(0) >= 200000 }}
            '';
            device_class = "occupancy";
            delay_on.minutes = 10;
            delay_off.minutes = 10;
          }
        ];
        sensor = [
          {
            name = "occupancy/home/people_count";
            state = "{{ states.person | selectattr('state','eq','home') | list | count }}";
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
      (ha.automation "occupancy/override_somebody_home.turn_off" {
        triggers = [ (ha.trigger.at "0:00:00") ];
        actions = [ (ha.action.off "input_boolean.occupancy_somebody_home")];
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

    recorder = {
      include = {
        entities = [
          "input_boolean.coming_home"
          "binary_sensor.anyone_home"
          "binary_sensor.anyone_coming_home"
          "binary_sensor.anyone_home_or_coming_home"
          "binary_sensor.far_away"
          "sensor.occupancy_anyone_home_daily"
          "device_tracker.sm_g780g"        
          "device_tracker.fphone_a55"
          "binary_sensor.flaptop"
          "binary_sensor.ndesk"
          "binary_sensor.nstudio"
        ];

        entity_globs = [
          "device_tracker.fphone*"
          "device_tracker.nphone*"
          "device_tracker.volvo_*"
          "device_tracker.*_position"
          "person.*"
          "sensor.sxw_*"
        ];
      };
    };
  };


}

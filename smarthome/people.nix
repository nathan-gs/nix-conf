{ config, lib, pkgs, ... }:

{
  services.home-assistant.config = {
    proximity = {
      home = {
        devices = [
          "device_tracker.nphone_s22"
          "device_tracker.sm_g780g"
        ];
        unit_of_measurement = "km";
        tolerance = 50;
      };
    };

    #device_tracker = [
    #  {
    #    platform = "ping";
    #    hosts = {
    #      #"fphone" = "fphone";
    #      #"nphone" = "nphone-s22";
    #    };
    #  }
    #];

    binary_sensor = [
      {
        platform = "ping";
        host = "ndesk";
        name = "ndesk";
        count = 2;
        scan_interval = 30;
      }
      {
        platform = "ping";
        host = "flaptop-CP113907";
        name = "flaptop";
        count = 2;
        scan_interval = 30;
      }
    ];

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
              {% set within_10km = states('proximity.home') | float(0) <= 10 %}
              {{ within_10km and is_state_attr('proximity.home', 'dir_of_travel', 'towards') }}
            '';
            device_class = "occupancy";
            delay_on.minutes = 1;
            delay_off.minutes = 10;
          }
          {
            name = "anyone_home_or_coming_home";
            state = ''
              {{ states('anyone_home') | bool(true) or states('is_anyone_coming_home') | bool(false) }}
            '';
            device_class = "occupancy";            
          }
          {
            name = "far_away";
            state = ''
              {{ states('proximity.home') | float(0) >= 200 }}
            '';
            device_class = "occupancy";
            delay_on.minutes = 10;
            delay_off.minutes = 10;
          }
        ];
      }
    ];
  };

}

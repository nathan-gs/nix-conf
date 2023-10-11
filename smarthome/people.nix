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
            name = "is_workday";
            state = "{{ (now().weekday() < 5) }}";
          }
          {
            name = "is_anyone_home";
            state = "{{ states.person | selectattr('state','eq','home') | list | count > 0 }}";
            device_class = "occupancy";
          }
        ];
      }
    ];
  };

}

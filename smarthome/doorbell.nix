{ config, lib, pkgs, ... }:

{
  services.home-assistant.config = {
    "automation manual" = [
      {
        id = "doorbell_notify";
        alias = "doorbell.notify";
        trigger = [
          {
            platform = "template";
            value_template = ''
              {{ states('sensor.system_doorbell_monitoring_plug_doorbell_power') | float(0) > 2 }}
            '';
          }
        ];
        condition = [ ];
        action = [
          {
            service = "notify.notify";
            data = {
              title = "Deurbel";
              message = "Deurbel: iemand aan de deur";
            };
          }
        ];
        mode = "single";
      }

    ];

  };
}

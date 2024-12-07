{ config, lib, pkgs, ha, ... }:

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
              {{ states('sensor.system_doorbell_monitoring_plug_doorbell_power') | float(0) > 5 }}
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

    recorder = {
      include = {
        entities = [
          "automation.doorbell_notify"          
        ];
      };
    };

  };

  

}

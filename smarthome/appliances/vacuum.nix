{ config, pkgs, lib, ha, ... }:
{

  services.home-assistant.config = {

    "automation manual" = [
      (
        ha.automation "floor1/vacuum.turn_on"
          {
            triggers = [ 
              (ha.trigger.off "binary_sensor.anyone_home")               
            ];
            conditions = [              
            ];
            actions = [
              {
                service = "vacuum.start";                
                target.entity_id = "vacuum.botje_boven";
              }
            ];
          } 

      )
    ];

    recorder = {
      include = {
        entities = [
          "vacuum.botje_boven"         
        ];

        entity_globs = [          
        ];
      };
    };

  };
}
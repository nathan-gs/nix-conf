{ config, pkgs, lib, ha, ... }:
{

  services.home-assistant.config = {
    "automation manual" = [ ]
      ++ (ha.automationOnOff "floor0/living/media/sonos"
      {
        triggersOn = [
          (ha.trigger.on "binary_sensor.floor0_living_appletv_woonkamer")          
        ];
        conditionsOn = [
          (ha.condition.time_after "10:30:00")
        ];
        triggersOff = [
          (ha.trigger.off_for "binary_sensor.floor0_living_appletv_woonkamer" "00:02:00")
        ];
        entities = [ "switch.floor0_living_plug_sonos_rear" ];
      });
  };
}

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
          (ha.condition.template "{{ (now().strftime('%H:%M') >= '10:30' and now().strftime('%H:%M') <= '17:30') or now().strftime('%H:%M') >= '20:30' }}")
        ];
        triggersOff = [
          (ha.trigger.off_for "binary_sensor.floor0_living_appletv_woonkamer" "00:02:00")
        ];
        entities = [ "switch.floor0_living_plug_sonos_rear" ];
      });
  };
}

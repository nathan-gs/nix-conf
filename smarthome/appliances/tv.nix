{ config, pkgs, lib, ha, ... }:
{

  services.home-assistant.config = {
    # Samsung 50" 2013 + Sonos soundbar + 2x Sonos One + AppleTV
    # active: ~70W TV + 15W soundbar + 10W 2×Sonos One + 4W AppleTV = 100W
    # standby: Sonos network standby + TV standby = 5W
    powercalc.sensors = [
      {
        name = "living_room_av";
        entity_id = "binary_sensor.floor0_living_appletv_woonkamer";
        standby_power = 5;
        fixed.power = 100;
      }
    ];

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

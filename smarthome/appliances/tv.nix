{ config, pkgs, lib, ha, ... }:
{

  services.home-assistant.config = {
    # Samsung UE50HU6900S (2014 50" 4K LED) + Apple TV 4K + Sonos soundbar
    # + 2× Sonos One.
    # TV: typical 86 W (IEC 62087), eco 52 W, max 178 W, standby 0.5 W.
    #     Not run at max brightness → use typical, not the 178 W nameplate.
    # Soundbar: ~20 W playing / 6 W idle. Apple TV 4K: ~3 W playing / 0.5 W sleep.
    # Each One: ~8 W playing / 3–4 W idle.
    powercalc.sensors = [
      {
        name = "floor0/living/av";
        entity_id = "binary_sensor.floor0_living_appletv_woonkamer";
        standby_power = 7;
        fixed.power = ''
          {% set tv = 86 %}
          {% set soundbar = 20 %}
          {% set appletv = 3 %}
          {% set sonos_ones = 16 %}
          {{ tv + soundbar + appletv + sonos_ones }}
        '';
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

{ config, pkgs, lib, ha, ... }:

{
  # 22 W, 16 h on / 8 h off. 15:00–07:00 is the placement that contains the
  # whole weekday off-peak night (22:00–07:00). The remaining 7 h are peak
  # whichever way the window sits, because off-peak is only 9 h long.
  services.home-assistant.config = {
    "automation manual" = [ ]
      ++ (ha.automationOnOff "floor0/keuken/mini_garden"
      {
        triggersOn = [
          (ha.trigger.at "15:00:00")
          { platform = "homeassistant"; event = "start"; }
          {
            platform = "state";
            entity_id = "switch.floor0_keuken_metering_plug_mini_garden";
            from = "unavailable";
          }
        ];
        conditionsOn = [
          {
            condition = "time";
            after = "15:00:00";
            before = "07:00:00";
          }
        ];
        triggersOff = [
          (ha.trigger.at "07:00:00")
          { platform = "homeassistant"; event = "start"; }
          {
            platform = "state";
            entity_id = "switch.floor0_keuken_metering_plug_mini_garden";
            from = "unavailable";
          }
        ];
        conditionsOff = [
          {
            condition = "time";
            after = "07:00:00";
            before = "15:00:00";
          }
        ];
        entities = [ "switch.floor0_keuken_metering_plug_mini_garden" ];
      });
  };
}

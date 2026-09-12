{ config, pkgs, lib, ha, ... }:

{

  services.home-assistant.config = {
    "automation manual" = [ ]
      ++ (ha.automationOnOff "floor1/fen/deken"
      {
        triggersOn = [
          (ha.trigger.off "input_boolean.floor0_living_in_use")          
        ];
        conditionsOn = [
          (ha.condition.time_after "21:50:00")
          # Never switch the blanket on during a fire alarm. This automation fires
          # in the evening when the living room empties, which is exactly when an
          # evening fire would otherwise re-energise it behind the fire automation's
          # back. See smarthome/air_quality/fire_alarm.nix and docs/fire-alarms.md.
          (ha.condition.off "input_boolean.fire_alarm_active")
        ];
        triggersOff = [
          (ha.trigger.on_for "switch.floor1_fen_metering_plug_deken" "00:25:00")
        ];
        entities = [ "switch.floor1_fen_metering_plug_deken" ];
      });
  };
}

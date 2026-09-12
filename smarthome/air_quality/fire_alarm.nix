{ config, pkgs, lib, ha, ... }:

let

  # Bosch alarms do NOT interconnect themselves. The z2m converter is explicit about
  # it: "a detected smoke alarm is not being transmitted automatically to other
  # devices". Interlinking them is therefore our job, not the hardware's.
  smokeSensors = [
    "binary_sensor.floor0_living_fire_alarm_main_smoke"
    "binary_sensor.floor1_hallway_fire_alarm_main_smoke"
    "binary_sensor.basement_basement_fire_alarm_top_smoke"
  ];

  # Twinguard (8750001213) sirens are driven by a select: stop/pre_alarm/fire/burglar.
  twinguardSirens = [
    "select.floor0_living_fire_alarm_main_alarm"
    "select.floor1_hallway_fire_alarm_main_alarm"
  ];

  # BSD-2 sirens are driven by a switch. Its broadcast_alarms option defaults to on,
  # so this one call is relayed to every BSD-2 on the network, not just this device.
  bsd2Sirens = [
    "switch.basement_basement_fire_alarm_top_manual_smoke_alarm"
  ];

  sirensOn =
    (map (e: ha.action.set_value e "fire") twinguardSirens)
    ++ (map (e: ha.action.on e) bsd2Sirens);

  sirensOff =
    (map (e: ha.action.set_value e "stop") twinguardSirens)
    ++ (map (e: ha.action.off e) bsd2Sirens);

  phones = [
    "mobile_app_nphone"
    "mobile_app_nphone_p10pro"
    "mobile_app_fphone"
  ];

  # A fire alarm that a Do Not Disturb profile can mute is not a fire alarm, so this
  # is sent as a high-priority/critical push. The Android keys (ttl/priority/channel/
  # importance) and the iOS keys (push.sound.critical) are both set; each platform
  # ignores the other's.
  notifyPhone = target: {
    service = "notify.${target}";
    data = {
      title = "🔥 BRANDALARM";
      message = "Rook gedetecteerd door {{ trigger.to_state.name | default('een rookmelder') }}. Alle sirenes zijn geactiveerd.";
      data = {
        ttl = 0;
        priority = "high";
        channel = "fire_alarm";
        importance = "high";
        persistent = true;
        tag = "fire_alarm";
        actions = [
          { action = "FIRE_ALARM_CLEAR"; title = "Alarm stoppen"; }
        ];
        push = {
          sound = {
            name = "default";
            critical = 1;
            volume = 1.0;
          };
        };
      };
    };
  };

in
{

  services.home-assistant.config = {

    input_button = {
      fire_alarm_clear = {
        name = "fire alarm clear";
        icon = "mdi:bell-off";
      };
    };

    "automation manual" = [

      (ha.automation "system/fire_alarm.detected" {
        triggers = [ (ha.trigger.on smokeSensors) ];
        actions = sirensOn ++ (map notifyPhone phones);
      })

      # Deliberately unconditional and free of notifications: clearing is idempotent,
      # so the worst a spurious run can do is stop sirens that are already stopped.
      # A guard template here would risk the opposite failure - being unable to
      # silence the house because a condition threw.
      (ha.automation "system/fire_alarm.clear" {
        triggers = [
          (ha.trigger.state "input_button.fire_alarm_clear")
          {
            platform = "event";
            event_type = "mobile_app_notification_action";
            event_data = { action = "FIRE_ALARM_CLEAR"; };
          }
        ];
        actions = sirensOff;
      })

    ];

    sensor = [];
    template = [

    ];

  };

}

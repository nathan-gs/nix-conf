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

  # Pushing the button on a device is the physical end-to-end test. On a Twinguard
  # that shows up as self_test (alarm_status bit 24); on the BSD-2 as button_pushed
  # (IAS zone bit 8). The Twinguard switches are settable too, so a test can also be
  # started from HA without walking to the device.
  selfTestSensors = [
    "switch.floor0_living_fire_alarm_main_self_test"
    "switch.floor1_hallway_fire_alarm_main_self_test"
    "binary_sensor.basement_basement_fire_alarm_top_button_pushed"
  ];

  # Twinguard (8750001213) sirens are driven by a select: stop/pre_alarm/fire/burglar.
  twinguardSirens = [
    "select.floor0_living_fire_alarm_main_alarm"
    "select.floor1_hallway_fire_alarm_main_alarm"
  ];

  # BSD-2 sirens are driven by a switch. Its broadcast_alarms option defaults to on,
  # so this one call is relayed to every BSD-2 on the network, not just this device.
  bsd2Siren = "switch.basement_basement_fire_alarm_top_manual_smoke_alarm";

  sirensOn =
    (map (e: ha.action.set_value e "fire") twinguardSirens)
    ++ [ (ha.action.on bsd2Siren) ];

  sirensOff =
    (map (e: ha.action.set_value e "stop") twinguardSirens)
    ++ [ (ha.action.off bsd2Siren) ];

  # True only when nothing is actually alarming. This is what separates "button
  # pushed to run a test" from "button pushed to silence a real alarm" - the BSD-2
  # reports both as the same button_pushed bit, so without this a panicked jab at
  # the silence button would re-sound the whole house.
  nothingAlarming = [
    { condition = "state"; entity_id = smokeSensors; state = "off"; }
    { condition = "state"; entity_id = bsd2Siren; state = "off"; }
  ];

  phones = [
    "mobile_app_nphone"
    "mobile_app_nphone_p10pro"
    "mobile_app_fphone"
  ];

  # critical = true bypasses Do Not Disturb via the Android (ttl/priority/channel/
  # importance) and iOS (push.sound.critical) keys; each platform ignores the
  # other's. Tests deliberately do NOT get this - only a real fire may wake you.
  notifyPhone = { title, message, tag, critical }: target: {
    service = "notify.${target}";
    data = {
      title = title;
      message = message;
      data = {
        tag = tag;
        actions = [
          { action = "FIRE_ALARM_CLEAR"; title = "Alarm stoppen"; }
        ];
      } // lib.optionalAttrs critical {
        ttl = 0;
        priority = "high";
        channel = "fire_alarm";
        importance = "high";
        persistent = true;
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

  notifyAlarm = map (notifyPhone {
    title = "🔥 BRANDALARM";
    message = "Rook gedetecteerd door {{ trigger.to_state.name | default('een rookmelder') }}. Alle sirenes zijn geactiveerd.";
    tag = "fire_alarm";
    critical = true;
  }) phones;

  notifyTest = map (notifyPhone {
    title = "🔔 Brandalarm test";
    message = "Test gestart via {{ trigger.to_state.name | default('een rookmelder') }}. Alle sirenes loeien 15s en stoppen dan vanzelf.";
    tag = "fire_alarm_test";
    critical = false;
  }) phones;

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
        actions = sirensOn ++ notifyAlarm;
      })

      # Physical test: push the button on any alarm and every siren should sound.
      # Guarded by nothingAlarming so a button press during a real alarm is treated
      # as "silence", not "test". Auto-stops after 15s, but re-checks for real smoke
      # first so a genuine alarm starting mid-test is never silenced by the timer.
      (ha.automation "system/fire_alarm.test" {
        triggers = [ (ha.trigger.on selfTestSensors) ];
        conditions = nothingAlarming;
        actions = sirensOn
          ++ notifyTest
          ++ [ (ha.action.delay "00:00:15") ]
          ++ [ { condition = "state"; entity_id = smokeSensors; state = "off"; } ]
          ++ sirensOff;
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

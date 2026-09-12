{ config, pkgs, lib, ha, ... }:

let

  # Bosch alarms do NOT interconnect themselves. The z2m converter is explicit about
  # it: "a detected smoke alarm is not being transmitted automatically to other
  # devices". Interlinking them is therefore our job, not the hardware's.
  #
  # Coverage map, known gaps and the pairing/testing gotchas are in
  # docs/fire-alarms.md. Read that before adding or re-pairing a device.
  #
  # One entry per alarm - everything below is derived from this list, so adding a
  # fourth alarm means adding one block here and nothing else.
  #
  #   label : human name used in notifications
  #   smoke : fires on real smoke
  #   test  : fires on a physical button press. HOLD THE BUTTON ~5 SECONDS; a short
  #           tap transmits nothing at all (measured 2026-09-12 - a brief press
  #           produced no Zigbee message whatsoever).
  #   siren : how this model is commanded. Twinguards take a select
  #           (stop/pre_alarm/fire/burglar), the BSD-2 takes a switch.
  alarms = [
    {
      # covers: the living room
      label = "de living";
      smoke = "binary_sensor.floor0_living_fire_alarm_main_smoke";
      test = "switch.floor0_living_fire_alarm_main_self_test";
      siren = { kind = "twinguard"; entity = "select.floor0_living_fire_alarm_main_alarm"; };
    }
    {
      # covers: waskot, fen, nikolai, badkamer, morgane
      label = "de gang (verdiep 1)";
      smoke = "binary_sensor.floor1_hallway_fire_alarm_main_smoke";
      test = "switch.floor1_hallway_fire_alarm_main_self_test";
      siren = { kind = "twinguard"; entity = "select.floor1_hallway_fire_alarm_main_alarm"; };
    }
    {
      # covers: the basement, and partially the floor0 hallway and kitchen.
      # NOTE: the CV room is only partially covered - the largest remaining gap.
      label = "de kelder";
      smoke = "binary_sensor.basement_basement_fire_alarm_top_smoke";
      test = "binary_sensor.basement_basement_fire_alarm_top_button_pushed";
      # broadcast_alarms defaults to on, so this one call is relayed to every BSD-2
      # on the network, not just this device.
      siren = { kind = "bsd2"; entity = "switch.basement_basement_fire_alarm_top_manual_smoke_alarm"; };
    }
  ];

  smokeSensors = map (a: a.smoke) alarms;
  selfTestSensors = map (a: a.test) alarms;

  sirensOf = kind: map (a: a.siren.entity) (lib.filter (a: a.siren.kind == kind) alarms);
  twinguardSirens = sirensOf "twinguard";
  bsd2Sirens = sirensOf "bsd2";

  sirensOn =
    (map (e: ha.action.set_value e "fire") twinguardSirens)
    ++ (map (e: ha.action.on e) bsd2Sirens);

  sirensOff =
    (map (e: ha.action.set_value e "stop") twinguardSirens)
    ++ (map (e: ha.action.off e) bsd2Sirens);

  allSmokeClear = { condition = "state"; entity_id = smokeSensors; state = "off"; };

  # True only when nothing is actually alarming. This is what separates "button
  # pushed to run a test" from "button pushed to silence a real alarm" - the BSD-2
  # reports both as the same button_pushed bit, so without this a panicked jab at
  # the silence button would re-sound the whole house.
  nothingAlarming = [
    allSmokeClear
  ] ++ (map (e: { condition = "state"; entity_id = e; state = "off"; }) bsd2Sirens);

  # Maps the triggering entity to a human location, so the notification says where.
  # trigger.to_state.name would render as "basement/basement/fire_alarm/top Smoke",
  # which is accurate and useless. Covers both smoke and test entities so the same
  # expression works in either automation.
  whichAlarm =
    let
      pairs = lib.concatStringsSep ", " (lib.flatten (map
        (a: [ "'${a.smoke}': '${a.label}'" "'${a.test}': '${a.label}'" ])
        alarms));
    in
    "{% set locations = {${pairs}} %}{{ locations.get(trigger.entity_id, 'een onbekende melder') }}";

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

  notifyAlarm = map
    (notifyPhone {
      title = "🔥 BRANDALARM";
      message = "Rook gedetecteerd in ${whichAlarm}. Alle sirenes zijn geactiveerd.";
      tag = "fire_alarm";
      critical = true;
    })
    phones;

  notifyTest = map
    (notifyPhone {
      title = "🔔 Brandalarm test";
      message = "Test gestart vanaf ${whichAlarm}. Alle sirenes loeien 15s en stoppen dan vanzelf.";
      tag = "fire_alarm_test";
      critical = false;
    })
    phones;

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

      # Physical test: hold the button on any alarm ~5s and every siren should sound.
      # Guarded by nothingAlarming so a button press during a real alarm is treated
      # as "silence", not "test". Auto-stops after 15s, but re-checks for real smoke
      # first so a genuine alarm starting mid-test is never silenced by the timer.
      (ha.automation "system/fire_alarm.test" {
        triggers = [ (ha.trigger.on selfTestSensors) ];
        conditions = nothingAlarming;
        actions = sirensOn
          ++ notifyTest
          ++ [ (ha.action.delay "00:00:15") ]
          ++ [ allSmokeClear ]
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

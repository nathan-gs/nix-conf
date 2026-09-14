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
  #           (stop/pre_alarm/fire/burglar), the BSD-2 takes a switch, and the
  #           Aqara takes a buzzer select (alarm/mute).
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
    {
      # covers: nominally the whole house from the top of the staircase, but
      # realistically mostly fen and morgane.
      #
      # Aqara JY-GZ-01AQ, sold as SD-S01E. Its buzzer can only be commanded while
      # the device sees no smoke of its own if linkage_alarm is on - i.e. exactly
      # the interlink case - and it fails silently otherwise. It came from the
      # factory with linkage_alarm already true; if this device is ever re-paired,
      # check that again before trusting the interlink.
      label = "de zolder";
      smoke = "binary_sensor.floor2_hallway_fire_alarm_main_smoke";
      # test = null: this device does not report its self-test state. Measured
      # 2026-09-14 - the selftest command was delivered and the device audibly
      # alarmed, yet binary_sensor..._test never left unknown and lastSeen did not
      # move for another half hour. So its button can never trigger the interlink;
      # wiring one here would only look like it worked. Its siren and smoke sensor
      # are unaffected - both verified the same evening.
      test = null;
      siren = { kind = "aqara"; entity = "select.floor2_hallway_fire_alarm_main_buzzer"; };
    }
  ];

  smokeSensors = map (a: a.smoke) alarms;
  # Devices whose self-test is observable. A device may set test = null when it
  # does not report one - see the attic Aqara.
  selfTestSensors = lib.filter (t: t != null) (map (a: a.test) alarms);

  sirensOf = kind: map (a: a.siren.entity) (lib.filter (a: a.siren.kind == kind) alarms);
  twinguardSirens = sirensOf "twinguard";
  bsd2Sirens = sirensOf "bsd2";
  aqaraSirens = sirensOf "aqara";

  sirensOn =
    (map (e: ha.action.set_value e "fire") twinguardSirens)
    ++ (map (e: ha.action.on e) bsd2Sirens)
    ++ (map (e: ha.action.set_value e "alarm") aqaraSirens);

  sirensOff =
    (map (e: ha.action.set_value e "stop") twinguardSirens)
    ++ (map (e: ha.action.off e) bsd2Sirens)
    ++ (map (e: ha.action.set_value e "mute") aqaraSirens);

  allSmokeClear = { condition = "state"; entity_id = smokeSensors; state = "off"; };

  # Set for the duration of a real alarm. Exists because turning things off is not
  # enough on its own: electric_heating.nix and ventilation.nix would cheerfully
  # switch the heaters and the WTW back on at their next trigger. Both consult this
  # and hold off while it is on.
  fireActive = "input_boolean.fire_alarm_active";

  # Escape lighting. Enumerated rather than using the "all" keyword so the list is
  # auditable and cannot silently change meaning - add new lights here.
  escapeLights = [
    "light.floor0_bureau_light_desk"
    "light.floor0_keuken_light_plug_aanrecht_l1"
    "light.floor0_keuken_light_switch_main_l1"
    "light.floor0_keuken_light_switch_main_l2"
    "light.floor0_living_light_bollamp"
    "light.floor0_living_light_booglamp"
    "light.floor0_living_light_kattenlamp"
    "light.floor0_living_light_switch_raam_zuid"
    "light.floor0_living_light_tv"
    "light.floor0_wc_light_switch_main_l1"
    "light.floor1_badkamer_light_switch_main_l1"
    "light.floor1_badkamer_light_switch_main_l2"
    "light.floor1_badkamer_light_switch_spiegel_l1"
  ];

  # Every electrical heat source. The gas CV is deliberately NOT touched: driving it
  # through ebusd is complex and its failure modes in an emergency are worse than
  # leaving it be. airco is included because split units heat as well as cool, and
  # cutting a large load during a fire is no loss either way.
  heaters = [
    "switch.system_wtw_metering_plug_verwarming"
    "switch.floor0_living_metering_plug_verwarming"
    "switch.floor0_bureau_metering_plug_verwarming"
    "switch.floor1_nikolai_metering_plug_verwarming"
    "switch.floor1_badkamer_metering_plug_verwarming"
    "switch.floor1_fen_metering_plug_deken"
    "switch.floor1_fen_metering_plug_airco"
  ];

  # Other large loads worth killing during a fire. The EV charger is the biggest
  # single load in the house, and an energised charge cable is not something you
  # want live while the fire brigade is working. The dryer earns its place for a
  # different reason: lint plus a heating element makes it one of the likeliest
  # appliances to *be* the fire.
  #
  # These are relay switches on metering plugs, so cutting them stops the appliance
  # without removing the plug from the Zigbee mesh - the plug stays mains-powered
  # and keeps routing. Verified on this system: floor0/living's verwarming plug
  # routes for the living room alarm at LQI 69 with zero ping failures while its
  # relay has been off all summer.
  largeLoads = [
    "switch.system_car_charger"
    "switch.floor1_waskot_metering_plug_droogkast"
    "switch.floor1_waskot_metering_plug_wasmachine"
  ];

  # Grace period before the loads above are shed, so that clearing a false alarm
  # from your phone saves a running wash or charge. Nothing life-safety waits on
  # this - sirens, escape lighting, the notification, the heaters and the WTW all
  # happen immediately; only these three are held back.
  #
  # 5 rather than 2 minutes because false alarms vastly outnumber fires and the
  # safety difference is small: cutting power does not extinguish anything, it only
  # stops adding heat. Shorten it if that trade feels wrong - it is just this value.
  loadShedGrace = "00:05:00";

  # Mains plug of the WTW unit, cut during a fire.
  #
  # A balanced MVHR extracts from the wet rooms and supplies into the bedrooms, so
  # leaving it running during a fire distributes smoke to where people sleep, moves
  # it between floors through the ducts, and feeds the fire air. It is far too weak
  # to clear a fire's smoke but more than strong enough to relocate it. Shutdown on
  # fire alarm is the normal requirement.
  #
  # It has to be the plug: fan.itho_wtw_fan exposes no "off" preset (low is its
  # floor), and "low" would still transport smoke, only slower.
  wtwPower = "switch.system_wtw_metering_plug_wtw";

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
        (a: [ "'${a.smoke}': '${a.label}'" ]
          ++ lib.optional (a.test != null) "'${a.test}': '${a.label}'")
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
      message = "Rook gedetecteerd in ${whichAlarm}. Alle sirenes zijn geactiveerd. Wasmachine, droogkast en laadpaal gaan over 5 min uit - stop het alarm nu om dat te voorkomen.";
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

    input_boolean = {
      fire_alarm_active = {
        name = "fire alarm active";
        icon = "mdi:fire-alert";
      };
    };

    "automation manual" = [

      # Ordered by urgency: raise the interlock first so nothing races us back on,
      # then the life-safety actions (sirens, escape lighting), then notify, then
      # the slower risk-reduction ones.
      (ha.automation "system/fire_alarm.detected" {
        triggers = [ (ha.trigger.on smokeSensors) ];
        actions = [ (ha.action.on fireActive) ]
          ++ sirensOn
          ++ (map ha.action.on escapeLights)
          ++ notifyAlarm
          ++ (map ha.action.off heaters)
          ++ [ (ha.action.off wtwPower) ];
      })

      # Shed the big loads only once the alarm has stood for the grace period.
      # Expressed as a "for" on the interlock rather than a delay inside the detect
      # automation: clearing the alarm turns fire_alarm_active off, which cancels
      # the timer outright, so a cleared false alarm never reaches these actions.
      # A delay+condition would also work but would tie up the detect automation,
      # and under mode=single a second alarm during the wait would be dropped.
      (ha.automation "system/fire_alarm.shed_loads" {
        triggers = [ (ha.trigger.on_for fireActive loadShedGrace) ];
        actions = map ha.action.off largeLoads;
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
      #
      # Lights and heaters are deliberately NOT restored here. Switching the lights
      # back off after a fire would be wrong, and the heaters resume on their own
      # once the interlock lifts. The WTW is the exception: it is powered back up,
      # both because ventilation is wanted once the smoke needs clearing and because
      # a house silently left without ventilation is easy to forget about.
      (ha.automation "system/fire_alarm.clear" {
        triggers = [
          (ha.trigger.state "input_button.fire_alarm_clear")
          {
            platform = "event";
            event_type = "mobile_app_notification_action";
            event_data = { action = "FIRE_ALARM_CLEAR"; };
          }
        ];
        actions = sirensOff
          ++ [ (ha.action.off fireActive) ]
          ++ [ (ha.action.on wtwPower) ];
      })

    ];

    sensor = [];
    template = [

    ];

  };

}

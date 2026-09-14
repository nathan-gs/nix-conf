# Fire alarms

Config lives in `smarthome/devices/fire_alarm.nix` (z2m device entries) and
`smarthome/air_quality/fire_alarm.nix` (interlink automations).

## Devices

| Location | Model | IEEE | Parent | LQI |
|---|---|---|---|---|
| `floor0/living/fire_alarm/main` | Bosch Twinguard 8750001213 | `0x000d6f00196fc58f` | `floor0/living/metering_plug/verwarming` | 69 |
| `floor1/hallway/fire_alarm/main` | Bosch Twinguard 8750001213 | `0x000d6f0019104455` | `floor1/badkamer/light_switch/main` | 78 |
| `basement/basement/fire_alarm/top` | Bosch BSD-2 (Smoke alarm II) | `0xf84477fffe0c62e1` | Coordinator (direct) | 132 |
| `floor2/hallway/fire_alarm/main` | Aqara JY-GZ-01AQ (sold as SD-S01E) | `0x54ef441001313d40` | `floor1/badkamer/light_switch/main` | 87 |

All optical/photoelectric. No heat or CO detection anywhere in the house.

The attic unit is at the top of the staircase. It is sold as **SD-S01E**, which is
not a model z2m knows by that name - the box SKU is not what z2m matches on. Over
the air it reports `lumi.sensor_smoke.acn03` and is recognised as JY-GZ-01AQ, so
no external converter is needed.

It was paired through the NIKO badkamer switch, a floor below, rather than the
SONOFF `wtw_valve/main` that is physically in the attic. It would not join via
`wtw_valve` but took first time via the NIKO. The upstream discussion for this
model reports having to "remove and add it like twenty times"; the difference is
probably that the NIKO has a direct one-hop path to the coordinator while
`wtw_valve` has none, and interviews are round-trip heavy. If the day-to-day link
at LQI 87 proves weak, re-pairing via `wtw_valve` is the thing to try - but expect
the join itself to be harder.

## Coverage

- **basement top** — the basement, and partially `floor0` hallway and kitchen.
- **living** — the living room.
- **floor1 hallway** — `waskot`, `fen`, `nikolai`, `badkamer`, `morgane`.
- **floor2 hallway (attic)** — nominally the whole house from the top of the
  staircase, but realistically mostly `fen` and `morgane`.

### Gaps

- **The basement CV room is not properly covered.** Only partially, by the
  basement-top unit. This is the boiler; it is the worst remaining gap.
- No coverage of kitchen or `waskot` by a detector suited to them. Both are
  places an optical alarm nuisance-trips, so the right answer there is a **heat**
  alarm, not another smoke one - see "Heat and CO" below.

## How the interlink works

Bosch alarms do **not** interconnect themselves. The z2m converter says outright
that "a detected smoke alarm is not being transmitted automatically to other
devices", so HA does it:

- `system/fire_alarm.detected` - smoke on any unit sounds every unit and sends a
  critical (DND-bypassing) push to all three phones.
- `system/fire_alarm.test` - holding a device button sounds everything for 15s,
  then stops. Guarded so it will not fire while something is really alarming.
- `system/fire_alarm.clear` - `input_button.fire_alarm_clear`, or the
  "Alarm stoppen" action on the notification.

Twinguards are commanded via a `select` (stop/pre_alarm/fire/burglar); the BSD-2
via a switch, which with `broadcast_alarms` on is relayed to every BSD-2 on the
network. So further BSD-2s are covered for free, but each new Twinguard (and the
Aqara) must be added to the `alarms` list by hand.

## What a real alarm does

In order of urgency:

1. `input_boolean.fire_alarm_active` on - the interlock, raised first
2. all sirens sound
3. 13 escape lights on
4. critical push to all three phones
5. 7 electrical heaters off
6. the WTW mains plug off

Then, **only after the alarm has stood for 5 minutes** (`loadShedGrace`):

7. the EV charger, dryer and washing machine off - the charger is the biggest load
   in the house and an energised charge cable is not wanted live while the fire
   brigade is working; the dryer earns its place for a different reason, being
   lint plus a heating element and so one of the likeliest appliances to *be* the
   fire

The grace period exists so that clearing a false alarm from your phone saves a
running wash or charge. It is built as a separate automation
(`system/fire_alarm.shed_loads`) triggered by `fire_alarm_active` being on *for*
5 minutes, not as a delay inside the detect automation: clearing the alarm turns
the interlock off, which breaks the `for` and cancels the timer outright, so a
cleared alarm can never reach these actions. A delay plus condition would also
work, but it would tie up the detect automation - and under `mode: single` a
second alarm arriving during the wait would be dropped, losing its sirens.

Nothing life-safety waits on the grace period. The notification states the window
explicitly, since a grace period nobody knows about is of no use.

Note this makes "clear alarm" do double duty: it silences the sirens *and* spares
the appliances. Silencing a confirmed fire in order to think also cancels the
load shed.

Cutting a metering plug's relay stops the appliance but does **not** remove the
plug from the Zigbee mesh - it stays mains-powered and keeps routing. Verified
here: the living room alarm parents to `floor0/living/metering_plug/verwarming`
at LQI 69 with zero ping failures while that relay has been off all summer. So
none of these cuts degrade the mesh during a fire, which would otherwise be a
reasonable worry.

The **button test deliberately does none of this** - it is sirens and a
notification only. A test should not kill the heating and blank the house.

### Why the WTW is cut rather than turned down

A balanced MVHR extracts from the wet rooms and supplies into the bedrooms. Left
running during a fire it distributes smoke to where people sleep, carries it
between floors through the ducts, and feeds the fire air. It is far too weak to
clear a fire's smoke (a few hundred m3/h) but more than strong enough to move it
somewhere worse. Shutdown on fire alarm is the normal building-code requirement.

It has to be the plug (`switch.system_wtw_metering_plug_wtw`): `fan.itho_wtw_fan`
exposes no "off" preset - `low` is its floor - and `low` would still transport
smoke, only more slowly.

The gas CV is deliberately left alone: driving it through ebusd is complex and its
failure modes in an emergency are worse than leaving it be.

### The interlock, and how it can bite

Turning things off is not enough on its own - the house would switch them back on:

| Automation | Would have |
|---|---|
| `electric_heating.nix` `automateTurnOn` (x5) | re-energised a heater at the next target transition |
| `appliances/deken.nix` | switched the electric blanket on when the living room empties after 21:50 - i.e. exactly during an evening fire |
| `ventilation.nix` `itho_wtw_target` | re-applied a fan preset |
| `car/car_charger/tuya.nix` start | restarted the EV charger via `should_charge` |

All eight now hold off while `input_boolean.fire_alarm_active` is on.

**This makes that boolean load-bearing for heating, ventilation, the blanket and
car charging.** If an alarm is silenced at the device (battery pulled, button
held) instead of through HA, the boolean stays on and all of those stay off
indefinitely, with nothing to say why. In winter that is a cold house with no
obvious cause, and a car that never charges overnight. Check it first if any of
those mysteriously stop working.

Clearing restores the WTW but deliberately not the lights or heaters: switching
lights off after a fire would be wrong, and the heaters resume by themselves once
the interlock lifts.

## Testing

**Hold the button for ~5 seconds.** A short tap produces *no Zigbee message at
all* - not a missed flag, literal silence. This cost an hour on 2026-09-12: the
first test looked like a broken automation when the press had simply never
transmitted.

Verified working 2026-09-12: button held on the basement BSD-2, all three sirens
sounded, auto-stopped after 15s.

## Gotchas

- **Twinguard rejoin does not re-run `configure`.** A factory-reset device joins
  fresh and configures itself, but a device that merely rejoins skips it, so it
  never receives `pairingCompleted` and sits paired-but-silent forever. Fix
  without touching the hardware:
  `mosquitto_pub -t zigbee2mqtt/bridge/request/device/configure -m '{"id":"<name>"}'`
- **Some entities are permanently `unknown`, and that is not a fault.** Note
  `unknown` (no value yet) is not `unavailable` (cannot be reached).
  - `select.*_fire_alarm_main_alarm` - the Twinguard converter never *reports*
    `alarm`; its from-Zigbee handlers set `smoke`, `siren_state`, `self_test` and
    the measurements, but nothing populates `alarm`. It is write-only in practice.
    This does **not** stop the automation commanding it: verified 2026-09-12, the
    test set both selects to `fire` and every siren sounded.
  - `number.*_test_mode_timeout` - only has a value while test mode is running.
  - `aqi` / `eco2` on a freshly paired Twinguard - the VOC element needs a burn-in
    period well beyond an hour. `eco2` is derived from `aqi` (`aqi * 10 + 500`), so
    both appear together. These do resolve on their own.

  The first two never resolve and are filtered out of the unavailable-entities
  sensor in `smarthome/ha/default.nix`.
- **`sensor.*_siren_state` lies after a stop.** For `alarm = "stop"` the
  converter sends the commands but returns no optimistic state, so Twinguards
  keep reading `fire` until the device reports otherwise. Do not put it on a
  dashboard as proof a siren is off. The BSD-2's switch state is trustworthy.
- **Availability timeout is 90 min** (`availability.timeout` per device),
  against z2m's 1500 min default for battery devices. Both Bosch models check in
  every 27 min, so 90 is three missed check-ins. The Aqara checks in **hourly**
  (`quirkCheckinInterval("1_HOUR")`) and will need roughly 200 min instead, or it
  will cry wolf.
- **Parent choice matters more than signal.** The living room unit died on
  2026-09-10 because it had parented to `floor0/living/light/tv`, a Tuya bulb
  that leaves the mesh whenever the lamp is switched off. Always pair through an
  always-on router using a targeted permit-join:
  `mosquitto_pub -t zigbee2mqtt/bridge/request/permit_join -m '{"time":254,"device":"<router>"}'`
  That unicasts the request so only that router accepts the join. `"Coordinator"`
  is a valid target and is the best parent of all when in range.
- **Bosch needs an install code** from the QR sticker; the printed plaintext code
  is not enough. It is stored in the dongle's NV, not in z2m or this repo - the
  sticker is the only copy. Add it with
  `mosquitto_pub -t zigbee2mqtt/bridge/request/install_code/add -m '{"value":"<QR payload>"}'`
  Adding the code does **not** open pairing; that is a separate request.
- **z2m runs at `log_level: warning`,** so joins, interviews and publishes are
  invisible in the journal. Watch `zigbee2mqtt/bridge/#` over MQTT instead, or
  raise the level temporarily. Note `ExecStartPre` recopies `configuration.yaml`
  from the nix store on every start, so any runtime change reverts on restart.

## Aqara JY-GZ-01AQ notes

- Works with z2m; the "requires Aqara Hub" claim on the box is marketing.
- **Do not OTA it.** Firmware v21 made it beep *once* and self-mute on detecting
  smoke; z2m retracted that version, but the device supports OTA and could take
  it. This unit's firmware version **cannot be read** - it reports
  `installed_version: -1` and a garbled `swBuildId` - so there is no way to tell
  whether it carries v21. That is a reason to leave OTA alone, not to reach for it.
- **`linkage_alarm` must be true,** otherwise the buzzer silently refuses to sound
  when commanded while the device sees no smoke of its own - exactly the interlink
  case. This unit arrived with it already set; re-check after any re-pair.
- It **does** use an install code, contrary to the z2m docs page saying 3 button
  presses. The QR is the Aqara `G$M:...$A:<ieee>$I:<key>` format, which z2m parses.
- Replaceable CR17450 cell. Arrived at 100% / 3100 mV.
- Ignore the reported `dateCode` - this unit reports `20230310` while the printed
  manufacturing date is 05/2025, so the date code is a firmware or design date and
  says nothing about service life.
- Aqara end devices have a poor reputation on Tuya-heavy meshes, and this mesh is
  mostly Tuya - so it is worth keeping it on the NIKO or SONOFF routers rather than
  letting it land on a Tuya plug.

## Heat and CO, if ever added

- Heat: **Heiman HM-5HA-E / HM-5HA-EF-3.0**. Has a commandable siren
  (`sirenForAutomationOnly`), so it interlinks both ways like the Bosch units.
  The right device for the kitchen and next to the dryer in `waskot`.
- CO: every CO alarm in the converter set is `toZigbee: []`, i.e. detect-only -
  it could trigger the interlink but never be sounded by it. FireAngel
  `ZBCO-AE-10X-EUR` is the most credible. Nothing in the house detects CO today,
  which is worth weighing given the gas heating.

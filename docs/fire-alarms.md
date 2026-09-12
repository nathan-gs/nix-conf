# Fire alarms

Config lives in `smarthome/devices/fire_alarm.nix` (z2m device entries) and
`smarthome/air_quality/fire_alarm.nix` (interlink automations).

## Devices

| Location | Model | IEEE | Parent | LQI |
|---|---|---|---|---|
| `floor0/living/fire_alarm/main` | Bosch Twinguard 8750001213 | `0x000d6f00196fc58f` | `floor0/living/metering_plug/verwarming` | 69 |
| `floor1/hallway/fire_alarm/main` | Bosch Twinguard 8750001213 | `0x000d6f0019104455` | `floor1/badkamer/light_switch/main` | 78 |
| `basement/basement/fire_alarm/top` | Bosch BSD-2 (Smoke alarm II) | `0xf84477fffe0c62e1` | Coordinator (direct) | 132 |
| _(ordered 2026-09-12)_ attic, top of staircase | Aqara JY-GZ-01AQ | — | plan: `floor0/living/wtw_valve/main` | — |

All optical/photoelectric. No heat or CO detection anywhere in the house.

## Coverage

- **basement top** — the basement, and partially `floor0` hallway and kitchen.
- **living** — the living room.
- **floor1 hallway** — `waskot`, `fen`, `nikolai`, `badkamer`, `morgane`.
- **attic (future)** — nominally the whole house from the top of the staircase,
  but realistically mostly `fen` and `morgane`.

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

## Aqara JY-GZ-01AQ notes (before it arrives)

- Works with z2m; the "requires Aqara Hub" claim on the box is marketing.
- **Do not OTA it.** Firmware v21 made it beep *once* and self-mute on detecting
  smoke; z2m retracted that version, but the device supports OTA and could take
  it. Check the firmware version on arrival.
- **Set `linkage_alarm: true`,** otherwise the buzzer cannot be sounded remotely
  when the device has no local smoke - i.e. exactly the interlink case - and it
  fails silently.
- Pairing is 3 button presses, no install code.
- Replaceable CR17450 cell, ~10y claimed.
- Aqara end devices have a poor reputation on Tuya-heavy meshes, and this mesh is
  mostly Tuya. Pair it through the SONOFF `wtw_valve/main` (in the attic, wooden
  wall to the staircase, ~5m) rather than anything Tuya.

## Heat and CO, if ever added

- Heat: **Heiman HM-5HA-E / HM-5HA-EF-3.0**. Has a commandable siren
  (`sirenForAutomationOnly`), so it interlinks both ways like the Bosch units.
  The right device for the kitchen and next to the dryer in `waskot`.
- CO: every CO alarm in the converter set is `toZigbee: []`, i.e. detect-only -
  it could trigger the interlink but never be sounded by it. FireAngel
  `ZBCO-AE-10X-EUR` is the most credible. Nothing in the house detects CO today,
  which is worth weighing given the gas heating.

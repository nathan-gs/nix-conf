# Andalung EV charger — E5 over-current trips & HA-side flapping (2026-08-28/29)

## Hardware

- Charger: **Andalung portable EV charger, 3.5 kW / Schuko, ~7 m, Tuya** (Type 2 + Schuko;
  https://www.andalung.com/products/andalung-portable-ev-charger-3-5kw-7m).
- Car: **Audi A6 Sportback e-tron 2025** (~100 kWh), dual AC Type 2 ports — both tried.
- Control: Tuya / Tuya Local integration + Home Assistant automations in
  `smarthome/car/car_charger/tuya.nix`.
- Car and charger both ~6 months old at the time; no prior charging issues.
- House supply has known voltage sag under load (216 V loaded vs. ~228–231 V idle).

## Fault #1: charger-side over-current protection (E5)

### Signature

- On-screen **E5**, **SuspendedEVSE** status, **red ring**, LED **5 red flashes**. Per the
  Andalung manual, 5 red flashes = over-current during charging (same code family as other Tuya
  portables' generic "E5 = over-current").
- CP goes from **6.0 V (charging)** to **9.0 V**, current drops to **0.0 A**, power to 0 kW.
- Not a thermal trip — box read as cold/22–34 °C on failures (overtemp is a different code,
  8 flashes).

### Trigger

The car's software updated to **03.11.00/C** (PPE combined flash, successor to **03.10.00/C
KD2**, which Audi's release notes listed as including charging fixes). High-current AC charging
on this specific portable started failing only after that update — **before the update the same
charger ran fine at 16 A.**

Plausible mechanism: 03.11.00/C changed the OBC/CP behaviour enough that this charger's own
over-current protection now trips, especially combined with the house's voltage sag under load.
No public reports found tying 03.11.00/C specifically to this failure mode; Audi does have 2025
A6/Q6 e-tron TSBs for AC charging issues after software updates (3.8 kW cap, AC fail, socket lock),
but nothing that matches this exactly.

### What testing on 2026-08-29 showed

- **8 A**: ran past 29 minutes with no E5.
- **10 A**: ran past 18 minutes with no E5.
- **13 A**: after a gradual **8 A → 10 A → 13 A** ramp (with delays between each step), ran for
  **hours** — but eventually still tripped E5. One such session that day: switch on 07:28 local,
  steady at 13 A, tripped **09:52:46 UTC (11:52:46 local)** — 3.5 hours in. So sustained 13 A is
  *more* stable than a cold jump to 13–16 A, but is **not** guaranteed safe long-term.
- A **cold start directly at 13 A** (current left over from a prior session, no ramp) tripped
  within **26 seconds** of power-on (2026-08-29 10:00:04 → 10:00:30 UTC).

### Workaround (charger/car side, not fixable from HA)

- Always start a session at **8 A**, then step up (8 → 10 → 13 A) with delay between jumps.
- Expect 13 A may still die on a long session; no current level found so far is proven safe
  indefinitely.
- 8 A ≈ 1.8 kW (~18 kWh/10 h) is too slow as the *only* charging method for a 100 kWh car; 10 A ≈
  2.3 kW, 13 A ≈ 3.0 kW, 16 A ≈ 3.7 kW (pre-update speed).
- **Not done yet** (external, not HA): run a second charger on the same car/outlet/port at
  13–16 A for a long session — if it holds, the Andalung is the weak link; if it also dies, the
  fault is upstream (car/supply) and worth a dealer read of the charge-unit/HV-box event memory.

## Fault #2: HA made the trip worse — rapid-fire current commands

### What happened

Investigating the 09:52:46 UTC trip above, HA's own automation turned out to have compounded it.
`sensor.system_car_charger_target_current` (the computed "ideal current right now" from the
capacity-tariff/headroom formula) recalculates on every dependency change — including the
intentionally noisy front-of-quarter headroom term, which is documented in the code itself as
chattery by design.

`automation.system_car_charger_set_current` was `mode = "restart"` and triggered on **any** change
of that target sensor. Each retrigger **cancelled the in-flight 1-minute step delay** and
immediately fired a fresh `number.set_value`. On 2026-08-29, the target recalculated
13 → 10 → 8 → 6 A in about 2 seconds (driven by `electricity_delivery_power_15m_estimated`
climbing fast), and the charger's actual current readback followed in lock-step:
13→10 A (09:52:42.086), →8 A (09:52:43.218), →6 A (09:52:43.750) — three real commands to the
device roughly a second apart. The switch reported off 3 seconds later. That cadence is
physically impossible to produce with a 1-step-per-60s delay working as intended — confirming the
automation, not just the charger, was misbehaving.

### Fix (`automation.system_car_charger_set_current`)

- Trigger now debounces via `for: "00:01:00"` — only reacts once the target has held steady for a
  full minute, instead of chasing every recalculation. (10s was tried first and judged too short;
  see commit history.) This targets the noisy front-of-quarter headroom branch specifically.
- Step delay increased from 1 to 2 minutes.
- The real capacity-tariff safety drop is exempted from both: `binary_sensor.system_car_charger_capacity_near`
  (banked `electricity_delivery_power_15m` crossing near the monthly cap) is monotonic within a
  quarter — it can't flap, so debouncing it serves no purpose — and gets its own **undebounced**
  trigger straight to 6 A. Its margin was also widened from 0.3 to 0.5 kW below the cap, to give
  back the time the slower 1 min debounce + 2 min/step cadence now costs elsewhere, so the average
  still lands under the cap before the 15-minute window closes.

## Fault #3: cold starts and stale current

`number.system_car_charger_charging_current` persists across restarts — a fresh start could
resume directly at whatever current was last used (e.g. 13 A), which is exactly the "cold start at
13–16 A is unreliable" failure mode above. Confirmed: the 10:00:04 UTC session on 2026-08-29
started with current already at 13 A (no ramp), tripped in 26 seconds.

### Fix (`automation.system_car_charger_start`)

Every start now resets current to 8 A right after turning the switch on (not before/while off —
see the "odd bug" note below), so every session ramps up from a cold 8 A regardless of history.

## Fault #4: manual current override bypassed all safety logic

`input_select.system_car_charger_current_override_a`, when set to a fixed amperage, used to
**replace** the entire headroom/peak-shaving calculation in `target_current` rather than cap it —
so a manual override could hold a current the house/charger couldn't actually sustain.

### Fix (`sensor.system_car_charger_target_current`)

The override now folds into `cap` (`cap = min(cap, override)`) instead of short-circuiting the
calculation. Headroom and peak-shaving always run and can still scale the actual current down
under that ceiling.

## Fault #5: HA repeatedly tried to charge an unplugged car (unrelated flapping)

### What happened

Separately from the E5 trips, `binary_sensor.system_car_charger_should_charge` has no concept of
whether a car is physically connected. While the car was away on 2026-08-29 (14:15–16:30 UTC),
the `/10m` recheck trigger plus every `sensor.system_house_pv_battery_soc` tick kept firing
`car_charger.start`, which turned the (unplugged) charger's switch on; with no vehicle to
negotiate a CP handshake it self-reported off within seconds every time. **36 switch flaps and 34
current writes in that one 2h15m window.**

### First attempt: Audi Connect API — rejected

Initially gated `start` on `binary_sensor.audi_a6_sportback_e_tron_plug_state` (+
`binary_sensor.anyone_home`, added because the Audi Connect API is cloud-polled and can lag well
behind reality). Then compared it against the charger's own status and found the Audi API is too
slow to trust even with that workaround: on the reconnect event that ended the 14:15–16:30 window,
`sensor.system_car_charger_status` reported `plugged_in` at **16:18:48**, a full **12 minutes**
before `binary_sensor.audi_a6_sportback_e_tron_plug_state` caught up at **16:30:46**.

### Fix — charger-native status instead

Added `binary_sensor.system_car_charger_vehicle_connected`, derived directly from the Tuya
charger's own status DP (`sensor.system_car_charger_status`: `available` / `plugged_in` /
`charging` / `paused` / `fault` / `fault_unplugged`) — local to the device, no cloud dependency,
no Audi or phone entities involved:

```
vehicle_connected = status not in ['available', 'fault_unplugged', 'unavailable', 'unknown']
```

- `car_charger.start` now requires `vehicle_connected` to be `on` before attempting to turn the
  charger on.
- New automation `car_charger.disconnected`: when `vehicle_connected` drops while the switch is
  on, turns the switch off and resets current to 8 A immediately, instead of waiting for the next
  `/10m` recheck.

## Safeguard: hard stop when the cap can't be avoided by throttling alone

> **Superseded 2026-10-11.** `capacity_near` and `electricity_capacity_critical` are gone; the
> single headroom rule and `binary_sensor.system_car_charger_capacity_pause` replace them — see
> "Current design" in `ev-battery-peak-coordination.md`. The debounce is now 30 s, steps 45 s.

The car's minimum current step is 6 A (~1.38 kW) — a *floor*, not zero. `target_current`'s
`banked >= capacity_near` tail throttles down to it, but if house load *other than the car* is
already enough to blow the quarter's capacity-tariff cap, throttling the car to 6 A doesn't help;
its residual 1.38 kW can still be the difference. The house battery is the first line of defence
(down to its own floor, `binary_sensor.solar_battery_sufficient` — see
`docs/ev-battery-peak-coordination.md`), but once *that* has nothing left to give either, nothing
was stopping the car's 6 A tail from adding to an overage that was going to happen regardless.

### Fix — `binary_sensor.electricity_capacity_critical` (`smarthome/energy/capacity_peaks.nix`)

Deliberately general, not car-specific, so any load could react to it in future:

```
electricity_capacity_critical =
  electricity_delivery_power_max_threshold (on)   # cap breached by non-car load alone, projected
  and not solar_battery_sufficient (on)           # AND the battery has hit its own floor
```

`electricity_delivery_power_max_threshold` already projects the quarter's average *excluding*
whatever the car is currently drawing (see its comment in `capacity_peaks.nix`), so "on" already
means the cap is inevitable with or without the car.

`system/car_charger/should_charge` (`tuya.nix`) now ANDs in `not capacity_critical`, applied
uniformly like the existing `rebalance` gate — including over `low_soc` (a critically low car
battery does not override this): a few minutes without topping up the car is a smaller cost than
the tariff hit, and charging resumes automatically the moment the sensor clears.

## The "odd bug": don't write to the device while it's off

`car_charger.stop`'s conditions carry the note *"Odd bug, if you call this while off, it puts it
on"* — calling the off-sequence (switch off + follow-up `number`/`select` writes) when the switch
is **already** off flips it back on. The safe pattern established in `stop` (and now reused in
`start` and `disconnected`) is: only write to `number`/`select` entities on the device **right
after you yourself changed the switch state in the same automation run** — never write to it while
it's been sitting off from an earlier, unrelated run.

## Entity/automation reference

| Entity | Meaning |
|---|---|
| `sensor.system_car_charger_status` | Tuya charger's own status DP — source of truth for vehicle presence |
| `binary_sensor.system_car_charger_vehicle_connected` | Derived: is a car actually attached |
| `sensor.system_car_charger_target_current` | Computed ideal current (headroom/peak-shaving/solar/override) |
| `number.system_car_charger_charging_current` | Actual commanded current, stepped one increment at a time |
| `input_select.system_car_charger_current_override_a` | Manual current ceiling (not a fixed value) |
| `automation.system_car_charger_start` | Turns charger on, resets to 8 A, ramps |
| `automation.system_car_charger_stop` | Turns charger off when `should_charge` goes off |
| `automation.system_car_charger_disconnected` | Turns charger off + resets to 8 A on physical unplug |
| `automation.system_car_charger_set_current` | Debounced step-wise ramp toward `target_current` |
| `binary_sensor.electricity_capacity_critical` | (`capacity_peaks.nix`, general) cap unavoidable by non-car load alone + battery at its floor — hard-stops `should_charge` |

## Open items (not fixed by any of the above — hardware/car side)

- No second-charger test done yet to isolate charger-vs-car/supply as the E5 root cause.
- No overnight proof that 10 A never trips.
- Tuya Local only reports a generic "Problem" for the integration health; `sensor.system_car_charger_status`
  and HA's current history are the only detailed signal available.
- If E5 keeps recurring even at 8–10 A over long sessions, next step is a second charger test or a
  dealer read of the car's charge-unit/HV-box event memory.

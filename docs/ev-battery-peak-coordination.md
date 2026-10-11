# EV charging vs. house battery — peak-shaving coordination

## Incident (2026-07-03, ~04:00)

The car stopped charging overnight. The house battery had been drained to 10 % because the
peak-shaving logic used the *battery* to absorb an EV-driven grid peak instead of throttling the
*car*. When the battery hit its 10 % floor, `solar/battery/sufficient` flipped off and the car
hard-stopped — worst of both worlds: battery empty **and** car uncharged.

## What we are optimising

- **Hard constraint:** the capaciteitstarief peak is the monthly maximum of the **15-minute
  average** of grid *import*. It is measured at the fiscal P1/DSMR meter.
- **Goals:** charge the car as fast as that constraint allows, and never stop it; keep the house
  battery for the expensive evening peak rather than spending it on cheap overnight charging.

## Fast vs. slow signals (this drives the whole design)

| Signal | Source | Update rate |
|---|---|---|
| `electricity_grid_consumed_power(_mean_1m)` — grid import | P1/DSMR | seconds (**fast**) |
| `electricity_delivery_power_15m` — contribution to this quarter's final average so far | DSMR | seconds (**fast**) |
| `electricity_delivery_power_15m_estimated` — projected end-of-window 15-min average | template | seconds (**fast**) |
| `car_charger_power` | Tuya plug | seconds (**fast**) |
| `solis_battery_power`, `solis_remaining_battery_capacity` (SoC) | Solis | **~5 min, often much staler (SoC seen ~1 h old)** |

Rule that falls out of this: **peak control runs on fast signals only.** The battery sensors are
far too slow to steer a 15-minute window and must never gate time-critical car control.

## Why it happened

`solar/battery.nix` `overdischargesoc_target` had a **deep-discharge branch**: when
`power15m > capacity_near` **and** `power15m_estimated > capacity_threshold`, it dropped the
battery's discharge floor from its normal 20 % (15 % on a solar day) to `overdischargesoc_min`
(10 %). So to shave a grid peak the battery discharged *below its normal floor* — draining to 10 %
overnight to absorb load that should have been throttled at the car. When it hit 10 %,
`solar/battery/sufficient` flipped off and the car hard-stopped.

The intent is fine to a point: **using the battery down to its normal floor to cover load (incl.
the car at up to 13 A) is fine — it stops there on its own.** What is *not* fine is dropping the
floor below that to peak-shave. Peaks should be shaved by throttling the car, not by spending the
battery's reserve.

## Strategy: battery holds its floor; the car shaves peaks by throttling

**The battery may cover load (incl. the car at up to 13 A) down to its normal floor
(`number.solar_battery_overdischargesoc`, 20 % / 15 % on a solar day) and stops there on its own —
that is fine. It must never go *below* that floor to peak-shave.** Peaks are shaved by throttling
the car. Two changes implement this:

### 1. Battery — remove the deep-discharge branch (`solar/battery.nix`, `overdischargesoc_target`)

The branch that dropped the floor to `overdischargesoc_min` (10 %) for peak shaving is **removed**.
The floor is now only ever the normal 15 % (solar day) / 20 %:

```
if is_solar_left:            15
elif is_car_charging:        20
else:                        15 if battery < 12 else 20
```

So the battery discharges to cover load down to that floor and holds; it never spends its reserve
to shave a peak. (This is the actual fix for 2026-07-03.)

### 2. Car — throttle to keep grid import under the cap (`tuya.nix`, `system/car_charger/target_current`)

> **Superseded 2026-10-11** — see "Current design" at the end of this file.

Once the battery is at its floor it no longer covers the car, so grid import jumps to
car + house. The car then throttles so the 15-minute average stays under the cap:

```
capacity_kw   = max(2.5, monthly_peak)          # billing floor — no point throttling below 2.5
capacity_near = max(2.2, monthly_peak - 0.3)
banked        = electricity_delivery_power_15m
if banked >= capacity_near:                                  # late in the quarter -> tail
    target_a = 6
else:
    headroom_kw = capacity_kw - (estimated_15m - charger_kw) # room under the cap for the car
    target_a    = round(headroom_kw * 1000 / 230)            # scales with monthly_peak
# then solar-boost / min(.,13), snapped to [6,8,10,13,16]
```

While the battery is covering load (grid ≈ 0) the car sees full headroom and charges at up to 13 A —
fine, that is the battery doing normal self-use down to its floor. When the battery reaches its
floor, grid import rises and the headroom term throttles the car (≈ 8 A at a 2.5 cap, more on
higher-peak months), with a 6 A tail once `banked` passes `capacity_near`.

### Verified by simulation

A coupled time-step sim (car ramp + self-use battery + both control loops) confirms:
- **Normal car-only load:** identical before/after the battery change — the car throttles enough
  that the old peak branch never fired anyway; the battery covers the car to its floor and holds.
- **Heavy non-car load (oven ~1.2 kW):** *before*, the peak branch fired and the battery discharged
  **below** its floor (→ 10 % over a night); *after*, the battery holds at its floor and a small
  grid peak (≈ 2.58 vs 2.5 kW floor) is accepted instead — the battery's reserve is preserved.

### Eligibility (`tuya.nix`, `system/car_charger/should_charge`) — the anti-hard-stop guard

`solar/battery/sufficient` (house battery > 10 %) now gates **only solar charging**. Grid charging
(offpeak / low car SoC / manual `on`) draws from the grid, so a low house battery no longer stops
it. Even if the battery does reach 10 % as a backstop, the car keeps charging.

## Tuning knobs

- **Battery floor** = `number.solar_battery_overdischargesoc`, driven by `overdischargesoc_target`
  in `battery.nix` (20 % normally, 15 % on a solar day). This is the hard limit the battery will
  not discharge below; raise it to keep more reserve overnight.
- **Car cap** = `capacity_kw = max(2.5, monthly_peak)` and the `banked >= capacity_near` tail
  trigger in `tuya.nix` `target_current`. The 2.5 kW floor matches the capaciteitstarief billing
  minimum — shaving below that has no bill impact.
- If a heavy non-car peak occurs while the battery is at its floor, it is now *accepted* (the
  battery no longer spends its reserve to shave it). If you'd rather still shave such peaks with the
  battery down to some lower reserve, re-add a bounded deep-discharge branch with a floor above
  10 % (e.g. 15 %) rather than the old `overdischargesoc_min`.

## Residual assumption to watch

This relies on `number.solar_battery_overdischargesoc` being a hard discharge floor the inverter
actually enforces (the user's model: the battery "stops exporting by itself" there). During testing
the live SoC read 14 % while the floor sensor showed 20 %, so verify the floor is strictly enforced
in practice — if the battery discharges below the set floor regardless, that is an inverter-side
setting, not this logic.

## Sign conventions / key entities

- `sensor.solis_battery_power` — **negative = discharging**, positive = charging (W).
- `sensor.electricity_delivery_power_15m` — contribution to this quarter's final 15-min average
  (climbs 0 → final over the window).
- `sensor.electricity_delivery_power_15m_estimated` — projected final 15-min average import.
- `binary_sensor.solar_battery_sufficient` — house battery > 10 %.

## Incident 2 (2026-10-10, ~22:00) — car charged off a peak-shaving battery

The battery's floor was at 8 % (peak shaving) when the car started at 13 A. The battery covered
the car, the P1 meter read ~0, and `capacity_headroom_current` saw 18-24 A of headroom, so the
car stayed at 13 A while the pack went 14 % -> 7 % in 12 minutes.

The fix (car side only, battery logic untouched) led to the current design below.

## Current design (2026-10-11) — one rule for the car, plus a pause

Replaces section 2 above, `binary_sensor.system_car_charger_capacity_near` (the banked-threshold
tail) and `binary_sensor.electricity_capacity_critical`. Battery logic (`battery.nix`) is unchanged.

**`sensor.system_car_charger_capacity_headroom_current`**, all quarter:

```
peak    = max(2.5, this month's 15-min peak)
target  = peak - 0.1                 # where the battery starts peak-shaving
house   = grid import - car          # instantaneous, not the 1-min mean (see below)
h       = min(seconds_left, 120)     # ~ how long set_current takes to react
allowed = ((target - banked)*900 - (house + 8A)*(seconds_left - h)) / h - house
allowed = min(allowed, target - house + 0.5)                     # ~one step above steady
A       = allowed, else 8 if 8A to the end stays under peak, else 6 if 6A does, else 0
```

"Run `allowed` for the next 2 minutes, then 8 A to the end of the quarter, landing on target": the
car front-loads at 10 A and finishes on 8 A. 6 A is a last resort — the car's fixed ~250 W overhead
makes it the least efficient step.

**`binary_sensor.system_car_charger_capacity_pause`** stops the charger (via `should_charge`) when
headroom is 0 (even 6 A would breach the peak), **or** when the battery is peak-shaving (floor < 15 %)
and discharging. The second is the only thing that actually protects the battery: the inverter feeds
whatever load is on, so a throttled car still drains it. Charging off the battery down to its normal
15/20 % floor is fine and is not paused. `delay_off` 2 min, so a long load holds the car off rather
than restarting it every quarter.

## Simulation (`manual/ev-peak-sim.py`)

1 s time-step model of a 22:00-07:00 night: P1 15-min window, inverter self-use (3 kW max) with the
`battery.nix` floor rules, 1 % overshoot below the floor, force-charge, the start/stop automations,
30/60 s debounce and 45 s steps. Peak 2.56 kW, ~0.3 kW base load, 8.3 kWh pack.
A = before 2026-10-11, B = 10/8 A-tail interim, C = this design.
`nix-shell -p python3 --run 'python3 manual/ev-peak-sim.py all 150'`

| scenario | design | car kWh (net of 250 W) | min at 6 A | battery out kWh | min SoC | max quarter kW | stops |
|---|---|---|---|---|---|---|---|
| 2026-10-10 replay (14 %, floor stuck at 8 % for 28 min) | A | 19.4 (17.1) | 63 | 0.55 | 7.4 % | 2.51 | 0 |
| | C | 17.8 (15.7) | 0 | 0.15 | 12.2 % | 2.44 | 1 |
| quiet night, battery 40 % | A | 19.9 (17.6) | 61 | 1.76 | 18.8 % | 2.48 | 0 |
| | C | 19.1 (16.8) | 0 | 1.71 | 19.4 % | 2.43 | 0 |
| 2 kW load from minute 12 for 1 h, battery 9 % | A | 18.1 (16.0) | 65 | 0.13 | 7.4 % | **2.87** | 6 |
| | C | 16.7 (14.7) | 0 | 0.00 | 9.0 % | 2.44 | 1 |

150 random nights (1-5 loads of 1-2.2 kW, battery starting 9-50 %):

| design | car kWh (net) | min at 6 A | battery out kWh | nights SoC < 8 % | nights with car-caused new peak | avg peak rise | current changes | stops |
|---|---|---|---|---|---|---|---|---|
| A | 18.7 (16.5) | 103 | 1.21 | 65 | 66 | 0.163 kW | 129 | 2.1 |
| B | 19.0 (16.7) | 81 | 1.21 | 10 | 71 | 0.220 kW | 126 | 2.2 |
| C | 17.0 (15.0) | 0 | 0.74 | 3 | 1 | 0.032 kW | 94 | 3.6 |

C trades ~1.5 kWh/night of car charge (it aims 0.1 kW lower and pauses during big house loads) for
almost no car-caused peaks, no 6 A, and ~40 % less battery use. The remaining low-SoC nights and
peaks are house-only loads the battery is shaving, not the car. Findings that shaped it:

- A 1-min-mean house load against an instantaneous car power made the car oscillate to 6 A on
  every step (~300 changes/night); instantaneous both fixes it.
- Pausing only when the battery is <= 10 % left 10/150 nights with car-caused peaks: the battery
  only starts shaving late in a quarter, so at 9-13 % it covers nothing early on.
- Counting battery discharge as house load (tried first) is redundant once the car pauses while the
  battery peak-shaves — identical results, so it was dropped.
- Target `peak - 0.03` instead of `- 0.1`: +0.6 kWh/night, but 2x the car-caused peaks and more pauses.

## Night: the battery tops up the car, quarter by quarter

Self-use dumps whatever the battery holds above its floor into house + car in the first ~30 minutes
after 22:00, while grid import is ~0 — that half hour's peak budget is lost. Instead, while
`should_charge` is on between 22:00 and 07:00, `overdischargesoc_target` uses
`sensor.solar_battery_night_car_floor`, latched at every quarter start:

```
n%    = (car at its mode cap + house - target) * 15 min / 83 Wh per %  - 0.6 (inverter overshoot)
floor = min(40, max(15, SoC - max(1, n%)))
```

The battery covers house + car for the first ~4 minutes of the quarter and then holds; the car runs
at 13 A on the grid budget for the rest (the car rule allows 13 A while the battery is above 15 % at
night). At 15 % it is the regular cycle. The floor register tops out at 40 %: above that the battery
covers house + car down to 40 % first (as before), then the steering takes over. A floor above the
SoC holds the pack; it does not grid-charge it (2026-10-10: floor 12-20 % with SoC at 7 % stayed put
until force-charge). The peak-shave branch keeps priority, and the car pauses whenever it fires.
~1 floor write per quarter while the battery lasts.

| scenario | C (no spread) | linear schedule 22:00 SoC -> 15 % at 07:00 | **per quarter** | ideal: inverter caps grid import |
|---|---|---|---|---|
| quiet night, battery 40 % at 22:00 | 19.1 kWh car | 19.9 | **20.7** | 21.1 |
| quiet night, battery 60 % | 19.2 | 20.6 | **21.3** (22.2 without the 40 % cap) | 22.8 |
| quiet night, battery 80 % | 19.3 | | **21.7** | |
| 2 kW load at minute 12, battery 40 % | 18.6 | 19.4 | **20.1** | |
| battery <= 15 % | same | same | same | same |
| weekend heavy loads, battery 40 %: peak | 2.89 kW | 2.89 kW | **2.50 kW** | |
| 150 random nights | 17.0 kWh | 17.4 | **17.7**, same peaks | |

Sizing each release from the house load at the start of the quarter means that on the heavy weekend
the battery covers the oven too and no new peak is set. The linear schedule released 1 % wherever a
step happened to fall — late in a quarter the car had already dropped to 8 A and the slack was lost
at the rollover. The ideal (Solis grid peak-shaving mode or a discharge-power cap) is smoother but
needs an inverter mode change never tested on this RHI.

**Weekends** (offpeak all day): oven 1 h + washing machine + dryer 1 h + dishwasher + kettles,
overlapping, no solar (worst case): with an empty battery the house alone sets ~4.2 kW in every
design — only load control (oven, dryer) could stop that. This is night-only; weekend daytime is
the regular cycle and was not simulated with solar.

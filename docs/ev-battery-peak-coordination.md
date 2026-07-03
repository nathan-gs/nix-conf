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

Once the battery is at its floor it no longer covers the car, so grid import jumps to
car + house. The car then throttles so the 15-minute average stays under the cap:

```
capacity_kw   = max(2.45, monthly_peak)
capacity_near = max(1.95, monthly_peak - 0.6)
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
floor, grid import rises and the headroom term throttles the car (≈ 8 A at a 2.45 cap, more on
higher-peak months), with a 6 A tail once `banked` passes `capacity_near`.

### Verified by simulation

A coupled time-step sim (car ramp + self-use battery + both control loops) confirms:
- **Normal car-only load:** identical before/after the battery change — the car throttles enough
  that the old peak branch never fired anyway; the battery covers the car to its floor and holds.
- **Heavy non-car load (oven ~1.2 kW):** *before*, the peak branch fired and the battery discharged
  **below** its floor (→ 10 % over a night); *after*, the battery holds at its floor and a small
  grid peak (≈ 2.58 vs 2.45 kW) is accepted instead — the battery's reserve is preserved.

### Eligibility (`tuya.nix`, `system/car_charger/should_charge`) — the anti-hard-stop guard

`solar/battery/sufficient` (house battery > 10 %) now gates **only solar charging**. Grid charging
(offpeak / low car SoC / manual `on`) draws from the grid, so a low house battery no longer stops
it. Even if the battery does reach 10 % as a backstop, the car keeps charging.

## Tuning knobs

- **Battery floor** = `number.solar_battery_overdischargesoc`, driven by `overdischargesoc_target`
  in `battery.nix` (20 % normally, 15 % on a solar day). This is the hard limit the battery will
  not discharge below; raise it to keep more reserve overnight.
- **Car cap** = `capacity_kw = max(2.45, monthly_peak)` and the `banked >= capacity_near` tail
  trigger in `tuya.nix` `target_current`.
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

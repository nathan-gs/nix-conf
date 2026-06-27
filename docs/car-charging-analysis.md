# Car charger — voltage drop & charging speed

## Setup

- Tuya metering plug feeding a 1-phase EVSE on **L3**, ~45 m of 2.5 mm² cable from CU.
- Sensors:
  - `sensor.dsmr_reading_phase_voltage_l3` — voltage at the DSMR grid meter (unloaded reference).
  - `sensor.system_car_charger_metering_plug_measure_voltage` — voltage at the plug (loaded).
  - `sensor.car_charger_power` — powercalc-derived, compensated to grid-meter view.

## Measured source impedance (24 h sample, 2026-06-26)

| Load | V meter | V plug | House-side drop |
|---|---|---|---|
| Idle (<50 W) | 230.3 | 228.5 | ~0 (noise) |
| ~1.5 kW (≈7 A) | 229.1 | 218.4 | 10.7 V |
| ~2.5 kW (≈12 A) | 230.6 | 215.3 | 15.2 V |
| ~3.3 kW (≈15 A) | 229.9 | 211.6 | **18.3 V** |

- **Source impedance ≈ 1.22 Ω**, entirely inside the house (grid voltage at meter is stable under load).
- Cable theory (45 m × 2.5 mm² × round-trip × hot copper) ≈ 0.72 Ω → ~0.5 Ω is in the plug/socket/terminals.
- Drop is linear with current → pure resistance, no failing joint. Safe to keep using, but at the edge of the 5 % NEN 1010 spec at full 16 A.

## Charging speed vs current

EV consumption assumed: **16 kWh / 100 km** (= 6.25 km/kWh).
"Useful power" = V_idle × I − I²R, i.e. what arrives at the car after the in-house loss.

| Current | Useful kW | kWh / hour | km / hour | Loss | Loss % | In spec (<5 %)? |
|---:|---:|---:|---:|---:|---:|:---:|
| 6 A | 1.34 | 1.34 | 8.4 | 36 W | 2.6 % | ✅ |
| 8 A | 1.76 | 1.76 | 11.0 | 64 W | 3.5 % | ✅ |
| 10 A | 2.19 | 2.19 | 13.7 | 100 W | 4.4 % | ✅ |
| 13 A | 2.80 | 2.80 | 17.5 | 169 W | 5.7 % | ⚠️ |
| 16 A | 3.40 | 3.40 | 21.3 | 256 W | 7.0 % | ❌ |

### Sweet spot

**10 A** is the practical optimum: still inside NEN 1010, ~46 Wh wasted per kWh delivered, and 13.7 km of range per hour of charging is enough to add 100+ km overnight.

16 A only buys ~3.8 km/h extra over 13 A while dissipating 50 % more heat — concentrated in the connector chain (plug, socket, terminals), which is the relevant failure mode for sustained EV charging on domestic outlets.

## Energy compensation

The plug under-reports power because it sits *after* the voltage drop. Powercalc scales it back to the grid-meter view:

```
power_corrected = plug_power × V_grid_L3 / V_plug
```

This is mathematically `V_plug × I × (V_grid / V_plug) = V_grid × I` — exactly what the grid meter records, and exactly what billing/reimbursement should be based on. The I²R loss in the house wiring is captured as part of the "car charging" energy total (which is correct — you paid for it at the meter).

`car_charger_grid_power` and `car_charger_solar_power` are split off `sensor.car_charger_power` (the compensated value), so they inherit the correct scaling.

**Important:** the reference voltage must be the phase the charger is actually on (L3 here). Using a different phase silently miscompensates when phases diverge under load.

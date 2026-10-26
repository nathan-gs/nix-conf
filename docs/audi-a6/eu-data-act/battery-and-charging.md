# Battery and charging insights (full export, 2026-10-26)

Source: the one-off full export, history 2026-03-20 → 2026-10-25, plus HA's pole meter
(`sensor.system_car_charger_energy`). Re-run with [scripts/](scripts/).

## Capacity table (`energyContentOverSOC`)

| SoC | Energy content | kWh per 1 % in that band |
|---:|---:|---:|
| 0 % | 0 kWh | |
| 20 % | 16.2 kWh | 0.81 |
| 35 % | 29.1 kWh | 0.86 |
| 50 % | 42.3 kWh | 0.88 |
| 80 % | 70.3 kWh | 0.93 |
| 100 % | **91.55 kWh** | 1.06 |

- 91.55 / 94.9 kWh spec = **96.5 %**.
- Treat with care: it is the **first and only** reading (the 15-min datasets never carry it), it
  sits in the charge-planner settings next to round model parameters (efficiency `0.92`, base load
  `0.4 kW`), and it was captured in late October with a cool battery — VW Group cars typically lower
  available-energy estimates when cold. If real, 3.5 % after ~8 months / ~19,000 km is at the high
  end of normal early fade (typically 2–4 % in year one, then ~1–2 %/year).
- **To know for sure:** dealer battery test; repeat the full export mid-winter and next summer and
  compare this table. A higher summer value means it is temperature dependent; lower values in the
  same season over time mean real wear.

## kWh per % calibration

- The car's per-session charged energy (power-curve `deltaChargeEnergy`, 0.5 kWh resolution) matches
  the home pole meter: 24.5 vs ~25.0 kWh and 17.0 vs ~17.2 kWh on two overnight sessions.
- Long home sessions: **1.07–1.13 kWh at the wall per 1 % SoC**, so ~1.1 is a sound flat factor for
  the usual 50–80 % band (about ±10 % off at the extremes, per the table above).
- Short top-ups read 1.5–2.25 kWh/% — rounding noise from the 0.5 kWh resolution, ignore them.

## Battery-health indicators

No state-of-health field exists in either dataset; these are indirect.

| Indicator | Value | Reading |
|---|---|---|
| Equivalent full cycles | **37.5** in 7 months (~65/year) | Light |
| Time at 50–80 % SoC | 52–84 % of each month | Ideal |
| Time below 20 % | ≤ 1.4 % per month (lows of 9–10 % three times) | Fine |
| Time at ≥ 90 % | ≤ 5.3 % per month (only around trips) | Fine |
| DC fast charging | 6 days in 7 months, peak 220 kW | Minimal |
| Battery care | Activated throughout (`invalid` = car asleep), threshold 80 % | Good |
| Parked drain | 0 % over 49 h underground; 0–2 % over other 36–48 h stretches | Negligible |

## Consumption and range

| Drive | Distance | SoC used | ≈ kWh/100 km (0.92 kWh/%) |
|---|---:|---:|---:|
| 2026-10-20, morning | 91 km | 17 % | 17 |
| 2026-10-23, evening | 92 km | 23 % | 23 |

Displayed range per 1 % SoC (monthly median, SoC ≥ 30 %): Mar 5.41 · Apr 5.53 · May 5.75 ·
Jun 5.97 · Jul 5.98 · Aug 5.55 · Sep 6.11 · **Oct 5.61 km/%**. Seasonal, no downward trend
(March vs October are similar). Expect another 10–20 % less through Dec–Feb, so the same overnight
grid target buys noticeably less range in winter.

## Charging behaviour

- **Home AC is slow by design:** median charge power ~2.0 kW, home peaks 2.1–3.3 kW. The 10 kW AC
  peaks in the data were away from home — the home pole is 1-phase, max 16 A (the car accepts
  11 kW 3-phase AC).
- The car models a **0.4 kW base load** while charging and 92 % efficiency. At ~2 kW that base load
  is a large share, consistent with ~0.93 kWh/% into the battery vs ~1.1 kWh/% at the wall. It is
  the price of following solar and staying under the capacity peak.
- **Many near-empty sessions:** 9 of 68 sessions added 0 %, ~15 more only 1–2 % — solar and
  `capacity_pause` stop/starts (e.g. 7 pauses in ~4 h on 2026-10-25).
- **Charging error 68 `APP_RBC_FailedByCpVoltage`** logged 2026-10-25 while the pole was paused by
  `capacity_pause`. "CP" is likely the control pilot, the pole↔car signalling line. The export only
  holds the latest error, so frequency is unknown — check whether the next export shows it again.
- **Battery care caps charging at 80 %**; sessions only went beyond it around trips.

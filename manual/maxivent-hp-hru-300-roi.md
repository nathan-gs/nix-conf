# Maxivent HP HRU 300 — impact & ROI assessment

*Analysis date: 2026-07-11. Based on live HA data.*

## Context

Evaluating replacement of the current **Itho Daalderop WTW** with a
[Maxivent by Econox HP HRU 300](https://www.ventilatieland.be/nl_BE/p/maxivent-by-econox-hp-hru-300-wtw-unit-met-geintegreerde-warmtepomp/35075/)
— a WTW unit with integrated heat pump that can actively heat and cool supply air,
and allows redistribution of airflow between floors.

---

## House baseline (from HA sensors)

### Room temperatures (July 1–11 average)

| Room | Avg | Max | Floor |
|------|-----|-----|-------|
| Living | 24.4°C | 26.1°C | 0 |
| Bureau | ~24.4°C | 25.9°C | 0 |
| Keuken | ~24.5°C | 26.6°C | 0 |
| Fen | 24.0°C | 26.1°C | 1 |
| **Nikolai** | **25.2°C** | **26.5°C** | 1 |
| **Morgane** | **25.2°C** | **26.7°C** | 1 |
| **Badkamer** | **25.4°C** | **27.2°C** | 1 |
| Basement | 23.5°C | 24.7°C | — |

Upper floor runs **0.8–1.0°C warmer on average, up to ~1.5°C warmer on hot days**.
All rooms are 5–8°C above comfort targets during a heatwave (outdoor peaked at 33°C).

### Current Itho WTW behaviour in summer

- `itho_wtw_is_summerday` ON 76% of days in July
- Bypass open 50% of the time (passive night cooling works)
- Fan set to **low** when outdoor ≥ 27°C — the automation correctly avoids drawing in hot air
- Current WTW power draw: avg 76W (range 10–134W)
- **On hot days the Itho has nothing to offer** — bypass closed, fan throttled, no active cooling

### Energy & tariffs

| | |
|---|---|
| Annual gas | 462 m³ = 4,879 kWh |
| Space heating gas | ~423 m³/yr = 4,459 kWh/yr (~€386/yr variable) |
| Summer baseline (DHW + cooking) | ~40 m³/yr |
| Gas cost (all-in variable) | €0.079/kWh = €0.913/m³ |
| Gas useful heat cost (at 85% boiler eff.) | **€0.093/kWh** |
| Electricity off-peak (energy component) | €0.145/kWh |
| Electricity all-in (realistic) | ~€0.21/kWh |
| Grid export price | **€0.040/kWh** |
| Annual grid export | **292 kWh/yr** (battery + car absorb almost all solar) |

The low export figure is critical: there is essentially no surplus solar to tap for
"free" cooling — the home battery and car charger consume it all.

---

## Maxivent HP HRU 300 — what it adds

### vs Itho (passive HRV only)

| Feature | Itho Daalderop | Maxivent HP HRU 300 |
|---------|---------------|---------------------|
| Heat recovery | ~90% | ~90% (same HRV part) |
| Active cooling | ✗ | ✓ (HP compressor) |
| Active heating | ✗ | ✓ (HP compressor) |
| Airflow per-room control | Fixed | Adjustable distribution |

### Summer cooling

At 300 m³/h, cooling supply air by 10°C delivers ~1.0 kW of sustained cooling.
At COP 3, that costs ~330W of electricity.

**Realistic effect:** slows temperature rise on hot days, shaves 1–2°C off indoor peak.
Not enough to fully prevent overheating when outdoor is 30°C+ (solar gain through windows
easily exceeds 3–5 kW), but meaningful for **overnight comfort in bedrooms**.

Redirecting more flow to the upper floor targets Nikolai and Morgane directly,
addressing the 0.8–1°C structural gradient.

Electricity cost for summer cooling: ~180 kWh/yr electrical input at COP 3 → ~€28/yr
(mostly competing with car charging, not surplus solar).

### Winter heating — corrected COP analysis

The HP uses warm exhaust air (~18–20°C) as its heat source — better than outdoor air
in winter, giving a higher COP than a typical air-to-air heat pump.

| | Gas boiler | HP HRU 300 |
|--|--|--|
| Useful heat cost | €0.093/kWh (€0.079 / 85%) | €0.066/kWh (€0.21 / 3.2) |
| Saving per kWh switched | — | **€0.027/kWh** |

HP is constrained by exhaust air flow (~150 m³/h effective average, extracting
~6°C from post-HRV exhaust) → **~440W max HP heat output**.

| Scenario | Annual HP heat | Gas saved | Elec cost | Net saving |
|---|---|---|---|---|
| Low (45% util.) | 864 kWh | €80/yr | €57/yr | **+€23/yr** |
| **Mid (65%)** | **1,249 kWh** | **€116/yr** | **€82/yr** | **+€34/yr** |
| High (85%) | 1,633 kWh | €151/yr | €107/yr | **+€44/yr** |

Mid estimate covers **~28% of annual space heating load**.

### Full ROI

| | |
|---|---|
| Estimated installed cost | ~€4,700 |
| vs replacing Itho with standard HRV | ~€2,000 |
| Incremental cost of HP feature | ~€2,700 |
| Net winter heating saving (mid) | +€34/yr |
| Summer cooling electricity cost | −€28/yr |
| **Net annual** | **~+€6/yr** |
| **Payback (total)** | **~800 years** |
| **Payback (incremental over HRV)** | **~450 years** |

**Why the ROI is weak despite correct COP:**
1. The HP is ventilation-sized — limited to ~440W by exhaust air volume, not a
   full house-sized heat pump.
2. Belgian gas is cheap — only a 29% cost advantage per kWh over the boiler.
3. Summer cooling is a net electricity cost, not a saving (no surplus solar to use).

> **Note:** If the Maxivent HP HRU 300 can also feed heat into a hydronic water
> circuit (buffer tank / boiler loop), this breaks the air-flow constraint and the
> heating numbers improve significantly. Worth checking the product specs.

---

## Comparison: dedicated split AC (2× 2.5 kW)

For Nikolai + Morgane bedrooms (the measured problem rooms).

| | HP HRU 300 | 2× Split AC |
|---|---|---|
| Investment | ~€4,700 | ~€3,000 |
| Net heating saving/yr | +€34 | +€62 (if used for bedroom heating, COP 4.2) |
| Cooling electricity cost | −€28/yr | −€34/yr |
| **Net annual** | **+€6/yr** | **+€28/yr** |
| **Payback** | **~800 yrs** | **~107 yrs** |
| Cooling power | 1–1.5 kW (all rooms) | 5 kW (2.5 kW/room) |
| Heating gas replaced | ~28% | ~10–15% (bedrooms only) |

Split AC wins on payback because:
- Higher COP in heating (4.2 vs 3.2) — not limited by exhaust air volume
- Delivers 2.5 kW per room on demand vs 1–1.5 kW total through ducts
- Lower upfront cost
- Can be used selectively (only when someone is in the room)

HP HRU 300 wins on:
- No visible indoor units
- Whole-house air distribution / quality
- One integrated system (no separate outdoor compressors per room)
- Makes more sense if the Itho is due for replacement anyway (€2,700 incremental)

---

## Conclusion

**Neither option has a meaningful financial ROI** — Belgian climate means cooling is
used ~40–60 days/year, and neither system pays back on energy alone.

The decision reduces to **comfort per euro**:
- If sleep comfort in the kids' bedrooms on hot nights is the goal: **split AC is
  better value** — more powerful, cheaper, faster.
- If aesthetics (no wall units) or whole-house air distribution matter, and the Itho
  needs replacing anyway: the **HP HRU 300 incremental cost (~€2,700) is more
  defensible**, even though pure financial ROI remains poor.

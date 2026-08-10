# Dynamic tariff analysis (Belgium)

**Date:** 2026-06-26 (revised 2026-08-10)  
**Question:** Does switching to a dynamic (Belpex-indexed hourly) electricity tariff make sense? Evaluated against the current Solis hybrid setup and the [[battery-expansion-analysis|expanded battery scenario]].

Solis control details: [[solis-steering]].

## Inputs

Actual current rates (from `sensor.electricity_cost_*` / `tariffs.nix`). Energy-component inputs are **VAT-inclusive**; network/tax line items sum with them to all-in €/kWh (ex monthly fixed):

- **Peak rate (07:00–22:00 weekdays):** €0.29717/kWh
  - Energy component: €0.1818
  - Network + tax: €0.1154
- **Offpeak rate (22:00–07:00 + weekends):** €0.26057/kWh
  - Energy component: €0.1452
  - Network + tax: €0.1154
- **Injection (Engie Drive):** €0.0404/kWh (CREG reference €0.3191/kWh — used for the prosumer regulated tariff calc, not actual payout)
- **Monthly fixed:** €20.62/mo = **€247/yr** (abonnement, capacity tariff, prosumer fee, etc.)
- **Car:** 100 kWh battery; ~10 kWh needed on a typical away day, occasional 40 kWh jumps. Rarely fully charged.
- **Home presence:** ~50%; when away, car charges later from home (overnight) or grid/public at €0.30/kWh
- **Current battery:** Solis hybrid + battery (~10 kWh, [[battery-expansion-analysis]] for context). [[battery-expansion-analysis|Expansion]]: +4.5 kWh for €1000.
- **House:** electric auxiliary heating exists (non-shiftable winter load when battery is empty).

The €0.1154/kWh network component is **identical for peak and offpeak**, confirming network costs are hour-independent today — they pass through unchanged to a dynamic tariff.

## Measured consumption profile (last 365 days)

> **Caveat: history is distorted by the recent EV switch.** A full EV replaced hybrid cars in March 2026. Months before that reflect PHEV charging (much smaller battery + occasional grid pulls), not the current EV profile. Post-EV data (Mar–Jun 2026) is only 4 months and skewed to spring/summer. Forward projection requires extrapolating winter EV charging.

### Annual totals (rolling 365d, mixed pre/post-EV)

| Flow                | kWh/yr |
|---------------------|--------|
| Solar production    | 4 905  |
| Grid import         | 4 665  |
| Grid export         | 542    |
| **Self-consumption ratio** | **89%** |
| Car charging (from grid) | 3 954 |
| House grid import (= total − car) | ~711 |

### Post-EV only (Mar–Jun 2026, 118 days)

| Flow                | 4-mo kWh | Implied annual rate at this season |
|---------------------|----------|------------------------------------|
| Grid import         | 1 339    | ~4 140 (linear, no winter scaling) |
| Grid export         | 230      | ~710                               |
| % of import 00–09h  | **71%**  | (vs 55% pre-EV mixed)              |

The post-EV profile is **even more concentrated overnight** (71% in 00–09h) — the EV is the dominant driver.

### Forward-looking annual import estimate (full EV-year)

Winter EV charging is much higher than spring/summer because:
- Less solar → most charging from grid
- Cold reduces EV range → more kWh per km driven
- Cabin heating draws from battery

Estimate by season:

| Season                   | kWh/mo (est.) | Months | Total  |
|--------------------------|---------------|--------|--------|
| Spring (Mar–May)         | ~350          | 3      | 1 050  |
| Summer (Jun–Aug)         | ~175          | 3      | 525    |
| Autumn (Sep–Nov)         | ~450          | 3      | 1 350  |
| Winter (Dec–Feb)         | ~900          | 3      | 2 700  |
| **Total forward annual** |               |        | **~5 600** |

Forward winter ~900 kWh/mo is a **guess** (historical peak Dec/Jan ~650 with PHEV; full EV + cold + less PV + electric heat could land ~650–900). Cost tables below use **5 600 kWh** as the central case; treat ±15% as the uncertainty band until a full EV winter is measured.

### Monthly grid flows (2025-06 → 2026-06)

| Month   | Import (kWh) | Export (kWh) |
|---------|--------------|--------------|
| 2025-06 | 9            | 1            |
| 2025-07 | 132          | 130          |
| 2025-08 | 186          | 131          |
| 2025-09 | 315          | 25           |
| 2025-10 | 462          | 4            |
| 2025-11 | 512          | 2            |
| 2025-12 | 657          | 2            |
| 2026-01 | 646          | 2            |
| 2026-02 | 403          | 16           |
| 2026-03 | 435          | 25           |
| 2026-04 | 442          | 86           |
| 2026-05 | 277          | 35           |
| 2026-06 | 189          | 84           |

**Winter dominates grid exposure:** Nov–Feb = 2 218 kWh = 48% of annual import. Summer months are nearly self-sufficient.

### Hourly grid-import profile (annual sum by hour-of-day)

| Hour | kWh/yr | Hour | kWh/yr |
|------|--------|------|--------|
| 00   | 288    | 12   | 110    |
| 01   | 382    | 13   | 84     |
| 02   | 398    | 14   | 81     |
| 03   | 401    | 15   | 73     |
| 04   | 389    | 16   | 66     |
| 05   | 373    | 17   | 61     |
| 06   | 351    | 18   | 59     |
| 07   | 293    | 19   | 55     |
| 08   | 241    | 20   | 97     |
| 09   | 197    | 21   | 123    |
| 10   | 159    | 22   | 121    |
| 11   | 143    | 23   | 120    |

Heavy concentration in **00:00–07:00** (2 575 kWh = 55% of import) — clearly night-time car charging. Daytime (10:00–17:00) is light because solar+battery cover the house.

### Hourly export profile (annual sum by hour-of-day)

Peaks 14:00–19:00 (cluster of ~400 kWh/yr), near zero at night. The 542 kWh/yr total is small because the battery absorbs most surplus.

## Belgian dynamic tariff context

Belgian dynamic suppliers (Engie Dynamic, Octa+ Dynamic, TotalEnergies Pulse Flex) pass through the **EPEX Belpex day-ahead hourly price** + a small markup + monthly subscription.

Final delivered price per kWh = `(belpex + supplier_markup + network_costs) × (1 + VAT)`

Typical 2025 components (residential, Flanders):

- **Belpex hourly:** annual avg ~€0.07/kWh, but highly time-varying:
  - Night (00–06): ~€0.05/kWh
  - Morning ramp (06–09): ~€0.10/kWh
  - Solar midday (10–15): ~€0.02/kWh (occasionally negative)
  - Afternoon (15–17): ~€0.06/kWh
  - **Evening peak (17–21): ~€0.13/kWh**
  - Late evening (21–24): ~€0.08/kWh
- **Supplier markup + abonnement:** ~€0.025/kWh energy markup + ~€5–7/month fixed
- **Network costs (Fluvius distribution + Elia transmission + taxes):** **€0.1154/kWh** (measured from your actual rates — peak − energy = offpeak − energy)
- **VAT:** 6% on energy component
- **Capacity tariff:** monthly peak power (15-min) charge, ~€45/kW/yr — unchanged by dynamic, but punishes concentrated car-charging power

## Cost comparison

### Current dual-tariff cost (forward EV year, 5 600 kWh)

Split assumption: with 71% of import during 00:00–09:00 (mostly offpeak) and most of the rest at weekends/evenings → assume **~85% offpeak, 15% peak** for the EV year.

| Register | kWh/yr | €/kWh   | Cost   |
|----------|--------|---------|--------|
| Offpeak  | 4 760  | €0.26057| €1 240 |
| Peak     | 840    | €0.29717| €250   |
| **Energy variable** | **5 600** | | **€1 490** |
| Monthly fixed | | | €247 |
| **Total current contract** | | | **€1 737/yr** |

### Dynamic tariff cost (forward EV year, 5 600 kWh)

Applied measured hourly import shape to an **annual** Belpex price profile:

| Window      | % of import (post-EV) | Avg Belpex |
|-------------|-----------------------|------------|
| 00–09       | 71%                   | €0.06      |
| 09–17       | 14%                   | €0.04      |
| 17–21       | 6%                    | €0.13      |
| 21–24       | 9%                    | €0.08      |

**Belpex-weighted average: ~€0.065/kWh** (optimistic if winter is not re-weighted — see below).

Delivered price under dynamic (commodity excl→incl VAT; network slice matched to all-in sensors):

| Component         | €/kWh   |
|-------------------|---------|
| Belpex (wtd avg)  | 0.065   |
| Supplier markup   | 0.025   |
| × VAT 1.06        | 0.0954  |
| + Network (fixed) | 0.1154  |
| **Delivered**     | **€0.211/kWh** |

| | Current dual | Dynamic (optimistic annual Belpex) |
|--|--------------|-------------------------------------|
| Energy variable | €1 490 | 5 600 × €0.211 = **€1 182** |
| Fixed / abonnement | €247 | ~€220 (placeholder — verify supplier) |
| **Total** | **€1 737** | **€1 402** |
| **Delta** | | **~€335/yr** (of which ~€308 energy, ~€27 fixed) |

**What that €308 energy gap actually is:** mostly a **cheaper commodity at the hours you already use** (you are already ~85% offpeak / night-heavy), not a large “schedule shift” win. True smart-shift value is the **extra** from avoiding 06–09 ramp and 17–21 peak, and catching weekend midday (especially non-winter). Do not over-attribute savings to automation effort.

Export side: 542 kWh/yr × ~€0.03 = ~€16/yr current; dynamic export ≈ Belpex when sun shines ≈ €0.02 → ~€11/yr. Slight loss (~€5/yr), trivial.

### Winter caveat: high kWh × high Belpex

~48% of historical annual import lands Nov–Feb. 2025 Belgium day-ahead monthly averages were roughly **€0.11–0.13/kWh in Jan–Feb** vs **~€0.06 in May** (year average ~€0.083) — well above the €0.065 night-heavy blend used above.

If consumption-weighted Belpex is closer to **€0.08–0.09**:

- Delivered ≈ **€0.23–0.24/kWh**
- Energy variable on 5 600 kWh ≈ **€1 290–1 340**
- Energy savings vs dual shrink toward **~€150–200/yr** before capacity-tariff drag

Cold-snap weeks can temporarily **exceed** dual-tariff energy rates exactly when EV + heat import peaks. Fixed tariffs hedge that correlation risk; dynamic does not. Shoulder/summer (and negative-price hours, mostly Mar–Sep) carry much of the annual dynamic win.

**Honest central band for contract-only savings:** ~**€150–300/yr** depending on winter severity and fixed-charge delta — still usually positive with this load shape, but not a guaranteed €335.

At high winter daily kWh, capacity-aware charging (~3 kW class, [[ev-battery-peak-coordination]] / [[car-charging-analysis]]) needs **many night hours**, so you cannot sit only in the absolute cheapest 02:00–04:00 band; morning-ramp Belpex exposure rises in winter.

---

## With battery arbitrage

Battery **TOU arbitrage** (grid charge cheap hours → cover evening load / avoid peak Belpex) is separate from solar storage. It mainly makes sense in **winter** (Nov–Feb, ~120 days/yr) when PV does not fill the pack.

Full control reference: [[solis-steering]].

### Per-cycle value (when grid cycling works)

Round-trip efficiency: ~90% (LiFePO4 + inverter)

Illustrative night→evening spread (annual averages — winter spreads and levels differ):

- Charge: Belpex €0.05 + markup €0.025 + network €0.1154 + VAT on commodity ≈ €0.20/kWh delivered order of magnitude  
- Discharge (avoided buy): evening Belpex higher → roughly **€0.05–0.07/kWh net** after losses in a good year  

### How Solis actually steers (corrected)

| Mechanism | Role | Live plant (2026-08) | Arbitrage use |
|-----------|------|----------------------|---------------|
| **Forcecharge SOC** (CID 160, max **~39%**) | Grid *heal* when SoC hits a floor | **9%** | Only fills up toward overdischarge floor — **not** “charge to 40% every night” |
| **Overdischarge SOC** (CID 158, max **40%**) | Discharge floor | **15%** | Keep ≥ force-charge; HA holds ~15–20% ([[ev-battery-peak-coordination]]) |
| **Max grid power when force charging** (CID 9020) | Cap W from grid during heal | **300 W** | Very slow; not an arbitrage fill |
| **Allow Grid Charging** (CID 109, bit 5 of 43110) | Permit grid → battery | **OFF** | **Must enable** for TOU grid fill |
| **TOU + schedule** (CID 543 on; **4643** slots) | Charge/discharge time windows | Self-use + TOU on; schedule TBD | **Real arbitrage path** |

`solis-control` already writes 158 / 160 / max-grid-power. It does **not** yet implement 109 or 4643 (109 needs read-then-set `yuanzhi`). The script also **self-caps force-charge at 20%** even though the UI allows ~39%.

**Force-charge is not full-pack arbitrage.** With live 9% → 15% band ≈ **~0.6 kWh** on a 10 kWh pack at 300 W — negligible €/yr.

### Two arbitrage cases

#### A. Status quo (force-charge floors only, no TOU grid fill)

- ~€0–15/yr (heal band only)  
- Dynamic case rests on **EV commodity + timing**, not house battery  

#### B. TOU grid charge enabled (Allow Grid Charging + 4643 windows)

Assumes winter nights charge a useful fraction of the pack (subject to Max Charge SOC, capacity tariff, and EV sharing night headroom):

| | Current ~10 kWh | Extended 14.5 kWh |
|--|-----------------|-------------------|
| Winter cycles (order of magnitude) | ~5–8 kWh × 100–120 nights if allowed | more headroom |
| Rough €/yr at ~€0.06/kWh net | **~€40–60** | **~€55–90** |

These are **upper-bound sketches** until 109+4643 are implemented and measured. They replace the old “30% of pack via force-charge” model, which mixed up setpoints.

Full-pack cycling every winter night is still constrained by: capacity tariff, EV overnight charge, and residual evening house load (incl. electric heat).

### Negative pricing days

Belgium had **500+** negative day-ahead hours in 2025 (mostly Mar–Sep, often weekend midday). Battery + EV can soak some of that; winter capture is small. Value ~€10–40/yr depending on automation and export rules — do not count on winter negatives.

## Total annual benefit summary

Forward EV import **~5 600 kWh/yr** central case.

| | Status quo Solis control | After TOU grid-charge (109 + 4643) |
|--|--------------------------|-------------------------------------|
| Dynamic vs dual (contract) | **€150–300** (winter-weighted) / up to ~€335 if annual Belpex holds | same |
| Battery arbitrage | ~€0–15 | **~€40–90** (sketch) |
| Negative price capture | ~€10–25 | ~€15–40 |
| **Combined (order of magnitude)** | **~€160–340** | **~€200–430** |

**Implications for [[battery-expansion-analysis]]:**

- Expansion still stands primarily on **solar capture** (~€140/yr, ~7 yr payback).  
- Dynamic TOU grid-charge adds **some** marginal winter value to extra kWh; not enough alone to flip the expansion decision.  
- Unlocking 109+4643 helps the dynamic case more than raising force-charge from 20% → 39%.

## Risks and caveats

1. **Belpex volatility / winter correlation.** 2022 crisis and harsh winters (e.g. early 2025) raise dynamic bills when import is highest.
   - **Mitigation:** Most Belgian dynamic contracts allow switching back to fixed with ~1 month notice. Simulate through a winter before locking in.

2. **Capacity tariff penalty.** Concentrating car (and battery) charging into cheapest hours spikes the 15-min peak → €5–15/month possible.
   - **Mitigation:** ~3 kW class car charge, spread hours, peak coordination already in tree ([[ev-battery-peak-coordination]]). Battery TOU charge must share the same peak budget.

3. **Automation.** Needs:
   - Belpex (or ENTSO-E / Nordpool) sensors  
   - Car charge on N cheapest hours within capacity cap  
   - Solis: enable **Allow Grid Charging** + **4643** TOU slots in winter ([[solis-steering]]); keep force-charge as floor only  
   - Do not enable feed-in priority mode for this use case  

4. **Future tariff regime.** Time-varying network charges or tighter capacity rules would shrink the dynamic edge.

5. **Subscription/abonnement.** Verify actual dynamic supplier standing charges; €220 vs €247 is a placeholder.

6. **Rates / VAT.** HA electricity rates are all-in (VAT in energy component). Dynamic model applies 6% VAT to Belpex+markup only, then adds the same network slice — consistent enough for comparison; re-check against a real dynamic quote.

## Verdict

**Still lean switch to dynamic**, with tempered expectations:

- **Bulk of the win is EV-shaped night import** meeting a lower average commodity than dual-tariff energy components — you are already offpeak-heavy; automation polishes, it does not create most of the € gap.  
- **Winter is the stress test**, not free upside: more kWh at higher Belpex; capacity-aware multi-hour charging; electric heat. Expect **€150–300/yr** contract savings in a realistic year, not a locked €335.  
- **House battery arbitrage is small until Solis TOU grid-charge is wired** (109 + 4643). Force-charge max ~40% is a **heal ceiling**, not the main arbitrage lever; live heal band is tiny. Details: [[solis-steering]].  
- **Battery expansion** remains a solar-capture decision ([[battery-expansion-analysis]]); dynamic does not make or break it.  
- **Highest-leverage Solis follow-ups:** implement Allow Grid Charging + TOU schedule in `solis-control`; optional raise force-charge script max to UI 39% only if useful for floors.  
- **Payback:** instantaneous on supplier switch (no capex); reversible.

Main downside remains exposure to price-spike winters. Asymmetric risk still favours **simulating first**, then switching.

## Recommended action sequence

1. **Belpex / ENTSO-E sensor in HA** — run in parallel with dual tariff (shadow bill).  
2. **Prefer a window that includes winter months** for the shadow comparison (3 sunny months overstate savings).  
3. **Automations (sim first):**
   - Car: N cheapest hours, capacity-capped ([[ev-battery-peak-coordination]])  
   - Solis: wire **CID 109** + **4643** ([[solis-steering]]); leave force-charge as floor  
4. **Switch supplier** if shadow bill confirms. Belgian switches are free and take ~3 weeks.

## SQL queries used

```sql
-- Annual import/export per tariff register
WITH meter AS (
  SELECT metadata_id, FROM_UNIXTIME(start_ts) AS ts, state
  FROM statistics
  WHERE metadata_id IN (1,2,3,4) AND start_ts > UNIX_TIMESTAMP() - 365*86400
),
diffs AS (
  SELECT metadata_id, state - LAG(state) OVER (PARTITION BY metadata_id ORDER BY ts) AS kwh FROM meter
)
SELECT m.statistic_id, ROUND(SUM(d.kwh),0) AS kwh_yr
FROM diffs d JOIN statistics_meta m ON m.id = d.metadata_id
WHERE d.kwh BETWEEN 0 AND 20 GROUP BY m.statistic_id;

-- Hourly grid import profile (annual, summed across both registers)
WITH d AS (
  SELECT FROM_UNIXTIME(start_ts + 7200) AS ts, state AS cum
  FROM statistics WHERE metadata_id IN (1,3) AND start_ts > UNIX_TIMESTAMP() - 365*86400
),
agg AS (
  SELECT DATE(ts) AS d, HOUR(ts) AS h, SUM(cum) AS total_cum FROM d GROUP BY d, h
),
diffs AS (
  SELECT d, h, total_cum - LAG(total_cum) OVER (ORDER BY d, h) AS kwh FROM agg
)
SELECT h AS hour, ROUND(SUM(kwh),1) AS total_kwh
FROM diffs WHERE kwh BETWEEN 0 AND 20 GROUP BY h ORDER BY h;

-- Monthly import/export
WITH meter AS (
  SELECT metadata_id, FROM_UNIXTIME(start_ts + 7200) AS ts, state
  FROM statistics WHERE metadata_id IN (1,2,3,4) AND start_ts > UNIX_TIMESTAMP() - 365*86400
),
diffs AS (
  SELECT metadata_id, ts, state - LAG(state) OVER (PARTITION BY metadata_id ORDER BY ts) AS kwh FROM meter
)
SELECT DATE_FORMAT(ts,'%Y-%m') AS mo,
       ROUND(SUM(CASE WHEN metadata_id IN (1,3) AND kwh BETWEEN 0 AND 20 THEN kwh ELSE 0 END),0) AS import_kwh,
       ROUND(SUM(CASE WHEN metadata_id IN (2,4) AND kwh BETWEEN 0 AND 20 THEN kwh ELSE 0 END),0) AS export_kwh
FROM diffs GROUP BY mo ORDER BY mo;
```

DSMR metadata_id reference (from `statistics_meta`):
- 1 = `sensor.dsmr_reading_electricity_delivered_1` (import register 1)
- 2 = `sensor.dsmr_reading_electricity_returned_1` (export register 1)
- 3 = `sensor.dsmr_reading_electricity_delivered_2` (import register 2)
- 4 = `sensor.dsmr_reading_electricity_returned_2` (export register 2)
- 191 = `sensor.solar_delivery_daily`
- 217 = `sensor.solis_remaining_battery_capacity`

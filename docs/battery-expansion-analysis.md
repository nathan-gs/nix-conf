# Battery expansion analysis

**Date:** 2026-06-26
**Question:** Does it make sense to add 4.5 kWh of battery storage to the existing Solis hybrid setup?

## Inputs

- **Offer:** €1000 for 4.5 kWh (≈ €222/kWh installed)
- **Grid price:** €0.25/kWh
- **Car charging away from home:** €0.30/kWh
- **Injection tariff:** €0.03/kWh, trending toward €0 or negative
- **Home presence:** ~50% of the time; when away, car charges later from grid/public at €0.30
- **Smart loads already maxed:** washer/dishwasher/DHW scheduled around solar peak
- **PV cannot be expanded:** 2 strings used, second inverter would exceed 5 kW limit of 1-phase Belgian meter
- **Car battery rarely full** → guaranteed sink for any stored surplus

## Data (HA recorder, MariaDB `hass` DB, 2023-03-29 → 2026-06-26)

### Daily PV production (`sensor.solar_delivery_daily`, metadata_id=191)

- 347 days >20 kWh total (~108/yr)
- Per-year: 2023=115, 2024=76, 2025=103, 2026=53 YTD
- Peak production days cap around high-20s kWh (no 30+ kWh days observed)

### Battery fill-rate by production tier (`sensor.solis_remaining_battery_capacity`, metadata_id=217)

| Production tier | Days | Days battery hit ≥98% | % full |
|-----------------|------|-----------------------|--------|
| 20–30 kWh       | 349  | 271                   | 77.7%  |
| 10–20 kWh       | 450  | 213                   | 47.3%  |
| <10 kWh         | 387  | 16                    | 4.1%   |

### Time spent at ≥98% SoC (clipping window)

| Production tier | Days w/ clipping | Avg hrs at full | Avg prod (kWh) |
|-----------------|------------------|-----------------|----------------|
| 25+ kWh         | 61               | 5.5             | 26.6           |
| 20–25 kWh       | 181              | 4.0             | 22.5           |
| 15–20 kWh       | 116              | 3.8             | 17.7           |
| <15 kWh         | 85               | 3.0             | 12.1           |

Interpretation: on big days the battery sits at 100% for 4–5.5 hours — substantial surplus is being exported that could be captured.

## Cycle estimate for an extra 4.5 kWh

| Tier   | Days/yr (w/ clipping) | Effective full cycles of +4.5 kWh |
|--------|-----------------------|-----------------------------------|
| 25+    | 19                    | 19                                |
| 20–25  | 56                    | ~50                               |
| 15–20  | 36                    | ~25 (partial)                     |
| <15    | 26                    | ~8                                |
| **Total** |                    | **~115/yr** (car-as-sink bumps from baseline 100) |

## Economics

- Net value per stored kWh = €0.30 (avoided car charging) − €0.03 (lost injection) = **€0.27/kWh**
- Year-1: 115 × 4.5 × €0.27 = **€140/yr**
- With grid +3%/yr real and injection → €0: 10-yr average ≈ €0.30/kWh → **€155/yr**
- **Payback: ~7 years**
- NPV at 3% discount over 10 years: **~€+250**

If injection becomes negative (curtailment fees), every retained kWh is double-value (avoided buy + avoided sell-penalty), further improving the case.

## Verdict: **buy it**

Borderline-positive NPV, asymmetric upside given Belgian policy direction (capacity tariff, dropping injection value, rising grid prices, no PV expansion possible).

## Caveats before committing

1. **LiFePO4 cells** (not NMC or lead-acid) with **≥10-year cell warranty**. At €222/kWh you cannot absorb early BMS/cell failure.
2. **Check inverter charge-rate headroom.** Solis hybrid charge current limits matter — if it pushes ~2 kW max into battery, filling the extra 4.5 kWh needs ~2 more hours of solar+charge headroom. Already implicit in the 115 cycles/yr estimate, but worth confirming the inverter isn't the bottleneck.
3. **DIY alternative:** LiFePO4 at €150/kWh (~€675 for 4.5 kWh) drops payback to ~5 years — clear win if you have appetite for self-install.

## Note (2026-08-20): charge/discharge current cap affects the headroom caveat above

`number.system_house_pv_max_charge_current` / `max_discharge_current` /
`battery_max_charge_current` / `battery_max_discharge_current` (registers 43012/43013/43117/43118)
were lowered from the default **100 A to 87 A** — Pylontech's own recommended combined continuous
rate (0.5C) for this pack (US5000 50 A + US3000C 37 A), done for battery-health reasons, not
capacity planning. See `docs/solis-modbus.md`.

This directly affects caveat #2 above (inverter charge-rate headroom). If re-running this
analysis — e.g. sizing a future expansion — **set these back to 100 A first**, since the current
115 cycles/yr estimate implicitly assumed the higher charge rate. Recalculate headroom against
whatever combined recommended rate applies to the pack size under consideration at that time
(0.5C scales with total capacity), not against 87 A, which is specific to today's US5000+US3000C
combo.

## SQL queries used

```sql
-- Days with >20 kWh production
SELECT COUNT(*) FROM (
  SELECT DATE(FROM_UNIXTIME(start_ts + 7200)) AS d, MAX(state) AS daily_max
  FROM statistics WHERE metadata_id=191 GROUP BY d
) t WHERE daily_max > 20;

-- Battery-full rate by production tier
WITH soc_daily AS (
  SELECT DATE(FROM_UNIXTIME(start_ts + 7200)) AS d, MAX(max) AS peak_soc
  FROM statistics WHERE metadata_id=217 GROUP BY d
),
solar_daily AS (
  SELECT DATE(FROM_UNIXTIME(start_ts + 7200)) AS d, MAX(state) AS kwh
  FROM statistics WHERE metadata_id=191 GROUP BY d
)
SELECT
  CASE WHEN sd.kwh >= 20 THEN '20+ kWh'
       WHEN sd.kwh >= 10 THEN '10-20 kWh'
       ELSE '<10 kWh' END AS production,
  COUNT(*) AS days,
  SUM(CASE WHEN so.peak_soc >= 98 THEN 1 ELSE 0 END) AS days_battery_full
FROM solar_daily sd JOIN soc_daily so USING(d)
GROUP BY production;

-- Hours/day at ≥98% SoC by production tier
WITH solar_daily AS (
  SELECT DATE(FROM_UNIXTIME(start_ts + 7200)) AS d, MAX(state) AS kwh
  FROM statistics WHERE metadata_id=191 GROUP BY d
),
soc_full_hours AS (
  SELECT DATE(FROM_UNIXTIME(start_ts + 7200)) AS d,
         SUM(CASE WHEN mean >= 98 THEN 1 ELSE 0 END) AS hrs_full
  FROM statistics WHERE metadata_id=217 GROUP BY d
)
SELECT
  CASE WHEN sd.kwh >= 25 THEN '25+ kWh'
       WHEN sd.kwh >= 20 THEN '20-25 kWh'
       WHEN sd.kwh >= 15 THEN '15-20 kWh'
       ELSE '<15 kWh' END AS production,
  COUNT(*) AS days,
  AVG(sf.hrs_full) AS avg_hrs_at_full,
  AVG(sd.kwh) AS avg_prod_kwh
FROM solar_daily sd JOIN soc_full_hours sf USING(d)
WHERE sf.hrs_full > 0
GROUP BY production;
```

Note: `start_ts + 7200` shifts UTC into CEST for local-day grouping (good enough; CET months will be off by 1 hour but doesn't affect daily aggregates meaningfully).

## Re-run (2026-08-23): real quote for a 2nd US5000-1C + US3000C set

A concrete quote came in for **another** US5000-1C + US3000C pair — i.e. doubling the existing pack
([[battery_pack_expansion]] added the first US5000+US3000C in 2024-09/10), not the generic
"4.5 kWh at €1000" placeholder the original analysis above was scoped around.

### Quote

| Line item        | Amount     |
|-------------------|-----------|
| Subtotaal          | €1,312.00 |
| Bebat-bijdrage      | €196.52   |
| Verzendkosten       | €75.00    |
| 21% BTW             | €332.54   |
| **Geschat totaal**  | **€1,916.06** |

### Capacity added (Pylontech datasheets)

| Module | Nominal | Usable (~95%) |
|--------|---------|---------------|
| US5000-1C | 4.80 kWh | 4.56 kWh |
| US3000C   | 3.55 kWh | 3.37 kWh |
| **Total**     | **8.35 kWh** | **7.93 kWh** |

Cost per kWh: **€229.5/kWh nominal**, **€241.6/kWh usable** — pricier than the original €222/kWh
scenario, and for ~1.85x the capacity.

### Why the original cycle model doesn't scale linearly to this size

The original methodology (hours/day at ≥98% SoC × avg production) is a proxy for "battery was full,
so there was surplus" — it doesn't say *how much* surplus, which matters a lot once the addition is
this much bigger than the original 4.5 kWh scenario. Queried actual grid export instead
(`sensor.system_house_pv_total_energy_fed_into_grid`, metadata_id=1561, `sum` column), restricted to
**since the current pack was installed** (2024-10-01 onward) so it reflects export that still
happens *after* today's existing 7.93 kWh usable pack is already full — i.e. the real ceiling on what
more capacity could capture:

| Production tier | Days | Avg export (kWh) | Total export (kWh) |
|------------------|------|-------------------|----------------------|
| 25+ kWh          | 22   | 4.36              | 96.0                 |
| 20–25 kWh        | 174  | 3.37              | 587.0                |
| 15–20 kWh        | 131  | 2.20              | 288.0                |
| 10–15 kWh        | 118  | 0.66              | 78.0                 |
| <10 kWh          | 244  | 0.05              | 11.0                 |
| **Total**        | 689  |                   | **1,060 kWh** over 692 days |

→ **~559 kWh/yr** is currently exported *even with the existing pack already installed*. That's the
hard upper bound on what a second US5000+US3000C set could realistically capture (charge-current
headroom isn't the binding constraint here, since this export only happens once the existing battery
is already full — the charge circuit was already busy filling it up to that point).

### Economics

- Net value per captured kWh: same €0.27/kWh as original (€0.30 avoided car charging − €0.03 lost injection)
- Year-1: 559.5 × €0.27 = **€151/yr**
- 10-yr average (grid +3%/yr, injection → €0, ≈€0.30/kWh): 559.5 × €0.30 = **€168/yr**
- **Simple payback: ~11–13 years**
- NPV at 3% discount over 10 years (annuity factor 8.53 × €168 = €1,433 vs €1,916.06 cost): **≈ −€480**

### Verdict: **don't buy this specific set at this price**

Doubling the pack runs straight into diminishing returns: the first expansion ([[battery_pack_expansion]])
captured the easy clipping days, so a second identical set is chasing a shrinking tail of already-reduced
export. Combined with a slightly higher €/kWh price than the original offer, this doesn't clear a
reasonable bar — negative 10-yr NPV, payback nearly double the household's other financial planning horizon.
A smaller/cheaper addition (or waiting for injection tariffs to go more negative, which raises the
€0.27/kWh spread) would change the math; this exact quote, at this size, does not.

### Additional SQL query used

```sql
-- Grid export by production tier, since current pack install (2024-10-01)
WITH solar_daily AS (
  SELECT DATE(FROM_UNIXTIME(start_ts + 7200)) AS d, MAX(state) AS kwh
  FROM statistics WHERE metadata_id=191 AND start_ts >= UNIX_TIMESTAMP('2024-10-01') GROUP BY d
),
inj_daily AS (
  SELECT DATE(FROM_UNIXTIME(start_ts + 7200)) AS d, (MAX(sum)-MIN(sum)) AS inj_kwh
  FROM statistics WHERE metadata_id=1561 AND start_ts >= UNIX_TIMESTAMP('2024-10-01') GROUP BY d
)
SELECT
  CASE WHEN sd.kwh >= 25 THEN '25+ kWh'
       WHEN sd.kwh >= 20 THEN '20-25 kWh'
       WHEN sd.kwh >= 15 THEN '15-20 kWh'
       WHEN sd.kwh >= 10 THEN '10-15 kWh'
       ELSE '<10 kWh' END AS production,
  COUNT(*) AS days,
  ROUND(AVG(inj.inj_kwh),2) AS avg_export_kwh,
  ROUND(SUM(inj.inj_kwh),1) AS total_export_kwh
FROM solar_daily sd JOIN inj_daily inj USING(d)
GROUP BY production
ORDER BY production DESC;
```

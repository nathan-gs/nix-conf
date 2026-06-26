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

# Dynamic tariff analysis (Belgium)

**Date:** 2026-06-26
**Question:** Does switching to a dynamic (Belpex-indexed hourly) electricity tariff make sense? Evaluated against the current Solis hybrid setup and the [[battery-expansion-analysis|expanded battery scenario]].

## Inputs

Actual current rates (from `sensor.electricity_cost_*` template sensors, all kWh-inclusive of network costs but excluding the monthly fixed):

- **Peak rate (07:00–22:00 weekdays):** €0.29717/kWh
  - Energy component: €0.1818
  - Network + tax + VAT: €0.1154
- **Offpeak rate (22:00–07:00 + weekends):** €0.26057/kWh
  - Energy component: €0.1452
  - Network + tax + VAT: €0.1154
- **Injection (Engie Drive):** €0.0404/kWh (CREG reference €0.3191/kWh — used for the prosumer regulated tariff calc, not actual payout)
- **Monthly fixed:** €20.62/mo = **€247/yr** (abonnement, capacity tariff, prosumer fee, etc.)
- **Car:** 100 kWh battery; ~10 kWh needed on a typical away day, occasional 40 kWh jumps. Rarely fully charged.
- **Home presence:** ~50%; when away, car charges later from home (overnight) or grid/public at €0.30/kWh
- **Current battery:** Solis hybrid + battery (~10 kWh, [[battery-expansion-analysis]] for context). [[battery-expansion-analysis|Expansion]]: +4.5 kWh for €1000.

The €0.1154/kWh network component is **identical for peak and offpeak**, confirming network costs are hour-independent — they pass through unchanged to a dynamic tariff.

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

This is **~20% higher than the historical 4 665 kWh** that the cost calculations below use — so all "savings from energy" numbers should be adjusted upward by ~20% as the EV-only year materializes.

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

Applied measured hourly import shape to Belpex price profile:

| Window      | % of import (post-EV) | Avg Belpex |
|-------------|-----------------------|------------|
| 00–09       | 71%                   | €0.06      |
| 09–17       | 14%                   | €0.04      |
| 17–21       | 6%                    | €0.13      |
| 21–24       | 9%                    | €0.08      |

**Belpex-weighted average: ~€0.065/kWh**

Delivered price under dynamic:

| Component         | €/kWh   |
|-------------------|---------|
| Belpex (wtd avg)  | 0.065   |
| Supplier markup   | 0.025   |
| × VAT 1.06        | 0.0954  |
| + Network (fixed) | 0.1154  |
| **Delivered**     | **€0.211/kWh** |

- **Dynamic energy cost:** 5 600 × €0.211 = **€1 182/yr**
- **Plus dynamic supplier fixed:** ~€220/yr (Engie Dynamic abonnement comparable to current)
- **Total dynamic contract:** **€1 402/yr**
- **Energy savings vs current: ~€335/yr**

The savings are higher than the previous estimate because:
1. Actual current rates are **€0.27 blended** (not the €0.25 originally assumed)
2. Forward EV consumption is **5 600 kWh** (not 4 665)
3. Most consumption hits the **night Belpex band** (~€0.05) where dynamic shines hardest
- Subtract extra subscription delta (assume +€30/yr vs current contract): **net ~€200/yr**

Export side: 542 kWh/yr × €0.03 fixed = €16/yr current; dynamic export ≈ Belpex when sun shines ≈ €0.02 → ~€11/yr. Slight loss (~€5/yr), trivial.

## With battery arbitrage

Battery enables explicit **time-of-use arbitrage**: charge from grid at cheap hours (00–06 night low), discharge during evening peak (17–21 high).

This is **separate from solar storage**, and only works on days when there's spare battery capacity not needed for solar — i.e. **winter** (Nov–Feb, ~120 days/yr), when PV barely fills the battery.

### Per-cycle arbitrage value

Round-trip efficiency: ~90% (LiFePO4 + inverter losses)

Price spread (night-charge to evening-discharge):
- Charge: Belpex €0.05 + markup €0.025 + network €0.10 + VAT = €0.186/kWh
- Discharge (avoided): Belpex €0.13 + markup €0.025 + network €0.10 + VAT = €0.271/kWh
- **Net per kWh cycled: €0.271 − €0.186/0.9 = €0.064/kWh**

### Constraint: Solis API caps force-charge target at 40% SoC

The Solis hybrid only accepts a `force_charge_soc` setpoint up to **40%**. This is the *target SoC*, not a percentage-points delta — so the arbitrageable window per night is roughly `40% − morning_soc_floor` of total capacity. Assuming a 10% morning floor (after evening discharge), usable arbitrage capacity is **~30% of total battery** per cycle.

### Current battery (~10 kWh usable) — limited to 30% window

- 30% × 10 kWh = 3 kWh per cycle
- 120 winter days × 3 kWh × €0.064 = **€23/yr** (down from €77 without the cap)

### Extended battery (+4.5 kWh, 14.5 kWh usable) — limited to 30% window

- 30% × 14.5 kWh = 4.35 kWh per cycle
- 120 days × 4.35 kWh × €0.064 = **€33/yr**
- **Marginal value of the extra 4.5 kWh in arbitrage: ~€10/yr** (down from €34)

### Workarounds for the 40% cap

The 40% cap is a Solis cloud-API restriction, not a hardware limit. Worth investigating:

1. **Direct Modbus control.** The Solis inverter exposes Modbus registers (RS485 or via the data logger's local API on `solis_local`). The `force_charge_soc` register typically accepts 0–100. The 40% limit is enforced in the SolisCloud app/API, not the inverter firmware. Writing the register directly via `pymodbus` or the existing `solis` integration's local mode would bypass it.
2. **Alternative integration.** The community [`hass-solis-modbus`](https://github.com/hultenvp/solis-sensor) or the local TCP/Modbus path may already expose unrestricted force-charge SoC.
3. **If unbypassable:** the 40% cap functionally kills grid→battery arbitrage as a meaningful revenue stream. The dynamic-tariff case then rests almost entirely on shifting the car-charging schedule.

### Negative pricing days

EPEX Belgium had ~80 hours of negative pricing in 2024, growing each year. Battery soaking up these hours adds ~€20–40/yr extra value, applicable to either battery size.

## Total annual benefit summary

Adjusted for forward-looking EV consumption (~5 600 kWh/yr import, +20% vs historical mix).

With the 40% force-charge cap enforced (current Solis cloud API state):

|                            | Current battery | Extended battery (+4.5 kWh) |
|----------------------------|-----------------|------------------------------|
| Dynamic vs current contract | €335           | €335                         |
| Battery arbitrage (30% window) | €23         | €33                          |
| Negative price capture (capped same way) | €8 | €12                         |
| **Total annual benefit**   | **~€365**       | **~€380**                    |

If the 40% cap can be bypassed via direct Modbus:

|                            | Current battery | Extended battery (+4.5 kWh) |
|----------------------------|-----------------|------------------------------|
| Dynamic vs current contract | €335           | €335                         |
| Battery arbitrage (full window) | €77        | €111                         |
| Negative price capture     | €25             | €30                          |
| **Total annual benefit**   | **~€435**       | **~€475**                    |

**Implications for the [[battery-expansion-analysis]]:**
- With cap: marginal expansion value under dynamic is only ~€15/yr extra — adds little to the solar-capture case (~€140/yr). Payback stays ~7 years.
- Without cap: marginal expansion value is ~€40/yr extra → combined €180/yr → payback ~5.5 years.

The expansion decision is **not changed by dynamic tariff** unless you can unlock the cap.

## Risks and caveats

1. **Belpex volatility.** 2022 averaged >€0.30/kWh during the gas crisis. Dynamic exposes you to repeat events. Fixed tariffs absorb that risk (and price it in via higher baseline).
   - **Mitigation:** Most Belgian dynamic contracts allow switching back to fixed with 1 month notice.

2. **Capacity tariff penalty.** Concentrating car charging into 2–3 hours at the cheapest Belpex point spikes your 15-min peak → increases monthly capacity charge by €5–15/month potentially.
   - **Mitigation:** Limit car charge rate to ~3 kW (vs 7 kW max) and spread over more hours, or use HA automation to keep 15-min average below current monthly peak. Already easy with the existing setup.

3. **Automation cost.** Requires HA automations to:
   - Charge car at hourly cheapest window (not just generic off-peak)
   - Force-charge battery from grid in winter on cheap nights
   - Avoid discharging battery to grid at low Belpex hours
   - Existing Engie Drive-style sensors (`sensor.electricity_injection_engie_drive_*`) suggest you've thought about this already. Belpex integration via [Nordpool](https://github.com/custom-components/nordpool) or [ENTSO-E](https://github.com/JaccoR/hass-entso-e) HA integrations is straightforward.

4. **Future tariff regime changes.** Belgian regulators are actively reshaping injection/capacity rules. The €228/yr energy savings could shrink if:
   - Network costs become more time-varying (making dynamic less advantageous because the "fixed" €0.10 component might rise during peak hours)
   - Capacity tariff tightens (penalizes night-charging peaks harder)

5. **Subscription/abonnement.** Run actual numbers against your current supplier's standing charges before switching; the €30/yr delta assumed above is a rough placeholder.

## Verdict

**Switch to dynamic.** The economics are still clear despite the 40% Solis force-charge cap, because the bulk of the win is car-charging shift, not battery arbitrage:

- ~€335/yr savings purely from shifting EV charging to cheapest Belpex hours (forward-looking with full EV year and actual measured rates) — minimal effort, just a smart charge schedule, **unaffected by the 40% cap**
- +€20–30/yr from winter battery arbitrage with cap (or +€75–110/yr if cap can be bypassed)
- +€8–25/yr from negative-pricing capture
- **Combined: ~€365/yr with cap, ~€435/yr without** — ongoing, no capex
- These figures scale further if winter EV consumption exceeds the 900 kWh/mo estimate (cold-snap years could push annual import to 6 500+ kWh → another ~€60/yr)
- **Payback: instantaneous**

The battery expansion case (separate from this) is **not significantly strengthened by dynamic tariff while the 40% cap is in place** — marginal value only ~€15/yr extra. The expansion still stands on its solar-capture economics ([[battery-expansion-analysis]], ~7yr payback).

**Investigating the Modbus bypass is the highest-leverage follow-up here.** Lifting the cap from 40% → 90% turns ~€60/yr of additional arbitrage value into reality, and disproportionately helps the expansion case.

The main downside is exposure to price-spike years. Given switching is reversible within a month, the asymmetric risk favours trying it.

## Recommended action sequence

1. **Set up Belpex price sensor in HA** (Nordpool or ENTSO-E custom integration) — get 3 months of data flowing without switching.
2. **Build automations** against simulated dynamic pricing:
   - Car charge schedule: charge during N cheapest hours of next 24h, sized to required SoC
   - Battery force-charge: when night Belpex < €0.06 and current SoC < threshold
   - Power capping on car charger to manage capacity tariff
3. **Compare actual measured savings** against fixed tariff for those 3 months.
4. **Switch supplier** if simulation confirms the model. Belgian switches are free and take ~3 weeks.

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

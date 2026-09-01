# Push the house battery to 100 % from the grid (Solis Modbus)

**Plant:** RHI-5K-48ES-5G + PYLON_LV (US5000 + US3000C)  
**Why:** Pylontech wants a long absorb at the top so the BMS can balance (US5000 cell 12 lags). Touching 99 % for an hour is not enough — sit **≥ 98 % for ~4 h**. The 45-day reminder (`binary_sensor.solar_battery_rebalance_overdue`) is when to do this.  
**Related:** [[solis-modbus]], [[solis-steering]], [[ev-battery-peak-coordination]], `smarthome/energy/solar/pylontech.nix`.

**Preferred:** trigger `automation.solar_battery_pylontech_rebalance_run` (energy dashboard **Rebalance pack**, or Developer Tools → Actions), or let `rebalance.auto_trigger` fire it automatically once overdue + SoC ≥ 98 % + the car charger is off/at its 8 A floor. If cells are already balanced (< 30 mV, min cell > 3.45 V) at ≥ 98 % SoC when triggered, it just stamps `last_rebalance` and skips — no car block, no grid. Otherwise: always prefer a **sunny afternoon**: the run blocks the car (only while at/near the knee or grid-charging, not the whole run) and lets PV finish the pack. Grid TOU (~1 kW, peak-capped) is only armed if remaining solar cannot reach 100 % **and** the run is within 24 h of timing out — a run gets up to ~3 days of solar-only patience first. The **4 h at ≥ 98 %** absorb is now cumulative — a dip below 98 % (sunset, a cloud) pauses it, it does not reset — so a rebalance can legitimately span several days of partial sun. A 5-minute watchdog restores on completion (or 96 h timeout / **Cancel rebalance**).

`binary_sensor.solar_battery_rebalance_solar_enough` is the switch: SoC already ≥ 98 %, or `energy_production_today_remaining` > kWh-to-full + 1.5 kWh. When that goes off mid-run, the watchdog escalates to grid.

---

## Do not use these

| Lever | Entity | Why not |
|---|---|---|
| Force-charge SOC | `number.system_house_pv_force_charge_soc` | Heal floor only. Fills **up to the overdischarge band** (~7–20 %), not to 100 %. Solis UI cap is ~39 % even though HA shows 0–100. |
| Force-charge power | `number.system_house_pv_force_charge_power_limitation` | Same mechanism. Live **300 W**. Morning automations reset it to 300 / 1200. |
| Max charge SOC | `number.system_house_pv_max_charge_soc` | Already **100 %**. Firmware **pins** it there on the Pylontech preset — writing 98 % reverts in ~15 s. |
| Float / equalize V | `number.system_house_pv_floating_charge_voltage` | Firmware reverts 52.5 → 53.5 V. BMS/CAN already governs charge. |
| “Grid Time of Use” 6-slot | `switch.system_house_pv_grid_time_of_use_charging_period_*` | Newer firmware family (`6798 = 0` here). **Legacy** TOU is `time_charging_*`. |
| Pylontech console | `pylontech2mqtt` | Read-only. Cannot command charge. |

---

## The path that actually fills to 100 %

**Self-Use + TOU** + **Allow Grid to Charge** + a **time-charging charge slot** with a non-zero current.

Live defaults (2026-08-26) to restore when done:

| Entity | Default |
|---|---|
| `select.system_house_pv_storage_mode` | **Self-Use** |
| `switch.system_house_pv_allow_grid_to_charge_the_battery` | **off** |
| `number.system_house_pv_time_charging_charge_current` | **1.0 A** (junk leftover — restore **0**) |
| `number.system_house_pv_time_charging_discharge_current` | **0** |
| `time.system_house_pv_time_charging_charge_start_slot_1` / `_end_slot_1` | leftover **12:33–12:37** — restore **00:00 / 00:00** |
| Charge slots 2–5 and all discharge slots | **00:00** |
| `sensor.system_house_pv_storage_control_switching_value` | **1** (bit 0 = self-use only) |

`switch.system_house_pv_self_use_mode` must stay **on**. Mode exclusivity: do not turn on Feed-in / Peak Shaving / Off-grid.

### Power budget (capaciteitstarief)

15-minute **import** average at the DSMR meter. Floor billed band is **2.5 kW**; live month peak is on `sensor.electricity_delivery_power_monthly_15m_max`.

Time-charging current is **battery amps at ~50 V**, not AC amps. **20 A ≈ 1.0 kW**, not 20 × 230 V = 4.6 kW. 2.5 kW at the meter would be ~50 A on the pack.

| Charge current | ≈ DC / grid |
|---|---|
| 10 A | 0.5 kW |
| **20 A (automation max)** | **1.0 kW** |
| 35 A | 1.8 kW |
| 50 A | 2.5 kW (the whole peak — do not) |

The run automation **peak-caps** every 5 min (`sensor.solar_battery_rebalance_charge_current_target`) so house import + this charge stay under `max(2.5 kW, this month’s peak)` with 0.2 kW margin. **Car charger off** for the window — battery + car sharing a 15-min bucket is how 2026-07-03 went wrong.

Pack is ~8.3 kWh nameplate × 94 % SOH ≈ **7.8 kWh**. From SoC `S` % to 100 %:

`(100 − S) / 100 × 7.8 kWh` plus **4 h absorb** at the top (CCL tapers; do not fight `sensor.system_house_pv_battery_charge_current_limitation_bms`).

Start as full as you can. The 4 h at the top is the point, not the climb.

---

## Procedure

Developer tools → Services, or the Solis device page. Wait ~10–15 s between writes (flash-backed registers).

### 1. Preconditions

- `switch.system_car_charger` **off** (or target current 0).
- `sensor.electricity_delivery_power_15m` well under the month peak.
- Prefer `binary_sensor.electricity_is_offpeak` if this is a night fill.
- If Solis SoC is already ≥ 98 % from PV: **do not start grid charge** — just leave it there 4 h (no car dump).

### 2. Arm grid charge

1. `switch.system_house_pv_allow_grid_to_charge_the_battery` → **on**  
2. `select.system_house_pv_storage_mode` → **Self-Use + TOU**  
3. Confirm `switch.system_house_pv_self_use_mode` still **on**. `sensor.system_house_pv_storage_control_switching_value` should be **35** (bits 0+1+5 = Self-Use + TOU + Allow Grid). Default idle is **1**.  
4. `number.system_house_pv_time_charging_discharge_current` → **0**  
5. All discharge slot start/end → **00:00**

### 3. Charge window

1. `number.system_house_pv_time_charging_charge_current` → **`sensor.solar_battery_rebalance_charge_current_target`** (max **20 A ≈ 1 kW**). Do not use 35 A; that plus house load can tag the 2.5 kW peak. Combined 0.5C is 87 A, but the meter is the limit.  
2. Slot 1 only:

   - `time.system_house_pv_time_charging_charge_start_slot_1` = now (or next full hour)  
   - `time.system_house_pv_time_charging_charge_end_slot_1` = start + climb + **4 h**

   Example from 70 % at 20 A: ~2.5 h climb + 4 h absorb → **6.5 h** window.  
3. Slots 2–5 stay **00:00**.

### 4. Confirm it is actually charging from grid

Within one Modbus poll (~10 s):

| Check | Expect |
|---|---|
| `sensor.system_house_pv_battery_current_direction` | charge (not 1 / discharge — this plant: **0 = charge, 1 = discharge**) |
| `sensor.electricity_battery_power` | negative (charging) |
| `sensor.electricity_grid_consumed_power` | ≈ chosen kW + house idle |
| `sensor.system_house_pv_battery_soc` | ticking up |
| BMS CCL | falling toward 5–20 A as SoC → 100 % — **leave it** |

If SoC is already above overdischarge and nothing happens: Allow-Grid is still off, mode is still plain Self-Use, the slot does not cover *now*, or current is 0. Slot leftover 12:33–12:37 is four minutes — not a window.

### 5. Sit at the top

Do **not** start the car when Solis hits 99 %.

Done when **either**:

- Solis SoC **≥ 98 % for 4 h** → `solar/battery/pylontech/rebalance.record` stamps `input_datetime.solar_battery_last_rebalance`, or  
- both packs on the knee: min cell **> 3.45 V** and imbalance **< 30 mV** for 20 min (US5000 cell 12 has caught up).

Watch `sensor.pylontech_us5000_pack_2_cell_imbalance` at rest near 100 %. 100 mV+ on the knee that collapses on the plateau is normal until that 4 h absorb; it is *not* the stop condition.

### 6. Restore (mandatory)

Order:

1. `number.system_house_pv_time_charging_charge_current` → **0**  
2. Slot 1 start/end → **00:00 / 00:00** (clear the 12:33 leftover too)  
3. `select.system_house_pv_storage_mode` → **Self-Use**  
4. `switch.system_house_pv_allow_grid_to_charge_the_battery` → **off**  
5. Confirm `storage_control_switching_value` is **1** again  

HA floor automations (`solar/battery/overdischarge.control`, `forcechargesoc.control`, `max_charge` at 07:00) do **not** touch TOU or Allow-Grid. If you leave Allow-Grid on, a later TOU slot (or junk 12:33 window) can import overnight.

---

## Optional: RC “charge now”

`switch.system_house_pv_rc_force_battery_charge` + `number.system_house_pv_rc_force_battery_charge_power` (reg 43135 / 43136). **Unverified on this RHI-5G.** Docs said try read-only first.

If you test it:

1. Allow-Grid **on** (still required).  
2. Set RC power to **1000 W**.  
3. Turn the switch **on**.  
4. If battery current / grid import does not move within **30 s**, turn it **off** and use the TOU path. Do not leave RC on.

`select.system_house_pv_rc_force_charge_discharge` is the same feature as a dropdown (`None` / `Solis RC Force Battery Charge`). Prefer the switch + number so power is explicit.

---

## What HA will not fight

| Automation | Writes | During this procedure |
|---|---|---|
| `solar/battery/overdischarge.control` | overdischarge 8–20 % | Discharge *floor* only. Charge still goes to 100 %. |
| `solar/battery/forcechargesoc.control` | force-charge **7 %** | Heal floor. Inactive while SoC ≫ 7 %. |
| `solar/battery/max_charge` (07:00) | force-charge power **300 W** | Irrelevant if you are not in force-charge. |
| `solar/battery/charge` (05:00) | force-charge power 1200 W if `input_boolean.solar_battery_charge_offpeak` | Off unless that boolean is on. |

None of them write `storage_mode`, Allow-Grid, or time-charging slots.

---

## Failure modes

| Symptom | Likely cause |
|---|---|
| SoC stalls ~90–95 %, PV gone | Allow-Grid still **off** — solar-only top-up died |
| No current in the slot | Mode still **Self-Use** (no TOU), or current 0, or clock not in the slot |
| Grid peak warning / month peak jumps | Current too high and/or car still on |
| 147 mV imbalance then 1 mV after a few % discharge | LFP knee, not a failed cell — keep sitting at 100 % |
| Max charge SOC won’t stay at 98 % | Firmware pin; ignore |
| Force-charge SOC at 100 % does nothing useful | Wrong tool; even if the write sticks it only changes the heal floor |

# Solis RHI-5K-48ES-5G — local Modbus (USB-RS485)

**Date:** 2026-08-14  
**Plant:** RHI-5K-48ES-5G + PYLON_LV (US5000 + US3000C) + S3-WIFI-ST on COM  
**Goal:** live battery/PV/house at 2–15 s, and steering, without SolisCloud.

Related: [[solis-steering]], [[ev-battery-peak-coordination]].

---

## Is this inverter supported?

**Yes for everything this plant actually uses.** The RHI-5G hybrids speak the **ESINV-33000** register map (query register 35000; high digits `20` = ESINV). Same family as:

| Model | Status in [solis_modbus](https://github.com/Pho3niX90/solis_modbus) |
|---|---|
| RHI-3K-48ES-5G | Tested |
| **RHI-5K-48ES-5G** (this unit) | Same protocol / 5 kW sibling |
| S5-EH1P5K-L | Tested (rebadge of this generation) |

Do **not** pick a “string inverter / INV-3000” profile. That is a different map.

### Reads (this plant today)

| What we use now | Cloud entity | Modbus register |
|---|---|---|
| Battery power | `sensor.solis_battery_power` | 33149–33150 (+ 33135 direction) |
| Battery SoC / SoH | `sensor.solis_remaining_battery_capacity` | 33139 / 33140 |
| House load | `sensor.solis_total_consumption_power` | 33147 |
| PV strings | `sensor.solis_dc_power_pv1/2` | 33049–33052 |
| Inverter temp | `sensor.solis_temperature` | 33093 |
| Grid / meter | Solis + DSMR | 33251–33286 (keep DSMR as fiscal) |
| Charge / discharge energy | Solis daily/total | 33161–33168 |

Poll interval can be **2–15 s** (integration “Extreme” profile is 2 s for the live group). That replaces the 5-minute SolisCloud sample.

### Writes (this plant’s steering)

Cloud CIDs in `solis-control` map 1:1 onto holding registers `solis_modbus` already exposes as numbers/switches:

| Cloud CID (today) | Register | Entity (solis_modbus) |
|---|---|---|
| 158 / 7228 Overdischarge SOC | **43011** | `number.solis_overdischarge_soc` |
| 160 Forcecharge SOC | **43018** | `number.solis_force_charge_soc` |
| 9020 Max grid W when force-charging | **43027** | `number.solis_force_charge_power_limitation` |
| 7691 Max charge SOC | 43010 | `number.solis_max_charge_soc` |
| 466 Self-use / 43110 bitfield | **43110** | `select.solis_storage_mode` + allow-grid-charge bit 5 |
| 4643 TOU slots | 43141–43169 | time-charging charge/discharge slots |

So the existing automations in `smarthome/energy/solar/battery.nix` can be retargeted from `number.solar_battery_*` (MQTT → cloud) to these Modbus numbers. No new control philosophy.

### Better steering than Cloud? (e.g. charge to 100 %)

**Same ceiling, better loop.** Max Charge SOC is already **100 %** (43010). Modbus cannot raise that. Pylontech will still taper charge current (often 40 A → 5 A) as SoC approaches 100 % — do not fight register 33143.

What Modbus *does* add over `solis-control`:

| Gain | Why it matters here |
|---|---|
| 2–15 s SoC / W / BMS CCL | Closed-loop: “keep charging until SoC has been 100 % for 15 min”, not “set a floor and wait 5 min for Cloud” |
| **43110 bit 5** Allow grid charge | Live it is **OFF**. Solar-only top-up dies when PV fades (~90–95 %). This bit is how you finish from the grid. |
| TOU slots 43141–43169 | Cheap-rate window + charge current to *force* a periodic 100 % (Pylontech likes ~monthly full charge to recalibrate SoC) |
| RC force charge 43135 / 43136 | Direct “charge now at N W” if this firmware implements it (RHI-5G: try read-only first) |
| No `yuanzhi` / Cloud lag / failed writes | Same 43011 / 43018 / 43027 you already use, locally |

Do **not** hammer flash-backed floors every few seconds. Keep today’s rate limits. Remote Dispatch (34502) is almost certainly **not** on this RHI.

### What you lose if the S3 stick comes out

| Keep | Lose |
|---|---|
| All live telemetry, faster | SolisCloud app / installer remote |
| All current steering registers | Inverter firmware OTA via the stick |
| DSMR as the legal meter | Cloud-computed “monthly grid” (we already ignore that) |
| | **New** “Remote Dispatch” (reg 34502 = `0xAA55`) — RHI-5G firmware is almost certainly too old for this anyway |

`solis-control.nix` becomes unused once writes go local.

---

## Two RS-485 buses — do not mix them

On the RHI-5G underside there are **two** comms connectors:

```
                    ┌──────────────────────────┐
   PV MC4s          │      RHI-5K-48ES-5G      │
                    │                          │
   BATTERY CAN ─────┤  CAN  (Pylontech only)   │  ← leave alone
                    │                          │
   GRID / BACKUP    │                          │
                    │   4-pin COM (logger)     │── S3-WIFI-ST today
                    │   2-pin RS485 (meter)    │── house CT / Solis meter
                    └──────────────────────────┘
```

| Port | Plug | Who is master | What rides on it |
|---|---|---|---|
| **4-pin COM** | Exceedconn EC04681-2014-BF (the stick) | Logger **or** your USB adapter | Inverter registers 33xxx / 43xxx |
| **2-pin RS485** | Small green “RS485” terminal | **The inverter** | Meter only |

Put the USB adapter on the **4-pin COM**, never on the meter pair. Sharing the meter bus with a second master will glitch self-use (the inverter stops seeing import/export correctly).

---

## 4-pin COM pinout (logger socket)

Ridge on the connector faces the latch. Pins, looking into the **inverter** socket (circular):

| Pin | Function | USB-RS485 adapter |
|---|---|---|
| 1 | **+5 V** (powers the stick) | **Do not connect** |
| 2 | GND | Adapter GND (recommended) |
| 3 | RS485 **A** (+) | Adapter **A** / D+ / D1 |
| 4 | RS485 **B** (−) | Adapter **B** / D− / D0 |

```
USB-RS485 dongle                         Inverter 4-pin COM
┌─────────────┐                          ┌─────────────┐
│ A  / D+     │──────────────────────────│ 3  RS485+   │
│ B  / D−     │──────────────────────────│ 4  RS485−   │
│ GND         │──────────────────────────│ 2  GND      │
│ 5V (if any) │    ✗ leave disconnected  │ 1  +5V      │
└─────────────┘                          └─────────────┘
         powered from the USB port              unplug the S3 stick
```

Notes:

- **A and B are often swapped** on cheap dongles. If every read times out, swap A/B once. That is the usual first failure.
- Some dongles label A/B backwards. No damage from swapping data pins.
- Connecting USB 5 V to pin 1 **can** fight the inverter PSU. Don’t.
- 120 Ω termination: the inverter is usually already terminated. Add a jumper on the dongle only if the cable is long *and* you see CRC errors.
- Twisted pair, keep it short. USB-RS485 over 5–10 m of junk cable is the second usual failure. If `nhtpc` is not next to the inverter, use a Waveshare / Elfin RS485-to-Ethernet brick on the LAN instead of a long USB lead.

### Where to get the connector

The socket is **Exceedconn EC04681-2014-BF** (circular 4-pin). The later **EC04681-2023-BF** / **1123-BF** are sold as drop-in replacements.

| Source | What | Notes |
|---|---|---|
| [eBay — “RS-485 Connector for Solis / Exceedconn EC04681-2014-BF”](https://www.ebay.com/itm/155648938095) | Plug only | Common; ships to BE |
| [eplop.co.uk — EC04681-2023-BF](https://store.eplop.co.uk/product/exceedconn-ec04681-2023-bf-female-for-solis-ginlong-inverter-rs-485-port) | Plug (+ optional Y-split kit) | UK |
| [NPE UK — EC04681-1123-BF](https://www.npe-uk.com/stock-parts/p/exceedconn-ec04681-1123-bf-rs485-connector-solis-ginlong) | Plug | IP68 housing |
| AliExpress / Amazon “USB RS485 Exceedconn Solis” | **Ready-made USB + plug** | Skip soldering; check A/B if it fails |
| Spare S3-WIFI-ST (~€20) | Harvest the plug | Or flash ESPHome onto it later |
| [3D-printed shell](https://github.com/hn/ginlong-solis/issues/37) | Housing only | Still need the metal pins |

Do **not** use crocodile clips on the live COM socket. It is a recessed circular four-pin with **+5 V on pin 1**. A slip shorts 5 V onto A/B and can kill the comms board or the USB adapter. Crocs are fine on a bench pigtail with pin 1 taped off, not in the inverter.

### Recommended: unplug the S3 stick

Two Modbus masters on COM (stick + USB) collide. Pho3niX90’s position: you lose SolisCloud unless you use a dedicated pass-through (Waveshare) that multiplexes. You want off-cloud, so:

1. Power the inverter down or accept a brief logger dropout.
2. Unplug the S3 stick from COM.
3. Fit a pigtail (spare Exceedconn, or the pins from a dead stick) to the USB adapter.
4. Leave the stick in a drawer. Factory-reset it later if you ever need Cloud OTA.

Keep the **meter** 2-pin cable exactly where it is.

---

## Serial settings

| | |
|---|---|
| Mode | Modbus RTU |
| Baud | **9600** (Solis default; 19200 on some units — try 9600 first) |
| Data | 8N1 |
| Slave ID | **1** |
| Device | `/dev/serial/by-id/usb-…` (never `/dev/ttyUSB0`) |

On NixOS the HA service user needs the `dialout` group and the stick must be plugged in before `home-assistant.service` starts (or add a udev `TAG+="systemd"` so HA restarts on attach).

Smoke test from `nhtpc` (after the adapter shows up):

```sh
nix-shell -p python3Packages.pymodbus --run \
  'python3 -c "
from pymodbus.client import ModbusSerialClient
c = ModbusSerialClient(\"/dev/serial/by-id/usb-YOUR-ADAPTER\", baudrate=9600)
assert c.connect()
r = c.read_input_registers(33000, 4, slave=1)
print(r.registers)
"'
```

Expect a model / DSP / HMI / protocol word. Protocol ≈ `20xx` → ESINV, you are on the right map. Then read 33139 (SoC) and 33149 (battery power).

---

## Software on this host

Preferred: **[Pho3niX90/solis_modbus](https://github.com/Pho3niX90/solis_modbus)** (HACS), connection type **Serial**, poll profile **Full** first, then **Extreme + battery/load** if you want 2 s updates.

This flake does not vendor that component yet. Until it is packaged like `powercalc`:

1. Add the custom component (or run a one-off test from a `nix-shell` as above).
2. Point HA automations at `number.solis_overdischarge_soc` etc.
3. Retire `services/solis-control.nix` and the SolisCloud platform sensors once the new entities have a day of history.
4. Keep DSMR as the Energy-dashboard grid source (fiscal). Use Modbus battery power / SoC / PV as the fast plant view.

Alternative if USB-to-inverter is awkward: [hn/ginlong-solis](https://github.com/hn/ginlong-solis) ESPHome on a **spare** S3 stick (`solis-modbus-esinv.yaml`). Same registers, Wi-Fi instead of USB. Do not flash the live stick until you have a spare — that is a one-way trip off Cloud.

---

## First-day checklist

1. Confirm A/B with a SoC read before writing anything.
2. Read 43011 / 43018 / 43027 and check they match today’s cloud setpoints (15 / 9 / 300).
3. Write overdischarge **up by 1 %** and confirm it sticks; revert.
4. Only then retarget `battery.nix` automations.
5. Do not hammer flash-backed registers (floors, TOU) every few seconds — the current automations already rate-limit.

---

## What “fully supported” is not

- **Remote Dispatch** (keep-alive watt setpoints, failsafe) — new S6 firmware. Not this RHI.
- **Sharing COM with the S3 stick** — not reliable.
- **Meter-port sniffing** — wrong bus.
- **S3 `inverter.cgi`** — still PV-only; Modbus is what actually has battery.

For this plant, local Modbus is a complete replacement for both `solis-sensor` (telemetry) and `solis-control` (steering).

---

## Keep history when switching (done 2026-08-20)

Went a different way than the original rename plan below (kept for reference): the `solis_modbus` device on this plant is named **`system_house_pv`** (serial `1031042229220103`, entity ids `sensor.system_house_pv_*`) — deliberately descriptive, not `solis_*`, and not tied to the USB adapter. Rather than doing the double-rename dance (cloud → `_cloud`, Modbus → historic id) to reuse the old `sensor.solis_*` ids, the cloud entities' history was **spliced directly into the `system_house_pv_*` statistics via MariaDB**, so the new descriptive names keep the id and inherit the history:

- **Energy (13 cumulative kWh counters)**: for each pair, computed `offset = source's last statistics.sum − destination's first statistics_short_term.sum`, applied that offset to the destination's already-accumulating `statistics_short_term` rows (so future hourly compiles continue seamlessly), then copied all of the source's `statistics` (long-term, hourly) rows into the destination unchanged. Verified before writing that each `sum` series only had genuine reset events (not corruption) by checking `COUNT(DISTINCT sum - state)` stayed low for the never-reset lifetime totals.
- **Power + SoC (7 series: battery SoC/power, PV1/PV2 power, household load, grid power, AC output power)**: no offset needed (not cumulative) — just copied `statistics` rows across.
- Only the long-term `statistics` table was touched (kept indefinitely); `statistics_short_term` (5-min, auto-purged after ~10 days) was left alone except for the sum-offset lift needed for continuity. Raw `states` history was not migrated (low value — purges after ~10 days anyway).
- A `mysqldump` of the affected `statistics` / `statistics_short_term` / `statistics_meta` rows (source + destination metadata ids) was taken before writing anything.
- Continuity was verified after the fact: the last imported historical row and the entity's own next naturally-compiled row landed on the same `sum` value.

Actual mapping used (cloud id → `system_house_pv` id):

| Cloud (history source) | `system_house_pv` (kept id, now has the history) |
|---|---|
| `sensor.solis_energy_total` | `sensor.system_house_pv_pv_total_energy_generation` |
| `sensor.solis_energy_today` | `sensor.system_house_pv_pv_today_energy_generation` |
| `sensor.solis_energy_this_month` | `sensor.system_house_pv_pv_current_month_energy_generation` |
| `sensor.solis_energy_this_year` | `sensor.system_house_pv_pv_this_year_energy_generation` |
| `sensor.solis_total_energy_charged` | `sensor.system_house_pv_total_battery_charge_energy` |
| `sensor.solis_daily_energy_charged` | `sensor.system_house_pv_today_battery_charge_energy` |
| `sensor.solis_total_energy_discharged` | `sensor.system_house_pv_total_battery_discharge_energy` |
| `sensor.solis_daily_energy_discharged` | `sensor.system_house_pv_today_battery_discharge_energy` |
| `sensor.solis_total_energy_used` | `sensor.system_house_pv_total_energy_consumption` |
| `sensor.solis_total_energy_purchased` | `sensor.system_house_pv_total_energy_imported_from_grid` |
| `sensor.solis_daily_grid_energy_purchased` | `sensor.system_house_pv_today_energy_imported_from_grid` |
| `sensor.solis_total_on_grid_energy` | `sensor.system_house_pv_total_energy_fed_into_grid` |
| `sensor.solis_daily_on_grid_energy` | `sensor.system_house_pv_today_energy_fed_into_grid` |
| `sensor.solis_remaining_battery_capacity` | `sensor.system_house_pv_battery_soc` |
| `sensor.solis_battery_power` | `sensor.system_house_pv_battery_power` |
| `sensor.solis_dc_power_pv1` | `sensor.system_house_pv_pv_power_1` |
| `sensor.solis_dc_power_pv2` | `sensor.system_house_pv_pv_power_2` |
| `sensor.solis_total_consumption_power` | `sensor.system_house_pv_household_load_power` |
| `sensor.solis_power_grid_total_power` | `sensor.system_house_pv_meter_total_active_power` |
| `sensor.solis_ac_output_total_power` | `sensor.system_house_pv_active_power` |
| `sensor.solis_temperature` | `sensor.system_house_pv_temperature` |
| `sensor.solis_ac_frequency` | `sensor.system_house_pv_grid_frequency` |

All `smarthome/**/*.nix` references to the `sensor.solis_*` ids above (car charger, HVAC, capacity peaks, demand management, `battery.nix`, `ha/default.nix` stale-entity watchdog) were retargeted to the `system_house_pv_*` equivalents in the same change. Not yet retargeted: the write-side `number.solar_battery_*` (still cloud, via `solis-control`/MQTT — see "Better steering than Cloud?" above for the eventual Modbus register targets) and Energy dashboard source config (Settings → Energy, UI-only, not in nix — point it at the `system_house_pv_*` kWh sensors manually).

`solis-sensor` (cloud) and `solis-control` are still running; retire them once the Modbus telemetry has proven itself for a few days.

### Original rename plan (superseded, kept for context)

The original idea was HA's own `entity_id` rename (cloud id → `_cloud` suffix, then Modbus id → the freed historic id), which is what keeps history in the simple case. Superseded here because the `solis_modbus` device got a deliberately descriptive name (`system_house_pv`) instead of reusing short `solis_*`-style ids, and a direct MariaDB splice was used instead so the new names could be kept as-is. If doing this on a future install where the Modbus entity ids do land on the same `sensor.solis_*` names, the rename approach is simpler:

```
hass-cli entity rename sensor.solis_energy_total sensor.solis_energy_total_cloud
hass-cli entity rename sensor.solis_pv_total_energy_generation sensor.solis_energy_total
```

Cloud id first → `*_cloud`, then Modbus id → historic id. [HA-Merge-Sensor-History](https://github.com/mayerwin/HA-Merge-Sensor-History) is a maintained custom-component alternative to a hand-rolled SQL splice if that's preferred another time — it does the same offset-lift automatically, at the cost of one more vendored component.

### What not to do

- Do not delete cloud entities first.
- Do not change nix `unique_id`s to “match” Modbus.
- Do not point Energy at brand-new kWh entity_ids the first week.
- Do not wipe MariaDB. Take a targeted `mysqldump` of the affected `statistics`/`statistics_short_term`/`statistics_meta` rows before writing.

---

## Direct Pylontech vs Solis?

**Not instead of Solis. Maybe later, in addition.**

The inverter already talks **CAN** to the stack (`PYLON_LV`). Pack voltage, current, SoC, SoH (you already have 94 %), and charge/discharge limits are BMS values relayed through Solis. After Modbus those update in seconds. That is what the inverter *steers* on — automations should keep using that SoC so they do not fight the hybrid.

A **console** lead on the master US5000/US3000C is a *second* RS485 (RJ45 pinout, **115200 8N1**, text protocol — not Modbus, not the Exceedconn, not the meter). Integrations: ESPHome `pylontech`, or a USB-RS485 on that console. Daisy-chain Link ports stay as they are; **do not tap CAN**.

| | Solis (CAN via inverter) | Pylontech console |
|---|---|---|
| Pack SoC / A / V | Yes, and it is the control value | Yes, may disagree by 1–3 % |
| Per-module V, T, SoC | No | Yes |
| Cell min/max, imbalance | No | Yes |
| Cycle count, MOSFET / warnings | Partial / none | Yes |
| Extra hardware | USB already ordered | Another adapter + cable to the rack |
| Risk | — | Wrong pins on console; never share Solis COM |

Worth doing if you care about **which module is sick** or warranty cycles. Not worth it to “get better energy numbers” — fiscal is DSMR, live power after Modbus is already the inverter’s view of the pack.

If you add it: keep `sensor.solis_remaining_battery_capacity` as the automation input; put Pylontech entities on a maintenance dashboard only.

### Can Pylontech “Modbus” steer better (e.g. charge to 100 %)?

**No.** The console is not Modbus (text @ 115200). It is a **read** path. The inverter is the charger; the BMS only *advertises* a charge-current limit (CCL) over CAN. Writing the pack to “go to 100 %” does not make the RHI push more current. Faking SoC on CAN (or unplugging CAN) is how people get the inverter to dump a full force-charge into a pack that then opens MOSFETs.

This plant **already has Max Charge SOC = 100 %** (CID 7691 / reg **43010**). If the stack stalls at ~90–95 %, that is almost always:

- Pylontech CCL taper (40 A → 5 A as SoC approaches 100 %) and Solis giving up / not floating long enough to balance
- **Allow grid charging OFF** (43110 bit 5) — no solar left → it sits there
- Cell imbalance (need hours at a slightly *lower* float, not a higher target)

Steering that *does* help is **Solis Modbus**, not Pylontech:

| Register | What |
|---|---|
| 43010 | Max charge SOC — already 100 % |
| 43110 bit 5 | Allow grid charge (needed for a cheap-rate top-up) |
| 43141–43169 | TOU charge window to *force* a periodic 100 % (Pylontech likes a full charge ~monthly to recalibrate SoC) |
| 33143 | BMS charge current limit — watch this taper; do not fight it |

Use a Pylontech console later to *see* cell max / imbalance if 100 % never sticks. Do not use it as a second charger.

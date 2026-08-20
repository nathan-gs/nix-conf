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

## Keep history when switching (rename plan)

Home Assistant long-term statistics follow **`entity_id`**. Only rename sensors whose **charts are worth 2023-03 → now**. Skip temp, frequency, voltages, phase VA/var, settings, and versions.

Energy dashboard kWh (`solar_delivery_total`, `battery_*_energy`, DSMR) is **not** from `solis-sensor`. It is untouched.

Do **not** delete `solis-sensor` until the renames below are done. Grok can run them with `hass-cli entity rename` once Modbus is live.

### Do rename — energy (must)

All have LTS `sum` from **2023-03-29** unless noted. Pair by unit + meaning after install; names on the right are what `solis_modbus` *usually* creates.

| Keep (cloud id, history) | Expected new id |
|---|---|
| `sensor.solis_energy_total` | `sensor.solis_pv_total_energy_generation` |
| `sensor.solis_energy_today` | `sensor.solis_pv_today_energy_generation` |
| `sensor.solis_energy_this_month` | `sensor.solis_pv_current_month_energy_generation` |
| `sensor.solis_energy_this_year` | `sensor.solis_pv_this_year_energy_generation` |
| `sensor.solis_total_energy_charged` | `sensor.solis_total_battery_charge_energy` |
| `sensor.solis_daily_energy_charged` | `sensor.solis_today_battery_charge_energy` |
| `sensor.solis_total_energy_discharged` | `sensor.solis_total_battery_discharge_energy` |
| `sensor.solis_daily_energy_discharged` | `sensor.solis_today_battery_discharge_energy` |
| `sensor.solis_total_energy_used` | `sensor.solis_total_energy_consumption` |
| `sensor.solis_total_energy_purchased` | `sensor.solis_total_energy_imported_from_grid` |
| `sensor.solis_daily_grid_energy_purchased` | `sensor.solis_today_energy_imported_from_grid` |
| `sensor.solis_total_on_grid_energy` | `sensor.solis_total_energy_fed_into_grid` |
| `sensor.solis_daily_on_grid_energy` | `sensor.solis_today_energy_fed_into_grid` |

Optional (shorter or noisier series — only if the new sensor is clearly the same counter): monthly/yearly charge, discharge, grid purchased, on-grid.

### Do rename — power + SoC (maybe)

Same start date, ~30k hourly rows. Worth it for “what was the pack doing in 2024”.

| Keep | Expected new id |
|---|---|
| `sensor.solis_remaining_battery_capacity` | `sensor.solis_battery_soc` |
| `sensor.solis_battery_power` | `sensor.solis_battery_power` (may already match → then only park the cloud one) |
| `sensor.solis_dc_power_pv1` | `sensor.solis_dc_power_1` |
| `sensor.solis_dc_power_pv2` | `sensor.solis_dc_power_2` |
| `sensor.solis_total_consumption_power` | `sensor.solis_household_load_power` |
| `sensor.solis_power_grid_total_power` | `sensor.solis_meter_total_active_power` / `solis_ac_grid_port_power` |
| `sensor.solis_ac_output_total_power` | `sensor.solis_active_power` |

Skip: `solis_battery_power_inverted` (6 hours of data), plant/backup load, per-phase W/VA/var.

### Do not rename

`sensor.solis_temperature`, `sensor.solis_ac_frequency`, all V/A, SoH, force-charge SoC, HMI, timestamps, `number.solar_battery_*`. New Modbus copies can keep their default ids. Automations that need SoC/power keep working via the renamed sensors above.

### Procedure (Grok, when USB is live)

```
# 1. List both sides
hass-cli entity list 'sensor.solis_*'

# 2. For each pair in the tables:
hass-cli entity rename sensor.solis_energy_total sensor.solis_energy_total_cloud
hass-cli entity rename sensor.solis_pv_total_energy_generation sensor.solis_energy_total
```

Cloud id first → `*_cloud`, then Modbus id → historic id. That is what keeps MariaDB `statistics`. Confirm SoC ±2 % before any rename.

Then remove `solis-sensor`. Leave `number.solar_battery_*` until `battery.nix` is retargeted.

If a chart still points at a `_2`: [migration guide](https://solis-modbus.readthedocs.io/en/latest/migration.html) or [HA-Merge-Sensor-History](https://github.com/mayerwin/HA-Merge-Sensor-History).

### What not to do

- Do not delete cloud entities first.
- Do not change nix `unique_id`s to “match” Modbus.
- Do not point Energy at brand-new kWh entity_ids the first week.
- Do not wipe MariaDB.

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

---

## Voltage setpoints vs Pylontech spec (assessed 2026-08-20)

Pylontech US5000/US3000C (15S LFP) datasheet charge voltage is **52.5–53.5 V**, absolute max 53.5 V. Pylontech support has told installers in writing to run bulk/float at **52.5 V**, not 53.5 V — the margin exists because inverter-side voltage sensors (Solis included) read slightly high at the terminals.

This plant's registers, as configured:

| Register | Value | Note |
|---|---|---|
| `number.system_house_pv_floating_charge_voltage` | 53.5 V | At datasheet max, not Pylontech's recommended 52.5 V |
| `number.system_house_pv_equalizing_charge_voltage` | 55.0 V | Above spec; likely inert since BMS/CAN governs actual charge, but not a value to leave above pack limits |

**Tried lowering Floating Charge Voltage to 52.5 V — Solis firmware silently reverts it back to 53.5 V.** Confirmed via the `number.` entity's own declared range (`min: 40, max: 60`, no HA-side restriction) — the revert happens inverter-side, not in `solis_modbus`. This matches a known DIY Solar Forum report that Solis won't accept an Equalizing Charge write below 54 V either (resets to 55 V on save). Read: when Battery Type is a recognized Lithium/Pylontech preset, Solis enforces its own floor on these registers regardless of what's written — **52.5 V is not reachable through this path.** Don't re-attempt; there's no known workaround short of switching Battery Type to Custom, which would forfeit the CAN-negotiated preset and isn't worth the risk given the BMS already governs real charge behavior (see "Can Pylontech Modbus steer better?" above).

Battery SOH history (`sensor.system_house_pv_battery_soh`, MariaDB `statistics`): 100 % → 94 % from 2023-03 to 2026-08, ~1.7–1.8 %/yr overall. Note a jump from 96.6 % → 98 % around 2024-09/10 — that's the pack physically expanding from 1× US5000 to 1× US5000 + 1× US3000C (blended SOH from the fresh module), not a recalibration or real capacity recovery. Post-expansion the combined stack has declined 98 % → 94 % over ~22 months (~2.2 %/yr) — the biggest available lever for slowing this is less time at 100 % SoC (Max Charge SOC is currently 100 % daily; Pylontech only needs a full charge ~monthly to recalibrate), not the 1 V float difference that turned out to be unenforceable anyway.

Steering that *does* help is **Solis Modbus**, not Pylontech:

| Register | What |
|---|---|
| 43010 | Max charge SOC — already 100 % |
| 43110 bit 5 | Allow grid charge (needed for a cheap-rate top-up) |
| 43141–43169 | TOU charge window to *force* a periodic 100 % (Pylontech likes a full charge ~monthly to recalibrate SoC) |
| 33143 | BMS charge current limit — watch this taper; do not fight it |

Use a Pylontech console later to *see* cell max / imbalance if 100 % never sticks. Do not use it as a second charger.

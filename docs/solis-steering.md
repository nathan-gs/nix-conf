# Solis hybrid — steering & control reference

**Date:** 2026-08-10  
**Scope:** What can be read and written on this plant’s Solis hybrid (cloud API + local stack), live setpoints, and how that maps to HA / `solis-control`.

Related: [[dynamic-tariff-analysis]], [[battery-expansion-analysis]], [[ev-battery-peak-coordination]], [[solis-modbus]].

**Superseded 2026-08-20.** `solis-control` and the SolisCloud Device Control API steering it used are removed — `battery.nix` writes local Modbus registers directly (see [[solis-modbus]] § "Better steering than Cloud?"). Kept below for the CID→register mapping reference and history.

---

## Two different SolisCloud APIs

| Document | Base URL | Purpose |
|----------|----------|---------|
| [Platform API V2.0.3](https://oss.soliscloud.com/templet/SolisCloud%20Platform%20API%20Document%20V2.0.3.pdf) | `https://www.soliscloud.com:13333/v1/api/…` | **Telemetry + plant admin only** (lists, detail, day/month/year energy, bind station/collector) |
| [Device Control API V2.0](https://oss.soliscloud.com/doc/SolisCloud%20Device%20Control%20API%20V2.0.pdf) | `…/v2/api/control`, `…/v2/api/atRead` | **Steering** by command ID (**CID**) |
| [Command list (xlsx)](https://oss.soliscloud.com/doc/SolisCloud_control_api_command_list.xlsx) | — | Full CID catalogue (hybrid / PV / off-grid sheets) |

Auth (both): Key ID + Secret from SolisCloud → Account → Basic Settings → API Management. Same credentials work for control **once Solis support has enabled Control API write access**.

Signing: `POST` + Content-MD5 + Content-Type + Date + path, HMAC-SHA1 with secret, Base64 — as implemented in `solis-control`.

**Platform API does not set force-charge, TOU, or modes.** It can *report* current setpoints in detail payloads (`socDischargeSet`, `socChargingSet`, `pLimitSet`, …) as read-only fields.

Data on Platform endpoints is typically ~**5 minutes** stale.

---

## Control endpoints

```http
POST /v2/api/atRead
{ "inverterSn": "<SN>", "cid": "<id>" }

POST /v2/api/control
{ "inverterSn": "<SN>", "cid": "<id>", "value": "<new>", "yuanzhi": "<previous raw>" }

POST /v2/api/atReadSAPN   # batch read
POST /v2/api/result       # async order status (some writes)
```

### `yuanzhi` (read-then-write)

Many bitfield CIDs require the **previous raw register value** as `yuanzhi`. Omitting it often yields:

```json
{ "code": "B0218", "msg": "This command needs to be read and then set" }
```

Rule: **atRead first → use returned value as `yuanzhi` → control with new `value`.**

For single-bit switches on a shared register, `value` is usually `"0"`/`"1"` for that bit’s on/off, while `yuanzhi` is the **full decimal word**. Do not write `"1"` as if it replaced the entire register.

---

## Architecture on this host

| Layer | Path | Role |
|-------|------|------|
| `services/solis-control.nix` | systemd on `nhtpc` | Runs `solis-control` MQTT bridge |
| `pkgs/solis-control.nix` | `nathan-gs/solis-control` v0.3.1 | Cloud `atRead` / `control` + HA MQTT discovery |
| HA numbers | `number.solar_battery_*` | Written by automations in `smarthome/energy/solar/battery.nix` |
| Local scrape | `smarthome/energy/solar/solis_local.nix` | Read-only `http://solis-s3wifi/inverter.cgi` |
| Telemetry | `solis-sensor` HA integration | SoC, power, PV strings, etc. |

Flow:

```
HA automation → number.solar_battery_*/set
             → MQTT solar/battery/…/set
             → solis-control → SolisCloud /v2/api/control
```

---

## Live plant state (widget dumps 2026-08)

Battery model: **PYLON_LV** (CID 155/156 = 1).  
Capability flags: **6798 = 0**, **9026 = 0** → **legacy** TOU path (not “new optimised earnings” 6+6 slots).

### Battery floors / force-charge

| CID | Name | Register | Live | UI min–max | Notes |
|-----|------|----------|------|------------|--------|
| **158** (alias 7228) | Overdischarge SOC | 43011 | **15%** | 5–**40%** | Discharge floor. Must stay **above** force-charge |
| **160** | Forcecharge SOC | 43018 | **9%** | 4–**39%** | Grid “heal” floor when SoC drops to this |
| **9020** | Max grid power when force charging | 43027 | **300 W** | 300–5000 W | Caps grid draw during force-charge |
| **7691** | Max Charge SOC | 43010 | **100%** | 80–100% | Charge ceiling |

Solis notices:

- Overdischarge may not stick unless force-charge is lowered first.
- Force-charge and overdischarge are coupled: keep **forcecharge &lt; overdischarge** (HA already uses overdischarge − 1 on the morning charge path).

### Mode bitfield — register **43110**

Live raw word (as of 2026-08-14 capture): `yuanzhi = 3` → bits 0 and 1 set. **Changed 2026-08-20**: switched `select.system_house_pv_storage_mode` from Self-Use + TOU to plain **Self-Use** (TOU schedule was never configured — nothing in `battery.nix`/`capacity_peaks.nix` writes 43141–43169). Live raw word now `yuanzhi = 1`, bit 0 only.

| Bit | Meaning | Live | Self-use page CID | Feed-in page CID |
|-----|---------|------|-------------------|------------------|
| 0 | Self-use mode | **ON** | **466** | — |
| 1 | Time of Use | **OFF** (was ON) | **543** | **100** (if feed-in on) |
| 4 | Battery reserve | OFF | **4648** | **4635** |
| 5 | **Allow grid charging** | **OFF** | **109** | **141** |
| 6 | Feed-in priority | OFF | — | **142** |
| 7 | (related peak-shave flags on other regs) | — | — | — |

Also on 43110 family (from xlsx / UI): night overdischarge hold, dynamic force-charge regulation, peak-shaving mode, etc. Full bit map also documented as CID **636** “Storage Inverters Control Switching” in the official xlsx.

**Mode exclusivity (Solis):** Self-use, feed-in priority, peak-shaving, and off-grid cannot all be off. Enabling another primary mode auto-disables self-use. **Keep self-use on** for this house.

### TOU charge / discharge schedule

| | Self-use path (use this) | Feed-in path (do not dual-write) |
|--|--------------------------|----------------------------------|
| Composite CID | **4643** | **4656** |
| Register block | **43141**, 30 registers | same block |
| Shown when | Self-use + TOU on, 6798 ≠ 43605 | Feed-in + TOU on, 6798 ≠ 43605 |
| New UI (unused here) | 6209 if 6798=43605 | 6210 if 6798=43605 |

**4643 / 4656 field layout** (widgetType 9 composite, up to 3 slots):

1. TOU charge current (A, 0–100)  
2. TOU discharge current (A, 0–100)  
3. Charge time slot 1 (begin–end)  
4. Discharge time slot 1 (begin–end)  
5–6. Charge / discharge current 2 (A, 0–70)  
7–8. Charge / discharge time slot 2  
9–10. Charge / discharge current 3  
11–12. Charge / discharge time slot 3  

Write value is a **comma-separated string** (same family as Solis demo for CID 103), e.g.:

```text
30,30,01:00-05:00,17:00-21:00,0,0,00:00-00:00,00:00-00:00,0,0,00:00-00:00,00:00-00:00
```

Always **atRead 4643** before writing; confirm exact field order against the live string.

### Grid connection / export limits (widget dump 2026-08)

Grid-code and feed-in control page (`pid` 4614 / 470). **Do not casually write grid code or neutral connection** — compliance / wiring settings.

| CID | Name | Register | Live | Range / menu | Notes |
|-----|------|----------|------|--------------|--------|
| **471** | Grid Code | write 43068 / read 33092 | **C10/11** (`yuanzhi` **46**) | country codes | Belgian C10/11 — leave alone |
| **4615** | Feed in Power Limit Switch | 43073 bit **4** | **OFF** (0) | 0/1 | Enables export power cap |
| **697** | Feed in Power Limit Value | 43074 | **0 W** | 0–9900 W, **multiple of 100** | Max export at PoC when 4615 on |
| **4618** | Feed in Current Limit Value | 43326 | **0 A** | 0–52 A | Max export current at PoC |
| **9008** | Export Calibration | 43195 | 0 W | −1000…1000 | Only if capability **9026 = 43605** (we have 0) |
| **8058** | Grid Neutral Connection | 43302 bit 8 | menu Connected=0 | Connected/Disconnected | Live `currentValue` 0 = Connected; `yuanzhi` 1 may be raw bitfield — treat carefully |
| **6964** | Unbalance Output | 43073 bit **6** | OFF | needs N-line connected | 3φ / split-phase; N/A for typical 1φ home |
| **9921** | Single phase power grid connection | 44207 | 0 | gated by other CIDs | Feature-flagged UI |
| **274** | Inverter phase (逆变器相位) | — | **1** | — | Phase index; leave alone |
| **7799** | (unnamed bit) | 33097 bit 1 | 0 | — | Status-like |

**Live summary:** export limiting is **off** (4615=0, limit values 0). Grid code is correctly **C10/11** for Belgium/Flanders.

**When export limit is useful:**

- Injection → €0 or negative, or curtailment fees  
- Avoiding export during very low Belpex (optional)  
- Hard local rules (e.g. max kW at connection)

To enable a e.g. 0 W hard zero-export (if ever desired):

1. Set **697** (and/or **4618**) to the limit (multiples of 100 W for 697)  
2. Turn **4615** ON with proper `yuanzhi` on reg 43073  

Note: xlsx also lists CID **499** / **696** as system export power limit — **697** is what this plant’s UI exposes for the W setpoint; prefer atRead on 697/4615 before writing.

### G100 / backflow (widget dump 2026-08)

UK-style **ENA G100** export / reverse-power controls (`pid` 509). Visible when N-line is connected (8058) and phase is not the special case `274=3`. **Not required under Belgian C10/11** for this plant; leave off unless a DNO/installer demands it.

| CID | Name | Register | Live | Notes |
|-----|------|----------|------|--------|
| **5064** | G100 Switch | 43426 bit **2** | **Disable (0)** | Master enable |
| **5065** | G100 Backflow Current | 43300 | **0 A** | Max reverse/export current when G100 on |
| **7538** | G100 Manual Fault Clearing | 43378 | **OFF (0)**; ON=`3` | Clear G100 trip; only when Vref-time (4804) is 0 |
| **4804** | Vref-time | — | **0** s (UI range 300–5000 if used) | Interlock for manual clear |
| **4824–4826**, **12632** | unnamed / capability | 34800–34804 | 0 | Status / feature flags (also gate other UI rules); not day-to-day controls |

**Live summary:** G100 fully **off**. Prefer the general feed-in limit (**4615** + **697**/**4618**) for any future Belgian export capping; do not enable G100 unless documentation for your connection requires it.

### Other relevant CIDs (not all wired)

| CID | Name | Notes |
|-----|------|--------|
| 157 / 4649 / 4636 | Reserved SOC | Only if reserve switch on (min 15%) |
| 10462 / 4632 | Peak-shaving switch | Needs Li + BMS comms; currently off |
| **4615** + **697** / **4618** | Feed-in power/current limit | See grid page above; currently off |
| **5064** / **5065** / **7538** | G100 switch / backflow A / fault clear | UK G100; currently off — not for BE C10/11 |
| 376 | Max inverter output % | Demo uses 80% |
| 52 / 54 | Inverter ON / OFF | Values 190 / 222 |
| 6972 | Charge+discharge one-shot (newer) | Up to 6+6 slots; not our 6798 path |
| 5916–5986 | Per-slot TOU CIDs | Newer firmware family |

---

## What is already steered (`solis-control` v0.3.1)

| MQTT / HA entity | CID in script | Live UI CID / reg | Script limits | Inverter UI limits |
|------------------|---------------|-------------------|---------------|--------------------|
| `number.solar_battery_overdischargesoc` | **158** | 158 / 43011 | ≤ **40%** | 5–40% |
| `number.solar_battery_forcechargesoc` | **160** | 160 / 43018 | ≤ **20%** (script) | 4–**39%** |
| `number.solar_battery_maxgridpower` | **676** | **9020** / 43027 | 300–5000 W | 300–5000 W |

Stubs present but **not implemented** (or broken on B0218):

| MQTT topic | Intended CID | Status |
|------------|--------------|--------|
| `solar/selfuse/AllowGridCharging/set` | **109** | Needs read-then-set + `yuanzhi` |
| `solar/selfuse/ChargeAndDischarge/set` | **4643** | Stub only (“not implemented yet”) |

### Important: two different “caps”

| Cap | Source | Effect |
|-----|--------|--------|
| Forcecharge SOC max **~39–40%** | Solis UI / cloud | Official limit on CID 160 |
| Forcecharge SOC max **20%** | `solis-control` MQTT validation + HA discovery | **Self-imposed**; can be raised to match UI if desired |
| Overdischarge max **40%** | Solis UI | Official limit on CID 158 |

Raising force-charge toward 39% only widens the **heal / floor** band; it does **not** fill the battery to 90% from the grid. Full night fill needs **TOU + Allow Grid Charging**. Plant recipe (HA entities, capaciteitstarief, restore): [[battery-grid-charge-to-100]].

---

## Force-charge vs TOU (do not confuse)

| Mechanism | Purpose | Grid fill amount | Power limit |
|-----------|---------|------------------|-------------|
| **Forcecharge SOC (160)** + max grid W (9020) | Protect battery: if SoC hits floor, pull grid to heal | Only up to ~forcecharge…overdischarge band | 9020 (live **300 W**) |
| **TOU schedule (4643)** + **Allow grid charge (109)** | Economic charge/discharge windows | Up to Max Charge SOC / full usable pack | TOU charge current (A) |

With live values (force 9%, overdischarge 15%, 300 W):

- Usable force-charge band ≈ **6% of pack** → ~0.6 kWh on 10 kWh  
- Not meaningful for winter arbitrage  
- **Allow Grid Charging is OFF** → TOU cannot grid-charge until bit 5 is set  

---

## Safe write recipes

### Allow Grid Charging (CID 109)

```json
// 1) atRead cid 109 or any 43110 bitfield CID → note yuanzhi (e.g. "3")
// 2) control:
{
  "inverterSn": "<SN>",
  "cid": "109",
  "value": "1",
  "yuanzhi": "3"
}
// Expected raw after: 3 | 32 = 35 (bits 0,1,5)
```

### TOU schedule (CID 4643)

```json
// 1) atRead cid 4643 → full current string as yuanzhi if required
// 2) control with new comma-separated schedule string
{
  "inverterSn": "<SN>",
  "cid": "4643",
  "value": "<chargeA>,<dischargeA>,HH:MM-HH:MM,HH:MM-HH:MM,..."
}
```

### Force-charge / overdischarge (already in production)

Order matters when raising floors: lower force-charge first if changing overdischarge upward fails; keep force &lt; overdischarge.

Prefer **self-use CIDs only** (466, 543, 109, 4643). Do not also write feed-in twins (142, 100, 141, 4656) for the same bits.

---

## Local / Modbus path

See **[[solis-modbus]]** for wiring the USB-RS485 adapter on the RHI-5K 4-pin COM, support vs `solis_modbus`, and how to drop SolisCloud.

- **Local logger:** `solis_local.nix` scrapes `inverter.cgi` — **read-only**, PV + temp only.  
- **Modbus (USB-RS485 on COM, stick unplugged):** same registers as the CIDs above (43011, 43018, 43027, 43110, …). This is a full local replacement for `solis-sensor` + `solis-control`.  
- Cloud UI max on force-charge (39%) is a **product limit**, not proven as a firmware absolute; Modbus may or may not allow higher — verify before relying on it.

---

## Recommended control roadmap

1. **atRead 4643** — capture live schedule string; document field order.  
2. Implement **109** with bit-preserving `yuanzhi` in `solis-control`.  
3. Implement **4643** write (and optional MQTT JSON → comma string).  
4. Optionally raise script force-charge max from 20 → **min(39, overdischarge−1)** to match Solis UI (still only a floor tool).  
5. Confirm whether CID **676** and **9020** are aliases for max grid power; prefer the ID that atRead returns on this SN.  
6. Keep peak-shaving / feed-in priority **off** unless a separate design needs them.  
7. Coordinate TOU grid charge power with **capaciteitstarief** and EV charging ([[ev-battery-peak-coordination]], [[car-charging-analysis]]) — night battery + car must share the 15‑min peak budget.  
8. Export limit (**4615** + **697**/**4618**) only if injection policy turns hostile; currently off, grid code C10/11 correct.

---

## References

- Platform API: <https://oss.soliscloud.com/templet/SolisCloud%20Platform%20API%20Document%20V2.0.3.pdf>  
- Device Control API: <https://oss.soliscloud.com/doc/SolisCloud%20Device%20Control%20API%20V2.0.pdf>  
- CID list: <https://oss.soliscloud.com/doc/SolisCloud_control_api_command_list.xlsx>  
- Bridge: <https://github.com/nathan-gs/solis-control>  
- Repo: `services/solis-control.nix`, `pkgs/solis-control.nix`, `smarthome/energy/solar/battery.nix`

# US5000 cell 12: knee-voltage imbalance is expected, not a fault

**Plant:** RHI-5K-48ES-5G + PYLON_LV (US5000 addr 2 + US3000C addr 3).
**Related:** [[battery-grid-charge-to-100]], [[battery-expansion-analysis]], `smarthome/energy/solar/pylontech.nix`.

## The pattern

Every time the pack approaches full (Solis SoC ≥ ~97 %), `sensor.pylontech_us5000_pack_2_cell_imbalance`
fans out to **90–130 mV**, driven almost entirely by cell 12 sagging below its neighbours
(`sensor.pylontech_us5000_pack_2_cell_min_voltage`). US3000C (pack 3) stays flat (single-digit mV)
through the same window. Once SoC comes back off the top under real load, imbalance collapses to
**~1 mV within the hour** — cell 12 tracks the others exactly at rest/under discharge.

This has been the same cell every time since first noticed (comment in `pylontech.nix:38`,
observed again 2026-08-26 and 2026-09-10). It is LFP knee behavior, not degradation:
the charge-voltage curve is razor-flat through the mid-range and goes near-vertical in the
last few %, so a cell with marginally lower capacity or slightly higher internal resistance
shows a disproportionately large *voltage* swing there for a negligible *capacity* difference —
and the same IR drop inflates the reading further under active charge current. Take away the
current (float or discharge) and the true rest-voltage spread is tiny.

## 2026-09-10 recorded trace (US5000 cell imbalance, mV)

```
10:00  ~2-3      SoC climbing, off the knee — normal
11:00  ~10
12:00  ~50       entering the knee
13:00  ~90-100
14:00  ~90-120   plateaued, oscillating, SoC ~98-99%
15:01  119       battery power down to 31 W (near float) — imbalance unchanged
15:31  107       still unchanged at near-float current
18:01  1.0       SoC 87%, battery power +453 W (discharging) — collapsed to 1 mV
```

The imbalance did **not** shrink while sitting at the top under trickle/float current — it only
collapsed once the pack came off the knee under real discharge load. That rules out "just needs
more absorb time" as the mechanism; it's charge-voltage/knee-position, not a slow-balancing
process that a longer soak would visibly improve.

## Is this something to worry about?

No, as observed so far. The signal that *would* be worrying is already what
`solar/battery/pylontech/alert.cell_imbalance` (pylontech.nix) watches for — imbalance
**> 40 mV while pack SoC is still < 90 %** (`cellImbalancePlateauSoc`). That is the "weak cell
emptying early / not actually reaching the top" case, and it has not fired for cell 12. What we
see instead is imbalance strictly confined to the ≥ 97 % knee, gone within an hour of coming off
it — exactly the case `alert.cell_imbalance`'s SoC-gated threshold is designed to *not* flag.

Worth re-checking if any of these change:
- Imbalance stops collapsing to single-digit mV at rest/under load (would mean real capacity
  loss on cell 12, not just knee geometry).
- The plateau alert (`< 90 % SoC`) actually fires for cell 12.
- `sensor.pylontech_us5000_pack_2_cell_min_voltage` starts dropping below
  `cellLowVoltageV` (3.05 V) while SoC is still moderate — the early-empty signal
  (`alert.cell_low`).
- The at-rest imbalance floor itself trends up over months (compare against this doc's
  2026-09-10 baseline of ~1 mV).

None of that has happened. This is filed as a known, benign, recurring pattern — not an
open issue.

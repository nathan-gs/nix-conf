# Audi A6 Sportback e-tron — EU Data Act data

Notes on the VW Group EU Data Act portal as a data source for the A6 (100 kWh performance
version, 94.9 kWh usable, PPE platform), and what a one-off **full export** taught us.

HA reads the portal through the `cupra_eu_data_act` custom component
(`pkgs/home-assistant/custom_components/vag-eu-data-act.nix`); its SoC lands in
`sensor.car_car_a6_battery` and feeds `system/car_charger/audi_soc` in
`smarthome/car/car_charger/tuya.nix`.

| Doc | Contents |
|---|---|
| [feed-delay-2026-10.md](feed-delay-2026-10.md) | The October 2026 backlog: ~30–48 h late data after 4 days offline, why it does not catch up |
| [battery-and-charging.md](battery-and-charging.md) | Capacity table, kWh per % calibration, battery-health indicators, consumption, charging behaviour |
| [dataset-schema.md](dataset-schema.md) | What the 15-min datasets and the full export contain, and their quirks |
| [scripts/](scripts/) | Analysis scripts to re-run on the next full export (baseline comparison) |

## Key insights

- **Two different products.** The 15-min datasets are small (~3 KB, 67 snake_case fields: SoC,
  range, mileage, locks, tyres, maintenance). The full export (requested once, 2026-10-26) is a
  30 MB JSON with ~212k values of history back to 2026-03-20, charge sessions with power curves,
  daily charged energy and the car's charge-planner settings. **Only the full export carries the
  battery capacity table.**
- **The backend has fresh data; the 15-min feed does not.** The full export held a status of
  **77 %** captured ~11 h before it was generated, while the 15-min feed was ~39 h behind at the
  same moment. After the car spent 4 days without signal the feed drains only **~15–23 records/h**,
  less than the car produces (~15–60/h), so the delay grows instead of shrinking. Recreating the
  portal subscription does not help: the new one continues the same backlog.
- **Use `data_captured_at`, not `last_updated`.** Each value is a genuine reading delivered late, so
  HA's state change time says nothing about its age.
- **Calibration: ~1.1 kWh at the home pole per 1 % SoC.** The car's own per-session charged energy
  matches the pole meter within its 0.5 kWh resolution; long home sessions give 1.07–1.13 kWh/%.
- **Capacity table reads 91.55 kWh at 100 %** — 96.5 % of the 94.9 kWh spec. A single, first
  reading in late October, possibly a planner model value and likely temperature dependent, so not
  proof of 3.5 % degradation. Repeat the full export in winter and summer and compare.
- **Usage is battery-friendly:** 37.5 equivalent full cycles in 7 months, SoC mostly 50–80 %,
  fast charging on only 6 days, battery care on throughout, no measurable parked drain.
- **Battery care caps at 80 %.** A "100 % for a long drive" charge plan only works with battery care
  switched off in the car.
- **No live SoC source exists besides the portal.** Audi Connect fails auth upstream, and the HA
  companion app car sensors (Android Auto, and the app on the MMI) stay empty even with car
  permissions granted — the A6 does not share car data with third-party apps.

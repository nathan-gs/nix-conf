# EU Data Act dataset schema

Both formats are a zip holding one JSON object `{ vin, userId, Data: [ … ] }`, where each element of
`Data` is `{ key, dataFieldName, value, timestampUtc }`. Values are strings. **The zip names and the
top-level fields carry the VIN and user id — never commit a raw dataset.**

## 15-minute datasets

- ~3 KB, one snapshot, **67 fields**, snake_case names.
- Families: `state_of_charge`, `cruising_range_*`, `mileage`, `cycle_data_mileage`, `bem_level`,
  `outside_temperature`, `fuel_level_*`, `locked_state_*` / `open_state_*` / `safe_state_*` (doors,
  bonnet, tailgate), window lifters, sunroof, spoiler, service hatch, parking brake/lights,
  `tyre_pressure_{actual,required,differential}_*`, `maintenance_interval_*`,
  `active_warnings_in_instrument_cluster_*`.
- No battery-health, capacity, cell or battery-temperature field.
- A new subscription starts with an almost empty file.
- HA's integration caches the last ~10 under `/var/lib/hass/cupra_eu_data_act_cache/`.

## Full export (one-off)

- 30 MB JSON, ~212,000 values, camelCase names, history from 2026-03-20.

| Family | Records | Span | Notes |
|---|---:|---|---|
| `currentSOCInPct` | 26,177 | 03-20 → 10-25 | SoC time series |
| `chargingState`, `chargePowerInKW`, `chargeType`, `chargeMode`, `chargingSettings`, `cruisingRangeElectricInKm` | ~17,800 each | 03-20 → 10-25 | Charging time series |
| `remainingChargingTimeToCompleteInMin`, `chargeRateInInKMPH` | ~15–17k | 03-20 → 10-25 | |
| `plugConnectionState`, `plugLockState`, `externalPower` | 7,253 each | 03-20 → 10-25 | |
| `timeInCar` | 8,811 | 03-20 → 08-13 | Stops in August |
| `climatisationState`, `climatisationTrigger`, `remainingClimatisationTimeInMin` | ~2,490 | 03-20 → 10-24 | |
| `batteryCareMode` | 1,597 | 03-20 → 08-13 | `activated` / `invalid` (asleep) |
| `mileage` | 488 | 10-15 → 10-24 | Only the last ~10 days |
| `chargingSession.[n].*` | 68 sessions | 09-11 → 10-25 | start/stop, `deltaSoc`, `endSoc`, `peakChargePower`, AC/DC |
| `powerCurve.[n].timeCurve.[m].*` | 1,500 points | per session | `soc`, `chargePower`, `deltaChargeEnergy` (0.5 kWh steps) |
| `aggregation.day.[n]` / `.month` | 43 days | | daily `chargedEnergy` |
| `energyContentOverSOC.[n]` | 6 points | snapshot | capacity table — **only here** |
| `chargingConnectors.[n]` | 3 | snapshot | AC3 10.5 kW, DC 350 kW (stations > 500 V), DC 131.7 kW (stations ≤ 500 V); efficiency 0.92, base load 0.4 kW |
| latest status block | | snapshot | `batteryStatus.*`, `chargingStatus.*`, `plugStatusItem.*`, `ChargingEvent.*`, care mode + threshold, timers, `vehicleError.*` |
| `inspectionDueDays` | 14 | | 596–705 days |

## Quirks

- Session and power-curve records have `timestampUtc` around **1970-01-21** (epoch seconds read as
  milliseconds); their *values* carry the real ISO timestamps.
- `invalid` in a state series means the car was asleep, not a fault.
- Some status records have `timestampUtc` `null` or `N/A`.
- Energy values in power curves have 0.5 kWh resolution — short sessions are dominated by rounding.
- Status blocks repeat `vehiclePlatform` as `PPE` or `UNKNOWN` depending on the report type.

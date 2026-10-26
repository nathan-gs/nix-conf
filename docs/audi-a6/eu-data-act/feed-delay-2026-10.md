# EU Data Act feed delay — October 2026

## Symptom

`sensor.car_car_a6_battery` showed 68 % while the car was at 77 %. Every 15-min dataset downloaded
fine (`integration_status: ok`, no server errors), but the vehicle data inside was more than a day
old. The overnight charge logic therefore acted on yesterday's SoC; the override had to be set to
`off` by hand.

## Timeline

| Period | Feed behaviour |
|---|---|
| until 2026-10-20 | Normal: data ~20–30 min old on arrival |
| 2026-10-20 → 10-23 | Car parked 4 days underground, no signal. Feed delivered nothing new; HA kept showing the last value (68 %) |
| 2026-10-25 01:17 UTC | Feed resumes, replaying old data in order, ~30 h late |
| 2026-10-25 20:02 | 34 h behind |
| 2026-10-26 11:55 | ~48 h behind; no new vehicle data at all for the previous 8 h while files kept arriving |

Delay on arrival, from the `data_captured_at` attribute:

| HA received (UTC) | Vehicle data from | Behind |
|---|---|---|
| 10-25 01:17 | 10-23 19:30 | 29.8 h |
| 10-25 11:32 | 10-24 08:00 | 27.5 h |
| 10-25 16:16 | 10-24 09:16 | 31.0 h |
| 10-25 20:02 | 10-24 10:01 | 34.0 h |
| 10-26 04:01 | 10-24 12:14 | 39.8 h |
| 10-26 11:52 | 10-24 12:14 | 47.6 h |

## Why it does not catch up

The feed drains a roughly fixed number of **records** per hour, not a fixed span of car time:

| Feed window | Vehicle-time span replayed | Records in that span | Rate |
|---|---|---|---|
| 8.4 h | 10-23 20:55 → 10-24 08:00 | 195 | 23 /h |
| 4.7 h | 10-24 08:00 → 09:16 | 67 | 14 /h |
| 11.75 h | 10-24 09:16 → 12:14 | 233 | 20 /h |

The car normally produces 350–1,470 records a day (~15–60 /h), and the day the backlog sits in
(10-24, plugged in and charging most of the day) was one of the busiest at 1,139. So busy stretches
replay at a few minutes of car time per file, quiet stretches faster, and on average the backlog
grows. At the time of the full export ~989 records were still queued before reaching data the
backend already held, i.e. ~50 h of work at that rate. Before the outage the same feed ran ~25 min
behind, so this is degraded throughput, not a design limit.

## What was tried

- **Recreating the portal subscription** (delete + new one): the integration followed the new data
  request automatically (it logs `Data-request identifier changed … Updating the config entry`), the
  first file was almost empty, and the next one continued exactly where the old subscription stopped
  (10-24 09:06 → 09:16). The backlog belongs to the vehicle's data in the backend, not to a
  subscription.
- **Audi Connect** as a fallback: auth errors upstream.
- **HA companion app car sensors** (Android Auto on a phone, and the app installed on the MMI):
  every car sensor stays `unavailable`, even `car_name`, with car permissions granted. Ignored in
  `unavailable_entities` (`smarthome/ha/default.nix`).
- **One-off full export:** contained a status from 10-25 15:28 (SoC 77 %), ~11 h old when generated,
  while the 15-min feed was ~39 h behind at the same moment. Proof the backend has the data.

## Evidence for VW Group support

- Delay started after the vehicle was without mobile coverage 2026-10-20 → 10-23.
- Since then every dataset is 27–48 h behind and the delay grows.
- A freshly created subscription continued the same backlog.
- A full export generated 2026-10-26 02:49 UTC held vehicle status from 2026-10-25 15:28 UTC, while
  the 15-min datasets at the same time only reached 2026-10-24 11:53 UTC.

## Implications for HA

- A held reading's age is only knowable from `data_captured_at`. `audi_soc` currently treats any
  value as live.
- Options discussed, not built (see memory / later decision):
  - staleness guard — if the car was unplugged from the home pole since `data_captured_at`, treat the
    SoC as unknown and use the existing 50 % fallback;
  - charger-kWh proxy — while the car stays plugged in since the reading, add pole kWh / ~1.1;
  - post-drive notification asking the SoC (50/60/70 %) as the anchor for that proxy.
- A proxy without a fresh anchor is worse than the stale value: pole kWh cannot see driving. On
  10-25 it would have read ~93 % against a real 77 %.

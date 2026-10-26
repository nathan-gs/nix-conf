# Analysis scripts

Run against the JSON inside a full EU Data Act export. Unzip it into its own empty directory
**outside this repo** (the file carries the VIN and user id), then:

```sh
nix-shell -p python3 --run 'python3 -I sessions.py /path/to/export.json'
nix-shell -p python3 --run 'python3 -I health.py /path/to/export.json'
```

- `sessions.py` — one line per charge session: start/stop, AC/DC, SoC gained, peak power, the car's
  own charged energy and kWh per %.
- `health.py` — time at SoC bands per month, equivalent full cycles, displayed range per %, AC/DC
  charge power, battery-care samples, the capacity table, long parked gaps, drive consumption.

Compare the output with [../battery-and-charging.md](../battery-and-charging.md) (baseline from the
2026-10-26 export). The parked-gap list also catches gaps that include charging — a SoC that went up
is not drain.

"""Battery-health and usage indicators from an EU Data Act full export.

Usage: python3 -I health.py <export.json>
"""
import json, re, sys, statistics as st
from collections import defaultdict
from datetime import datetime, timezone

data = json.load(open(sys.argv[1]))["Data"]

def ts(s):
    try:
        return datetime.fromisoformat(s.replace("Z", "+00:00"))
    except Exception:
        return None

series = defaultdict(list)
for r in data:
    f = r["dataFieldName"]
    if f in ("currentSOCInPct", "cruisingRangeElectricInKm", "chargingState", "chargePowerInKW",
             "chargeType", "plugConnectionState", "climatisationState", "batteryCareMode",
             "mileage", "timeInCar", "externalPower", "chargeMode"):
        t = ts(r.get("timestampUtc") or "")
        if t and t.year > 2000:
            series[f].append((t, r["value"]))
for k in series:
    series[k].sort()

soc = [(t, float(v)) for t, v in series["currentSOCInPct"]]
rng = dict((t, float(v)) for t, v in series["cruisingRangeElectricInKm"])

print("== SoC series:", soc[0][0], "->", soc[-1][0], len(soc), "points")

# 1. time-weighted SoC distribution, per month
bands = [(0, 20), (20, 50), (50, 80), (80, 90), (90, 101)]
dist = defaultdict(lambda: defaultdict(float))
for (t0, s0), (t1, _) in zip(soc, soc[1:]):
    dt = (t1 - t0).total_seconds() / 3600
    if dt > 24 * 5:
        continue
    m = t0.strftime("%Y-%m")
    for lo, hi in bands:
        if lo <= s0 < hi:
            dist[m][(lo, hi)] += dt
print("\n== time at SoC band (% of covered hours) per month")
print("month     hours   <20   20-50  50-80  80-90  >=90   min  max")
mins = defaultdict(lambda: 101); maxs = defaultdict(lambda: -1)
for t, s in soc:
    m = t.strftime("%Y-%m"); mins[m] = min(mins[m], s); maxs[m] = max(maxs[m], s)
for m in sorted(dist):
    tot = sum(dist[m].values())
    print(f"{m}  {tot:6.0f}  " + "  ".join(f"{100*dist[m][b]/tot:5.1f}" for b in bands) + f"  {mins[m]:4.0f} {maxs[m]:4.0f}")

# 2. equivalent full cycles: sum of SoC increases
up = defaultdict(float)
for (t0, s0), (t1, s1) in zip(soc, soc[1:]):
    if s1 > s0:
        up[t1.strftime("%Y-%m")] += s1 - s0
print("\n== SoC % added per month (100 = 1 equivalent full cycle)")
for m in sorted(up):
    print(m, f"{up[m]:6.0f}  ->  {up[m]/100:4.1f} cycles")
print("total", f"{sum(up.values())/100:.1f} equivalent full cycles since", soc[0][0].date())

# 3. range per % (km per 1% SoC), monthly median, only SoC >= 30 to avoid low-SoC buffer effects
kmpp = defaultdict(list)
for t, s in soc:
    if t in rng and s >= 30:
        kmpp[t.strftime("%Y-%m")].append(rng[t] / s)
print("\n== displayed range per 1% SoC (monthly median; reflects recent consumption/temperature)")
for m in sorted(kmpp):
    v = kmpp[m]
    print(m, f"{st.median(v):5.2f} km/%   -> implies {st.median(v)*100:4.0f} km at 100%   (n={len(v)})")

# 4. charging: AC vs DC power
pw = [(t, float(v)) for t, v in series["chargePowerInKW"] if v not in ("", None)]
ct = dict(series["chargeType"])
dc = [(t, p) for t, p in pw if ct.get(t, "").lower() == "dc" and p > 0]
ac = [p for t, p in pw if ct.get(t, "").lower() == "ac" and p > 0]
print("\n== charge power")
print("AC samples", len(ac), "median", st.median(ac) if ac else None, "max", max(ac) if ac else None)
dcdays = sorted({t.date() for t, _ in dc})
print("DC samples", len(dc), "on days", [str(d) for d in dcdays], "max", max((p for _, p in dc), default=None))

# 5. battery care mode ("invalid" = car asleep) and the capacity table (full export only)
care = defaultdict(int)
for _, v in series["batteryCareMode"]:
    care[str(v).lower()] += 1
print("\n== batteryCareMode samples:", dict(care))
table = defaultdict(dict)
for r in data:
    m = re.match(r"energyContentOverSOC\.\[(\d+)\]\.(\w+)", r["dataFieldName"])
    if m:
        table[int(m[1])][m[2]] = float(r["value"])
print("\n== capacity table (energyContentOverSOC) — compare with the 2026-10-26 baseline: 91.55 kWh at 100 %")
for i in sorted(table):
    row = table[i]
    print(f"{row.get('stateOfChargeInPercent', 0):5.0f} %  {row.get('stateOfChargeInkWh', 0):7.2f} kWh")

# 6. long gaps with no SoC change and no charging (parked drain)
print("\n== parked drain: intervals >= 24h between consecutive SoC points, or long flat runs")
for (t0, s0), (t1, s1) in zip(soc, soc[1:]):
    h = (t1 - t0).total_seconds() / 3600
    if h >= 24:
        print(t0.strftime("%Y-%m-%d %H:%M"), "->", t1.strftime("%Y-%m-%d %H:%M"), f"{h:5.0f} h", f"{s0:.0f}% -> {s1:.0f}%")

# 7. consumption from mileage + SoC drops (Oct only, mileage series)
mil = [(t, float(v)) for t, v in series["mileage"]]
print("\n== consumption: drives (mileage increase) with SoC drop, Oct")
def soc_at(t):
    best = None
    for tt, s in soc:
        if tt <= t: best = s
        else: break
    return best
# group mileage points into drives separated by >= 30 min with no mileage change
drives = []
cur = None
for t, km in mil:
    if cur and km > cur["km1"] and (t - cur["t1"]).total_seconds() < 3600:
        cur["t1"], cur["km1"] = t, km
    elif cur and km == cur["km1"]:
        cur["t_last_same"] = t
    else:
        if cur: drives.append(cur)
        cur = dict(t0=t, km0=km, t1=t, km1=km)
if cur: drives.append(cur)
tot_km = tot_pct = 0
for d in drives:
    km = d["km1"] - d["km0"]
    s0, s1 = soc_at(d["t0"]), soc_at(d["t1"])
    if km >= 10 and s0 is not None and s1 is not None and s0 > s1:
        pct = s0 - s1
        tot_km += km; tot_pct += pct
        print(d["t0"].strftime("%m-%d %H:%M"), "->", d["t1"].strftime("%H:%M"), f"{km:5.0f} km  {s0:.0f}->{s1:.0f}%  {pct*0.92/km*100:5.1f} kWh/100km (at ~0.92 kWh/%)")
if tot_km:
    print(f"total {tot_km:.0f} km, {tot_pct:.0f}%  ->  {tot_pct*0.92/tot_km*100:.1f} kWh/100km, {tot_km/tot_pct:.2f} km/%")

# 8. climatisation usage
cl = series["climatisationState"]
on = [t for (t, v) in cl if str(v).lower() not in ("off", "invalid", "")]
print("\n== climatisation non-off samples:", len(on), "values:", sorted({v for _, v in cl}))

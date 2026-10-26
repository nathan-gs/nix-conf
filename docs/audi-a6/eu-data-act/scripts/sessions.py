"""Per-session table (SoC gained, car-measured energy, kWh per %) from an EU Data Act full export.

Usage: python3 -I sessions.py <export.json>
"""
import json, re, sys
from collections import defaultdict

data = json.load(open(sys.argv[1]))["Data"]
sess = defaultdict(dict)
curve = defaultdict(lambda: defaultdict(dict))
curve_sid = {}
for r in data:
    f = r["dataFieldName"]
    m = re.match(r"chargingSession\.\[(\d+)\]\.(\w+)", f)
    if m:
        sess[int(m[1])][m[2]] = r["value"]
        continue
    m = re.match(r"powerCurve\.\[(\d+)\]\.sessionId", f)
    if m:
        curve_sid[int(m[1])] = r["value"]
        continue
    m = re.match(r"powerCurve\.\[(\d+)\]\.timeCurve\.\[(\d+)\]\.(\w+)", f)
    if m:
        curve[int(m[1])][int(m[2])][m[3]] = r["value"]

by_sid = {}
for ci, pts in curve.items():
    pts = [pts[k] for k in sorted(pts)]
    e = [float(p.get("deltaChargeEnergy", 0)) for p in pts]
    socs = [int(float(p["soc"])) for p in pts if "soc" in p]
    by_sid[curve_sid.get(ci)] = dict(n=len(pts), esum=sum(e), emax=max(e) if e else 0,
                                    soc0=socs[0] if socs else None, soc1=socs[-1] if socs else None,
                                    pmax=max(float(p.get("chargePower", 0)) for p in pts))

print("start                stop                 type  dSoc endSoc  peakkW  curve:n  sum(dE)  max(dE)  soc0->soc1  kWh/%")
for i in sorted(sess, key=lambda i: sess[i].get("startChargingTimestamp", "")):
    s = sess[i]
    c = by_sid.get(s.get("sessionId"), {})
    d = int(float(s.get("deltaSoc", 0)))
    e = c.get("esum", 0)
    print(f"{s.get('startChargingTimestamp','?'):20} {s.get('stopChargingTimestamp','?'):20} {s.get('chargeType','?'):4} {d:5} {s.get('endSoc','?'):>6} {float(s.get('peakChargePower',0)):7.1f} {c.get('n',0):8} {e:8.2f} {c.get('emax',0):8.2f}  {c.get('soc0')}->{c.get('soc1')}  {e/d if d else float('nan'):6.2f}")

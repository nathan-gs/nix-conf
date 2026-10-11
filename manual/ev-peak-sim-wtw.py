import random

import importlib.util, os
spec = importlib.util.spec_from_file_location("sim", os.path.join(os.path.dirname(os.path.abspath(__file__)), "ev-peak-sim.py"))
sim = importlib.util.module_from_spec(spec); spec.loader.exec_module(sim)

def wtw(seed, extra=()):
    base = sim.with_events(seed, list(extra))
    rnd = random.Random(seed)
    # WTW pre-heater: 500 W for 30 s, every 120-180 s, all night
    on = set()
    t = 0
    while t < sim.NIGHT_S:
        for k in range(30):
            on.add(t + k)
        t += rnd.randint(120, 180)
    return lambda t: base(t) + (500 if t in on else 0)

# late jumps: 2 kW starting at minute 12 of a quarter, 6-10 min, several times a night
late = [(q * 900 + 720, 480, 2.0) for q in (4, 9, 14, 19, 24, 29)]
cases = [
    ("WTW cycling, battery 40%", lambda: wtw(11), 40),
    ("WTW cycling, battery 15%", lambda: wtw(11), 15),
    ("WTW + 6 late 2 kW jumps, battery 40%", lambda: wtw(12, late), 40),
    ("WTW + 6 late 2 kW jumps, battery 15%", lambda: wtw(12, late), 15),
]
print("| scenario | design | car kWh | min at 6A | max quarter kW | new peak | quarters > 2.56 | current changes | stops | battery min % |")
print("|---|---|---|---|---|---|---|---|---|---|")
for name, fn, soc in cases:
    for d in ('A', 'C', 'F'):
        r = sim.Sim(d, fn(), soc).run()
        print(f"| {name} | {d} | {r['car_kwh']:.1f} | {r['min6']:.0f} | {r['max_q']:.2f} | {r['new_peak']:.2f} | {r['over']} | {r['changes']} | {r['stops']} | {r['min_soc']:.1f} |")

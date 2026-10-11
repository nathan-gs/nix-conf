"""Night-time EV charging vs house battery vs capaciteitstarief peak — 1 s time-step sim.

Designs:
  A  before today (9fcd373): headroom from 15m estimate, 6A tail at banked >= max(2.3, peak-0.5),
     60s debounce, capacity_critical stop, force-charge 7%.
  B  main now: A + battery discharge counted while peak-shaving, tail at max(2.1, peak-0.8) -> 8A
     (6A if 8A would cross battery trigger), 30s debounce, force-charge 8%.
  C  single rule (tuya.nix capacity_headroom_current): run `allowed` for 2 min then 8A to the end
     of the quarter on target = peak - 0.1, capped at steady+0.5kW, 6A only if 8A would breach;
     capacity_pause (6A would breach, or battery peak-shaving and discharging; delay_off 5min),
     30s debounce, force-charge 8%.
Usage: python3 ev-peak-sim.py [det|mc|all] [nights]
Battery logic (battery.nix overdischargesoc_target) is identical in all three.
"""
import random, math, sys
from collections import deque

V = 230
STEPS = [6, 8, 10, 13]          # auto mode cap 13A
CAP_WH = 8300                   # US5000 + US3000C, ~83 Wh / %
INV_MAX_W = 3000                # observed ~2.9 kW discharge 2026-10-10
NIGHT_S = 9 * 3600              # 22:00 -> 07:00


def quantize(a):
    s = [x for x in STEPS if x <= a]
    return max(s) if s else STEPS[0]


class Sim:
    def __init__(s, design, house_fn, soc0, peak0=2.56, car_need_kwh=45, forced_floor=None,
                 start_s=0):
        s.d = design
        s.house_fn = house_fn
        s.soc = soc0                       # true SoC %
        s.peak = peak0
        s.peak0 = peak0
        s.car_need = car_need_kwh * 1000 * 3600  # J
        s.forced_floor = forced_floor or (lambda t: None)
        s.force_soc = 7 if design == 'A' else 8
        s.debounce = 60 if design == 'A' else 30
        # state
        s.sw_on = False; s.I = 8; s.car_ramp_t = None
        s.target = 8; s.target_changed = 0; s.target_fired = True
        s.auto_running = False; s.next_step = None
        s.banked_j = 0.0; s.carq_j = 0.0; s.car_peaks = 0
        s.grid_hist = deque([0.0] * 60, maxlen=60)
        s.batt_hist = deque([0.0] * 10, maxlen=10)   # battery power sensor lag ~10s
        s.soc_sensor = int(soc0); s.soc_sensor_t = 0
        s.floor = 20
        s.pause = False; s.pause_ok_since = None
        s.should_prev = False; s.stop_at = None
        s.near_prev = False
        s.recover = False
        # metrics
        s.car_j = 0.0; s.batt_out_j = 0.0; s.min_soc = soc0
        s.quarters = []; s.changes = 0; s.stops = 0; s.starts = 0; s.s6 = 0; s.net_j = 0.0
        s.car_w = 0.0; s.grid_w = 0.0; s.batt_w = 0.0

    # ---------- sensors ----------
    def left(s, t):
        return 900 - (t % 900)

    def banked(s, t):
        return s.banked_j / 900 / 1000 / 1  # kW·quarter: J / (900 s) / 1000 -> kW avg so far x fraction

    def mean1m(s):
        return sum(s.grid_hist) / len(s.grid_hist) / 1000

    def batt_sensor_kw(s):
        return s.batt_hist[0] / 1000      # +discharge

    def estimated(s, t):
        return s.banked(t) + s.mean1m() * s.left(t) / 900

    # ---------- battery.nix (unchanged in all designs) ----------
    def battery_floor(s, t):
        f = s.forced_floor(t)
        if f is not None:
            return f
        p15 = s.banked(t); est = s.estimated(t)
        near = max(2.2, s.peak - 0.3); thr = max(2.5, s.peak - 0.1)
        if p15 > near and est > thr:
            return 8
        if s.car_w > 20:
            return 20
        return 15 if s.soc_sensor < 12 else 20

    # ---------- car headroom per design ----------
    def headroom(s, t):
        peak = max(2.5, s.peak); car_kw = s.car_w / 1000
        peak_shaving = s.floor < 15
        batt_kw = max(0, s.batt_sensor_kw()) if peak_shaving else 0
        if s.d == 'A':
            if s.banked(t) >= max(2.3, s.peak - 0.5):
                return 6
            return round((peak - (s.estimated(t) - car_kw)) * 1000 / V)
        if s.d == 'B':
            if s.banked(t) >= max(2.1, s.peak - 0.8):
                house = max(0, s.mean1m() - car_kw) + batt_kw
                proj8 = s.banked(t) + (house + 8 * V / 1000) * s.left(t) / 900
                return 8 if proj8 < max(2.5, s.peak - 0.1) else 6
            return round((peak - (s.estimated(t) - car_kw) - batt_kw) * 1000 / V)
        # C
        target = peak - 0.1
        left = s.left(t)
        banked = s.banked(t) if left < 870 else 0
        house = max(0, s.grid_w / 1000 - car_kw)
        # run `allowed` for the next h seconds (reaction window), then 8A to the end of the quarter
        h = min(left, 120)
        eight = 8 * V / 1000
        allowed = ((target - banked) * 900 - (house + eight) * (left - h)) / max(h, 60) - house
        allowed = min(allowed, target - house + 0.5)
        a = math.floor(allowed * 1000 / V)
        # 6A only as a last resort: if 8A to the end of the quarter still stays under the peak, use 8A
        if a < 8 and banked + (house + eight) * left / 900 <= peak:
            a = 8
        return a

    def near(s, t):
        if s.d == 'A':
            return s.banked(t) >= max(2.3, s.peak - 0.5)
        if s.d == 'B':
            return s.banked(t) >= max(2.1, s.peak - 0.8)
        return False

    def blocked(s, t, hr):
        if s.d in ('A', 'B'):
            left = s.left(t); banked = s.banked(t)
            residual = max(0, s.mean1m() - s.car_w / 1000)
            proj = banked + residual * left / 900
            max_thr = banked > 1.5 and proj >= max(2.5, s.peak)
            return max_thr and s.soc_sensor <= 10
        # C: capacity_pause with delay_off 300
        left = s.left(t); banked = s.banked(t) if left < 870 else 0
        house = max(0, s.grid_w / 1000 - s.car_w / 1000)
        breach_at_6a = banked + (house + 6 * V / 1000) * left / 900 > max(2.5, s.peak)
        cond = breach_at_6a or (s.floor < 15 and s.batt_sensor_kw() > 0.1)
        if cond:
            s.pause = True; s.pause_ok_since = None
        elif s.pause:
            if s.pause_ok_since is None:
                s.pause_ok_since = t
            elif t - s.pause_ok_since >= 300:
                s.pause = False
        return s.pause

    # ---------- main loop ----------
    def run(s):
        for t in range(NIGHT_S):
            if t % 900 == 0 and t > 0:
                q = s.banked_j / 900 / 1000
                s.quarters.append(q)
                if q > s.peak and q - s.carq_j / 900 / 1000 <= s.peak:
                    s.car_peaks += 1
                if q > s.peak:
                    s.peak = q
                s.banked_j = 0.0; s.carq_j = 0.0
            if t - s.soc_sensor_t >= 60:
                s.soc_sensor = int(round(s.soc)); s.soc_sensor_t = t

            s.floor = s.battery_floor(t)
            hr = s.headroom(t)
            new_target = quantize(min(hr, 13))
            if new_target != s.target:
                s.target = new_target; s.target_changed = t; s.target_fired = False
            should = s.car_need > 0 and not s.blocked(t, hr)

            # stop automation
            if not should and s.sw_on:
                if s.stop_at is None:
                    s.stop_at = t + 5
                elif t >= s.stop_at:
                    s.sw_on = False; s.stop_at = None; s.stops += 1
                    s.auto_running = False
            if should:
                s.stop_at = None
            # start automation (on should_charge -> on, or /10min)
            if should and not s.sw_on and (not s.should_prev or t % 600 == 0):
                s.sw_on = True; s.I = 8; s.car_ramp_t = t + 30; s.starts += 1
                s.auto_running = True; s.next_step = t + 15
            s.should_prev = should

            # set_current automation (mode restart)
            fire = False
            if s.sw_on and not s.target_fired and t - s.target_changed >= s.debounce:
                s.target_fired = True; fire = True
            nr = s.near(t)
            if s.sw_on and nr and not s.near_prev:
                fire = True
            s.near_prev = nr
            if fire:
                s.auto_running = True; s.next_step = t
            if s.auto_running and s.next_step is not None and t >= s.next_step:
                if s.I != s.target:
                    if s.target > s.I:
                        s.I = min(x for x in STEPS if x > s.I)
                    else:
                        s.I = max(x for x in STEPS if x < s.I)
                    s.changes += 1
                    s.next_step = t + 45
                else:
                    s.auto_running = False

            # physics
            car_w = s.I * V if (s.sw_on and s.car_ramp_t is not None and t >= s.car_ramp_t and s.car_need > 0) else 0
            house_w = s.house_fn(t)
            load = house_w + car_w
            batt_w = 0.0
            if s.soc > s.floor - 0.6:
                batt_w = min(load, INV_MAX_W)
            elif s.soc < s.force_soc:
                s.recover = True
            if s.recover:
                if s.soc >= s.force_soc + 1:
                    s.recover = False
                else:
                    batt_w = -330.0
            grid = max(0.0, load - batt_w)
            s.soc -= batt_w / CAP_WH / 3600 * 100
            if batt_w > 0:
                s.batt_out_j += batt_w
            s.min_soc = min(s.min_soc, s.soc)
            s.car_j += car_w; s.car_need -= car_w
            if car_w > 0:
                s.net_j += car_w - 250
                s.s6 += (s.I == 6)
            s.banked_j += grid; s.carq_j += car_w
            s.grid_hist.append(grid); s.batt_hist.append(batt_w)
            s.car_w = car_w; s.grid_w = grid
        q = s.banked_j / 900 / 1000
        s.quarters.append(q)
        return dict(
            car_kwh=s.car_j / 3.6e6,
            batt_kwh=s.batt_out_j / 3.6e6,
            min_soc=s.min_soc,
            max_q=max(s.quarters),
            over=sum(1 for q in s.quarters if q > s.peak0 + 0.005), car_peaks=s.car_peaks,
            changes=s.changes,
            stops=s.stops, min6=s.s6 / 60, net=s.net_j / 3.6e6,
            new_peak=s.peak,
        )


# ---------- house load models ----------
def base_load(seed):
    rnd = random.Random(seed)
    noise = [0.28 + 0.08 * rnd.random() for _ in range(NIGHT_S // 60 + 1)]
    return lambda t: noise[t // 60] * 1000


def with_events(seed, events):
    b = base_load(seed)
    def f(t):
        w = b(t)
        for (st, dur, kw) in events:
            if st <= t < st + dur:
                w += kw * 1000
        return w
    return f


def random_events(rnd):
    ev = []
    for _ in range(rnd.choice([1, 2, 3, 3, 4, 5])):
        kind = rnd.random()
        st = rnd.randrange(0, NIGHT_S - 1800)
        if kind < 0.35:   ev.append((st, rnd.randint(120, 300), 2.2))     # kettle / microwave
        elif kind < 0.6:  ev.append((st, rnd.randint(900, 1800), 2.0))   # dishwasher heat
        elif kind < 0.8:  ev.append((st, rnd.randint(1200, 2400), 2.0))  # washing machine heat
        else:             ev.append((st, rnd.randint(1800, 3600), 1.0))  # aux electric heating
    return ev


def show(name, rows):
    print(f"\n### {name}")
    print("| design | car kWh (net of 250 W) | min at 6A | battery out kWh | min SoC % | max quarter kW | new month peak | current changes | stops |")
    print("|---|---|---|---|---|---|---|---|---|")
    for d, r in rows:
        print(f"| {d} | {r['car_kwh']:.1f} ({r['net']:.1f}) | {r['min6']:.0f} | {r['batt_kwh']:.2f} | {r['min_soc']:.1f} | {r['max_q']:.2f} | {r['new_peak']:.2f} | {r['changes']} | {r['stops']} |")


if __name__ == '__main__':
    which = sys.argv[1] if len(sys.argv) > 1 else 'all'
    D = ['A', 'B', 'C']
    if which in ('all', 'det'):
        # S1: last night — battery 14%, floor stuck at 8 for the first 28 min (observed), quiet house
        show("S1 replay 2026-10-10: battery 14%, floor 8% for 28 min, quiet house",
             [(d, Sim(d, base_load(1), 14, forced_floor=lambda t: 8 if t < 1680 else None).run()) for d in D])
        # S2: quiet night, battery 40%
        show("S2 quiet night, battery 40%",
             [(d, Sim(d, base_load(2), 40).run()) for d in D])
        # S3: 2 kW load starting at minute 12 of a quarter (00:12 rel = 3600+720) for 10 min, battery 40%
        ev = [(3600 + 720, 600, 2.0)]
        show("S3 2 kW load at minute 12 for 10 min, battery 40%",
             [(d, Sim(d, with_events(3, ev), 40).run()) for d in D])
        # S4: same, battery empty (9%)
        show("S4 2 kW load at minute 12 for 10 min, battery 9%",
             [(d, Sim(d, with_events(3, ev), 9).run()) for d in D])
        # S5: 2 kW load for 1 h, battery empty
        ev = [(3600 + 720, 3600, 2.0)]
        show("S5 2 kW load for 1 h from minute 12, battery 9%",
             [(d, Sim(d, with_events(4, ev), 9).run()) for d in D])
    if which in ('all', 'mc'):
        n = int(sys.argv[2]) if len(sys.argv) > 2 else 60
        agg = {d: [] for d in D}
        for i in range(n):
            rnd = random.Random(1000 + i)
            ev = random_events(rnd)
            soc0 = rnd.choice([9, 12, 18, 25, 35, 50])
            for d in D:
                agg[d].append(Sim(d, with_events(2000 + i, ev), soc0).run())
        print(f"\n### Monte Carlo, {n} random nights (1-5 random 1-2.2 kW loads, battery start 9-50%)")
        print("| design | avg car kWh (net) | avg min at 6A | avg battery out kWh | nights SoC < 8% | nights w/ new peak | worst quarter kW | avg peak rise kW | avg current changes | avg stops | nights w/ car-caused new peak |")
        print("|---|---|---|---|---|---|---|---|---|---|---|")
        for d in D:
            r = agg[d]
            print(f"| {d} | {sum(x['car_kwh'] for x in r)/n:.1f} ({sum(x['net'] for x in r)/n:.1f}) | {sum(x['min6'] for x in r)/n:.0f} | {sum(x['batt_kwh'] for x in r)/n:.2f} | "
                  f"{sum(1 for x in r if x['min_soc'] < 7.5)} | {sum(1 for x in r if x['new_peak'] > 2.565)} | "
                  f"{max(x['max_q'] for x in r):.2f} | {sum(x['new_peak'] - 2.56 for x in r)/n:.3f} | "
                  f"{sum(x['changes'] for x in r)/n:.0f} | {sum(x['stops'] for x in r)/n:.1f} | {sum(1 for x in r if x['car_peaks'] > 0)} |")

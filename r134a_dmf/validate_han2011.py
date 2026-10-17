# -*- coding: utf-8 -*-
"""The 112-point p-T-x data of Han et al. 2011 (JCED 56, 1821-1826):
1) consistency check against data of Cui et al. 2007 from the same laboratory (linear interpolation at the same temperature);
2) independent validation with the existing frozen model (NRTL + gamma-phi, parameters fitted to Zehioua 2009)."""
import csv, sys
sys.path.insert(0, "/home/hatch/workspace/your_files/r134a_dmf")
from r134a_dmf import psol

W = "/home/hatch/workspace/your_files/r134a_dmf"

def load(name):
    pts = []
    with open(f"{W}/{name}") as f:
        for row in csv.DictReader(f):
            pts.append((float(row["T_K"]), float(row["x1"]), float(row["p_kPa"])))
    return pts

han = load("han2011.csv")
cui = load("cui2007.csv")
print(f"Han 2011: {len(han)} points, T={min(p[0] for p in han):.2f}~{max(p[0] for p in han):.2f}K")
print(f"Cui 2007: {len(cui)} points, T={min(p[0] for p in cui):.2f}~{max(p[0] for p in cui):.2f}K")

# ---- 1) Han vs Cui: at the same temperature, interpolate Cui in the x direction and compare with Han ----
cui_by_T = {}
for T, x, p in cui:
    cui_by_T.setdefault(T, []).append((x, p))
for T in cui_by_T:
    cui_by_T[T].sort()

diffs, diffs_by_T = [], {}
for T, x, p in han:
    if T not in cui_by_T:
        continue
    xs = cui_by_T[T]
    if x < xs[0][0] or x > xs[-1][0]:
        continue
    for (x0, p0), (x1, p1) in zip(xs, xs[1:]):
        if x0 <= x <= x1:
            pc = p0 + (p1 - p0) * (x - x0) / (x1 - x0)
            d = (p - pc) / pc * 100.0
            diffs.append(d)
            diffs_by_T.setdefault(T, []).append(d)
            break

print(f"\n=== Han vs Cui direct comparison (same-T interpolation, n={len(diffs)}) ===")
print(f"Mean relative deviation: {sum(diffs)/len(diffs):+.2f}%, mean |dev|: {sum(abs(d) for d in diffs)/len(diffs):.2f}%, max |dev|: {max(abs(d) for d in diffs):.2f}%")
for T in sorted(diffs_by_T):
    s = diffs_by_T[T]
    print(f"T={T:7.2f}K  n={len(s):3d}  mean dev={sum(s)/len(s):+6.2f}%  mean |dev|={sum(abs(d) for d in s)/len(s):5.2f}%")

# ---- 2) Validate Han 2011 with the frozen model ----
pts = []
for T, x1, pe in han:
    p_MPa, _ = psol(T, x1)
    pc = p_MPa * 1000.0
    dev = (pc - pe) / pe * 100.0
    pts.append((T, x1, pe, pc, dev))

n = len(pts)
aard = sum(abs(d) for _, _, _, _, d in pts) / n
mx = max(pts, key=lambda r: abs(r[4]))
print(f"\n=== Frozen model vs Han 2011 (n={n}) ===")
print(f"Overall AARD: {aard:.2f}%, max |dev|: {abs(mx[4]):.2f}%  (T={mx[0]:.2f}K, x1={mx[1]}, p_exp={mx[2]:.2f} kPa, p_calc={mx[3]:.2f} kPa)")
mean = sum(d for _, _, _, _, d in pts) / n
print(f"Mean deviation (signed): {mean:+.2f}%  (positive = model overestimates)")

print("\n--- AARD by temperature ---")
for T in sorted(set(p[0] for p in pts)):
    sub = [p for p in pts if p[0] == T]
    a = sum(abs(p[4]) for p in sub) / len(sub)
    m = sum(p[4] for p in sub) / len(sub)
    print(f"T={T:7.2f}K  n={len(sub):2d}  AARD={a:5.2f}%  mean dev={m:+6.2f}%")

print("\n--- 10 points with the largest deviation ---")
for T, x1, pe, pc, d in sorted(pts, key=lambda r: abs(r[4]), reverse=True)[:10]:
    print(f"T={T:7.2f}K x1={x1:.4f} p_exp={pe:9.2f} p_calc={pc:9.2f} dev={d:+6.2f}%")

print("\n--- Key temperatures compared with the Cui validation results ---")
for T in (283.15, 293.15, 303.15, 363.15):
    sub = [p for p in pts if p[0] == T]
    a = sum(abs(p[4]) for p in sub) / len(sub)
    print(f"Han T={T:.2f}K: AARD={a:.2f}%   (Cui same T: 283K=8.53%, 363K=26.21%)")

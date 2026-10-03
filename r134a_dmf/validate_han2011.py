# -*- coding: utf-8 -*-
"""Han et al. 2011 (JCED 56, 1821-1826) 112 点 p-T-x 数据:
1) 与同实验室 Cui et al. 2007 的数据一致性检查 (同温度线性插值对比);
2) 用现有冻结模型 (NRTL+gamma-phi, Zehioua 2009 拟合参数) 做独立验证。"""
import os, csv, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from r134a_dmf import bubble_p

W = os.path.dirname(os.path.abspath(__file__))

def load(name):
    pts = []
    with open(f"{W}/{name}") as f:
        for row in csv.DictReader(f):
            pts.append((float(row["T_K"]), float(row["x1"]), float(row["p_kPa"])))
    return pts

han = load("han2011.csv")
cui = load("cui2007.csv")
print(f"Han 2011: {len(han)} 点, T={min(p[0] for p in han):.2f}~{max(p[0] for p in han):.2f}K")
print(f"Cui 2007: {len(cui)} 点, T={min(p[0] for p in cui):.2f}~{max(p[0] for p in cui):.2f}K")

# ---- 1) Han vs Cui: 同温度, 对 Cui 做 x 方向线性插值, 与 Han 对比 ----
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

print(f"\n=== Han vs Cui 直接对比 (同T插值, n={len(diffs)}) ===")
print(f"平均相对偏差: {sum(diffs)/len(diffs):+.2f}%, 平均|偏差|: {sum(abs(d) for d in diffs)/len(diffs):.2f}%, 最大|偏差|: {max(abs(d) for d in diffs):.2f}%")
for T in sorted(diffs_by_T):
    s = diffs_by_T[T]
    print(f"T={T:7.2f}K  n={len(s):3d}  平均偏差={sum(s)/len(s):+6.2f}%  平均|偏差|={sum(abs(d) for d in s)/len(s):5.2f}%")

# ---- 2) 冻结模型验证 Han 2011 ----
pts = []
for T, x1, pe in han:
    p_MPa, _ = bubble_p(T, x1)
    pc = p_MPa * 1000.0
    dev = (pc - pe) / pe * 100.0
    pts.append((T, x1, pe, pc, dev))

n = len(pts)
aard = sum(abs(d) for _, _, _, _, d in pts) / n
mx = max(pts, key=lambda r: abs(r[4]))
print(f"\n=== 冻结模型 vs Han 2011 (n={n}) ===")
print(f"总体 AARD: {aard:.2f}%, 最大 |偏差|: {abs(mx[4]):.2f}%  (T={mx[0]:.2f}K, x1={mx[1]}, p_exp={mx[2]:.2f} kPa, p_calc={mx[3]:.2f} kPa)")
mean = sum(d for _, _, _, _, d in pts) / n
print(f"平均偏差(带符号): {mean:+.2f}%  (正=模型高估)")

print("\n--- 按温度统计 AARD ---")
for T in sorted(set(p[0] for p in pts)):
    sub = [p for p in pts if p[0] == T]
    a = sum(abs(p[4]) for p in sub) / len(sub)
    m = sum(p[4] for p in sub) / len(sub)
    print(f"T={T:7.2f}K  n={len(sub):2d}  AARD={a:5.2f}%  平均偏差={m:+6.2f}%")

print("\n--- 偏差最大的 10 个点 ---")
for T, x1, pe, pc, d in sorted(pts, key=lambda r: abs(r[4]), reverse=True)[:10]:
    print(f"T={T:7.2f}K x1={x1:.4f} p_exp={pe:9.2f} p_calc={pc:9.2f} dev={d:+6.2f}%")

print("\n--- 与 Cui 验证结果对照的关键温度 ---")
for T in (283.15, 293.15, 303.15, 363.15):
    sub = [p for p in pts if p[0] == T]
    a = sum(abs(p[4]) for p in sub) / len(sub)
    print(f"Han T={T:.2f}K: AARD={a:.2f}%   (Cui 同T: 283K=8.53%, 363K=26.21%)")

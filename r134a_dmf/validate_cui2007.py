# -*- coding: utf-8 -*-
"""用现有 R134a-DMF 模型 (NRTL+gamma-phi, 拟合自 Zehioua 2009)
对 Cui et al. 2007 (ICR07) 的 90 点 p-T-x 数据做独立验证。"""
import os, csv, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from r134a_dmf import bubble_p

pts = []
with open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "cui2007.csv")) as f:
    for row in csv.DictReader(f):
        T = float(row["T_K"]); x1 = float(row["x1"]); pe = float(row["p_kPa"])
        p_MPa, _ = bubble_p(T, x1)
        pc = p_MPa * 1000.0
        dev = (pc - pe) / pe * 100.0
        pts.append((T, x1, pe, pc, dev))

n = len(pts)
aard = sum(abs(d) for _, _, _, _, d in pts) / n
mx = max(pts, key=lambda r: abs(r[4]))
print(f"总点数: {n}")
print(f"总体 AARD: {aard:.2f}%, 最大 |偏差|: {abs(mx[4]):.2f}%  (T={mx[0]:.2f}K, x1={mx[1]}, p_exp={mx[2]:.2f} kPa, p_calc={mx[3]:.2f} kPa)")

print("\n--- 按温度统计 AARD ---")
Ts = sorted(set(p[0] for p in pts))
for T in Ts:
    sub = [p for p in pts if p[0] == T]
    a = sum(abs(p[4]) for p in sub) / len(sub)
    w = max(sub, key=lambda r: abs(r[4]))
    print(f"T={T:7.2f}K  n={len(sub):2d}  AARD={a:5.2f}%  最大|偏差|={abs(w[4]):5.2f}% (x1={w[1]})")

print("\n--- 偏差最大的 10 个点 ---")
for T, x1, pe, pc, d in sorted(pts, key=lambda r: abs(r[4]), reverse=True)[:10]:
    print(f"T={T:7.2f}K x1={x1:.4f} p_exp={pe:9.2f} p_calc={pc:9.2f} dev={d:+6.2f}%")

print("\n--- 293.15/303.15K 子集 (Feng 2016 裁决用) ---")
sub = [p for p in pts if p[0] in (293.15, 303.15)]
a = sum(abs(p[4]) for p in sub) / len(sub)
print(f"n={len(sub)} AARD={a:.2f}%")
for T, x1, pe, pc, d in sorted(sub, key=lambda r: r[1]):
    print(f"T={T:7.2f}K x1={x1:.4f} p_exp={pe:9.2f} p_calc={pc:9.2f} dev={d:+6.2f}%")

print("\n--- 283.15/363.15K 外推边界子集 ---")
sub = [p for p in pts if p[0] in (283.15, 363.15)]
a = sum(abs(p[4]) for p in sub) / len(sub)
print(f"n={len(sub)} AARD={a:.2f}%")

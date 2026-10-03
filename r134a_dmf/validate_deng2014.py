# -*- coding: utf-8 -*-
"""验证 Deng 2014 表1 的 8 个 R134a+DMF 装置验证点。
1) 与 Han 2011 数据在 xexp 处插值比较 (复现论文 1.51%/2.89% 的说法)
2) 冻结模型 (DG12=868.1, DG21=-929.1, alpha=0.3) 对这 8 点的验证
"""
import os, csv, math, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from r134a_dmf import bubble_p

# --- 读 Han 2011 数据, 按温度分组 ---
han = {}
with open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "han2011.csv")) as f:
    for row in csv.DictReader(f):
        T = float(row["T_K"]); x = float(row["x1"]); p = float(row["p_kPa"])
        han.setdefault(T, []).append((x, p))
for T in han:
    han[T].sort()

def interp_han(T, x):
    pts = han[T]
    if x <= pts[0][0]: return pts[0][1]
    if x >= pts[-1][0]: return pts[-1][1]
    for i in range(len(pts)-1):
        x0,p0 = pts[i]; x1,p1 = pts[i+1]
        if x0 <= x <= x1:
            return p0 + (p1-p0)*(x-x0)/(x1-x0)
    return pts[-1][1]

def read_deng():
    with open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "deng2014.csv")) as f:
        lines = [l for l in f if not l.startswith("#")]
    return csv.DictReader(lines)

print(f"{'T/K':>8} {'x_exp':>8} {'p_exp':>8} {'p_Han(x)':>9} {'dHan%':>7} {'p_mod':>8} {'dMod%':>7}")
devs_han, devs_mod = [], []
for row in read_deng():
        T = float(row["T_K"]); xe = float(row["x1exp"]); pe = float(row["pexp_kPa"])
        ph = interp_han(T, xe)
        pm = bubble_p(T, xe)[0] * 1000.0  # MPa -> kPa
        dh = (pe-ph)/ph*100; dm = (pm-pe)/pe*100
        devs_han.append(abs(dh)); devs_mod.append(abs(dm))
        print(f"{T:8.2f} {xe:8.4f} {pe:8.1f} {ph:9.1f} {dh:7.2f} {pm:8.1f} {dm:7.2f}")

n = len(devs_han)
print(f"\nvs Han 2011 插值: 平均 |偏差| = {sum(devs_han)/n:.2f}%, 最大 = {max(devs_han):.2f}%")
print(f"  (论文称: 平均 1.51%, 最大 2.89% —— 注: 论文用的是 Han 的 NRTL 关联式, 此处用数据线性插值)")
print(f"冻结模型验证:  AARD = {sum(devs_mod)/n:.2f}%, 最大 = {max(devs_mod):.2f}%")

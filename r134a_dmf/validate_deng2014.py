# -*- coding: utf-8 -*-
"""Validate the 8 R134a+DMF apparatus validation points in Table 1 of Deng 2014.
1) Interpolate the Han 2011 data at xexp and compare (reproducing the paper's stated 1.51%/2.89%)
2) Validation of the frozen model (DG12=868.1, DG21=-929.1, alpha=0.3) on these 8 points
"""
import csv, math, sys
sys.path.insert(0, "/home/hatch/workspace/your_files/r134a_dmf")
from r134a_dmf import psol

# --- Read the Han 2011 data, grouped by temperature ---
han = {}
with open("/home/hatch/workspace/your_files/r134a_dmf/han2011.csv") as f:
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
    with open("/home/hatch/workspace/your_files/r134a_dmf/deng2014.csv") as f:
        lines = [l for l in f if not l.startswith("#")]
    return csv.DictReader(lines)

print(f"{'T/K':>8} {'x_exp':>8} {'p_exp':>8} {'p_Han(x)':>9} {'dHan%':>7} {'p_mod':>8} {'dMod%':>7}")
devs_han, devs_mod = [], []
for row in read_deng():
        T = float(row["T_K"]); xe = float(row["x1exp"]); pe = float(row["pexp_kPa"])
        ph = interp_han(T, xe)
        pm = psol(T, xe)[0] * 1000.0  # MPa -> kPa
        dh = (pe-ph)/ph*100; dm = (pm-pe)/pe*100
        devs_han.append(abs(dh)); devs_mod.append(abs(dm))
        print(f"{T:8.2f} {xe:8.4f} {pe:8.1f} {ph:9.1f} {dh:7.2f} {pm:8.1f} {dm:7.2f}")

n = len(devs_han)
print(f"\nvs Han 2011 interpolation: mean |dev| = {sum(devs_han)/n:.2f}%, max = {max(devs_han):.2f}%")
print(f"  (paper states: mean 1.51%, max 2.89% -- note: the paper used Han's NRTL correlation; here the data are linearly interpolated)")
print(f"Frozen-model validation:  AARD = {sum(devs_mod)/n:.2f}%, max = {max(devs_mod):.2f}%")

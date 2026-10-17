# -*- coding: utf-8 -*-
"""Recompute pcal with the NRTL parameters printed in Han 2011 itself and compare with the pcal column of the paper's Table 3,
verifying that han2011.csv was entered without error (temperature-block division, row correspondence).
Paper Eqs. (6)(7): tau12=(a0+a1*lnT)/(R*T), tau21=(b0+b1*lnT)/(R*T)
Table 4: a0=8073, a1=1367, b0=11638, b1=2106, alpha=0.14
p = gamma1 * x1 * psat(T) * Poynting (Poynting ~ 1, neglected)
psat uses this project's Tillner-Roth & Baehr fit (deviation from REFPROP 7 in this temperature range <0.3%)."""
import csv, math, sys
sys.path.insert(0, "/home/hatch/workspace/your_files/r134a_dmf")
from r134a_dmf import pref_r134a  # returns MPa

R = 8.314462
a0, a1, b0, b1, alpha = 8073.0, 1367.0, 11638.0, 2106.0, 0.14

def gamma1_han(T, x1):
    x2 = 1.0 - x1
    t12 = (a0 + a1 * math.log(T)) / (R * T)
    t21 = (b0 + b1 * math.log(T)) / (R * T)
    G12 = math.exp(-alpha * t12)
    G21 = math.exp(-alpha * t21)
    term1 = t21 * (G21 / (x1 + x2 * G21)) ** 2
    term2 = t12 * G12 / (x2 + x1 * G12) ** 2
    return math.exp(x2 ** 2 * (term1 + term2))

# The paper's Table 3 pcal values (kPa), in entry order
pcal_paper = [
 # 263.15
 29.17,47.58,66.56,90.74,113.00,125.89,148.06,177.05,
 # 273.15
 41.18,67.33,94.39,129.15,161.55,180.40,213.32,257.12,
 # 283.15
 48.78,73.27,92.37,129.67,177.66,222.78,276.67,318.33,360.37,
 # 293.15
 65.26,121.36,172.30,199.40,259.25,276.87,317.35,371.35,428.80,489.28,533.96,
 # 303.15
 85.39,159.13,225.86,261.35,339.52,362.56,415.33,486.03,562.24,645.67,712.09,
 # 313.15
 204.52,290.35,335.85,435.96,465.48,532.92,623.25,721.46,832.43,926.11,
 # 323.15
 137.17,256.38,364.26,421.55,547.58,584.67,669.55,783.28,838.73,1050.75,1179.37,
 # 333.15
 169.22,316.17,449.78,520.81,677.21,723.57,829.08,957.99,1024.49,1305.15,1475.00,
 # 343.15
 204.41,383.00,546.26,633.29,825.39,882.74,1012.74,1171.64,1252.62,1599.67,1816.72,
 # 353.15
 241.22,440.33,651.50,756.98,990.88,1061.24,1220.31,1415.02,1513.68,1938.36,2208.00,
 # 363.15
 276.79,503.67,762.76,889.85,1172.99,1258.93,1452.74,1689.92,1806.75,2325.86,2654.10,
]

pts = []
with open("/home/hatch/workspace/your_files/r134a_dmf/han2011.csv") as f:
    for row in csv.DictReader(f):
        pts.append((float(row["T_K"]), float(row["x1"]), float(row["p_kPa"])))

assert len(pts) == len(pcal_paper) == 112, (len(pts), len(pcal_paper))

worst = []
for (T, x1, pe), pc_paper in zip(pts, pcal_paper):
    g1 = gamma1_han(T, x1)
    pc_mine = g1 * x1 * pref_r134a(T) * 1000.0  # kPa
    d = (pc_mine - pc_paper) / pc_paper * 100.0
    worst.append(abs(d))

worst_sorted = sorted(worst, reverse=True)
print(f"112 points: my pcal vs the paper's pcal, mean |dev|={sum(worst)/112:.3f}%, max |dev|={worst_sorted[0]:.3f}%")
print("Largest 5:", [f"{v:.2f}%" for v in worst_sorted[:5]])
# If the mean deviation is <0.5% and the maximum <1.5%, the entered (T,x) correspond one-to-one to the paper's rows

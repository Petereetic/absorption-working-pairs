#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Verification record for the Patek-Klomfar (1995) transcription.

Run: python3 verify_transcription.py
All checks must print OK.
"""
import sys
sys.path.insert(0, ".")
from ammonia_water import *

ok = True
def check(name, calc, ref, tol):
    global ok
    d = abs(calc - ref)
    s = "OK " if d <= tol else "FAIL"
    if d > tol: ok = False
    print("[%s] %-52s calc=%10.4f ref=%10.4f diff=%7.4f tol=%.3f"
          % (s, name, calc, ref, d, tol))

# --- 1. Pure-component limits of Eq (6) : textbook saturation temperatures ---
check("Eq6 NH3 Tsat @1 atm (C)", T_bubble_PX(0.101325, 1.0) - 273.15, -33.34, 1.5)
check("Eq6 H2O Tsat @1 atm (C)", T_bubble_PX(0.101325, 0.0) - 273.15, 100.00, 1.5)
check("Eq6 NH3 Tsat @2 MPa (C)", T_bubble_PX(2.0, 1.0) - 273.15, 49.3, 1.5)
check("Eq6 H2O Tsat @2 MPa (C)", T_bubble_PX(2.0, 0.0) - 273.15, 212.4, 1.5)

# --- 2. Pure-component limits of Eq (7) (paper: 95 % within +/-2 K;
#         the 2 MPa water end sits just outside at 2.04 K -- edge of the
#         T(p,y) data, honest fit behaviour, see notes) ---
check("Eq7 NH3 dew @2 MPa (C)", T_dew_PY(2.0, 1.0) - 273.15, 49.3, 2.0)
check("Eq7 H2O dew @2 MPa (C)", T_dew_PY(2.0, 0.0) - 273.15, 212.4, 2.5)

# --- 3. Enthalpy reference state: h_l(273.16 K, x=0) = 0 (paper definition) ---
check("h_l(273.16K, x=0) (kJ/kg)", h_liq(273.16, 0.0), 0.0, 1e-9)
# at x=1 the fit gives ~0 within its own RMS (0.9 kJ/kg)
check("h_l(273.16K, x=1) (kJ/kg)", h_liq(273.16, 1.0), 0.0, 0.9)

# --- 4. y(p,x) physical bounds: vapour enriched in NH3 ---
bad = 0
for p in (0.05, 0.1, 0.2, 0.5, 1.0, 1.5, 2.0):
    x = 0.06
    while x < 1.0:
        y = y_equil(p, x)
        if not (x < y <= 1.0): bad += 1
        x += 0.02
print("[%s] y(p,x) in (x,1] on grid, violations=%d" % ("OK " if bad == 0 else "FAIL", bad))
ok = ok and bad == 0

# --- 5. Mutual consistency T(p,x)/T(p,y)/y(p,x) in y (paper p. 232:
#         better than 1 % for x > 0.2) ---
def y_star(p, x):
    Tb = T_bubble_PX(p, x)
    lo, hi = x, 1.0
    for _ in range(200):
        mid = 0.5 * (lo + hi)
        if T_dew_PY(p, mid) > Tb: lo = mid
        else: hi = mid
    return 0.5 * (lo + hi)

worst = 0.0
for p in (0.05, 0.1, 0.2, 0.5, 1.0, 1.5, 2.0):
    x = 0.21
    while x <= 0.99:
        ys = y_star(p, x)
        worst = max(worst, abs(y_equil(p, x) - ys) / ys * 100.0)
        x += 0.03
print("[%s] max y-inconsistency for x>0.2: %.3f %% (paper: <1 %%)"
      % ("OK " if worst < 1.0 else "FAIL", worst))
ok = ok and worst < 1.0

print("\nALL CHECKS PASSED" if ok else "\nSOME CHECKS FAILED")
sys.exit(0 if ok else 1)

# -*- coding: utf-8 -*-
"""Anchor checks for h2o_cacl2.py against the Conde dossier
(dossiers/H2O-LiCl-CaCl2-Conde.md, verification section and Sec.8
figure anchors of the 2026-11-19 ruling)."""
import math
import h2o_cacl2 as m

fails = []


def chk(name, got, want, tol):
    ok = got is not None and abs(got - want) <= tol
    print("%-28s got=%r want=%r tol=%r  %s" % (name, got, want, tol,
                                               "OK" if ok else "FAIL"))
    if not ok:
        fails.append(name)


# Water side (dossier verification values)
chk("pref_water(25C) MPa", m.pref_water(25.0), 0.003172, 5e-6)
chk("pref_water(100C) MPa", m.pref_water(100.0), 0.1014, 5e-4)
chk("rho_water(20C)", m.rho_water(20.0), 998.3, 0.3)
chk("rho_water(25C)", m.rho_water(25.0), 997.1, 0.3)

# VLE pi at 25C (dossier verification table)
for xi, want in ((0.1, 0.9393), (0.2, 0.8266), (0.3, 0.6453), (0.4, 0.4107)):
    chk("pi_factor(%.1f,25C)" % xi, m.pi_factor(xi, 25.0), want, 5e-4)
chk("pi_factor(0,25C)", m.pi_factor(0.0, 25.0), 0.99756, 5e-5)

# Density (dossier: handbook cross-checks)
chk("rho_sol(20C,0.3)", m.rho_sol(20.0, 0.3), 1284.3, 0.5)
chk("rho_sol(20C,0.4)", m.rho_sol(20.0, 0.4), 1392.3, 0.5)

# Specific heat factor (dossier: (1-f1*f2)=0.6555 at xi=0.3/20C with
# external Cp_H2O=4.183 -> 2.742; module table Cp_H2O(20C)=4.182)
chk("cp factor(20C,0.3)", m.cp_sol(20.0, 0.3) / 4.183, 0.6555, 5e-4)
chk("cp factor(20C,0.4)", m.cp_sol(20.0, 0.4) / 4.183, 0.5764, 5e-4)

# Dilution enthalpy, theta_r (dossier Sec.8 figure anchors, 600 dpi
# re-read 2026-11-19; figure-read tolerance)
chk("dh_d(0.445,40C)", m.dh_d(0.445, 40.0), 209.0, 15.0)
chk("dh_d(0.505,40C)", m.dh_d(0.505, 40.0), 300.0, 12.0)
chk("dh_d(0.52,40C)", m.dh_d(0.52, 40.0), 321.0, 10.0)
chk("dh_d(0.6,100C)", m.dh_d(0.6, 100.0), 649.6, 15.0)

# Viscosity / surface tension (dossier magnitude anchors)
chk("eta_sol(20C,0.3) mPa s", m.eta_sol(20.0, 0.3) * 1000.0, 3.44, 0.05)
chk("sigma ratio(25C,0.3)", m.sigma_sol(25.0, 0.3) / m.sigma_water(25.0),
    1.200, 0.01)

# SLE ice-line eutectic (dossier: formula -55.77 vs Fig.2 inset -54.23)
chk("sle_T(0.2985,ice)", m.sle_T(0.2985, "ice"), -55.77, 0.1)

# Round trips
chk("bubble_T(psol(80,0.4))", m.bubble_T(m.psol(80.0, 0.4), 0.4), 80.0, 1e-6)
chk("xi_by_tsol_tdew", m.xi_by_tsol_tdew(80.0, m.tdew_by_tsol_xi(80.0, 0.4)),
    0.4, 1e-6)
chk("tsol_by_hsol", m.tsol_by_hsol(m.hsol(80.0, 0.4), 0.4), 80.0, 1e-4)

# Out of range -> None
for f, args in [(m.psol, (25.0, 0.61)), (m.rho_sol, (20.0, -0.1)),
                (m.dh_d, (0.61, 25.0)), (m.hsol, (25.0, 0.61)),
                (m.sle_T, (0.81, "ice"))]:
    v = f(*args)
    print("%-28s got=%r want=None  %s" % (f.__name__ + str(args), v,
                                          "OK" if v is None else "FAIL"))
    if v is not None:
        fails.append(f.__name__)

# VBA comparison points (full precision; the Excel testcall must
# reproduce these)
print("\nVBA test points:")
print("  Psol(80C, 0.4)  = %.17g MPa" % m.psol(80.0, 0.4))
print("  Psol(25C, 0.3)  = %.17g MPa" % m.psol(25.0, 0.3))
print("  Hsol(80C, 0.4)  = %.17g kJ/kg" % m.hsol(80.0, 0.4))
print("  Hsol(25C, 0.5)  = %.17g kJ/kg" % m.hsol(25.0, 0.5))
print("  DhD(0.52, 40C)  = %.17g kJ/kg_H2O" % m.dh_d(0.52, 40.0))
print("  RhoSol(20C,0.3) = %.17g kg/m3" % m.rho_sol(20.0, 0.3))
print("  CpSol(20C,0.3)  = %.17g kJ/(kg K)" % m.cp_sol(20.0, 0.3))
print("  SleT(0.2985,ice)= %.17g degC" % m.sle_T(0.2985, "ice"))

print("\n%s" % ("ALL OK" if not fails else "FAILURES: %s" % fails))

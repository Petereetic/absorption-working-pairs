# -*- coding: utf-8 -*-
"""
Verification of h2o_licl.py against the anchors of the source
dossier dossiers/H2O-LiCl-CaCl2-Conde.md (Conde 2004), which were
themselves checked against the paper's figures and handbook data
(see the dossier's verification section; the dossier verify script
H2O-LiCl-CaCl2-Conde-verify.py is the primary record).

Anchors checked here:
  * pure water: Saul-Wagner p(25C) = 3.172 kPa (ref 3.170),
    p(100C) = 101.4 kPa (ref 101.42); rho(20C) = 998.3,
    rho(25C) = 997.1 kg/m3 (ref 998.2 / 997.0).
  * vapour-pressure ratio pi at 25C (dossier values from the
    paper's Fig. 3 curve level): xi = 0.1/0.2/0.3/0.4 ->
    0.8815 / 0.6898 / 0.4215 / 0.1874; boundary pi(0) = 0.99594;
    saturated fixed point xi = 0.458 -> pi = 0.1062 (fixed-point
    RH 0.113, -6 %: the paper fit's own residual, recorded).
  * density at 20C: xi = 0.3 -> 1182.0, xi = 0.2 -> 1115.9 kg/m3.
  * SLE: ice line at xi = 0.253 -> -76.00 degC (Fig. 1 inset
    eutectic -75.5 degC); LiCl.5H2O branch at xi = 0.287 ->
    -68.2 degC (inset point B).
  * specific heat: xi = 0.3, 25C -> 2.963 kJ/(kg K) (dossier value
    with Cp_H2O = 4.183 inserted; this module's tabulated
    Cp_H2O(25C) = 4.181 shifts the result by -0.05 %).
  * differential dilution enthalpy (theta = theta_r per the
    dossier Sec.8 ruling of 2026-11-19; this module was changed
    from theta_s to theta_r on 2026-11-24): xi = 0.4, 25C ->
    259.3 kJ/kg_H2O (paper Fig. 26, Lange & Duerr data points,
    figure reading 245-258).  The superseded theta_s build gave
    211.5 at this point, below the figure's curve bundle.
  * viscosity at 20C: xi = 0.3 -> 4.08 mPa s (dossier, with
    eta_H2O = 1.002 mPa s inserted; this module's Vogel eta_water
    gives the same 1.002 at 20C).
  * surface-tension ratio at 25C: xi = 0.3 -> 1.241.
  * round trips: bubble_T(psol), xi_by_tsol_tdew, tsol_by_hsol;
    d(hsol)/dT against cp_sol (exact by construction).
"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import h2o_licl as m

fails = []

def chk(name, got, ref, tol, unit=""):
    dev = got - ref
    ok = abs(dev) <= tol
    print("%-38s got %12.4f  ref %12.4f  dev %+9.4f %s  %s"
          % (name, got, ref, dev, unit, "OK" if ok else "FAIL"))
    if not ok:
        fails.append(name)

# pure water
chk("pref_water(25C) [kPa]", m.pref_water(25.0) * 1000.0, 3.172, 0.01)
chk("pref_water(100C) [kPa]", m.pref_water(100.0) * 1000.0, 101.4, 0.3)
chk("rho_water(20C)", m.rho_water(20.0), 998.3, 0.5)
chk("rho_water(25C)", m.rho_water(25.0), 997.1, 0.5)
chk("sigma_water(25C) [mN/m]", m.sigma_water(25.0) * 1000.0, 72.0, 0.3)
chk("eta_water(20C) [mPa s]", m.eta_water(20.0) * 1000.0, 1.002, 0.01)
chk("tsat_water(pref(80C)) roundtrip", m.tsat_water(m.pref_water(80.0)), 80.0, 1e-6)

# vapour pressure ratio pi at 25C
for xi, ref in ((0.1, 0.8815), (0.2, 0.6898), (0.3, 0.4215), (0.4, 0.1874)):
    chk("pi(25C, xi=%.1f)" % xi, m.pi_factor(xi, 25.0), ref, 0.002)
chk("pi(25C, xi=0) boundary", m.pi_factor(0.0, 25.0), 0.99594, 0.0005)
chk("pi(25C, xi=0.458) sat.", m.pi_factor(0.458, 25.0), 0.1062, 0.002)

# density
chk("rho_sol(20C, 0.3)", m.rho_sol(20.0, 0.3), 1182.0, 1.0)
chk("rho_sol(20C, 0.2)", m.rho_sol(20.0, 0.2), 1115.9, 1.0)

# SLE
chk("sle ice(0.253) [degC]", m.sle_T(0.253, "ice"), -76.00, 0.05)
chk("sle 5H2O(0.287) [degC]", m.sle_T(0.287, "LiCl.5H2O"), -68.2, 0.3)
chk("crystallization_T(0.253)", m.crystallization_T(0.253), -75.5, 0.3)

# specific heat / dilution enthalpy / viscosity / surface tension
chk("cp_sol(25C, 0.3)", m.cp_sol(25.0, 0.3), 2.963, 0.01)
chk("dh_d(0.4, 25C) theta_r", m.dh_d(0.4, 25.0), 259.3, 1.0)
# theta convention contrast at the same point: current theta_r vs
# the superseded theta_s build (pre-2026-11-24), computed inline
# from the same Table 11 coefficients.
_z = 0.4 / (0.6 - 0.4)
_old_ts = (169.105 + 457.85 * (298.15 / 228.0 - 1.0)) \
    * (1.0 + (_z / 0.845) ** (-1.965)) ** (-2.265)
print("dh_d(0.4, 25C): theta_r = %.4f (current) vs theta_s = %.4f (superseded)"
      % (m.dh_d(0.4, 25.0), _old_ts))
chk("eta_sol(20C, 0.3) [mPa s]", m.eta_sol(20.0, 0.3) * 1000.0, 4.08, 0.08)
chk("sigma ratio(25C, 0.3)", m.sigma_sol(25.0, 0.3) / m.sigma_water(25.0), 1.241, 0.01)
print("lambda_sol(20C, 0.3) = %.3f W/(m K) (sanity: ~0.53-0.55)"
      % m.lambda_sol(20.0, 0.3))

# round trips
e1 = max(abs(m.bubble_T(m.psol(T, xi), xi) - T)
         for T in (25.0, 60.0, 100.0) for xi in (0.1, 0.3, 0.5))
e2 = max(abs(m.xi_by_tsol_tdew(T, m.tdew_by_tsol_xi(T, xi)) - xi)
         for T in (40.0, 80.0, 120.0) for xi in (0.15, 0.3, 0.45))
e3 = max(abs(m.tsol_by_hsol(m.hsol(T, xi), xi) - T)
         for T in (10.0, 60.0, 120.0) for xi in (0.0, 0.2, 0.4))
print("round-trip bubble_T max err      = %.2e degC" % e1)
print("round-trip xi_by_tsol_tdew err   = %.2e" % e2)
print("round-trip tsol_by_hsol err      = %.2e degC" % e3)
if max(e1, e2, e3) > 1e-6:
    fails.append("round-trip")

# dh/dT vs cp (exact by construction: e25 is T-independent)
num = (m.hsol(80.5, 0.35) - m.hsol(79.5, 0.35)) / 1.0
print("dhsol/dT(80C, 0.35) numeric = %.4f vs cp_sol = %.4f"
      % (num, m.cp_sol(80.0, 0.35)))
if abs(num - m.cp_sol(80.0, 0.35)) > 0.01:
    fails.append("dh/dT vs cp")

# out-of-range behaviour
for fn, args in [(m.psol, (200.0, 0.3)), (m.rho_sol, (25.0, 0.7)),
                 (m.dh_d, (0.58, 25.0)), (m.hsol, (25.0, 0.58))]:
    if fn(*args) is not None:
        fails.append("range %s%s" % (fn.__name__, args))
print("Out-of-range returns None: OK")

print("\nRESULT:", "ALL OK" if not fails else "FAILURES: %s" % fails)

# Verification: pointwise consistency of C vs. Python + spot checks against the thesis's own data
# Run: python3 verify_methanol_bromide.py (requires gcc; scipy only for the PCHIP comparison)
import math
import subprocess
import sys

sys.path.insert(0, ".")
import methanol_bromide as mb

subprocess.run(["gcc", "-O2", "-Wall", "-Wextra", "-o", "/tmp/mb_c",
                "methanol_bromide.c", "-lm"], check=True)
out = subprocess.run(["/tmp/mb_c"], capture_output=True, text=True, check=True).stdout

maxdev = 0.0
for line in out.strip().splitlines():
    f = line.split(",")
    if f[0] == "grid":
        T, w = float(f[1]), float(f[2])
        py = [mb.psol_TW(T, w), mb.cp(T, w), mb.h_prime(T, w),
              mb.hsol(T, w), mb.hgas(T, w)]
        for cv, pv in zip(f[3:], py):
            maxdev = max(maxdev, abs(float(cv) - pv))
    elif f[0] == "inv":
        P, w = float(f[1]), float(f[2])
        maxdev = max(maxdev, abs(float(f[3]) - mb.T_bubble_PW(P, w)))
print("C vs Python  maximum deviation: %.3g" % maxdev)

# PCHIP vs. scipy comparison (only checks that the in-house implementation agrees with the standard algorithm)
try:
    from scipy.interpolate import PchipInterpolator
    p1 = PchipInterpolator(mb._W_NODES, mb._C1_NODES)
    p2 = PchipInterpolator(mb._W_NODES, mb._C2_NODES)
    dmax = 0.0
    for i in range(2001):
        w = 0.243 + (0.509 - 0.243) * i / 2000
        dmax = max(dmax, abs(p1(w) - mb._c1(w)), abs(p2(w) - mb._c2(w)))
    print("PCHIP vs scipy maximum deviation: %.3g" % dmax)
except ImportError:
    print("scipy not available, skipping the PCHIP comparison")

# Isobaric temperature table of Appendix A of the thesis: bubble-point temperatures at P = 300 mmHg
# (Unit ruling of 2026-10-14: the module inputs are now MPa; 300 mmHg = 0.039997 MPa; the former bar convention was 0.39997)
print("\nBubble-point temperature spot check (Appendix A, 300 mmHg):")
for w, tref in [(0.250, 419.0), (0.262, 411.7), (0.301, 391.4), (0.356, 380.3)]:
    t = mb.T_bubble_PW(0.039997, w)
    print("  w=%.3f  calc %7.2f K  paper %6.1f K  dev %+.2f K" % (w, t, tref, t - tref))

# Enthalpy-of-vaporisation table of Appendix A of the thesis
print("\nH' spot check (Appendix A table, p.196):")
for T, w, href in [(283.15, 0.25, 1940.0), (283.15, 0.356, 1601.0), (373.15, 0.25, 1645.0)]:
    hv = mb.h_prime(T, w)
    print("  T=%.0fC w=%.3f  calc %7.1f  paper %6.0f  dev %+.2f%%"
          % (T - 273.15, w, hv, href, 100.0 * (hv - href) / href))

# Measured specific heats of Table 3.7 of the thesis (also the ruling evidence for the sign of the last term of B in Eq. (3.4): take "-")
print("\nCp spot check (Table 3.7, measured):")
for tc, w, cref in [(51.3, 0.403, 1.27), (69.9, 0.403, 1.30),
                    (40.0, 0.311, 1.19), (80.6, 0.311, 1.26)]:
    cv = mb.cp(tc + 273.15, w)
    print("  t=%.1fC w=%.3f  calc %.3f  measured %.2f  dev %+.2f%%"
          % (tc, w, cv, cref, 100.0 * (cv - cref) / cref))

# Pure-methanol Antoine fit errors (the 7 data points of Appendix A)
print("\nPure-methanol Antoine fit (Appendix A data points):")
for mmhg, tk in [(300, 316.7), (500, 328.3), (600, 332.6), (700, 336.4),
                 (800, 339.7), (900, 342.7), (1000, 345.4)]:
    pc = mb.meoh_pref_bar(tk) / 1.3332239e-4
    print("  T=%.1f K  calc %7.2f mmHg  paper %d mmHg  dev %+.2f%%"
          % (tk, pc, mmhg, 100.0 * (pc - mmhg) / mmhg))
print("  fitted temperature at 400 mmHg %.2f K (paper prints 373.1 K; back-calculated from the Ratio column as 323.1 K, judged a misprint)"
      % mb.meoh_Tsat_bar(400 * 1.3332239e-4))

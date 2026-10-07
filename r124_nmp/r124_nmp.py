# -*- coding: utf-8 -*-
"""
R124 (1) - NMP (2) vapour-liquid equilibrium.

Source: Xu, Wang, Wu, Hu & Jiang, "Measurement and Correlation of
Vapor-Liquid Equilibrium for R124-NMP and R124-DMF Mixtures",
J. Chem. Eng. Data 2017, 62, 3414-3422.  DOI 10.1021/acs.jced.7b00444

Model (paper Eqs. 4-11): five-parameter NRTL for the activity
coefficient of R124, gamma-phi bubble pressure with the vapor taken as
pure R124 (the paper finds NMP/DMF in the vapor negligible) and a
Poynting correction using the saturated-liquid molar volume of R124:

    tau12 = (a1 + b1 ln T)/(R T),   tau21 = (a2 + b2 ln T)/(R T)
    G12 = exp(-alpha tau12),        G21 = exp(-alpha tau21)
    ln g1 = x2^2 [ tau21 (G21/(x1+x2 G21))^2 + tau12 G12/(x2+x1 G12)^2 ]
    p = ps1 x1 g1 exp( VL1 (p - ps1)/(R T) )        (implicit, iterated)

Pure R124 saturation pressure: Antoine fit to the REFPROP values of
the paper's Table 5 (max deviation 0.05 %); saturated-liquid molar
volume: quadratic fit to the same table (max deviation 0.24 %, the
Poynting factor itself is worth at most ~6 %).

Concentration variable xi = R124 MASS fraction (repo convention);
the NRTL works in mole fractions, converted internally.
M(R124) = 136.50, M(NMP) = 99.13 g/mol.

VALID RANGE: T = 303.15-363.15 K (30-90 degC), the measured range.
Functions return NaN outside it - the parameters were fitted there
and this library does not extrapolate past a model's fitted edge.
Bubble pressure reproduces the paper's 53 measured points with
AARD 1.25 % (paper reports 1.25 %); see verify_r124_nmp.py.

NOT covered (no published data): mixture enthalpy, density,
viscosity.  The absorbent is treated as non-volatile, so the dew
point is the pure-R124 saturation temperature.

Units: T in degC, P in bar.
"""
import math

# Antoine fit to Xu 2017 Table 5 (REFPROP), p in kPa, T in K
_ANT_A = 14.750463
_ANT_B = 2527.6371
_ANT_C = -10.9815

# R124 saturated-liquid molar volume, quadratic in T_C [m3/kmol]
_VL = (3.43888821e-06, 5.21631071e-06, 9.89804979e-02)

# NRTL parameters (Xu 2017 Table 8), energies in J/mol
_A1, _B1 = 242408.0, -46295.3
_A2, _B2 = -166747.0, 30875.3
_ALPHA = -0.0515

_R = 8.314            # J/(mol K)
_M1 = 136.50          # R124
_M2 = 99.13          # NMP
_TMIN, _TMAX = 30.0, 90.0

NAN = float("nan")


def psat_R124(T_C):
    """Pure R124 saturation pressure [bar], 30-90 degC."""
    T = T_C + 273.15
    return math.exp(_ANT_A - _ANT_B / (T + _ANT_C)) / 100.0


def Tsat_R124(P_bar):
    """Pure R124 saturation temperature [degC] (= dew point here)."""
    if P_bar <= 0:
        return NAN
    T = _ANT_B / (_ANT_A - math.log(P_bar * 100.0)) - _ANT_C
    return T - 273.15


def _VL_R124(T_C):
    """R124 saturated-liquid molar volume [m3/mol]."""
    c2, c1, c0 = _VL
    return (c2 * T_C * T_C + c1 * T_C + c0) / 1000.0


def xi_to_x(xi):
    """R124 mass fraction -> mole fraction."""
    n1 = xi / _M1
    return n1 / (n1 + (1.0 - xi) / _M2)


def x_to_xi(x):
    """R124 mole fraction -> mass fraction."""
    m1 = x * _M1
    return m1 / (m1 + (1.0 - x) * _M2)


def gamma1(T_C, xi):
    """Activity coefficient of R124 (NRTL), NaN outside the range."""
    if not (_TMIN <= T_C <= _TMAX):
        return NAN
    T = T_C + 273.15
    x1 = xi_to_x(xi)
    x2 = 1.0 - x1
    if x1 <= 0.0:
        return NAN
    if x1 >= 1.0:
        return 1.0
    lnT = math.log(T)
    t12 = (_A1 + _B1 * lnT) / (_R * T)
    t21 = (_A2 + _B2 * lnT) / (_R * T)
    G12 = math.exp(-_ALPHA * t12)
    G21 = math.exp(-_ALPHA * t21)
    lng = x2 * x2 * (t21 * (G21 / (x1 + x2 * G21)) ** 2
                     + t12 * G12 / (x2 + x1 * G12) ** 2)
    return math.exp(lng)


def bubble_P(T_C, xi):
    """Bubble-point pressure [bar]; vapor = pure R124."""
    if not (_TMIN <= T_C <= _TMAX) or not (0.0 < xi < 1.0):
        return NAN
    T = T_C + 273.15
    ps1 = psat_R124(T_C)                      # bar
    x1 = xi_to_x(xi)
    p = ps1 * x1 * gamma1(T_C, xi)            # bar
    vl = _VL_R124(T_C)                        # m3/mol
    for _ in range(50):
        pn = ps1 * x1 * gamma1(T_C, xi) * math.exp(
            vl * (p - ps1) * 1.0e5 / (_R * T))
        if abs(pn - p) < 1e-10:
            p = pn
            break
        p = pn
    return p


def bubble_T(P_bar, xi, iters=60):
    """Bubble-point temperature [degC] at P [bar]; NaN if the root is
    outside the validated 30-90 degC window."""
    lo, hi = _TMIN, _TMAX
    plo, phi = bubble_P(lo, xi), bubble_P(hi, xi)
    if math.isnan(plo) or math.isnan(phi) or not (plo <= P_bar <= phi):
        return NAN
    for _ in range(iters):
        mid = 0.5 * (lo + hi)
        if bubble_P(mid, xi) < P_bar:
            lo = mid
        else:
            hi = mid
    return 0.5 * (lo + hi)


def dew_T(P_bar, xi=None):
    """Dew point [degC]: absorbent non-volatile -> pure R124 Tsat.
    The mixture model is windowed to 30-90 degC, but the dew point is
    a pure-fluid reference: below 30 degC the Antoine (anchored on
    REFPROP at 303-363 K) is extrapolated a short way, to -30 degC."""
    T = Tsat_R124(P_bar)
    return T if -30.0 <= T <= _TMAX else NAN


if __name__ == "__main__":
    print("R124-NMP: bubble pressure [bar]")
    print("  T_C    xi=0.3   xi=0.5   xi=0.7   xi=0.85")
    for T in (30.0, 50.0, 70.0, 90.0):
        row = " ".join("%8.3f" % bubble_P(T, xi) for xi in (0.3, 0.5, 0.7, 0.85))
        print("%6.0f  %s" % (T, row))
    print("gamma1 at 60 C, xi=0.5:", round(gamma1(60.0, 0.5), 4))

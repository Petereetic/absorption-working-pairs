#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Ammonia-water mixture: Patek & Klomfar (1995) fast explicit correlations.

Reference:
    J. Patek, J. Klomfar,
    "Simple functions for fast calculations of selected thermodynamic
     properties of the ammonia-water system",
    Int. J. Refrigeration 18(4), 228-234, 1995.

Five explicit (non-iterative) equations:

    Eq (6):  T(p,x) = T0 * sum_i a_i (1-x)^m_i [ln(p0/p)]^n_i      bubble-point T
             T0 = 100 K, p0 = 2 MPa;  0.002 <= p <= 2 MPa, full x range
             95 % of fitted points within 1.5 K.
    Eq (7):  T(p,y) = T0 * sum_i a_i (1-y)^(m_i/4) [ln(p0/p)]^n_i  dew-point T
             T0 = 100 K, p0 = 2 MPa;  0.02 <= p <= 2 MPa
             95 % of fitted points within +/-2 K.
    Eq (8):  y(p,x) = 1 - exp[ ln(1-x) * sum_i a_i (p/p0)^m_i x^(n_i/3) ]
             equilibrium vapour mole fraction;
             valid for liquid NH3 mole fraction x > 0.05, p > 0.05 MPa.
    Eq (9):  h_l(T,x) = h0 * sum_i a_i (T/T0 - 1)^m_i x^n_i        liquid enthalpy
             h0 = 100 kJ/kg, T0 = 273.16 K; RMS 0.9 kJ/kg vs Zinner data.
    Eq (10): h_g(T,y) = h0 * sum_i a_i (1 - T0/T)^m_i (1-y)^(n_i/4) vapour enthalpy
             h0 = 1000 kJ/kg, T0 = 324 K; < 1 % vs Scatchard / Ziegler-Trepp.

Reference state (paper): zero enthalpy for BOTH water and ammonia =
liquid water at the triple point.  So h_l(273.16 K, x=0) = 0 by construction.

Conventions in this module
---------------------------
x : ammonia MOLE fraction in the liquid phase   (paper's X)
y : ammonia MOLE fraction in the gas phase      (paper's Y)
p : pressure in MPa
T : temperature in K
h : specific enthalpy in kJ/kg

Unlike the R22-DMF / R134a-DMF / R22-DEGDME pairs already implemented,
BOTH components are volatile here, so the dew curve is a true mixture
dew curve (Eq 7), not the pure-refrigerant saturation temperature, and
the generator of an absorption cycle needs a rectifier.
"""

import math

# ---------------------------------------------------------------------------
# Coefficient tables: (m_i, n_i, a_i)
# ---------------------------------------------------------------------------

# Eq (6) T(p,x); T0 = 100 K, p0 = 2 MPa
_C6 = [
    (0, 0,  +3.22302),
    (0, 1,  -0.384206),
    (0, 2,  +0.0460965),
    (0, 3,  -0.00378945),
    (0, 4,  +0.000135610),
    (1, 0,  +0.487755),
    (1, 1,  -0.120108),
    (1, 2,  +0.0106154),
    (2, 3,  -0.000533589),
    (4, 0,  +7.85041),
    (5, 0,  -11.5941),
    (5, 1,  -0.0523150),
    (6, 0,  +4.89596),
    (13, 1, +0.0421059),
]

# Eq (7) T(p,y); T0 = 100 K, p0 = 2 MPa
_C7 = [
    (0, 0,  +3.24004),
    (0, 1,  -0.395920),
    (0, 2,  +0.0435624),
    (0, 3,  -0.00218943),
    (1, 0,  -1.43526),
    (1, 1,  +1.05256),
    (1, 2,  -0.0719281),
    (2, 0,  +12.2362),
    (2, 1,  -2.24368),
    (3, 0,  -20.1780),
    (3, 1,  +1.10834),
    (4, 0,  +14.5399),
    (4, 2,  +0.644312),
    (5, 0,  -2.21246),
    (5, 2,  -0.756266),
    (6, 0,  -1.35529),
    (7, 2,  +0.183541),
]

# Eq (8) y(p,x); p0 = 2 MPa
_C8 = [
    (0, 0,  +19.8022017),
    (0, 1,  -11.8092669),
    (0, 6,  +27.7479980),
    (0, 7,  -28.8634277),
    (1, 0,  -59.1616608),
    (2, 1,  +578.091305),
    (2, 2,  -6.21736743),
    (3, 2,  -3421.98402),
    (4, 3,  +11940.3127),
    (5, 4,  -24541.3777),
    (6, 5,  +29159.1865),
    (7, 6,  -18478.2290),
    (7, 7,  +23.4819434),
    (8, 7,  +4803.10617),
]

# Eq (9) h_l(T,x); h0 = 100 kJ/kg, T0 = 273.16 K
_C9 = [
    (0,  1,  -7.61080),
    (0,  4,  +25.6905),
    (0,  8,  -247.092),
    (0,  9,  +325.952),
    (0, 12,  -158.854),
    (0, 14,  +61.9084),
    (1,  0,  +11.4314),
    (1,  1,  +1.18157),
    (2,  1,  +2.84179),
    (3,  3,  +7.41609),
    (5,  3,  +891.844),
    (5,  4,  -1613.09),
    (5,  5,  +622.106),
    (6,  2,  -207.588),
    (6,  4,  -6.87393),
    (8,  0,  +3.50716),
]

# Eq (10) h_g(T,y); h0 = 1000 kJ/kg, T0 = 324 K
_C10 = [
    (0,  0, +1.28827),
    (1,  0, +0.125247),
    (2,  0, -2.08748),
    (3,  0, +2.17696),
    (0,  2, +2.35687),
    (1,  2, -8.86987),
    (2,  2, +10.2635),
    (3,  2, -2.37440),
    (0,  3, -6.70515),
    (1,  3, +16.4508),
    (2,  3, -9.36849),
    (0,  4, +8.42254),
    (1,  4, -8.58807),
    (0,  5, -2.77049),
    (4,  6, -0.961248),
    (2,  7, +0.988009),
    (1, 10, +0.308482),
]

_T0_67 = 100.0      # K,   Eqs (6),(7)
_P0 = 2.0           # MPa, Eqs (6),(7),(8)
_H0_9 = 100.0       # kJ/kg, Eq (9)
_T0_9 = 273.16      # K,     Eq (9)
_H0_10 = 1000.0     # kJ/kg, Eq (10)
_T0_10 = 324.0      # K,     Eq (10)

M_NH3 = 17.03052    # g/mol (IUPAC; paper does not print values,
M_H2O = 18.01528    # only needed for mole<->mass conversion)

# Validity ranges stated in the paper
P_RANGE_6 = (0.002, 2.0)   # MPa, Eq (6)
P_RANGE_7 = (0.02, 2.0)    # MPa, Eq (7)
X_MIN_8 = 0.05             # mole fraction, Eq (8)
P_MIN_8 = 0.05             # MPa, Eq (8)


# ---------------------------------------------------------------------------
# Core equations
# ---------------------------------------------------------------------------

def T_bubble_PX(p_MPa, x):
    """Eq (6): bubble-point temperature [K] at pressure p [MPa],
    liquid NH3 mole fraction x."""
    L = math.log(_P0 / p_MPa)
    omx = 1.0 - x
    s = 0.0
    for m, n, a in _C6:
        s += a * (omx ** m) * (L ** n)
    return _T0_67 * s


def T_dew_PY(p_MPa, y):
    """Eq (7): dew-point temperature [K] at pressure p [MPa],
    vapour NH3 mole fraction y."""
    L = math.log(_P0 / p_MPa)
    omy = max(0.0, 1.0 - y)
    s = 0.0
    for m, n, a in _C7:
        s += a * (omy ** (m / 4.0)) * (L ** n)
    return _T0_67 * s


def y_equil(p_MPa, x):
    """Eq (8): equilibrium vapour NH3 mole fraction at pressure p [MPa]
    and liquid NH3 mole fraction x.  Valid for x > 0.05 (mole)."""
    if x >= 1.0:
        return 1.0
    if x <= 0.0:
        return 0.0
    pr = p_MPa / _P0
    s = 0.0
    for m, n, a in _C8:
        s += a * (pr ** m) * (x ** (n / 3.0))
    return 1.0 - math.exp(math.log(1.0 - x) * s)


def h_liq(T_K, x):
    """Eq (9): saturated-liquid specific enthalpy [kJ/kg].
    Reference: h = 0 for liquid water at the triple point."""
    u = T_K / _T0_9 - 1.0
    s = 0.0
    for m, n, a in _C9:
        s += a * (u ** m) * (x ** n)
    return _H0_9 * s


def h_vap(T_K, y):
    """Eq (10): vapour specific enthalpy [kJ/kg] (ideal-mixture fit).
    Same reference state as h_liq."""
    v = 1.0 - _T0_10 / T_K
    omy = max(0.0, 1.0 - y)
    s = 0.0
    for m, n, a in _C10:
        s += a * (v ** m) * (omy ** (n / 4.0))
    return _H0_10 * s


# ---------------------------------------------------------------------------
# Convenience / composite functions
# ---------------------------------------------------------------------------

def mole_to_mass(x):
    """NH3 mole fraction -> NH3 mass fraction."""
    return x * M_NH3 / (x * M_NH3 + (1.0 - x) * M_H2O)


def mass_to_mole(xi):
    """NH3 mass fraction -> NH3 mole fraction."""
    return (xi / M_NH3) / (xi / M_NH3 + (1.0 - xi) / M_H2O)


def bubble_state_pX(p_MPa, x):
    """Full bubble state at (p, x): returns dict with
    T_bubble [K], y [vapour mole fraction], h_l [kJ/kg],
    h_g_bubble [kJ/kg] = h_g(T_bubble, y)  (cf. paper Fig. 8)."""
    Tb = T_bubble_PX(p_MPa, x)
    y = y_equil(p_MPa, x)
    return {
        "T_bubble": Tb,
        "y": y,
        "T_dew_of_y": T_dew_PY(p_MPa, y),
        "h_l": h_liq(Tb, x),
        "h_g": h_vap(Tb, y),
    }


def glide_pX(p_MPa, z):
    """True temperature glide [K] at pressure p [MPa] and overall NH3
    mole fraction z:
        glide = T_dew(p, y=z) - T_bubble(p, x=z).
    At fixed overall composition z, the bubble point is where the first
    vapour bubble forms (liquid still at z) and the dew point is where
    the first liquid drop condenses (vapour still at z).  Both components
    are volatile here, so this is a genuine mixture glide -- unlike the
    DMF/DEGDME pairs where the dew curve was approximated by the pure
    refrigerant saturation temperature."""
    st = bubble_state_pX(p_MPa, z)
    return T_dew_PY(p_MPa, z) - st["T_bubble"]


def consistency_residual_pX(p_MPa, x):
    """Self-consistency residual [K] = T_bubble(p,x) - T_dew(p, y(p,x)).
    The paper (p. 232) states the T(p,x), T(p,y), y(p,x) system was
    checked and found consistent to better than 1 % in y for x > 0.2
    (not worse than 5 % for x < 0.2).  A small residual here confirms
    the transcription."""
    st = bubble_state_pX(p_MPa, x)
    return st["T_bubble"] - st["T_dew_of_y"]


# ---------------------------------------------------------------------------
# Inverse functions (bisection on the forward equations)
# ---------------------------------------------------------------------------

def p_bubble_TX(T_K, x, p_lo=0.002, p_hi=2.0, tol=1e-9):
    """Bubble pressure [MPa] at temperature T [K] and liquid NH3 mole
    fraction x -- numerical inverse of Eq (6).  T_bubble(p, x) is
    monotonically decreasing in p, so bisection is safe."""
    flo = T_bubble_PX(p_lo, x) - T_K
    for _ in range(200):
        pm = 0.5 * (p_lo + p_hi)
        fm = T_bubble_PX(pm, x) - T_K
        if fm == 0.0 or (p_hi - p_lo) < tol * max(1.0, pm):
            return pm
        # T decreases as p increases: if fm > 0, T(pm) too high -> raise p
        if (fm > 0.0) == (flo > 0.0):
            p_lo, flo = pm, fm
        else:
            p_hi = pm
    return 0.5 * (p_lo + p_hi)


def p_dew_TY(T_K, y, p_lo=0.02, p_hi=2.0, tol=1e-9):
    """Dew pressure [MPa] at temperature T [K] and vapour NH3 mole
    fraction y -- numerical inverse of Eq (7)."""
    flo = T_dew_PY(p_lo, y) - T_K
    for _ in range(200):
        pm = 0.5 * (p_lo + p_hi)
        fm = T_dew_PY(pm, y) - T_K
        if fm == 0.0 or (p_hi - p_lo) < tol * max(1.0, pm):
            return pm
        if (fm > 0.0) == (flo > 0.0):
            p_lo, flo = pm, fm
        else:
            p_hi = pm
    return 0.5 * (p_lo + p_hi)


if __name__ == "__main__":
    # --- Transcription checks against pure-component limits ---
    print("Pure NH3, Eq(6) T(2 MPa, x=1)   = %.2f K  (expect ~322.3 K / 49.1 C)" % T_bubble_PX(2.0, 1.0))
    print("Pure H2O, Eq(6) T(2 MPa, x=0)   = %.2f K  (expect ~485.6 K / 212.4 C)" % T_bubble_PX(2.0, 0.0))
    print("Pure NH3, Eq(7) T(2 MPa, y=1)   = %.2f K  (expect ~324.0 K)" % T_dew_PY(2.0, 1.0))
    print("Pure H2O, Eq(7) T(2 MPa, y=0)   = %.2f K  (expect ~485.6 K)" % T_dew_PY(2.0, 0.0))
    print("Pure NH3, Eq(6) T(1 MPa, x=1)   = %.2f K  (NH3 Tsat@1MPa ~ 298.4 K)" % T_bubble_PX(1.0, 1.0))
    print("h_l(273.16 K, x=0) = %.4f kJ/kg (reference state = 0)" % h_liq(273.16, 0.0))
    print("h_l(273.16 K, x=1) = %.4f kJ/kg (expect ~0)" % h_liq(273.16, 1.0))
    print()
    # --- A cycle-relevant point ---
    p, z = 1.0, 0.5
    st = bubble_state_pX(p, z)
    print("p = 1 MPa, overall x = z = 0.5 (mole):")
    print("  T_bubble(x=z) = %.2f C,  T_dew(y=z) = %.2f C,  glide = %.2f K"
          % (st["T_bubble"] - 273.15, T_dew_PY(p, z) - 273.15, glide_pX(p, z)))
    print("  equilibrium vapour y(x=0.5) = %.4f" % st["y"])
    print("  consistency residual |T_bub(x)-T_dew(y(x))| = %.2f K (expect <~1 K)"
          % abs(consistency_residual_pX(p, z)))
    print("  h_l = %.1f kJ/kg,  h_g(bubble) = %.1f kJ/kg" % (st["h_l"], st["h_g"]))

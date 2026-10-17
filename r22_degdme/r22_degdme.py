# Thermodynamic correlations for R22-DEGDME (reference implementation)
# Source: E. Ando, I. Takeshita,
#   "Residential gas-fired absorption heat pump based on R22-DEGDME pair.
#    Part I Thermodynamic properties of the R22-DEGDME pair",
#   Int. J. Refrigeration, Vol.7, No.3, pp.181-186, 1984.
#
# All three correlations are computable; the constants are taken directly from Table 2, Table 3 and Eq. (7) of the paper:
#   Eq. (1) Bubble-point pressure, Rankine equation   lnP = ΣAnX^n + (1/T)ΣBnX^n + lnT·ΣCnX^n
#         P: kg/cm2, T: K, X: R22 mole fraction; valid X=0.1~1.0, P=0.1~30 kg/cm2,
#         T=-20~190°C; 151 points, mean relative deviation 0.79%
#   Eq. (6) Molar heat-capacity polynomial        C = ΣAnX^n + t·ΣBnX^n + t^2·ΣCnX^n
#         C: J/mol/°C, t: °C; all concentrations, t=-30~110°C; 193 points, mean relative deviation 0.83%
#   Eq. (7) Heat of mixing, Redlich-Kister  ΔHm = X(1-X)·Σ Gi·(1-2X)^(i-1), i=1..4
#         ΔHm: J/mol, measured at 10°C; 11 points, mean relative deviation 0.72%
#   Eq. (9) Solution-enthalpy assembly            H(T,X) = (1-X)H1 + X·H2 + ΔHm + integral(Tm->T) Cp dτ
#
# Reference state (a convention of this document; Part I of the paper fixes no absolute enthalpy value):
#   The pure-component liquids have enthalpy 0 at Tm=10°C;
#   then H(T,X) = ΔHm(X) + integral(10°C->t) Cp(X,τ) dτ   [J/mol], converted to kJ/kg.
# Note: X is the R22 mole fraction (the paper's system), not a mass fraction.

import math

# ---- Constants ----
_M_R22 = 86.47      # g/mol, CHClF2
_M_DEGDME = 134.17  # g/mol, C6H14O3 (bis(2-methoxyethyl)ether)
_TM_C = 10.0        # heat-of-mixing measurement temperature / enthalpy reference temperature, °C
_KGCM2_TO_MPA = 0.0980665  # 1 kg/cm2 = 0.0980665 MPa (exact definition)

# Table 2: (A, B, C) of Eq. (1) for n=0..5
_T2 = [
    ( 5.2167e1, -5.5828e3, -6.3489e0),
    ( 1.2753e1,  3.3999e3, -1.4386e0),
    (-1.3901e2, -8.6015e3,  2.2313e1),
    ( 7.3205e2, -3.1686e3, -1.1454e2),
    (-1.1910e3,  3.0425e4,  1.8148e2),
    ( 5.4717e2, -1.9049e4, -8.1999e1),
]

# Table 3: (A, B, C) of Eq. (6) for n=0..3
_T3 = [
    ( 2.7974e2, -4.2015e-2,  2.3114e-3),
    (-1.5075e2,  5.9865e-1, -5.9745e-3),
    ( 1.0095e2, -1.3790e0,   3.4322e-3),
    (-1.2802e2,  1.0167e0,   1.0571e-3),
]

# Eq. (7): G1..G4
_G = (-1.9061e4, 8.7280e3, -1.3948e3, -6.4218e2)


def _poly(coefs, X):
    s = 0.0
    for n, c in enumerate(coefs):
        s += c * X ** n
    return s


def psol_kgcm2(X, T_K):
    """Eq. (1): bubble-point pressure, kg/cm2. X = R22 mole fraction, T_K in kelvin."""
    sA = _poly([r[0] for r in _T2], X)
    sB = _poly([r[1] for r in _T2], X)
    sC = _poly([r[2] for r in _T2], X)
    return math.exp(sA + sB / T_K + sC * math.log(T_K))


def psol_bar(X, t_C):
    """Eq. (1): bubble-point pressure, MPa.

    [Note: the function name psol_bar is the retained original name (renaming pending a ruling); the return unit has been
    changed from bar to MPa] = native kg/cm2 value x0.0980665. t_C in °C."""
    return psol_kgcm2(X, t_C + 273.15) * _KGCM2_TO_MPA


def xi_by_tsol_tdew(Tsol_C, Tdew_C):
    """Solve the concentration X (R22 mole fraction) back from the dew-point temperature and the solution temperature, by 80 bisection steps.

    The dew point fixes the pressure P = psol_kgcm2(1.0, Tdew_C+273.15) [native kg/cm2]:
    at the X=1 end, Eq. (1) is this module's pure-R22 saturation pressure (DEGDME treated as
    non-volatile); then bisection solves psol_kgcm2(X, Tsol_C+273.15) = P, with the bracket taken as the valid concentration domain of
    Eq. (1), X in [0.1, 1.0]. Internally the native kg/cm2 functions are used throughout (not via the
    MPa export line), so the temperature/concentration outputs are bit-for-bit unchanged.
    Returns None when there is no root (e.g. Tsol clearly below Tdew, with P outside the bubble-point
    pressure interval under Tsol).
    """
    P = psol_kgcm2(1.0, Tdew_C + 273.15)
    Plo, Phi = psol_kgcm2(0.1, Tsol_C + 273.15), psol_kgcm2(1.0, Tsol_C + 273.15)
    if not (Plo <= P <= Phi):
        return None
    lo, hi = 0.1, 1.0
    for _ in range(80):
        mid = 0.5 * (lo + hi)
        if psol_kgcm2(mid, Tsol_C + 273.15) < P:
            lo = mid
        else:
            hi = mid
    return 0.5 * (lo + hi)



def tdew_by_tsol_xi(X, t_C):
    """Dew-point temperature [°C] of the solution at (X, t_C) (library-wide TdewByTsolXi convention):
    Tdew is the temperature at which this module's own pure-R22 line (the X=1 end of Eq. (1)) satisfies
    psol_kgcm2(1.0, Tdew+273.15) = psol_kgcm2(X, t_C+273.15)
    [native kg/cm2], inverted by 80 bisection steps, with the solution bracket
    t in [-50, 190] °C. Internally the native kg/cm2 functions are used throughout (not via the MPa
    export line), so the temperature output is bit-for-bit unchanged. Note: the nominal temperature domain of
    Eq. (1) is -20~190 °C; results with Tdew < -20 °C use an extrapolation of the pure end outside its domain
    (an extrapolation of the Rankine-type equation form); this note must accompany any citation.
    DEGDME is treated as non-volatile. Returns None when P lies outside the pressure span of the pure end within the bracket.
    (This module's function convention is the (X, T) parameter order; this function follows it.)"""
    P = psol_kgcm2(X, t_C + 273.15)
    lo, hi = -50.0, 190.0
    if not (psol_kgcm2(1.0, lo + 273.15) <= P <= psol_kgcm2(1.0, hi + 273.15)):
        return None
    for _ in range(80):
        mid = 0.5 * (lo + hi)
        if psol_kgcm2(1.0, mid + 273.15) < P:
            lo = mid
        else:
            hi = mid
    return 0.5 * (lo + hi)


def tsol_by_hsol(h, X):
    """Solve the solution temperature [°C] back from the solution specific enthalpy h [kJ/kg] and R22 mole fraction X:
    hsol increases monotonically with t at fixed X (the specific heat of Eq. (6) is positive within its domain);
    inverted by 100 bisection steps, with the solution bracket t in [-30, 110] °C (the domain of Eq. (6)).
    Returns None when h lies outside the range of hsol at that X."""
    lo, hi = -30.0, 110.0
    hlo, hhi = hsol(X, lo), hsol(X, hi)
    if not (hlo <= h <= hhi):
        return None
    for _ in range(100):
        mid = 0.5 * (lo + hi)
        if hsol(X, mid) < h:
            lo = mid
        else:
            hi = mid
    return 0.5 * (lo + hi)


def cp_molar(X, t_C):
    """Eq. (6): molar heat capacity of the mixture at constant pressure, J/mol/°C."""
    sA = _poly([r[0] for r in _T3], X)
    sB = _poly([r[1] for r in _T3], X)
    sC = _poly([r[2] for r in _T3], X)
    return sA + t_C * sB + t_C * t_C * sC


def heat_of_mixing(X):
    """Eq. (7): molar heat of mixing (measured at 10°C), J/mol. Negative when exothermic."""
    return X * (1.0 - X) * sum(g * (1.0 - 2.0 * X) ** i for i, g in enumerate(_G))


def hsol(X, t_C):
    """Eq. (9): solution specific enthalpy, kJ/kg.
    Reference state: the pure-component liquids have enthalpy 0 at 10°C (a convention of this document)."""
    sA = _poly([r[0] for r in _T3], X)
    sB = _poly([r[1] for r in _T3], X)
    sC = _poly([r[2] for r in _T3], X)
    t0 = _TM_C
    sensible = (sA * (t_C - t0)
                + sB * (t_C * t_C - t0 * t0) / 2.0
                + sC * (t_C ** 3 - t0 ** 3) / 3.0)  # J/mol
    h_mol = heat_of_mixing(X) + sensible  # J/mol
    M_mix = X * _M_R22 + (1.0 - X) * _M_DEGDME  # g/mol
    return h_mol / M_mix  # kJ/kg


if __name__ == "__main__":
    # Self-check: comparison against Fig. 6 of the paper (the minimum of ΔHm is about -5000 J/mol) and physical orders of magnitude
    print("Psol(X=1.0, 10°C)  = %.3f kg/cm2" % psol_kgcm2(1.0, 283.15))
    print("Psol(X=0.5, 10°C)  = %.4f MPa" % psol_bar(0.5, 10.0))
    print("Psol(X=0.5, 80°C)  = %.4f MPa" % psol_bar(0.5, 80.0))
    print("Cp  (X=0.5, 10°C)  = %.1f J/mol/K" % cp_molar(0.5, 10.0))
    print("dHm (X=0.5)        = %.0f J/mol" % heat_of_mixing(0.5))
    print("Hsol(X=0.5, 10°C)  = %.2f kJ/kg" % hsol(0.5, 10.0))
    print("Hsol(X=0.5, 80°C)  = %.2f kJ/kg" % hsol(0.5, 80.0))
    print("Hsol(X=0.5,-20°C)  = %.2f kJ/kg" % hsol(0.5, -20.0))

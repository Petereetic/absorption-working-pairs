#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
nh3_lino3.py -- Reference implementation of the properties of ammonia-lithium nitrate (NH3/LiNO3) solutions
================================================================
Source: Amaris Castilla, C.F. (2014), doctoral thesis,
"Intensification of NH3 Bubble Absorption Process Using Advanced
Surfaces and Carbon Nanotubes for NH3/LiNO3 Absorption Chillers",
Universitat Rovira i Virgili, correlations transcribed in Appendix B (pp. A-6 ~ A-8):

  Bubble-point pressure   Libotean et al. (2007), J. Chem. Eng. Data 52, 1050-1055
             ln P[kPa] = pa(x) + pb(x)/T[K]; pa/pb are cubic polynomials in x
             (the ln P[kPa] above follows the paper's source-formula convention; this module's internal arithmetic keeps kPa,
             and pressures at public-function boundaries are always MPa; see "Conventions" below)
  Liquid enthalpy     Valles & Salavera (2011, internal report), Haltenberger (1939) method
             H[kJ/kg] = ha(x) + hb(x) T + hc(x) T^2
  Specific heat       Libotean et al. (2008): Cp = cpa(x) + cpb(x) T
  Density       Libotean et al. (2008): rho = 1000 (da(x) + db(x) T)
  Thermal conductivity       Cuenca et al. (2013a): k = ka1 + ka2 T + ka3 T^2 + ka4 x
  Crystallisation limit   Infante Ferreira et al. (1984): XCRIS ten-segment polynomial
  Viscosity       Libotean et al. (2008) -- the typesetting in the thesis is damaged and the reconstructed form is unverified;
             provided in Python only and marked EXPERIMENTAL; not implemented in C/VBA

Conventions
----
* x : ammonia mass fraction (a fraction, e.g. 0.5), not a percentage
* T : K (the T of the crystallisation function x_cris is in °C, as in the original)
* p : MPa (at public-function boundaries; internal arithmetic and the source formulas remain in kPa; public functions convert
  MPa <-> kPa only at the boundary), h : kJ/kg, cp : kJ/(kg K),
  rho : kg/m^3, k : W/(m K)

Reference state (enthalpy, as in the source)
------------------------
The ammonia enthalpy takes 0 kJ/kg at 0 °C as its zero; the mixture reference state is 0 °C and ammonia mass fraction 0.5,
where H = 0 kJ/kg. This module keeps the source reference state; it is not unified with the other pairs in this library.

Valid ranges (outside them a ValueError is raised; no silent extrapolation)
--------------------------------------------
  psol_TX / T_bubble_PX : T 293.15-353.15 K, x 0.35-0.65
  hsol                     : T 273.15-353.15 K, x 0.35-0.65
                              (the lower bound is the reference-state temperature: the enthalpy formula is constructed by the Haltenberger method,
                              integrating from 273.15 K, and the reference point holds exactly by definition;
                              the VLE data support interval is 293.15-353.15 K)
  cp, rho                   : T 293.15-353.15 K, x 0.35-0.65
  k_therm                   : T 303.15-353.15 K, x 0.35-0.60
  x_cris                    : x 0-1 (branch domain of the original pseudocode), T in °C

Notes
----
* Thermal conductivity: Appendix B of the thesis prints k = ka1 + ka2 T + ka3 T^2 x + ka4 x (the ka3 term carries an x).
  This module implements the reading without the extra x (ka3 T^2); the two readings differ at 300 K/x=0.4
  by about 3%. See the formula notes file.
* x_cris: the original pseudocode is XCRIS = f(TSol[°C], xSol), branching on xSol. This function's
  signature is x_cris(T_C, x); branch endpoints belong to the segment of the lower bound (the original uses strict inequalities).
"""

import math

# ---------------------------------------------------------------------------
# Coefficients (transcribed verbatim from Appendix B of the thesis; re-checked against the pdftotext extraction on 2026-10-03)
# ---------------------------------------------------------------------------

# Bubble-point pressure, Libotean et al. (2007): cubic-polynomial coefficients for pa/pb (constant term first)
_PA = (4.99470524658178, 88.5490906185871, -197.698944465798, 134.938665891525)
_PB = (-1793.21854659273, -22317.1158016582, 61289.3128925447, -45238.5915843719)

# Liquid enthalpy, Valles & Salavera (2011): cubic-polynomial coefficients for ha/hb/hc
_HA = (249.1567745, -1628.297463, -464.3464344, -105.6321057)
_HB = (2.481273559, -5.184392344, -0.775202139, 18.98142102)
_HC = (-0.004240786, 0.025111292, -0.013342843, -0.025956064)

# Specific heat, Libotean et al. (2008): cpa/cpb are linear in x (intercept, slope)
_CPA = (0.559273057, 3.241167393)      # J/(g K) datum term
_CPB = (0.00207796, 0.001846907)       # J/(g K^2)

# Density, Libotean et al. (2008): da/db are linear in x
_DA = (1.521, -0.4528)
_DB = (-0.00001961, -0.001726)

# Thermal conductivity, Cuenca et al. (2013a)
_KA1, _KA2, _KA3, _KA4 = 0.446088003, -0.000350326, 2.13849e-07, 0.006538043

# Viscosity reconstruction coefficients (unverified; see the mu_visc docstring)
_VA = (1.918, 10.094, -18.394)
_VB = (-1.205, -35.627, 51.529)

# Valid ranges
_T_VLE = (293.15, 353.15)   # K (bubble point / cp / density)
_T_H = (273.15, 353.15)     # K (enthalpy: the lower bound is the reference-state temperature; see the module header note)
_T_KTH = (303.15, 353.15)   # K (thermal conductivity)
_X_VLE = (0.35, 0.65)
_X_KTH = (0.35, 0.60)


def _poly(c, x):
    """Horner: c0 + c1 x + c2 x^2 + ..."""
    s = 0.0
    for ci in reversed(c):
        s = s * x + ci
    return s


def _check(T_K, x, t_rng, x_rng, name):
    if not (t_rng[0] <= T_K <= t_rng[1]):
        raise ValueError(f"{name}: T={T_K} K outside {t_rng} K")
    if not (x_rng[0] <= x <= x_rng[1]):
        raise ValueError(f"{name}: x={x} outside {x_rng}")


# ---------------------------------------------------------------------------
# Bubble-point pressure and bubble-point temperature
# ---------------------------------------------------------------------------

def _pa_pb(x):
    return _poly(_PA, x), _poly(_PB, x)


def _psol_TX_kPa(T_K, x):
    """(private, internal native value) Bubble-point pressure [kPa]: temperature T_K [K], ammonia mass fraction x.

    ln P = pa(x) + pb(x)/T  (Libotean et al. 2007; the source formula is in kPa)
    """
    _check(T_K, x, _T_VLE, _X_VLE, "psol_TX")
    pa, pb = _pa_pb(x)
    return math.exp(pa + pb / T_K)


def psol_TX(T_K, x):
    """Bubble-point pressure [MPa]: solution at temperature T_K [K] and ammonia mass fraction x.

    The public boundary only converts units: returns _psol_TX_kPa(T_K, x) * 1e-3
    (internal source formula ln P[kPa] = pa(x) + pb(x)/T, Libotean et al. 2007).
    """
    return _psol_TX_kPa(T_K, x) * 1e-3


def _T_bubble_PX_kPa(P_kPa, x):
    """(private, internal native value) Bubble-point temperature [K]: pressure P_kPa [kPa], ammonia mass fraction x.

    Analytic inverse: T = pb / (ln P - pa). The result must lie within 293.15-353.15 K.
    """
    if not (_X_VLE[0] <= x <= _X_VLE[1]):
        raise ValueError(f"T_bubble_PX: x={x} outside {_X_VLE}")
    if P_kPa <= 0.0:
        raise ValueError("T_bubble_PX: P must be > 0")
    pa, pb = _pa_pb(x)
    denom = math.log(P_kPa) - pa
    if denom == 0.0:
        raise ValueError("T_bubble_PX: ln P == pa, no finite solution")
    T_K = pb / denom
    if not (_T_VLE[0] <= T_K <= _T_VLE[1]):
        raise ValueError(
            f"T_bubble_PX: result T={T_K} K outside {_T_VLE} K")
    return T_K


def T_bubble_PX(P_MPa, x):
    """Bubble-point temperature [K]: solution at pressure P_MPa [MPa] and ammonia mass fraction x.

    The public boundary only converts units: the MPa input is converted back to kPa and passed to the internal native function
    _T_bubble_PX_kPa for analytic inversion. The result must lie within 293.15-353.15 K.
    """
    return _T_bubble_PX_kPa(P_MPa * 1e3, x)


# ---------------------------------------------------------------------------
# Pure-ammonia saturation line (dew-point convention, for use by x_by_tsol_tdew)
# ---------------------------------------------------------------------------
# LiNO3 is non-volatile; the vapour phase is treated as pure ammonia. The pure-ammonia line was re-sourced on 2026-10-12 (see the formula notes file):
# it now uses a compact fit to the ammonia NIST saturation table -- an lnP-t degree-7 polynomial (source: NIST WebBook
# saturation table, 210 points, -77~132 degC; the max deviation over the usual fit band -50~+60 degC
# is 0.0027%; coefficients and verification are in the working-pair formula materials library document "Pure-ammonia saturation property fit - NIST table",
# of the same origin as the ammonia fit in pure_fluids). Previously, the endpoint at ammonia mole fraction = 1 of the Patek-Klomfar Eq. (6)
# of the ammonia-water module was used: at 25 degC that endpoint gives 1012 kPa, about 0.9% above the NIST
# table value 1002.69 kPa; from now on it is kept only as a historical convention, accounted separately from this line.
# The mixture bubble-point formula (psol_TX) is unchanged. Fit domain t = -77~132 degC
# (P approx. 6.4~11280 kPa).

_NH3_FIT = (-0.8457026848887617, 0.03739502393748032,
            -0.00015333383280607642, 6.551063627525382e-07,
            -2.4759314474490567e-09, 9.070213653911228e-12,
            -3.681466540446358e-14, 1.1501679663496297e-16)
_NH3_TLO, _NH3_THI = -77.0, 132.0    # degC, domain of the NIST-table fit


def _pref_NH3_pure(T_K):
    """Pure-ammonia saturation pressure [kPa] (NIST-table lnP-t degree-7 polynomial fit; P in the formula is in MPa).

    Returns None when T_K lies outside the fit domain -77~132 degC.
    """
    t = T_K - 273.15
    if not (_NH3_TLO <= t <= _NH3_THI):
        return None
    lnP = 0.0
    for c in reversed(_NH3_FIT):
        lnP = lnP * t + c
    return 1000.0 * math.exp(lnP)


def _Tsat_NH3_pure(P_kPa):
    """Pure-ammonia saturation temperature [K]: inverted from _pref_NH3_pure by 80 bisection steps.

    Returns None when P_kPa lies outside the pressure span of the fit domain (approx. 6.4~11280 kPa).
    """
    lo, hi = _NH3_TLO + 273.15, _NH3_THI + 273.15
    if not (_pref_NH3_pure(lo) <= P_kPa <= _pref_NH3_pure(hi)):
        return None
    for _ in range(80):
        mid = 0.5 * (lo + hi)
        if _pref_NH3_pure(mid) < P_kPa:
            lo = mid
        else:
            hi = mid
    return 0.5 * (lo + hi)


def x_by_tsol_tdew(Tsol_K, Tdew_K):
    """Solve the ammonia mass fraction x back from the dew-point temperature and the solution temperature.

    Dew-point pressure: P = _pref_NH3_pure(Tdew_K) (pure-ammonia saturation pressure; convention above);
    then 80 bisection steps invert _psol_TX_kPa(Tsol_K, x) = P (internal kPa throughout,
    not via the public MPa boundary); the bracket is the bubble-point function's valid concentration domain x = 0.35-0.65
    (the bubble-point pressure increases monotonically with x in that domain).
    Returns None when there is no root (P outside the span of bubble-point pressures under Tsol, e.g. the solution temperature
    clearly below the dew-point temperature; or Tdew_K outside the pure-ammonia NIST fit domain). Note: this function
    follows the cross-pair library convention of returning None; it does not use the raise ValueError convention
    of the rest of this module.
    """
    P = _pref_NH3_pure(Tdew_K)
    if P is None:
        return None
    if not (_T_VLE[0] <= Tsol_K <= _T_VLE[1]):
        return None
    Plo = _psol_TX_kPa(Tsol_K, _X_VLE[0])
    Phi = _psol_TX_kPa(Tsol_K, _X_VLE[1])
    if not (Plo <= P <= Phi):
        return None
    lo, hi = _X_VLE
    for _ in range(80):
        mid = 0.5 * (lo + hi)
        if _psol_TX_kPa(Tsol_K, mid) < P:
            lo = mid
        else:
            hi = mid
    return 0.5 * (lo + hi)


# ---------------------------------------------------------------------------
# Liquid enthalpy / specific heat / density / thermal conductivity
# ---------------------------------------------------------------------------

def hsol(T_K, x):
    """Solution specific enthalpy [kJ/kg] (Valles & Salavera 2011, Haltenberger method).

    H = ha(x) + hb(x) T + hc(x) T^2, with T in K.
    Reference state: H = 0 at 0 °C and x=0.5 (per the source; differs from the other pairs in this library).
    """
    _check(T_K, x, _T_H, _X_VLE, "hsol")
    ha = _poly(_HA, x)
    hb = _poly(_HB, x)
    hc = _poly(_HC, x)
    return ha + hb * T_K + hc * T_K * T_K



def tdew_from_tsol_x(T_K, x):
    """Dew-point temperature [K] of the solution at (T_K, x) (library-wide TdewByTsolXi convention):
        Tdew = _Tsat_NH3_pure(_psol_TX_kPa(T_K, x)),
    i.e. the saturation temperature corresponding to the solution surface pressure Psol, evaluated with the pure-ammonia NIST fit line
    (re-sourced on 2026-10-12; see the comment above _pref_NH3_pure) (internal kPa throughout,
    not via the public MPa boundary). LiNO₃ is non-volatile,
    the vapour phase is treated as pure ammonia, so there is no endpoint-convention issue. The domain follows psol_TX (T 293.15-353.15 K,
    x 0.35-0.65); out of domain, the ValueError of _psol_TX_kPa propagates as usual."""
    return _Tsat_NH3_pure(_psol_TX_kPa(T_K, x))


def tsol_by_hsol(h, x):
    """Solve the solution temperature [K] back from the solution specific enthalpy h [kJ/kg] and ammonia mass fraction x:
    hsol increases monotonically with T at fixed x (cp > 0); inverted by 100 bisection steps,
    with the solution bracket taken as the hsol domain T in [273.15, 353.15] K (_T_H).
    Returns None when h lies outside the range of hsol at that x; when x is out of domain, the ValueError of hsol
    propagates as usual."""
    lo, hi = 273.15, 353.15
    hlo, hhi = hsol(lo, x), hsol(hi, x)
    if not (hlo <= h <= hhi):
        return None
    for _ in range(100):
        mid = 0.5 * (lo + hi)
        if hsol(mid, x) < h:
            lo = mid
        else:
            hi = mid
    return 0.5 * (lo + hi)


def cp(T_K, x):
    """Solution specific heat [kJ/(kg K)] (Libotean et al. 2008).

    The Cp of the original is in J/(g K): Cp = cpa(x) + cpb(x) T; the numerical value is the same as in kJ/(kg K).
    """
    _check(T_K, x, _T_VLE, _X_VLE, "cp")
    cpa = _CPA[0] + _CPA[1] * x
    cpb = _CPB[0] + _CPB[1] * x
    return cpa + cpb * T_K


def rho(T_K, x):
    """Solution density [kg/m^3] (Libotean et al. 2008).

    rho = 1000 * (da(x) + db(x) T), with T in K.
    """
    _check(T_K, x, _T_VLE, _X_VLE, "rho")
    da = _DA[0] + _DA[1] * x
    db = _DB[0] + _DB[1] * x
    return 1000.0 * (da + db * T_K)


def k_therm(T_K, x):
    """Solution thermal conductivity [W/(m K)] (Cuenca et al. 2013a).

    k = ka1 + ka2 T + ka3 T^2 + ka4 x.
    Note: Appendix B of the thesis prints ka3 T^2 x (the ka3 term carries an x); this implementation follows the reading without the extra x;
    the two readings differ by about 3%; see the formula notes file.
    """
    _check(T_K, x, _T_KTH, _X_KTH, "k_therm")
    return _KA1 + _KA2 * T_K + _KA3 * T_K * T_K + _KA4 * x


# ---------------------------------------------------------------------------
# Crystallisation limit (Infante Ferreira et al. 1984; the Appendix B pseudocode transcribed verbatim)
# ---------------------------------------------------------------------------

def x_cris(T_C, x):
    """Crystallisation-limit quantity XCRIS (Infante Ferreira et al. 1984).

    Original pseudocode: XCRIS = f(TSol[°C], xSol), branching on the solution ammonia mass fraction xSol;
    each segment is a polynomial in T[°C]. This function transcribes all ten segments verbatim; branch endpoints belong to the segment of
    the lower bound (the original uses strict inequalities). x must lie within [0, 1].
    The physical dimension of XCRIS is recorded as printed in the original pseudocode; for how to compare it against state points in use,
    see the original report of Infante Ferreira et al. (1984).
    """
    T = T_C
    if x < 0.2911:
        return 0.3021 - 0.00034 * T - 0.00000272 * T * T
    if x < 0.3:
        return x
    if x < 0.3076:
        return -0.000608 * T + 0.3152
    if x < 0.3362:
        return 0.0143 * T + 0.12885
    if x < 0.4304:
        return -0.005402 * T + 0.41318
    if x < 0.5072:
        return 0.443413 + 0.0069 * T + 0.000854 * T * T
    if x < 0.6434:
        return 0.527643 - 0.003126 * T - 0.000019 * T * T
    if x < 0.6649:
        return -0.004605 * T + 0.40761
    if x < 0.7826:
        return 0.0000309 * T * T + 0.57452
    if x <= 1.0:
        return 0.07378 * T + 6.7214
    raise ValueError(f"x_cris: x={x} outside [0, 1]")


# ---------------------------------------------------------------------------
# Viscosity (EXPERIMENTAL / UNVERIFIED -- Python only; not implemented in C/VBA)
# ---------------------------------------------------------------------------

def mu_visc(T_K, x):
    """Dynamic viscosity [mPa s] -- **experimental reconstruction, unverified; do not use for engineering calculations**.

    The viscosity formula in Appendix B of the thesis is typeset in damaged form (the original shows it in a stacked form,
    "Sol = e^(1000 va / vb / T)", with operators lost). This function reconstructs it, on grounds of numerical plausibility, as
        mu = exp(va(x) * 1000 / T + vb(x)),
        va = 1.918 + 10.094 x - 18.394 x^2,
        vb = -1.205 - 35.627 x + 51.529 x^2,
    Spot checks: at x=0.45, 313.15 K -> approx. 6.9 mPa s; 293.15 K -> approx. 12.6 mPa s
    (plausible orders of magnitude). Before admission to the library it must be checked against the original of Libotean et al. (2008),
    J. Chem. Eng. Data 53, 2383-2388.
    """
    va = _poly(_VA, x)
    vb = _poly(_VB, x)
    return math.exp(va * 1000.0 / T_K + vb)

#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
libr_water.py -- Reference implementation of the properties of lithium-bromide aqueous solutions (Patterson + Chua hybrid)
================================================================
Patterson, M.R. & Perez-Blanco, H. (1988)
"Numerical fits of the properties of lithium-bromide water solutions",
ASHRAE Transactions 94(2), pp. 2059-2077 (paper OT-88-20-2).
  7 explicit polynomial functions: enthalpy HLIBR, dew point TDEW, vapour pressure PRESS,
  thermal conductivity TCON, viscosity VISCOS, density SPMASS, surface tension STEN.
  Uniform form: F(X,T) = Σ_{i=0..K} X^i·(A_i + T·A_{i+K+1} + T²·A_{i+2K+2}),
  X = LiBr weight percent (a number, e.g. 50), T = °C.

Chua, H.T. et al. (2000)
"Improved thermodynamic property fields of LiBr-H2O solution",
Int. J. Refrigeration 23, 412-429.
  Dühring vapour-pressure equation (Table 1, 42 coefficients) + density correlation (Table 2, 15 coefficients),
  range 0-190°C / 0-75 wt%, as the upgrade option for the high-concentration, high-temperature segment.

Conventions
----
* X : LiBr weight percent (a number, 0-100, e.g. 50), not a fraction
* T : °C (as in the Patterson original)
* Returns are SI: h kJ/kg, p MPa, lambda W/(m K), eta Pa s,
  rho kg/m^3, sigma N/m ; t_dew / crystallization_T in °C
  (pressure unit per the 2026-10-14 rule: public functions return MPa; the fits' native values and
  internal arithmetic remain in Pa; a public function = the private native-value function x1e-6.)

Ranges and crystallisation checks
--------------
Each function first performs two checks and raises ValueError if either fails (no silent extrapolation):
1. Crystallisation/unknown-region check: the XN/TN polyline (freezing point) and the XUNKN/TUNKN polyline
   (unknown region) of the Patterson appendix, with the logic ported line by line from the Fortran original.
2. The fit's valid range of each function (see each function's docstring).

Transcribed 2026-10-01, checked character by character against 200 dpi renderings of the original pages.
Notes:
* The PRESS text says input in °F / output in psia, but the code actually takes °C input and returns Pa
  (x6894.757); the code governs. The comment "Horacio says is DEG F" is also doubtful.
  This module computes with that native Pa value; the public psol converts x1e-6 and returns MPa.
* The TUNKN values of TCON are printed as Fahrenheit numbers (260/280/320/360) yet are compared against T in °C,
  so its unknown-region check never triggers - recorded as printed in the original.
* STEN is not a special K=4 polynomial; it still uses the standard double loop (KUP=5, 15 coefficients).
* Reference state: h(0%, 25°C) = 104.615 kJ/kg, i.e. pure water as saturated liquid at 0°C has h=0
  (computed from the coefficients; not stated explicitly in the paper; from the data datum of McNeely 1979).
"""

import math

# --------------------------------------------------------------------------
# Crystallisation boundary tables (Patterson appendix; shared by all 7 functions; for the TUNKN of TCON see the note)
# --------------------------------------------------------------------------
_XN = [57.5, 62.5, 62.5, 67.5, 67.5, 100.0, 100.0]   # wt%
_TN = [0.0, 10.0, 40.0, 50.0, 90.0, 100.0, 180.0]     # °C
_XUNKN = [0.0, 37.5, 51.5, 60.5]                       # wt%
_TUNKN = [126.7, 137.8, 160.0, 182.2]                  # °C
_TUNKN_TCON_F = [260.0, 280.0, 320.0, 360.0]           # TCON as printed in the original (values in °F)


def _check_region(X, T, func_name, check_unknown=True, tunkn=None):
    """Patterson crystallisation/unknown-region check. Returns None; raises ValueError on failure.

    The logic corresponds line by line to the Fortran:
      Freezing-point polyline: interpolate XSTAR at the first N with T<=TN[N]; X>=XSTAR -> crystallisation region
      T>180 -> after the "TEMPERATURE HIGHER THAN TABLE ALLOWS" warning, continue with the unknown-region check
      Unknown-region polyline: interpolate XSTAR at the first N with T<=TUNKN[N]; X<=XSTAR -> unknown region
    HLIBR still performs the unknown-region check after passing the freezing-point check; the other functions compute directly after
    passing the freezing-point check (check_unknown=False), but at T>180 all go through the unknown-region check.
    """
    if tunkn is None:
        tunkn = _TUNKN
    # --- Freezing-point check ---
    star = None
    for n in range(1, 7):
        if T > _TN[n]:
            continue
        if _XN[n] == _XN[n - 1]:
            xstar = _XN[n]
        else:
            xstar = (_XN[n - 1] + (T - _TN[n - 1]) / (_TN[n] - _TN[n - 1])
                     * (_XN[n] - _XN[n - 1]))
        star = xstar
        break
    if star is None:
        # T > 180: the original code prints a warning and continues with the unknown-region check
        pass
    elif X >= star:
        raise ValueError(
            "%s: point (X=%.2f%%, T=%.2f°C) is in the crystallisation region (freezing-point concentration X*=%.2f%%)"
            % (func_name, X, T, star))
    elif not check_unknown:
        return  # Other functions: passed the freezing-point check -> compute directly
    # --- Unknown-region check ---
    for n in range(1, 4):
        if T > tunkn[n]:
            continue
        if _XUNKN[n] == _XUNKN[n - 1]:
            xstar = _XUNKN[n]
        else:
            xstar = (_XUNKN[n - 1]
                     + (T - tunkn[n - 1]) / (tunkn[n] - tunkn[n - 1])
                     * (_XUNKN[n] - _XUNKN[n - 1]))
        if X <= xstar:
            raise ValueError(
                "%s: point (X=%.2f%%, T=%.2f°C) is in the unknown region (X*<=%.2f%%, no data)"
                % (func_name, X, T, xstar))
        return
    # T > TUNKN[3]: the original code falls into 150 -> unknown region
    raise ValueError(
        "%s: T=%.2f°C exceeds the upper limit of the unknown-region table (%.1f°C), no data" % (func_name, T, tunkn[3]))


def _poly(X, T, A, kup):
    """Uniform polynomial: Σ_{i=0..K} X^i·(A_i + T·A_{i+K+1} + T²·A_{i+2K+2}).
    A is a 0-based list; kup = K+1."""
    K = kup - 1
    s = 0.0
    xk = 1.0
    for i in range(kup):
        if i > 0:
            xk *= X
        s += xk * (A[i] + T * (A[i + kup] + T * A[i + 2 * kup]))
    return s


# --------------------------------------------------------------------------
# Patterson coefficient tables (in DATA-statement order, 0-based)
# --------------------------------------------------------------------------
# HLIBR: enthalpy kJ/kg, KUP=6
_A_H = [
    1.134125e+00, -4.800450e-01, -2.161438e-03, 2.336235e-04,
    -1.188679e-05, 2.291532e-07, 4.124891e+00, -7.643903e-02,
    2.589577e-03, -9.500522e-05, 1.708026e-06, -1.102363e-08,
    5.743693e-04, 5.870921e-05, -7.375319e-06, 3.277592e-07,
    -6.062304e-09, 3.901897e-11,
]
# TDEW: dew point °C (the polynomial internally uses °F and converts back to °C before returning), KUP=6
_A_TDEW = [
    -1.313448e-01, 1.820914e-01, -5.177356e-02, 2.827426e-03,
    -6.380541e-05, 4.340498e-07, 9.967944e-01, 1.778069e-03,
    -2.215597e-04, 5.913618e-06, -7.308556e-08, 2.788472e-10,
    1.978788e-05, -1.779481e-05, 2.002427e-06, -7.667546e-08,
    1.201525e-09, -6.641716e-12,
]
# TCON: thermal conductivity kcal/(h·m·°C), KUP=5
_A_TC = [
    4.815196e-01, -2.217277e-03, -1.994141e-05, 3.727255e-07,
    -2.489886e-09, 1.858174e-03, 9.614755e-06, -1.139291e-06,
    2.107608e-08, -1.330532e-10, -7.923126e-06, -1.869392e-07,
    1.408951e-08, -2.740806e-10, 1.810818e-12,
]
# VISCOS: viscosity cP, KUP=6
_A_VIS = [
    1.488747e+00, 1.143975e-01, -1.278729e-02, 6.999985e-04,
    -1.638074e-05, 1.456348e-07, -4.164814e-02, 9.636832e-04,
    -5.981025e-05, -1.282435e-07, 5.703002e-08, -9.842266e-10,
    3.404030e-04, -2.794515e-05, 2.580301e-06, -9.737750e-08,
    1.585609e-09, -7.922925e-12,
]
# SPMASS: density kg/L, KUP=5
_A_RHO = [
    9.939006e-01, 1.046888e-02, -1.667939e-04, 5.332835e-06,
    -3.440005e-08, -5.631094e-04, 1.633541e-05, -1.110273e-06,
    2.882292e-08, -2.523579e-10, 1.392527e-06, -2.801009e-07,
    1.734979e-08, -4.232988e-10, 3.503024e-12,
]
# STEN: surface tension dyne/cm, KUP=5
_A_SIG = [
    7.626234e+01, 4.583900e-01, -1.463071e-02, 3.834735e-04,
    -2.733854e-06, -1.507474e-01, -9.057263e-03, 4.459087e-04,
    -9.542318e-06, 6.610416e-08, -1.107075e-05, 7.238986e-05,
    -3.822731e-06, 8.077592e-08, -5.681625e-10,
]


def _range_check(X, T, func_name, x_lo, x_hi, t_lo, t_hi):
    if not (x_lo <= X <= x_hi and t_lo <= T <= t_hi):
        raise ValueError(
            "%s: (X=%.2f%%, T=%.2f°C) outside the fit range X in [%.g,%.g%%], T in [%.g,%.g°C]"
            % (func_name, X, T, x_lo, x_hi, t_lo, t_hi))


# --------------------------------------------------------------------------
# Public functions (Patterson)
# --------------------------------------------------------------------------
def hsol(X, T):
    """Solution specific enthalpy [kJ/kg]; X wt%, T °C. Range: X in (0,70), T in (0,180)."""
    _range_check(X, T, 'hsol', 0, 70, 0, 180)
    _check_region(X, T, 'hsol', check_unknown=True)
    return _poly(X, T, _A_H, 6)


def _tdew_poly(X, T):
    """The internal TDEW polynomial (°F input, °F returned), without the crystallisation check."""
    TF = 9.0 / 5.0 * T + 32.0
    return _poly(X, TF, _A_TDEW, 6)


def t_dew(X, T):
    """Dew-point temperature [°C]; X wt%, T °C (solution temperature). Range: X in (0,70), T in (4.4,182.2)."""
    _range_check(X, T, 't_dew', 0, 70, 4.4, 182.2)
    _check_region(X, T, 't_dew', check_unknown=False)
    return 5.0 / 9.0 * (_tdew_poly(X, T) - 32.0)


def _psol_Pa(X, T):
    """Native value of the water vapour partial pressure [Pa] (Patterson PRESS, private); X wt%, T °C.
    First obtain the dew point (°F) from the TDEW polynomial, then log10 P[psia]=6.21147-2886.373/TR-337269.46/TR²
    (TR in °R), x6894.757 -> Pa. All internal arithmetic uses this Pa value."""
    _range_check(X, T, 'psol', 0, 70, 4.4, 182.2)
    _check_region(X, T, 'psol', check_unknown=False)
    tdew_f = _tdew_poly(X, T)
    TR = tdew_f + 459.7
    return 10.0 ** (6.21147 - 2886.373 / TR - 337269.46 / TR ** 2) * 6894.757


def psol(X, T):
    """Water vapour partial pressure [MPa] (Patterson PRESS); X wt%, T °C.
    Public boundary = private native value _psol_Pa x1e-6 (Pa -> MPa)."""
    return _psol_Pa(X, T) * 1e-6


def lambda_libr(X, T):
    """Thermal conductivity [W/(m K)]; X wt%, T °C. Original in kcal/(h·m·°C) x1.163."""
    _range_check(X, T, 'lambda_libr', 0, 70, 4.4, 182.2)
    _check_region(X, T, 'lambda_libr', check_unknown=False,
                  tunkn=_TUNKN_TCON_F)
    return _poly(X, T, _A_TC, 5) * 1.163


def eta_libr(X, T):
    """Dynamic viscosity [Pa s]; X wt%, T °C. Original in cP x1e-3. Range: X in (5,60), T in (0,90)."""
    _range_check(X, T, 'eta_libr', 5, 60, 0, 90)
    _check_region(X, T, 'eta_libr', check_unknown=False)
    return _poly(X, T, _A_VIS, 6) * 1e-3


def rho_libr(X, T):
    """Density [kg/m^3]; X wt%, T °C. Original in kg/L x1000. Range: X in (10,60), T in (0,100)."""
    _range_check(X, T, 'rho_libr', 10, 60, 0, 100)
    _check_region(X, T, 'rho_libr', check_unknown=False)
    return _poly(X, T, _A_RHO, 5) * 1000.0


def sigma_libr(X, T):
    """Surface tension [N/m]; X wt%, T °C. Original in dyne/cm x1e-3. Range: X in (5,60), T in (0,60)."""
    _range_check(X, T, 'sigma_libr', 5, 60, 0, 60)
    _check_region(X, T, 'sigma_libr', check_unknown=False)
    return _poly(X, T, _A_SIG, 5) * 1e-3


def crystallization_T(X):
    """Crystallisation temperature [°C]: the freezing-point-polyline temperature for concentration X wt%.
    For X<57.5% there is no crystallisation boundary within the table range; returns NaN."""
    if X < 57.5:
        return float('nan')
    if X > 100:
        raise ValueError("crystallization_T: X=%.2f%% exceeds 100%%" % X)
    # Freezing-point polyline XN/TN: take the highest T at which X=XSTAR(T) (for a vertical segment take the upper endpoint)
    best = None
    for n in range(1, 7):
        x0, x1 = _XN[n - 1], _XN[n]
        t0, t1 = _TN[n - 1], _TN[n]
        if x0 == x1:
            if X == x0:
                best = t1 if best is None else max(best, t1)
        elif min(x0, x1) <= X <= max(x0, x1):
            t = t0 + (X - x0) / (x1 - x0) * (t1 - t0)
            best = t if best is None else max(best, t)
    return best


# --------------------------------------------------------------------------
# Chua 2000: Dühring vapour pressure (Table 1) + density (Table 2)
# The Table 1 coefficients were transcribed from p.417 of the original (checked character by character at 200 dpi); see also the notes below.
# --------------------------------------------------------------------------
# A_D(x) = Σ_{i=0}^{16} A_i x^i + Σ_{i=17}^{20} A_i ⟨x-60⟩^i, ⟨y⟩=max(y,0)
# B_D(x) has the same form. (T-273.15) = A_D·(T_dp-273.15) + B_D(x)
_DUHR_A = [
    1.0,
    2.92242e-04, 1.05207e-04, 8.86101e-07, -2.71833e-06, 3.52718e-07,
    -2.03849e-08, 5.68810e-10, -4.32385e-12, -1.42122e-13, 2.37604e-15,
    3.96440e-17, -9.81319e-19, -7.91591e-21, 3.92677e-22, -4.04965e-24,
    1.41694e-26,
    6.51878e-03, -2.57030e-04, 2.43912e-05, -6.86236e-08,
]
_DUHR_B = [
    0.0,
    5.22677e-02, -9.78477e-03, 7.82919e-03, -1.62913e-03, 1.64050e-04,
    -8.98817e-06, 2.62640e-07, -2.95400e-09, -3.23145e-11, 7.67888e-13,
    1.36662e-14, -3.12628e-16, -4.91441e-18, 1.87723e-19, -1.92463e-21,
    6.87629e-24,
    1.93956e+00, 8.22588e-02, -1.04537e-02, 4.09856e-04,
]
# Notes (found during transcription checking; all verified numerically against the curves of Fig.1/Fig.2 of the original):
#  * B_12 is printed in the original without a minus sign ("3.12628E-16"), but only with the negative sign can B_D reproduce Fig.2
#    (B_D(30)=4.52 vs. Fig.2 ~4.5; with the positive sign one gets 336.8 - clearly a minus sign dropped in print).
#    The value used here is -3.12628E-16.
#  * B_14 is printed as "1.87723B-19" (the B in the exponent position is a glyph); read as 1.87723E-19.
#  * A_10 is printed as "2.37604E.15"; read as 2.37604E-15 from the exponent sequence and the order of magnitude.
#  * The <x-60> correction terms (i=17..20) diverge at x>60 with the values as printed
#    (A_D(65)=4.45e9, whereas Fig.1 should be ~1.225) and cannot reproduce the curves of the original,
#    so psol_chua is limited to x<=60%. The original calls the 60-75% segment an extrapolation; it is not implemented here.
#
# Table 2 density: ρ = Σ_{k=1..5} x^{k-1}[G_{0,k}+T(G_{1,k}+T G_{2,k})],
# x wt%, T °C, ρ kg/m³.G[k] = [G_{0,k},G_{1,k},G_{2,k}] (k=1..5).
# (i=1,j=4) is printed as "-9.08213EB-06"; read as -9.08213E-06.
_G_RHO_CHUA = [
    [9.99100e+02, -2.39865e-02, -3.90453e-03],
    [7.74931e+00, -1.28346e-02, -5.55855e-05],
    [5.36509e-03, 2.07232e-04, 1.09879e-05],
    [1.34988e-03, -9.08213e-06, -2.39834e-07],
    [-3.08671e-06, 9.94788e-08, 1.53514e-09],
]


def _wagner_pref_water(T_C):
    """Saturation vapour pressure of pure water [Pa], T °C. Wagner equation (the form accompanying IAPWS-95,
    Wagner & Pruss 1993):
    ln(p/pc) = (Tc/T)·Σ a_i·θ^e_i, θ = 1-T/Tc.
    The original of Chua used the Haar (1984) NBS/NRC steam tables; replaced here by an equivalent."""
    T = T_C + 273.15
    Tc = 647.096
    Pc = 22.064e6
    theta = 1.0 - T / Tc
    a = (-7.85951783, 1.84408259, -11.7866497,
         22.6807411, -15.9618719, 1.80122502)
    e = (1.0, 1.5, 3.0, 3.5, 4.0, 7.5)
    s = sum(ai * theta ** ei for ai, ei in zip(a, e))
    return Pc * math.exp((Tc / T) * s)


def _psol_chua_Pa(X, T):
    """Native value of the water vapour partial pressure [Pa] (Chua Dühring, private); X wt%, T °C. Range: 0-190°C, 0-60%.

    (T-273.15) = A_D(x)·(T_dp-273.15) + B_D(x), with T/T_dp in K;
    obtaining the pure-water Psat from T_dp via the Wagner equation gives the solution vapour pressure (LiBr is non-volatile).
    The <x-60> correction terms for x>60% cannot reproduce Fig.1/2 with the values as printed in the original, so they are not implemented.
    All internal arithmetic uses this Pa value."""
    if not (0 <= X <= 60 and 0 <= T <= 190):
        raise ValueError("psol_chua: (X=%.2f%%, T=%.2f°C) out of range [0-60%%, 0-190°C]"
                         % (X, T))
    x = X
    AD = sum(a * x ** i for i, a in enumerate(_DUHR_A[:17]))
    BD = sum(b * x ** i for i, b in enumerate(_DUHR_B[:17]))
    # T_C = AD*Tdp_C + BD  →  Tdp_C = (T_C-BD)/AD
    Tdp_C = (T - BD) / AD
    return _wagner_pref_water(Tdp_C)


def psol_chua(X, T):
    """Water vapour partial pressure [MPa] (Chua Dühring); X wt%, T °C. Range: 0-190°C, 0-60%.
    Public boundary = private native value _psol_chua_Pa x1e-6 (Pa -> MPa)."""
    return _psol_chua_Pa(X, T) * 1e-6


def x_by_tsol_tdew_chua(Tsol_C, Tdew_C):
    """Solve the LiBr concentration X [wt%] back from the dew-point temperature and the solution temperature (Chua route).

    Construction: the dew point fixes the pressure P = the saturation pressure of pure water at Tdew, using the module's own pure-water
    saturation-pressure function _wagner_pref_water (Wagner equation); then 80 bisection steps invert the solution vapour-pressure
    function _psol_chua_Pa(X, Tsol_C) = P (Pa throughout internally, accounted separately from the MPa boundary of the public
    psol_chua), with the bracket X in [0,60] (the valid concentration domain of psol_chua).
    _psol_chua_Pa decreases monotonically with X, so the bisection direction is opposite to the increasing case.
    Reason for choosing the Chua route: psol_chua is itself constructed from the Dühring dew point via the same Wagner pure-water
    function, so the dew-point definition is self-consistent; Patterson PRESS differs from it by about 0.5-1.4%
    (see Section 4 of the formula notes), and the two routes must not be mixed.
    Returns None when there is no root (e.g. when Tsol is clearly below Tdew, P is above the vapour pressure at the X=0 end,
    or P is below the vapour pressure at the X=60 end). When Tsol is outside the range of psol_chua, its
    ValueError propagates as usual (the established convention of this module)."""
    P = _wagner_pref_water(Tdew_C)
    Pmax = _psol_chua_Pa(0.0, Tsol_C)    # X=0 end: highest vapour pressure
    Pmin = _psol_chua_Pa(60.0, Tsol_C)   # X=60 end: lowest vapour pressure
    if not (Pmin <= P <= Pmax):
        return None
    lo, hi = 0.0, 60.0
    for _ in range(80):
        mid = 0.5 * (lo + hi)
        if _psol_chua_Pa(mid, Tsol_C) > P:
            lo = mid   # vapour pressure too high -> a higher concentration is needed to lower it
        else:
            hi = mid
    return 0.5 * (lo + hi)



def _tsat_water_patterson(P_Pa):
    """Pure-water saturation temperature [degC] on the Patterson log10
    relation built into psol:
        log10(P[psia]) = 6.21147 - 2886.373/TR - 337269.46/TR^2,
    TR in degR.  Analytic inverse (quadratic in 1/TR).  This is the
    module's own pure-water line for the Patterson route."""
    L = math.log10(P_Pa / 6894.757)
    a, b = 2886.373, 337269.46
    disc = a * a - 4.0 * b * (L - 6.21147)
    if disc < 0.0:
        return None
    u = (-a + math.sqrt(disc)) / (2.0 * b)
    return (1.0 / u - 459.7 - 32.0) * 5.0 / 9.0


def tdew_by_tsol_x(X, T):
    """Dew-point temperature [degC] of the solution at (X, T)
    (library-wide TdewByTsolXi convention):
        Tdew = Tsat_water(Psol(X, T)),
    with Psol the Patterson surface pressure and Tsat_water the
    analytic inverse of the pure-water relation inside psol.  By
    construction this equals t_dew(X, T) (the Patterson TDEW
    polynomial is that same dew temperature); LiBr is non-volatile,
    so no endpoint convention is involved.  Domain/range errors of
    psol propagate as ValueError, as for t_dew.  Internally the Pa
    native value _psol_Pa is used (public psol returns MPa)."""
    P = _psol_Pa(X, T)
    return _tsat_water_patterson(P)


def tsol_by_hsol(h, X):
    """Solution temperature [degC] from specific enthalpy h [kJ/kg]
    and LiBr mass percent X: inverse of hsol.  hsol is only defined
    on the Patterson standard region (it raises ValueError in the
    unknown region), so the bracket is first located by scanning
    T = 0..180 degC in 5 degC steps over the evaluable points, then
    refined by 80 bisection steps (hsol increases monotonically with
    T at fixed X).  None if no evaluable bracket contains h."""
    prev_T, prev_h, bracket = None, None, None
    k = 0
    while k <= 36:
        T = 5.0 * k
        k += 1
        try:
            hv = hsol(X, T)
        except ValueError:
            continue
        if prev_h is not None and prev_h <= h <= hv:
            bracket = (prev_T, T)
            break
        prev_T, prev_h = T, hv
    if bracket is None:
        return None
    lo, hi = bracket
    for _ in range(80):
        mid = 0.5 * (lo + hi)
        if hsol(X, mid) < h:
            lo = mid
        else:
            hi = mid
    return 0.5 * (lo + hi)


def rho_chua(X, T):
    """Density [kg/m^3] (Chua Table 2); X wt%, T °C. Range: 0-200°C, 0-70%.

    ρ = Σ_{k=1..5} x^{k-1}·[G_{0,k} + T·(G_{1,k} + T·G_{2,k})]"""
    if not (0 <= X <= 70 and 0 <= T <= 200):
        raise ValueError("rho_chua: (X=%.2f%%, T=%.2f°C) out of range" % (X, T))
    G = _G_RHO_CHUA  # 5×3: G[k][0..2] = G_{0,k},G_{1,k},G_{2,k}
    s = 0.0
    xk = 1.0
    for k in range(5):
        if k > 0:
            xk *= X
        s += xk * (G[k][0] + T * (G[k][1] + T * G[k][2]))
    return s


# --------------------------------------------------------------------------
# Kaita 2001: high-temperature set (dew point Eq.(1), vapour pressure Eq.(2),
# specific heat Eq.(3), enthalpy Eq.(8)); range 20-210 degC, 40-65 wt%.
# Kaita, Y., Int. J. Refrigeration 24 (2001) 374-390.  Verified 2026-10-22
# against the original (dossier dossiers/LiBr-H2O-Kaita2001.md in the
# working-pair formula library): Eqs.(1)-(3) match the print character by
# character; Eq.(8) prints D2 = +4.5348E-3 but Eq.(6) prints C2 = -4.5348E-3
# for the identical coefficient, and Kaita's own Tables 5/6 arbitrate for
# the negative value (max deviation 0.029% on Table 6 with D2<0, 23.6%
# with the printed positive sign; transcription-error register TE-962).
# The operative value D2 = -4.5348E-3 is used here.
# Enthalpy datum follows Kaita Sec.3.2 (McNeely/Feuerecker datum) and
# differs from the Patterson datum by a non-constant +1.7..+5.9 kJ/kg over
# the checked points: keep the two enthalpy sets in separate accounts and
# use enthalpy differences within one set only.
# --------------------------------------------------------------------------
_KAITA_A = [  # Eq.(1) Aij, index [i][j]: TD = sum_ij Aij (X-40)^j T^i
    [-9.133128e+00, -4.759724e-01, -5.638171e-02, 1.108418e-03],
    [9.439697e-01, -2.882015e-03, -1.345453e-04, 5.852133e-07],
    [-7.324352e-05, -1.556533e-05, 1.992657e-06, -3.924205e-08],
]
_KAITA_CP = (3.462023, -2.679895e-02, 1.3499e-03, -6.55e-06)  # Eq.(3) A0,A1,B0,B1
_KAITA_D = (162.81, -6.0418, -4.5348e-03, 1.2053e-03)  # Eq.(8) D0..D3, D2 corrected (see above)


def _kaita_range(X, T, func_name):
    if not (40.0 <= X <= 65.0 and 20.0 <= T <= 210.0):
        raise ValueError(
            "%s: (X=%.2f%%, T=%.2f°C) outside the Kaita 2001 range X in [40,65%%], T in [20,210°C]"
            % (func_name, X, T))


def tdew_by_tsol_x_kaita(X, T):
    """Dew-point temperature [°C] (Kaita Eq.(1)); X wt%, T °C. Range: X in [40,65], T in [20,210]."""
    _kaita_range(X, T, 'tdew_by_tsol_x_kaita')
    dx = X - 40.0
    return sum(_KAITA_A[i][j] * dx ** j * T ** i for i in range(3) for j in range(4))


def _psol_kaita_kPa(X, T):
    """Native vapour pressure [kPa] (Kaita Eq.(1)+(2) chain, private)."""
    TD = tdew_by_tsol_x_kaita(X, T)
    Tk = TD + 273.15
    return 10.0 ** (7.05 - 1603.54 / Tk - 104095.5 / Tk ** 2)


def psol_kaita(X, T):
    """Water vapour partial pressure [MPa] (Kaita Eq.(1)+(2)); X wt%, T °C.
    Public boundary = native kPa value x1e-3. Range as tdew_by_tsol_x_kaita."""
    return _psol_kaita_kPa(X, T) * 1e-3


def cp_kaita(X, T):
    """Solution specific heat [kJ/(kg K)] (Kaita Eq.(3), Rockenfeller form); X wt%, T °C."""
    _kaita_range(X, T, 'cp_kaita')
    A0, A1, B0, B1 = _KAITA_CP
    return (A0 + A1 * X) + (B0 + B1 * X) * T


def hsol_kaita(X, T):
    """Solution specific enthalpy [kJ/kg] (Kaita Eq.(8), D2 corrected negative; see header note);
    X wt%, T °C. Kaita datum - do not mix with Patterson hsol values, use differences within this set."""
    _kaita_range(X, T, 'hsol_kaita')
    A0, A1, B0, B1 = _KAITA_CP
    D0, D1, D2, D3 = _KAITA_D
    return ((A0 + A1 * X) * T + 0.5 * (B0 + B1 * X) * T ** 2
            + (D0 + D1 * X + D2 * X ** 2 + D3 * X ** 3))


def tsol_by_hsol_kaita(h, X):
    """Solution temperature [°C] from Kaita enthalpy h [kJ/kg] and X [wt%]: inverse of hsol_kaita.
    Bracket scanned over T = 20..210 °C in 5 °C steps, then 80 bisection steps
    (hsol_kaita increases monotonically with T at fixed X, Cp > 0). None if no bracket."""
    if not (40.0 <= X <= 65.0):
        raise ValueError("tsol_by_hsol_kaita: X=%.2f%% outside [40,65%%]" % X)
    prev_T, prev_h, bracket = None, None, None
    k = 0
    while k <= 38:
        T = 20.0 + 5.0 * k
        k += 1
        hv = hsol_kaita(X, T)
        if prev_h is not None and prev_h <= h <= hv:
            bracket = (prev_T, T)
            break
        prev_T, prev_h = T, hv
    if bracket is None:
        return None
    lo, hi = bracket
    for _ in range(80):
        mid = 0.5 * (lo + hi)
        if hsol_kaita(X, mid) < h:
            lo = mid
        else:
            hi = mid
    return 0.5 * (lo + hi)


def x_by_tsol_tdew_kaita(Tsol_C, Tdew_C):
    """LiBr concentration X [wt%] back from solution temperature and dew point (Kaita Eq.(1) route).
    Eq.(1) TD decreases monotonically with X at fixed T over [40,65]
    (higher concentration, lower vapour pressure, lower dew point);
    80 bisection steps. None when Tdew is outside the X in [40,65] band
    at Tsol. Range errors of the underlying Eq.(1) domain (Tsol outside
    [20,210]) propagate as ValueError."""
    TD_hi = tdew_by_tsol_x_kaita(40.0, Tsol_C)
    TD_lo = tdew_by_tsol_x_kaita(65.0, Tsol_C)
    if not (TD_lo <= Tdew_C <= TD_hi):
        return None
    lo, hi = 40.0, 65.0
    for _ in range(80):
        mid = 0.5 * (lo + hi)
        if tdew_by_tsol_x_kaita(mid, Tsol_C) > Tdew_C:
            lo = mid
        else:
            hi = mid
    return 0.5 * (lo + hi)


if __name__ == '__main__':
    # Quick self-check
    print('h(0%%,25°C) = %.3f kJ/kg (expected ~104.6)' % hsol(0.0, 25.0))
    print('rho(60%%,25°C) = %.1f kg/m³ (expected ~1700)' % rho_libr(60.0, 25.0))
    print('eta(60%%,25°C) = %.2f mPa·s (expected order ~10)' % (eta_libr(60.0, 25.0) * 1e3))
    print('psol(50%%,80°C) = %.6f MPa' % psol(50.0, 80.0))
    print('t_dew(50%%,80°C) = %.2f °C' % t_dew(50.0, 80.0))
    print('lambda(50%%,80°C) = %.4f W/(m K)' % lambda_libr(50.0, 80.0))
    print('sigma(50%%,25°C) = %.1f mN/m' % (sigma_libr(50.0, 25.0) * 1e3))
    print('T_cryst(60%%) = %.1f °C' % crystallization_T(60.0))
    print('T_cryst(65%%) = %.1f °C' % crystallization_T(65.0))

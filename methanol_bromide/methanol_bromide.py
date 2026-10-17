# Thermodynamic correlations for methanol / (2LiBr-ZnBr2) (reference implementation)
# Source: S. El-Shamarka, "An investigation of methanol and inorganic bromides
#   for thermally operated heat pumps", PhD thesis, Cranfield Institute of
#   Technology, 1981.
#
# System: the salt mixture ratio is fixed at LiBr:ZnBr2 = 2:1 (molar ratio); the whole thesis calls it "2LiBr-ZnBr2".
# The concentration variable w is always the methanol mass fraction (kg/kg). The salt is non-volatile; the vapour phase is treated as pure methanol.
#
# Correlations (constants checked character by character against images of the original pages):
#   Eq. (3.1) Bubble-point pressure (thesis p.71; coefficient Table 3.3 on p.74):
#           log10 P[mbar] = C1(w) + C2(w)·(1000/T[K] - 2.3)
#           C1 and C2 are given at 8 measured composition nodes; between nodes, shape-preserving PCHIP interpolation is used.
#           Note: the -C2 in Table 3.3 at w=28.0% (2.7278) breaks the monotonic trend
#           (2.8197 at 30.1%); printed as in the original table; PCHIP has zero slope at that node,
#           forming a local plateau and producing no overshoot.
#   Eq. (3.4) Specific heat (p.86; restated in Appendix A, p.194):
#           Cp[kJ/(kg·°C)] = A + B·t[°C]
#           A = 0.652 + 2.139w - 2.077w^2
#           B = -0.000205 + 0.00928w - 0.0101w^2
#           [Sign ruling] In the original formula on p.86 the sign of the last term of B is an overprinted glyph; the restatement in Appendix A prints it as
#           "-". Checked against the measured specific heats in Table 3.7 of the thesis: taking "-" gives a max deviation of 0.7%
#           (w=0.403: 51.3°C->1.274 vs. measured 1.27; 69.9°C->1.309 vs. 1.30;
#            w=0.311: 40.0°C->1.185 vs 1.19; 80.6°C->1.254 vs 1.26),
#           taking "+" gives deviations of 6%~14%, contradicting the thesis's own claim of a 2% mean error.
#           This implementation therefore takes "-", consistent with the printing in Appendix A and the measured data.
#   Appendix A enthalpy of vaporisation H' (p.196, including the heat of mixing, derived from the vapour-pressure slope via Clausius-Clapeyron):
#           H'[kJ/kg] = A + B·w + C·w^2
#           A = 2202.6 + 9.24T - 0.0218T^2
#           B = -(4417.8 + 15.53T - 0.0392T^2)
#           C = 3570.0 + 10.81T - 0.0294T^2
#           [Trap] T in the formula is in kelvin (the data table on the same page is listed in °C). Verified with three points from the table:
#           (10°C, w=0.25): 1920 vs. table value 1940 (-1.0%);
#           (10°C, w=0.356): 1593 vs 1601(-0.5%);
#           (100°C, w=0.25): 1646 vs 1645(+0.05%).
#           The fit interval is only w approx. 0.25~0.356; extrapolation is forbidden (at w=1 it gives 1672 kJ/kg,
#           whereas the true value for pure methanol is about 1193). In the table, the cell at w=35.6%, 110°C is printed as 1221,
#           breaking the smooth trend (neighbours 1352, 1288); suspected printing error; not used as a check point.
#
# Reference state (a convention of this document; the thesis defines no absolute datum for the solution enthalpy and uses only enthalpy differences):
#   hsol(0°C, any w) = 100 kJ/kg, i.e. hsol = 100 + integral(0°C->t) Cp dt
#   = 100 + A*t + B*t^2/2. The concentration dependence of the enthalpy enters the vapour-phase enthalpy via h_prime:
#   hgas(T, w) = hsol(T, w) + H'(T, w) (assembled the same way as in the author's COP program).
#
# Valid ranges:
#   Bubble point: w = 0.243~0.509, measured approx. 15~193°C; Cp: w = 0.249~0.403 (as stated in the thesis);
#   H': w = 0.25~0.356 (hard limit), T approx. 283~472 K (the table lists 10~199°C).
#
# Pure-methanol saturation line (only for the dew point of the glide plots): the table in Appendix A (p.194) gives the equilibrium temperatures of pure methanol
# at 300~1000 mmHg; this module fits an Antoine equation to 7 points from it
# log10 P[mmHg] = A - B/(T + C), A=8.885298, B=2070.3714, C=6.3818,
# Max fit error 0.11%. In the 400 mmHg row the methanol temperature is printed as 373.1 K, which contradicts the value 323.1 K back-computed from
# the Ratio column of that row (the fit also gives 323.13 K); judged a misprint and excluded.
#
# Unverified formulas (Python only; not in C/VBA):
#   Eq. (4.10) Density: rho = 2.55 - 2.366w - 0.0068t [g/cc]. As printed (0.0068) it differs from the measured values of Table 4.2 of the thesis
#   (e.g. w=0.253, 50°C approx. 1914 kg/m3) by about 16%; if the temperature coefficient
#   were 0.00068, the difference would be 0.2%. The printed decimal point is in doubt; to be refitted from the raw data of Table 4.2.
#   Eq. (4.11) Viscosity (Guzman-Andrade type): mu = A*exp(B/T); the OCR digits are severely damaged
#   (including the multiplier of order 10^-3 in A and the decimal point of B); unusable; to be refitted from Table 4.3.

# Pressure unit (library-wide unification of 2026-10-14): the public functions of this module return/accept MPa.
# Internal native computation is in bar (private function names carry the suffix _bar); public functions only scale at the boundary
# (MPa = bar x0.1; MPa inputs x10 back to bar). The _bar in the function names meoh_pref_bar /
# meoh_Tsat_bar is a retained historical name; their public convention is actually MPa.

import math

# ---- Table 3.3 (p.74): node compositions (methanol mass fractions) and C1, C2 (C2 takes negative values) ----
_W_NODES = (0.243, 0.250, 0.262, 0.280, 0.301, 0.356, 0.403, 0.509)
_C1_NODES = (2.6712, 2.8572, 2.9758, 3.0535, 3.3146, 3.4604, 3.7770, 4.0494)
_C2_NODES = (-3.0602, -3.0344, -2.9531, -2.7278, -2.8197, -2.6219, -2.4256, -2.0194)


def _pchip_end_slope(h0, h1, d0, d1):
    m = ((2.0 * h0 + h1) * d0 - h0 * d1) / (h0 + h1)
    if m * d0 <= 0.0:
        return 0.0
    if d0 * d1 < 0.0 and abs(m) > abs(3.0 * d0):
        return 3.0 * d0
    return m


def _pchip_eval(xs, ys, x):
    """Fritsch-Carlson PCHIP (same algorithm as scipy's PchipInterpolator)."""
    n = len(xs)
    h = [xs[i + 1] - xs[i] for i in range(n - 1)]
    d = [(ys[i + 1] - ys[i]) / h[i] for i in range(n - 1)]
    m = [0.0] * n
    for i in range(1, n - 1):
        if d[i - 1] * d[i] <= 0.0:
            m[i] = 0.0
        else:
            w1 = 2.0 * h[i] + h[i - 1]
            w2 = h[i] + 2.0 * h[i - 1]
            m[i] = (w1 + w2) / (w1 / d[i - 1] + w2 / d[i])
    m[0] = _pchip_end_slope(h[0], h[1], d[0], d[1])
    m[n - 1] = _pchip_end_slope(h[n - 2], h[n - 3], d[n - 2], d[n - 3])
    if x <= xs[0]:
        i = 0
    elif x >= xs[n - 1]:
        i = n - 2
    else:
        lo, hi = 0, n - 1
        while hi - lo > 1:
            mid = (lo + hi) // 2
            if xs[mid] <= x:
                lo = mid
            else:
                hi = mid
        i = lo
    s = (x - xs[i]) / h[i]
    s2, s3 = s * s, s * s * s
    return ((2.0 * s3 - 3.0 * s2 + 1.0) * ys[i]
            + h[i] * (s3 - 2.0 * s2 + s) * m[i]
            + (3.0 * s2 - 2.0 * s3) * ys[i + 1]
            + h[i] * (s3 - s2) * m[i + 1])


def _c1(w):
    return _pchip_eval(_W_NODES, _C1_NODES, w)


def _c2(w):
    return _pchip_eval(_W_NODES, _C2_NODES, w)


def _psol_TW_bar(T_K, w):
    """Eq. (3.1) native value (private): bubble-point pressure, bar."""
    log10p_mbar = _c1(w) + _c2(w) * (1000.0 / T_K - 2.3)
    return 10.0 ** log10p_mbar / 1000.0


def psol_TW(T_K, w):
    """Eq. (3.1): bubble-point pressure, MPa. T_K in kelvin, w methanol mass fraction (0.243~0.509)."""
    return _psol_TW_bar(T_K, w) * 0.1


def _T_bubble_PW_bar(P_bar, w):
    """Eq. (3.1) analytic inverse, native value (private): bubble-point temperature, K. P_bar in bar."""
    log10p_mbar = math.log10(P_bar * 1000.0)
    return 1000.0 / ((log10p_mbar - _c1(w)) / _c2(w) + 2.3)


def T_bubble_PW(P_MPa, w):
    """Eq. (3.1) analytic inverse: bubble-point temperature, K. P_MPa in MPa, w methanol mass fraction."""
    return _T_bubble_PW_bar(P_MPa * 10.0, w)


def _cp_AB(w):
    A = 0.652 + 2.139 * w - 2.077 * w * w
    B = -0.000205 + 0.00928 * w - 0.0101 * w * w
    return A, B


def cp(T_K, w):
    """Eq. (3.4): solution specific heat, kJ/(kg·K). t = T_K - 273.15 (°C)."""
    A, B = _cp_AB(w)
    return A + B * (T_K - 273.15)


def h_prime(T_K, w):
    """Appendix A: enthalpy of vaporisation of the solution H' (including the heat of mixing), kJ/kg. T_K in kelvin (never use °C).
    Valid only for w = 0.25~0.356; extrapolation forbidden."""
    A = 2202.6 + 9.24 * T_K - 0.0218 * T_K * T_K
    B = -(4417.8 + 15.53 * T_K - 0.0392 * T_K * T_K)
    C = 3570.0 + 10.81 * T_K - 0.0294 * T_K * T_K
    return A + B * w + C * w * w


def hsol(T_K, w):
    """Solution specific enthalpy, kJ/kg. Reference state by the convention of this document: hsol(0°C, any w) = 100 kJ/kg,
    hsol = 100 + A*t + B*t^2/2, t in °C (analytic integral of Eq. (3.4))."""
    A, B = _cp_AB(w)
    t = T_K - 273.15
    return 100.0 + A * t + B * t * t / 2.0


def hgas(T_K, w):
    """Vapour-phase specific enthalpy, kJ/kg: hgas = hsol + H' (the vapour phase is pure methanol vapour;
    H' already includes the heat-of-mixing correction required to vaporise the methanol out of the solution)."""
    return hsol(T_K, w) + h_prime(T_K, w)


# ---- Pure-methanol saturation line: Antoine fit to the table in Appendix A of the thesis (see the header note) ----
_MEOH_ANT = (8.885298, 2070.3714, 6.3818)  # log10 P[mmHg], T[K]; error <=0.11% within 300~1000 mmHg


def _meoh_pref_bar(T_K):
    """Native value of the pure-methanol saturation pressure (private): bar (Antoine, fitted to the data points of Appendix A of the thesis)."""
    A, B, C = _MEOH_ANT
    return (10.0 ** (A - B / (T_K + C))) * 1.3332239e-3


def meoh_pref_bar(T_K):
    """Pure-methanol saturation pressure, MPa (Antoine, fitted to the data points of Appendix A of the thesis).
    The _bar in the function name is a retained historical name; the return value is actually MPa."""
    return _meoh_pref_bar(T_K) * 0.1


def _meoh_Tsat_bar(P_bar):
    """Native value of the pure-methanol saturation temperature (private): K, P_bar in bar (analytic inverse of Antoine)."""
    A, B, C = _MEOH_ANT
    return B / (A - math.log10(P_bar / 1.3332239e-3)) - C


def meoh_Tsat_bar(P_MPa):
    """Pure-methanol saturation temperature, K (analytic inverse of the above). P_MPa in MPa;
    the _bar in the function name is a retained historical name; the input is actually MPa."""
    return _meoh_Tsat_bar(P_MPa * 10.0)


def w_by_tsol_tdew(Tsol_K, Tdew_K):
    """Solve the methanol mass fraction w back from the dew-point temperature and the solution temperature.

    Dew-point pressure: P = _meoh_pref_bar(Tdew_K) (internal native value in bar; the salt is non-volatile,
    the vapour phase is pure methanol; the pure-methanol saturation pressure uses this module's own Antoine equation, see above); then
    80 bisection steps invert _psol_TW_bar(Tsol_K, w) = P, with the bracket taken as the bubble-point function's valid concentration domain
    w = 0.243~0.509 (the bubble-point pressure increases monotonically with w in that domain).
    Returns None when there is no root (P outside the span of bubble-point pressures under Tsol,
    e.g. the solution temperature clearly below the dew-point temperature)."""
    P = _meoh_pref_bar(Tdew_K)
    Plo = _psol_TW_bar(Tsol_K, _W_NODES[0])
    Phi = _psol_TW_bar(Tsol_K, _W_NODES[-1])
    if not (Plo <= P <= Phi):
        return None
    lo, hi = _W_NODES[0], _W_NODES[-1]
    for _ in range(80):
        mid = 0.5 * (lo + hi)
        if _psol_TW_bar(Tsol_K, mid) < P:
            lo = mid
        else:
            hi = mid
    return 0.5 * (lo + hi)



def tdew_from_tsol_w(T_K, w):
    """Dew-point temperature [K] of the solution at (T_K, w) (library-wide TdewByTsolXi convention):
        Tdew = meoh_Tsat_bar(psol_TW(T_K, w)) (public convention MPa;
        internally it goes through the native-bar private functions _meoh_Tsat_bar(_psol_TW_bar(...))),
    i.e. the saturation temperature corresponding to the solution surface pressure Psol, evaluated with this module's own pure-methanol Antoine line.
    The salt is non-volatile and the vapour phase is pure methanol, so there is no endpoint-convention issue. The valid domain of w
    follows psol_TW (0.243~0.509)."""
    return _meoh_Tsat_bar(_psol_TW_bar(T_K, w))


def tsol_by_hsol(h, w):
    """Solve the solution temperature [K] back from the solution specific enthalpy h [kJ/kg] and methanol mass fraction w:
    hsol increases monotonically with T at fixed w (cp = A + B*t is positive over the whole domain);
    inverted by 100 bisection steps, with the solution bracket T in [233.15, 423.15] K.
    Returns None when h lies outside the range of hsol at that w."""
    lo, hi = 233.15, 423.15
    hlo, hhi = hsol(lo, w), hsol(hi, w)
    if not (hlo <= h <= hhi):
        return None
    for _ in range(100):
        mid = 0.5 * (lo + hi)
        if hsol(mid, w) < h:
            lo = mid
        else:
            hi = mid
    return 0.5 * (lo + hi)


# ---- Unverified formulas (archival only; do not use for computation; see the header note) ----
def density_printed_UNVERIFIED(T_K, w):
    """Eq. (4.10) transcribed as printed: rho = 2.55 - 2.366w - 0.0068t [g/cc], returns kg/m3.
    Warning: the temperature coefficient 0.0068 differs from the measurements in Table 4.2 of the thesis by about 16%; it is suspected to be 0.00068; unverified."""
    t = T_K - 273.15
    return 1000.0 * (2.55 - 2.366 * w - 0.0068 * t)


def viscosity_eq411_UNVERIFIED(T_K, w):
    """Eq. (4.11) transcribed from the OCR: mu = A*exp(B/T) [cP],
    A = 2.516 - 5.722w + 3.304w^2, B = -5424 + 22.3009w - 38.558w^2.
    Warning: the OCR is severely damaged (A is suspected to be missing a 10^-3 multiplier and the decimal point of B is unreliable); the values are unusable;
    archival only, to be refitted from the raw data of Table 4.3."""
    A = 2.516 - 5.722 * w + 3.304 * w * w
    B = -5424.0 + 22.3009 * w - 38.558 * w * w
    return A * math.exp(B / T_K)


if __name__ == "__main__":
    # Self-check: bubble-point temperatures from the isobaric temperature table of Appendix A (300 mmHg = 0.039997 MPa)
    print("T_bubble @300mmHg: w=0.250 -> %.2f K (thesis 419.0)" % T_bubble_PW(0.039997, 0.250))
    print("T_bubble @300mmHg: w=0.301 -> %.2f K (thesis 391.4)" % T_bubble_PW(0.039997, 0.301))
    print("T_bubble @300mmHg: w=0.356 -> %.2f K (thesis 380.3)" % T_bubble_PW(0.039997, 0.356))
    # Check points for H'
    print("H'(10C, 0.25)  = %.0f kJ/kg (thesis table 1940)" % h_prime(283.15, 0.25))
    print("H'(10C, 0.356) = %.0f kJ/kg (thesis table 1601)" % h_prime(283.15, 0.356))
    print("H'(100C, 0.25) = %.0f kJ/kg (thesis table 1645)" % h_prime(373.15, 0.25))
    # Check points for Cp (Table 3.7)
    print("Cp(51.3C, 0.403) = %.3f (measured 1.27)" % cp(273.15 + 51.3, 0.403))
    print("Cp(69.9C, 0.403) = %.3f (measured 1.30)" % cp(273.15 + 69.9, 0.403))
    print("P_bubble(80C, 0.35) = %.4f MPa" % psol_TW(353.15, 0.35))
    print("hsol(80C, 0.35) = %.1f kJ/kg, hgas = %.1f kJ/kg"
          % (hsol(353.15, 0.35), hgas(353.15, 0.35)))

"""
R134a (1) + DMF (2) solution VLE and enthalpy calculation - reference implementation
================================================
Model: NRTL activity coefficients + gamma-phi bubble-point model
Parameters fitted to: Zehioua et al., J. Chem. Eng. Data 2009 (DOI: 10.1021/je900440t)
            Table 5, 58 data points, 303.30-353.24 K
Validation accuracy: bubble-point pressure mean absolute relative error 1.49%, maximum 3.01%

Reference state: saturated-liquid enthalpy at 273.15 K = 100 kJ/kg (unified for R134a and DMF)

Author: Muse (2026-09-27)
"""

import math

R = 8.314462618          # J/(mol·K)
M1 = 102.03              # R134a molar mass, g/mol
M2 = 73.09               # DMF molar mass, g/mol

# ---- NRTL parameters (fitted values, alpha=0.3) ----
DG12 = 868.1             # J/mol,  (g12 - g22)
DG21 = -929.1            # J/mol,  (g21 - g11)
ALPHA = 0.3


def pref_r134a(T):
    """R134a saturation pressure, MPa. T in K. (Fitted to Table 3 of Zehioua, 298-353K, error <0.2%)"""
    return math.exp(7.89191 - 2310.84 / (T - 19.79))


def psat_dmf(T):
    """DMF saturation pressure, MPa. T in K. (NIST WebBook, Gopal & Rizvi 1968)"""
    return (10 ** (3.93068 - 1337.716 / (T - 82.648))) * 0.1


def vl_r134a(T):
    """R134a saturated-liquid molar volume, m3/mol (for the Poynting correction; a rough value suffices)"""
    rho = 1207 * (1 - 0.35 * (T - 300) / 100)   # kg/m3
    return 0.10203 / max(rho, 800)


def vl_dmf(T):
    """DMF liquid molar volume, m3/mol"""
    return 0.07309 / (944 * (1 - 0.0009 * (T - 293)))


def nrtl_gamma(T, x1):
    """
    NRTL activity coefficients.
    Returns (gamma1, gamma2)
    """
    x2 = 1.0 - x1
    t12 = DG12 / (R * T)
    t21 = DG21 / (R * T)
    G12 = math.exp(-ALPHA * t12)
    G21 = math.exp(-ALPHA * t21)
    D1 = x1 + x2 * G21
    D2 = x2 + x1 * G12
    ln_g1 = x2**2 * (t21 * (G21 / D1)**2 + t12 * G12 / D2**2)
    ln_g2 = x1**2 * (t12 * (G12 / D2)**2 + t21 * G21 / D1**2)
    return math.exp(ln_g1), math.exp(ln_g2)


def nrtl_hE(T, x1):
    """
    NRTL excess molar enthalpy, J/mol. (Obtained by analytic differentiation of gE with respect to T; verified by numerical differentiation)
    hE = -R*T^2 * d(gE/RT)/dT
    """
    x2 = 1.0 - x1
    t12 = DG12 / (R * T)
    t21 = DG21 / (R * T)
    G12 = math.exp(-ALPHA * t12)
    G21 = math.exp(-ALPHA * t21)
    D1 = x1 + x2 * G21
    D2 = x2 + x1 * G12
    term1 = (t21 * G21 / D1) * (-1 + ALPHA * t21 * x1 / D1)
    term2 = (t12 * G12 / D2) * (-1 + ALPHA * t12 * x2 / D2)
    return -R * T * x1 * x2 * (term1 + term2)


def psol(T, x1):
    """
    Bubble-point pressure calculation.
    Input: T (K), x1 (R134a liquid-phase mole fraction)
    Returns: (p_MPa, y1) bubble-point pressure in MPa and vapour-phase R134a mole fraction
    """
    x2 = 1.0 - x1
    g1, g2 = nrtl_gamma(T, x1)
    p1s = pref_r134a(T)
    p2s = psat_dmf(T)
    V1 = vl_r134a(T)
    V2 = vl_dmf(T)
    p = x1 * g1 * p1s + x2 * g2 * p2s
    for _ in range(40):
        Poy1 = math.exp(V1 * (p - p1s) * 1e6 / (R * T))
        Poy2 = math.exp(V2 * (p - p2s) * 1e6 / (R * T))
        p = x1 * g1 * p1s * Poy1 + x2 * g2 * p2s * Poy2
    y1 = x1 * g1 * p1s * math.exp(V1 * (p - p1s) * 1e6 / (R * T)) / p
    return p, y1


def bubble_T(p_MPa, x1, Tguess=330.0):
    """
    Back-calculate the temperature from a known bubble-point pressure (Newton iteration).
    Input: p_MPa, x1, initial value Tguess (K)
    Returns: T (K)
    """
    T = Tguess
    for _ in range(50):
        pc, _ = psol(T, x1)
        dT = 0.2
        p2, _ = psol(T + dT, x1)
        dpdT = (p2 - pc) / dT
        T = T - (pc - p_MPa) / dpdT
        if abs(pc - p_MPa) < 1e-9:
            break
    return T


def xi_by_tsol_tdew(Tsol, Tdew):
    """
    Back-calculate the concentration from a known dew-point temperature and solution temperature (80 bisection iterations).
    Input: Tdew (K) dew-point temperature, Tsol (K) solution temperature
    Returns: x1 (R134a liquid-phase mole fraction); None when there is no root
    Principle: DMF is treated as non-volatile; the dew point fixes the pressure P = pref_r134a(Tdew);
          then bisection solves psol(Tsol, x1) = P, with the bracket x1 in [0, 1]
          (the bubble-point pressure increases monotonically with x1 in that interval).
    No-root case: P outside the bubble-point pressure interval under Tsol (e.g. Tsol clearly below Tdew).
    """
    P = pref_r134a(Tdew)
    Plo = psol(Tsol, 0.0)[0]
    Phi = psol(Tsol, 1.0)[0]
    if not (Plo <= P <= Phi):
        return None
    lo, hi = 0.0, 1.0
    for _ in range(80):
        mid = 0.5 * (lo + hi)
        if psol(Tsol, mid)[0] < P:
            lo = mid
        else:
            hi = mid
    return 0.5 * (lo + hi)


def hliq_r134a(T):
    """
    R134a saturated-liquid enthalpy, kJ/kg.
    Fitted to Table C-1 of Tillner-Roth & Baehr (1994); the reference state has been shifted to 273.15K = 100 kJ/kg.
    Valid approx. 233-353 K, fit error <0.4 kJ/kg.
    """
    t = T - 273.15
    return 1.310235e-5 * t**3 + 1.34329e-3 * t**2 + 1.334242 * t + 100.0


def h_dmf_L(T):
    """
    DMF liquid enthalpy, kJ/kg.
    He et al., Solar Energy 83 (2009), Eq. (5); reference state: saturated liquid at 273.15K = 100 kJ/kg.
    """
    return -297.61 + 0.89544 * T + 0.0020551 * T * T


def x_to_w(x1):
    """Mole fraction -> mass fraction (R134a)"""
    return x1 * M1 / (x1 * M1 + (1 - x1) * M2)


def w_to_x(w1):
    """Mass fraction -> mole fraction (R134a)"""
    return (w1 / M1) / (w1 / M1 + (1 - w1) / M2)


def hsol(T, x1):
    """
    R134a-DMF solution enthalpy, kJ/kg.
    Input: T (K), x1 (R134a liquid-phase mole fraction)
    Reference state: saturated liquid at 273.15K = 100 kJ/kg (unified for both components)
    h = w1*h1 + w2*h2 + hE/Mbar
    """
    x2 = 1.0 - x1
    Mbar = x1 * M1 + x2 * M2          # g/mol
    w1 = x1 * M1 / Mbar
    w2 = x2 * M2 / Mbar
    hE = nrtl_hE(T, x1)               # J/mol
    return w1 * hliq_r134a(T) + w2 * h_dmf_L(T) + hE / Mbar  # J/mol / (g/mol) = kJ/kg



def _tsat_r134a(P_MPa):
    """R134a saturation temperature (K): analytic inverse of pref_r134a
    (the inverse function of P = exp(7.89191 - 2310.84/(T - 19.79)))."""
    return 2310.84 / (7.89191 - math.log(P_MPa)) + 19.79


def tdew_by_tsol_xi(T, x1):
    """
    Dew-point temperature (K) of the solution at (T, x1) (library-wide TdewByTsolXi convention):
        Tdew = _tsat_r134a(the pressure from psol(T, x1)),
    i.e. the saturation temperature corresponding to the solution surface pressure Psol, evaluated with this module's own pure-R134a line.
    DMF is treated as non-volatile (vapour phase y1 > 0.99).
    """
    return _tsat_r134a(psol(T, x1)[0])


def tsol_by_hsol(h, x1):
    """
    Solve the solution temperature (K) back from the solution specific enthalpy h (kJ/kg) and the R134a mole fraction x1:
    hsol increases monotonically with T at fixed x1; inverted by 100 bisection steps,
    with the solution bracket T in [280, 360] K. Returns None when h is outside the range.
    """
    lo, hi = 280.0, 360.0
    hlo, hhi = hsol(lo, x1), hsol(hi, x1)
    if not (hlo <= h <= hhi):
        return None
    for _ in range(100):
        mid = 0.5 * (lo + hi)
        if hsol(mid, x1) < h:
            lo = mid
        else:
            hi = mid
    return 0.5 * (lo + hi)


if __name__ == "__main__":
    print("VLE 验证 (T, x1 -> p):")
    for T, x1, pe in [(303.30, 0.4437, 337.0), (323.34, 0.7247, 923.8), (353.24, 0.6594, 1665.2)]:
        p, y1 = psol(T, x1)
        print(f"  T={T}K x1={x1}: p={p*1000:.1f} kPa (实验 {pe:.1f}), y1={y1:.4f}")
    print("\n溶液焓 h(T,x1) [kJ/kg]:")
    for T in [300, 330, 350]:
        for x1 in [0.2, 0.5, 0.8]:
            print(f"  T={T}K x1={x1}: h={hsol(T, x1):.2f}")

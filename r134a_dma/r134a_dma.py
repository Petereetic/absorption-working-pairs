"""
R134a (1) + DMA (2) bubble-point pressure and solution enthalpy - reference implementation
================================================
Model source: Nezu et al., "Thermodynamic properties of working-fluid pairs
          with R-134a for absorption refrigeration system",
          IIR/IIF Commission B1,B2,E1,E2, Guangzhou, 2002, pp.446-453.

Bubble-point pressure: paper Eq. (1) + Table 2 constants (R-134a/DMA column)
  P = P_R134a * x1 * exp{ x2*(A0+A1*Tr+A2*Tr^2+A3*Tr^3)
                        + x2^2*(B0+B1*Tr+B2*Tr^2)
                        + x2^3*(C0+C1*Tr) + x2^4*D0 }
  Tr = T/374.18, P_R134a is the R134a saturation pressure (Tillner-Roth & Baehr 1994,
  replaced here by the fitted formula; error <0.2% over 298-353K).
  Reported in the paper: deviation from experiment < ±3.8 kPa (DMA).

Solution enthalpy: paper Eq. (6) h = w1*h1 + w2*h2 + hE
  hE: UNIQUAC Eqs. (3)(4)(5) + Table 3 (q) + Table 4 (adjustable parameters, R-134a/DMA column)
  h1: R134a saturated-liquid enthalpy (Tillner-Roth fit; reference state 273.15K = 200 kJ/kg,
      consistent with the paper's h0=200 kJ/kg)
  h2: DMA liquid enthalpy, h2 = 200 + Cp*(T-273.15), Cp taken as the constant 178.2 J/mol/K
      (Wikipedia/DMA properties, 298K liquid-phase value), M=87.12 g/mol.
      Note: the paper computes Cp by Joback + CSP; a constant approximation is used here, as stated in the documentation.

Reference state: saturated liquid at 273.15 K = 200 kJ/kg (uniform for both components, as in the paper).

Author: Muse (2026-09-29)
"""

import math

R = 8.314462618          # J/(mol·K)
M1 = 102.03              # R134a molar mass, g/mol
M2 = 87.12               # DMA molar mass, g/mol (C4H9NO)
TC1 = 374.18             # R134a critical temperature, K (used in paper Eq. 1)

# ---- Paper Table 2: Eq. (1) constants (R-134a/DMA) ----
A0, A1, A2, A3 = -0.68156, 0.93065, 2.36801, -3.58456
B0, B1, B2 = 3.29883, 1.85907, 3.29883
C0, C1 = 1.77009, -3.90560
D0 = 1.26416

# ---- Paper Table 3: UNIQUAC q (R-134a/DMA) ----
Q1, Q2 = 2.38, 3.276

# ---- Paper Table 4: UNIQUAC adjustable parameters (R-134a/DMA) ----
# u_ij = Aij + Bij*T + Cij*T^2  (J/mol)
UA12, UA21 = -2.68e-2, -2.70e-2
UB12, UB21 = -4.34, -4.37
UC12, UC21 = 2.02e-2, 6.44e-3

# ---- DMA constant-pressure specific heat (constant approximation) ----
CP_DMA = 178.2 / M2      # kJ/(kg·K) = 2.0453


def psat_r134a(T):
    """R134a saturation pressure, MPa. T in K. (Fit; error <0.2% over 298-353K)"""
    return math.exp(7.89191 - 2310.84 / (T - 19.79))


def h_r134a_L(T):
    """
    R134a saturated-liquid enthalpy, kJ/kg.
    Fitted from Tillner-Roth & Baehr (1994). Reference state 273.15K = 200 kJ/kg
    (paper h0=200 kJ/kg; the original fit is based on 100, shifted by +100 here).
    """
    t = T - 273.15
    return 1.310235e-5 * t**3 + 1.34329e-3 * t**2 + 1.334242 * t + 200.0


def h_dma_L(T):
    """
    DMA liquid enthalpy, kJ/kg. Reference state 273.15K = 200 kJ/kg (paper h0).
    Cp taken as a constant approximation (see module documentation).
    """
    return 200.0 + CP_DMA * (T - 273.15)


def w_to_x(w1):
    """R134a mass fraction -> mole fraction"""
    return (w1 / M1) / (w1 / M1 + (1 - w1) / M2)


def x_to_w(x1):
    """R134a mole fraction -> mass fraction"""
    return x1 * M1 / (x1 * M1 + (1 - x1) * M2)


def bubble_p_w(T, w1):
    """
    Bubble-point pressure, MPa. Paper Eq. (1).
    Input: T (K), w1 (R134a mass fraction)
    """
    x1 = w_to_x(w1)
    x2 = 1.0 - x1
    Tr = T / TC1
    p1s = psat_r134a(T)
    e = (x2 * (A0 + A1*Tr + A2*Tr*Tr + A3*Tr*Tr*Tr)
         + x2*x2 * (B0 + B1*Tr + B2*Tr*Tr)
         + x2*x2*x2 * (C0 + C1*Tr)
         + x2*x2*x2*x2 * D0)
    return p1s * x1 * math.exp(e)


def bubble_T_w(p_MPa, w1):
    """
    Given the bubble-point pressure, solve back for the temperature (bisection).
    Input: p_MPa, w1. Returns: T (K)
    """
    lo, hi = 200.0, 374.0
    for _ in range(60):
        mid = 0.5 * (lo + hi)
        if bubble_p_w(mid, w1) < p_MPa:
            lo = mid
        else:
            hi = mid
    return 0.5 * (lo + hi)


def uniquac_hE(T, x1):
    """
    UNIQUAC excess molar enthalpy, J/mol. Paper Eqs. (3)(4)(5).
    Input: T (K), x1 (R134a mole fraction)
    """
    x2 = 1.0 - x1
    u12 = UA12 + UB12 * T + UC12 * T * T
    u21 = UA21 + UB21 * T + UC21 * T * T
    t12 = math.exp(-u12 / (R * T))
    t21 = math.exp(-u21 / (R * T))
    d1 = Q1 * x1 + Q2 * x2 * t21
    d2 = Q2 * x2 + Q1 * x1 * t12
    term1 = t21 * (UA21 - UC21 * T * T) / d1
    term2 = t12 * (UA12 - UC12 * T * T) / d2
    return Q1 * Q2 * x1 * x2 * (term1 + term2)


def h_solution_w(T, w1):
    """
    R134a-DMA solution enthalpy, kJ/kg. Paper Eq. (6).
    Input: T (K), w1 (R134a mass fraction)
    h = w1*h1 + w2*h2 + hE/Mbar
    """
    x1 = w_to_x(w1)
    x2 = 1.0 - x1
    Mbar = x1 * M1 + x2 * M2          # g/mol
    hE = uniquac_hE(T, x1)            # J/mol
    return w1 * h_r134a_L(T) + (1 - w1) * h_dma_L(T) + hE / Mbar


if __name__ == "__main__":
    print("R134a-DMA bubble point / solution enthalpy (Nezu et al. 2002)")
    print("=" * 60)
    # Bubble-point worked example
    for Tc, w in [(30, 0.5), (80, 0.4), (0, 0.3), (100, 0.6)]:
        T = Tc + 273.15
        p = bubble_p_w(T, w)
        print(f"BubbleP({Tc}°C, w={w}) = {p*10:.3f} bar")
    print("-" * 60)
    # Inverse-solution worked example
    for pbar, w in [(5.0, 0.5), (1.0, 0.3), (10.0, 0.7)]:
        T = bubble_T_w(pbar / 10, w)
        print(f"BubbleT({pbar} bar, w={w}) = {T-273.15:.2f} °C")
    print("-" * 60)
    # Enthalpy worked example
    for Tc, w in [(30, 0.5), (80, 0.4), (0, 0.3), (100, 0.6)]:
        T = Tc + 273.15
        h = h_solution_w(T, w)
        x = w_to_x(w)
        hE = uniquac_hE(T, x) / (x*M1 + (1-x)*M2)
        print(f"Hsol({Tc}°C, w={w}) = {h:.2f} kJ/kg  (hE={hE:.2f})")
    print("-" * 60)
    # Endpoint checks
    print(f"h_R134aL(0°C) = {h_r134a_L(273.15):.2f} (expected =200)")
    print(f"h_DMA(0°C) = {h_dma_L(273.15):.2f} (expected =200)")
    print(f"Hsol(30°C, w=1) = {h_solution_w(303.15, 1.0):.2f} (expected ~h_R134a)")
    print(f"Hsol(30°C, w=0) = {h_solution_w(303.15, 0.0):.2f} (expected ~h_DMA)")

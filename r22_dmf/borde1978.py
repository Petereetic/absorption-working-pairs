"""
Borde 1978 reconstruction: transcription and verification of the formulas from the R22-DMF enthalpy-concentration diagram paper

Identity of the paper (verified from the first page of the full text):
    M. Jelinek, I. Borde, I. Yaron,
    "Enthalpy-Concentration Diagram of the System R22-Dimethyl Formamide
     and Performance Characteristics of Refrigeration Cycle Operating
     with this System",
    ASHRAE Transactions, 84(2), 60-67, 1978. (ASHRAE No. 2493)
    The author line on the first page is printed as "IRENE BORDE".

Transcription notes:
    Eqs. (1)-(8) transcribed verbatim from the printed paper (the formula-page images at 200 dpi were checked item by item).
    The breakpoint of Eqs. (3)(4): for t_o < 154°F use Eq. (4); for 154 < t_o < 204.8°F use Eq. (5).
    Eq. (8) gives kcal/kg as printed (the formula already divides by the mean molecular weight);
    the text below Eq. (8) says "kcal/kmole", contradicting the kcal/kg required by Eq. (2);
    the formula itself (with /Mbar) governs, i.e. kcal/kg.

================================================================
Important: the constants of Eqs. (1) and (8) in the printed version are corrupted and must not be used for computation
================================================================
Numerical verification conclusions (2026-10-01; see the Borde 1978 reconstruction and verification notes file):

1. Eq. (1), computed with the printed constants, gives non-physical pressures over all reasonable compositions/temperatures
   (e.g. at X=0.5, 20°C it gives P = e^-39.3 psi, and the dP/dX trend is negative).
   The printing was checked item by item: g2 = -7367276 does carry the minus sign (not an OCR misread);
   the corruption cannot be explained by a single sign (at the pure-R22 end X=1 it also fails to converge to the saturation pressure).

2. The hmix computed by Eq. (8) with the printed constants differs from Fig. 1 of the paper (the actual output of the author's program)
   by up to a factor of 3.4, so the printed constants of Eq. (8) are likewise untrustworthy.

3. The usable numerical record is Fig. 1 itself (isotherms 10-90°C, isobars 1-20 kg/cm²);
   this module includes the digitised data of Fig. 1 (FIG1_...), with uncertainties of about ξ±0.01,
   h±1.2 kcal/kg, and intersection temperatures ±5°C.

In this module, p_solution_borde1978() and hmix_borde1978() are kept as implementations "transcribed as printed",
for verification reproduction only, and raise a warning when called; do not use them for engineering computation.
"""

import math
import warnings

# ------------------------------------------------------------------
# Constants of Eq. (1): transcribed as printed (confirmed corrupted)
#   P = exp[ Σe_n X^n + (1/T)Σf_n X^n + (1/T²)Σg_n X^n ], P in psi, T in K,
#   X = R22 mole fraction
# ------------------------------------------------------------------
E = (16.17326, -42.6391, 58.78278)
F_ = (-6504.46, 32838.19, -42259.76)
G = (656962.9, -5650373, -7367276)

# Constants of Eq. (7): pure-R22 saturation pressure (Tyagi & Shankar)
#   P = exp(a + b/T + c*T + d*lnT), P in atm, T in K
A7, B7, C7, D7 = 209.72706, -7738.205251, 0.0562768, -34.79

M_R22, M_DMF = 86.47, 73.09          # molecular weights used by Eq. (8)
R_KCAL = 1.986                        # kcal/(kmol·K), as given by Eq. (8)
KCAL2KJ = 4.1868

_CORRUPT_MSG = ("Borde 1978 式(1)/式(8) 印刷常数已数值证实损坏，"
                "结果非物理，仅供转录核验，不得用于工程计算。")


def _poly(c, x):
    return c[0] + c[1] * x + c[2] * x * x


def p_solution_borde1978(X, T_K):
    """Eq. (1): solution equilibrium pressure [psi]. X = R22 mole fraction, T_K in K. Corrupted; see the module docstring."""
    warnings.warn(_CORRUPT_MSG, UserWarning)
    lnP = _poly(E, X) + _poly(F_, X) / T_K + _poly(G, X) / T_K ** 2
    return math.exp(lnP)


def p_R22_sat_borde1978(T_K):
    """Eq. (7): pure-R22 saturation pressure [atm]. T_K in K."""
    return math.exp(A7 + B7 / T_K + C7 * T_K + D7 * math.log(T_K))


def h_r22_borde1978(t_C):
    """Eqs. (3)-(5): liquid-R22 enthalpy [kcal/kg]. t_C in °C; reference state 273.2K = 100."""
    t_o = t_C * 9.0 / 5.0 + 32.0  # °F
    if t_o < 154.0:
        Fto = 10.70116 + 0.256331 * t_o + 0.000295846 * t_o ** 2      # Eq. (4)
    else:
        Fto = 133.0235 - 1.253386 * t_o + 0.00497 * t_o ** 2          # Eq. (5)
    return 89.3491 + 0.556 * Fto                                      # Eq. (3)


def h_dmf_borde1978(t_C):
    """Eq. (6): liquid-DMF enthalpy [kcal/kg]. t_C in °C; reference state 273.2K = 100."""
    return 100.0 + 0.482 * t_C + 0.000491 * t_C ** 2


def hmix_borde1978(t_C, xi):
    """Eq. (8): integral heat of mixing [kJ/kg]. xi = R22 mass fraction. Corrupted; see the module docstring."""
    warnings.warn(_CORRUPT_MSG, UserWarning)
    T = t_C + 273.15
    n1, n2 = xi / M_R22, (1.0 - xi) / M_DMF
    X = n1 / (n1 + n2)
    if not (0.0 < X < 1.0):
        return 0.0
    Mbar = M_R22 * X + M_DMF * (1.0 - X)
    c0 = (F_[0] + 2.0 * G[0] / T) - B7 - C7 * T ** 2 + D7 * T
    c1 = F_[1] + 2.0 * G[1] / T
    c2 = F_[2] + 2.0 * G[2] / T
    xx = X / (1.0 - X)
    braces = (c0 * xx
              + c1 * (xx + math.log(1.0 - X))
              + c2 * (1.0 / (1.0 - X) - (1.0 - X) + 2.0 * math.log(1.0 - X)))
    h_kcal_per_kg = R_KCAL * (1.0 - X) / Mbar * braces
    return h_kcal_per_kg * KCAL2KJ


def h_solution_borde1978(t_C, xi, use_printed_hmix=False):
    """Eq. (2): solution enthalpy [kJ/kg]. By default hmix=0 (because the printed Eq. (8) is corrupted);
    with use_printed_hmix=True it is computed by the printed Eq. (8) (raises a warning; for verification only)."""
    h_kcal = (xi * h_r22_borde1978(t_C) + (1.0 - xi) * h_dmf_borde1978(t_C))
    if use_printed_hmix:
        h_kcal += hmix_borde1978(t_C, xi) / KCAL2KJ
    return h_kcal * KCAL2KJ


# ------------------------------------------------------------------
# Digitised data of Fig. 1 (extracted 2026-10-01 from the scanned figure of the paper)
# Uncertainties: ξ ±0.01, h ±1.2 kcal/kg; intersection temperatures ±5°C.
# Isotherm label points: T exact (the label lies on the line); (ξ,h) is the label centre.
# Isobar label points: P exact (the label value); (ξ,h) is the label centre.
# Intersections: crossings of isobars and isotherms; P/T are nominal values; (ξ,h) is the intersection position.
# ------------------------------------------------------------------
# (T_C, xi, h_kcal_per_kg)
FIG1_ISOTHERMS = [
    (90, 0.1131, 145.89),
    (80, 0.2005, 137.24),
    (70, 0.2474, 130.94),
    (60, 0.2980, 124.04),
    (50, 0.3755, 115.38),
    (40, 0.4477, 109.00),
    (30, 0.5398, 107.08),
    (20, 0.6035, 102.10),
    (10, 0.6826, 98.86),
]

# (P_kg_per_cm2, xi, h_kcal_per_kg)
FIG1_ISOBARS = [
    (1, 0.2007, 104.97),
    (2, 0.2572, 108.43),
    (3, 0.2984, 111.89),
    (4, 0.3395, 114.78),
    (5, 0.3909, 114.43),
    (6, 0.4422, 113.63),
    (8, 0.4936, 117.67),
    (10, 0.5347, 119.40),
    (12, 0.5789, 128.64),
    (14, 0.6170, 130.95),
    (16, 0.6365, 134.41),
    (18, 0.6663, 136.14),
    (20, 0.6858, 138.22),
]

# (P_kg_per_cm2, T_C, xi, h_kcal_per_kg)
FIG1_CROSSINGS = [
    (1, 40, 0.2624, 114.20),
    (2, 40, 0.4063, 111.32),
    (3, 50, 0.3960, 116.63),
    (4, 50, 0.4165, 118.59),
    (6, 50, 0.5502, 117.09),
    (8, 60, 0.5419, 120.09),
    (10, 60, 0.5902, 119.28),
    (12, 70, 0.5656, 125.17),
    (14, 70, 0.6087, 123.79),
    (16, 80, 0.5872, 130.72),
    (20, 80, 0.6735, 127.94),
]


def hmix_from_fig1(t_C, xi, h_fig_kcal):
    """Back out the heat of mixing [kJ/kg] from Fig. 1 (T,ξ,h): hmix = h_fig - [ξ*hR22 + (1-ξ)*hDMF]."""
    h_ideal = xi * h_r22_borde1978(t_C) + (1.0 - xi) * h_dmf_borde1978(t_C)
    return (h_fig_kcal - h_ideal) * KCAL2KJ

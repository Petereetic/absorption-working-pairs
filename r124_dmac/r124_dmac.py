"""R124-DMAC bubble-point pressure, solution enthalpy, density and viscosity.

Reference implementation transcribed from:
  Borde, I., Jelinek, M., Daltrophe, N. C., "Working fluids for an absorption
  system based on R124 (2-chloro-1,1,2,-tetrafluoroethane) and organic
  absorbents", Int. J. Refrigeration 20(4), 256-266, 1997.

Conventions (as in the paper):
  xi  = weight fraction of R124 in the liquid solution (0..1)
  x   = mole fraction of R124 in the liquid solution
  T_C = temperature in degC;  T = T_C + 273.15 in K where an equation needs K
  P   = bar;  h = kJ/kg;  rho = kg/m3;  eta = mPa s (= cP)

Two misprints in the paper are corrected here, each arbitrated by the paper's
own data (see 公式说明.md for the full evidence):
  * Table 8, DMAC row: eta0/eta1 are printed x10 too large
    (-16.8400 / 1348.80). The mixture correlation Eq. (26) at xi = 0 and the
    literature value of DMAC viscosity agree with -1.68400 / 134.880.
  * Table 9, coefficient rho_{0,0} is printed 0.95521E+01; with E+00 both
    pure-component endpoints reproduce the Table 7 intercepts to < 0.3 %.
The pure-component vapour-pressure equation is Eq. (15) of the paper; the
caption of Table 2 mislabels it "Equation (1)".
"""
import math

_M_R124 = 136.50   # g/mol (Table 1)
_M_DMAC = 87.12    # g/mol (Table 1)

# ---- Pure-component vapour pressure, Eq. (15): ------------------------------
# ln(Ps/bar) = A + B/(T+C) + D*T + E*ln(T) + F*T^2 ,  T in K   (Table 2)
_PSAT = {
    "R124":   (-119.33446, -1351.341,    0.0, -0.12497, 27.21197, 8.32656e-5),
    "DMAC":   (   6.01834, -1800.240, -138.5,  0.0,      0.0,      0.0),
    "NMP":    (   8.50639, -3063.357, -115.4,  0.0,      0.0,      0.0),
    "MCL":    (   8.09382, -3078.393, -130.0,  0.0,      0.0,      0.0),
    "DMEU":   (  26.80333, -25627.39,  459.0,  0.0,      0.0,      0.0),
    "DMETEG": (  24.56738, -21564.48,  328.4,  0.0,      0.0,      0.0),
}

def psat(comp, T_C):
    """Saturation pressure (bar) of a pure component, Eq. (15). T_C in degC."""
    A, B, C, D, E, F = _PSAT[comp]
    T = T_C + 273.15
    return math.exp(A + B / (T + C) + D * T + E * math.log(T) + F * T * T)

def psat_R124(T_C):
    return psat("R124", T_C)

def psat_DMAC(T_C):
    return psat("DMAC", T_C)

def Tsat_R124(P_bar):
    """Saturation temperature (degC) of pure R124 at P_bar (inverts Eq. 15)."""
    lo, hi = -60.0, 120.0
    if not (psat_R124(lo) <= P_bar <= psat_R124(hi)):
        return None
    for _ in range(80):
        mid = 0.5 * (lo + hi)
        if psat_R124(mid) < P_bar:
            lo = mid
        else:
            hi = mid
    return 0.5 * (lo + hi)

# ---- Bubble-point pressure of R124-DMAC, Eq. (16): --------------------------
# P = sum_j sum_i p_ij * xi^i * T^j   (bar; xi weight fraction; T in K)
# Table 3, rows j = 0..7, columns i = 0..7.
_P = [
    [ 0.11502e-01, -0.28240e+02,  0.41188e+02, -0.26168e+02,  0.0,          0.18381e+03, -0.31190e+03,  0.13914e+03],
    [-0.13711e-01,  0.24179e+00, -0.26951e+00,  0.0,          0.0,          0.75999e-01,  0.0,          0.0],
    [ 0.91911e-04,  0.0,          0.0,          0.0,          0.0,          0.0,          0.0,          0.0],
    [ 0.0,         -0.31564e-05,  0.92677e-06,  0.78191e-05, -0.13310e-04,  0.0,          0.12701e-04, -0.65958e-05],
    [-0.86519e-09,  0.0,          0.0,          0.0,          0.0,          0.0,          0.0,          0.0],
    [ 0.0,          0.22998e-10,  0.0,          0.0,          0.0,          0.33233e-10,  0.0,         -0.24081e-10],
    [ 0.59436e-14,  0.0,         -0.68310e-13,  0.0,         -0.17145e-13,  0.0,          0.0,          0.0],
    [-0.67036e-17, -0.53440e-16,  0.14140e-15, -0.94881e-16,  0.0,          0.56692e-15, -0.10014e-14,  0.53340e-15],
]

def bubble_P(T_C, xi):
    """Bubble-point pressure (bar). T_C in degC, xi = R124 mass fraction."""
    T = T_C + 273.15
    s = 0.0
    for j in range(8):
        row = 0.0
        for i in range(8):
            row += _P[j][i] * xi ** i
        s += row * T ** j
    return s

def bubble_T(P_bar, xi, Tlo_C=0.0, Thi_C=150.0):
    """Bubble-point temperature (degC) by bisection. None if out of range."""
    Plo, Phi = bubble_P(Tlo_C, xi), bubble_P(Thi_C, xi)
    if not (Plo <= P_bar <= Phi):
        return None
    lo, hi = Tlo_C, Thi_C
    for _ in range(80):
        mid = 0.5 * (lo + hi)
        if bubble_P(mid, xi) < P_bar:
            lo = mid
        else:
            hi = mid
    return 0.5 * (lo + hi)

def dew_T(P_bar, xi=None):
    """Dew-point temperature (degC): pure-R124 saturation temperature.

    DMAC is treated as non-volatile (psat_DMAC/psat_R124 < 0.6 % at 80 degC),
    so the vapour is essentially pure R124.
    """
    return Tsat_R124(P_bar)

# ---- Enthalpy ---------------------------------------------------------------
# Excess specific enthalpy, Eq. (19):
#   hE = 4.1868 * sum_j sum_i h_ij * x^i * T^j   (kJ/kg; x mole fraction; T K)
# Table 4, rows j = 0..7, columns i = 0..7.
_H = [
    [-0.34981e+02, -0.18479e+03,  0.27310e+03, -0.22155e+02,  0.0,         -0.49058e+02,  0.61147e+01,  0.16635e+01],
    [ 0.31418e+00,  0.59584e+00, -0.90572e+00,  0.0,          0.0,          0.16399e+00,  0.0,          0.0],
    [-0.80917e-03,  0.0,          0.0,          0.11400e-04,  0.0,          0.0,          0.0,          0.0],
    [ 0.0,          0.32184e-07,  0.0,          0.0,          0.14107e-05,  0.0,          0.74883e-06, -0.10444e-05],
    [ 0.17947e-08,  0.0,          0.0,          0.0,          0.0,          0.0,          0.0,          0.0],
    [ 0.0,         -0.11860e-10,  0.18271e-10,  0.0,          0.0,         -0.22810e-10,  0.0,          0.10914e-10],
    [ 0.0,          0.0,          0.0,          0.0,          0.0,          0.0,          0.0,          0.0],
    [-0.43652e-17,  0.34001e-16, -0.50197e-16, -0.10080e-16,  0.0,          0.67800e-16,  0.0,         -0.31527e-16],
]

def xi_to_x(xi):
    """Weight fraction -> mole fraction of R124."""
    n_r = xi / _M_R124
    n_a = (1.0 - xi) / _M_DMAC
    return n_r / (n_r + n_a)

def h_excess(T_C, xi):
    """Excess specific enthalpy of the solution (kJ/kg), Eq. (19)."""
    T = T_C + 273.15
    x = xi_to_x(xi)
    s = 0.0
    for j in range(8):
        row = 0.0
        for i in range(8):
            row += _H[j][i] * x ** i
        s += row * T ** j
    return 4.1868 * s

# Pure liquid enthalpies; reference state: h = 100 kJ/kg at 0 degC for both.
_CP_DMAC = (0.4578, 0.000839)            # Table 5: Cp0, Cp1 (cal/g/K basis)
_HR_R124 = (0.250767, 0.347753e-3, 0.100977e-5, 0.342458e-8,
            0.0, 0.0, 0.699612e-14)      # Table 6: h_r1 .. h_r7

def h_absorbent(T_C):
    """Liquid enthalpy of pure DMAC (kJ/kg), Eq. (20). T_C in degC."""
    Cp0, Cp1 = _CP_DMAC
    return 100.0 + 4.1868 * (Cp0 * T_C + 0.5 * Cp1 * T_C ** 2)

def h_refrigerant(T_C):
    """Liquid enthalpy of pure R124 (kJ/kg), Eq. (21). T_C in degC."""
    s = 0.0
    for i, hr in enumerate(_HR_R124, start=1):
        s += hr * T_C ** i
    return 100.0 + 4.1868 * s

def h_liq(T_C, xi):
    """Solution liquid enthalpy (kJ/kg), Eq. (22). xi = R124 mass fraction."""
    return h_refrigerant(T_C) * xi + h_absorbent(T_C) * (1.0 - xi) \
        + h_excess(T_C, xi)

# ---- Density ----------------------------------------------------------------
# Pure components, Eq. (23): rho = sum_i rho_i t^i  (10^3 kg/m3; t in degC)
_RHO_PURE = {
    "R124": (1.4660, -0.3394e-2, -0.16063e-5, -0.20040e-6),
    "DMAC": (0.9528, -0.5856e-3, -0.33632e-5, 0.0),
}

def rho_pure(comp, T_C):
    """Pure-component liquid density (kg/m3), Eq. (23)."""
    c = _RHO_PURE[comp]
    return 1000.0 * sum(c[i] * T_C ** i for i in range(4))

# Mixture, Eq. (25): rho = sum_j sum_i rho_ij xi^i t^j (10^3 kg/m3; t in degC)
# Table 9, rows j = 0..3, columns i = 0..3. rho_00 corrected (see docstring).
_RHO_MIX = [
    [0.95521,      0.43672,     -0.28160,      0.35610],
    [-0.15533e-3, -0.37079e-3,  0.0,         -0.29230e-2],
    [-0.13981e-4,  0.0,          0.13550e-4,   0.0],
    [0.60941e-7,  -0.97547e-7,   0.33531e-6,  -0.50554e-6],
]

def rho_mix(T_C, xi):
    """Solution density (kg/m3), Eq. (25). T_C in degC, xi mass fraction."""
    s = 0.0
    for j in range(4):
        row = 0.0
        for i in range(4):
            row += _RHO_MIX[j][i] * xi ** i
        s += row * T_C ** j
    return 1000.0 * s

# ---- Viscosity ---------------------------------------------------------------
# Pure components, Eq. (24): ln(eta) = eta0 + eta1/(T + eta2), eta in mPa s, T K
# DMAC row uses the corrected coefficients (printed values are x10, see notes).
_ETA_PURE = {
    "R124": (-8.9301, 5094.90, 357.4),     # based on predicted data (paper)
    "DMAC": (-1.68400, 134.880, -223.2),   # corrected; printed: -16.8400/1348.80
}

def eta_pure(comp, T_C):
    """Pure-component viscosity (mPa s), Eq. (24). T_C in degC."""
    e0, e1, e2 = _ETA_PURE[comp]
    T = T_C + 273.15
    return math.exp(e0 + e1 / (T + e2))

# Mixture, Eq. (26): ln(eta) = sum_j sum_i eta_ij xi^i T^{-j}  (mPa s; T in K)
# Table 10, rows j = 0..3, columns i = 0..3.
_ETA_MIX = [
    [7.6992,     0.60007,   -8.9875,    -1.7031],
    [-6769.2,    0.0,        4555.4,    0.0],
    [1343400.0,  0.0,        0.0,       0.0],
    [0.0,       -64446000.0, 0.0,      -106310000.0],
]

def eta_mix(T_C, xi):
    """Solution viscosity (mPa s), Eq. (26). T_C in degC, xi mass fraction."""
    T = T_C + 273.15
    s = 0.0
    for j in range(4):
        row = 0.0
        for i in range(4):
            row += _ETA_MIX[j][i] * xi ** i
        s += row * T ** (-j)
    return math.exp(s)

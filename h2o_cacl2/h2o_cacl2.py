# -*- coding: utf-8 -*-
"""
H2O - CaCl2 working pair: properties of aqueous calcium chloride.

Source: Conde-Petit, M. R., "Properties of aqueous solutions of
lithium and calcium chlorides: formulations for use in air
conditioning equipment design", Int. J. Thermal Sciences 43 (2004)
367-382.  DOI 10.1016/j.ijthermalsci.2003.09.003.
This module implements the CaCl2 branch only; the LiCl branch of the
same paper lives in ../h2o_licl/.  Coefficients and verification
anchors: dossiers/H2O-LiCl-CaCl2-Conde.md (formula material library).

Dilution-enthalpy theta convention (IMPORTANT): in Sec.8 the paper
does not redefine theta, so by the paper's own Nomenclature default
theta = theta_r = T_K / T_c,H2O (dossier Sec.8 ruling, 2026-11-19,
confirmed against the paper's Figs. 26/27 at 600 dpi: CaCl2 branch
xi=0.445/0.505/0.52 at 40 degC -> 209/300/321 kJ/kg_H2O, figure
~197/298/322; xi=0.6 at 100 degC -> 649.6, figure ~660).  The Sato
theta_s = T_K/228 - 1 is used ONLY in the Sec.7 specific-heat
section, where the paper defines it explicitly.  NOTE: the sibling
h2o_licl module as first built (2026-11-20) used theta_s in its
dh_d; it was changed to theta_r on 2026-11-24 by Peter's order, so
both branches now follow the 2026-11-19 ruling.

Conventions (library-wide):
  * xi  = CaCl2 MASS fraction (0 .. 0.60), the paper's variable.
  * T   in degC at the public boundary (paper works in K internally;
          theta_r = T_K / 647.096, theta_s = T_K / 228 - 1).
  * P   in MPa at the public boundary (2026-10-14 rule).
  * h   in kJ/kg, rho kg/m3, eta Pa s, sigma N/m,
    lambda W/(m K), cp kJ/(kg K), dh_d kJ/kg_H2O.
  * Functions return None outside their stated range
    (C returns NAN, VBA returns Empty).

Implemented paper sections (CaCl2 coefficients only):
  Sec.1 vapour pressure (Table 3), Sec.2 crystallisation / SLE
  (Table 2), Sec.3 density (Tables 4-5), Sec.4 surface tension
  (Table 6), Sec.5 viscosity (Table 7), Sec.6 thermal conductivity
  (Table 9, Riedel), Sec.7 specific heat (Table 10),
  Sec.8 differential dilution enthalpy (Table 11, CaCl2 branch,
  theta = theta_r per the dossier ruling), Appendix A Saul-Wagner
  vapour pressure of pure water (Table 12).

Water-side auxiliary correlations NOT given numerically in the
paper (the paper cites the IAPWS industrial formulations; its own
Sato Cp_H2O coefficients are printed only inside Fig. 21):
  * cp_water / lambda_water: linear interpolation of standard
    IAPWS saturated-liquid values tabulated every 10 degC
    (0..150 degC) -- same tables as the h2o_licl module.
  * eta_water: Vogel equation eta = 2.414e-5 * 10^(247.8/(T_K-140))
    Pa s (reproduces 1.002 mPa s at 20 degC, 0.890 at 25 degC).
  * sigma_water: IAPWS formula as printed in the paper Sec.4,
    sigma = sigma0 * (1 + b*(1-theta_r)) * (1-theta_r)^mu with
    b = -0.625 (see the h2o_licl module for the sign note).

Enthalpy construction (hsol) -- READ BEFORE USE:
  Conde gives no closed-form solution enthalpy.  hsol is built as
      hsol(T, xi) = integral_0^T cp_sol(T', xi) dT'  +  e25(xi)
      e25(xi)     = xi * integral_0^xi dh_d(s, 25 degC) / s^2 ds
  where dh_d is the Sec.8 differential dilution enthalpy under the
  convention (Conde's desorption-enthalpy usage) that the partial
  specific enthalpy of water in solution is h_w^liq - dh_d; the
  integral is the resulting excess enthalpy per kg of solution
  over the pure-component mixture, anchored at 25 degC.
  Datum: hsol(0 degC, xi=0) = 0 (pure liquid water at 0 degC);
  the pure-component sensible datum is zero at 0 degC, so
  hsol(0 degC, xi) = e25(xi).  By construction
  d(hsol)/dT = cp_sol exactly; the temperature dependence of dh_d
  is NOT folded into hsol (dh_d(T, xi) is provided separately for
  desorption-enthalpy balances).  Use enthalpy DIFFERENCES within
  this module only; do not mix with other modules' enthalpy data.

Boundary residual (paper, recorded as printed): pi(xi->0) =
1 - pi9 * exp(-2) = 0.99756, i.e. psol(T, 0) is 0.24 % below
pref_water(T); xi_by_tsol_tdew therefore has no root when the dew
point is within ~0.25 % (in pressure) of the solution temperature.
"""
import math

_TC = 647.096          # K, critical temperature of water
_PC = 22.064           # MPa, critical pressure of water
_M_CACL2 = 110.98      # g/mol (used as kg/kmol in Sec.6, see there)
_I_S = 2.0             # stoichiometric ion number of CaCl2 (Sec.6)

# --- Appendix A: Saul-Wagner vapour pressure of water (Table 12) ---
_A_SW = (-7.858230, 1.839910, -11.781100, 22.670500, -15.939300, 1.775160)

# --- Sec.3 water density coefficients ---
_B_RHO = (1.9937718430, 1.0985211604, -0.5094492996, -1.7619124270,
          -44.9005480267, -723692.2618632)
_RHO_C = 322.0         # kg/m3

# --- Sec.1 vapour-pressure parameters, CaCl2 (Table 3) ---
_PI = (0.31, 3.698, 0.60, 0.231, 4.584, 0.49, 0.478, -5.20, -0.40, 0.018)

# --- Sec.3 density coefficients, CaCl2 (Tables 4-5) ---
_RHO = (1.0, 0.836014, -0.436300, 0.105642)

# --- Sec.4 surface tension coefficients, CaCl2 (Table 6) ---
_SIG = (2.33067, -10.78779, 13.56611, 1.95017, -1.77990)

# --- Sec.5 viscosity coefficients, CaCl2 (Table 7) ---
_ETA = (-0.169310, 0.817350, 0.574230, 0.398750)

# --- Sec.6 Riedel thermal conductivity, CaCl2 (Table 9) ---
_ALP0, _ALP1 = 5.9473e-3, -1.3988e-3
_LAM0, _LAM1 = 0.208496, 1.747278   # supercooled water branch

# --- Sec.7 specific heat (Table 10), CaCl2: A,B,C,D,E,F,G,H ---
# CaCl2 uses the cubic f1 = A xi + B xi^2 + C xi^3 over the whole
# range (D = E = 0 in the paper; there is no second branch).
_TAB10 = (1.63799, -1.69002, 1.05124, 0.0, 0.0,
          58.5225, -105.6343, 47.7948)

# --- Sec.8 differential dilution enthalpy (Table 11), CaCl2: H1..H6 ---
_HD = (0.855, -1.965, -2.265, 0.8, -955.690, 3011.974)

# --- Sec.2 SLE branches, CaCl2 (Table 2): (A0, A1, A2, A3) with
# theta_r = A0 + A1*xi + A2*xi^2 + A3*xi^7.5 ---
_SLE = {
    "ice":          (0.422088, -0.066933, -0.282395, -355.514247),
    "CaCl2.6H2O":   (-0.378950, 3.456900, -3.531310, 0.0),
    "CaCl2.4H2Oa":  (-0.519970, 3.400970, -2.851290, 0.0),
    "CaCl2.4H2Ob":  (-1.149044, 5.509111, -4.642544, 0.0),
    "CaCl2.2H2O":   (-2.385836, 8.084829, -5.303476, 0.0),
    "CaCl2":        (-2.807560, 4.678250, 0.0, 0.0),
}

# Tabulated saturated-liquid water values (IAPWS), every 10 degC.
_CP_W_TAB = (4.217, 4.192, 4.182, 4.178, 4.178, 4.179, 4.181, 4.186,
             4.193, 4.204, 4.216, 4.229, 4.242, 4.254, 4.267, 4.281)
_LAM_W_TAB = (0.561, 0.580, 0.598, 0.615, 0.631, 0.644, 0.654, 0.663,
              0.670, 0.676, 0.679, 0.683, 0.685, 0.686, 0.685, 0.683)

_XI_MAX = 0.60
_XI_H_MAX = 0.60
_XI_SLE_MAX = 0.80


def _tab_interp(tab, T_C):
    """Linear interpolation on a 0..150 degC / 10 degC table."""
    if T_C <= 0.0:
        return tab[0]
    if T_C >= 150.0:
        return tab[-1]
    i = int(T_C // 10.0)
    f = (T_C - 10.0 * i) / 10.0
    return tab[i] * (1.0 - f) + tab[i + 1] * f


# ----------------------------------------------------------------------
# Pure water
# ----------------------------------------------------------------------
def pref_water(T_C):
    """Saturation pressure of pure water [MPa] (Saul-Wagner, App. A).
    Range: -50..300 degC."""
    if T_C is None or not (-50.0 <= T_C <= 300.0):
        return None
    T = T_C + 273.15
    tau = 1.0 - T / _TC
    s = (_A_SW[0] * tau + _A_SW[1] * tau ** 1.5 + _A_SW[2] * tau ** 3
         + _A_SW[3] * tau ** 3.5 + _A_SW[4] * tau ** 4
         + _A_SW[5] * tau ** 7.5)
    return _PC * math.exp(s / (1.0 - tau))


def tsat_water(P_MPa):
    """Saturation temperature of pure water [degC] at P [MPa]:
    bisection inverse of this module's own pref_water."""
    if P_MPa is None or P_MPa <= 0.0:
        return None
    lo, hi = -50.0, 300.0
    if not (pref_water(lo) <= P_MPa <= pref_water(hi)):
        return None
    for _ in range(100):
        mid = 0.5 * (lo + hi)
        if pref_water(mid) < P_MPa:
            lo = mid
        else:
            hi = mid
    return 0.5 * (lo + hi)


def rho_water(T_C):
    """Density of pure water [kg/m3] (Sec.3). Range: -40..150 degC."""
    if T_C is None or not (-40.0 <= T_C <= 150.0):
        return None
    T = T_C + 273.15
    tau = 1.0 - T / _TC
    return _RHO_C * (1.0 + _B_RHO[0] * tau ** (1.0 / 3.0)
                     + _B_RHO[1] * tau ** (2.0 / 3.0)
                     + _B_RHO[2] * tau ** (5.0 / 3.0)
                     + _B_RHO[3] * tau ** (16.0 / 3.0)
                     + _B_RHO[4] * tau ** (43.0 / 3.0)
                     + _B_RHO[5] * tau ** (110.0 / 3.0))


def cp_water(T_C):
    """Specific heat of liquid water [kJ/(kg K)]: tabulated IAPWS
    saturated-liquid values, linear interpolation. Range 0..150 degC.
    (Conde's own Sato Cp_H2O coefficients are figure-printed only
    and flagged [to be verified] in the dossier.)"""
    if T_C is None or not (0.0 <= T_C <= 150.0):
        return None
    return _tab_interp(_CP_W_TAB, T_C)


def sigma_water(T_C):
    """Surface tension of pure water [N/m] (IAPWS form, Sec.4):
    sigma = 235.8 * (1 + b*(1-theta_r)) * (1-theta_r)^1.256 mN/m,
    b = -0.625.  Range: -40..150 degC."""
    if T_C is None or not (-40.0 <= T_C <= 150.0):
        return None
    th = (T_C + 273.15) / _TC
    return 235.8e-3 * (1.0 - 0.625 * (1.0 - th)) * (1.0 - th) ** 1.256


def eta_water(T_C):
    """Dynamic viscosity of pure water [Pa s]: Vogel equation
    2.414e-5 * 10^(247.8/(T_K-140)).  Range: 0..150 degC.
    (Conde cites the IAPWS industrial formulation, App. B; its
    coefficient tables were not transcribed in the dossier.)"""
    if T_C is None or not (0.0 <= T_C <= 150.0):
        return None
    return 2.414e-5 * 10.0 ** (247.8 / (T_C + 273.15 - 140.0))


def lambda_water(T_C):
    """Thermal conductivity of pure water [W/(m K)].  For T >= 20 degC
    tabulated IAPWS values (interpolated); for T < 20 degC Conde's
    supercooled branch lambda = lambda(20C) * (lam0 + lam1*theta_r).
    Range: -20..150 degC."""
    if T_C is None or not (-20.0 <= T_C <= 150.0):
        return None
    if T_C >= 20.0:
        return _tab_interp(_LAM_W_TAB, T_C)
    th = (T_C + 273.15) / _TC
    return _tab_interp(_LAM_W_TAB, 20.0) * (_LAM0 + _LAM1 * th)


# ----------------------------------------------------------------------
# Vapour pressure (Sec.1)
# ----------------------------------------------------------------------
def pi_factor(xi, T_C):
    """pi = p_sol / p_H2O at (xi, T_C) (Sec.1). xi in [0, 0.60],
    T in [-40, 150] degC."""
    if xi is None or T_C is None:
        return None
    if not (0.0 <= xi <= _XI_MAX and -40.0 <= T_C <= 150.0):
        return None
    p = _PI
    th = (T_C + 273.15) / _TC
    A = 2.0 - (1.0 + (xi / p[0]) ** p[1]) ** p[2]
    B = (1.0 + (xi / p[3]) ** p[4]) ** p[5] - 1.0
    f = A + B * th
    if xi == 0.0:
        pi25 = 1.0 - p[9] * math.exp(-0.01 / 0.005)
    else:
        pi25 = (1.0 - (1.0 + (xi / p[6]) ** p[7]) ** p[8]
                - p[9] * math.exp(-((xi - 0.1) ** 2) / 0.005))
    return pi25 * f


def psol(T_C, xi):
    """Solution surface (bubble) pressure [MPa] (Sec.1):
    psol = pi(xi, T) * pref_water(T). CaCl2 treated as non-volatile."""
    pi = pi_factor(xi, T_C)
    if pi is None:
        return None
    return pi * pref_water(T_C)


def bubble_T(P_MPa, xi):
    """Bubble-point temperature [degC] at P [MPa]: bisection inverse
    of psol over -40..150 degC. None if not bracketed."""
    if P_MPa is None or xi is None:
        return None
    lo, hi = -40.0, 150.0
    plo, phi = psol(lo, xi), psol(hi, xi)
    if plo is None or phi is None or not (plo <= P_MPa <= phi):
        return None
    for _ in range(80):
        mid = 0.5 * (lo + hi)
        if psol(mid, xi) < P_MPa:
            lo = mid
        else:
            hi = mid
    return 0.5 * (lo + hi)


def tdew_by_tsol_xi(T_C, xi):
    """Dew-point temperature [degC] of the solution at (T_C, xi)
    (library-wide TdewByTsolXi convention):
        Tdew = tsat_water(psol(T_C, xi)),
    the pure-water saturation temperature on this module's own
    Saul-Wagner line at the solution surface pressure.  CaCl2 is
    non-volatile, so the dew point is a pure-water reference."""
    P = psol(T_C, xi)
    if P is None:
        return None
    return tsat_water(P)


def xi_by_tsol_tdew(Tsol_C, Tdew_C):
    """CaCl2 mass fraction from solution temperature and dew point.
    The dew point fixes P = pref_water(Tdew); then solve
    psol(Tsol, xi) = P by bisection on xi in [0, 0.60] (psol
    decreases with xi, so the bisection direction is reversed).
    None if no root (e.g. Tdew too close to Tsol: pi(0) = 0.99756
    boundary residual, see module header)."""
    if Tsol_C is None or Tdew_C is None:
        return None
    if not (-40.0 <= Tsol_C <= 150.0):
        return None
    P = pref_water(Tdew_C)
    if P is None:
        return None
    pmax = psol(Tsol_C, 0.0)
    pmin = psol(Tsol_C, _XI_MAX)
    if pmax is None or pmin is None or not (pmin <= P <= pmax):
        return None
    lo, hi = 0.0, _XI_MAX
    for _ in range(80):
        mid = 0.5 * (lo + hi)
        if psol(Tsol_C, mid) > P:
            lo = mid
        else:
            hi = mid
    return 0.5 * (lo + hi)


# ----------------------------------------------------------------------
# Density (Sec.3), surface tension (Sec.4), viscosity (Sec.5),
# thermal conductivity (Sec.6), specific heat (Sec.7)
# ----------------------------------------------------------------------
def rho_sol(T_C, xi):
    """Solution density [kg/m3] (Sec.3). xi <= 0.60 (paper range),
    T in [-40, 150] degC."""
    if xi is None or T_C is None:
        return None
    if not (0.0 <= xi <= _XI_MAX and -40.0 <= T_C <= 150.0):
        return None
    rw = rho_water(T_C)
    if rw is None:
        return None
    z = xi / (1.0 - xi)
    return rw * sum(_RHO[i] * z ** i for i in range(4))


def sigma_sol(T_C, xi):
    """Solution surface tension [N/m] (Sec.4)."""
    if xi is None or T_C is None:
        return None
    if not (0.0 <= xi <= _XI_MAX and -40.0 <= T_C <= 150.0):
        return None
    sw = sigma_water(T_C)
    if sw is None:
        return None
    th = (T_C + 273.15) / _TC
    s = _SIG
    ratio = (1.0 + s[0] * xi + s[1] * xi * th + s[2] * xi * th ** 2
             + s[3] * xi ** 2 + s[4] * xi ** 3)
    return sw * ratio


def eta_sol(T_C, xi):
    """Solution dynamic viscosity [Pa s] (Sec.5):
    eta = eta_water * exp(eta1*zeta^3.6 + eta2*zeta + eta3*zeta/theta_r
    + eta4*zeta^2), zeta = xi / (1-xi)^(1/0.6). T in [0, 150] degC."""
    if xi is None or T_C is None:
        return None
    if not (0.0 <= xi <= _XI_MAX and 0.0 <= T_C <= 150.0):
        return None
    ew = eta_water(T_C)
    if ew is None:
        return None
    th = (T_C + 273.15) / _TC
    zeta = xi / (1.0 - xi) ** (1.0 / 0.6)
    e = _ETA
    return ew * math.exp(e[0] * zeta ** 3.6 + e[1] * zeta
                         + e[2] * zeta / th + e[3] * zeta ** 2)


def lambda_sol(T_C, xi):
    """Solution thermal conductivity [W/(m K)] (Sec.6, Riedel):
    lambda_sol = lambda_water - alpha_R * zeta_eq,
    zeta_eq = xi * rho_sol * I_s / M with I_s = 2 and M = 110.98
    (the paper's unit convention: rho in kg/m3, M in g/mol, so
    zeta_eq is in mol/L), alpha_R = alp0 + alp1*xi.
    T in [-20, 150] degC."""
    if xi is None or T_C is None:
        return None
    if not (0.0 <= xi <= _XI_MAX and -20.0 <= T_C <= 150.0):
        return None
    lw = lambda_water(T_C)
    rs = rho_sol(T_C, xi)
    if lw is None or rs is None:
        return None
    zeta_eq = xi * rs * _I_S / _M_CACL2
    return lw - (_ALP0 + _ALP1 * xi) * zeta_eq


def _cp_f1(xi):
    A, B, C = _TAB10[:3]
    return A * xi + B * xi ** 2 + C * xi ** 3


def _cp_f2(T_C):
    F, G, H = _TAB10[5:8]
    th = (T_C + 273.15) / 228.0 - 1.0
    return F * th ** 0.02 + G * th ** 0.04 + H * th ** 0.06


def cp_sol(T_C, xi):
    """Solution specific heat [kJ/(kg K)] (Sec.7):
    cp_sol = cp_water * (1 - f1(xi) * f2(theta_s)).
    T in [0, 150] degC, xi in [0, 0.60]."""
    if xi is None or T_C is None:
        return None
    if not (0.0 <= xi <= _XI_MAX and 0.0 <= T_C <= 150.0):
        return None
    cw = cp_water(T_C)
    if cw is None:
        return None
    return cw * (1.0 - _cp_f1(xi) * _cp_f2(T_C))


# ----------------------------------------------------------------------
# Differential dilution enthalpy (Sec.8) and solution enthalpy
# ----------------------------------------------------------------------
def dh_d(xi, T_C):
    """Differential dilution enthalpy [kJ/kg_H2O] (Sec.8, CaCl2
    branch; theta = theta_r = T_K / T_c,H2O per the paper's
    Nomenclature default and the dossier Sec.8 ruling of
    2026-11-19 -- the Sec.8 text does not redefine theta):
        dh_d = dh_d0 * [1 + (zeta/H1)^H2]^H3,
        zeta = xi / (H4 - xi),  dh_d0 = H5 + H6 * theta_r.
    Positive = heat released on absorption of 1 kg of water
    (equivalently, extra heat beyond the latent heat needed to
    desorb 1 kg of water). xi in [0, 0.60], T in [0, 150] degC."""
    if xi is None or T_C is None:
        return None
    if not (0.0 <= xi <= _XI_H_MAX and 0.0 <= T_C <= 150.0):
        return None
    H1, H2, H3, H4, H5, H6 = _HD
    th = (T_C + 273.15) / _TC
    dh0 = H5 + H6 * th
    zeta = xi / (H4 - xi)
    if xi == 0.0:
        return 0.0
    return dh0 * (1.0 + (zeta / H1) ** H2) ** H3


def hmix_excess(xi, Tref_C=25.0):
    """Excess (mixing) enthalpy per kg of solution [kJ/kg] at the
    anchor temperature Tref (default 25 degC):
        e(xi) = xi * integral_0^xi dh_d(s, Tref) / s^2 ds
    (Simpson, 400 intervals; the integrand tends to 0 as s -> 0).
    See the module header for the sign convention.
    xi in [0, 0.60]."""
    if xi is None or not (0.0 <= xi <= _XI_H_MAX):
        return None
    if xi == 0.0:
        return 0.0
    n = 400
    h = xi / n

    def g(s):
        if s <= 0.0:
            return 0.0
        return dh_d(s, Tref_C) / (s * s)

    total = g(0.0) + g(xi)
    for i in range(1, n):
        total += (4.0 if i % 2 == 1 else 2.0) * g(i * h)
    return xi * total * h / 3.0


def hsol(T_C, xi):
    """Solution specific enthalpy [kJ/kg]:
        hsol(T, xi) = integral_0^T cp_sol(T', xi) dT' + e25(xi)
    (Simpson, 200 intervals).  Datum and construction: see the
    module header.  T in [0, 150] degC, xi in [0, 0.60]."""
    if xi is None or T_C is None:
        return None
    if not (0.0 <= xi <= _XI_H_MAX and 0.0 <= T_C <= 150.0):
        return None
    e = hmix_excess(xi, 25.0)
    if e is None:
        return None
    if T_C == 0.0:
        return e
    n = 200
    h = T_C / n
    total = cp_sol(0.0, xi) + cp_sol(T_C, xi)
    for i in range(1, n):
        total += (4.0 if i % 2 == 1 else 2.0) * cp_sol(i * h, xi)
    return total * h / 3.0 + e


def tsol_by_hsol(h, xi):
    """Solution temperature [degC] from hsol h [kJ/kg] and xi:
    inverse of hsol (scan 0..150 degC in 5 degC steps, then 80
    bisection steps; hsol increases monotonically with T at fixed
    xi).  None if no bracket contains h."""
    if h is None or xi is None or not (0.0 <= xi <= _XI_H_MAX):
        return None
    prev_T, prev_h, bracket = None, None, None
    for k in range(31):
        T = 5.0 * k
        hv = hsol(T, xi)
        if hv is None:
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
        if hsol(mid, xi) < h:
            lo = mid
        else:
            hi = mid
    return 0.5 * (lo + hi)


# ----------------------------------------------------------------------
# Crystallisation / solubility boundary (Sec.2, Table 2)
# ----------------------------------------------------------------------
def sle_T(xi, branch):
    """SLE boundary temperature [degC] of one branch at xi:
    theta_r = A0 + A1*xi + A2*xi^2 + A3*xi^7.5.  branch in
    {"ice", "CaCl2.6H2O", "CaCl2.4H2Oa", "CaCl2.4H2Ob",
    "CaCl2.2H2O", "CaCl2"}.  xi in [0, 0.80]."""
    if xi is None or branch not in _SLE:
        return None
    if not (0.0 <= xi <= _XI_SLE_MAX):
        return None
    A0, A1, A2, A3 = _SLE[branch]
    return (A0 + A1 * xi + A2 * xi ** 2 + A3 * xi ** 7.5) * _TC - 273.15


def crystallization_T(xi):
    """Crystallisation temperature [degC] at xi: upper envelope
    (maximum) of the six Table 2 branch temperatures -- the stable
    solid phase at a given xi is the branch with the highest
    boundary temperature.  xi in [0, 0.80]."""
    if xi is None or not (0.0 <= xi <= _XI_SLE_MAX):
        return None
    return max(sle_T(xi, b) for b in _SLE)


if __name__ == "__main__":
    print("H2O-CaCl2 (Conde 2004): psol [MPa]")
    print("  T_C    xi=0.1   xi=0.2   xi=0.3   xi=0.4")
    for T in (25.0, 40.0, 60.0, 80.0):
        row = " ".join("%8.5f" % psol(T, xi) for xi in (0.1, 0.2, 0.3, 0.4))
        print("%6.0f  %s" % (T, row))
    print("rho_sol(20C, 0.3) = %.1f kg/m3" % rho_sol(20.0, 0.3))
    print("cp_sol(20C, 0.3)  = %.3f kJ/(kg K)" % cp_sol(20.0, 0.3))
    print("hsol(80C, 0.4)    = %.2f kJ/kg" % hsol(80.0, 0.4))

'use strict';
/*
 * r124_dmf.js -- R124 (1) - DMF (2) vapour-liquid equilibrium
 * (JavaScript set of the absorption-working-pairs library; companion
 * to r124_dmf.py / .c / .bas).
 * ==========================================================================
 * Source
 * ------
 * Xu, Wang, Wu, Hu & Jiang, "Measurement and Correlation of
 * Vapor-Liquid Equilibrium for R124-NMP and R124-DMF Mixtures",
 * J. Chem. Eng. Data 2017, 62, 3414-3422.
 * DOI 10.1021/acs.jced.7b00444
 *
 * Model (paper Eqs. 4-11): five-parameter NRTL for the activity
 * coefficient of R124, gamma-phi bubble pressure with the vapour
 * taken as pure R124 (the paper finds NMP/DMF in the vapour
 * negligible) and a Poynting correction using the saturated-liquid
 * molar volume of R124:
 *     tau12 = (a1 + b1 ln T)/(R T),   tau21 = (a2 + b2 ln T)/(R T)
 *     G12 = exp(-alpha tau12),        G21 = exp(-alpha tau21)
 *     ln g1 = x2^2 [ tau21 (G21/(x1+x2 G21))^2
 *                    + tau12 G12/(x2+x1 G12)^2 ]
 *     p = ps1 x1 g1 exp( VL1 (p - ps1)/(R T) )   (implicit, iterated)
 *
 * Pure R124 saturation pressure: Antoine fit to the REFPROP values
 * of the paper's Table 5 (max deviation 0.05 %); saturated-liquid
 * molar volume: quadratic fit to the same table (max deviation
 * 0.24 %, the Poynting factor itself is worth at most ~6 %).
 * Bubble pressure reproduces the paper's 60 measured points with
 * AARD 1.17 % (paper reports 1.17 %).
 *
 * Conventions
 * -----------
 * xi : R124 MASS fraction (repo convention); the NRTL works in
 *      mole fractions, converted internally.
 *      M(R124) = 136.50, M(DMF) = 73.09 g/mol.
 * T  : degC at the public boundary.
 * P  : MPa at the public boundary; internal native unit is bar:
 *      private *_bar helpers carry the original formulas verbatim,
 *      public functions only scale at the boundary (MPa = bar x 0.1
 *      on return, MPa x 10 on input).
 * Function names are exactly the Python set's public names; no
 * aliases are kept.  Internal arithmetic and coefficients are
 * copied verbatim from r124_dmf.py; only the domain discipline
 * below is this set's own rendering of the source-stated domains.
 * Python None is rendered as null here.
 *
 * NOT covered (no published data): mixture enthalpy, density,
 * viscosity.  The absorbent is treated as non-volatile, so the dew
 * point is the pure-R124 saturation temperature.
 *
 * Domain discipline
 * -----------------
 * Only domains stated below produce a RANGE error (an Error with
 * .code 'RANGE'); all internal calls use the raw private
 * implementations so the public checks never corrupt the Python
 * logic:
 *   pref_R124       : public T_C in [30, 90] else RANGE (designed
 *                     divergence: Python's pref has no check and
 *                     returns a value outside); internal calls
 *                     always use the raw version, so e.g.
 *                     xi_by_tsol_tdew can evaluate Tdew = 20 degC.
 *   Tsat_R124       : mirrors Python: P_MPa null or <= 0 returns
 *                     null; otherwise analytic inverse, no
 *                     temperature window.
 *   xi_to_x, x_to_xi: fraction outside [0, 1] throws RANGE.
 *   gamma1          : T_C outside [30, 90] throws RANGE (designed
 *                     divergence: Python returns None); xi outside
 *                     [0, 1] throws RANGE; xi == 0 returns null
 *                     (Python x1 <= 0 -> None); xi == 1 returns 1.0.
 *   psol            : T_C outside [30, 90] or xi outside [0, 1]
 *                     throws RANGE; xi == 0 or xi == 1 returns
 *                     null (Python: open interval (0, 1) else
 *                     None).  Poynting implicit iteration 50 steps,
 *                     convergence threshold 1e-10 bar, verbatim
 *                     from Python (gamma1 recomputed each step).
 *   bubble_T        : xi outside [0, 1] throws RANGE; xi == 0 or
 *                     xi == 1 returns null; bracket T in [30, 90]
 *                     degC, 60 bisection steps; P outside the raw
 *                     psol span returns null.
 *   xi_by_tsol_tdew : Tsol_C outside [30, 90] throws RANGE
 *                     (designed divergence: Python returns None);
 *                     otherwise mirrors Python: P = raw pref at
 *                     Tdew, P > raw pref at Tsol returns null,
 *                     80 bisection steps over xi in [0, 1],
 *                     interior points only.
 *   dew_T           : mirrors Python: result T in [-30, 90] degC
 *                     returns a value, otherwise null; P <= 0
 *                     returns null; optional second argument xi
 *                     is ignored (same signature as Python
 *                     dew_T(P_MPa, xi=None)).
 *   tdew_by_tsol_xi : propagates psol's RANGE (same T / xi public
 *                     discipline as psol); xi endpoints or a dew
 *                     window miss return null; internally follows
 *                     the raw path _dew_T_bar(_psol_bar(...)).
 */

// ---------------------------------------------------------------------------
// Coefficients (verbatim from r124_dmf.py)
// ---------------------------------------------------------------------------

// Antoine fit to Xu 2017 Table 5 (REFPROP), p in kPa, T in K
const _ANT_A = 14.750463;
const _ANT_B = 2527.6371;
const _ANT_C = -10.9815;

// R124 saturated-liquid molar volume, quadratic in T_C [m3/kmol]
const _VL = [3.43888821e-06, 5.21631071e-06, 9.89804979e-02];

// NRTL parameters (Xu 2017 Table 8), energies in J/mol
const _A1 = -52406.6, _B1 = 4671.8;
const _A2 = -88324.0, _B2 = 14735.9;
const _ALPHA = -0.5116;

const _R = 8.314;            // J/(mol K)
const _M1 = 136.50;          // R124
const _M2 = 73.09;           // DMF
const _TMIN = 30.0, _TMAX = 90.0;

function domainError(code, message) {
  const e = new Error(message);
  e.code = code;
  return e;
}

// ---------------------------------------------------------------------------
// Raw private implementations (no range checks, mirroring Python)
// ---------------------------------------------------------------------------

/** Pure R124 saturation pressure [bar], native. */
function _pref_R124_bar(T_C) {
  const T = T_C + 273.15;
  return Math.exp(_ANT_A - _ANT_B / (T + _ANT_C)) / 100.0;
}

/** Pure R124 saturation temperature [degC] at P [bar], native. */
function _Tsat_R124_bar(P_bar) {
  if (P_bar === null || P_bar === undefined || P_bar <= 0) {
    return null;
  }
  const T = _ANT_B / (_ANT_A - Math.log(P_bar * 100.0)) - _ANT_C;
  return T - 273.15;
}

/** R124 saturated-liquid molar volume [m3/mol]. */
function _VL_R124(T_C) {
  const c2 = _VL[0], c1 = _VL[1], c0 = _VL[2];
  return (c2 * T_C * T_C + c1 * T_C + c0) / 1000.0;
}

/** R124 mass fraction -> mole fraction (raw, no range check). */
function _xi_to_x_raw(xi) {
  const n1 = xi / _M1;
  return n1 / (n1 + (1.0 - xi) / _M2);
}

/** R124 mole fraction -> mass fraction (raw, no range check). */
function _x_to_xi_raw(x) {
  const m1 = x * _M1;
  return m1 / (m1 + (1.0 - x) * _M2);
}

/** Activity coefficient of R124 (NRTL), raw: mirrors the Python
 *  gamma1 body (x1 <= 0 -> null, x1 >= 1 -> 1.0); the Python
 *  temperature-window check lives in the public wrapper as RANGE. */
function _gamma1_raw(T_C, xi) {
  const T = T_C + 273.15;
  const x1 = _xi_to_x_raw(xi);
  const x2 = 1.0 - x1;
  if (x1 <= 0.0) {
    return null;
  }
  if (x1 >= 1.0) {
    return 1.0;
  }
  const lnT = Math.log(T);
  const t12 = (_A1 + _B1 * lnT) / (_R * T);
  const t21 = (_A2 + _B2 * lnT) / (_R * T);
  const G12 = Math.exp(-_ALPHA * t12);
  const G21 = Math.exp(-_ALPHA * t21);
  const lng = x2 * x2 * (t21 * Math.pow(G21 / (x1 + x2 * G21), 2)
                     + t12 * G12 / Math.pow(x2 + x1 * G12, 2));
  return Math.exp(lng);
}

/** Bubble-point pressure [bar], native; vapour = pure R124. */
function _psol_bar(T_C, xi) {
  if (!(_TMIN <= T_C && T_C <= _TMAX) || !(0.0 < xi && xi < 1.0)) {
    return null;
  }
  const T = T_C + 273.15;
  const ps1 = _pref_R124_bar(T_C);                 // bar
  const x1 = _xi_to_x_raw(xi);
  let p = ps1 * x1 * _gamma1_raw(T_C, xi);         // bar
  const vl = _VL_R124(T_C);                        // m3/mol
  for (let i = 0; i < 50; i++) {
    const pn = ps1 * x1 * _gamma1_raw(T_C, xi) * Math.exp(
      vl * (p - ps1) * 1.0e5 / (_R * T));
    if (Math.abs(pn - p) < 1e-10) {
      p = pn;
      break;
    }
    p = pn;
  }
  return p;
}

/** Bubble-point temperature [degC] at P [bar], native; null if
 *  the root is outside the validated 30-90 degC window. */
function _bubble_T_bar(P_bar, xi, iters) {
  if (iters === undefined) iters = 60;
  let lo = _TMIN, hi = _TMAX;
  const plo = _psol_bar(lo, xi), phi = _psol_bar(hi, xi);
  if (plo === null || phi === null || !(plo <= P_bar && P_bar <= phi)) {
    return null;
  }
  for (let i = 0; i < iters; i++) {
    const mid = 0.5 * (lo + hi);
    if (_psol_bar(mid, xi) < P_bar) {
      lo = mid;
    } else {
      hi = mid;
    }
  }
  return 0.5 * (lo + hi);
}

/** Dew point [degC] at P [bar], native: absorbent non-volatile
 *  -> pure R124 Tsat.  Window [-30, 90] degC, as in Python. */
function _dew_T_bar(P_bar, xi) {
  if (P_bar === null || P_bar === undefined) {
    return null;
  }
  const T = _Tsat_R124_bar(P_bar);
  return (T !== null && -30.0 <= T && T <= _TMAX) ? T : null;
}

// ---------------------------------------------------------------------------
// Public functions (MPa boundary, Python names verbatim)
// ---------------------------------------------------------------------------

/** Pure R124 saturation pressure [MPa], 30-90 degC.
 *  Public T_C outside [30, 90] throws RANGE. */
function pref_R124(T_C) {
  if (!(_TMIN <= T_C && T_C <= _TMAX)) {
    throw domainError('RANGE',
      `pref_R124: T_C=${T_C} is outside the domain T_C in [30, 90]`);
  }
  return _pref_R124_bar(T_C) * 0.1;
}

/** Pure R124 saturation temperature [degC] (= dew point here);
 *  P [MPa].  Mirrors Python: P_MPa null or <= 0 returns null,
 *  otherwise analytic inverse, no temperature window. */
function Tsat_R124(P_MPa) {
  if (P_MPa === null || P_MPa === undefined) {
    return null;
  }
  return _Tsat_R124_bar(P_MPa * 10.0);
}

/** R124 mass fraction -> mole fraction.
 *  Fraction outside [0, 1] throws RANGE. */
function xi_to_x(xi) {
  if (!(0.0 <= xi && xi <= 1.0)) {
    throw domainError('RANGE',
      `xi_to_x: xi=${xi} is outside the domain xi in [0, 1]`);
  }
  return _xi_to_x_raw(xi);
}

/** R124 mole fraction -> mass fraction.
 *  Fraction outside [0, 1] throws RANGE. */
function x_to_xi(x) {
  if (!(0.0 <= x && x <= 1.0)) {
    throw domainError('RANGE',
      `x_to_xi: x=${x} is outside the domain x in [0, 1]`);
  }
  return _x_to_xi_raw(x);
}

/** Activity coefficient of R124 (NRTL).
 *  T_C outside [30, 90] throws RANGE; xi outside [0, 1] throws
 *  RANGE; xi == 0 returns null; xi == 1 returns 1.0. */
function gamma1(T_C, xi) {
  if (!(_TMIN <= T_C && T_C <= _TMAX)) {
    throw domainError('RANGE',
      `gamma1: T_C=${T_C} is outside the domain T_C in [30, 90]`);
  }
  if (!(0.0 <= xi && xi <= 1.0)) {
    throw domainError('RANGE',
      `gamma1: xi=${xi} is outside the domain xi in [0, 1]`);
  }
  return _gamma1_raw(T_C, xi);
}

/** Bubble-point pressure [MPa]; vapour = pure R124.
 *  T_C outside [30, 90] or xi outside [0, 1] throws RANGE;
 *  xi == 0 or xi == 1 returns null. */
function psol(T_C, xi) {
  if (!(_TMIN <= T_C && T_C <= _TMAX)) {
    throw domainError('RANGE',
      `psol: T_C=${T_C} is outside the domain T_C in [30, 90]`);
  }
  if (!(0.0 <= xi && xi <= 1.0)) {
    throw domainError('RANGE',
      `psol: xi=${xi} is outside the domain xi in [0, 1]`);
  }
  const p = _psol_bar(T_C, xi);
  return p === null ? null : p * 0.1;
}

/** Bubble-point temperature [degC] at P [MPa]; null if the root
 *  is outside the validated 30-90 degC window.
 *  xi outside [0, 1] throws RANGE; xi == 0 or xi == 1 returns
 *  null; P_MPa null returns null. */
function bubble_T(P_MPa, xi, iters) {
  if (iters === undefined) iters = 60;
  if (!(0.0 <= xi && xi <= 1.0)) {
    throw domainError('RANGE',
      `bubble_T: xi=${xi} is outside the domain xi in [0, 1]`);
  }
  if (P_MPa === null || P_MPa === undefined) {
    return null;
  }
  return _bubble_T_bar(P_MPa * 10.0, xi, iters);
}

/** Concentration from dew-point temperature and solution
 *  temperature.  NOTE the argument order: (Tsol_C, Tdew_C).
 *  The dew point fixes the pressure, P = raw pref at Tdew in
 *  native bar (DMF treated as non-volatile); then solve
 *  raw psol(Tsol, xi) = P by bisection (80 steps, bracket xi in
 *  [0, 1], interior points only).  Tsol_C outside [30, 90]
 *  throws RANGE; no root (e.g. P > raw pref at Tsol) returns
 *  null. */
function xi_by_tsol_tdew(Tsol_C, Tdew_C) {
  if (!(_TMIN <= Tsol_C && Tsol_C <= _TMAX)) {
    throw domainError('RANGE',
      `xi_by_tsol_tdew: Tsol_C=${Tsol_C} is outside the domain ` +
      'Tsol_C in [30, 90]');
  }
  const P = _pref_R124_bar(Tdew_C);
  if (!(P <= _pref_R124_bar(Tsol_C))) {
    return null;
  }
  let lo = 0.0, hi = 1.0;
  for (let i = 0; i < 80; i++) {
    const mid = 0.5 * (lo + hi);
    if (_psol_bar(Tsol_C, mid) < P) {
      lo = mid;
    } else {
      hi = mid;
    }
  }
  return 0.5 * (lo + hi);
}

/** Dew point [degC] at P [MPa]: absorbent non-volatile -> pure
 *  R124 Tsat.  Mirrors Python: P_MPa null returns null, result
 *  outside [-30, 90] degC returns null.  Optional second
 *  argument xi is ignored, as in Python. */
function dew_T(P_MPa, xi) {
  if (xi === undefined) xi = null;
  if (P_MPa === null || P_MPa === undefined) {
    return null;
  }
  return _dew_T_bar(P_MPa * 10.0, xi);
}

/** Dew-point temperature [degC] of the solution at (T_C, xi)
 *  (library-wide TdewByTsolXi convention):
 *      Tdew = dew_T(psol(T_C, xi)) at the public boundary,
 *  evaluated internally in native bar as
 *  _dew_T_bar(_psol_bar(T_C, xi)).  Absorbent treated as
 *  non-volatile.  Propagates psol's RANGE; null where the raw
 *  psol or the dew window gives no value. */
function tdew_by_tsol_xi(T_C, xi) {
  if (!(_TMIN <= T_C && T_C <= _TMAX)) {
    throw domainError('RANGE',
      `tdew_by_tsol_xi: T_C=${T_C} is outside the domain ` +
      'T_C in [30, 90]');
  }
  if (!(0.0 <= xi && xi <= 1.0)) {
    throw domainError('RANGE',
      `tdew_by_tsol_xi: xi=${xi} is outside the domain xi in [0, 1]`);
  }
  return _dew_T_bar(_psol_bar(T_C, xi));
}

module.exports = {
  pref_R124, Tsat_R124, xi_to_x, x_to_xi, gamma1, psol, bubble_T,
  xi_by_tsol_tdew, dew_T, tdew_by_tsol_xi,
};

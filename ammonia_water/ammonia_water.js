'use strict';
/*
 * ammonia_water.js -- NH3-H2O (ammonia-water) mixture properties
 * (JavaScript set of the absorption-working-pairs library; companion to
 * ammonia_water.py / .c / .bas).  Main module only: the Patek & Klomfar
 * correlations and their inverses/composites.  (Transport properties
 * live in the separate ammonia_water_transport module and are NOT
 * ported here.)
 * ==========================================================================
 * Source
 * ------
 * Patek, J. & Klomfar, J. (1995), "Simple functions for fast
 * calculations of selected thermodynamic properties of the
 * ammonia-water system", Int. J. Refrigeration 18(4), pp. 228-234:
 * five explicit (non-iterative) equations, Eqs (6)-(10), plus the
 * inverses/composites built on them in the Python set.
 *
 *     Eq (6):  T(p,x) bubble-point temperature,
 *              T0 = 100 K, p0 = 2 MPa; fitted range 0.002 <= p <= 2 MPa,
 *              full x range; 95 % of fitted points within 1.5 K.
 *     Eq (7):  T(p,y) dew-point temperature,
 *              T0 = 100 K, p0 = 2 MPa; fitted range 0.02 <= p <= 2 MPa;
 *              95 % of fitted points within +/-2 K.
 *     Eq (8):  y(p,x) equilibrium vapour mole fraction,
 *              p0 = 2 MPa; valid for liquid mole fraction x > 0.05 and
 *              p > 0.05 MPa.
 *     Eq (9):  h_l(T,x) saturated-liquid enthalpy,
 *              h0 = 100 kJ/kg, T0 = 273.16 K; RMS 0.9 kJ/kg vs the
 *              Zinner data (the paper states no T range for this fit).
 *     Eq (10): h_g(T,y) vapour enthalpy (ideal-mixture fit),
 *              h0 = 1000 kJ/kg, T0 = 324 K; < 1 % vs Scatchard /
 *              Ziegler-Trepp (the paper states no T range for this fit).
 *
 * Conventions
 * -----------
 * x : ammonia MOLE fraction in the liquid phase (the paper's X).
 * y : ammonia MOLE fraction in the gas phase (the paper's Y).
 * T : temperature in K.
 * p : pressure in MPa.  Pressure is NATIVELY in MPa in this pair
 *     (p0 = 2 MPa in the fits themselves), so -- unlike pairs whose
 *     fits are in Pa/bar -- no rescaling is applied anywhere.
 * h : specific enthalpy in kJ/kg.
 * Function names are exactly the Python set's public names; no
 * aliases are kept.  Internal arithmetic and coefficients are copied
 * verbatim from ammonia_water.py; only the domain discipline and the
 * no-root convention below are the JavaScript set's own (as in the
 * LiBr-H2O JavaScript set).
 *
 * Reference state (the paper): zero enthalpy for BOTH components =
 * liquid water at the triple point.  So hsol(273.16 K, x = 0) = 0 by
 * construction, and hgas shares the same reference state.
 *
 * Domain discipline
 * -----------------
 * A point outside a function's fitted range throws an Error with
 * .code 'RANGE'; nothing is silently extrapolated:
 *   T_bubble_PX : p in [0.002, 2] MPa, x in [0, 1]
 *   T_dew_PY    : p in [0.02, 2] MPa, y in [0, 1]
 *   y_equil     : x in (0.05, 1], p in (0.05, 2] MPa (Eq 8 validity;
 *                 x = 1 returns 1, the Python set's early return)
 *   hsol        : x in [0, 1] (no T range is stated -- none is imposed)
 *   hgas        : y in [0, 1] (no T range is stated -- none is imposed)
 *   glide_pX    : p in [0.02, 2] MPa (intersection of the Eq 6 / Eq 7
 *                 ranges), z in [0, 1]
 *   mole_to_mass / mass_to_mole : fraction in [0, 1]
 * Composite functions (bubble_state_pX, consistency_residual_pX)
 * propagate the domain errors of the functions they call.
 *
 * Inverses and the no-root convention
 * -----------------------------------
 * psol_TX / p_dew_TY return null when T lies outside the achievable
 * temperature span of the forward equation over its fitted pressure
 * range (p in [0.002, 2] MPa for Eq 6, p in [0.02, 2] MPa for Eq 7).
 * (The Python set's bisection silently converges to an endpoint in
 * that case; null is this set's no-root convention, as in the
 * LiBr-H2O JavaScript set.)  When a root exists, the bisection
 * mirrors the Python set exactly (200 iterations, tol = 1e-9).
 * x_by_tsol_tdew follows the Python set's own construction and None
 * logic (see its note below); tsol_by_hsol bisects hsol on the
 * bracket T in [240, 480] K (100 iterations) and returns null when h
 * lies outside the hsol span at x.  tdew_from_tsol_x propagates the
 * psol_TX null (no bubble pressure, no dew temperature).
 *
 * TWO-ACCOUNTS DEW-POINT WARNING
 * ------------------------------
 * tdew_from_tsol_x is the library-wide TdewByTsolXi convention: the
 * dew-point temperature of the solution at (T, x) is taken as the
 * PURE-NH3 saturation temperature -- the x = 1 endpoint of Eq (6) --
 * evaluated at the solution surface (bubble) pressure psol_TX(T, x).
 * It is NOT the true mixture dew point T_dew_PY (Eq 7): for this pair
 * the absorbent (water) IS volatile, so the two are different
 * functions and must not be interchanged.  glide_pX uses the TRUE
 * dew point: glide = T_dew(p, z) - T_bubble(p, z) at fixed overall
 * composition z (both components volatile -- a genuine mixture
 * glide, unlike the DMF/DEGDME pairs whose dew curve was approximated
 * by the pure-refrigerant saturation temperature).
 */

// ---------------------------------------------------------------------------
// Coefficient tables: [m_i, n_i, a_i] (verbatim from ammonia_water.py)
// ---------------------------------------------------------------------------

// Eq (6) T(p,x); T0 = 100 K, p0 = 2 MPa
const C6 = [
  [0, 0, +3.22302],
  [0, 1, -0.384206],
  [0, 2, +0.0460965],
  [0, 3, -0.00378945],
  [0, 4, +0.000135610],
  [1, 0, +0.487755],
  [1, 1, -0.120108],
  [1, 2, +0.0106154],
  [2, 3, -0.000533589],
  [4, 0, +7.85041],
  [5, 0, -11.5941],
  [5, 1, -0.0523150],
  [6, 0, +4.89596],
  [13, 1, +0.0421059],
];

// Eq (7) T(p,y); T0 = 100 K, p0 = 2 MPa
const C7 = [
  [0, 0, +3.24004],
  [0, 1, -0.395920],
  [0, 2, +0.0435624],
  [0, 3, -0.00218943],
  [1, 0, -1.43526],
  [1, 1, +1.05256],
  [1, 2, -0.0719281],
  [2, 0, +12.2362],
  [2, 1, -2.24368],
  [3, 0, -20.1780],
  [3, 1, +1.10834],
  [4, 0, +14.5399],
  [4, 2, +0.644312],
  [5, 0, -2.21246],
  [5, 2, -0.756266],
  [6, 0, -1.35529],
  [7, 2, +0.183541],
];

// Eq (8) y(p,x); p0 = 2 MPa
const C8 = [
  [0, 0, +19.8022017],
  [0, 1, -11.8092669],
  [0, 6, +27.7479980],
  [0, 7, -28.8634277],
  [1, 0, -59.1616608],
  [2, 1, +578.091305],
  [2, 2, -6.21736743],
  [3, 2, -3421.98402],
  [4, 3, +11940.3127],
  [5, 4, -24541.3777],
  [6, 5, +29159.1865],
  [7, 6, -18478.2290],
  [7, 7, +23.4819434],
  [8, 7, +4803.10617],
];

// Eq (9) h_l(T,x); h0 = 100 kJ/kg, T0 = 273.16 K
const C9 = [
  [0, 1, -7.61080],
  [0, 4, +25.6905],
  [0, 8, -247.092],
  [0, 9, +325.952],
  [0, 12, -158.854],
  [0, 14, +61.9084],
  [1, 0, +11.4314],
  [1, 1, +1.18157],
  [2, 1, +2.84179],
  [3, 3, +7.41609],
  [5, 3, +891.844],
  [5, 4, -1613.09],
  [5, 5, +622.106],
  [6, 2, -207.588],
  [6, 4, -6.87393],
  [8, 0, +3.50716],
];

// Eq (10) h_g(T,y); h0 = 1000 kJ/kg, T0 = 324 K
const C10 = [
  [0, 0, +1.28827],
  [1, 0, +0.125247],
  [2, 0, -2.08748],
  [3, 0, +2.17696],
  [0, 2, +2.35687],
  [1, 2, -8.86987],
  [2, 2, +10.2635],
  [3, 2, -2.37440],
  [0, 3, -6.70515],
  [1, 3, +16.4508],
  [2, 3, -9.36849],
  [0, 4, +8.42254],
  [1, 4, -8.58807],
  [0, 5, -2.77049],
  [4, 6, -0.961248],
  [2, 7, +0.988009],
  [1, 10, +0.308482],
];

const T0_67 = 100.0;    // K,   Eqs (6),(7)
const P0 = 2.0;         // MPa, Eqs (6),(7),(8)
const H0_9 = 100.0;     // kJ/kg, Eq (9)
const T0_9 = 273.16;    // K,     Eq (9)
const H0_10 = 1000.0;   // kJ/kg, Eq (10)
const T0_10 = 324.0;    // K,     Eq (10)

const M_NH3 = 17.03052; // g/mol (IUPAC; the paper does not print values,
const M_H2O = 18.01528; // only needed for mole<->mass conversion)

function domainError(code, message) {
  const e = new Error(message);
  e.code = code;
  return e;
}

// ---------------------------------------------------------------------------
// Core equations
// ---------------------------------------------------------------------------

/** Eq (6): bubble-point temperature [K] at pressure p [MPa],
 *  liquid NH3 mole fraction x.  Range: p in [0.002, 2] MPa, x in [0, 1]. */
function T_bubble_PX(p_MPa, x) {
  if (!(0.002 <= p_MPa && p_MPa <= 2.0 && 0.0 <= x && x <= 1.0)) {
    throw domainError('RANGE',
      `T_bubble_PX: (p=${p_MPa} MPa, x=${x}) is outside the fitted range ` +
      'p in [0.002, 2] MPa, x in [0, 1]');
  }
  const L = Math.log(P0 / p_MPa);
  const omx = 1.0 - x;
  let s = 0.0;
  for (const [m, n, a] of C6) {
    s += a * Math.pow(omx, m) * Math.pow(L, n);
  }
  return T0_67 * s;
}

/** Eq (7): dew-point temperature [K] at pressure p [MPa],
 *  vapour NH3 mole fraction y.  Range: p in [0.02, 2] MPa, y in [0, 1]. */
function T_dew_PY(p_MPa, y) {
  if (!(0.02 <= p_MPa && p_MPa <= 2.0 && 0.0 <= y && y <= 1.0)) {
    throw domainError('RANGE',
      `T_dew_PY: (p=${p_MPa} MPa, y=${y}) is outside the fitted range ` +
      'p in [0.02, 2] MPa, y in [0, 1]');
  }
  const L = Math.log(P0 / p_MPa);
  const omy = Math.max(0.0, 1.0 - y);
  let s = 0.0;
  for (const [m, n, a] of C7) {
    s += a * Math.pow(omy, m / 4.0) * Math.pow(L, n);
  }
  return T0_67 * s;
}

/** Eq (8): equilibrium vapour NH3 mole fraction at pressure p [MPa]
 *  and liquid NH3 mole fraction x.
 *  Range (paper validity): x in (0.05, 1], p in (0.05, 2] MPa. */
function y_equil(p_MPa, x) {
  if (!(0.05 < x && x <= 1.0 && 0.05 < p_MPa && p_MPa <= 2.0)) {
    throw domainError('RANGE',
      `y_equil: (p=${p_MPa} MPa, x=${x}) is outside the Eq (8) validity ` +
      'range x in (0.05, 1], p in (0.05, 2] MPa');
  }
  if (x >= 1.0) {
    return 1.0;
  }
  const pr = p_MPa / P0;
  let s = 0.0;
  for (const [m, n, a] of C8) {
    s += a * Math.pow(pr, m) * Math.pow(x, n / 3.0);
  }
  return 1.0 - Math.exp(Math.log(1.0 - x) * s);
}

/** Eq (9): saturated-liquid specific enthalpy [kJ/kg].
 *  Reference: h = 0 for liquid water at the triple point.
 *  Domain: x in [0, 1] (the paper states no T range; none is imposed). */
function hsol(T_K, x) {
  if (!(0.0 <= x && x <= 1.0)) {
    throw domainError('RANGE',
      `hsol: x=${x} is outside the domain x in [0, 1]`);
  }
  const u = T_K / T0_9 - 1.0;
  let s = 0.0;
  for (const [m, n, a] of C9) {
    s += a * Math.pow(u, m) * Math.pow(x, n);
  }
  return H0_9 * s;
}

/** Eq (10): vapour specific enthalpy [kJ/kg] (ideal-mixture fit).
 *  Same reference state as hsol.
 *  Domain: y in [0, 1] (the paper states no T range; none is imposed). */
function hgas(T_K, y) {
  if (!(0.0 <= y && y <= 1.0)) {
    throw domainError('RANGE',
      `hgas: y=${y} is outside the domain y in [0, 1]`);
  }
  const v = 1.0 - T0_10 / T_K;
  const omy = Math.max(0.0, 1.0 - y);
  let s = 0.0;
  for (const [m, n, a] of C10) {
    s += a * Math.pow(v, m) * Math.pow(omy, n / 4.0);
  }
  return H0_10 * s;
}

// ---------------------------------------------------------------------------
// Convenience / composite functions
// ---------------------------------------------------------------------------

/** NH3 mole fraction -> NH3 mass fraction.  Domain: x in [0, 1]. */
function mole_to_mass(x) {
  if (!(0.0 <= x && x <= 1.0)) {
    throw domainError('RANGE',
      `mole_to_mass: x=${x} is outside the domain [0, 1]`);
  }
  return x * M_NH3 / (x * M_NH3 + (1.0 - x) * M_H2O);
}

/** NH3 mass fraction -> NH3 mole fraction.  Domain: xi in [0, 1]. */
function mass_to_mole(xi) {
  if (!(0.0 <= xi && xi <= 1.0)) {
    throw domainError('RANGE',
      `mass_to_mole: xi=${xi} is outside the domain [0, 1]`);
  }
  return (xi / M_NH3) / (xi / M_NH3 + (1.0 - xi) / M_H2O);
}

/** Full bubble state at (p, x): returns an object with
 *  T_bubble [K], y [vapour mole fraction], T_dew_of_y [K],
 *  h_l [kJ/kg], h_g [kJ/kg] = h_g(T_bubble, y).
 *  Domain errors of the constituent functions propagate. */
function bubble_state_pX(p_MPa, x) {
  const Tb = T_bubble_PX(p_MPa, x);
  const y = y_equil(p_MPa, x);
  return {
    T_bubble: Tb,
    y: y,
    T_dew_of_y: T_dew_PY(p_MPa, y),
    h_l: hsol(Tb, x),
    h_g: hgas(Tb, y),
  };
}

/** True temperature glide [K] at pressure p [MPa] and overall NH3
 *  mole fraction z:  glide = T_dew(p, y=z) - T_bubble(p, x=z).
 *  Computed directly from Eqs (6)/(7) (not via bubble_state_pX, whose
 *  y_equil step has the narrower Eq (8) validity range).
 *  Range: p in [0.02, 2] MPa, z in [0, 1]. */
function glide_pX(p_MPa, z) {
  if (!(0.02 <= p_MPa && p_MPa <= 2.0 && 0.0 <= z && z <= 1.0)) {
    throw domainError('RANGE',
      `glide_pX: (p=${p_MPa} MPa, z=${z}) is outside the range ` +
      'p in [0.02, 2] MPa, z in [0, 1]');
  }
  return T_dew_PY(p_MPa, z) - T_bubble_PX(p_MPa, z);
}

/** Self-consistency residual [K] = T_bubble(p,x) - T_dew(p, y(p,x)).
 *  Domain errors of the constituent functions propagate. */
function consistency_residual_pX(p_MPa, x) {
  const st = bubble_state_pX(p_MPa, x);
  return st.T_bubble - st.T_dew_of_y;
}

// ---------------------------------------------------------------------------
// Inverse functions (bisection on the forward equations)
// ---------------------------------------------------------------------------

function psolRaw(T_K, x) {
  // The Python set's psol_TX bisection, verbatim (200 iterations,
  // tol = 1e-9): always returns a number, silently converging to an
  // endpoint when T is outside the achievable span.  Private: the
  // public psol_TX layers the null no-root convention on top, and
  // x_by_tsol_tdew -- whose None logic is defined by the Python set
  // in terms of this solver -- uses this raw form internally.
  let pLo = 0.002, pHi = 2.0;
  let flo = T_bubble_PX(pLo, x) - T_K;
  for (let i = 0; i < 200; i++) {
    const pm = 0.5 * (pLo + pHi);
    const fm = T_bubble_PX(pm, x) - T_K;
    if (fm === 0.0 || (pHi - pLo) < 1e-9 * Math.max(1.0, pm)) {
      return pm;
    }
    // Sign-tracking bisection, line-mirrored from the Python set.
    if ((fm > 0.0) === (flo > 0.0)) {
      pLo = pm; flo = fm;
    } else {
      pHi = pm;
    }
  }
  return 0.5 * (pLo + pHi);
}

/** Bubble pressure [MPa] at temperature T [K] and liquid NH3 mole
 *  fraction x -- numerical inverse of Eq (6).  T_bubble(p, x) is
 *  monotonic in p, so the sign-tracking bisection is safe.
 *  Returns null when T is outside the achievable T_bubble span over
 *  p in [0.002, 2] MPa at x.  Domain: x in [0, 1] (else RANGE). */
function psol_TX(T_K, x) {
  if (!(0.0 <= x && x <= 1.0)) {
    throw domainError('RANGE',
      `psol_TX: x=${x} is outside the domain x in [0, 1]`);
  }
  const tMin = T_bubble_PX(0.002, x);  // T increases as p increases
  const tMax = T_bubble_PX(2.0, x);
  if (!(tMin <= T_K && T_K <= tMax)) return null;
  return psolRaw(T_K, x);
}

function pDewRaw(T_K, y) {
  // The Python set's p_dew_TY bisection, verbatim (200 iterations,
  // tol = 1e-9); private raw form, see psolRaw.
  let pLo = 0.02, pHi = 2.0;
  let flo = T_dew_PY(pLo, y) - T_K;
  for (let i = 0; i < 200; i++) {
    const pm = 0.5 * (pLo + pHi);
    const fm = T_dew_PY(pm, y) - T_K;
    if (fm === 0.0 || (pHi - pLo) < 1e-9 * Math.max(1.0, pm)) {
      return pm;
    }
    if ((fm > 0.0) === (flo > 0.0)) {
      pLo = pm; flo = fm;
    } else {
      pHi = pm;
    }
  }
  return 0.5 * (pLo + pHi);
}

/** Dew pressure [MPa] at temperature T [K] and vapour NH3 mole
 *  fraction y -- numerical inverse of Eq (7).
 *  Returns null when T is outside the achievable T_dew span over
 *  p in [0.02, 2] MPa at y.  Domain: y in [0, 1] (else RANGE). */
function p_dew_TY(T_K, y) {
  if (!(0.0 <= y && y <= 1.0)) {
    throw domainError('RANGE',
      `p_dew_TY: y=${y} is outside the domain y in [0, 1]`);
  }
  const tMin = T_dew_PY(0.02, y);  // T increases as p increases
  const tMax = T_dew_PY(2.0, y);
  if (!(tMin <= T_K && T_K <= tMax)) return null;
  return pDewRaw(T_K, y);
}

/** NH3 mole fraction x from a dew-point temperature [K] and a
 *  solution temperature [K] -- bisection inverse of psol_TX.
 *
 *  Construction (pure-NH3 endpoint, as in the Python set): the dew
 *  point fixes the pressure through the PURE ammonia saturation
 *  pressure at Tdew,  P = psol(Tdew_K, x=1),  i.e. the x = 1 endpoint
 *  of Eq (6); then solve psol(Tsol_K, x) = P for x by 80 bisection
 *  steps over x in [0, 1].  Returns null if there is no root (P
 *  outside the bubble-pressure span at Tsol_K, e.g. Tsol_K well below
 *  Tdew_K).
 *
 *  NOTE / approximation: ammonia-water vapour in reality contains
 *  water (equilibrium y < 1 for x < 1), so this is NOT the true
 *  mixture dew curve of Eq (7).  It treats the given dew-point
 *  temperature as a pure-NH3 saturation temperature -- the same
 *  x = 1 endpoint convention used in the dual-adiabatic-chamber
 *  scans. */
function x_by_tsol_tdew(Tsol_K, Tdew_K) {
  const P = psolRaw(Tdew_K, 1.0);
  const Plo = psolRaw(Tsol_K, 0.0);
  const Phi = psolRaw(Tsol_K, 1.0);
  if (!(Plo <= P && P <= Phi)) {
    return null;
  }
  let lo = 0.0, hi = 1.0;
  for (let i = 0; i < 80; i++) {
    const mid = 0.5 * (lo + hi);
    if (psolRaw(Tsol_K, mid) < P) {
      lo = mid;
    } else {
      hi = mid;
    }
  }
  return 0.5 * (lo + hi);
}

/** Dew-point temperature [K] of the solution at (T_K, x), under the
 *  library-wide TdewByTsolXi convention (pure-refrigerant endpoint):
 *
 *      Tdew = T_bubble_PX(psol_TX(T_K, x), x=1),
 *
 *  i.e. the pure-ammonia saturation temperature on this module's own
 *  pure line (the x = 1 endpoint of Eq (6)) evaluated at the solution
 *  surface (bubble) pressure Psol.  Returns null when psol_TX has no
 *  root at (T_K, x).
 *
 *  CAUTION: the absorbent (water) IS volatile for this pair, so this
 *  is NOT the true mixture dew point T_dew_PY(p, z) of Eq (7) that
 *  the glide figures use; the two are different functions and must
 *  not be interchanged. */
function tdew_from_tsol_x(T_K, x) {
  const P = psol_TX(T_K, x);
  if (P === null) return null;
  return T_bubble_PX(P, 1.0);
}

/** Solution temperature [K] from specific enthalpy h [kJ/kg] and
 *  NH3 mole fraction x: bisection inverse of hsol (Eq 9), which
 *  increases monotonically with T at fixed x.  Solver bracket
 *  T in [240, 480] K (100 iterations, as in the Python set).
 *  Returns null if h lies outside the hsol span at x.
 *  Domain errors of hsol (x outside [0, 1]) propagate. */
function tsol_by_hsol(h, x) {
  let lo = 240.0, hi = 480.0;
  const hlo = hsol(lo, x);
  const hhi = hsol(hi, x);
  if (!(hlo <= h && h <= hhi)) {
    return null;
  }
  for (let i = 0; i < 100; i++) {
    const mid = 0.5 * (lo + hi);
    if (hsol(mid, x) < h) {
      lo = mid;
    } else {
      hi = mid;
    }
  }
  return 0.5 * (lo + hi);
}

module.exports = {
  T_bubble_PX, T_dew_PY, y_equil, hsol, hgas,
  psol_TX, p_dew_TY, x_by_tsol_tdew, tdew_from_tsol_x, tsol_by_hsol,
  glide_pX, bubble_state_pX, consistency_residual_pX,
  mole_to_mass, mass_to_mole,
};

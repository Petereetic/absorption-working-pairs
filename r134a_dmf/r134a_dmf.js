'use strict';
/*
 * r134a_dmf.js -- R134a (1) + DMF (2) solution VLE and enthalpy
 * (JavaScript set of the absorption-working-pairs library; companion to
 * r134a_dmf.py / .c / .bas).
 * ==========================================================================
 * Source
 * ------
 * Zehioua et al., J. Chem. Eng. Data 2009, DOI 10.1021/je900440t,
 * Table 5, 58 points, 303.30-353.24 K.
 *
 * Model: NRTL activity coefficients (DG12 = 868.1, DG21 = -929.1 J/mol,
 * alpha = 0.3, re-fitted in the gamma-phi framework -- NOT the paper's
 * PR+MHV1 parameters (2250, -2650) J/mol) + gamma-phi bubble model
 * with Poynting correction.
 *
 * Fit: AARD 1.49% on the training set only (Zehioua Table 5).
 * Honest cross-laboratory uncertainty is approximately 8% at 300 K
 * and approximately 20% at 360 K (Cui 2007 / Han 2011 / Feng 2016
 * merge study).
 *
 * Conventions
 * -----------
 * x1 : R134a liquid MOLE fraction.
 * T  : temperature in K.
 * p  : pressure in MPa.  Pressure is NATIVELY in MPa in this pair,
 *      so no rescaling is applied anywhere.
 * h  : specific enthalpy in kJ/kg.
 * Function names are exactly the Python set's public names; no
 * aliases are kept.  Internal arithmetic and coefficients are copied
 * verbatim from r134a_dmf.py; only the domain discipline and the
 * no-root (null) convention below are the JavaScript set's own.
 *
 * Reference state: saturated liquid enthalpy at 273.15 K = 100 kJ/kg
 * for BOTH components (R134a and DMF).
 *
 * DMF is treated as non-volatile for the dew / xi constructions
 * (the model gives vapour y1 > 0.99).
 *
 * Domain discipline
 * -----------------
 * A point outside a function's stated range throws an Error with
 * .code 'RANGE'; nothing is silently extrapolated:
 *   pref_r134a      : 298 <= T <= 353
 *   psat_dmf        : 303 <= T <= 363
 *   vl_r134a, vl_dmf: no range
 *   nrtl_gamma      : 0 <= x1 <= 1
 *   nrtl_hE         : 0 <= x1 <= 1
 *   psol            : 303.30 <= T <= 353.24, 0 <= x1 <= 1
 *   bubble_T        : 0 <= x1 <= 1 (else RANGE); p_MPa outside the
 *                     achievable psol span at x1 over T in
 *                     [303.30, 353.24] returns null (no-root
 *                     convention, as in the ammonia inverses)
 *   xi_by_tsol_tdew : 303.30 <= Tsol <= 353.24 (Tdew itself gets NO
 *                     range check; see the function note)
 *   hliq_r134a      : 233 <= T <= 353
 *   h_dmf_L         : no T range imposed (none stated for
 *                     He et al. 2009 Eq (5))
 *   x_to_w, w_to_x  : fraction in [0, 1]
 *   hsol            : 233 <= T <= 353, 0 <= x1 <= 1 (the public
 *                     composite enforces the hliq component range;
 *                     tsol_by_hsol uses the raw hsol internally
 *                     because its bracket reaches 360 K)
 *   tdew_by_tsol_xi : propagates psol's RANGE
 *   tsol_by_hsol    : 0 <= x1 <= 1
 *
 * Inverses and the no-root convention
 * -----------------------------------
 * bubble_T, xi_by_tsol_tdew and tsol_by_hsol return null when
 * there is no root, mirroring the Python set's None (for bubble_T,
 * the no-root case is p_MPa outside the achievable psol span).
 * One designed divergence from Python: xi_by_tsol_tdew with Tsol
 * outside the psol T range (e.g. Tsol = 300 K, where Python
 * returns None) throws RANGE here, because Tsol walks the psol
 * jurisdiction -- the same pattern as the ammonia set.
 *
 * Raw internals
 * -------------
 * The Python set has no range checks, and several of its
 * constructions evaluate functions outside the public ranges above
 * (e.g. xi_by_tsol_tdew evaluates pref_r134a at Tdew values well
 * below 298 K, such as the documented anchor Tdew = 276.62 K).
 * This file therefore structures each range-checked function as a
 * raw private implementation plus a public wrapper that enforces
 * the range, and all internal calls inside xi_by_tsol_tdew,
 * bubble_T, tdew_by_tsol_xi's helpers, hsol and tsol_by_hsol use
 * the raw private versions so the public range checks do not
 * corrupt the Python logic.
 */

const R = 8.314462618;          // J/(mol*K)
const M1 = 102.03;              // R134a molar mass, g/mol
const M2 = 73.09;               // DMF molar mass, g/mol

// ---- NRTL parameters (fitted values, alpha = 0.3) ----
const DG12 = 868.1;             // J/mol, (g12 - g22)
const DG21 = -929.1;            // J/mol, (g21 - g11)
const ALPHA = 0.3;

function domainError(code, message) {
  const e = new Error(message);
  e.code = code;
  return e;
}

// ---------------------------------------------------------------------------
// Raw private implementations (no range checks, mirroring Python)
// ---------------------------------------------------------------------------

function prefRaw(T) {
  return Math.exp(7.89191 - 2310.84 / (T - 19.79));
}

function psatDmfRaw(T) {
  return (Math.pow(10, (3.93068 - 1337.716 / (T - 82.648)))) * 0.1;
}

function nrtlGammaRaw(T, x1) {
  const x2 = 1.0 - x1;
  const t12 = DG12 / (R * T);
  const t21 = DG21 / (R * T);
  const G12 = Math.exp(-ALPHA * t12);
  const G21 = Math.exp(-ALPHA * t21);
  const D1 = x1 + x2 * G21;
  const D2 = x2 + x1 * G12;
  const ln_g1 = x2 ** 2 * (t21 * (G21 / D1) ** 2 + t12 * G12 / D2 ** 2);
  const ln_g2 = x1 ** 2 * (t12 * (G12 / D2) ** 2 + t21 * G21 / D1 ** 2);
  return { gamma1: Math.exp(ln_g1), gamma2: Math.exp(ln_g2) };
}

function nrtlHERaw(T, x1) {
  const x2 = 1.0 - x1;
  const t12 = DG12 / (R * T);
  const t21 = DG21 / (R * T);
  const G12 = Math.exp(-ALPHA * t12);
  const G21 = Math.exp(-ALPHA * t21);
  const D1 = x1 + x2 * G21;
  const D2 = x2 + x1 * G12;
  const term1 = (t21 * G21 / D1) * (-1 + ALPHA * t21 * x1 / D1);
  const term2 = (t12 * G12 / D2) * (-1 + ALPHA * t12 * x2 / D2);
  return -R * T * x1 * x2 * (term1 + term2);
}

function psolRaw(T, x1) {
  const x2 = 1.0 - x1;
  const { gamma1: g1, gamma2: g2 } = nrtlGammaRaw(T, x1);
  const p1s = prefRaw(T);
  const p2s = psatDmfRaw(T);
  const V1 = vl_r134a(T);
  const V2 = vl_dmf(T);
  let p = x1 * g1 * p1s + x2 * g2 * p2s;
  for (let i = 0; i < 40; i++) {
    const Poy1 = Math.exp(V1 * (p - p1s) * 1e6 / (R * T));
    const Poy2 = Math.exp(V2 * (p - p2s) * 1e6 / (R * T));
    p = x1 * g1 * p1s * Poy1 + x2 * g2 * p2s * Poy2;
  }
  const y1 = x1 * g1 * p1s * Math.exp(V1 * (p - p1s) * 1e6 / (R * T)) / p;
  return { p_MPa: p, y1: y1 };
}

function hliqRaw(T) {
  const t = T - 273.15;
  return 1.310235e-5 * t ** 3 + 1.34329e-3 * t ** 2 + 1.334242 * t + 100.0;
}

function hDmfLRaw(T) {
  return -297.61 + 0.89544 * T + 0.0020551 * T * T;
}

function hsolRaw(T, x1) {
  const x2 = 1.0 - x1;
  const Mbar = x1 * M1 + x2 * M2;          // g/mol
  const w1 = x1 * M1 / Mbar;
  const w2 = x2 * M2 / Mbar;
  const hE = nrtlHERaw(T, x1);             // J/mol
  return w1 * hliqRaw(T) + w2 * hDmfLRaw(T) + hE / Mbar;
}

/** R134a saturation temperature (K): analytic inverse of prefRaw
 *  (P = exp(7.89191 - 2310.84/(T - 19.79))).  Private. */
function tsat_r134aRaw(P_MPa) {
  return 2310.84 / (7.89191 - Math.log(P_MPa)) + 19.79;
}

// ---------------------------------------------------------------------------
// Pure-component saturation pressures
// ---------------------------------------------------------------------------

/** R134a saturation pressure, MPa.  T in K.
 *  (Fitted from Zehioua Table 3, 298-353 K, error < 0.2%.)
 *  Range: 298 <= T <= 353. */
function pref_r134a(T) {
  if (!(298 <= T && T <= 353)) {
    throw domainError('RANGE',
      `pref_r134a: T=${T} K is outside the fitted range T in [298, 353] K`);
  }
  return prefRaw(T);
}

/** DMF saturation pressure, MPa.  T in K.
 *  (NIST WebBook, Gopal & Rizvi 1968.)
 *  Range: 303 <= T <= 363. */
function psat_dmf(T) {
  if (!(303 <= T && T <= 363)) {
    throw domainError('RANGE',
      `psat_dmf: T=${T} K is outside the range T in [303, 363] K`);
  }
  return psatDmfRaw(T);
}

// ---------------------------------------------------------------------------
// Liquid molar volumes (for the Poynting correction; no range)
// ---------------------------------------------------------------------------

/** R134a saturated-liquid molar volume, m3/mol (rough value suffices). */
function vl_r134a(T) {
  const rho = 1207 * (1 - 0.35 * (T - 300) / 100);   // kg/m3
  return 0.10203 / Math.max(rho, 800);
}

/** DMF liquid molar volume, m3/mol. */
function vl_dmf(T) {
  return 0.07309 / (944 * (1 - 0.0009 * (T - 293)));
}

// ---------------------------------------------------------------------------
// NRTL
// ---------------------------------------------------------------------------

/** NRTL activity coefficients.  Returns {gamma1, gamma2}.
 *  Domain: 0 <= x1 <= 1. */
function nrtl_gamma(T, x1) {
  if (!(0 <= x1 && x1 <= 1)) {
    throw domainError('RANGE',
      `nrtl_gamma: x1=${x1} is outside the domain x1 in [0, 1]`);
  }
  return nrtlGammaRaw(T, x1);
}

/** NRTL excess molar enthalpy, J/mol (analytic derivative of gE
 *  with respect to T, verified against numerical differentiation
 *  in the Python set).  Domain: 0 <= x1 <= 1. */
function nrtl_hE(T, x1) {
  if (!(0 <= x1 && x1 <= 1)) {
    throw domainError('RANGE',
      `nrtl_hE: x1=${x1} is outside the domain x1 in [0, 1]`);
  }
  return nrtlHERaw(T, x1);
}

// ---------------------------------------------------------------------------
// Bubble pressure and its temperature inverse
// ---------------------------------------------------------------------------

/** Bubble-point pressure.
 *  Input: T (K), x1 (R134a liquid mole fraction).
 *  Returns {p_MPa, y1}: bubble pressure in MPa, vapour R134a mole
 *  fraction.  Range: 303.30 <= T <= 353.24, 0 <= x1 <= 1.
 *  The 40-iteration Poynting loop mirrors the Python set exactly. */
function psol(T, x1) {
  if (!(303.30 <= T && T <= 353.24 && 0 <= x1 && x1 <= 1)) {
    throw domainError('RANGE',
      `psol: (T=${T} K, x1=${x1}) is outside the fitted range ` +
      'T in [303.30, 353.24] K, x1 in [0, 1]');
  }
  return psolRaw(T, x1);
}

/** Bubble-point temperature [K] from bubble pressure [MPa] and x1
 *  (Newton iteration, mirroring the Python set exactly: Tguess =
 *  330, 50 iterations, dT = 0.2, break when |pc - p_MPa| < 1e-9).
 *  The iteration uses the raw psol internally, as in Python.
 *  Domain: 0 <= x1 <= 1 (else RANGE).  Returns null when p_MPa is
 *  outside the achievable psol span at x1 over T in
 *  [303.30, 353.24] K -- the no-root convention, as in the ammonia
 *  inverses; the span is computed via the raw psol so the span
 *  check itself does not throw for the boundary temperatures. */
function bubble_T(p_MPa, x1) {
  if (!(0 <= x1 && x1 <= 1)) {
    throw domainError('RANGE',
      `bubble_T: x1=${x1} is outside the domain x1 in [0, 1]`);
  }
  const pLo = psolRaw(303.30, x1).p_MPa;
  const pHi = psolRaw(353.24, x1).p_MPa;
  if (!(pLo <= p_MPa && p_MPa <= pHi)) {
    return null;
  }
  let T = 330.0;
  for (let i = 0; i < 50; i++) {
    const pc = psolRaw(T, x1).p_MPa;
    const dT = 0.2;
    const p2 = psolRaw(T + dT, x1).p_MPa;
    const dpdT = (p2 - pc) / dT;
    T = T - (pc - p_MPa) / dpdT;
    if (Math.abs(pc - p_MPa) < 1e-9) {
      break;
    }
  }
  return T;
}

// ---------------------------------------------------------------------------
// Concentration from solution and dew temperatures
// ---------------------------------------------------------------------------

/** R134a liquid mole fraction x1 from solution temperature Tsol
 *  [K] and dew-point temperature Tdew [K] (80 bisection steps).
 *  NOTE the argument order: (Tsol, Tdew) -- Tsol first.
 *  Principle: DMF is treated as non-volatile, so the dew point
 *  fixes the pressure, P = pref_r134a(Tdew); then bisect
 *  psol(Tsol, x1) = P over x1 in [0, 1] (bubble pressure increases
 *  monotonically with x1 on that interval).  Returns null when
 *  there is no root (P outside the bubble-pressure span at Tsol,
 *  e.g. Tsol well below Tdew).
 *  Domain: 303.30 <= Tsol <= 353.24 (else RANGE).  Tdew itself
 *  gets NO range check -- the Python construction evaluates
 *  pref_r134a at Tdew values well below 298 K (documented anchor
 *  Tdew = 276.62 K) -- so all internal calls here use the raw
 *  private versions. */
function xi_by_tsol_tdew(Tsol, Tdew) {
  if (!(303.30 <= Tsol && Tsol <= 353.24)) {
    throw domainError('RANGE',
      `xi_by_tsol_tdew: Tsol=${Tsol} K is outside the fitted range ` +
      'Tsol in [303.30, 353.24] K');
  }
  const P = prefRaw(Tdew);
  const Plo = psolRaw(Tsol, 0.0).p_MPa;
  const Phi = psolRaw(Tsol, 1.0).p_MPa;
  if (!(Plo <= P && P <= Phi)) {
    return null;
  }
  let lo = 0.0, hi = 1.0;
  for (let i = 0; i < 80; i++) {
    const mid = 0.5 * (lo + hi);
    if (psolRaw(Tsol, mid).p_MPa < P) {
      lo = mid;
    } else {
      hi = mid;
    }
  }
  return 0.5 * (lo + hi);
}

// ---------------------------------------------------------------------------
// Enthalpies
// ---------------------------------------------------------------------------

/** R134a saturated-liquid enthalpy, kJ/kg.
 *  Fitted from Tillner-Roth & Baehr (1994) Table C-1, reference
 *  state shifted to 273.15 K = 100 kJ/kg.
 *  Range: 233 <= T <= 353 (fit error < 0.4 kJ/kg). */
function hliq_r134a(T) {
  if (!(233 <= T && T <= 353)) {
    throw domainError('RANGE',
      `hliq_r134a: T=${T} K is outside the fitted range T in [233, 353] K`);
  }
  return hliqRaw(T);
}

/** DMF liquid enthalpy, kJ/kg.
 *  He et al., Solar Energy 83 (2009) Eq (5), reference state
 *  273.15 K saturated liquid = 100 kJ/kg.
 *  No T range is imposed (none stated for Eq (5)). */
function h_dmf_L(T) {
  return hDmfLRaw(T);
}

// ---------------------------------------------------------------------------
// Mole <-> mass fraction
// ---------------------------------------------------------------------------

/** Mole fraction -> mass fraction (R134a).  Domain: x1 in [0, 1]. */
function x_to_w(x1) {
  if (!(0 <= x1 && x1 <= 1)) {
    throw domainError('RANGE',
      `x_to_w: x1=${x1} is outside the domain [0, 1]`);
  }
  return x1 * M1 / (x1 * M1 + (1 - x1) * M2);
}

/** Mass fraction -> mole fraction (R134a).  Domain: w1 in [0, 1]. */
function w_to_x(w1) {
  if (!(0 <= w1 && w1 <= 1)) {
    throw domainError('RANGE',
      `w_to_x: w1=${w1} is outside the domain [0, 1]`);
  }
  return (w1 / M1) / (w1 / M1 + (1 - w1) / M2);
}

/** R134a-DMF solution enthalpy, kJ/kg.
 *  Input: T (K), x1 (R134a liquid mole fraction).
 *  Reference state: 273.15 K saturated liquid = 100 kJ/kg (both
 *  components).  h = w1*h1 + w2*h2 + hE/Mbar.
 *  Domain: 233 <= T <= 353 and 0 <= x1 <= 1 -- the PUBLIC
 *  composite enforces the hliq component's stated range
 *  (jurisdiction table, 2026-10-16).  tsol_by_hsol uses the raw
 *  hsol internally, because its solver bracket reaches 360 K
 *  (the table's trap #3); the raw component implementations are
 *  used internally here too. */
function hsol(T, x1) {
  if (!(233 <= T && T <= 353 && 0 <= x1 && x1 <= 1)) {
    throw domainError('RANGE',
      `hsol: (T=${T} K, x1=${x1}) is outside the domain ` +
      'T in [233, 353] K, x1 in [0, 1]');
  }
  return hsolRaw(T, x1);
}

// ---------------------------------------------------------------------------
// Dew temperature and enthalpy inverse
// ---------------------------------------------------------------------------

/** Dew-point temperature [K] of the solution at (T, x1), under the
 *  library-wide TdewByTsolXi convention:
 *      Tdew = tsat_r134a(psol(T, x1) pressure),
 *  i.e. the pure-R134a saturation temperature, on this module's own
 *  pure line, evaluated at the solution surface pressure Psol.
 *  DMF is treated as non-volatile (vapour y1 > 0.99).
 *  Propagates psol's RANGE. */
function tdew_by_tsol_xi(T, x1) {
  return tsat_r134aRaw(psol(T, x1).p_MPa);
}

/** Solution temperature [K] from solution specific enthalpy
 *  h [kJ/kg] and R134a mole fraction x1: bisection inverse of
 *  hsol (100 iterations), which increases monotonically with T at
 *  fixed x1.  Solver bracket T in [280, 360] K.  Returns null if
 *  h lies outside the hsol span at x1 (the span is evaluated with
 *  the raw hsol so no range error interferes).
 *  Domain: 0 <= x1 <= 1 (else RANGE). */
function tsol_by_hsol(h, x1) {
  if (!(0 <= x1 && x1 <= 1)) {
    throw domainError('RANGE',
      `tsol_by_hsol: x1=${x1} is outside the domain x1 in [0, 1]`);
  }
  const lo = 280.0, hi = 360.0;
  const hlo = hsolRaw(lo, x1);
  const hhi = hsolRaw(hi, x1);
  if (!(hlo <= h && h <= hhi)) {
    return null;
  }
  let loT = lo, hiT = hi;
  for (let i = 0; i < 100; i++) {
    const mid = 0.5 * (loT + hiT);
    if (hsolRaw(mid, x1) < h) {
      loT = mid;
    } else {
      hiT = mid;
    }
  }
  return 0.5 * (loT + hiT);
}

module.exports = {
  pref_r134a, psat_dmf, vl_r134a, vl_dmf,
  nrtl_gamma, nrtl_hE, psol, bubble_T, xi_by_tsol_tdew,
  hliq_r134a, h_dmf_L, x_to_w, w_to_x, hsol,
  tdew_by_tsol_xi, tsol_by_hsol,
};

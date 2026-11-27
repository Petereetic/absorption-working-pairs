'use strict';
/*
 * r124.js -- R124 (2-chloro-1,1,1,2-tetrafluoroethane) pure-substance
 * saturation properties (JavaScript set of the
 * absorption-working-pairs library; companion to
 * pure_fluids.py / .c / .bas, R124 section).
 * ==========================================================================
 * Source
 * ------
 * Fit to the NIST WebBook saturation table for R124 (276 points),
 * as recorded in the header of pure_fluids.py, the pure_fluids
 * formula notes and the working-pair formula materials document
 * "R124 pure fluid - NIST table fit and Borde arbitration".
 *   Saturation pressure: Wagner variant
 *     ln(P/Pc) = (Tc/T) * (a1*tau + a2*tau^1.5 + a3*tau^3
 *                          + a4*tau^6),  tau = 1 - T/Tc,
 *     with Tc = 395.428 K and Pc = 36.245 bar.  NOTE the
 *     exponents 1, 1.5, 3, 6 (the _wagner_pref36 form in
 *     Python), NOT the 1, 1.5, 2.5, 5 form used for R134a/R22.
 *     The fit is native in bar (the internal unit below); the
 *     public boundary converts bar <-> MPa by x0.1 / x10,
 *     exactly as in the Python reference.  Maximum deviation
 *     vs. the table: 0.111 % over the valid band -40 to
 *     110 degC.
 *   Saturated-liquid / saturated-vapour enthalpy: degree-6
 *     polynomials h(t), t in degC, kJ/kg.  Maximum deviations
 *     vs. the table over the same band: hliq 1.11 kJ/kg,
 *     hgas 1.63 kJ/kg.
 *   Saturation temperature: inversion of Pref by 60 bisection
 *     steps, exactly as in the Python reference.
 *
 * Conventions
 * -----------
 * t  : temperature in degC.
 * P  : MPa at the public boundary; bar only inside the Wagner
 *      fit (Pc and the private raw Pref), converted at the
 *      boundary exactly as in Python (x0.1 out, x10 in).
 * h  : kJ/kg.
 * Function names are exactly the Python set's public names
 * for R124; no aliases are kept.  Internal arithmetic and
 * coefficients are copied verbatim from pure_fluids.py; only
 * the domain discipline below is this set's own rendering of
 * the source-stated valid band.  Python None is rendered as
 * null here.
 *
 * Reference state
 * ---------------
 * Saturated liquid at 0 degC = 100 kJ/kg (the library-wide
 * uniform datum; the NIST table's own datum of 200 kJ/kg was
 * shifted by -100 as a whole when the fits were made, and the
 * latent heat hlat = hgas - hliq is unchanged by the shift).
 * The reference point 0 degC lies INSIDE the fitted band
 * [-40, 110] degC.  Note: the fitted hliq polynomial gives
 * R124_hliq(0) = 100.04767130193036 kJ/kg, i.e. 0.048 kJ/kg
 * above the nominal datum -- well inside the stated hliq fit
 * deviation of 1.11 kJ/kg; the coefficients are kept verbatim.
 *
 * Domain discipline (designed divergence from Python)
 * ---------------------------------------------------
 * The Python set states the valid band in its header but
 * performs NO range checks on the t-input functions (Pref,
 * hliq, hgas, hlat) and evaluates anyway.  This set enforces
 * the source-stated valid band at the public boundary: t
 * outside [-40, 110] degC throws an Error with .code 'RANGE'.
 * R124_Tsat carries no RANGE check: it mirrors Python
 * exactly -- P outside the Pref span over [-40, 110] degC
 * returns null (the pure-fluid Tsat span-null precedent, cf.
 * H2O_Tsat / NH3_Tsat / CH3OH_Tsat / R134a_Tsat / R22_Tsat).
 * All internal calls use the raw private implementations so
 * the public checks never corrupt the Python logic.
 * Per function:
 *   R124_Pref : t outside [-40, 110] throws RANGE.
 *   R124_Tsat : no RANGE; P outside [Pref(-40), Pref(110)]
 *              returns null; inside, 60 bisection steps.
 *   R124_hliq : t outside [-40, 110] throws RANGE.
 *   R124_hgas : t outside [-40, 110] throws RANGE.
 *   R124_hlat : t outside [-40, 110] throws RANGE; value is
 *              raw hgas - raw hliq at the same t.
 */

// ---------------------------------------------------------------------------
// Coefficients (verbatim from pure_fluids.py, R124 section)
// ---------------------------------------------------------------------------

const _R124_Tc = 395.428;
const _R124_Pc = 36.245;
const _R124_W = [-7.401179377235425, 1.4613603991162563, -3.476435267708954,
  -1.772232810745864];
const _R124_hL = [3.101121704716488e-12, 6.118884579625834e-10, -1.0126584362284601e-08,
  -3.744431218418699e-06, 9.264564201937477e-04, 1.0995525531984227,
  1.0004767130193036e+02];
const _R124_hV = [-4.7606354686130485e-12, -9.020883920792309e-10, 2.036341936229362e-08,
  4.234769176716097e-06, -3.8033802108463233e-04, 5.621038923140594e-01,
  2.5994742998138406e+02];
const _R124_TLO = -40.0;
const _R124_THI = 110.0;

function domainError(code, message) {
  const e = new Error(message);
  e.code = code;
  return e;
}

function _checkT(fnName, t_C) {
  if (!(_R124_TLO <= t_C && t_C <= _R124_THI)) {
    throw domainError('RANGE',
      `${fnName}: t_C=${t_C} is outside the domain t_C in [-40, 110]`);
  }
}

// ---------------------------------------------------------------------------
// Raw private implementations (no range checks, mirroring Python)
// ---------------------------------------------------------------------------

function _poly6(c, t) {
  return (((((c[0] * t + c[1]) * t + c[2]) * t + c[3]) * t + c[4]) * t + c[5]) * t + c[6];
}

/** Wagner-variant saturation pressure (private raw), bar: the
 *  fit's native unit, exponents 1, 1.5, 3, 6 as in Python's
 *  _wagner_pref36. */
function _wagner_pref36_bar(t_C) {
  const T = t_C + 273.15;
  const tau = 1.0 - T / _R124_Tc;
  const a = _R124_W;
  return _R124_Pc * Math.exp((_R124_Tc / T) * (a[0] * tau + a[1] * Math.pow(tau, 1.5)
    + a[2] * Math.pow(tau, 3.0) + a[3] * Math.pow(tau, 6.0)));
}

function _hliq_raw(t_C) {
  return _poly6(_R124_hL, t_C);
}

function _hgas_raw(t_C) {
  return _poly6(_R124_hV, t_C);
}

/** Bisection inversion of a Pref function, 60 steps, exactly
 *  as _tsat_bisect in Python: P and pref_fn share one unit
 *  (bar here, as in the Python R124 entry); returns null
 *  when P lies outside the Pref span over [t_lo, t_hi]. */
function _tsat_bisect(P, pref_fn, t_lo, t_hi) {
  const Plo = pref_fn(t_lo), Phi = pref_fn(t_hi);
  if (!(Plo <= P && P <= Phi)) {
    return null;
  }
  let lo = t_lo, hi = t_hi;
  for (let i = 0; i < 60; i++) {
    const mid = 0.5 * (lo + hi);
    if (pref_fn(mid) < P) {
      lo = mid;
    } else {
      hi = mid;
    }
  }
  return 0.5 * (lo + hi);
}

// ---------------------------------------------------------------------------
// Public functions (Python names verbatim)
// ---------------------------------------------------------------------------

/** R124 saturation pressure, MPa.  t_C in degC (Wagner-variant
 *  fit to the NIST WebBook saturation table; internal bar
 *  value converted by x0.1, as in Python).  t_C outside
 *  [-40, 110] throws RANGE. */
function R124_Pref(t_C) {
  _checkT('R124_Pref', t_C);
  return 0.1 * _wagner_pref36_bar(t_C);
}

/** R124 saturation temperature, degC.  P_MPa in MPa (converted
 *  by x10 to bar for the bisection, as in Python).  Returns
 *  null when P lies outside the Pref span over [-40, 110] degC
 *  (mirrors Python; no RANGE check on P). */
function R124_Tsat(P_MPa) {
  return _tsat_bisect(10.0 * P_MPa, _wagner_pref36_bar, _R124_TLO, _R124_THI);
}

/** R124 saturated-liquid enthalpy, kJ/kg.  Reference state:
 *  saturated liquid at 0 degC = 100 kJ/kg (nominal datum; the
 *  fit gives 100.04767130193036 at 0 degC).  t_C outside
 *  [-40, 110] throws RANGE. */
function R124_hliq(t_C) {
  _checkT('R124_hliq', t_C);
  return _hliq_raw(t_C);
}

/** R124 saturated-vapour enthalpy, kJ/kg.  Reference state as
 *  for hliq.  t_C outside [-40, 110] throws RANGE. */
function R124_hgas(t_C) {
  _checkT('R124_hgas', t_C);
  return _hgas_raw(t_C);
}

/** R124 saturation latent heat, kJ/kg = hgas - hliq (the datum
 *  shift cancels).  t_C outside [-40, 110] throws RANGE. */
function R124_hlat(t_C) {
  _checkT('R124_hlat', t_C);
  return _hgas_raw(t_C) - _hliq_raw(t_C);
}

module.exports = {
  R124_Pref, R124_Tsat, R124_hliq, R124_hgas, R124_hlat,
};

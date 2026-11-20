'use strict';
/*
 * r22.js -- R22 (chlorodifluoromethane) pure-substance
 * saturation properties (JavaScript set of the
 * absorption-working-pairs library; companion to
 * pure_fluids.py / .c / .bas, R22 section).
 * ==========================================================================
 * Source
 * ------
 * Fits to CoolProp's built-in reference equation of state for
 * R22, as recorded in the header
 * of pure_fluids.py and the pure_fluids formula notes.
 *   Saturation pressure: Wagner equation
 *     ln(P/Pc) = (Tc/T) * (a1*tau + a2*tau^1.5 + a3*tau^2.5
 *                          + a4*tau^5),  tau = 1 - T/Tc,
 *     with Tc = 369.30 K and Pc = 49.90 bar.  The fit is native
 *     in bar (the internal unit below); the public boundary
 *     converts bar <-> MPa by x0.1 / x10, exactly as in the
 *     Python reference.  Maximum deviation vs. the equation of
 *     state: 0.0065 % over the valid band -50 to 90 degC.
 *   Saturated-liquid / saturated-vapour enthalpy: degree-6
 *     polynomials h(t), t in degC, kJ/kg.  Maximum deviations
 *     vs. the equation of state: hliq 0.42 kJ/kg, hgas
 *     0.59 kJ/kg.
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
 * for R22; no aliases are kept.  Internal arithmetic and
 * coefficients are copied verbatim from pure_fluids.py; only
 * the domain discipline below is this set's own rendering of
 * the source-stated valid band.  Python None is rendered as
 * null here.
 *
 * Reference state
 * ---------------
 * Saturated liquid at 0 degC = 100 kJ/kg (the library-wide
 * uniform datum; CoolProp's own default of 200 kJ/kg was
 * shifted by -100 as a whole when the fits were made, and the
 * latent heat hlat = hgas - hliq is unchanged by the shift).
 * The reference point 0 degC lies INSIDE the fitted band
 * [-50, 90] degC.  Note: the fitted hliq polynomial gives
 * R22_hliq(0) = 99.972867 kJ/kg, i.e. 0.027 kJ/kg below the
 * nominal datum -- well inside the stated hliq fit deviation
 * of 0.42 kJ/kg; the coefficients are kept verbatim.
 *
 * Domain discipline (designed divergence from Python)
 * ---------------------------------------------------
 * The Python set states the valid band in its header but
 * performs NO range checks on the t-input functions (Pref,
 * hliq, hgas, hlat) and evaluates anyway.  This set enforces
 * the source-stated valid band at the public boundary: t
 * outside [-50, 90] degC throws an Error with .code 'RANGE'.
 * R22_Tsat carries no RANGE check: it mirrors Python
 * exactly -- P outside the Pref span over [-50, 90] degC
 * returns null (the pure-fluid Tsat span-null precedent, cf.
 * H2O_Tsat / NH3_Tsat / CH3OH_Tsat).  All internal calls use
 * the raw private implementations so the public checks never
 * corrupt the Python logic.
 * Per function:
 *   R22_Pref : t outside [-50, 90] throws RANGE.
 *   R22_Tsat : no RANGE; P outside [Pref(-50), Pref(90)]
 *              returns null; inside, 60 bisection steps.
 *   R22_hliq : t outside [-50, 90] throws RANGE.
 *   R22_hgas : t outside [-50, 90] throws RANGE.
 *   R22_hlat : t outside [-50, 90] throws RANGE; value is
 *              raw hgas - raw hliq at the same t.
 */

// ---------------------------------------------------------------------------
// Coefficients (verbatim from pure_fluids.py, R22 section)
// ---------------------------------------------------------------------------

const _R22_Tc = 369.30;
const _R22_Pc = 49.90;
const _R22_W = [-7.0486230, 1.4828095, -1.8223105, -2.8257753];
const _R22_hL = [4.6681599e-11, -2.2286115e-09, -1.2586426e-07, 1.4969301e-05,
  1.5173919e-03, 1.1678030e+00, 9.9972867e+01];
const _R22_hV = [-6.5412360e-11, 3.1584987e-09, 1.6628519e-07, -2.1606737e-05,
  -1.9128189e-03, 3.7574587e-01, 3.0508640e+02];
const _R22_TLO = -50.0;
const _R22_THI = 90.0;

function domainError(code, message) {
  const e = new Error(message);
  e.code = code;
  return e;
}

function _checkT(fnName, t_C) {
  if (!(_R22_TLO <= t_C && t_C <= _R22_THI)) {
    throw domainError('RANGE',
      `${fnName}: t_C=${t_C} is outside the domain t_C in [-50, 90]`);
  }
}

// ---------------------------------------------------------------------------
// Raw private implementations (no range checks, mirroring Python)
// ---------------------------------------------------------------------------

function _poly6(c, t) {
  return (((((c[0] * t + c[1]) * t + c[2]) * t + c[3]) * t + c[4]) * t + c[5]) * t + c[6];
}

/** Wagner saturation pressure (private raw), bar: the fit's
 *  native unit, exponents 1, 1.5, 2.5, 5 as in Python. */
function _wagner_pref_bar(t_C) {
  const T = t_C + 273.15;
  const tau = 1.0 - T / _R22_Tc;
  const a = _R22_W;
  return _R22_Pc * Math.exp((_R22_Tc / T) * (a[0] * tau + a[1] * Math.pow(tau, 1.5)
    + a[2] * Math.pow(tau, 2.5) + a[3] * Math.pow(tau, 5.0)));
}

function _hliq_raw(t_C) {
  return _poly6(_R22_hL, t_C);
}

function _hgas_raw(t_C) {
  return _poly6(_R22_hV, t_C);
}

/** Bisection inversion of a Pref function, 60 steps, exactly
 *  as _tsat_bisect in Python: P and pref_fn share one unit
 *  (bar here, as in the Python R22 entry); returns null
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

/** R22 saturation pressure, MPa.  t_C in degC (Wagner fit to
 *  the CoolProp reference EOS; internal bar value
 *  converted by x0.1, as in Python).  t_C outside [-50, 90]
 *  throws RANGE. */
function R22_Pref(t_C) {
  _checkT('R22_Pref', t_C);
  return 0.1 * _wagner_pref_bar(t_C);
}

/** R22 saturation temperature, degC.  P_MPa in MPa (converted
 *  by x10 to bar for the bisection, as in Python).  Returns
 *  null when P lies outside the Pref span over [-50, 90] degC
 *  (mirrors Python; no RANGE check on P). */
function R22_Tsat(P_MPa) {
  return _tsat_bisect(10.0 * P_MPa, _wagner_pref_bar, _R22_TLO, _R22_THI);
}

/** R22 saturated-liquid enthalpy, kJ/kg.  Reference state:
 *  saturated liquid at 0 degC = 100 kJ/kg (nominal datum; the
 *  fit gives 99.972867 at 0 degC).  t_C outside [-50, 90]
 *  throws RANGE. */
function R22_hliq(t_C) {
  _checkT('R22_hliq', t_C);
  return _hliq_raw(t_C);
}

/** R22 saturated-vapour enthalpy, kJ/kg.  Reference state as
 *  for hliq.  t_C outside [-50, 90] throws RANGE. */
function R22_hgas(t_C) {
  _checkT('R22_hgas', t_C);
  return _hgas_raw(t_C);
}

/** R22 saturation latent heat, kJ/kg = hgas - hliq (the datum
 *  shift cancels).  t_C outside [-50, 90] throws RANGE. */
function R22_hlat(t_C) {
  _checkT('R22_hlat', t_C);
  return _hgas_raw(t_C) - _hliq_raw(t_C);
}

module.exports = {
  R22_Pref, R22_Tsat, R22_hliq, R22_hgas, R22_hlat,
};

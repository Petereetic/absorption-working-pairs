'use strict';
/*
 * h2o.js -- H2O (water) pure-substance saturation properties
 * (JavaScript set of the absorption-working-pairs library;
 * companion to pure_fluids.py / .c / .bas, H2O section).
 * ==========================================================================
 * Source
 * ------
 * Compact fits to the NIST WebBook saturation table for water
 * (373 table points, 1 to 373 degC), adopted 2026-10-13; the
 * full fit notes are in pure_fluids/fit-notes/ and the summary
 * is in the pure_fluids formula notes (2026-10-13 supplement).
 *   Saturation pressure: lnP-t degree-7 polynomial,
 *     ln(P/MPa) = sum(c_k t^k, k = 0..7), t in degC; the form
 *     is natively in MPa, so this module returns MPa directly.
 *     Maximum deviation vs. the table: 0.0291 % over the full
 *     range, 0.0128 % over the usual band 5 to 300 degC.
 *   Saturated-liquid / saturated-vapour enthalpy: degree-6
 *     polynomials h(t), t in degC, kJ/kg.  Maximum deviations
 *     vs. the table over the usual band: hliq 3.51 kJ/kg,
 *     hgas 5.51 kJ/kg; deviations grow near the critical end
 *     (full-range maxima 49.5 / 76.2 kJ/kg, see the fit notes).
 *   Saturation temperature: inversion of Pref by 60 bisection
 *     steps, exactly as in the Python reference.
 * The authoritative standard for water remains the IAPWS
 * formulation; this fit is a portable compact form and does
 * not replace it.
 *
 * Conventions
 * -----------
 * t  : temperature in degC.
 * P  : MPa at the public boundary (native unit of the fit; no
 *      conversion anywhere in this module).
 * h  : kJ/kg.
 * Function names are exactly the Python set's public names
 * for H2O; no aliases are kept.  Internal arithmetic and
 * coefficients are copied verbatim from pure_fluids.py; only
 * the domain discipline below is this set's own rendering of
 * the source-stated table range.  Python None is rendered as
 * null here.
 *
 * Reference state
 * ---------------
 * Saturated liquid at 0 degC = 100 kJ/kg (the library-wide
 * uniform datum).  The enthalpies have been shifted from the
 * NIST table's own datum to this datum by +93.351889719 kJ/kg
 * (constant term only; the shift is already contained in the
 * coefficients below, and the latent heat hlat = hgas - hliq
 * is unchanged by it).  Note the reference point 0 degC lies
 * just below the fitted band [1, 373] degC; the datum is a
 * statement about the coefficients, and hliq is served only
 * inside the band (see the domain discipline).
 *
 * Domain discipline (designed divergence from Python)
 * ---------------------------------------------------
 * The Python set states the table range in its header and
 * fit notes but performs NO range checks on the t-input
 * functions (Pref, hliq, hgas, hlat) and evaluates anyway.
 * This set enforces the source-stated table range at the
 * public boundary: t outside [1, 373] degC throws an Error
 * with .code 'RANGE'.  H2O_Tsat carries no RANGE check: it
 * mirrors Python exactly -- P outside the Pref span over
 * [1, 373] degC returns null (the pure-fluid Tsat span-null
 * precedent, cf. Tsat_R124 in the R124-DMAC set).  All
 * internal calls use the raw private implementations so the
 * public checks never corrupt the Python logic.
 * Per function:
 *   H2O_Pref : t outside [1, 373] throws RANGE.
 *   H2O_Tsat : no RANGE; P outside [Pref(1), Pref(373)]
 *              returns null; inside, 60 bisection steps.
 *   H2O_hliq : t outside [1, 373] throws RANGE.
 *   H2O_hgas : t outside [1, 373] throws RANGE.
 *   H2O_hlat : t outside [1, 373] throws RANGE; value is
 *              raw hgas - raw hliq at the same t.
 */

// ---------------------------------------------------------------------------
// Coefficients (verbatim from pure_fluids.py, H2O section)
// ---------------------------------------------------------------------------

const _H2O_LNP = [5.54627791673895e-18, -8.99249875691861e-15, 6.660700555390007e-12, -3.088083641876246e-09,
  1.056735995405781e-06, -0.0002954387998568004, 0.07259423527358563, -7.399704960820133];
const _H2O_hL = [4.9253814056437e-12, -4.8364685293173926e-09, 1.8115766448129802e-06, -0.0003141174119157094,
  0.02553352332697852, 3.3541747407753046, 100.0];
const _H2O_hV = [-8.083632440447619e-12, 7.910908004577575e-09, -2.951073494811462e-06, 0.0005046392594921277,
  -0.04153882947643235, 3.1701433360694287, 2583.8464687067276];
const _H2O_TLO = 1.0;
const _H2O_THI = 373.0;

function domainError(code, message) {
  const e = new Error(message);
  e.code = code;
  return e;
}

function _checkT(fnName, t_C) {
  if (!(_H2O_TLO <= t_C && t_C <= _H2O_THI)) {
    throw domainError('RANGE',
      `${fnName}: t_C=${t_C} is outside the domain t_C in [1, 373]`);
  }
}

// ---------------------------------------------------------------------------
// Raw private implementations (no range checks, mirroring Python)
// ---------------------------------------------------------------------------

function _poly6(c, t) {
  return (((((c[0] * t + c[1]) * t + c[2]) * t + c[3]) * t + c[4]) * t + c[5]) * t + c[6];
}

function _poly7(c, t) {
  return ((((((c[0] * t + c[1]) * t + c[2]) * t + c[3]) * t + c[4]) * t + c[5]) * t + c[6]) * t + c[7];
}

/** Saturation pressure from the lnP-t degree-7 polynomial
 *  (private raw): the notes' formula is natively in MPa. */
function _lnp_pref_raw(t_C) {
  return Math.exp(_poly7(_H2O_LNP, t_C));
}

function _hliq_raw(t_C) {
  return _poly6(_H2O_hL, t_C);
}

function _hgas_raw(t_C) {
  return _poly6(_H2O_hV, t_C);
}

/** Bisection inversion of a Pref function, 60 steps, exactly
 *  as _tsat_bisect in Python: returns null when P lies outside
 *  the Pref span over [t_lo, t_hi]. */
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

/** H2O saturation pressure, MPa.  t_C in degC (NIST-table fit,
 *  lnP-t degree-7 polynomial).  t_C outside [1, 373] throws
 *  RANGE. */
function H2O_Pref(t_C) {
  _checkT('H2O_Pref', t_C);
  return _lnp_pref_raw(t_C);
}

/** H2O saturation temperature, degC.  P_MPa in MPa.  Returns
 *  null when P lies outside the Pref span over [1, 373] degC
 *  (mirrors Python; no RANGE check on P). */
function H2O_Tsat(P_MPa) {
  return _tsat_bisect(P_MPa, _lnp_pref_raw, _H2O_TLO, _H2O_THI);
}

/** H2O saturated-liquid enthalpy, kJ/kg.  Reference state:
 *  saturated liquid at 0 degC = 100 kJ/kg (after the shift).
 *  t_C outside [1, 373] throws RANGE. */
function H2O_hliq(t_C) {
  _checkT('H2O_hliq', t_C);
  return _hliq_raw(t_C);
}

/** H2O saturated-vapour enthalpy, kJ/kg.  Reference state as
 *  for hliq (after the shift).  t_C outside [1, 373] throws
 *  RANGE. */
function H2O_hgas(t_C) {
  _checkT('H2O_hgas', t_C);
  return _hgas_raw(t_C);
}

/** H2O saturation latent heat, kJ/kg = hgas - hliq (the shift
 *  cancels; independent of the table reference state).  t_C
 *  outside [1, 373] throws RANGE. */
function H2O_hlat(t_C) {
  _checkT('H2O_hlat', t_C);
  return _hgas_raw(t_C) - _hliq_raw(t_C);
}

module.exports = {
  H2O_Pref, H2O_Tsat, H2O_hliq, H2O_hgas, H2O_hlat,
};

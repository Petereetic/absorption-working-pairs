'use strict';
/*
 * ch3oh.js -- CH3OH (methanol) pure-substance saturation properties
 * (JavaScript set of the absorption-working-pairs library;
 * companion to pure_fluids.py / .c / .bas, CH3OH section).
 * ==========================================================================
 * Source
 * ------
 * Compact fits to the NIST WebBook saturation table for methanol
 * (330 table points, -90 to 239 degC), adopted 2026-10-13; the
 * full fit notes are in pure_fluids/fit-notes/ and the summary
 * is in the pure_fluids formula notes (2026-10-13 supplement).
 *   Saturation pressure: lnP-t degree-7 polynomial,
 *     ln(P/MPa) = sum(c_k t^k, k = 0..7), t in degC; the form
 *     is natively in MPa, so this module returns MPa directly.
 *     Maximum deviation vs. the table: 0.1064 % over the full
 *     range, 0.0321 % over the usual band -40 to 90 degC; the
 *     full-range maximum sits at the low end (-90 degC, where
 *     the table pressure is only 6.091e-07 MPa, four significant
 *     figures, so the source rounding noise is amplified).
 *   Saturated-liquid / saturated-vapour enthalpy: degree-6
 *     polynomials h(t), t in degC, kJ/kg.  Maximum deviations
 *     vs. the table over the usual band: hliq 1.25 kJ/kg,
 *     hgas 3.92 kJ/kg; deviations grow near the critical end
 *     (full-range maxima 22.46 / 46.59 kJ/kg, both at
 *     239 degC, see the fit notes).
 *   Saturation temperature: inversion of Pref by 60 bisection
 *     steps, exactly as in the Python reference.
 * The source table is the WebBook web-page rounded output
 * (mostly five significant figures, enthalpies to two decimal
 * places), so the fit residuals above include source-table
 * rounding noise.  Spot checks in the fit notes show the
 * source table agreeing with CoolProp's reference equation of
 * state at the rounding level (saturation pressure within
 * 0.003 %, latent heat within 0.05 kJ/kg), so only the fit
 * residuals above are on account.
 *
 * Conventions
 * -----------
 * t  : temperature in degC.
 * P  : MPa at the public boundary (native unit of the fit; no
 *      conversion anywhere in this module).
 * h  : kJ/kg.
 * Function names are exactly the Python set's public names
 * for CH3OH; no aliases are kept.  Internal arithmetic and
 * coefficients are copied verbatim from pure_fluids.py; only
 * the domain discipline below is this set's own rendering of
 * the source-stated table range.  Python None is rendered as
 * null here.
 *
 * Reference state
 * ---------------
 * Saturated liquid at 0 degC = 100 kJ/kg (the library-wide
 * uniform datum).  The enthalpies have been shifted from the
 * NIST table's own datum to this datum by +266.341441575
 * kJ/kg (constant term only; the shift is already contained
 * in the coefficients below, and the latent heat
 * hlat = hgas - hliq is unchanged by it).  As for ammonia,
 * the reference point 0 degC lies INSIDE the fitted band
 * [-90, 239] degC, so CH3OH_hliq(0) = 100 kJ/kg is served as
 * an ordinary in-band value.
 *
 * Domain discipline (designed divergence from Python)
 * ---------------------------------------------------
 * The Python set states the table range in its header and
 * fit notes but performs NO range checks on the t-input
 * functions (Pref, hliq, hgas, hlat) and evaluates anyway.
 * This set enforces the source-stated table range at the
 * public boundary: t outside [-90, 239] degC throws an Error
 * with .code 'RANGE'.  CH3OH_Tsat carries no RANGE check: it
 * mirrors Python exactly -- P outside the Pref span over
 * [-90, 239] degC returns null (the pure-fluid Tsat span-null
 * precedent, cf. H2O_Tsat in the H2O set).  All internal
 * calls use the raw private implementations so the public
 * checks never corrupt the Python logic.
 * Per function:
 *   CH3OH_Pref : t outside [-90, 239] throws RANGE.
 *   CH3OH_Tsat : no RANGE; P outside [Pref(-90), Pref(239)]
 *              returns null; inside, 60 bisection steps.
 *   CH3OH_hliq : t outside [-90, 239] throws RANGE.
 *   CH3OH_hgas : t outside [-90, 239] throws RANGE.
 *   CH3OH_hlat : t outside [-90, 239] throws RANGE; value is
 *              raw hgas - raw hliq at the same t.
 */

// ---------------------------------------------------------------------------
// Coefficients (verbatim from pure_fluids.py, CH3OH section)
// ---------------------------------------------------------------------------

const _CH3OH_LNP = [6.071697789417314e-17, -4.474383382147671e-14, 1.4922332158687438e-11, -3.713389940921318e-09,
  9.643627950530163e-07, -0.00025454685882528256, 0.06310145783702696, -5.507805919357708];
const _CH3OH_hL = [5.573934158642428e-12, -1.8104866695124476e-09, 8.709794689054448e-08, 2.7396583808978296e-05,
  0.001358520746256356, 2.362545782283046, 100.0];
const _CH3OH_hV = [-1.228628960059207e-11, 4.469399531774273e-09, -3.1756317512396483e-07, -4.548213600653677e-05,
  0.002018557942790822, 1.156097552141014, 1301.565002270651];
const _CH3OH_TLO = -90.0;
const _CH3OH_THI = 239.0;

function domainError(code, message) {
  const e = new Error(message);
  e.code = code;
  return e;
}

function _checkT(fnName, t_C) {
  if (!(_CH3OH_TLO <= t_C && t_C <= _CH3OH_THI)) {
    throw domainError('RANGE',
      `${fnName}: t_C=${t_C} is outside the domain t_C in [-90, 239]`);
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
  return Math.exp(_poly7(_CH3OH_LNP, t_C));
}

function _hliq_raw(t_C) {
  return _poly6(_CH3OH_hL, t_C);
}

function _hgas_raw(t_C) {
  return _poly6(_CH3OH_hV, t_C);
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

/** CH3OH saturation pressure, MPa.  t_C in degC (NIST-table fit,
 *  lnP-t degree-7 polynomial).  t_C outside [-90, 239] throws
 *  RANGE. */
function CH3OH_Pref(t_C) {
  _checkT('CH3OH_Pref', t_C);
  return _lnp_pref_raw(t_C);
}

/** CH3OH saturation temperature, degC.  P_MPa in MPa.  Returns
 *  null when P lies outside the Pref span over [-90, 239] degC
 *  (mirrors Python; no RANGE check on P). */
function CH3OH_Tsat(P_MPa) {
  return _tsat_bisect(P_MPa, _lnp_pref_raw, _CH3OH_TLO, _CH3OH_THI);
}

/** CH3OH saturated-liquid enthalpy, kJ/kg.  Reference state:
 *  saturated liquid at 0 degC = 100 kJ/kg (after the shift).
 *  t_C outside [-90, 239] throws RANGE. */
function CH3OH_hliq(t_C) {
  _checkT('CH3OH_hliq', t_C);
  return _hliq_raw(t_C);
}

/** CH3OH saturated-vapour enthalpy, kJ/kg.  Reference state as
 *  for hliq (after the shift).  t_C outside [-90, 239] throws
 *  RANGE. */
function CH3OH_hgas(t_C) {
  _checkT('CH3OH_hgas', t_C);
  return _hgas_raw(t_C);
}

/** CH3OH saturation latent heat, kJ/kg = hgas - hliq (the shift
 *  cancels; independent of the table reference state).  t_C
 *  outside [-90, 239] throws RANGE. */
function CH3OH_hlat(t_C) {
  _checkT('CH3OH_hlat', t_C);
  return _hgas_raw(t_C) - _hliq_raw(t_C);
}

module.exports = {
  CH3OH_Pref, CH3OH_Tsat, CH3OH_hliq, CH3OH_hgas, CH3OH_hlat,
};

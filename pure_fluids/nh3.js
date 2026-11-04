'use strict';
/*
 * nh3.js -- NH3 (ammonia) pure-substance saturation properties
 * (JavaScript set of the absorption-working-pairs library;
 * companion to pure_fluids.py / .c / .bas, NH3 section).
 * ==========================================================================
 * Source
 * ------
 * Compact fits to the NIST WebBook saturation table for ammonia
 * (210 table points, -77 to 132 degC), adopted 2026-10-13; the
 * full fit notes are in pure_fluids/fit-notes/ and the summary
 * is in the pure_fluids formula notes (2026-10-13 supplement).
 *   Saturation pressure: lnP-t degree-7 polynomial,
 *     ln(P/MPa) = sum(c_k t^k, k = 0..7), t in degC; the form
 *     is natively in MPa, so this module returns MPa directly.
 *     Maximum deviation vs. the table: 0.0272 % over the full
 *     range, 0.0027 % over the usual band -50 to 60 degC; the
 *     full-range maximum sits at the critical end (132 degC,
 *     where the fit gives 11.278 MPa against the critical
 *     pressure 11.333 MPa).
 *   Saturated-liquid / saturated-vapour enthalpy: degree-6
 *     polynomials h(t), t in degC, kJ/kg.  Maximum deviations
 *     vs. the table over the usual band: hliq 2.05 kJ/kg,
 *     hgas 3.09 kJ/kg; deviations grow near the critical end
 *     (full-range maxima 29.29 / 43.42 kJ/kg, see the fit
 *     notes).
 *   Saturation temperature: inversion of Pref by 60 bisection
 *     steps, exactly as in the Python reference.
 * Spot checks in the fit notes show the source table agreeing
 * with CoolProp's reference equation of state to floating-point
 * tail digits, so only the fit residuals above are on account.
 *
 * Conventions
 * -----------
 * t  : temperature in degC.
 * P  : MPa at the public boundary (native unit of the fit; no
 *      conversion anywhere in this module).
 * h  : kJ/kg.
 * Function names are exactly the Python set's public names
 * for NH3; no aliases are kept.  Internal arithmetic and
 * coefficients are copied verbatim from pure_fluids.py; only
 * the domain discipline below is this set's own rendering of
 * the source-stated table range.  Python None is rendered as
 * null here.
 *
 * Reference state
 * ---------------
 * Saturated liquid at 0 degC = 100 kJ/kg (the library-wide
 * uniform datum).  The enthalpies have been shifted from the
 * NIST table's own datum to this datum by -244.768062686
 * kJ/kg (constant term only; the shift is already contained
 * in the coefficients below, and the latent heat
 * hlat = hgas - hliq is unchanged by it).  Unlike water, the
 * reference point 0 degC lies INSIDE the fitted band
 * [-77, 132] degC, so NH3_hliq(0) = 100 kJ/kg is served as an
 * ordinary in-band value.
 *
 * Domain discipline (designed divergence from Python)
 * ---------------------------------------------------
 * The Python set states the table range in its header and
 * fit notes but performs NO range checks on the t-input
 * functions (Pref, hliq, hgas, hlat) and evaluates anyway.
 * This set enforces the source-stated table range at the
 * public boundary: t outside [-77, 132] degC throws an Error
 * with .code 'RANGE'.  NH3_Tsat carries no RANGE check: it
 * mirrors Python exactly -- P outside the Pref span over
 * [-77, 132] degC returns null (the pure-fluid Tsat span-null
 * precedent, cf. H2O_Tsat in the H2O set).  All internal
 * calls use the raw private implementations so the public
 * checks never corrupt the Python logic.
 * Per function:
 *   NH3_Pref : t outside [-77, 132] throws RANGE.
 *   NH3_Tsat : no RANGE; P outside [Pref(-77), Pref(132)]
 *              returns null; inside, 60 bisection steps.
 *   NH3_hliq : t outside [-77, 132] throws RANGE.
 *   NH3_hgas : t outside [-77, 132] throws RANGE.
 *   NH3_hlat : t outside [-77, 132] throws RANGE; value is
 *              raw hgas - raw hliq at the same t.
 */

// ---------------------------------------------------------------------------
// Coefficients (verbatim from pure_fluids.py, NH3 section)
// ---------------------------------------------------------------------------

const _NH3_LNP = [1.1501679663496297e-16, -3.681466540446358e-14, 9.070213653911228e-12, -2.4759314474490567e-09,
  6.551063627525382e-07, -0.00015333383280607642, 0.03739502393748032, -0.8457026848887617];
const _NH3_hL = [1.0230389195910096e-10, -9.01173619674778e-09, -7.693180171285098e-07, 8.148925711345767e-05,
  0.0049020842504556555, 4.529640315972919, 100.0];
const _NH3_hV = [-1.5323246964436346e-10, 1.341154075047321e-08, 1.181178610537754e-06, -0.000132743256804236,
  -0.01090080493286388, 1.2129121114680004, 1364.0392422964662];
const _NH3_TLO = -77.0;
const _NH3_THI = 132.0;

function domainError(code, message) {
  const e = new Error(message);
  e.code = code;
  return e;
}

function _checkT(fnName, t_C) {
  if (!(_NH3_TLO <= t_C && t_C <= _NH3_THI)) {
    throw domainError('RANGE',
      `${fnName}: t_C=${t_C} is outside the domain t_C in [-77, 132]`);
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
  return Math.exp(_poly7(_NH3_LNP, t_C));
}

function _hliq_raw(t_C) {
  return _poly6(_NH3_hL, t_C);
}

function _hgas_raw(t_C) {
  return _poly6(_NH3_hV, t_C);
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

/** NH3 saturation pressure, MPa.  t_C in degC (NIST-table fit,
 *  lnP-t degree-7 polynomial).  t_C outside [-77, 132] throws
 *  RANGE. */
function NH3_Pref(t_C) {
  _checkT('NH3_Pref', t_C);
  return _lnp_pref_raw(t_C);
}

/** NH3 saturation temperature, degC.  P_MPa in MPa.  Returns
 *  null when P lies outside the Pref span over [-77, 132] degC
 *  (mirrors Python; no RANGE check on P). */
function NH3_Tsat(P_MPa) {
  return _tsat_bisect(P_MPa, _lnp_pref_raw, _NH3_TLO, _NH3_THI);
}

/** NH3 saturated-liquid enthalpy, kJ/kg.  Reference state:
 *  saturated liquid at 0 degC = 100 kJ/kg (after the shift).
 *  t_C outside [-77, 132] throws RANGE. */
function NH3_hliq(t_C) {
  _checkT('NH3_hliq', t_C);
  return _hliq_raw(t_C);
}

/** NH3 saturated-vapour enthalpy, kJ/kg.  Reference state as
 *  for hliq (after the shift).  t_C outside [-77, 132] throws
 *  RANGE. */
function NH3_hgas(t_C) {
  _checkT('NH3_hgas', t_C);
  return _hgas_raw(t_C);
}

/** NH3 saturation latent heat, kJ/kg = hgas - hliq (the shift
 *  cancels; independent of the table reference state).  t_C
 *  outside [-77, 132] throws RANGE. */
function NH3_hlat(t_C) {
  _checkT('NH3_hlat', t_C);
  return _hgas_raw(t_C) - _hliq_raw(t_C);
}

module.exports = {
  NH3_Pref, NH3_Tsat, NH3_hliq, NH3_hgas, NH3_hlat,
};

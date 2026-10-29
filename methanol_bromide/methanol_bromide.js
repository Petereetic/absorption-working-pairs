'use strict';
/*
 * methanol_bromide.js -- CH3OH-(2LiBr-ZnBr2) solution properties
 * (JavaScript set of the absorption-working-pairs library; companion
 * to methanol_bromide.py / .c / .bas).
 * ==========================================================================
 * Source
 * ------
 * S. El-Shamarka, "An investigation of methanol and inorganic
 * bromides for thermally operated heat pumps", PhD thesis,
 * Cranfield Institute of Technology, 1981:
 *   Eq. (3.1) Bubble-point pressure (thesis p.71; coefficient
 *             Table 3.3 on p.74):
 *             log10 P[mbar] = C1(w) + C2(w)*(1000/T[K] - 2.3),
 *             C1 and C2 tabulated at 8 composition nodes and
 *             interpolated between nodes by shape-preserving PCHIP
 *             (Fritsch-Carlson, same algorithm as scipy's
 *             PchipInterpolator).  The -C2 value at w = 28.0%
 *             (2.7278) breaks the monotonic trend (2.8197 at
 *             30.1%); it is kept as printed, and PCHIP has zero
 *             slope at that node, forming a local plateau with no
 *             overshoot.
 *   Eq. (3.4) Specific heat (p.86; restated in Appendix A, p.194):
 *             Cp[kJ/(kg degC)] = A + B*t[degC],
 *             A = 0.652 + 2.139w - 2.077w^2,
 *             B = -0.000205 + 0.00928w - 0.0101w^2.
 *             The sign of the last term of B is an overprinted glyph
 *             on p.86; Appendix A prints "-".  Measured Table 3.7
 *             values decide for "-": max deviation 0.7% with "-",
 *             6%~14% with "+".  This set takes "-", as in Python.
 *   Appendix A enthalpy of vaporisation H' (p.196, including the
 *             heat of mixing, from the vapour-pressure slope via
 *             Clausius-Clapeyron):
 *             H'[kJ/kg] = A + B*w + C*w^2,
 *             A = 2202.6 + 9.24T - 0.0218T^2,
 *             B = -(4417.8 + 15.53T - 0.0392T^2),
 *             C = 3570.0 + 10.81T - 0.0294T^2.
 *             T in this formula is in KELVIN (the data table on the
 *             same page is listed in degC).  The fit interval is
 *             only w approx. 0.25~0.356; extrapolation is forbidden
 *             (at w = 1 it gives 1672 kJ/kg, whereas the true value
 *             for pure methanol is about 1193).  The table cell at
 *             w = 35.6%, 110 degC is printed as 1221, breaking the
 *             smooth trend (neighbours 1352, 1288); suspected
 *             printing error; not used as a check point.
 *   Pure-methanol saturation line (Appendix A table, p.194):
 *             equilibrium temperatures of pure methanol at
 *             300~1000 mmHg, fitted by an Antoine equation to 7
 *             points from that table (the 400 mmHg row prints the
 *             methanol temperature as 373.1 K, contradicting the
 *             323.1 K back-computed from the Ratio column of that
 *             row and the fit value 323.13 K; judged a misprint and
 *             excluded):
 *             log10 P[mmHg] = A - B/(T + C),
 *             A = 8.885298, B = 2070.3714, C = 6.3818,
 *             max fit error 0.11%.
 *
 * System and conventions
 * ----------------------
 * The salt mixture ratio is FIXED at LiBr:ZnBr2 = 2:1 (molar
 * ratio); the whole thesis calls it "2LiBr-ZnBr2".  Changing the
 * salt ratio changes the system; this module does not apply.
 * w  : methanol MASS fraction (kg/kg), NOT a salt concentration.
 * T  : K at every public boundary (this pair's Python set is
 *      natively in K; no degC conversion is made here).
 * P  : MPa at every public boundary; internal native computation
 *      is in bar: private *_bar helpers carry the original
 *      formulas verbatim, public functions only scale at the
 *      boundary (MPa = bar x 0.1 on return, MPa x 10 on input).
 *      The _bar in the public names meoh_pref_bar / meoh_Tsat_bar
 *      is a retained HISTORICAL name; their public convention is
 *      actually MPa in / MPa out (see each function's note).
 * h  : kJ/kg; cp : kJ/(kg K).
 * The salt is non-volatile; the vapour phase is treated as pure
 * methanol, so the dew point is the pure-methanol saturation
 * temperature and there is no endpoint-convention issue.
 * Function names are exactly the Python set's public names; no
 * aliases are kept.  Internal arithmetic and coefficients are
 * copied verbatim from methanol_bromide.py; only the domain
 * discipline below is this set's own rendering of the
 * source-stated domains.  Python None is rendered as null here.
 *
 * Reference state (a convention of the formula notes; the thesis
 * defines no absolute datum for the solution enthalpy and uses
 * only enthalpy differences)
 * ----------------------------------------------------------------
 * hsol(0 degC, any w) = 100 kJ/kg, i.e.
 * hsol = 100 + integral(0 degC -> t) Cp dt = 100 + A*t + B*t^2/2.
 * The concentration dependence of the enthalpy enters the
 * vapour-phase enthalpy via h_prime:
 * hgas(T, w) = hsol(T, w) + H'(T, w), assembled the same way as in
 * the author's COP program.  This reference state must not be
 * mixed directly with other pairs in this library.
 *
 * Domain discipline (designed divergence from Python)
 * ---------------------------------------------------
 * The Python set states source ranges in its header but (except
 * for the no-root brackets of w_by_tsol_tdew and tsol_by_hsol,
 * which return None) performs NO range checks and evaluates
 * anyway.  This set enforces the source-stated domains at the
 * public boundary: an out-of-domain input throws an Error with
 * .code 'RANGE'.  All internal calls use the raw private
 * implementations so the public checks never corrupt the Python
 * logic.  Per function:
 *   psol_TW          : w outside [0.243, 0.509] throws RANGE;
 *                      T_K outside [288.15, 466.15] K (measured
 *                      approx. 15~193 degC) throws RANGE.
 *   T_bubble_PW      : w outside [0.243, 0.509] throws RANGE;
 *                      P_MPa <= 0 throws RANGE; a result T outside
 *                      [288.15, 466.15] K throws RANGE (result
 *                      check, following the nh3_lino3
 *                      T_bubble_PX precedent).
 *   cp               : w outside [0.249, 0.403] throws RANGE
 *                      (thesis-stated range of Eq. (3.4)); T has
 *                      no source-stated range and is not checked.
 *   h_prime          : w outside [0.25, 0.356] throws RANGE (hard
 *                      limit, extrapolation forbidden); T_K
 *                      outside [283.15, 472.15] K (table lists
 *                      10~199 degC) throws RANGE.
 *   hsol             : w outside [0.249, 0.403] throws RANGE (via
 *                      the Cp Eq. (3.4) domain); T is not checked.
 *   hgas             : w outside [0.25, 0.356] throws RANGE and
 *                      T_K outside [283.15, 472.15] K throws RANGE
 *                      (hgas = hsol + H'; the H' hard limit
 *                      dominates).
 *   meoh_pref_bar    : T_K outside [316.7, 345.4] K throws RANGE
 *                      (the Appendix A 300~1000 mmHg fit anchor
 *                      band).
 *   meoh_Tsat_bar    : P_MPa outside [0.039997, 0.133322] throws
 *                      RANGE.  These bounds are the 300~1000 mmHg
 *                      anchor band in MPa: with the Python factor
 *                      1.3332239e-3 bar per mmHg the exact values
 *                      are 300 mmHg = 0.039996717 MPa and
 *                      1000 mmHg = 0.13332239 MPa; the lower bound
 *                      0.039997 is the rounded value the Python
 *                      self-check itself uses for 300 mmHg, and
 *                      the upper bound 0.133322 is the exact value
 *                      rounded to 6 decimals.  The bounds enforced
 *                      here are exactly [0.039997, 0.133322].
 *   w_by_tsol_tdew   : Tsol_K outside [288.15, 466.15] K throws
 *                      RANGE; Tdew_K outside [316.7, 345.4] K
 *                      throws RANGE; otherwise mirrors Python
 *                      (80 bisection steps over w in
 *                      [0.243, 0.509], no root returns null).
 *   tdew_from_tsol_w : same T / w discipline as psol_TW (throws
 *                      RANGE); internally the raw path
 *                      _meoh_Tsat_bar(_psol_TW_bar(...)); the
 *                      result is not separately checked (mirrors
 *                      Python).
 *   tsol_by_hsol     : w outside [0.249, 0.403] throws RANGE;
 *                      h outside the raw hsol span over the
 *                      bracket T in [233.15, 423.15] K returns null
 *                      (mirrors Python, 100 bisection steps);
 *                      internal hsol calls use the raw version
 *                      (the raw hsol itself performs no w check;
 *                      the public function checks w first, then
 *                      bisects).
 *
 * Not ported
 * ----------
 * density_printed_UNVERIFIED and viscosity_eq411_UNVERIFIED
 * (El-Shamarka Eq. (4.10) density as printed and Eq. (4.11)
 * viscosity from damaged OCR) are unverified archival functions
 * in the Python set and are NOT ported (following the NH3-LiNO3
 * viscosity precedent: an unverified correlation is not shipped).
 * The Iedema 1984 density / viscosity correlations exist only in
 * the C/VBA sets; the Python set does not carry them, so they are
 * outside this round's Python reference source and are NOT ported
 * here either.
 */

// ---------------------------------------------------------------------------
// Coefficients (verbatim from methanol_bromide.py)
// ---------------------------------------------------------------------------

// Table 3.3 (p.74): node compositions (methanol mass fractions)
// and C1, C2 (C2 takes negative values)
const _W_NODES = [0.243, 0.250, 0.262, 0.280, 0.301, 0.356, 0.403, 0.509];
const _C1_NODES = [2.6712, 2.8572, 2.9758, 3.0535, 3.3146, 3.4604, 3.7770, 4.0494];
const _C2_NODES = [-3.0602, -3.0344, -2.9531, -2.7278, -2.8197, -2.6219, -2.4256, -2.0194];

// Pure-methanol saturation line: Antoine fit to the table in
// Appendix A of the thesis (see the header note)
const _MEOH_ANT = [8.885298, 2070.3714, 6.3818];  // log10 P[mmHg], T[K]; error <=0.11% within 300~1000 mmHg

function domainError(code, message) {
  const e = new Error(message);
  e.code = code;
  return e;
}

// ---------------------------------------------------------------------------
// Raw private implementations (no range checks, mirroring Python)
// ---------------------------------------------------------------------------

function _pchip_end_slope(h0, h1, d0, d1) {
  const m = ((2.0 * h0 + h1) * d0 - h0 * d1) / (h0 + h1);
  if (m * d0 <= 0.0) {
    return 0.0;
  }
  if (d0 * d1 < 0.0 && Math.abs(m) > Math.abs(3.0 * d0)) {
    return 3.0 * d0;
  }
  return m;
}

/** Fritsch-Carlson PCHIP (same algorithm as scipy's
 *  PchipInterpolator), verbatim from the Python set. */
function _pchip_eval(xs, ys, x) {
  const n = xs.length;
  const h = [], d = [];
  for (let i = 0; i < n - 1; i++) {
    h.push(xs[i + 1] - xs[i]);
    d.push((ys[i + 1] - ys[i]) / h[i]);
  }
  const m = new Array(n).fill(0.0);
  for (let i = 1; i < n - 1; i++) {
    if (d[i - 1] * d[i] <= 0.0) {
      m[i] = 0.0;
    } else {
      const w1 = 2.0 * h[i] + h[i - 1];
      const w2 = h[i] + 2.0 * h[i - 1];
      m[i] = (w1 + w2) / (w1 / d[i - 1] + w2 / d[i]);
    }
  }
  m[0] = _pchip_end_slope(h[0], h[1], d[0], d[1]);
  m[n - 1] = _pchip_end_slope(h[n - 2], h[n - 3], d[n - 2], d[n - 3]);
  let idx;
  if (x <= xs[0]) {
    idx = 0;
  } else if (x >= xs[n - 1]) {
    idx = n - 2;
  } else {
    let lo = 0, hi = n - 1;
    while (hi - lo > 1) {
      const mid = Math.floor((lo + hi) / 2);
      if (xs[mid] <= x) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    idx = lo;
  }
  const s = (x - xs[idx]) / h[idx];
  const s2 = s * s, s3 = s2 * s;
  return ((2.0 * s3 - 3.0 * s2 + 1.0) * ys[idx]
        + h[idx] * (s3 - 2.0 * s2 + s) * m[idx]
        + (3.0 * s2 - 2.0 * s3) * ys[idx + 1]
        + h[idx] * (s3 - s2) * m[idx + 1]);
}

function _c1(w) {
  return _pchip_eval(_W_NODES, _C1_NODES, w);
}

function _c2(w) {
  return _pchip_eval(_W_NODES, _C2_NODES, w);
}

/** Eq. (3.1) native value (private): bubble-point pressure, bar. */
function _psol_TW_bar(T_K, w) {
  const log10p_mbar = _c1(w) + _c2(w) * (1000.0 / T_K - 2.3);
  return Math.pow(10.0, log10p_mbar) / 1000.0;
}

/** Eq. (3.1) analytic inverse, native value (private):
 *  bubble-point temperature, K. P_bar in bar. */
function _T_bubble_PW_bar(P_bar, w) {
  const log10p_mbar = Math.log10(P_bar * 1000.0);
  return 1000.0 / ((log10p_mbar - _c1(w)) / _c2(w) + 2.3);
}

function _cp_AB(w) {
  const A = 0.652 + 2.139 * w - 2.077 * w * w;
  const B = -0.000205 + 0.00928 * w - 0.0101 * w * w;
  return [A, B];
}

/** Eq. (3.4) raw: solution specific heat, kJ/(kg K). */
function _cp_raw(T_K, w) {
  const [A, B] = _cp_AB(w);
  return A + B * (T_K - 273.15);
}

/** Appendix A H' raw: enthalpy of vaporisation, kJ/kg. */
function _h_prime_raw(T_K, w) {
  const A = 2202.6 + 9.24 * T_K - 0.0218 * T_K * T_K;
  const B = -(4417.8 + 15.53 * T_K - 0.0392 * T_K * T_K);
  const C = 3570.0 + 10.81 * T_K - 0.0294 * T_K * T_K;
  return A + B * w + C * w * w;
}

/** Solution specific enthalpy raw, kJ/kg. */
function _hsol_raw(T_K, w) {
  const [A, B] = _cp_AB(w);
  const t = T_K - 273.15;
  return 100.0 + A * t + B * t * t / 2.0;
}

/** Native value of the pure-methanol saturation pressure
 *  (private): bar (Antoine, fitted to Appendix A of the thesis). */
function _meoh_pref_bar_raw(T_K) {
  const A = _MEOH_ANT[0], B = _MEOH_ANT[1], C = _MEOH_ANT[2];
  return Math.pow(10.0, A - B / (T_K + C)) * 1.3332239e-3;
}

/** Native value of the pure-methanol saturation temperature
 *  (private): K, P_bar in bar (analytic inverse of Antoine). */
function _meoh_Tsat_bar_raw(P_bar) {
  const A = _MEOH_ANT[0], B = _MEOH_ANT[1], C = _MEOH_ANT[2];
  return B / (A - Math.log10(P_bar / 1.3332239e-3)) - C;
}

// ---------------------------------------------------------------------------
// Public functions (MPa boundary, Python names verbatim)
// ---------------------------------------------------------------------------

/** Eq. (3.1): bubble-point pressure [MPa].  T_K in kelvin, w
 *  methanol mass fraction.  w outside [0.243, 0.509] or T_K
 *  outside [288.15, 466.15] K throws RANGE. */
function psol_TW(T_K, w) {
  if (!(0.243 <= w && w <= 0.509)) {
    throw domainError('RANGE',
      `psol_TW: w=${w} is outside the domain w in [0.243, 0.509]`);
  }
  if (!(288.15 <= T_K && T_K <= 466.15)) {
    throw domainError('RANGE',
      `psol_TW: T_K=${T_K} is outside the domain T_K in [288.15, 466.15]`);
  }
  return _psol_TW_bar(T_K, w) * 0.1;
}

/** Eq. (3.1) analytic inverse: bubble-point temperature [K].
 *  P_MPa in MPa, w methanol mass fraction.  w outside
 *  [0.243, 0.509], P_MPa <= 0, or a result T outside
 *  [288.15, 466.15] K throws RANGE. */
function T_bubble_PW(P_MPa, w) {
  if (!(0.243 <= w && w <= 0.509)) {
    throw domainError('RANGE',
      `T_bubble_PW: w=${w} is outside the domain w in [0.243, 0.509]`);
  }
  if (!(P_MPa > 0.0)) {
    throw domainError('RANGE', 'T_bubble_PW: P_MPa must be > 0');
  }
  const T_K = _T_bubble_PW_bar(P_MPa * 10.0, w);
  if (!(288.15 <= T_K && T_K <= 466.15)) {
    throw domainError('RANGE',
      `T_bubble_PW: result T=${T_K} K is outside the domain ` +
      'T_K in [288.15, 466.15]');
  }
  return T_K;
}

/** Eq. (3.4): solution specific heat [kJ/(kg K)].  t = T_K -
 *  273.15 (degC).  w outside [0.249, 0.403] throws RANGE; T is
 *  not checked (no source-stated range). */
function cp(T_K, w) {
  if (!(0.249 <= w && w <= 0.403)) {
    throw domainError('RANGE',
      `cp: w=${w} is outside the domain w in [0.249, 0.403]`);
  }
  return _cp_raw(T_K, w);
}

/** Appendix A: enthalpy of vaporisation of the solution H'
 *  (including the heat of mixing) [kJ/kg].  T_K in kelvin (never
 *  use degC).  w outside [0.25, 0.356] throws RANGE (hard limit,
 *  extrapolation forbidden); T_K outside [283.15, 472.15] K
 *  throws RANGE. */
function h_prime(T_K, w) {
  if (!(0.25 <= w && w <= 0.356)) {
    throw domainError('RANGE',
      `h_prime: w=${w} is outside the domain w in [0.25, 0.356]`);
  }
  if (!(283.15 <= T_K && T_K <= 472.15)) {
    throw domainError('RANGE',
      `h_prime: T_K=${T_K} is outside the domain T_K in [283.15, 472.15]`);
  }
  return _h_prime_raw(T_K, w);
}

/** Solution specific enthalpy [kJ/kg].  Reference state:
 *  hsol(0 degC, any w) = 100 kJ/kg.  w outside [0.249, 0.403]
 *  throws RANGE; T is not checked. */
function hsol(T_K, w) {
  if (!(0.249 <= w && w <= 0.403)) {
    throw domainError('RANGE',
      `hsol: w=${w} is outside the domain w in [0.249, 0.403]`);
  }
  return _hsol_raw(T_K, w);
}

/** Vapour-phase specific enthalpy [kJ/kg]: hgas = hsol + H'
 *  (the vapour phase is pure methanol vapour; H' already
 *  includes the heat-of-mixing correction).  w outside
 *  [0.25, 0.356] or T_K outside [283.15, 472.15] K throws RANGE
 *  (the H' hard limit dominates).  Internal calls use the raw
 *  versions. */
function hgas(T_K, w) {
  if (!(0.25 <= w && w <= 0.356)) {
    throw domainError('RANGE',
      `hgas: w=${w} is outside the domain w in [0.25, 0.356]`);
  }
  if (!(283.15 <= T_K && T_K <= 472.15)) {
    throw domainError('RANGE',
      `hgas: T_K=${T_K} is outside the domain T_K in [283.15, 472.15]`);
  }
  return _hsol_raw(T_K, w) + _h_prime_raw(T_K, w);
}

/** Pure-methanol saturation pressure [MPa] (Antoine, fitted to
 *  the data points of Appendix A of the thesis).  The _bar in
 *  the function name is a retained historical name; the return
 *  value is actually MPa.  T_K outside [316.7, 345.4] K throws
 *  RANGE. */
function meoh_pref_bar(T_K) {
  if (!(316.7 <= T_K && T_K <= 345.4)) {
    throw domainError('RANGE',
      `meoh_pref_bar: T_K=${T_K} is outside the domain ` +
      'T_K in [316.7, 345.4]');
  }
  return _meoh_pref_bar_raw(T_K) * 0.1;
}

/** Pure-methanol saturation temperature [K] (analytic inverse of
 *  the above).  P_MPa in MPa; the _bar in the function name is a
 *  retained historical name; the input is actually MPa.  P_MPa
 *  outside [0.039997, 0.133322] throws RANGE (the 300~1000 mmHg
 *  anchor band; see the header note for the exact conversion). */
function meoh_Tsat_bar(P_MPa) {
  if (!(0.039997 <= P_MPa && P_MPa <= 0.133322)) {
    throw domainError('RANGE',
      `meoh_Tsat_bar: P_MPa=${P_MPa} is outside the domain ` +
      'P_MPa in [0.039997, 0.133322]');
  }
  return _meoh_Tsat_bar_raw(P_MPa * 10.0);
}

/** Solve the methanol mass fraction w back from the dew-point
 *  temperature and the solution temperature.  Dew-point pressure:
 *  P = _meoh_pref_bar_raw(Tdew_K) (internal native value in bar);
 *  then 80 bisection steps invert _psol_TW_bar(Tsol_K, w) = P,
 *  with the bracket w = 0.243~0.509.  Tsol_K outside
 *  [288.15, 466.15] K or Tdew_K outside [316.7, 345.4] K throws
 *  RANGE; otherwise returns null when there is no root (P outside
 *  the span of bubble-point pressures under Tsol), mirroring
 *  Python. */
function w_by_tsol_tdew(Tsol_K, Tdew_K) {
  if (!(288.15 <= Tsol_K && Tsol_K <= 466.15)) {
    throw domainError('RANGE',
      `w_by_tsol_tdew: Tsol_K=${Tsol_K} is outside the domain ` +
      'Tsol_K in [288.15, 466.15]');
  }
  if (!(316.7 <= Tdew_K && Tdew_K <= 345.4)) {
    throw domainError('RANGE',
      `w_by_tsol_tdew: Tdew_K=${Tdew_K} is outside the domain ` +
      'Tdew_K in [316.7, 345.4]');
  }
  const P = _meoh_pref_bar_raw(Tdew_K);
  const Plo = _psol_TW_bar(Tsol_K, _W_NODES[0]);
  const Phi = _psol_TW_bar(Tsol_K, _W_NODES[_W_NODES.length - 1]);
  if (!(Plo <= P && P <= Phi)) {
    return null;
  }
  let lo = _W_NODES[0], hi = _W_NODES[_W_NODES.length - 1];
  for (let i = 0; i < 80; i++) {
    const mid = 0.5 * (lo + hi);
    if (_psol_TW_bar(Tsol_K, mid) < P) {
      lo = mid;
    } else {
      hi = mid;
    }
  }
  return 0.5 * (lo + hi);
}

/** Dew-point temperature [K] of the solution at (T_K, w):
 *  Tdew = meoh_Tsat_bar(psol_TW(T_K, w)) in public MPa terms;
 *  internally the raw path
 *  _meoh_Tsat_bar_raw(_psol_TW_bar(...)).  Same T / w discipline
 *  as psol_TW (throws RANGE); the result is not separately
 *  checked (mirrors Python). */
function tdew_from_tsol_w(T_K, w) {
  if (!(0.243 <= w && w <= 0.509)) {
    throw domainError('RANGE',
      `tdew_from_tsol_w: w=${w} is outside the domain w in [0.243, 0.509]`);
  }
  if (!(288.15 <= T_K && T_K <= 466.15)) {
    throw domainError('RANGE',
      `tdew_from_tsol_w: T_K=${T_K} is outside the domain ` +
      'T_K in [288.15, 466.15]');
  }
  return _meoh_Tsat_bar_raw(_psol_TW_bar(T_K, w));
}

/** Solve the solution temperature [K] back from the solution
 *  specific enthalpy h [kJ/kg] and methanol mass fraction w:
 *  100 bisection steps, with the solution bracket T in
 *  [233.15, 423.15] K.  w outside [0.249, 0.403] throws RANGE;
 *  h outside the raw hsol span at w returns null (mirrors
 *  Python).  Internal hsol calls use the raw version. */
function tsol_by_hsol(h, w) {
  if (!(0.249 <= w && w <= 0.403)) {
    throw domainError('RANGE',
      `tsol_by_hsol: w=${w} is outside the domain w in [0.249, 0.403]`);
  }
  const lo = 233.15, hi = 423.15;
  const hlo = _hsol_raw(lo, w), hhi = _hsol_raw(hi, w);
  if (!(hlo <= h && h <= hhi)) {
    return null;
  }
  let a = lo, b = hi;
  for (let i = 0; i < 100; i++) {
    const mid = 0.5 * (a + b);
    if (_hsol_raw(mid, w) < h) {
      a = mid;
    } else {
      b = mid;
    }
  }
  return 0.5 * (a + b);
}

module.exports = {
  psol_TW, T_bubble_PW, cp, h_prime, hsol, hgas,
  meoh_pref_bar, meoh_Tsat_bar, w_by_tsol_tdew,
  tdew_from_tsol_w, tsol_by_hsol,
};

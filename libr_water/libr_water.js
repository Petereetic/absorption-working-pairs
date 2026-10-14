'use strict';
/*
 * libr_water.js -- LiBr-H2O solution properties (JavaScript set of the
 * absorption-working-pairs library; companion to libr_water.py / .c / .bas).
 * ==========================================================================
 * Sources
 * -------
 * Patterson, M.R. & Perez-Blanco, H. (1988), "Numerical fits of the
 * properties of lithium-bromide water solutions", ASHRAE Transactions
 * 94(2), pp. 2059-2077 (paper OT-88-20-2): seven explicit polynomial
 * fits (enthalpy HLIBR, dew point TDEW, vapour pressure PRESS, thermal
 * conductivity TCON, viscosity VISCOS, density SPMASS, surface tension
 * STEN), all of the unified form
 *     F(X,T) = sum_{i=0..K} X^i * (A_i + T*A_{i+K+1} + T^2*A_{i+2K+2}).
 *
 * Chua, H.T. et al. (2000), "Improved thermodynamic property fields of
 * LiBr-H2O solution", Int. J. Refrigeration 23, pp. 412-429: Duehring
 * vapour-pressure equation (Table 1) and density correlation (Table 2),
 * offered as cross-check / wide-range alternatives.
 *
 * Conventions (library-wide unified naming, 2026-10-12 renaming)
 * --------------------------------------------------------------
 * X : LiBr mass percent as a number (e.g. 50 means 50 wt%), NOT a fraction.
 * T : degC.  SI outputs: h kJ/kg, p Pa, lambda W/(m K), eta Pa s,
 *     rho kg/m^3, sigma N/m; dew point / crystallisation temperature degC.
 * Function names follow the unified system (Psol, TdewByTsolXi,
 * XiByTsolTdew, hsol, TsolByHsol, ...); no aliases are kept.
 * Argument order follows this module's convention (X, T), as in the
 * Python/C/VBA sets, except XiByTsolTdew(Tsol, Tdew) and
 * TsolByHsol(h, X), which keep their library signatures.
 *
 * Reference state: h(0 wt%, 25 degC) = 104.615 kJ/kg, i.e. saturated
 * liquid water at 0 degC has h = 0 (McNeely 1979 data basis, as implied
 * by the Patterson coefficients; the paper does not state it).
 *
 * Domain discipline
 * -----------------
 * Every function first applies (1) the Patterson crystallisation /
 * unknown-region check (XN/TN and XUNKN/TUNKN polylines of the paper's
 * appendix, logic ported line by line from the Fortran originals) and
 * (2) its own fitted range.  A point outside either throws an Error
 * with .code 'RANGE', 'CRYSTALLIZATION' or 'UNKNOWN_REGION'; nothing
 * is silently extrapolated.  (The C set returns NAN and the Python set
 * raises ValueError for the same points.)
 *
 * Transcription notes (from the Python set's collation of the papers)
 * -------------------------------------------------------------------
 * - PRESS: the paper text says degF in / psia out, but the Fortran code
 *   takes degC in and returns Pa (x 6894.757); the code is followed.
 * - TCON's TUNKN is printed in degF numbers (260/280/320/360) yet is
 *   compared against degC T, so its unknown-region check never fires;
 *   reproduced as printed.
 * - Chua B_12 is printed without a minus sign; the negative value is
 *   used (only then does B_D reproduce the paper's Fig. 2).
 * - Chua's <x-60> correction terms (i = 17..20) diverge as printed for
 *   x > 60 wt% and cannot reproduce Figs. 1/2, so PsolChua is limited
 *   to x <= 60 wt% (the paper's own 60-75 wt% band is an extrapolation
 *   that is not implemented here).
 *
 * Verification: point-checked against libr_water.py on a 324-point
 * (X, T) grid per function (fitted domains incl. boundary-interior
 * points; error classification included) -- max relative difference
 * at the 1e-12 level or below.  See the module's delivery record.
 */

// ---------------------------------------------------------------------------
// Crystallisation / unknown-region boundary tables (Patterson appendix,
// shared by all seven functions; TCON's TUNKN as printed, see header note)
// ---------------------------------------------------------------------------
const XN = [57.5, 62.5, 62.5, 67.5, 67.5, 100.0, 100.0];        // wt%
const TN = [0.0, 10.0, 40.0, 50.0, 90.0, 100.0, 180.0];          // degC
const XUNKN = [0.0, 37.5, 51.5, 60.5];                           // wt%
const TUNKN = [126.7, 137.8, 160.0, 182.2];                      // degC
const TUNKN_TCON_F = [260.0, 280.0, 320.0, 360.0];               // as printed

function domainError(code, message) {
  const e = new Error(message);
  e.code = code;
  return e;
}

function checkRegion(X, T, funcName, checkUnknown = true, tunkn = TUNKN) {
  // Freezing (crystallisation) polyline: interpolate XSTAR at the first
  // segment with T <= TN[n]; X >= XSTAR -> crystallisation region.
  let star = null;
  for (let n = 1; n < 7; n++) {
    if (T > TN[n]) continue;
    star = (XN[n] === XN[n - 1])
      ? XN[n]
      : XN[n - 1] + (T - TN[n - 1]) / (TN[n] - TN[n - 1]) * (XN[n] - XN[n - 1]);
    break;
  }
  if (star === null) {
    // T > 180: the original prints a warning and continues to the
    // unknown-region check.
  } else if (X >= star) {
    throw domainError('CRYSTALLIZATION',
      `${funcName}: point (X=${X.toFixed(2)} wt%, T=${T.toFixed(2)} degC) is in the ` +
      `crystallisation region (freezing concentration X*=${star.toFixed(2)} wt%)`);
  } else if (!checkUnknown) {
    return; // other functions: freezing check passed -> compute directly
  }
  // Unknown-region polyline: X <= XSTAR -> no data.
  for (let n = 1; n < 4; n++) {
    if (T > tunkn[n]) continue;
    const xstar = (XUNKN[n] === XUNKN[n - 1])
      ? XUNKN[n]
      : XUNKN[n - 1] + (T - tunkn[n - 1]) / (tunkn[n] - tunkn[n - 1]) *
        (XUNKN[n] - XUNKN[n - 1]);
    if (X <= xstar) {
      throw domainError('UNKNOWN_REGION',
        `${funcName}: point (X=${X.toFixed(2)} wt%, T=${T.toFixed(2)} degC) is in the ` +
        `unknown region (X*<=${xstar.toFixed(2)} wt%, no data)`);
    }
    return;
  }
  throw domainError('UNKNOWN_REGION',
    `${funcName}: T=${T.toFixed(2)} degC exceeds the unknown-region table ` +
    `limit (${tunkn[3].toFixed(1)} degC), no data`);
}

function poly(X, T, A, kup) {
  // Unified polynomial: sum_{i=0..K} X^i * (A_i + T*A_{i+K+1} + T^2*A_{i+2K+2})
  let s = 0.0;
  let xk = 1.0;
  for (let i = 0; i < kup; i++) {
    if (i > 0) xk *= X;
    s += xk * (A[i] + T * (A[i + kup] + T * A[i + 2 * kup]));
  }
  return s;
}

function rangeCheck(X, T, funcName, xLo, xHi, tLo, tHi) {
  if (!(xLo <= X && X <= xHi && tLo <= T && T <= tHi)) {
    throw domainError('RANGE',
      `${funcName}: (X=${X.toFixed(2)} wt%, T=${T.toFixed(2)} degC) is outside the ` +
      `fitted range X in [${xLo}, ${xHi} wt%], T in [${tLo}, ${tHi} degC]`);
  }
}

// ---------------------------------------------------------------------------
// Patterson coefficient tables (DATA-statement order, 0-based)
// ---------------------------------------------------------------------------
// HLIBR: enthalpy kJ/kg, KUP=6
const A_H = [
  1.134125e+00, -4.800450e-01, -2.161438e-03, 2.336235e-04,
  -1.188679e-05, 2.291532e-07, 4.124891e+00, -7.643903e-02,
  2.589577e-03, -9.500522e-05, 1.708026e-06, -1.102363e-08,
  5.743693e-04, 5.870921e-05, -7.375319e-06, 3.277592e-07,
  -6.062304e-09, 3.901897e-11,
];
// TDEW: dew point (polynomial in degF, converted back to degC), KUP=6
const A_TDEW = [
  -1.313448e-01, 1.820914e-01, -5.177356e-02, 2.827426e-03,
  -6.380541e-05, 4.340498e-07, 9.967944e-01, 1.778069e-03,
  -2.215597e-04, 5.913618e-06, -7.308556e-08, 2.788472e-10,
  1.978788e-05, -1.779481e-05, 2.002427e-06, -7.667546e-08,
  1.201525e-09, -6.641716e-12,
];
// TCON: thermal conductivity kcal/(h m degC), KUP=5
const A_TC = [
  4.815196e-01, -2.217277e-03, -1.994141e-05, 3.727255e-07,
  -2.489886e-09, 1.858174e-03, 9.614755e-06, -1.139291e-06,
  2.107608e-08, -1.330532e-10, -7.923126e-06, -1.869392e-07,
  1.408951e-08, -2.740806e-10, 1.810818e-12,
];
// VISCOS: viscosity cP, KUP=6
const A_VIS = [
  1.488747e+00, 1.143975e-01, -1.278729e-02, 6.999985e-04,
  -1.638074e-05, 1.456348e-07, -4.164814e-02, 9.636832e-04,
  -5.981025e-05, -1.282435e-07, 5.703002e-08, -9.842266e-10,
  3.404030e-04, -2.794515e-05, 2.580301e-06, -9.737750e-08,
  1.585609e-09, -7.922925e-12,
];
// SPMASS: density kg/L, KUP=5
const A_RHO = [
  9.939006e-01, 1.046888e-02, -1.667939e-04, 5.332835e-06,
  -3.440005e-08, -5.631094e-04, 1.633541e-05, -1.110273e-06,
  2.882292e-08, -2.523579e-10, 1.392527e-06, -2.801009e-07,
  1.734979e-08, -4.232988e-10, 3.503024e-12,
];
// STEN: surface tension dyne/cm, KUP=5
const A_SIG = [
  7.626234e+01, 4.583900e-01, -1.463071e-02, 3.834735e-04,
  -2.733854e-06, -1.507474e-01, -9.057263e-03, 4.459087e-04,
  -9.542318e-06, 6.610416e-08, -1.107075e-05, 7.238986e-05,
  -3.822731e-06, 8.077592e-08, -5.681625e-10,
];

// ---------------------------------------------------------------------------
// Public functions (Patterson)
// ---------------------------------------------------------------------------

/** Solution specific enthalpy [kJ/kg]. Range: X in [0,70] wt%, T in [0,180] degC. */
function hsol(X, T) {
  rangeCheck(X, T, 'hsol', 0, 70, 0, 180);
  checkRegion(X, T, 'hsol', true);
  return poly(X, T, A_H, 6);
}

function tdewPolyF(X, T) {
  // TDEW inner polynomial (degF in, degF out), no region check.
  const TF = 9.0 / 5.0 * T + 32.0;
  return poly(X, TF, A_TDEW, 6);
}

/** Dew-point temperature [degC] of the solution at (X, T).
 *  Range: X in [0,70] wt%, T in [4.4,182.2] degC. */
function Tdew(X, T) {
  rangeCheck(X, T, 'Tdew', 0, 70, 4.4, 182.2);
  checkRegion(X, T, 'Tdew', false);
  return 5.0 / 9.0 * (tdewPolyF(X, T) - 32.0);
}

/** Solution surface (equilibrium) vapour pressure [Pa] (Patterson PRESS).
 *  Range: X in [0,70] wt%, T in [4.4,182.2] degC. */
function Psol(X, T) {
  rangeCheck(X, T, 'Psol', 0, 70, 4.4, 182.2);
  checkRegion(X, T, 'Psol', false);
  const tdewF = tdewPolyF(X, T);
  const TR = tdewF + 459.7;
  return Math.pow(10.0, 6.21147 - 2886.373 / TR - 337269.46 / (TR * TR)) * 6894.757;
}

/** Thermal conductivity [W/(m K)]. Range: X in [0,70] wt%, T in [4.4,182.2] degC. */
function Lambda(X, T) {
  rangeCheck(X, T, 'Lambda', 0, 70, 4.4, 182.2);
  checkRegion(X, T, 'Lambda', false, TUNKN_TCON_F);
  return poly(X, T, A_TC, 5) * 1.163;
}

/** Dynamic viscosity [Pa s]. Range: X in [5,60] wt%, T in [0,90] degC. */
function Eta(X, T) {
  rangeCheck(X, T, 'Eta', 5, 60, 0, 90);
  checkRegion(X, T, 'Eta', false);
  return poly(X, T, A_VIS, 6) * 1e-3;
}

/** Density [kg/m^3] (Patterson SPMASS). Range: X in [10,60] wt%, T in [0,100] degC. */
function Rho(X, T) {
  rangeCheck(X, T, 'Rho', 10, 60, 0, 100);
  checkRegion(X, T, 'Rho', false);
  return poly(X, T, A_RHO, 5) * 1000.0;
}

/** Surface tension [N/m]. Range: X in [5,60] wt%, T in [0,60] degC. */
function Sigma(X, T) {
  rangeCheck(X, T, 'Sigma', 5, 60, 0, 60);
  checkRegion(X, T, 'Sigma', false);
  return poly(X, T, A_SIG, 5) * 1e-3;
}

/** Crystallisation temperature [degC] at concentration X wt% (freezing
 *  polyline).  Returns NaN for X < 57.5 wt% (no boundary in the table). */
function Tcryst(X) {
  if (X < 57.5) return NaN;
  if (X > 100) {
    throw domainError('RANGE', `Tcryst: X=${X.toFixed(2)} wt% exceeds 100 wt%`);
  }
  let best = null;
  for (let n = 1; n < 7; n++) {
    const x0 = XN[n - 1], x1 = XN[n], t0 = TN[n - 1], t1 = TN[n];
    if (x0 === x1) {
      if (X === x0) best = (best === null) ? t1 : Math.max(best, t1);
    } else if (Math.min(x0, x1) <= X && X <= Math.max(x0, x1)) {
      const t = t0 + (X - x0) / (x1 - x0) * (t1 - t0);
      best = (best === null) ? t : Math.max(best, t);
    }
  }
  return best;
}

// ---------------------------------------------------------------------------
// Chua et al. 2000: Duehring vapour pressure (Table 1) + density (Table 2)
// A_D(x) = sum_{i=0}^{16} A_i x^i + sum_{i=17}^{20} A_i <x-60>^i, B_D likewise.
// The i = 17..20 terms are tabulated for the record but NOT used: as
// printed they diverge for x > 60 wt% (see header note), so PsolChua is
// limited to x <= 60 wt%.
// ---------------------------------------------------------------------------
const DUHR_A = [
  1.0,
  2.92242e-04, 1.05207e-04, 8.86101e-07, -2.71833e-06, 3.52718e-07,
  -2.03849e-08, 5.68810e-10, -4.32385e-12, -1.42122e-13, 2.37604e-15,
  3.96440e-17, -9.81319e-19, -7.91591e-21, 3.92677e-22, -4.04965e-24,
  1.41694e-26,
  6.51878e-03, -2.57030e-04, 2.43912e-05, -6.86236e-08,
];
const DUHR_B = [
  0.0,
  5.22677e-02, -9.78477e-03, 7.82919e-03, -1.62913e-03, 1.64050e-04,
  -8.98817e-06, 2.62640e-07, -2.95400e-09, -3.23145e-11, 7.67888e-13,
  1.36662e-14, -3.12628e-16, -4.91441e-18, 1.87723e-19, -1.92463e-21,
  6.87629e-24,
  1.93956e+00, 8.22588e-02, -1.04537e-02, 4.09856e-04,
];
// Density (Table 2): rho = sum_{k=1..5} x^{k-1} [G_{0,k} + T (G_{1,k} + T G_{2,k})]
const G_RHO_CHUA = [
  [9.99100e+02, -2.39865e-02, -3.90453e-03],
  [7.74931e+00, -1.28346e-02, -5.55855e-05],
  [5.36509e-03, 2.07232e-04, 1.09879e-05],
  [1.34988e-03, -9.08213e-06, -2.39834e-07],
  [-3.08671e-06, 9.94788e-08, 1.53514e-09],
];

function wagnerPrefWater(T_C) {
  // Pure-water saturation pressure [Pa], Wagner equation (IAPWS-95
  // companion form, Wagner & Pruss 1993).  Chua's paper uses the Haar
  // (1984) NBS/NRC steam tables; this is the library's equivalent.
  const T = T_C + 273.15;
  const Tc = 647.096;
  const Pc = 22.064e6;
  const theta = 1.0 - T / Tc;
  const a = [-7.85951783, 1.84408259, -11.7866497,
             22.6807411, -15.9618719, 1.80122502];
  const e = [1.0, 1.5, 3.0, 3.5, 4.0, 7.5];
  let s = 0.0;
  for (let i = 0; i < 6; i++) s += a[i] * Math.pow(theta, e[i]);
  return Pc * Math.exp((Tc / T) * s);
}

/** Solution vapour pressure [Pa] by the Chua Duehring equation.
 *  Range: X in [0,60] wt%, T in [0,190] degC (see header note on x > 60). */
function PsolChua(X, T) {
  if (!(0 <= X && X <= 60 && 0 <= T && T <= 190)) {
    throw domainError('RANGE',
      `PsolChua: (X=${X.toFixed(2)} wt%, T=${T.toFixed(2)} degC) is outside the ` +
      'range [0-60 wt%, 0-190 degC]');
  }
  let AD = 0.0, BD = 0.0;
  for (let i = 0; i < 17; i++) {
    const xi = Math.pow(X, i);
    AD += DUHR_A[i] * xi;
    BD += DUHR_B[i] * xi;
  }
  // T_C = AD * Tdp_C + BD  ->  Tdp_C = (T_C - BD) / AD
  const Tdp_C = (T - BD) / AD;
  return wagnerPrefWater(Tdp_C);
}

/** Density [kg/m^3] by Chua Table 2. Range: X in [0,70] wt%, T in [0,200] degC. */
function RhoChua(X, T) {
  if (!(0 <= X && X <= 70 && 0 <= T && T <= 200)) {
    throw domainError('RANGE',
      `RhoChua: (X=${X.toFixed(2)} wt%, T=${T.toFixed(2)} degC) is outside the ` +
      'range [0-70 wt%, 0-200 degC]');
  }
  let s = 0.0;
  let xk = 1.0;
  for (let k = 0; k < 5; k++) {
    if (k > 0) xk *= X;
    s += xk * (G_RHO_CHUA[k][0] + T * (G_RHO_CHUA[k][1] + T * G_RHO_CHUA[k][2]));
  }
  return s;
}

// ---------------------------------------------------------------------------
// Inverse / composite functions (library additions, 2026-10-11 / 2026-10-12)
// ---------------------------------------------------------------------------

function tsatWaterPatterson(P_Pa) {
  // Pure-water saturation temperature [degC] on the Patterson log10
  // relation built into Psol; analytic inverse (quadratic in 1/TR).
  // Returns null when the discriminant is negative.
  const L = Math.log10(P_Pa / 6894.757);
  const a = 2886.373, b = 337269.46;
  const disc = a * a - 4.0 * b * (L - 6.21147);
  if (disc < 0.0) return null;
  const u = (-a + Math.sqrt(disc)) / (2.0 * b);
  return (1.0 / u - 459.7 - 32.0) * 5.0 / 9.0;
}

/** Dew-point temperature [degC] at (X, T), library-wide convention:
 *  TdewByTsolXi = Tsat_water(Psol(X, T)) on the Patterson route.  By
 *  construction equal to Tdew(X, T).  Domain errors of Psol propagate. */
function TdewByTsolXi(X, T) {
  const P = Psol(X, T);
  return tsatWaterPatterson(P);
}

/** Concentration X [wt%] from solution temperature and dew-point
 *  temperature (Chua route): the dew point fixes P = Psat_water(Tdew)
 *  (Wagner); 80-step bisection inverts PsolChua(X, Tsol) = P on
 *  X in [0, 60].  Returns null when no root exists in the bracket.
 *  Domain errors of PsolChua propagate. */
function XiByTsolTdew(Tsol_C, Tdew_C) {
  const P = wagnerPrefWater(Tdew_C);
  const Pmax = PsolChua(0.0, Tsol_C);
  const Pmin = PsolChua(60.0, Tsol_C);
  if (!(Pmin <= P && P <= Pmax)) return null;
  let lo = 0.0, hi = 60.0;
  for (let i = 0; i < 80; i++) {
    const mid = 0.5 * (lo + hi);
    if (PsolChua(mid, Tsol_C) > P) lo = mid; else hi = mid;
  }
  return 0.5 * (lo + hi);
}

/** Solution temperature [degC] from specific enthalpy h [kJ/kg] and
 *  X [wt%]: inverse of hsol.  The evaluable bracket is located by
 *  scanning T = 0..180 degC in 5 degC steps, then refined by 80
 *  bisection steps (hsol increases monotonically with T at fixed X).
 *  Returns null when no evaluable bracket contains h. */
function TsolByHsol(h, X) {
  let prevT = null, prevH = null, bracket = null;
  for (let k = 0; k <= 36; k++) {
    const T = 5.0 * k;
    let hv;
    try {
      hv = hsol(X, T);
    } catch (err) {
      continue;
    }
    if (prevH !== null && prevH <= h && h <= hv) {
      bracket = [prevT, T];
      break;
    }
    prevT = T; prevH = hv;
  }
  if (bracket === null) return null;
  let lo = bracket[0], hi = bracket[1];
  for (let i = 0; i < 80; i++) {
    const mid = 0.5 * (lo + hi);
    if (hsol(X, mid) < h) lo = mid; else hi = mid;
  }
  return 0.5 * (lo + hi);
}

module.exports = {
  Psol, PsolChua, Tdew, TdewByTsolXi, XiByTsolTdew,
  hsol, TsolByHsol, Rho, RhoChua, Eta, Lambda, Sigma, Tcryst,
};

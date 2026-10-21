'use strict';
/*
 * r124_dmac.js -- R124-DMAC bubble-point pressure, solution enthalpy,
 * density and viscosity (JavaScript set of the absorption-working-pairs
 * library; companion to r124_dmac.py / .c / .bas).
 * ==========================================================================
 * Source
 * ------
 * Borde, I., Jelinek, M., Daltrophe, N. C., "Working fluids for an
 * absorption system based on R124 (2-chloro-1,1,2,-tetrafluoroethane)
 * and organic absorbents", Int. J. Refrigeration 20(4), 256-266, 1997.
 *
 * Conventions
 * -----------
 * xi : weight (mass) fraction of R124 in the liquid solution (0..1).
 * x  : mole fraction of R124 in the liquid solution.
 * T  : degC at the public boundary; T = T_C + 273.15 in K where an
 *      equation needs K.
 * P  : MPa at the public boundary; the Borde correlations are
 *      evaluated internally in their native bar via private *_bar
 *      helpers; public functions only scale by 0.1 (pressure outputs)
 *      or 10 (pressure inputs) at the boundary.
 * h  : kJ/kg;  rho : kg/m^3;  eta : mPa s (= cP).
 * Function names are exactly the Python set's public names; no
 * aliases are kept.  Internal arithmetic and coefficients are copied
 * verbatim from r124_dmac.py; only the domain discipline below is
 * this set's own rendering of the source-stated domains.
 *
 * Reference state (enthalpy, as in the paper)
 * --------------------------------------------
 * h = 100 kJ/kg at 0 degC for both pure-component liquids (R124 and
 * DMAC).
 *
 * Pure-R124 line (re-sourced 2026-10-12)
 * ---------------------------------------
 * pref_R124 -- and with it dew_T, tdew_by_tsol_xi and abs_vap_flow --
 * no longer uses Eq. (15) for R124.  pref_R124 is the NIST-table
 * Wagner-type fit held in pure_fluids (identical coefficients),
 * band -40..110 degC.  Eq. (15) remains in psat() for the
 * absorbent-side components and for the xi = 1 endpoint comparison
 * of Eq. (16).
 *
 * Dew-point convention
 * --------------------
 * DMAC is treated as non-volatile (psat_DMAC / pref_R124 < 0.6 % at
 * 80 degC), so the vapour is essentially pure R124 and the dew-point
 * temperature is the pure-R124 saturation temperature.
 *
 * Two misprints in the paper are corrected here, each arbitrated by
 * the paper's own data:
 *   * Table 8, DMAC row: eta0/eta1 are printed x10 too large
 *     (-16.8400 / 1348.80); the values used are -1.68400 / 134.880.
 *   * Table 9, coefficient rho_{0,0} is printed 0.95521E+01; with
 *     E+00 both pure-component endpoints reproduce the Table 7
 *     intercepts to < 0.3 %.
 * The pure-component vapour-pressure equation is Eq. (15) of the
 * paper; the caption of Table 2 mislabels it "Equation (1)".
 *
 * Domain discipline
 * -----------------
 * Only domains stated in the source / formula notes produce a RANGE
 * error (an Error with .code 'RANGE'); nothing else is guarded, and
 * all internal calls use the raw private implementations so the
 * public checks never corrupt the Python logic:
 *   pref_R124       : public T_C in [-40, 110] else RANGE; internal
 *                     calls always use the raw version.
 *   psol            : public T_C in [0, 140], xi in [0, 0.95] else
 *                     RANGE (domain stated in the formula notes);
 *                     internal calls use the raw version.
 *   bubble_T        : xi outside [0, 0.95] throws RANGE; P outside
 *                     the raw psol span at xi over T in [0, 150] degC
 *                     (the Python default bracket) returns null.
 *   xi_by_tsol_tdew : Tsol_C outside [0, 140] throws RANGE (designed
 *                     divergence: Python returns None / a value);
 *                     otherwise no root returns null; internal calls
 *                     use the raw versions, bracket xi in [0, 1],
 *                     80 bisection steps, as in Python.
 *   tdew_by_tsol_xi : propagates psol's RANGE; returns null when
 *                     there is no corresponding saturation
 *                     temperature.
 *   Tsat_R124, dew_T: P outside the pure-line span returns null
 *                     (mirroring Python's None); no RANGE.
 *   xi_to_x         : xi outside [0, 1] throws RANGE.
 *   psat, rho_pure, eta_pure : a comp not in the table throws RANGE
 *                     (Python raises KeyError); no temperature
 *                     domain (none stated in the source).
 *   All other functions (psat_DMAC, h_excess, h_absorbent,
 *   h_refrigerant, hsol, tsol_by_hsol, rho_mix, eta_mix) carry no
 *   RANGE check, mirroring Python (tsol_by_hsol returns null when h
 *   lies outside its span; bracket T in [-40, 150] degC, 100
 *   bisection steps, as in Python).
 *   abs_vap_flow mirrors Python: Tv_C outside [-40, 110] or
 *   xi_w >= 0.95 or no bracketed root returns null; 400-point scan
 *   plus 100 bisection steps, as in Python; internal calls use the
 *   raw bubble-point / enthalpy versions.
 */

// ---------------------------------------------------------------------------
// Coefficients (verbatim from r124_dmac.py)
// ---------------------------------------------------------------------------

const _M_R124 = 136.50;   // g/mol (Table 1)
const _M_DMAC = 87.12;    // g/mol (Table 1)

// ---- Pure-component vapour pressure, Eq. (15): ------------------------------
// ln(Ps/bar) = A + B/(T+C) + D*T + E*ln(T) + F*T^2 ,  T in K   (Table 2)
const _PSAT = {
  R124:   [-119.33446, -1351.341,    0.0, -0.12497, 27.21197, 8.32656e-5],
  DMAC:   [   6.01834, -1800.240, -138.5,  0.0,      0.0,      0.0],
  NMP:    [   8.50639, -3063.357, -115.4,  0.0,      0.0,      0.0],
  MCL:    [   8.09382, -3078.393, -130.0,  0.0,      0.0,      0.0],
  DMEU:   [  26.80333, -25627.39,  459.0,  0.0,      0.0,      0.0],
  DMETEG: [  24.56738, -21564.48,  328.4,  0.0,      0.0,      0.0],
};

// Pure-R124 saturation pressure: NIST WebBook saturation-table fit
// (Wagner type, exponents 1, 1.5, 3, 6), identical to
// pure_fluids.R124_Pref.  Band -40..110 degC.
const _R124_NIST_TC = 395.428;
const _R124_NIST_PC = 36.245;
const _R124_NIST_W = [-7.401179377235425, 1.4613603991162563,
                      -3.476435267708954, -1.772232810745864];

// ---- Bubble-point pressure of R124-DMAC, Eq. (16): --------------------------
// P = sum_j sum_i p_ij * xi^i * T^j   (source unit bar; xi weight fraction;
// T in K).  Table 3, rows j = 0..7, columns i = 0..7.
const _P = [
  [ 0.11502e-01, -0.28240e+02,  0.41188e+02, -0.26168e+02,  0.0,          0.18381e+03, -0.31190e+03,  0.13914e+03],
  [-0.13711e-01,  0.24179e+00, -0.26951e+00,  0.0,          0.0,          0.75999e-01,  0.0,          0.0],
  [ 0.91911e-04,  0.0,          0.0,          0.0,          0.0,          0.0,          0.0,          0.0],
  [ 0.0,         -0.31564e-05,  0.92677e-06,  0.78191e-05, -0.13310e-04,  0.0,          0.12701e-04, -0.65958e-05],
  [-0.86519e-09,  0.0,          0.0,          0.0,          0.0,          0.0,          0.0,          0.0],
  [ 0.0,          0.22998e-10,  0.0,          0.0,          0.0,          0.33233e-10,  0.0,         -0.24081e-10],
  [ 0.59436e-14,  0.0,         -0.68310e-13,  0.0,         -0.17145e-13,  0.0,          0.0,          0.0],
  [-0.67036e-17, -0.53440e-16,  0.14140e-15, -0.94881e-16,  0.0,          0.56692e-15, -0.10014e-14,  0.53340e-15],
];

// ---- Enthalpy ---------------------------------------------------------------
// Excess specific enthalpy, Eq. (19):
//   hE = 4.1868 * sum_j sum_i h_ij * x^i * T^j   (kJ/kg; x mole fraction; T K)
// Table 4, rows j = 0..7, columns i = 0..7.
const _H = [
  [-0.34981e+02, -0.18479e+03,  0.27310e+03, -0.22155e+02,  0.0,         -0.49058e+02,  0.61147e+01,  0.16635e+01],
  [ 0.31418e+00,  0.59584e+00, -0.90572e+00,  0.0,          0.0,          0.16399e+00,  0.0,          0.0],
  [-0.80917e-03,  0.0,          0.0,          0.11400e-04,  0.0,          0.0,          0.0,          0.0],
  [ 0.0,          0.32184e-07,  0.0,          0.0,          0.14107e-05,  0.0,          0.74883e-06, -0.10444e-05],
  [ 0.17947e-08,  0.0,          0.0,          0.0,          0.0,          0.0,          0.0,          0.0],
  [ 0.0,         -0.11860e-10,  0.18271e-10,  0.0,          0.0,         -0.22810e-10,  0.0,          0.10914e-10],
  [ 0.0,          0.0,          0.0,          0.0,          0.0,          0.0,          0.0,          0.0],
  [-0.43652e-17,  0.34001e-16, -0.50197e-16, -0.10080e-16,  0.0,          0.67800e-16,  0.0,         -0.31527e-16],
];

// Pure liquid enthalpies; reference state: h = 100 kJ/kg at 0 degC for both.
const _CP_DMAC = [0.4578, 0.000839];            // Table 5: Cp0, Cp1 (cal/g/K basis)
const _HR_R124 = [0.250767, 0.347753e-3, 0.100977e-5, 0.342458e-8,
                  0.0, 0.0, 0.699612e-14];      // Table 6: h_r1 .. h_r7

// ---- Density ----------------------------------------------------------------
// Pure components, Eq. (23): rho = sum_i rho_i t^i  (10^3 kg/m3; t in degC)
const _RHO_PURE = {
  R124: [1.4660, -0.3394e-2, -0.16063e-5, -0.20040e-6],
  DMAC: [0.9528, -0.5856e-3, -0.33632e-5, 0.0],
};

// Mixture, Eq. (25): rho = sum_j sum_i rho_ij xi^i t^j (10^3 kg/m3; t in degC)
// Table 9, rows j = 0..3, columns i = 0..3. rho_00 corrected (see header).
const _RHO_MIX = [
  [0.95521,      0.43672,     -0.28160,      0.35610],
  [-0.15533e-3, -0.37079e-3,  0.0,         -0.29230e-2],
  [-0.13981e-4,  0.0,          0.13550e-4,   0.0],
  [0.60941e-7,  -0.97547e-7,   0.33531e-6,  -0.50554e-6],
];

// ---- Viscosity ---------------------------------------------------------------
// Pure components, Eq. (24): ln(eta) = eta0 + eta1/(T + eta2), eta in mPa s, T K
// DMAC row uses the corrected coefficients (printed values are x10, see header).
const _ETA_PURE = {
  R124: [-8.9301, 5094.90, 357.4],      // based on predicted data (paper)
  DMAC: [-1.68400, 134.880, -223.2],    // corrected; printed: -16.8400/1348.80
};

// Mixture, Eq. (26): ln(eta) = sum_j sum_i eta_ij xi^i T^{-j}  (mPa s; T in K)
// Table 10, rows j = 0..3, columns i = 0..3.
const _ETA_MIX = [
  [7.6992,     0.60007,   -8.9875,    -1.7031],
  [-6769.2,    0.0,        4555.4,    0.0],
  [1343400.0,  0.0,        0.0,       0.0],
  [0.0,       -64446000.0, 0.0,      -106310000.0],
];

// ---- Adiabatic absorber -----------------------------------------------------
// Saturated vapour enthalpy of pure R124 (kJ/kg): NIST WebBook saturation
// table fit, identical polynomial to pure_fluids.R124_hgas. Reference state
// matches this module (liquid = 100 kJ/kg at 0 degC). Enthalpy fit band:
// -40..110 degC.
const _HVAP_R124 = [-4.7606354686130485e-12, -9.020883920792309e-10,
                    2.036341936229362e-08, 4.234769176716097e-06,
                    -3.8033802108463233e-04, 5.621038923140594e-01,
                    2.5994742998138406e+02];

function domainError(code, message) {
  const e = new Error(message);
  e.code = code;
  return e;
}

// ---------------------------------------------------------------------------
// Raw private implementations (no range checks, mirroring Python)
// ---------------------------------------------------------------------------

/** Saturation pressure in native bar of a pure component, Eq. (15). */
function _psat_bar(comp, T_C) {
  const [A, B, C, D, E, F] = _PSAT[comp];
  const T = T_C + 273.15;
  return Math.exp(A + B / (T + C) + D * T + E * Math.log(T) + F * T * T);
}

/** Pure R124 saturation pressure in native bar: NIST-table Wagner fit
 *  (same coefficients as pure_fluids.R124_Pref), band -40..110 degC. */
function _pref_R124_bar(T_C) {
  const T = T_C + 273.15;
  const tau = 1.0 - T / _R124_NIST_TC;
  const a = _R124_NIST_W;
  return _R124_NIST_PC * Math.exp((_R124_NIST_TC / T) * (
    a[0] * tau + a[1] * Math.pow(tau, 1.5) + a[2] * Math.pow(tau, 3.0)
    + a[3] * Math.pow(tau, 6.0)));
}

function _psat_DMAC_bar(T_C) {
  return _psat_bar('DMAC', T_C);
}

/** Saturation temperature (degC) of pure R124 at P_bar in native bar
 *  (inverts _pref_R124_bar, the NIST-table fit; span -40..110 degC). */
function _Tsat_R124_bar(P_bar) {
  let lo = -40.0, hi = 110.0;
  if (!(_pref_R124_bar(lo) <= P_bar && P_bar <= _pref_R124_bar(hi))) {
    return null;
  }
  for (let i = 0; i < 80; i++) {
    const mid = 0.5 * (lo + hi);
    if (_pref_R124_bar(mid) < P_bar) {
      lo = mid;
    } else {
      hi = mid;
    }
  }
  return 0.5 * (lo + hi);
}

/** Bubble-point pressure in native bar. T_C in degC, xi mass fraction. */
function _psol_bar(T_C, xi) {
  const T = T_C + 273.15;
  let s = 0.0;
  for (let j = 0; j < 8; j++) {
    let row = 0.0;
    for (let i = 0; i < 8; i++) {
      row += _P[j][i] * Math.pow(xi, i);
    }
    s += row * Math.pow(T, j);
  }
  return s;
}

/** Bubble-point temperature (degC) by bisection on native bar.
 *  null if out of range. */
function _bubble_T_bar(P_bar, xi, Tlo_C = 0.0, Thi_C = 150.0) {
  const Plo = _psol_bar(Tlo_C, xi), Phi = _psol_bar(Thi_C, xi);
  if (!(Plo <= P_bar && P_bar <= Phi)) {
    return null;
  }
  let lo = Tlo_C, hi = Thi_C;
  for (let i = 0; i < 80; i++) {
    const mid = 0.5 * (lo + hi);
    if (_psol_bar(mid, xi) < P_bar) {
      lo = mid;
    } else {
      hi = mid;
    }
  }
  return 0.5 * (lo + hi);
}

/** Dew-point temperature (degC) at native bar: pure-R124 saturation
 *  temperature (DMAC treated as non-volatile). */
function _dew_T_bar(P_bar) {
  return _Tsat_R124_bar(P_bar);
}

/** Weight fraction -> mole fraction of R124 (raw, no range check). */
function _xi_to_x_raw(xi) {
  const n_r = xi / _M_R124;
  const n_a = (1.0 - xi) / _M_DMAC;
  return n_r / (n_r + n_a);
}

function _h_excess_raw(T_C, xi) {
  const T = T_C + 273.15;
  const x = _xi_to_x_raw(xi);
  let s = 0.0;
  for (let j = 0; j < 8; j++) {
    let row = 0.0;
    for (let i = 0; i < 8; i++) {
      row += _H[j][i] * Math.pow(x, i);
    }
    s += row * Math.pow(T, j);
  }
  return 4.1868 * s;
}

function _h_absorbent_raw(T_C) {
  const [Cp0, Cp1] = _CP_DMAC;
  return 100.0 + 4.1868 * (Cp0 * T_C + 0.5 * Cp1 * Math.pow(T_C, 2));
}

function _h_refrigerant_raw(T_C) {
  let s = 0.0;
  for (let idx = 0; idx < _HR_R124.length; idx++) {
    const i = idx + 1;
    s += _HR_R124[idx] * Math.pow(T_C, i);
  }
  return 100.0 + 4.1868 * s;
}

function _hsol_raw(T_C, xi) {
  return _h_refrigerant_raw(T_C) * xi + _h_absorbent_raw(T_C) * (1.0 - xi)
    + _h_excess_raw(T_C, xi);
}

function _hgas_R124(T_C) {
  let s = 0.0;
  for (let k = 0; k < _HVAP_R124.length; k++) {
    s = s * T_C + _HVAP_R124[k];
  }
  return s;
}

function _check_psol_domain(T_C, xi, name) {
  if (!(0 <= T_C && T_C <= 140 && 0 <= xi && xi <= 0.95)) {
    throw domainError('RANGE',
      `${name}: (T_C=${T_C}, xi=${xi}) is outside the stated domain ` +
      'T_C in [0, 140], xi in [0, 0.95]');
  }
}

// ---------------------------------------------------------------------------
// Pure-component vapour pressures
// ---------------------------------------------------------------------------

/** Saturation pressure (MPa) of a pure component, Eq. (15). T_C in degC.
 *  comp not in the table throws RANGE (Python raises KeyError);
 *  no temperature domain (none stated in the source). */
function psat(comp, T_C) {
  if (!Object.prototype.hasOwnProperty.call(_PSAT, comp)) {
    throw domainError('RANGE', `psat: comp=${comp} is not in the table`);
  }
  return 0.1 * _psat_bar(comp, T_C);
}

/** Pure R124 saturation pressure (MPa): NIST-table Wagner fit
 *  (same coefficients as pure_fluids.R124_Pref), band -40..110 degC.
 *  Public T_C outside [-40, 110] throws RANGE; internal calls use
 *  the raw version. */
function pref_R124(T_C) {
  if (!(-40 <= T_C && T_C <= 110)) {
    throw domainError('RANGE',
      `pref_R124: T_C=${T_C} is outside the fit band T_C in [-40, 110]`);
  }
  return 0.1 * _pref_R124_bar(T_C);
}

/** Saturation pressure (MPa) of pure DMAC, Eq. (15). T_C in degC.
 *  No domain is imposed (none stated). */
function psat_DMAC(T_C) {
  return 0.1 * _psat_DMAC_bar(T_C);
}

/** Saturation temperature (degC) of pure R124 at P_MPa
 *  (inverts pref_R124, the NIST-table fit; span -40..110 degC).
 *  Returns null when P_MPa lies outside the span; no RANGE. */
function Tsat_R124(P_MPa) {
  return _Tsat_R124_bar(P_MPa * 10.0);
}

// ---------------------------------------------------------------------------
// Bubble-point pressure and its inverses
// ---------------------------------------------------------------------------

/** Bubble-point pressure (MPa). T_C in degC, xi = R124 mass fraction.
 *  Domain stated in the formula notes: T_C in [0, 140], xi in
 *  [0, 0.95]; outside throws RANGE.  Internal calls use the raw
 *  version. */
function psol(T_C, xi) {
  _check_psol_domain(T_C, xi, 'psol');
  return 0.1 * _psol_bar(T_C, xi);
}

/** Bubble-point temperature (degC) at P_MPa by bisection.
 *  xi outside [0, 0.95] throws RANGE; P outside the raw psol span
 *  at xi over T in [Tlo_C, Thi_C] (Python defaults 0..150 degC)
 *  returns null. */
function bubble_T(P_MPa, xi, Tlo_C = 0.0, Thi_C = 150.0) {
  if (!(0 <= xi && xi <= 0.95)) {
    throw domainError('RANGE',
      `bubble_T: xi=${xi} is outside the domain xi in [0, 0.95]`);
  }
  return _bubble_T_bar(P_MPa * 10.0, xi, Tlo_C, Thi_C);
}

/** Concentration from dew-point temperature and solution temperature.
 *  NOTE the argument order: (Tsol_C, Tdew_C) -- Tsol first.
 *  The dew point fixes the pressure, P = pref_R124(Tdew) (DMAC
 *  treated as non-volatile); then solve psol(Tsol, xi) = P by
 *  bisection over xi in [0, 1] (80 steps, internal raw versions).
 *  Returns null if no root (P outside the bubble-pressure span at
 *  Tsol).  Tsol_C outside [0, 140] throws RANGE (designed
 *  divergence: Python returns None / a value there). */
function xi_by_tsol_tdew(Tsol_C, Tdew_C) {
  if (!(0 <= Tsol_C && Tsol_C <= 140)) {
    throw domainError('RANGE',
      `xi_by_tsol_tdew: Tsol_C=${Tsol_C} is outside the domain ` +
      'Tsol_C in [0, 140]');
  }
  const P = _pref_R124_bar(Tdew_C);
  const Plo = _psol_bar(Tsol_C, 0.0), Phi = _psol_bar(Tsol_C, 1.0);
  if (!(Plo <= P && P <= Phi)) {
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

/** Dew-point temperature (degC) at P_MPa: pure-R124 saturation
 *  temperature.  DMAC is treated as non-volatile (psat_DMAC /
 *  pref_R124 < 0.6 % at 80 degC), so the vapour is essentially pure
 *  R124.  Returns null when P_MPa lies outside the pure-line span;
 *  no RANGE. */
function dew_T(P_MPa) {
  return _Tsat_R124_bar(P_MPa * 10.0);
}

/** Dew-point temperature [degC] of the solution at (T_C, xi)
 *  (library-wide TdewByTsolXi convention):
 *      Tdew = dew_T(psol(T_C, xi)),
 *  i.e. the pure-R124 saturation temperature on this module's
 *  pure-R124 NIST-table fit line at the solution surface pressure
 *  Psol.  DMAC is treated as non-volatile.  Propagates psol's
 *  RANGE; returns null if the pressure lies outside the dew_T
 *  bisection span. */
function tdew_by_tsol_xi(T_C, xi) {
  _check_psol_domain(T_C, xi, 'tdew_by_tsol_xi');
  return _dew_T_bar(_psol_bar(T_C, xi));
}

/** Solution temperature [degC] from specific enthalpy h [kJ/kg]
 *  and R124 mass fraction xi: bisection inverse of hsol over
 *  T in [-40, 150] degC (100 steps; hsol increases monotonically
 *  with T at fixed xi).  Returns null if h lies outside the hsol
 *  span at xi.  No RANGE check (none in Python). */
function tsol_by_hsol(h, xi) {
  const lo = -40.0, hi = 150.0;
  const hlo = _hsol_raw(lo, xi), hhi = _hsol_raw(hi, xi);
  if (!(hlo <= h && h <= hhi)) {
    return null;
  }
  let loT = lo, hiT = hi;
  for (let i = 0; i < 100; i++) {
    const mid = 0.5 * (loT + hiT);
    if (_hsol_raw(mid, xi) < h) {
      loT = mid;
    } else {
      hiT = mid;
    }
  }
  return 0.5 * (loT + hiT);
}

// ---------------------------------------------------------------------------
// Enthalpy
// ---------------------------------------------------------------------------

/** Weight fraction -> mole fraction of R124.
 *  xi outside [0, 1] throws RANGE. */
function xi_to_x(xi) {
  if (!(0 <= xi && xi <= 1)) {
    throw domainError('RANGE',
      `xi_to_x: xi=${xi} is outside the domain xi in [0, 1]`);
  }
  return _xi_to_x_raw(xi);
}

/** Excess specific enthalpy of the solution (kJ/kg), Eq. (19).
 *  No RANGE check (none in Python); uses the raw xi_to_x. */
function h_excess(T_C, xi) {
  return _h_excess_raw(T_C, xi);
}

/** Liquid enthalpy of pure DMAC (kJ/kg), Eq. (20). T_C in degC.
 *  No RANGE check (none in Python). */
function h_absorbent(T_C) {
  return _h_absorbent_raw(T_C);
}

/** Liquid enthalpy of pure R124 (kJ/kg), Eq. (21). T_C in degC.
 *  No RANGE check (none in Python). */
function h_refrigerant(T_C) {
  return _h_refrigerant_raw(T_C);
}

/** Solution liquid enthalpy (kJ/kg), Eq. (22). xi = R124 mass
 *  fraction.  No RANGE check (none in Python). */
function hsol(T_C, xi) {
  return _hsol_raw(T_C, xi);
}

// ---------------------------------------------------------------------------
// Density
// ---------------------------------------------------------------------------

/** Pure-component liquid density (kg/m3), Eq. (23).
 *  comp not in the table throws RANGE (Python raises KeyError);
 *  no temperature domain (none stated in the source). */
function rho_pure(comp, T_C) {
  if (!Object.prototype.hasOwnProperty.call(_RHO_PURE, comp)) {
    throw domainError('RANGE', `rho_pure: comp=${comp} is not in the table`);
  }
  const c = _RHO_PURE[comp];
  let s = 0.0;
  for (let i = 0; i < 4; i++) {
    s += c[i] * Math.pow(T_C, i);
  }
  return 1000.0 * s;
}

/** Solution density (kg/m3), Eq. (25). T_C in degC, xi mass
 *  fraction.  No RANGE check (none in Python). */
function rho_mix(T_C, xi) {
  let s = 0.0;
  for (let j = 0; j < 4; j++) {
    let row = 0.0;
    for (let i = 0; i < 4; i++) {
      row += _RHO_MIX[j][i] * Math.pow(xi, i);
    }
    s += row * Math.pow(T_C, j);
  }
  return 1000.0 * s;
}

// ---------------------------------------------------------------------------
// Viscosity
// ---------------------------------------------------------------------------

/** Pure-component viscosity (mPa s), Eq. (24). T_C in degC.
 *  comp not in the table throws RANGE (Python raises KeyError);
 *  no temperature domain (none stated in the source). */
function eta_pure(comp, T_C) {
  if (!Object.prototype.hasOwnProperty.call(_ETA_PURE, comp)) {
    throw domainError('RANGE', `eta_pure: comp=${comp} is not in the table`);
  }
  const [e0, e1, e2] = _ETA_PURE[comp];
  const T = T_C + 273.15;
  return Math.exp(e0 + e1 / (T + e2));
}

/** Solution viscosity (mPa s), Eq. (26). T_C in degC, xi mass
 *  fraction.  No RANGE check (none in Python). */
function eta_mix(T_C, xi) {
  const T = T_C + 273.15;
  let s = 0.0;
  for (let j = 0; j < 4; j++) {
    let row = 0.0;
    for (let i = 0; i < 4; i++) {
      row += _ETA_MIX[j][i] * Math.pow(xi, i);
    }
    s += row * Math.pow(T, -j);
  }
  return Math.exp(s);
}

// ---------------------------------------------------------------------------
// Adiabatic absorber
// ---------------------------------------------------------------------------

/** Vapour flow absorbed in a single-pass adiabatic absorber.
 *  Inlets: weak solution (flow ms, temperature Ts_C, R124 mass
 *  fraction xi_w) and saturated R124 vapour at Tv_C. The absorber
 *  pressure is the evaporator pressure P = pref_R124(Tv_C) (DMAC
 *  non-volatile). The outlet solution is the adiabatic-equilibrium
 *  state at that pressure: bubble_T(P, xi_r) with xi_r from the
 *  refrigerant balance, closed by the adiabatic enthalpy balance
 *      hs + r*hv = (1 + r) * hsol(T_out, xi_r),
 *      r = m_vap/ms = (xi_r - xi_w) / (1 - xi_r).
 *  Returns {m_vap, T_out, xi_r}, or null if no solution exists
 *  inside the model domain (Borde bubble equation xi <= 0.95;
 *  vapour enthalpy fit -40..110 degC) -- e.g. solution too hot to
 *  absorb.  Mirrors Python exactly: 400-point scan plus 100
 *  bisection steps; internal calls use the raw versions. */
function abs_vap_flow(Ts_C, xi_w, ms, Tv_C) {
  if (!(-40.0 <= Tv_C && Tv_C <= 110.0) || xi_w >= 0.95) {
    return null;
  }
  const P = _pref_R124_bar(Tv_C);
  const hv = _hgas_R124(Tv_C);
  const hs = _hsol_raw(Ts_C, xi_w);

  function resid(xr) {
    const Tout = _bubble_T_bar(P, xr);
    if (Tout === null) {
      return null;
    }
    const r = (xr - xi_w) / (1.0 - xr);
    return hs + r * hv - (1.0 + r) * _hsol_raw(Tout, xr);
  }

  let bracket = null, prev = null;
  const n = 400;
  for (let i = 1; i <= n; i++) {
    const xr = xi_w + (0.95 - xi_w) * i / n;
    const f = resid(xr);
    if (f === null) {
      continue;
    }
    if (prev !== null && ((prev[1] > 0 && f <= 0)
                           || (prev[1] < 0 && f >= 0))) {
      bracket = [prev[0], xr];
      break;
    }
    prev = [xr, f];
  }
  if (bracket === null) {
    return null;
  }
  let lo = bracket[0], hi = bracket[1];
  let flo = resid(lo);
  for (let i = 0; i < 100; i++) {
    const mid = 0.5 * (lo + hi);
    const fm = resid(mid);
    if ((flo > 0) === (fm > 0)) {
      lo = mid; flo = fm;
    } else {
      hi = mid;
    }
  }
  const xr = 0.5 * (lo + hi);
  const r = (xr - xi_w) / (1.0 - xr);
  return { m_vap: ms * r, T_out: _bubble_T_bar(P, xr), xi_r: xr };
}

module.exports = {
  psat, pref_R124, psat_DMAC, Tsat_R124, psol, bubble_T,
  xi_by_tsol_tdew, dew_T, tdew_by_tsol_xi, tsol_by_hsol, xi_to_x,
  h_excess, h_absorbent, h_refrigerant, hsol, rho_pure, rho_mix,
  eta_pure, eta_mix, abs_vap_flow,
};

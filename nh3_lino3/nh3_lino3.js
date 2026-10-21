'use strict';
/*
 * nh3_lino3.js -- NH3-LiNO3 (ammonia-lithium nitrate) solution properties
 * (JavaScript set of the absorption-working-pairs library; companion to
 * nh3_lino3.py / .c / .bas).
 * ==========================================================================
 * Source
 * ------
 * Amaris Castilla, C.F. (2014), doctoral thesis, "Intensification of
 * NH3 Bubble Absorption Process Using Advanced Surfaces and Carbon
 * Nanotubes for NH3/LiNO3 Absorption Chillers", Universitat Rovira i
 * Virgili, correlations transcribed in Appendix B (pp. A-6..A-8):
 *   Bubble-point pressure   Libotean et al. (2007), J. Chem. Eng. Data
 *                           52, 1050-1055: ln P[kPa] = pa(x) + pb(x)/T
 *   Liquid enthalpy         Valles & Salavera (2011, internal report),
 *                           Haltenberger (1939) method:
 *                           H = ha(x) + hb(x) T + hc(x) T^2
 *   Specific heat           Libotean et al. (2008)
 *   Density                 Libotean et al. (2008)
 *   Thermal conductivity    Cuenca et al. (2013a)
 *   Crystallisation limit   Infante Ferreira et al. (1984), XCRIS
 *                           ten-segment polynomial
 * The viscosity correlation of the thesis Appendix B is typeset in
 * damaged form and its reconstruction is unverified; the Python set
 * carries it only as EXPERIMENTAL (mu_visc) and the C/VBA sets do not
 * implement it.  It is NOT ported here.
 *
 * Conventions
 * -----------
 * x : ammonia MASS fraction (a fraction, e.g. 0.5), not a percentage.
 * T : K (the T of x_cris is in degC, as in the original pseudocode).
 * p : MPa at public-function boundaries; internal arithmetic and the
 *     source formulas remain in kPa, exactly as in the Python set --
 *     public functions convert MPa <-> kPa only at the boundary.
 * h : kJ/kg, cp : kJ/(kg K), rho : kg/m^3, k : W/(m K).
 * Function names are exactly the Python set's public names; no
 * aliases are kept.  Internal arithmetic and coefficients are copied
 * verbatim from nh3_lino3.py; only the domain discipline below is
 * this set's own rendering of the Python set's discipline.
 *
 * Reference state (enthalpy, as in the source)
 * --------------------------------------------
 * The ammonia enthalpy takes 0 kJ/kg at 0 degC as its zero; the
 * mixture reference state is 0 degC and ammonia mass fraction 0.5,
 * where H = 0 kJ/kg (hsol(273.15, 0.5) = 0.0024 kJ/kg).  This set
 * keeps the source reference state; it is not unified with the
 * other pairs in this library.
 *
 * Domain discipline
 * -----------------
 * This pair's Python set states a range per function and raises
 * ValueError outside it.  This set mirrors that classification
 * exactly: a ValueError in Python is an Error with .code 'RANGE'
 * here; a Python None (no-root convention of the two inverses
 * noted below) is null here; nothing is silently extrapolated:
 *   psol_TX / T_bubble_PX : T 293.15-353.15 K, x 0.35-0.65
 *                           (T_bubble_PX also: P > 0 and the result
 *                           T in the same band)
 *   hsol                  : T 273.15-353.15 K, x 0.35-0.65
 *   cp, rho               : T 293.15-353.15 K, x 0.35-0.65
 *   k_therm               : T 303.15-353.15 K, x 0.35-0.60
 *   x_cris                : the ten segments transcribed verbatim;
 *                           x > 1 throws RANGE (the Python set falls
 *                           through to ValueError there); branch
 *                           endpoints belong to the segment of the
 *                           lower bound, as in the Python set.
 * Inverses and the no-root convention:
 *   x_by_tsol_tdew returns null when there is no root (dew-point
 *   pressure outside the bubble-pressure span at Tsol, Tsol outside
 *   its band, or Tdew outside the pure-ammonia NIST fit domain),
 *   mirroring the Python set's None.
 *   tsol_by_hsol returns null when h lies outside the hsol span at
 *   x; an out-of-domain x propagates hsol's RANGE, as in Python.
 *   tdew_from_tsol_x propagates psol_TX's RANGE and returns null
 *   when the pure-ammonia line has no saturation temperature for
 *   the bubble pressure, as in Python.
 *
 * Notes
 * -----
 * Thermal conductivity: Appendix B prints k = ka1 + ka2 T +
 * ka3 T^2 x + ka4 x (the ka3 term carries an x).  Like the Python
 * set, this set implements the reading without the extra x
 * (ka3 T^2); the two readings differ at 300 K / x = 0.4 by about
 * 3%.  See the formula notes file of the pair.
 * Pure-ammonia line (dew-point convention): LiNO3 is non-volatile,
 * the vapour phase is treated as pure ammonia.  The line is the
 * compact fit to the ammonia NIST saturation table (lnP-t degree-7
 * polynomial; NIST WebBook saturation table, 210 points,
 * -77..132 degC), re-sourced 2026-10-12, exactly as in the
 * Python set.
 */

// ---------------------------------------------------------------------------
// Coefficients (verbatim from nh3_lino3.py)
// ---------------------------------------------------------------------------

const _PA = [4.99470524658178, 88.5490906185871, -197.698944465798, 134.938665891525];
const _PB = [-1793.21854659273, -22317.1158016582, 61289.3128925447, -45238.5915843719];
const _HA = [249.1567745, -1628.297463, -464.3464344, -105.6321057];
const _HB = [2.481273559, -5.184392344, -0.775202139, 18.98142102];
const _HC = [-0.004240786, 0.025111292, -0.013342843, -0.025956064];
const _CPA = [0.559273057, 3.241167393];
const _CPB = [0.00207796, 0.001846907];
const _DA = [1.521, -0.4528];
const _DB = [-0.00001961, -0.001726];
const _KA1 = 0.446088003, _KA2 = -0.000350326, _KA3 = 2.13849e-07, _KA4 = 0.006538043;

const _T_VLE = [293.15, 353.15];
const _T_H = [273.15, 353.15];
const _T_KTH = [303.15, 353.15];
const _X_VLE = [0.35, 0.65];
const _X_KTH = [0.35, 0.60];

const _NH3_FIT = [-0.8457026848887617, 0.03739502393748032,
  -0.00015333383280607642, 6.551063627525382e-07,
  -2.4759314474490567e-09, 9.070213653911228e-12,
  -3.681466540446358e-14, 1.1501679663496297e-16];
const _NH3_TLO = -77.0, _NH3_THI = 132.0;

function domainError(code, message) {
  const e = new Error(message);
  e.code = code;
  return e;
}

function _poly(c, x) {
  let s = 0.0;
  for (let i = c.length - 1; i >= 0; i--) {
    s = s * x + c[i];
  }
  return s;
}

function _check(T_K, x, t_rng, x_rng, name) {
  if (!(t_rng[0] <= T_K && T_K <= t_rng[1])) {
    throw domainError('RANGE', `${name}: T=${T_K} K outside [${t_rng[0]}, ${t_rng[1]}] K`);
  }
  if (!(x_rng[0] <= x && x <= x_rng[1])) {
    throw domainError('RANGE', `${name}: x=${x} outside [${x_rng[0]}, ${x_rng[1]}]`);
  }
}

// ---------------------------------------------------------------------------
// Bubble-point pressure and bubble-point temperature
// ---------------------------------------------------------------------------

function _pa_pb(x) {
  return [_poly(_PA, x), _poly(_PB, x)];
}

function _psol_TX_kPa(T_K, x) {
  _check(T_K, x, _T_VLE, _X_VLE, 'psol_TX');
  const [pa, pb] = _pa_pb(x);
  return Math.exp(pa + pb / T_K);
}

/** Bubble-point pressure [MPa]: solution at T_K [K], ammonia mass
 *  fraction x.  Boundary conversion only: _psol_TX_kPa * 1e-3. */
function psol_TX(T_K, x) {
  return _psol_TX_kPa(T_K, x) * 1e-3;
}

function _T_bubble_PX_kPa(P_kPa, x) {
  if (!(_X_VLE[0] <= x && x <= _X_VLE[1])) {
    throw domainError('RANGE', `T_bubble_PX: x=${x} outside [${_X_VLE[0]}, ${_X_VLE[1]}]`);
  }
  if (!(P_kPa > 0.0)) {
    throw domainError('RANGE', 'T_bubble_PX: P must be > 0');
  }
  const [pa, pb] = _pa_pb(x);
  const denom = Math.log(P_kPa) - pa;
  if (denom === 0.0) {
    throw domainError('RANGE', 'T_bubble_PX: ln P == pa, no finite solution');
  }
  const T_K = pb / denom;
  if (!(_T_VLE[0] <= T_K && T_K <= _T_VLE[1])) {
    throw domainError('RANGE',
      `T_bubble_PX: result T=${T_K} K outside [${_T_VLE[0]}, ${_T_VLE[1]}] K`);
  }
  return T_K;
}

/** Bubble-point temperature [K] at pressure P_MPa [MPa] and ammonia
 *  mass fraction x (analytic inverse T = pb / (ln P - pa); the MPa
 *  input is converted back to kPa at the boundary). */
function T_bubble_PX(P_MPa, x) {
  return _T_bubble_PX_kPa(P_MPa * 1e3, x);
}

// ---------------------------------------------------------------------------
// Pure-ammonia saturation line (private; dew-point convention)
// ---------------------------------------------------------------------------

function _pref_NH3_pure(T_K) {
  const t = T_K - 273.15;
  if (!(_NH3_TLO <= t && t <= _NH3_THI)) {
    return null;
  }
  let lnP = 0.0;
  for (let i = _NH3_FIT.length - 1; i >= 0; i--) {
    lnP = lnP * t + _NH3_FIT[i];
  }
  return 1000.0 * Math.exp(lnP);
}

function _Tsat_NH3_pure(P_kPa) {
  let lo = _NH3_TLO + 273.15, hi = _NH3_THI + 273.15;
  if (!(_pref_NH3_pure(lo) <= P_kPa && P_kPa <= _pref_NH3_pure(hi))) {
    return null;
  }
  for (let i = 0; i < 80; i++) {
    const mid = 0.5 * (lo + hi);
    if (_pref_NH3_pure(mid) < P_kPa) {
      lo = mid;
    } else {
      hi = mid;
    }
  }
  return 0.5 * (lo + hi);
}

/** Ammonia mass fraction x from dew-point temperature Tdew_K and
 *  solution temperature Tsol_K (80 bisection steps over x in
 *  [0.35, 0.65], internal kPa throughout).  Returns null when there
 *  is no root, mirroring the Python set's None. */
function x_by_tsol_tdew(Tsol_K, Tdew_K) {
  const P = _pref_NH3_pure(Tdew_K);
  if (P === null) {
    return null;
  }
  if (!(_T_VLE[0] <= Tsol_K && Tsol_K <= _T_VLE[1])) {
    return null;
  }
  const Plo = _psol_TX_kPa(Tsol_K, _X_VLE[0]);
  const Phi = _psol_TX_kPa(Tsol_K, _X_VLE[1]);
  if (!(Plo <= P && P <= Phi)) {
    return null;
  }
  let lo = _X_VLE[0], hi = _X_VLE[1];
  for (let i = 0; i < 80; i++) {
    const mid = 0.5 * (lo + hi);
    if (_psol_TX_kPa(Tsol_K, mid) < P) {
      lo = mid;
    } else {
      hi = mid;
    }
  }
  return 0.5 * (lo + hi);
}

// ---------------------------------------------------------------------------
// Liquid enthalpy / specific heat / density / thermal conductivity
// ---------------------------------------------------------------------------

/** Solution specific enthalpy [kJ/kg] (Valles & Salavera 2011,
 *  Haltenberger method).  Reference state: H = 0 at 0 degC, x = 0.5. */
function hsol(T_K, x) {
  _check(T_K, x, _T_H, _X_VLE, 'hsol');
  const ha = _poly(_HA, x);
  const hb = _poly(_HB, x);
  const hc = _poly(_HC, x);
  return ha + hb * T_K + hc * T_K * T_K;
}

/** Dew-point temperature [K] of the solution at (T_K, x) under the
 *  library-wide TdewByTsolXi convention: the pure-ammonia saturation
 *  temperature (NIST fit line) at the solution surface pressure
 *  Psol (internal kPa throughout). */
function tdew_from_tsol_x(T_K, x) {
  return _Tsat_NH3_pure(_psol_TX_kPa(T_K, x));
}

/** Solution temperature [K] from solution specific enthalpy
 *  h [kJ/kg] and ammonia mass fraction x (100 bisection steps over
 *  the hsol domain T in [273.15, 353.15] K).  Returns null when h
 *  lies outside the hsol range at x. */
function tsol_by_hsol(h, x) {
  const lo = 273.15, hi = 353.15;
  const hlo = hsol(lo, x), hhi = hsol(hi, x);
  if (!(hlo <= h && h <= hhi)) {
    return null;
  }
  let loT = lo, hiT = hi;
  for (let i = 0; i < 100; i++) {
    const mid = 0.5 * (loT + hiT);
    if (hsol(mid, x) < h) {
      loT = mid;
    } else {
      hiT = mid;
    }
  }
  return 0.5 * (loT + hiT);
}

/** Solution specific heat [kJ/(kg K)] (Libotean et al. 2008). */
function cp(T_K, x) {
  _check(T_K, x, _T_VLE, _X_VLE, 'cp');
  const cpa = _CPA[0] + _CPA[1] * x;
  const cpb = _CPB[0] + _CPB[1] * x;
  return cpa + cpb * T_K;
}

/** Solution density [kg/m^3] (Libotean et al. 2008). */
function rho(T_K, x) {
  _check(T_K, x, _T_VLE, _X_VLE, 'rho');
  const da = _DA[0] + _DA[1] * x;
  const db = _DB[0] + _DB[1] * x;
  return 1000.0 * (da + db * T_K);
}

/** Solution thermal conductivity [W/(m K)] (Cuenca et al. 2013a;
 *  ka3 term without the extra x, as in the Python set). */
function k_therm(T_K, x) {
  _check(T_K, x, _T_KTH, _X_KTH, 'k_therm');
  return _KA1 + _KA2 * T_K + _KA3 * T_K * T_K + _KA4 * x;
}

// ---------------------------------------------------------------------------
// Crystallisation limit (Infante Ferreira et al. 1984; verbatim)
// ---------------------------------------------------------------------------

/** Crystallisation-limit quantity XCRIS: ten segments branching on
 *  the ammonia mass fraction x, polynomials in T_C [degC]; branch
 *  endpoints belong to the segment of the lower bound.  x > 1
 *  throws RANGE, exactly where the Python set raises ValueError. */
function x_cris(T_C, x) {
  const T = T_C;
  if (x < 0.2911) {
    return 0.3021 - 0.00034 * T - 0.00000272 * T * T;
  }
  if (x < 0.3) {
    return x;
  }
  if (x < 0.3076) {
    return -0.000608 * T + 0.3152;
  }
  if (x < 0.3362) {
    return 0.0143 * T + 0.12885;
  }
  if (x < 0.4304) {
    return -0.005402 * T + 0.41318;
  }
  if (x < 0.5072) {
    return 0.443413 + 0.0069 * T + 0.000854 * T * T;
  }
  if (x < 0.6434) {
    return 0.527643 - 0.003126 * T - 0.000019 * T * T;
  }
  if (x < 0.6649) {
    return -0.004605 * T + 0.40761;
  }
  if (x < 0.7826) {
    return 0.0000309 * T * T + 0.57452;
  }
  if (x <= 1.0) {
    return 0.07378 * T + 6.7214;
  }
  throw domainError('RANGE', `x_cris: x=${x} outside [0, 1]`);
}

module.exports = {
  psol_TX, T_bubble_PX, x_by_tsol_tdew, hsol, tdew_from_tsol_x,
  tsol_by_hsol, cp, rho, k_therm, x_cris,
};

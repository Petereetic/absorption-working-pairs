'use strict';
/*
 * r22_dmf.js -- R22 (1) - DMF (2) bubble-point pressure and
 * solution enthalpy (JavaScript set of the absorption-working-pairs
 * library; companion to r22_dmf.py / .c / .bas).
 * ==========================================================================
 * Source
 * ------
 * Bubble pressure: Agarwal 1982 VLE data (via Ardita thesis
 * Lampiran-7, 132 points, xi >= 0.10), fitted per isopleth with
 * Antoine ln(P/bar) = A + B/T + C*ln(T) (T in K) and interpolated
 * in the R22 mass fraction xi by monotone cubic (PCHIP,
 * Fritsch-Carlson).  Fit quality against the data: AARD 2.38 %,
 * max 9.6 % (C header note).  Note xi > 0.80 and T > 65 degC
 * extrapolates beyond the measured data (R22 near/supercritical),
 * as flagged in the C header.
 *
 * Solution enthalpy: Fatouh et al. 1993 correlations (via Ardita
 * thesis Ch. 2, Eqs. 2.38-2.43), T in K, h in kJ/kg.
 *
 * Conventions
 * -----------
 * xi : R22 MASS fraction.
 * T  : degC at the public boundary.
 * P  : MPa at the public boundary; internal native unit is bar:
 *      private *_bar helpers carry the original formulas verbatim,
 *      public functions only scale at the boundary (MPa = bar x 0.1
 *      on return, MPa x 10 on input).
 * h  : kJ/kg.  Reference state (C header): 100 kJ/kg liquid at
 *      273.15 K; hliq_R22(0 degC) and h_DMF(0 degC) both evaluate
 *      to about 100 kJ/kg under this convention.
 * Function names are exactly the Python set's public names; no
 * aliases are kept.  Internal arithmetic and coefficients are
 * copied verbatim from r22_dmf.py; only the domain discipline
 * below is this set's own rendering of the source-stated domains.
 * Python None is rendered as null here.
 *
 * Domain discipline
 * -----------------
 * Only domains stated below produce a RANGE error (an Error with
 * .code 'RANGE'); all internal calls use the raw private
 * implementations so the public checks never corrupt the Python
 * logic:
 *   psol            : T_C outside [-25, 120] throws RANGE (source:
 *                     C header, valid T -25..120 degC); xi outside
 *                     [0.10, 1.00] throws RANGE (designed
 *                     divergence: Python clamps xi to
 *                     [0.10, 1.00] and returns a value; source:
 *                     C header, valid xi 0.10..1.00).
 *   bubble_T        : xi outside [0.10, 1.00] throws RANGE
 *                     (designed divergence: Python clamps xi);
 *                     P outside the raw psol span over the bracket
 *                     T in [-25, 120] degC returns null (mirrors
 *                     Python, 60 bisection steps).
 *   xi_by_tsol_tdew : Tsol_C outside [-25, 120] or Tdew_C outside
 *                     [-25, 120] throws RANGE (designed
 *                     divergence: Python has no check and returns
 *                     None or a value via the psol span);
 *                     otherwise mirrors Python: P = raw
 *                     _psol_bar(Tdew, 1.0), 80 bisection steps
 *                     over xi in [0.10, 1.00], no root returns
 *                     null.
 *   tdew_by_tsol_xi : same T / xi public discipline as psol
 *                     (throws RANGE); otherwise follows the raw
 *                     path _bubble_T_bar(_psol_bar(T, xi), 1.0),
 *                     no root returns null.
 *   hliq_R22        : T_C outside [-20, 95] throws RANGE (source:
 *   hgas_R22          Fatouh valid approx. -20..95 degC; designed
 *   h_DMF             divergence: Python's polynomials have no
 *                     check and evaluate anyway).
 *   hsol            : T_C outside [-20, 95] or xi outside [0, 1]
 *                     throws RANGE; xi == 0 returns h_DMF,
 *                     xi == 1 returns hliq_R22, xi <= 0.9 uses the
 *                     raw Fatouh correlation, 0.9 < xi < 1 uses a
 *                     linear blend to pure R22, verbatim from
 *                     Python.
 *   tsol_by_hsol    : xi outside [0, 1] throws RANGE; h outside
 *                     the raw hsol span over T in [-20, 95] degC
 *                     returns null (mirrors Python, 100 bisection
 *                     steps); internal hsol calls use the raw
 *                     version (unaffected by the public T check,
 *                     and always inside the bracket anyway).
 */

// ---------------------------------------------------------------------------
// Coefficients (verbatim from r22_dmf.py)
// ---------------------------------------------------------------------------

// xi(R22 mass frac), A, B, C (fit to Agarwal 1982, xi >= 0.10)
const _ISO = [
  [0.10000,  30.772744, -3182.9395, -3.629138],
  [0.23076,  10.400862, -2459.9752, -0.388685],
  [0.32000,  10.271208, -2405.5462, -0.311415],
  [0.40348,  -5.848160, -1618.6504,  2.088399],
  [0.50000,  39.598401, -3709.7856, -4.591025],
  [0.60220,  27.566449, -3089.5702, -2.819850],
  [0.70000,  28.096798, -3022.7056, -2.907606],
  [0.80000,  51.969188, -4223.6822, -6.297351],
  [0.90000,  99.166678, -6197.2000, -13.369886],
  [1.00000,  18.474130, -2766.7568, -1.197267],
];
const _XI_LO = 0.10, _XI_HI = 1.00;

// Fatouh et al. 1993 solution enthalpy (thesis eq 2.38-2.43)
const _MR22 = 86.47, _MDMF = 73.09, _R = 8.314;  // g/mol, kJ/(kmol K)
const _F_R22_L = [[-68.14840, 0.0631300, 0.0020200, 253.15, 323.15],
                  [1966.645, -12.09784, 0.02018352, 323.15, 368.15]];
const _F_R22_V = [[37.22971, 1.599520, -0.002260308, 253.15, 323.15],
                  [-2720.182, 18.11784, -0.02699451, 323.15, 368.15]];
const _F_DMF = [-352.2493, 1.317081, 0.001239553];
const _B = [-1817.206, -4302.679, 9877.574, 0.0];
const _C = [-135585.8, 625797.9, -1435546.0, 0.0];
const _E1 = -7738.2052, _E2 = 0.05627680, _E3 = -34.79;

function domainError(code, message) {
  const e = new Error(message);
  e.code = code;
  return e;
}

// ---------------------------------------------------------------------------
// Raw private implementations (no range checks, mirroring Python)
// ---------------------------------------------------------------------------

/** Monotone cubic (PCHIP, Fritsch-Carlson) interpolation. */
function _pchip(x, y, xq) {
  const n = x.length;
  const h = [], d = [];
  for (let i = 0; i < n - 1; i++) {
    h.push(x[i + 1] - x[i]);
    d.push((y[i + 1] - y[i]) / h[i]);
  }
  const dk = new Array(n).fill(0.0);
  dk[0] = d[0];
  dk[n - 1] = d[n - 2];
  for (let k = 1; k < n - 1; k++) {
    if (d[k - 1] * d[k] <= 0) {
      dk[k] = 0.0;
    } else {
      const w1 = 2 * h[k] + h[k - 1];
      const w2 = h[k] + 2 * h[k - 1];
      dk[k] = (w1 + w2) / (w1 / d[k - 1] + w2 / d[k]);
    }
  }
  // bisect_right(x, xq) - 1, clamped to [0, n-2], as in Python
  let br = 0;
  for (let i = 0; i < n; i++) {
    if (x[i] <= xq) br = i + 1;
  }
  const k = Math.min(Math.max(br - 1, 0), n - 2);
  const t = (xq - x[k]) / h[k];
  const t2 = t * t, t3 = t2 * t;
  return ((2 * t3 - 3 * t2 + 1) * y[k] + (t3 - 2 * t2 + t) * h[k] * dk[k]
        + (-2 * t3 + 3 * t2) * y[k + 1] + (t3 - t2) * h[k] * dk[k + 1]);
}

/** Bubble-point pressure [bar], native; xi clamped as in Python. */
function _psol_bar(T_C, xi) {
  const T = T_C + 273.15;
  const xc = Math.min(Math.max(xi, _XI_LO), _XI_HI);
  const xs = _ISO.map(r => r[0]);
  const Pj = _ISO.map(r => Math.exp(r[1] + r[2] / T + r[3] * Math.log(T)));
  return _pchip(xs, Pj, xc);
}

/** Bubble-point temperature [degC] at P [bar], native; null if
 *  the pressure is outside the psol span over the bracket. */
function _bubble_T_bar(P_bar, xi, Tlo_C, Thi_C) {
  if (Tlo_C === undefined) Tlo_C = -25.0;
  if (Thi_C === undefined) Thi_C = 120.0;
  const xc = Math.min(Math.max(xi, _XI_LO), _XI_HI);
  const Plo = _psol_bar(Tlo_C, xc), Phi = _psol_bar(Thi_C, xc);
  if (!(Plo <= P_bar && P_bar <= Phi)) {
    return null;
  }
  let lo = Tlo_C, hi = Thi_C;
  for (let i = 0; i < 60; i++) {
    const mid = 0.5 * (lo + hi);
    if (_psol_bar(mid, xc) < P_bar) {
      lo = mid;
    } else {
      hi = mid;
    }
  }
  return 0.5 * (lo + hi);
}

function _poly(F, T) {
  const F0 = F[0], F1 = F[1], F2 = F[2];
  return F0 + F1 * T + F2 * T * T;
}

/** R22 saturated liquid enthalpy [kJ/kg], raw. */
function _hliq_R22_raw(T_C) {
  const T = T_C + 273.15;
  const F = T < 323.15 ? _F_R22_L[0] : _F_R22_L[1];
  return _poly(F, T);
}

/** R22 saturated vapour enthalpy [kJ/kg], raw. */
function _hgas_R22_raw(T_C) {
  const T = T_C + 273.15;
  const F = T < 323.15 ? _F_R22_V[0] : _F_R22_V[1];
  return _poly(F, T);
}

/** DMF liquid enthalpy [kJ/kg], raw. */
function _h_DMF_raw(T_C) {
  return _poly(_F_DMF, T_C + 273.15);
}

/** Raw Fatouh correlation (valid xi <= 0.9; hmix does not vanish
 *  at xi = 1). */
function _h_fatouh(T_C, xi) {
  const T = T_C + 273.15;
  const omx = 1.0 - xi;
  const Y0 = xi / omx;
  const Y1 = xi / omx + Math.log(omx);
  const Y2 = 1.0 / omx - omx + 2.0 * Math.log(omx);
  const Y3 = xi / omx + xi * xi / 2.0 + 2.0 * xi + 3.0 * Math.log(omx);
  const T2 = T * T, T3 = T * T * T;
  const K0 = _B[0] / T2 + 2 * _C[0] / T3 - _E1 / T2 + _E2 + _E3 / T;
  const K1 = _B[1] / T2 + 2 * _C[1] / T3;
  const K2 = _B[2] / T2 + 2 * _C[2] / T3;
  const K3 = _B[3] / T2 + 2 * _C[3] / T3;
  const Mmix = xi * _MR22 + omx * _MDMF;
  const hmix = (omx * _R * T2 / Mmix) * (K0 * Y0 + K1 * Y1 + K2 * Y2 + K3 * Y3);
  return xi * _hliq_R22_raw(T_C) + omx * _h_DMF_raw(T_C) + hmix;
}

/** Solution enthalpy [kJ/kg], raw: verbatim branch structure of
 *  the Python hsol. */
function _hsol_raw(T_C, xi) {
  if (xi <= 0.0) return _h_DMF_raw(T_C);
  if (xi >= 1.0) return _hliq_R22_raw(T_C);
  if (xi <= 0.9) return _h_fatouh(T_C, xi);
  const h09 = _h_fatouh(T_C, 0.9);
  return h09 + (xi - 0.9) / 0.1 * (_hliq_R22_raw(T_C) - h09);
}

// ---------------------------------------------------------------------------
// Public functions (MPa boundary, Python names verbatim)
// ---------------------------------------------------------------------------

/** Bubble-point pressure [MPa].  T_C in degC, xi = R22 mass
 *  fraction.  T_C outside [-25, 120] or xi outside [0.10, 1.00]
 *  throws RANGE. */
function psol(T_C, xi) {
  if (!(-25.0 <= T_C && T_C <= 120.0)) {
    throw domainError('RANGE',
      `psol: T_C=${T_C} is outside the domain T_C in [-25, 120]`);
  }
  if (!(_XI_LO <= xi && xi <= _XI_HI)) {
    throw domainError('RANGE',
      `psol: xi=${xi} is outside the domain xi in [0.10, 1.00]`);
  }
  return _psol_bar(T_C, xi) * 0.1;
}

/** Bubble-point temperature [degC] by bisection; P_MPa in MPa.
 *  Returns null if out of range.  xi outside [0.10, 1.00] throws
 *  RANGE. */
function bubble_T(P_MPa, xi, Tlo_C, Thi_C) {
  if (Tlo_C === undefined) Tlo_C = -25.0;
  if (Thi_C === undefined) Thi_C = 120.0;
  if (!(_XI_LO <= xi && xi <= _XI_HI)) {
    throw domainError('RANGE',
      `bubble_T: xi=${xi} is outside the domain xi in [0.10, 1.00]`);
  }
  return _bubble_T_bar(P_MPa * 10.0, xi, Tlo_C, Thi_C);
}

/** Concentration from dew-point temperature and solution
 *  temperature.  Tsol_C or Tdew_C outside [-25, 120] throws RANGE;
 *  otherwise mirrors Python (P = raw _psol_bar(Tdew, 1.0), 80
 *  bisection steps, no root returns null). */
function xi_by_tsol_tdew(Tsol_C, Tdew_C) {
  if (!(-25.0 <= Tsol_C && Tsol_C <= 120.0)) {
    throw domainError('RANGE',
      `xi_by_tsol_tdew: Tsol_C=${Tsol_C} is outside the domain ` +
      'Tsol_C in [-25, 120]');
  }
  if (!(-25.0 <= Tdew_C && Tdew_C <= 120.0)) {
    throw domainError('RANGE',
      `xi_by_tsol_tdew: Tdew_C=${Tdew_C} is outside the domain ` +
      'Tdew_C in [-25, 120]');
  }
  const P = _psol_bar(Tdew_C, 1.0);
  const Plo = _psol_bar(Tsol_C, _XI_LO), Phi = _psol_bar(Tsol_C, _XI_HI);
  if (!(Plo <= P && P <= Phi)) {
    return null;
  }
  let lo = _XI_LO, hi = _XI_HI;
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

/** Dew-point temperature [degC] of the solution at (T_C, xi):
 *  Tdew = bubble_T(psol(T_C, xi), 1.0) on this module's own
 *  pure-R22 isopleth (DMF treated as non-volatile), evaluated on
 *  the raw native bar functions.  Same T / xi public discipline
 *  as psol (throws RANGE); no root returns null. */
function tdew_by_tsol_xi(T_C, xi) {
  if (!(-25.0 <= T_C && T_C <= 120.0)) {
    throw domainError('RANGE',
      `tdew_by_tsol_xi: T_C=${T_C} is outside the domain ` +
      'T_C in [-25, 120]');
  }
  if (!(_XI_LO <= xi && xi <= _XI_HI)) {
    throw domainError('RANGE',
      `tdew_by_tsol_xi: xi=${xi} is outside the domain xi in [0.10, 1.00]`);
  }
  return _bubble_T_bar(_psol_bar(T_C, xi), 1.0);
}

/** Solution temperature [degC] from specific enthalpy h [kJ/kg]
 *  and R22 mass fraction xi: bisection inverse of hsol over T in
 *  [-20, 95] degC.  xi outside [0, 1] throws RANGE; h outside the
 *  raw hsol span at xi returns null.  Internal hsol calls use the
 *  raw version. */
function tsol_by_hsol(h, xi) {
  if (!(0.0 <= xi && xi <= 1.0)) {
    throw domainError('RANGE',
      `tsol_by_hsol: xi=${xi} is outside the domain xi in [0, 1]`);
  }
  const lo = -20.0, hi = 95.0;
  const hlo = _hsol_raw(lo, xi), hhi = _hsol_raw(hi, xi);
  if (!(hlo <= h && h <= hhi)) {
    return null;
  }
  let a = lo, b = hi;
  for (let i = 0; i < 100; i++) {
    const mid = 0.5 * (a + b);
    if (_hsol_raw(mid, xi) < h) {
      a = mid;
    } else {
      b = mid;
    }
  }
  return 0.5 * (a + b);
}

/** R22 saturated liquid enthalpy [kJ/kg].
 *  T_C outside [-20, 95] throws RANGE. */
function hliq_R22(T_C) {
  if (!(-20.0 <= T_C && T_C <= 95.0)) {
    throw domainError('RANGE',
      `hliq_R22: T_C=${T_C} is outside the domain T_C in [-20, 95]`);
  }
  return _hliq_R22_raw(T_C);
}

/** R22 saturated vapour enthalpy [kJ/kg].
 *  T_C outside [-20, 95] throws RANGE. */
function hgas_R22(T_C) {
  if (!(-20.0 <= T_C && T_C <= 95.0)) {
    throw domainError('RANGE',
      `hgas_R22: T_C=${T_C} is outside the domain T_C in [-20, 95]`);
  }
  return _hgas_R22_raw(T_C);
}

/** DMF liquid enthalpy [kJ/kg].
 *  T_C outside [-20, 95] throws RANGE. */
function h_DMF(T_C) {
  if (!(-20.0 <= T_C && T_C <= 95.0)) {
    throw domainError('RANGE',
      `h_DMF: T_C=${T_C} is outside the domain T_C in [-20, 95]`);
  }
  return _h_DMF_raw(T_C);
}

/** R22-DMF solution enthalpy [kJ/kg].  T_C in degC, xi = R22 mass
 *  fraction.  T_C outside [-20, 95] or xi outside [0, 1] throws
 *  RANGE; otherwise verbatim from Python (xi == 0 -> h_DMF,
 *  xi == 1 -> hliq_R22, xi <= 0.9 raw Fatouh, 0.9 < xi < 1 linear
 *  blend). */
function hsol(T_C, xi) {
  if (!(-20.0 <= T_C && T_C <= 95.0)) {
    throw domainError('RANGE',
      `hsol: T_C=${T_C} is outside the domain T_C in [-20, 95]`);
  }
  if (!(0.0 <= xi && xi <= 1.0)) {
    throw domainError('RANGE',
      `hsol: xi=${xi} is outside the domain xi in [0, 1]`);
  }
  return _hsol_raw(T_C, xi);
}

module.exports = {
  psol, bubble_T, xi_by_tsol_tdew, tdew_by_tsol_xi, tsol_by_hsol,
  hliq_R22, hgas_R22, h_DMF, hsol,
};

'use strict';
/*
 * r22_degdme.js -- R22-DEGDME bubble-point pressure, molar heat
 * capacity, heat of mixing and solution enthalpy (JavaScript set
 * of the absorption-working-pairs library; companion to
 * r22_degdme.py / .c / .bas).
 * ==========================================================================
 * Source
 * ------
 * E. Ando, I. Takeshita, "Residential gas-fired absorption heat
 * pump based on R22-DEGDME pair. Part I Thermodynamic properties
 * of the R22-DEGDME pair", Int. J. Refrigeration, Vol.7, No.3,
 * pp.181-186, 1984.  All correlations are computable; constants
 * are taken directly from Table 2, Table 3 and Eq. (7) of the
 * paper:
 *   Eq. (1) Bubble-point pressure, Rankine equation
 *           lnP = sum(An X^n) + (1/T) sum(Bn X^n)
 *                 + lnT sum(Cn X^n), n = 0..5 (Table 2).
 *           P in kg/cm2, T in K, X = R22 mole fraction; valid
 *           X = 0.1~1.0, P = 0.1~30 kg/cm2, T = -20~190 degC;
 *           151 points, mean relative deviation 0.79 %.
 *   Eq. (6) Molar heat capacity
 *           C = sum(An X^n) + t sum(Bn X^n) + t^2 sum(Cn X^n),
 *           n = 0..3 (Table 3).  C in J/mol/degC, t in degC;
 *           all concentrations, t = -30~110 degC; 193 points,
 *           mean relative deviation 0.83 %.
 *   Eq. (7) Heat of mixing, Redlich-Kister
 *           dHm = X(1-X) sum(Gi (1-2X)^(i-1)), i = 1..4.
 *           dHm in J/mol, measured at 10 degC; 11 points,
 *           mean relative deviation 0.72 %.  At X = 0.5 the exact
 *           value is -4765.25 J/mol (the formula notes quote the
 *           rounded -4765 J/mol; the paper Fig. 6 minimum is
 *           about -5000 J/mol).
 *   Eq. (9) Solution-enthalpy assembly
 *           H(T,X) = (1-X)H1 + X H2 + dHm
 *                    + integral(Tm -> T) Cp dtau.
 *
 * Conventions
 * -----------
 * X  : R22 MOLE fraction (the paper's system), not a mass
 *      fraction.
 * DEGDME is treated as non-volatile: the dew point is this
 * module's own pure-R22 line, i.e. Eq. (1) at the X = 1 end.
 * Temperature units differ per function and follow the Python
 * signatures exactly: psol_kgcm2 takes T in K; psol_bar,
 * xi_by_tsol_tdew, tdew_by_tsol_xi, cp_molar and hsol take
 * temperatures in degC; tsol_by_hsol returns degC.
 * P  : MPa at the public boundary, with ONE exception:
 *      psol_kgcm2 returns kg/cm2 (see the exception note below).
 *      psol_bar returns MPa = native kg/cm2 value x 0.0980665
 *      (exact definition 1 kg/cm2 = 0.0980665 MPa).  The name
 *      psol_bar is the retained original name (renaming pending
 *      a ruling); its return unit was changed from bar to MPa
 *      on 2026-10-14.  All internal pressure links run on the
 *      native kg/cm2 private function, never through the public
 *      MPa line, so temperature/concentration outputs are
 *      unchanged by the boundary scaling.
 * h  : hsol in kJ/kg; cp_molar in J/mol/degC; heat_of_mixing in
 *      J/mol.
 * Function names are exactly the Python set's public names; no
 * aliases are kept.  Internal arithmetic and coefficients are
 * copied verbatim from r22_degdme.py; only the domain discipline
 * below is this set's own rendering of the source-stated
 * domains.  Python None is rendered as null here.
 *
 * Reference state (a convention of the formula notes; Part I of
 * the paper fixes no absolute enthalpy value)
 * ----------------------------------------------------------------
 * The pure-component liquids have enthalpy 0 at Tm = 10 degC;
 * then H(T,X) = dHm(X) + integral(10 degC -> t) Cp(X,tau) dtau
 * [J/mol], divided by the mixture molar mass to give kJ/kg.
 * Molar masses: R22 86.47 g/mol, DEGDME 134.17 g/mol.  At the
 * reference temperature itself, hsol(X, 10 degC) reduces by
 * construction to heat_of_mixing(X) / M_mix(X); e.g.
 * hsol(0.5, 10 degC) = -4765.25 / 110.32
 * = -43.194796954314725 kJ/kg.
 *
 * The kg/cm2 exception (psol_kgcm2)
 * ---------------------------------
 * psol_kgcm2 is the library's only kg/cm2 legacy line retained
 * by ruling (full-library MPa conversion inventory, section 5:
 * retained pending a ruling).  This set keeps it verbatim from
 * Python: argument T in K, return value in kg/cm2, no unit
 * conversion.  Eq. (1) itself is stated in kg/cm2 in the source,
 * and the inverse functions below link through it natively.
 *
 * Domain discipline (designed divergence from Python)
 * ---------------------------------------------------
 * The Python set states the source ranges in its header and
 * docstrings but performs NO range checks (except the no-root
 * brackets of the inverse functions, which return None) and
 * evaluates anyway.  This set enforces the source-stated
 * domains at the public boundary: an out-of-domain input throws
 * an Error with .code 'RANGE'.  All internal calls use the raw
 * private implementations so the public checks never corrupt
 * the Python logic.  Per function:
 *   psol_kgcm2      : X outside [0.1, 1.0] throws RANGE (Eq. (1)
 *                     source domain); T_K outside
 *                     [253.15, 463.15] K (= -20~190 degC) throws
 *                     RANGE.  The Eq. (1) fit band
 *                     P in [0.1, 30] kg/cm2 is a fit-quality
 *                     statement about the data, not an input
 *                     domain; no result check is applied
 *                     (pending a ruling, see the jurisdiction
 *                     table).
 *   psol_bar        : X outside [0.1, 1.0] or t_C outside
 *                     [-20, 190] throws RANGE (same Eq. (1)
 *                     domain; boundary conversion only: the raw
 *                     kg/cm2 value x 0.0980665).
 *   xi_by_tsol_tdew : Tsol_C outside [-20, 190] throws RANGE
 *                     (Eq. (1) domain at the solution end);
 *                     Tdew_C outside [-50, 190] throws RANGE
 *                     (the dew temperature is read on the pure
 *                     end of Eq. (1); the lower bound follows
 *                     the [-50, 190] degC solution bracket of
 *                     tdew_by_tsol_xi, whose sub -20 degC part
 *                     is the documented pure-end extrapolation,
 *                     so that dew temperatures produced by
 *                     tdew_by_tsol_xi can be fed back; whether
 *                     the strict Eq. (1) bound -20 degC should
 *                     apply instead is pending a ruling).
 *                     Otherwise mirrors Python: P = raw
 *                     psol_kgcm2(1.0, Tdew), 80 bisection steps
 *                     over X in [0.1, 1.0], no root returns
 *                     null.
 *   tdew_by_tsol_xi : X outside [0.1, 1.0] or t_C outside
 *                     [-20, 190] throws RANGE (Eq. (1) domain);
 *                     otherwise mirrors Python: 80 bisection
 *                     steps over the bracket t in [-50, 190]
 *                     degC on the pure end, no root returns
 *                     null.  NOTE: the nominal Eq. (1)
 *                     temperature domain is -20~190 degC;
 *                     results with Tdew < -20 degC use an
 *                     extrapolation of the pure end outside its
 *                     domain (an extrapolation of the
 *                     Rankine-type equation form); this note
 *                     must accompany any citation.  The result
 *                     is NOT range-checked (mirrors Python).
 *   tsol_by_hsol    : X outside [0, 1] throws RANGE (mole
 *                     fraction physical bound; Eq. (6) states
 *                     all concentrations -- the reading of that
 *                     phrase as [0, 1] is pending a ruling);
 *                     h outside the raw hsol span over the
 *                     bracket t in [-30, 110] degC (the domain
 *                     of Eq. (6)) returns null (mirrors Python,
 *                     100 bisection steps); internal hsol calls
 *                     use the raw version.
 *   cp_molar        : X outside [0, 1] throws RANGE (same
 *                     all-concentrations reading as above);
 *                     t_C outside [-30, 110] throws RANGE
 *                     (Eq. (6) source domain).
 *   heat_of_mixing  : X outside [0, 1] throws RANGE.  Eq. (7)
 *                     states no explicit X interval (11 points
 *                     measured at 10 degC); [0, 1] is the
 *                     physical mole-fraction bound (pending a
 *                     ruling).  The function has no temperature
 *                     parameter; the 10 degC measurement
 *                     temperature is the reference temperature
 *                     of the enthalpy assembly, not an input
 *                     domain.
 *   hsol            : X outside [0, 1] throws RANGE (as above);
 *                     t_C outside [-30, 110] throws RANGE
 *                     (the enthalpy is assembled by integrating
 *                     Eq. (6) Cp from 10 degC, so the Eq. (6)
 *                     temperature domain governs; Eq. (9)
 *                     itself states no separate t range).
 */

// ---------------------------------------------------------------------------
// Coefficients (verbatim from r22_degdme.py)
// ---------------------------------------------------------------------------

const _M_R22 = 86.47;      // g/mol, CHClF2
const _M_DEGDME = 134.17;  // g/mol, C6H14O3 (bis(2-methoxyethyl)ether)
const _TM_C = 10.0;        // heat-of-mixing measurement temperature / enthalpy reference temperature, degC
const _KGCM2_TO_MPA = 0.0980665;  // 1 kg/cm2 = 0.0980665 MPa (exact definition)

// Table 2: (A, B, C) of Eq. (1) for n=0..5
const _T2 = [
  [ 5.2167e1, -5.5828e3, -6.3489e0],
  [ 1.2753e1,  3.3999e3, -1.4386e0],
  [-1.3901e2, -8.6015e3,  2.2313e1],
  [ 7.3205e2, -3.1686e3, -1.1454e2],
  [-1.1910e3,  3.0425e4,  1.8148e2],
  [ 5.4717e2, -1.9049e4, -8.1999e1],
];

// Table 3: (A, B, C) of Eq. (6) for n=0..3
const _T3 = [
  [ 2.7974e2, -4.2015e-2,  2.3114e-3],
  [-1.5075e2,  5.9865e-1, -5.9745e-3],
  [ 1.0095e2, -1.3790e0,   3.4322e-3],
  [-1.2802e2,  1.0167e0,   1.0571e-3],
];

// Eq. (7): G1..G4
const _G = [-1.9061e4, 8.7280e3, -1.3948e3, -6.4218e2];

function domainError(code, message) {
  const e = new Error(message);
  e.code = code;
  return e;
}

// ---------------------------------------------------------------------------
// Raw private implementations (no range checks, mirroring Python)
// ---------------------------------------------------------------------------

function _poly(coefs, X) {
  let s = 0.0;
  for (let n = 0; n < coefs.length; n++) {
    s += coefs[n] * X ** n;
  }
  return s;
}

/** Eq. (1) native value (private): bubble-point pressure,
 *  kg/cm2.  X = R22 mole fraction, T_K in kelvin. */
function _psol_kgcm2_raw(X, T_K) {
  const sA = _poly(_T2.map(r => r[0]), X);
  const sB = _poly(_T2.map(r => r[1]), X);
  const sC = _poly(_T2.map(r => r[2]), X);
  return Math.exp(sA + sB / T_K + sC * Math.log(T_K));
}

/** Eq. (7) raw: molar heat of mixing (measured at 10 degC),
 *  J/mol.  Negative when exothermic. */
function _heat_of_mixing_raw(X) {
  let s = 0.0;
  for (let i = 0; i < _G.length; i++) {
    s += _G[i] * (1.0 - 2.0 * X) ** i;
  }
  return X * (1.0 - X) * s;
}

/** Eq. (6) raw: molar heat capacity of the mixture at constant
 *  pressure, J/mol/degC. */
function _cp_molar_raw(X, t_C) {
  const sA = _poly(_T3.map(r => r[0]), X);
  const sB = _poly(_T3.map(r => r[1]), X);
  const sC = _poly(_T3.map(r => r[2]), X);
  return sA + t_C * sB + t_C * t_C * sC;
}

/** Eq. (9) raw: solution specific enthalpy, kJ/kg.
 *  Reference state: the pure-component liquids have enthalpy 0
 *  at 10 degC (a convention of the formula notes). */
function _hsol_raw(X, t_C) {
  const sA = _poly(_T3.map(r => r[0]), X);
  const sB = _poly(_T3.map(r => r[1]), X);
  const sC = _poly(_T3.map(r => r[2]), X);
  const t0 = _TM_C;
  const sensible = (sA * (t_C - t0)
                + sB * (t_C * t_C - t0 * t0) / 2.0
                + sC * (t_C ** 3 - t0 ** 3) / 3.0);  // J/mol
  const h_mol = _heat_of_mixing_raw(X) + sensible;  // J/mol
  const M_mix = X * _M_R22 + (1.0 - X) * _M_DEGDME;  // g/mol
  return h_mol / M_mix;  // kJ/kg
}

// ---------------------------------------------------------------------------
// Public functions (Python names verbatim)
// ---------------------------------------------------------------------------

/** Eq. (1): bubble-point pressure, kg/cm2 (retained kg/cm2
 *  legacy exception, pending a ruling; see the header note).
 *  X = R22 mole fraction, T_K in kelvin.  X outside [0.1, 1.0]
 *  or T_K outside [253.15, 463.15] K throws RANGE. */
function psol_kgcm2(X, T_K) {
  if (!(0.1 <= X && X <= 1.0)) {
    throw domainError('RANGE',
      `psol_kgcm2: X=${X} is outside the domain X in [0.1, 1.0]`);
  }
  if (!(253.15 <= T_K && T_K <= 463.15)) {
    throw domainError('RANGE',
      `psol_kgcm2: T_K=${T_K} is outside the domain ` +
      'T_K in [253.15, 463.15]');
  }
  return _psol_kgcm2_raw(X, T_K);
}

/** Eq. (1): bubble-point pressure, MPa.  The function name
 *  psol_bar is the retained original name (renaming pending a
 *  ruling); the return unit is MPa = native kg/cm2 value
 *  x 0.0980665.  X = R22 mole fraction, t_C in degC.  X outside
 *  [0.1, 1.0] or t_C outside [-20, 190] throws RANGE. */
function psol_bar(X, t_C) {
  if (!(0.1 <= X && X <= 1.0)) {
    throw domainError('RANGE',
      `psol_bar: X=${X} is outside the domain X in [0.1, 1.0]`);
  }
  if (!(-20.0 <= t_C && t_C <= 190.0)) {
    throw domainError('RANGE',
      `psol_bar: t_C=${t_C} is outside the domain t_C in [-20, 190]`);
  }
  return _psol_kgcm2_raw(X, t_C + 273.15) * _KGCM2_TO_MPA;
}

/** Solve the concentration X (R22 mole fraction) back from the
 *  dew-point temperature and the solution temperature, by 80
 *  bisection steps.  The dew point fixes the pressure
 *  P = raw psol_kgcm2(1.0, Tdew_C+273.15) [native kg/cm2]; then
 *  bisection solves raw psol_kgcm2(X, Tsol_C+273.15) = P over
 *  X in [0.1, 1.0].  Tsol_C outside [-20, 190] or Tdew_C outside
 *  [-50, 190] throws RANGE; returns null when there is no root.
 *  Internal links use the native kg/cm2 raw function
 *  throughout. */
function xi_by_tsol_tdew(Tsol_C, Tdew_C) {
  if (!(-20.0 <= Tsol_C && Tsol_C <= 190.0)) {
    throw domainError('RANGE',
      `xi_by_tsol_tdew: Tsol_C=${Tsol_C} is outside the domain ` +
      'Tsol_C in [-20, 190]');
  }
  if (!(-50.0 <= Tdew_C && Tdew_C <= 190.0)) {
    throw domainError('RANGE',
      `xi_by_tsol_tdew: Tdew_C=${Tdew_C} is outside the domain ` +
      'Tdew_C in [-50, 190]');
  }
  const P = _psol_kgcm2_raw(1.0, Tdew_C + 273.15);
  const Plo = _psol_kgcm2_raw(0.1, Tsol_C + 273.15);
  const Phi = _psol_kgcm2_raw(1.0, Tsol_C + 273.15);
  if (!(Plo <= P && P <= Phi)) {
    return null;
  }
  let lo = 0.1, hi = 1.0;
  for (let i = 0; i < 80; i++) {
    const mid = 0.5 * (lo + hi);
    if (_psol_kgcm2_raw(mid, Tsol_C + 273.15) < P) {
      lo = mid;
    } else {
      hi = mid;
    }
  }
  return 0.5 * (lo + hi);
}

/** Dew-point temperature [degC] of the solution at (X, t_C):
 *  Tdew is the temperature at which this module's own pure-R22
 *  line (the X = 1 end of Eq. (1)) satisfies
 *  raw psol_kgcm2(1.0, Tdew+273.15) = raw psol_kgcm2(X,
 *  t_C+273.15) [native kg/cm2], inverted by 80 bisection steps
 *  over the bracket t in [-50, 190] degC.  X outside [0.1, 1.0]
 *  or t_C outside [-20, 190] throws RANGE; returns null when P
 *  lies outside the pressure span of the pure end within the
 *  bracket.  Results with Tdew < -20 degC use the documented
 *  pure-end extrapolation (see the header note).  DEGDME is
 *  treated as non-volatile.  (This module's function convention
 *  is the (X, T) parameter order; this function follows it.) */
function tdew_by_tsol_xi(X, t_C) {
  if (!(0.1 <= X && X <= 1.0)) {
    throw domainError('RANGE',
      `tdew_by_tsol_xi: X=${X} is outside the domain X in [0.1, 1.0]`);
  }
  if (!(-20.0 <= t_C && t_C <= 190.0)) {
    throw domainError('RANGE',
      `tdew_by_tsol_xi: t_C=${t_C} is outside the domain ` +
      't_C in [-20, 190]');
  }
  const P = _psol_kgcm2_raw(X, t_C + 273.15);
  const lo = -50.0, hi = 190.0;
  if (!(_psol_kgcm2_raw(1.0, lo + 273.15) <= P &&
        P <= _psol_kgcm2_raw(1.0, hi + 273.15))) {
    return null;
  }
  let a = lo, b = hi;
  for (let i = 0; i < 80; i++) {
    const mid = 0.5 * (a + b);
    if (_psol_kgcm2_raw(1.0, mid + 273.15) < P) {
      a = mid;
    } else {
      b = mid;
    }
  }
  return 0.5 * (a + b);
}

/** Solve the solution temperature [degC] back from the solution
 *  specific enthalpy h [kJ/kg] and R22 mole fraction X: 100
 *  bisection steps over the bracket t in [-30, 110] degC (the
 *  domain of Eq. (6)).  X outside [0, 1] throws RANGE; returns
 *  null when h lies outside the range of raw hsol at that X.
 *  Internal hsol calls use the raw version. */
function tsol_by_hsol(h, X) {
  if (!(0.0 <= X && X <= 1.0)) {
    throw domainError('RANGE',
      `tsol_by_hsol: X=${X} is outside the domain X in [0, 1]`);
  }
  const lo = -30.0, hi = 110.0;
  const hlo = _hsol_raw(X, lo), hhi = _hsol_raw(X, hi);
  if (!(hlo <= h && h <= hhi)) {
    return null;
  }
  let a = lo, b = hi;
  for (let i = 0; i < 100; i++) {
    const mid = 0.5 * (a + b);
    if (_hsol_raw(X, mid) < h) {
      a = mid;
    } else {
      b = mid;
    }
  }
  return 0.5 * (a + b);
}

/** Eq. (6): molar heat capacity of the mixture at constant
 *  pressure, J/mol/degC.  X outside [0, 1] or t_C outside
 *  [-30, 110] throws RANGE. */
function cp_molar(X, t_C) {
  if (!(0.0 <= X && X <= 1.0)) {
    throw domainError('RANGE',
      `cp_molar: X=${X} is outside the domain X in [0, 1]`);
  }
  if (!(-30.0 <= t_C && t_C <= 110.0)) {
    throw domainError('RANGE',
      `cp_molar: t_C=${t_C} is outside the domain t_C in [-30, 110]`);
  }
  return _cp_molar_raw(X, t_C);
}

/** Eq. (7): molar heat of mixing (measured at 10 degC), J/mol.
 *  Negative when exothermic.  X outside [0, 1] throws RANGE
 *  (physical mole-fraction bound; Eq. (7) states no explicit X
 *  interval -- pending a ruling, see the header note). */
function heat_of_mixing(X) {
  if (!(0.0 <= X && X <= 1.0)) {
    throw domainError('RANGE',
      `heat_of_mixing: X=${X} is outside the domain X in [0, 1]`);
  }
  return _heat_of_mixing_raw(X);
}

/** Eq. (9): solution specific enthalpy, kJ/kg.  Reference
 *  state: the pure-component liquids have enthalpy 0 at 10 degC
 *  (a convention of the formula notes).  X outside [0, 1] or
 *  t_C outside [-30, 110] throws RANGE (the Eq. (6) temperature
 *  domain governs the Cp integral).  (This module's function
 *  convention is the (X, T) parameter order; this function
 *  follows it.) */
function hsol(X, t_C) {
  if (!(0.0 <= X && X <= 1.0)) {
    throw domainError('RANGE',
      `hsol: X=${X} is outside the domain X in [0, 1]`);
  }
  if (!(-30.0 <= t_C && t_C <= 110.0)) {
    throw domainError('RANGE',
      `hsol: t_C=${t_C} is outside the domain t_C in [-30, 110]`);
  }
  return _hsol_raw(X, t_C);
}

module.exports = {
  psol_kgcm2, psol_bar, xi_by_tsol_tdew, tdew_by_tsol_xi,
  tsol_by_hsol, cp_molar, heat_of_mixing, hsol,
};

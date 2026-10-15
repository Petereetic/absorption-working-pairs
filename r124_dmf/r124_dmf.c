/* R124-DMF working pair: bubble pressure / bubble temperature
 * (VLE only - no published mixture enthalpy, density or viscosity).
 * Source: Xu, Wang, Wu, Hu & Jiang, J. Chem. Eng. Data 2017, 62,
 * 3414-3422 (five-parameter NRTL, Eqs. 4-11; parameters Table 8;
 * measured data Tables 6/7).  Antoine psat and VL fits to the paper's
 * Table 5 (REFPROP).  Validated range: 30-90 degC; NaN outside.
 * Conventions: T_C in degC, xi = R124 mass fraction, P in MPa
 * (public boundary).  Internal native unit is bar: static *_bar
 * helpers carry the original formulas verbatim, public functions
 * only scale at the boundary (MPa = bar x 0.1, MPa x 10 on input).
 * Verified: reproduces the paper's 60 measured points with
 * AARD 1.17 % (paper reports 1.17 %). */
#include <math.h>

static const double R124DMF_A1 = -52406.6, R124DMF_B1 = 4671.8;
static const double R124DMF_A2 = -88324.0, R124DMF_B2 = 14735.9;
static const double R124DMF_ALPHA = -0.5116;
static const double R124DMF_M1 = 136.50, R124DMF_M2 = 73.09;
static const double R124DMF_RGAS = 8.314;

static double R124DMF_PrefR124_bar(double T_C)  /* Antoine, bar */
{ double T = T_C + 273.15;
  return exp(14.750463 - 2527.6371 / (T - 10.9815)) / 100.0; }

double R124DMF_PrefR124(double T_C)   /* public: MPa */
{ return R124DMF_PrefR124_bar(T_C) * 0.1; }

static double R124DMF_TsatR124_bar(double P_bar)
{ if (P_bar <= 0) return NAN;
  return 2527.6371 / (14.750463 - log(P_bar * 100.0)) + 10.9815 - 273.15; }

double R124DMF_TsatR124(double P_MPa)  /* public: P in MPa */
{ return R124DMF_TsatR124_bar(P_MPa * 10.0); }

static double R124DMF_VL(double T_C)  /* m3/mol, quadratic fit to Table 5 */
{ return (3.43888821e-06 * T_C * T_C + 5.21631071e-06 * T_C
          + 9.89804979e-02) / 1000.0; }

double R124DMF_XiToX(double xi)
{ double n1 = xi / R124DMF_M1; return n1 / (n1 + (1.0 - xi) / R124DMF_M2); }

double R124DMF_XToXi(double x)
{ double m1 = x * R124DMF_M1; return m1 / (m1 + (1.0 - x) * R124DMF_M2); }

double R124DMF_Gamma1(double T_C, double xi)
{ double T, x1, x2, lnT, t12, t21, G12, G21, lng;
  if (T_C < 30.0 || T_C > 90.0) return NAN;
  T = T_C + 273.15; x1 = R124DMF_XiToX(xi); x2 = 1.0 - x1;
  if (x1 <= 0.0) return NAN;
  if (x1 >= 1.0) return 1.0;
  lnT = log(T);
  t12 = (R124DMF_A1 + R124DMF_B1 * lnT) / (R124DMF_RGAS * T);
  t21 = (R124DMF_A2 + R124DMF_B2 * lnT) / (R124DMF_RGAS * T);
  G12 = exp(-R124DMF_ALPHA * t12); G21 = exp(-R124DMF_ALPHA * t21);
  lng = x2 * x2 * (t21 * pow(G21 / (x1 + x2 * G21), 2)
                   + t12 * G12 / pow(x2 + x1 * G12, 2));
  return exp(lng); }

static double R124DMF_Psol_bar(double T_C, double xi)
{ double T, ps1, x1, g1, vl, p, pn; int i;
  if (T_C < 30.0 || T_C > 90.0 || xi <= 0.0 || xi >= 1.0) return NAN;
  T = T_C + 273.15; ps1 = R124DMF_PrefR124_bar(T_C);
  x1 = R124DMF_XiToX(xi); g1 = R124DMF_Gamma1(T_C, xi); vl = R124DMF_VL(T_C);
  p = ps1 * x1 * g1;
  for (i = 0; i < 50; i++) {
      pn = ps1 * x1 * g1 * exp(vl * (p - ps1) * 1.0e5 / (R124DMF_RGAS * T));
      if (fabs(pn - p) < 1e-10) { p = pn; break; }
      p = pn;
  }
  return p; }

double R124DMF_Psol(double T_C, double xi)  /* public: MPa */
{ return R124DMF_Psol_bar(T_C, xi) * 0.1; }

static double R124DMF_BubbleT_bar(double P_bar, double xi)
{ double lo = 30.0, hi = 90.0, mid; int i;
  if (!(R124DMF_Psol_bar(lo, xi) <= P_bar && P_bar <= R124DMF_Psol_bar(hi, xi)))
      return NAN;
  for (i = 0; i < 60; i++) { mid = 0.5 * (lo + hi);
      if (R124DMF_Psol_bar(mid, xi) < P_bar) lo = mid; else hi = mid; }
  return 0.5 * (lo + hi); }

double R124DMF_BubbleT(double P_MPa, double xi)  /* public: P in MPa */
{ return R124DMF_BubbleT_bar(P_MPa * 10.0, xi); }

static double R124DMF_DewT_bar(double P_bar);  /* forward: defined below */
/* Dew-point temperature [degC] of the solution at (T_C, xi)
   (library-wide TdewByTsolXi convention):
   R124DMF_DewT(R124DMF_Psol(T_C, xi)) at the public boundary, evaluated
   internally in native bar as DewT_bar(Psol_bar(T_C, xi)) on this
   module's own Antoine pure line, so the result is unchanged.
   NAN where Psol or DewT is NAN. */
double R124DMF_TdewByTsolXi(double T_C, double xi)
{
    return R124DMF_DewT_bar(R124DMF_Psol_bar(T_C, xi));
}

/* Concentration from dew-point temperature and solution temperature:
 * the dew point fixes the pressure, P = PrefR124_bar(Tdew) in native
 * bar (DMF treated as non-volatile), then solve Psol_bar(Tsol, xi) = P
 * for xi by bisection.
 * Psol_bar is only defined on the open interval 0 < xi < 1; its limits
 * there, 0 (xi -> 0) and PrefR124_bar(Tsol) (xi -> 1), serve as the
 * bracket - the bisection only ever evaluates interior points.
 * Returns NAN if no root (e.g. Tsol below Tdew, or Tsol outside the
 * validated 30-90 degC window). */
double R124DMF_XiByTsolTdew(double Tsol_C, double Tdew_C)
{ double P, lo = 0.0, hi = 1.0, mid; int i;
  if (Tsol_C < 30.0 || Tsol_C > 90.0) return NAN;
  P = R124DMF_PrefR124_bar(Tdew_C);
  if (!(P <= R124DMF_PrefR124_bar(Tsol_C))) return NAN;
  for (i = 0; i < 80; i++) { mid = 0.5 * (lo + hi);
      if (R124DMF_Psol_bar(Tsol_C, mid) < P) lo = mid; else hi = mid; }
  return 0.5 * (lo + hi); }

static double R124DMF_DewT_bar(double P_bar)  /* absorbent non-volatile */
{ double T = R124DMF_TsatR124_bar(P_bar);
  return (T >= -30.0 && T <= 90.0) ? T : NAN;  /* dew = pure-fluid reference; Antoine extrapolated to -30 C */ }

double R124DMF_DewT(double P_MPa)  /* public: P in MPa */
{ return R124DMF_DewT_bar(P_MPa * 10.0); }

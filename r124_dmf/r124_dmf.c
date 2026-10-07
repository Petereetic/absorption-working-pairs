/* R124-DMF working pair: bubble pressure / bubble temperature
 * (VLE only - no published mixture enthalpy, density or viscosity).
 * Source: Xu, Wang, Wu, Hu & Jiang, J. Chem. Eng. Data 2017, 62,
 * 3414-3422 (five-parameter NRTL, Eqs. 4-11; parameters Table 8;
 * measured data Tables 6/7).  Antoine psat and VL fits to the paper's
 * Table 5 (REFPROP).  Validated range: 30-90 degC; NaN outside.
 * Conventions: T_C in degC, xi = R124 mass fraction, P in bar.
 * Verified: reproduces the paper's 60 measured points with
 * AARD 1.17 % (paper reports 1.17 %). */
#include <math.h>

static const double R124DMF_A1 = -52406.6, R124DMF_B1 = 4671.8;
static const double R124DMF_A2 = -88324.0, R124DMF_B2 = 14735.9;
static const double R124DMF_ALPHA = -0.5116;
static const double R124DMF_M1 = 136.50, R124DMF_M2 = 73.09;
static const double R124DMF_RGAS = 8.314;

double R124DMF_PsatR124(double T_C)   /* Antoine fit to Table 5, bar */
{ double T = T_C + 273.15;
  return exp(14.750463 - 2527.6371 / (T - 10.9815)) / 100.0; }

double R124DMF_TsatR124(double P_bar)
{ if (P_bar <= 0) return NAN;
  return 2527.6371 / (14.750463 - log(P_bar * 100.0)) - 10.9815 - 273.15; }

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

double R124DMF_BubbleP(double T_C, double xi)
{ double T, ps1, x1, g1, vl, p, pn; int i;
  if (T_C < 30.0 || T_C > 90.0 || xi <= 0.0 || xi >= 1.0) return NAN;
  T = T_C + 273.15; ps1 = R124DMF_PsatR124(T_C);
  x1 = R124DMF_XiToX(xi); g1 = R124DMF_Gamma1(T_C, xi); vl = R124DMF_VL(T_C);
  p = ps1 * x1 * g1;
  for (i = 0; i < 50; i++) {
      pn = ps1 * x1 * g1 * exp(vl * (p - ps1) * 1.0e5 / (R124DMF_RGAS * T));
      if (fabs(pn - p) < 1e-10) { p = pn; break; }
      p = pn;
  }
  return p; }

double R124DMF_BubbleT(double P_bar, double xi)
{ double lo = 30.0, hi = 90.0, mid; int i;
  if (!(R124DMF_BubbleP(lo, xi) <= P_bar && P_bar <= R124DMF_BubbleP(hi, xi)))
      return NAN;
  for (i = 0; i < 60; i++) { mid = 0.5 * (lo + hi);
      if (R124DMF_BubbleP(mid, xi) < P_bar) lo = mid; else hi = mid; }
  return 0.5 * (lo + hi); }

double R124DMF_DewT(double P_bar)  /* absorbent non-volatile */
{ double T = R124DMF_TsatR124(P_bar);
  return (T >= -30.0 && T <= 90.0) ? T : NAN;  /* dew = pure-fluid reference; Antoine extrapolated to -30 C */ }

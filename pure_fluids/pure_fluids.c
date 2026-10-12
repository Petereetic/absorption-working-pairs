/* R134a / R22 / R124 纯物质饱和性质（C 实现，与 pure_fluids.py 逐点一致）
 * 基准：CoolProp 内置参考状态方程（R134a: Tillner-Roth & Baehr 1994）
 * 参考态：0°C 饱和液体焓 = 100 kJ/kg
 *   Psat: Wagner 方程 ln(P/Pc)=(Tc/T)(a1 τ+a2 τ^1.5+a3 τ^2.5+a4 τ^5), τ=1-T/Tc
 *     R134a: Tc=374.21K Pc=40.59bar, -50~95°C, 偏差 0.031%
 *     R22:   Tc=369.30K Pc=49.90bar, -50~90°C, 偏差 0.0065%
 *   hL/hV: 6 次多项式（t 为 °C），偏差 <0.61 kJ/kg
 *   R124: NIST WebBook 饱和表拟合；Wagner 变体（指数 1, 1.5, 3, 6）,
 *     Tc=395.428K Pc=36.245bar, -40~110°C, Psat 偏差 0.111%,
 *     hL/hV 偏差 <1.63 kJ/kg；焓由表基准（0°C 液体 = 200）平移 -100
 * 编译：gcc -O2 -Wall -o pure_fluids pure_fluids.c -lm
 */
#include <stdio.h>
#include <math.h>

/* ---- R134a ---- */
static const double R134A_TC = 374.21, R134A_PC = 40.59;
static const double R134A_W[4] = {-7.6391282, 1.7650117, -2.6103553, -3.3657380};
static const double R134A_HL[7] = {3.5283163e-11, -2.2259203e-09, -7.2651551e-08,
    1.3659406e-05, 1.4602205e-03, 1.3386046e+00, 9.9982381e+01};
static const double R134A_HV[7] = {-5.4059642e-11, 3.2801028e-09, 1.2592287e-07,
    -2.1005140e-05, -1.2602316e-03, 5.9085680e-01, 2.9863031e+02};
static const double R134A_TLO = -50.0, R134A_THI = 95.0;

/* ---- R22 ---- */
static const double R22_TC = 369.30, R22_PC = 49.90;
static const double R22_W[4] = {-7.0486230, 1.4828095, -1.8223105, -2.8257753};
static const double R22_HL[7] = {4.6681599e-11, -2.2286115e-09, -1.2586426e-07,
    1.4969301e-05, 1.5173919e-03, 1.1678030e+00, 9.9972867e+01};
static const double R22_HV[7] = {-6.5412360e-11, 3.1584987e-09, 1.6628519e-07,
    -2.1606737e-05, -1.9128189e-03, 3.7574587e-01, 3.0508640e+02};
static const double R22_TLO = -50.0, R22_THI = 90.0;

/* ---- R124（NIST 表拟合；焓已平移 -100 至本模块统一基准） ---- */
static const double R124_TC = 395.428, R124_PC = 36.245;
static const double R124_W[4] = {-7.401179377235425, 1.4613603991162563,
    -3.476435267708954, -1.772232810745864};
static const double R124_HL[7] = {3.101121704716488e-12, 6.118884579625834e-10,
    -1.0126584362284601e-08, -3.744431218418699e-06, 9.264564201937477e-04,
    1.0995525531984227, 1.0004767130193036e+02};
static const double R124_HV[7] = {-4.7606354686130485e-12, -9.020883920792309e-10,
    2.036341936229362e-08, 4.234769176716097e-06, -3.8033802108463233e-04,
    5.621038923140594e-01, 2.5994742998138406e+02};
static const double R124_TLO = -40.0, R124_THI = 110.0;

static double wagner_pref(double t_C, double Tc, double Pc, const double *a)
{
    double T = t_C + 273.15, tau = 1.0 - T / Tc;
    double s = a[0]*tau + a[1]*pow(tau,1.5) + a[2]*pow(tau,2.5) + a[3]*pow(tau,5.0);
    return Pc * exp((Tc / T) * s);
}

static double wagner_pref36(double t_C, double Tc, double Pc, const double *a)
{
    double T = t_C + 273.15, tau = 1.0 - T / Tc;
    double s = a[0]*tau + a[1]*pow(tau,1.5) + a[2]*pow(tau,3.0) + a[3]*pow(tau,6.0);
    return Pc * exp((Tc / T) * s);
}

static double poly6(const double *c, double t)
{
    return (((((c[0]*t + c[1])*t + c[2])*t + c[3])*t + c[4])*t + c[5])*t + c[6];
}

typedef double (*pref_fn)(double);

static double tsat_bisect(pref_fn f, double P_bar, double t_lo, double t_hi)
{
    /* 超出范围返回 NAN */
    if (P_bar < f(t_lo) || P_bar > f(t_hi)) return NAN;
    double lo = t_lo, hi = t_hi;
    for (int i = 0; i < 60; i++) {
        double mid = 0.5 * (lo + hi);
        if (f(mid) < P_bar) lo = mid; else hi = mid;
    }
    return 0.5 * (lo + hi);
}

double R134a_Pref(double t_C) { return wagner_pref(t_C, R134A_TC, R134A_PC, R134A_W); }
double R134a_Tsat(double P_bar) { return tsat_bisect(R134a_Pref, P_bar, R134A_TLO, R134A_THI); }
double R134a_hliq(double t_C) { return poly6(R134A_HL, t_C); }
double R134a_hgas(double t_C) { return poly6(R134A_HV, t_C); }
double R134a_hlat(double t_C) { return R134a_hgas(t_C) - R134a_hliq(t_C); }

double R22_Pref(double t_C) { return wagner_pref(t_C, R22_TC, R22_PC, R22_W); }
double R22_Tsat(double P_bar) { return tsat_bisect(R22_Pref, P_bar, R22_TLO, R22_THI); }
double R22_hliq(double t_C) { return poly6(R22_HL, t_C); }
double R22_hgas(double t_C) { return poly6(R22_HV, t_C); }
double R22_hlat(double t_C) { return R22_hgas(t_C) - R22_hliq(t_C); }

double R124_Pref(double t_C) { return wagner_pref36(t_C, R124_TC, R124_PC, R124_W); }
double R124_Tsat(double P_bar) { return tsat_bisect(R124_Pref, P_bar, R124_TLO, R124_THI); }
double R124_hliq(double t_C) { return poly6(R124_HL, t_C); }
double R124_hgas(double t_C) { return poly6(R124_HV, t_C); }
double R124_hlat(double t_C) { return R124_hgas(t_C) - R124_hliq(t_C); }

#ifdef PURE_FLUIDS_MAIN
int main(void)
{
    double ts[] = {-40.0, -10.0, 0.0, 25.0, 50.0, 80.0};
    for (int i = 0; i < 6; i++) {
        double t = ts[i];
        printf("%.1f %.6f %.6f %.6f %.6f %.6f %.6f\n", t,
               R134a_Pref(t), R134a_hliq(t), R134a_hgas(t),
               R22_Pref(t), R22_hliq(t), R22_hgas(t));
    }
    printf("Tsat10 %.6f %.6f\n", R134a_Tsat(10.0), R22_Tsat(10.0));
    return 0;
}
#endif

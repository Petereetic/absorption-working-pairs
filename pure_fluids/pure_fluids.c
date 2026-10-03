/* R134a / R22 纯物质饱和性质（C 实现，与 pure_fluids.py 逐点一致）
 * 基准：CoolProp 内置参考状态方程（R134a: Tillner-Roth & Baehr 1994）
 * 参考态：0°C 饱和液体焓 = 100 kJ/kg
 *   Psat: Wagner 方程 ln(P/Pc)=(Tc/T)(a1 τ+a2 τ^1.5+a3 τ^2.5+a4 τ^5), τ=1-T/Tc
 *     R134a: Tc=374.21K Pc=40.59bar, -50~95°C, 偏差 0.031%
 *     R22:   Tc=369.30K Pc=49.90bar, -50~90°C, 偏差 0.0065%
 *   hL/hV: 6 次多项式（t 为 °C），偏差 <0.61 kJ/kg
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

static double wagner_psat(double t_C, double Tc, double Pc, const double *a)
{
    double T = t_C + 273.15, tau = 1.0 - T / Tc;
    double s = a[0]*tau + a[1]*pow(tau,1.5) + a[2]*pow(tau,2.5) + a[3]*pow(tau,5.0);
    return Pc * exp((Tc / T) * s);
}

static double poly6(const double *c, double t)
{
    return (((((c[0]*t + c[1])*t + c[2])*t + c[3])*t + c[4])*t + c[5])*t + c[6];
}

typedef double (*psat_fn)(double);

static double tsat_bisect(psat_fn f, double P_bar, double t_lo, double t_hi)
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

double R134a_Psat(double t_C) { return wagner_psat(t_C, R134A_TC, R134A_PC, R134A_W); }
double R134a_Tsat(double P_bar) { return tsat_bisect(R134a_Psat, P_bar, R134A_TLO, R134A_THI); }
double R134a_hL(double t_C) { return poly6(R134A_HL, t_C); }
double R134a_hV(double t_C) { return poly6(R134A_HV, t_C); }

double R22_Psat(double t_C) { return wagner_psat(t_C, R22_TC, R22_PC, R22_W); }
double R22_Tsat(double P_bar) { return tsat_bisect(R22_Psat, P_bar, R22_TLO, R22_THI); }
double R22_hL(double t_C) { return poly6(R22_HL, t_C); }
double R22_hV(double t_C) { return poly6(R22_HV, t_C); }

#ifdef PURE_FLUIDS_MAIN
int main(void)
{
    double ts[] = {-40.0, -10.0, 0.0, 25.0, 50.0, 80.0};
    for (int i = 0; i < 6; i++) {
        double t = ts[i];
        printf("%.1f %.6f %.6f %.6f %.6f %.6f %.6f\n", t,
               R134a_Psat(t), R134a_hL(t), R134a_hV(t),
               R22_Psat(t), R22_hL(t), R22_hV(t));
    }
    printf("Tsat10 %.6f %.6f\n", R134a_Tsat(10.0), R22_Tsat(10.0));
    return 0;
}
#endif

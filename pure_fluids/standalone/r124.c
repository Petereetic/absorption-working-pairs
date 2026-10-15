/* R124 纯物质饱和性质（单独计算文件，与合并模块 pure_fluids.c 系数逐字同源）
 * 源：NIST WebBook 饱和表拟合（笔记见 ../fit-notes/R124纯工质-NIST表拟合与Borde仲裁.md），与合并模块 pure_fluids 系数逐字相同；Wagner 变体（1, 1.5, 3, 6）饱和压对表最大偏差 0.111%，焓已由表基准平移 -100 至统一基准。
 * 函数：Pref(MPa) / Tsat(°C，入参 MPa，二分反解，超界返回 NAN) / hliq / hgas / hlat（kJ/kg）。Wagner 拟合内部以 bar 计，公开边界换算。
 * 参考态：0°C 饱和液体焓 = 100 kJ/kg（模块统一基准）。
 * 编译：gcc -O2 -Wall -DSTANDALONE_MAIN -o test_r124 r124.c -lm */
#include <stdio.h>
#include <math.h>

static const double R124_TC = 395.428, R124_PC = 36.245;
static const double R124_W[4] = {-7.401179377235425, 1.4613603991162563, -3.476435267708954, -1.772232810745864};
static const double R124_HL[7] = {3.101121704716488e-12, 6.118884579625834e-10, -1.0126584362284601e-08, -3.744431218418699e-06, 0.0009264564201937477, 1.0995525531984227, 100.04767130193036};
static const double R124_HV[7] = {-4.7606354686130485e-12, -9.020883920792309e-10, 2.036341936229362e-08, 4.234769176716097e-06, -0.00038033802108463233, 0.5621038923140594, 259.94742998138406};
static const double R124_TLO = -40.0, R124_THI = 110.0;

static double poly6(const double *c, double t)
{ return (((((c[0]*t + c[1])*t + c[2])*t + c[3])*t + c[4])*t + c[5])*t + c[6]; }
static double R124_pref_bar(double t_C)
{
    double T = t_C + 273.15, tau = 1.0 - T / R124_TC;
    double s = R124_W[0]*tau + R124_W[1]*pow(tau,1.5) + R124_W[2]*pow(tau,3.0) + R124_W[3]*pow(tau,6.0);
    return R124_PC * exp((R124_TC / T) * s);
}
double R124_Pref(double t_C) { return 0.1 * R124_pref_bar(t_C); }
double R124_Tsat(double P_MPa)
{
    double P_bar = 10.0 * P_MPa;
    if (P_bar < R124_pref_bar(R124_TLO) || P_bar > R124_pref_bar(R124_THI)) return NAN;
    double lo = R124_TLO, hi = R124_THI;
    for (int i = 0; i < 60; i++) { double mid = 0.5*(lo+hi);
        if (R124_pref_bar(mid) < P_bar) lo = mid; else hi = mid; }
    return 0.5 * (lo + hi);
}
double R124_hliq(double t_C) { return poly6(R124_HL, t_C); }
double R124_hgas(double t_C) { return poly6(R124_HV, t_C); }
double R124_hlat(double t_C) { return R124_hgas(t_C) - R124_hliq(t_C); }

#ifdef STANDALONE_MAIN
int main(void)
{
    double ts[] = {-40.0, 0.0, 25.0, 80.0};
    for (int i = 0; i < 4; i++) { double t = ts[i];
        printf("%.4f %.10g %.10g %.10g %.10g\n", t, R124_Pref(t), R124_hliq(t), R124_hgas(t), R124_Tsat(R124_Pref(t))); }
    return 0;
}
#endif

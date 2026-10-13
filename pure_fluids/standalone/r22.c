/* R22 纯物质饱和性质（单独计算文件，与合并模块 pure_fluids.c 系数逐字同源）
 * 源：CoolProp 参考状态方程拟合，与合并模块 pure_fluids 系数逐字相同；Wagner 饱和压最大偏差 0.0065%，焓偏差 0.42/0.59 kJ/kg；参考态 0°C 饱和液体 = 100 kJ/kg。
 * 函数：Pref(bar) / Tsat(°C，二分反解，超界返回 NAN) / hliq / hgas / hlat（kJ/kg）。
 * 参考态：0°C 饱和液体焓 = 100 kJ/kg（模块统一基准）。
 * 编译：gcc -O2 -Wall -DSTANDALONE_MAIN -o test_r22 r22.c -lm */
#include <stdio.h>
#include <math.h>

static const double R22_TC = 369.3, R22_PC = 49.9;
static const double R22_W[4] = {-7.048623, 1.4828095, -1.8223105, -2.8257753};
static const double R22_HL[7] = {4.6681599e-11, -2.2286115e-09, -1.2586426e-07, 1.4969301e-05, 0.0015173919, 1.167803, 99.972867};
static const double R22_HV[7] = {-6.541236e-11, 3.1584987e-09, 1.6628519e-07, -2.1606737e-05, -0.0019128189, 0.37574587, 305.0864};
static const double R22_TLO = -50.0, R22_THI = 90.0;

static double poly6(const double *c, double t)
{ return (((((c[0]*t + c[1])*t + c[2])*t + c[3])*t + c[4])*t + c[5])*t + c[6]; }
double R22_Pref(double t_C)
{
    double T = t_C + 273.15, tau = 1.0 - T / R22_TC;
    double s = R22_W[0]*tau + R22_W[1]*pow(tau,1.5) + R22_W[2]*pow(tau,2.5) + R22_W[3]*pow(tau,5.0);
    return R22_PC * exp((R22_TC / T) * s);
}
double R22_Tsat(double P_bar)
{
    if (P_bar < R22_Pref(R22_TLO) || P_bar > R22_Pref(R22_THI)) return NAN;
    double lo = R22_TLO, hi = R22_THI;
    for (int i = 0; i < 60; i++) { double mid = 0.5*(lo+hi);
        if (R22_Pref(mid) < P_bar) lo = mid; else hi = mid; }
    return 0.5 * (lo + hi);
}
double R22_hliq(double t_C) { return poly6(R22_HL, t_C); }
double R22_hgas(double t_C) { return poly6(R22_HV, t_C); }
double R22_hlat(double t_C) { return R22_hgas(t_C) - R22_hliq(t_C); }

#ifdef STANDALONE_MAIN
int main(void)
{
    double ts[] = {-40.0, 0.0, 25.0, 80.0};
    for (int i = 0; i < 4; i++) { double t = ts[i];
        printf("%.4f %.10g %.10g %.10g %.10g\n", t, R22_Pref(t), R22_hliq(t), R22_hgas(t), R22_Tsat(R22_Pref(t))); }
    return 0;
}
#endif

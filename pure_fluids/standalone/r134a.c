/* R134a 纯物质饱和性质（单独计算文件，与合并模块 pure_fluids.c 系数逐字同源）
 * 源：CoolProp 参考状态方程（Tillner-Roth & Baehr 1994）拟合，与合并模块 pure_fluids 系数逐字相同；Wagner 饱和压最大偏差 0.031%，焓偏差 0.41/0.61 kJ/kg；参考态 0°C 饱和液体 = 100 kJ/kg。
 * 函数：Pref(MPa) / Tsat(°C，入参 MPa，二分反解，超界返回 NAN) / hliq / hgas / hlat（kJ/kg）。Wagner 拟合内部以 bar 计，公开边界换算。
 * 参考态：0°C 饱和液体焓 = 100 kJ/kg（模块统一基准）。
 * 编译：gcc -O2 -Wall -DSTANDALONE_MAIN -o test_r134a r134a.c -lm */
#include <stdio.h>
#include <math.h>

static const double R134a_TC = 374.21, R134a_PC = 40.59;
static const double R134a_W[4] = {-7.6391282, 1.7650117, -2.6103553, -3.365738};
static const double R134a_HL[7] = {3.5283163e-11, -2.2259203e-09, -7.2651551e-08, 1.3659406e-05, 0.0014602205, 1.3386046, 99.982381};
static const double R134a_HV[7] = {-5.4059642e-11, 3.2801028e-09, 1.2592287e-07, -2.100514e-05, -0.0012602316, 0.5908568, 298.63031};
static const double R134a_TLO = -50.0, R134a_THI = 95.0;

static double poly6(const double *c, double t)
{ return (((((c[0]*t + c[1])*t + c[2])*t + c[3])*t + c[4])*t + c[5])*t + c[6]; }
static double R134a_pref_bar(double t_C)
{
    double T = t_C + 273.15, tau = 1.0 - T / R134a_TC;
    double s = R134a_W[0]*tau + R134a_W[1]*pow(tau,1.5) + R134a_W[2]*pow(tau,2.5) + R134a_W[3]*pow(tau,5.0);
    return R134a_PC * exp((R134a_TC / T) * s);
}
double R134a_Pref(double t_C) { return 0.1 * R134a_pref_bar(t_C); }
double R134a_Tsat(double P_MPa)
{
    double P_bar = 10.0 * P_MPa;
    if (P_bar < R134a_pref_bar(R134a_TLO) || P_bar > R134a_pref_bar(R134a_THI)) return NAN;
    double lo = R134a_TLO, hi = R134a_THI;
    for (int i = 0; i < 60; i++) { double mid = 0.5*(lo+hi);
        if (R134a_pref_bar(mid) < P_bar) lo = mid; else hi = mid; }
    return 0.5 * (lo + hi);
}
double R134a_hliq(double t_C) { return poly6(R134a_HL, t_C); }
double R134a_hgas(double t_C) { return poly6(R134a_HV, t_C); }
double R134a_hlat(double t_C) { return R134a_hgas(t_C) - R134a_hliq(t_C); }

#ifdef STANDALONE_MAIN
int main(void)
{
    double ts[] = {-40.0, 0.0, 25.0, 80.0};
    for (int i = 0; i < 4; i++) { double t = ts[i];
        printf("%.4f %.10g %.10g %.10g %.10g\n", t, R134a_Pref(t), R134a_hliq(t), R134a_hgas(t), R134a_Tsat(R134a_Pref(t))); }
    return 0;
}
#endif

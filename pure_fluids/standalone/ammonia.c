/* NH3 纯物质饱和性质（单独计算文件，与合并模块 pure_fluids.c 系数逐字同源）
 * 源：NIST WebBook 饱和表紧凑拟合（笔记见 ../fit-notes/纯氨饱和性质拟合-NIST表.md）；饱和压 lnP-t 7 次式，对表全程最大 0.0272%、常用带（-50~60°C）0.0027%；焓已由表基准平移 -244.768062686 至统一基准。
 * 函数：Pref(bar) / Tsat(°C，二分反解，超界返回 NAN) / hliq / hgas / hlat（kJ/kg）。
 * 参考态：0°C 饱和液体焓 = 100 kJ/kg（模块统一基准）。
 * 编译：gcc -O2 -Wall -DSTANDALONE_MAIN -o test_ammonia ammonia.c -lm */
#include <stdio.h>
#include <math.h>

static const double NH3_LNP[8] = {1.1501679663496297e-16, -3.681466540446358e-14, 9.070213653911228e-12, -2.4759314474490567e-09, 6.551063627525382e-07, -0.00015333383280607642, 0.03739502393748032, -0.8457026848887617};
static const double NH3_HL[7] = {1.0230389195910096e-10, -9.01173619674778e-09, -7.693180171285098e-07, 8.148925711345767e-05, 0.0049020842504556555, 4.529640315972919, 100.0};
static const double NH3_HV[7] = {-1.5323246964436346e-10, 1.341154075047321e-08, 1.181178610537754e-06, -0.000132743256804236, -0.01090080493286388, 1.2129121114680004, 1364.0392422964662};
static const double NH3_TLO = -77.0, NH3_THI = 132.0;

static double poly7(const double *c, double t)
{ return ((((((c[0]*t + c[1])*t + c[2])*t + c[3])*t + c[4])*t + c[5])*t + c[6])*t + c[7]; }
static double poly6(const double *c, double t)
{ return (((((c[0]*t + c[1])*t + c[2])*t + c[3])*t + c[4])*t + c[5])*t + c[6]; }
double NH3_Pref(double t_C) { return 10.0 * exp(poly7(NH3_LNP, t_C)); }
double NH3_Tsat(double P_bar)
{
    if (P_bar < NH3_Pref(NH3_TLO) || P_bar > NH3_Pref(NH3_THI)) return NAN;
    double lo = NH3_TLO, hi = NH3_THI;
    for (int i = 0; i < 60; i++) { double mid = 0.5*(lo+hi);
        if (NH3_Pref(mid) < P_bar) lo = mid; else hi = mid; }
    return 0.5 * (lo + hi);
}
double NH3_hliq(double t_C) { return poly6(NH3_HL, t_C); }
double NH3_hgas(double t_C) { return poly6(NH3_HV, t_C); }
double NH3_hlat(double t_C) { return NH3_hgas(t_C) - NH3_hliq(t_C); }

#ifdef STANDALONE_MAIN
int main(void)
{
    double ts[] = {-77.0, -8.030000000000001, 60.94, 132.0};
    for (int i = 0; i < 4; i++) { double t = ts[i];
        printf("%.4f %.10g %.10g %.10g %.10g\n", t, NH3_Pref(t), NH3_hliq(t), NH3_hgas(t), NH3_Tsat(NH3_Pref(t))); }
    return 0;
}
#endif

/* CO2 纯物质饱和性质（单独计算文件，与合并模块 pure_fluids.c 系数逐字同源）
 * 源：NIST WebBook 饱和表紧凑拟合（笔记见 ../fit-notes/二氧化碳饱和性质拟合-NIST表.md；源表有取整）；饱和压 lnP-t 7 次式，对表全程最大 0.0099%、常用带（-50~25°C）0.0059%；焓已由表基准平移 -100.255791821 至统一基准。
 * 函数：Pref(bar) / Tsat(°C，二分反解，超界返回 NAN) / hliq / hgas / hlat（kJ/kg）。
 * 参考态：0°C 饱和液体焓 = 100 kJ/kg（模块统一基准）。
 * 编译：gcc -O2 -Wall -DSTANDALONE_MAIN -o test_co2 co2.c -lm */
#include <stdio.h>
#include <math.h>

static const double CO2_LNP[8] = {7.349267422320306e-15, 9.714937274844203e-13, 5.722737962459257e-11, -5.000472245728414e-10, 5.236317080887681e-07, -9.20196795346934e-05, 0.02647312340946483, 1.2485141855617028};
static const double CO2_HL[7] = {2.948691221375449e-09, 3.3584601264848553e-07, 1.0969134467517922e-05, 9.865777775779578e-05, 0.006887751259917945, 2.4420397272329732, 100.0};
static const double CO2_HV[7] = {-4.280078787604416e-09, -4.893910288449988e-07, -1.62198769938507e-05, -0.00015811780903671123, -0.012470655351837747, -0.5840479229797425, 330.2675971498235};
static const double CO2_TLO = -56.0, CO2_THI = 30.0;

static double poly7(const double *c, double t)
{ return ((((((c[0]*t + c[1])*t + c[2])*t + c[3])*t + c[4])*t + c[5])*t + c[6])*t + c[7]; }
static double poly6(const double *c, double t)
{ return (((((c[0]*t + c[1])*t + c[2])*t + c[3])*t + c[4])*t + c[5])*t + c[6]; }
double CO2_Pref(double t_C) { return 10.0 * exp(poly7(CO2_LNP, t_C)); }
double CO2_Tsat(double P_bar)
{
    if (P_bar < CO2_Pref(CO2_TLO) || P_bar > CO2_Pref(CO2_THI)) return NAN;
    double lo = CO2_TLO, hi = CO2_THI;
    for (int i = 0; i < 60; i++) { double mid = 0.5*(lo+hi);
        if (CO2_Pref(mid) < P_bar) lo = mid; else hi = mid; }
    return 0.5 * (lo + hi);
}
double CO2_hliq(double t_C) { return poly6(CO2_HL, t_C); }
double CO2_hgas(double t_C) { return poly6(CO2_HV, t_C); }
double CO2_hlat(double t_C) { return CO2_hgas(t_C) - CO2_hliq(t_C); }

#ifdef STANDALONE_MAIN
int main(void)
{
    double ts[] = {-56.0, -27.619999999999997, 0.7600000000000051, 30.0};
    for (int i = 0; i < 4; i++) { double t = ts[i];
        printf("%.4f %.10g %.10g %.10g %.10g\n", t, CO2_Pref(t), CO2_hliq(t), CO2_hgas(t), CO2_Tsat(CO2_Pref(t))); }
    return 0;
}
#endif

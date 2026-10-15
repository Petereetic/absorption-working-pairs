/* H2O 纯物质饱和性质（单独计算文件，与合并模块 pure_fluids.c 系数逐字同源）
 * 源：NIST WebBook 饱和表紧凑拟合（笔记见 ../fit-notes/水饱和性质拟合-NIST表.md）；饱和压 lnP-t 7 次式，对表全程最大 0.0291%、常用带（5~300°C）0.0128%；焓已由表基准平移 +93.351889719 至统一基准。水的权威标准为 IAPWS 公式，本式为可移植紧凑式。
 * 函数：Pref(MPa) / Tsat(°C，二分反解，超界返回 NAN) / hliq / hgas / hlat（kJ/kg）。
 * 参考态：0°C 饱和液体焓 = 100 kJ/kg（模块统一基准）。
 * 编译：gcc -O2 -Wall -DSTANDALONE_MAIN -o test_water water.c -lm */
#include <stdio.h>
#include <math.h>

static const double H2O_LNP[8] = {5.54627791673895e-18, -8.99249875691861e-15, 6.660700555390007e-12, -3.088083641876246e-09, 1.056735995405781e-06, -0.0002954387998568004, 0.07259423527358563, -7.399704960820133};
static const double H2O_HL[7] = {4.9253814056437e-12, -4.8364685293173926e-09, 1.8115766448129802e-06, -0.0003141174119157094, 0.02553352332697852, 3.3541747407753046, 100.0};
static const double H2O_HV[7] = {-8.083632440447619e-12, 7.910908004577575e-09, -2.951073494811462e-06, 0.0005046392594921277, -0.04153882947643235, 3.1701433360694287, 2583.8464687067276};
static const double H2O_TLO = 1.0, H2O_THI = 373.0;

static double poly7(const double *c, double t)
{ return ((((((c[0]*t + c[1])*t + c[2])*t + c[3])*t + c[4])*t + c[5])*t + c[6])*t + c[7]; }
static double poly6(const double *c, double t)
{ return (((((c[0]*t + c[1])*t + c[2])*t + c[3])*t + c[4])*t + c[5])*t + c[6]; }
double H2O_Pref(double t_C) { return exp(poly7(H2O_LNP, t_C)); }
double H2O_Tsat(double P_MPa)
{
    if (P_MPa < H2O_Pref(H2O_TLO) || P_MPa > H2O_Pref(H2O_THI)) return NAN;
    double lo = H2O_TLO, hi = H2O_THI;
    for (int i = 0; i < 60; i++) { double mid = 0.5*(lo+hi);
        if (H2O_Pref(mid) < P_MPa) lo = mid; else hi = mid; }
    return 0.5 * (lo + hi);
}
double H2O_hliq(double t_C) { return poly6(H2O_HL, t_C); }
double H2O_hgas(double t_C) { return poly6(H2O_HV, t_C); }
double H2O_hlat(double t_C) { return H2O_hgas(t_C) - H2O_hliq(t_C); }

#ifdef STANDALONE_MAIN
int main(void)
{
    double ts[] = {1.0, 123.76, 246.52, 373.0};
    for (int i = 0; i < 4; i++) { double t = ts[i];
        printf("%.4f %.10g %.10g %.10g %.10g\n", t, H2O_Pref(t), H2O_hliq(t), H2O_hgas(t), H2O_Tsat(H2O_Pref(t))); }
    return 0;
}
#endif

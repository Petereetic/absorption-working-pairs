/* 九工质纯物质饱和性质（C 实现，与 pure_fluids.py 逐点一致）：
 * R134a / R22 / R124 / H2O / NH3 / CH3OH / R32 / R218 / CO2
 * 基准：CoolProp 内置参考状态方程（R134a: Tillner-Roth & Baehr 1994）
 * 参考态：0°C 饱和液体焓 = 100 kJ/kg
 *   Psat: Wagner 方程 ln(P/Pc)=(Tc/T)(a1 τ+a2 τ^1.5+a3 τ^2.5+a4 τ^5), τ=1-T/Tc
 *     R134a: Tc=374.21K Pc=40.59bar, -50~95°C, 偏差 0.031%
 *     R22:   Tc=369.30K Pc=49.90bar, -50~90°C, 偏差 0.0065%
 *   hL/hV: 6 次多项式（t 为 °C），偏差 <0.61 kJ/kg
 *   R124: NIST WebBook 饱和表拟合；Wagner 变体（指数 1, 1.5, 3, 6）,
 *     Tc=395.428K Pc=36.245bar, -40~110°C, Psat 偏差 0.111%,
 *     hL/hV 偏差 <1.63 kJ/kg；焓由表基准（0°C 液体 = 200）平移 -100
 * 2026-10-13 增补六工质：NIST WebBook 饱和表拟合（笔记见 fit-notes/）；
 *   饱和压 lnP-t 7 次多项式（ln(P/MPa)，x10 以 bar 返回），对表最大偏差
 *   全程/常用带：H2O 0.0291%/0.0128%（1~373°C）、NH3 0.0272%/0.0027%
 *   （-77~132°C）、CH3OH 0.1064%/0.0321%（-90~239°C）、R32 0.0609%/0.0147%
 *   （-136~78°C）、R218 0.1495%/0.0396%（-147~71°C）、CO2 0.0099%/0.0059%
 *   （-56~30°C）；焓 6 次多项式，已平移到统一基准，平移量（kJ/kg）：
 *   H2O +93.351889719、NH3 -244.768062686、CH3OH +266.341441575、
 *   R32 -100.673431938、R218 -100.177980782、CO2 -100.255791821。
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


/* ===== NIST WebBook 表拟合六工质（2026-10-13 增补） ===== */
/* 饱和压：lnP-t 7 次多项式（笔记取定式，ln(P/MPa)；此处 x10 以 bar 返回）；
 * 焓：6 次多项式，常数项已由各表自带基准平移到统一基准（0°C 液体 = 100），
 * 平移量见各工质注（潜热不变）。系数数组均为降幂序。 */

/* ---- H2O（平移 +93.351889719 kJ/kg） ---- */
static const double H2O_LNP[8] = {5.54627791673895e-18, -8.99249875691861e-15,
    6.660700555390007e-12, -3.088083641876246e-09, 1.056735995405781e-06, -0.0002954387998568004, 0.07259423527358563, -7.399704960820133};
static const double H2O_HL[7] = {4.9253814056437e-12, -4.8364685293173926e-09, 1.8115766448129802e-06,
    -0.0003141174119157094, 0.02553352332697852, 3.3541747407753046, 100.0};
static const double H2O_HV[7] = {-8.083632440447619e-12, 7.910908004577575e-09, -2.951073494811462e-06,
    0.0005046392594921277, -0.04153882947643235, 3.1701433360694287, 2583.8464687067276};
static const double H2O_TLO = 1.0, H2O_THI = 373.0;

/* ---- NH3（平移 -244.76806269 kJ/kg） ---- */
static const double NH3_LNP[8] = {1.1501679663496297e-16, -3.681466540446358e-14,
    9.070213653911228e-12, -2.4759314474490567e-09, 6.551063627525382e-07, -0.00015333383280607642, 0.03739502393748032, -0.8457026848887617};
static const double NH3_HL[7] = {1.0230389195910096e-10, -9.01173619674778e-09, -7.693180171285098e-07,
    8.148925711345767e-05, 0.0049020842504556555, 4.529640315972919, 100.0};
static const double NH3_HV[7] = {-1.5323246964436346e-10, 1.341154075047321e-08, 1.181178610537754e-06,
    -0.000132743256804236, -0.01090080493286388, 1.2129121114680004, 1364.0392422964662};
static const double NH3_TLO = -77.0, NH3_THI = 132.0;

/* ---- CH3OH（平移 +266.34144157 kJ/kg） ---- */
static const double CH3OH_LNP[8] = {6.071697789417314e-17, -4.474383382147671e-14,
    1.4922332158687438e-11, -3.713389940921318e-09, 9.643627950530163e-07, -0.00025454685882528256, 0.06310145783702696, -5.507805919357708};
static const double CH3OH_HL[7] = {5.573934158642428e-12, -1.8104866695124476e-09, 8.709794689054448e-08,
    2.7396583808978296e-05, 0.001358520746256356, 2.362545782283046, 100.0};
static const double CH3OH_HV[7] = {-1.228628960059207e-11, 4.469399531774273e-09, -3.1756317512396483e-07,
    -4.548213600653677e-05, 0.002018557942790822, 1.156097552141014, 1301.565002270651};
static const double CH3OH_TLO = -90.0, CH3OH_THI = 239.0;

/* ---- R32（平移 -100.67343194 kJ/kg） ---- */
static const double R32_LNP[8] = {4.985734545925537e-16, 8.088993550316065e-15,
    7.23916818285453e-12, -2.4123562470111985e-09, 5.690865248769261e-07, -0.00012346886007261548, 0.032029536226752524, -0.20703267077542895};
static const double R32_HL[7] = {3.052117712232615e-11, 7.669342242883148e-09, 4.426168044128746e-07,
    -6.097377922612308e-06, 0.0010654645657896644, 1.7643249519580528, 100.0};
static const double R32_HV[7] = {-4.488337246373621e-11, -1.1379788910261148e-08, -6.764615880681746e-07,
    7.561508556936408e-06, -0.0024175577393345023, 0.1589860001017608, 413.6297944744754};
static const double R32_TLO = -136.0, R32_THI = 78.0;

/* ---- R218（平移 -100.17798078 kJ/kg） ---- */
static const double R218_LNP[8] = {8.255415504414131e-16, 7.344897883851216e-14,
    1.093452574911193e-11, -2.800385114611927e-09, 6.13844960232108e-07, -0.00013063706572324828, 0.03248293004447796, -0.8809937809605295};
static const double R218_HL[7] = {7.040720312389206e-12, 2.1911253182755153e-09, 1.9931060577128075e-07,
    4.329266994236428e-06, 0.0010980864706317968, 1.070171579409284, 100.0};
static const double R218_HV[7] = {-1.0731550245287959e-11, -3.374732945181214e-09, -3.125522092678402e-07,
    -8.835005867404636e-06, -2.3183839296438865e-05, 0.596775089781136, 189.38572453841817};
static const double R218_TLO = -147.0, R218_THI = 71.0;

/* ---- CO2（平移 -100.25579182 kJ/kg） ---- */
static const double CO2_LNP[8] = {7.349267422320306e-15, 9.714937274844203e-13,
    5.722737962459257e-11, -5.000472245728414e-10, 5.236317080887681e-07, -9.20196795346934e-05, 0.02647312340946483, 1.2485141855617028};
static const double CO2_HL[7] = {2.948691221375449e-09, 3.3584601264848553e-07, 1.0969134467517922e-05,
    9.865777775779578e-05, 0.006887751259917945, 2.4420397272329732, 100.0};
static const double CO2_HV[7] = {-4.280078787604416e-09, -4.893910288449988e-07, -1.62198769938507e-05,
    -0.00015811780903671123, -0.012470655351837747, -0.5840479229797425, 330.2675971498235};
static const double CO2_TLO = -56.0, CO2_THI = 30.0;

static double poly7(const double *c, double t)
{
    return ((((((c[0]*t + c[1])*t + c[2])*t + c[3])*t + c[4])*t + c[5])*t + c[6])*t + c[7];
}

static double lnp_pref(double t_C, const double *c) { return 10.0 * exp(poly7(c, t_C)); }

double H2O_Pref(double t_C) { return lnp_pref(t_C, H2O_LNP); }
double H2O_Tsat(double P_bar) { return tsat_bisect(H2O_Pref, P_bar, H2O_TLO, H2O_THI); }
double H2O_hliq(double t_C) { return poly6(H2O_HL, t_C); }
double H2O_hgas(double t_C) { return poly6(H2O_HV, t_C); }
double H2O_hlat(double t_C) { return H2O_hgas(t_C) - H2O_hliq(t_C); }

double NH3_Pref(double t_C) { return lnp_pref(t_C, NH3_LNP); }
double NH3_Tsat(double P_bar) { return tsat_bisect(NH3_Pref, P_bar, NH3_TLO, NH3_THI); }
double NH3_hliq(double t_C) { return poly6(NH3_HL, t_C); }
double NH3_hgas(double t_C) { return poly6(NH3_HV, t_C); }
double NH3_hlat(double t_C) { return NH3_hgas(t_C) - NH3_hliq(t_C); }

double CH3OH_Pref(double t_C) { return lnp_pref(t_C, CH3OH_LNP); }
double CH3OH_Tsat(double P_bar) { return tsat_bisect(CH3OH_Pref, P_bar, CH3OH_TLO, CH3OH_THI); }
double CH3OH_hliq(double t_C) { return poly6(CH3OH_HL, t_C); }
double CH3OH_hgas(double t_C) { return poly6(CH3OH_HV, t_C); }
double CH3OH_hlat(double t_C) { return CH3OH_hgas(t_C) - CH3OH_hliq(t_C); }

double R32_Pref(double t_C) { return lnp_pref(t_C, R32_LNP); }
double R32_Tsat(double P_bar) { return tsat_bisect(R32_Pref, P_bar, R32_TLO, R32_THI); }
double R32_hliq(double t_C) { return poly6(R32_HL, t_C); }
double R32_hgas(double t_C) { return poly6(R32_HV, t_C); }
double R32_hlat(double t_C) { return R32_hgas(t_C) - R32_hliq(t_C); }

double R218_Pref(double t_C) { return lnp_pref(t_C, R218_LNP); }
double R218_Tsat(double P_bar) { return tsat_bisect(R218_Pref, P_bar, R218_TLO, R218_THI); }
double R218_hliq(double t_C) { return poly6(R218_HL, t_C); }
double R218_hgas(double t_C) { return poly6(R218_HV, t_C); }
double R218_hlat(double t_C) { return R218_hgas(t_C) - R218_hliq(t_C); }

double CO2_Pref(double t_C) { return lnp_pref(t_C, CO2_LNP); }
double CO2_Tsat(double P_bar) { return tsat_bisect(CO2_Pref, P_bar, CO2_TLO, CO2_THI); }
double CO2_hliq(double t_C) { return poly6(CO2_HL, t_C); }
double CO2_hgas(double t_C) { return poly6(CO2_HV, t_C); }
double CO2_hlat(double t_C) { return CO2_hgas(t_C) - CO2_hliq(t_C); }

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

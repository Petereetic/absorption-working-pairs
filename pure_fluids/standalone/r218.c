/* R218 pure-substance saturation properties (standalone calculation file; coefficients verbatim identical to the merged module pure_fluids.c)
 * Source: compact fit to the NIST WebBook saturation table (see fit notes in ../fit-notes/, "R218 saturation-property fit - NIST table"); saturation pressure as a degree-7 lnP-t polynomial, max deviation vs. table 0.1495% over the full range and 0.0396% in the usual band (-100~50°C); enthalpy shifted from the table datum by -100.177980782 to the uniform reference.
 * Functions: Pref (MPa) / Tsat (°C, inverse by bisection, returns NAN when out of range) / hliq / hgas / hlat (kJ/kg).
 * Reference state: saturated-liquid enthalpy at 0°C = 100 kJ/kg (uniform module reference).
 * Build: gcc -O2 -Wall -DSTANDALONE_MAIN -o test_r218 r218.c -lm */
#include <stdio.h>
#include <math.h>

static const double R218_LNP[8] = {8.255415504414131e-16, 7.344897883851216e-14, 1.093452574911193e-11, -2.800385114611927e-09, 6.13844960232108e-07, -0.00013063706572324828, 0.03248293004447796, -0.8809937809605295};
static const double R218_HL[7] = {7.040720312389206e-12, 2.1911253182755153e-09, 1.9931060577128075e-07, 4.329266994236428e-06, 0.0010980864706317968, 1.070171579409284, 100.0};
static const double R218_HV[7] = {-1.0731550245287959e-11, -3.374732945181214e-09, -3.125522092678402e-07, -8.835005867404636e-06, -2.3183839296438865e-05, 0.596775089781136, 189.38572453841817};
static const double R218_TLO = -147.0, R218_THI = 71.0;

static double poly7(const double *c, double t)
{ return ((((((c[0]*t + c[1])*t + c[2])*t + c[3])*t + c[4])*t + c[5])*t + c[6])*t + c[7]; }
static double poly6(const double *c, double t)
{ return (((((c[0]*t + c[1])*t + c[2])*t + c[3])*t + c[4])*t + c[5])*t + c[6]; }
double R218_Pref(double t_C) { return exp(poly7(R218_LNP, t_C)); }
double R218_Tsat(double P_MPa)
{
    if (P_MPa < R218_Pref(R218_TLO) || P_MPa > R218_Pref(R218_THI)) return NAN;
    double lo = R218_TLO, hi = R218_THI;
    for (int i = 0; i < 60; i++) { double mid = 0.5*(lo+hi);
        if (R218_Pref(mid) < P_MPa) lo = mid; else hi = mid; }
    return 0.5 * (lo + hi);
}
double R218_hliq(double t_C) { return poly6(R218_HL, t_C); }
double R218_hgas(double t_C) { return poly6(R218_HV, t_C); }
double R218_hlat(double t_C) { return R218_hgas(t_C) - R218_hliq(t_C); }

#ifdef STANDALONE_MAIN
int main(void)
{
    double ts[] = {-147.0, -75.06, -3.1200000000000045, 71.0};
    for (int i = 0; i < 4; i++) { double t = ts[i];
        printf("%.4f %.10g %.10g %.10g %.10g\n", t, R218_Pref(t), R218_hliq(t), R218_hgas(t), R218_Tsat(R218_Pref(t))); }
    return 0;
}
#endif

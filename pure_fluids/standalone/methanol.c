/* CH3OH pure-substance saturation properties (standalone calculation file; coefficients verbatim identical to the merged module pure_fluids.c)
 * Source: compact fit to the NIST WebBook saturation table (see fit notes in ../fit-notes/, "methanol saturation-property fit - NIST table"; the source table is rounded web output, so the residuals include rounding noise); saturation pressure as a degree-7 lnP-t polynomial, max deviation vs. table 0.1064% over the full range and 0.0321% in the usual band (-40~90°C); enthalpy shifted from the table datum by +266.341441575 to the uniform reference.
 * Functions: Pref (MPa) / Tsat (°C, inverse by bisection, returns NAN when out of range) / hliq / hgas / hlat (kJ/kg).
 * Reference state: saturated-liquid enthalpy at 0°C = 100 kJ/kg (uniform module reference).
 * Build: gcc -O2 -Wall -DSTANDALONE_MAIN -o test_methanol methanol.c -lm */
#include <stdio.h>
#include <math.h>

static const double CH3OH_LNP[8] = {6.071697789417314e-17, -4.474383382147671e-14, 1.4922332158687438e-11, -3.713389940921318e-09, 9.643627950530163e-07, -0.00025454685882528256, 0.06310145783702696, -5.507805919357708};
static const double CH3OH_HL[7] = {5.573934158642428e-12, -1.8104866695124476e-09, 8.709794689054448e-08, 2.7396583808978296e-05, 0.001358520746256356, 2.362545782283046, 100.0};
static const double CH3OH_HV[7] = {-1.228628960059207e-11, 4.469399531774273e-09, -3.1756317512396483e-07, -4.548213600653677e-05, 0.002018557942790822, 1.156097552141014, 1301.565002270651};
static const double CH3OH_TLO = -90.0, CH3OH_THI = 239.0;

static double poly7(const double *c, double t)
{ return ((((((c[0]*t + c[1])*t + c[2])*t + c[3])*t + c[4])*t + c[5])*t + c[6])*t + c[7]; }
static double poly6(const double *c, double t)
{ return (((((c[0]*t + c[1])*t + c[2])*t + c[3])*t + c[4])*t + c[5])*t + c[6]; }
double CH3OH_Pref(double t_C) { return exp(poly7(CH3OH_LNP, t_C)); }
double CH3OH_Tsat(double P_MPa)
{
    if (P_MPa < CH3OH_Pref(CH3OH_TLO) || P_MPa > CH3OH_Pref(CH3OH_THI)) return NAN;
    double lo = CH3OH_TLO, hi = CH3OH_THI;
    for (int i = 0; i < 60; i++) { double mid = 0.5*(lo+hi);
        if (CH3OH_Pref(mid) < P_MPa) lo = mid; else hi = mid; }
    return 0.5 * (lo + hi);
}
double CH3OH_hliq(double t_C) { return poly6(CH3OH_HL, t_C); }
double CH3OH_hgas(double t_C) { return poly6(CH3OH_HV, t_C); }
double CH3OH_hlat(double t_C) { return CH3OH_hgas(t_C) - CH3OH_hliq(t_C); }

#ifdef STANDALONE_MAIN
int main(void)
{
    double ts[] = {-90.0, 18.570000000000007, 127.14000000000001, 239.0};
    for (int i = 0; i < 4; i++) { double t = ts[i];
        printf("%.4f %.10g %.10g %.10g %.10g\n", t, CH3OH_Pref(t), CH3OH_hliq(t), CH3OH_hgas(t), CH3OH_Tsat(CH3OH_Pref(t))); }
    return 0;
}
#endif

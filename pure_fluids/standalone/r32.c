/* R32 pure-substance saturation properties (standalone calculation file; coefficients verbatim identical to the merged module pure_fluids.c)
 * Source: compact fit to the NIST WebBook saturation table (see fit notes in ../fit-notes/, "R32 saturation-property fit - NIST table"); saturation pressure as a degree-7 lnP-t polynomial, max deviation vs. table 0.0609% over the full range and 0.0147% in the usual band (-40~60°C); enthalpy shifted from the table datum by -100.673431938 to the uniform reference.
 * Functions: Pref (MPa) / Tsat (°C, inverse by bisection, returns NAN when out of range) / hliq / hgas / hlat (kJ/kg).
 * Reference state: saturated-liquid enthalpy at 0°C = 100 kJ/kg (uniform module reference).
 * Build: gcc -O2 -Wall -DSTANDALONE_MAIN -o test_r32 r32.c -lm */
#include <stdio.h>
#include <math.h>

static const double R32_LNP[8] = {4.985734545925537e-16, 8.088993550316065e-15, 7.23916818285453e-12, -2.4123562470111985e-09, 5.690865248769261e-07, -0.00012346886007261548, 0.032029536226752524, -0.20703267077542895};
static const double R32_HL[7] = {3.052117712232615e-11, 7.669342242883148e-09, 4.426168044128746e-07, -6.097377922612308e-06, 0.0010654645657896644, 1.7643249519580528, 100.0};
static const double R32_HV[7] = {-4.488337246373621e-11, -1.1379788910261148e-08, -6.764615880681746e-07, 7.561508556936408e-06, -0.0024175577393345023, 0.1589860001017608, 413.6297944744754};
static const double R32_TLO = -136.0, R32_THI = 78.0;

static double poly7(const double *c, double t)
{ return ((((((c[0]*t + c[1])*t + c[2])*t + c[3])*t + c[4])*t + c[5])*t + c[6])*t + c[7]; }
static double poly6(const double *c, double t)
{ return (((((c[0]*t + c[1])*t + c[2])*t + c[3])*t + c[4])*t + c[5])*t + c[6]; }
double R32_Pref(double t_C) { return exp(poly7(R32_LNP, t_C)); }
double R32_Tsat(double P_MPa)
{
    if (P_MPa < R32_Pref(R32_TLO) || P_MPa > R32_Pref(R32_THI)) return NAN;
    double lo = R32_TLO, hi = R32_THI;
    for (int i = 0; i < 60; i++) { double mid = 0.5*(lo+hi);
        if (R32_Pref(mid) < P_MPa) lo = mid; else hi = mid; }
    return 0.5 * (lo + hi);
}
double R32_hliq(double t_C) { return poly6(R32_HL, t_C); }
double R32_hgas(double t_C) { return poly6(R32_HV, t_C); }
double R32_hlat(double t_C) { return R32_hgas(t_C) - R32_hliq(t_C); }

#ifdef STANDALONE_MAIN
int main(void)
{
    double ts[] = {-136.0, -65.38, 5.240000000000009, 78.0};
    for (int i = 0; i < 4; i++) { double t = ts[i];
        printf("%.4f %.10g %.10g %.10g %.10g\n", t, R32_Pref(t), R32_hliq(t), R32_hgas(t), R32_Tsat(R32_Pref(t))); }
    return 0;
}
#endif

/* r22_dmf.c - R22-DMF bubble-point pressure & solution enthalpy
 *
 * Bubble pressure: per-isopleth Antoine fits ln(P/bar)=A+B/T+C*ln(T) (T in K)
 *   to Agarwal (1982) VLE data (via Ardita thesis Lampiran-7, 132 pts, xi>=0.10),
 *   PCHIP interpolation in R22 mass fraction xi.
 *   Valid: T -25..120 C, xi 0.10..1.00. AARD 2.38%, max 9.6% vs data.
 *   (xi>0.80 & T>65C extrapolates beyond measured data: R22 near/supercritical.)
 *
 * Solution enthalpy: Fatouh et al. 1993 correlations (via Ardita thesis Ch.2,
 *   eq 2.38-2.43). T in K, h in kJ/kg, ref 100 kJ/kg liquid at 273.15 K.
 *   Valid approx: T -20..95 C, xi 0..1 (R22 F-coeffs fit 253..368 K).
 *
 * Build: gcc -O2 -Wall -o r22_dmf r22_dmf.c -lm
 */
#include <stdio.h>
#include <math.h>

#define NISO 10
static const double ISO_XI[NISO] = {
    0.10000, 0.23076, 0.32000, 0.40348, 0.50000,
    0.60220, 0.70000, 0.80000, 0.90000, 1.00000 };
static const double ISO_A[NISO] = {
     30.772744,  10.400862,  10.271208,  -5.848160,  39.598401,
     27.566449,  28.096798,  51.969188,  99.166678,  18.474130 };
static const double ISO_B[NISO] = {
    -3182.9395, -2459.9752, -2405.5462, -1618.6504, -3709.7856,
    -3089.5702, -3022.7056, -4223.6822, -6197.2000, -2766.7568 };
static const double ISO_C[NISO] = {
     -3.629138,  -0.388685,  -0.311415,   2.088399,  -4.591025,
     -2.819850,  -2.907606,  -6.297351, -13.369886,  -1.197267 };

/* Monotone cubic (PCHIP, Fritsch-Carlson) interpolation. x must be increasing. */
static double pchip(const double *x, const double *y, int n, double xq)
{
    double h[NISO-1], d[NISO-1], dk[NISO];
    int k, i;
    for (i = 0; i < n-1; i++) { h[i] = x[i+1]-x[i]; d[i] = (y[i+1]-y[i])/h[i]; }
    dk[0] = d[0]; dk[n-1] = d[n-2];
    for (k = 1; k < n-1; k++) {
        if (d[k-1]*d[k] <= 0.0) { dk[k] = 0.0; }
        else {
            double w1 = 2.0*h[k]+h[k-1], w2 = h[k]+2.0*h[k-1];
            dk[k] = (w1+w2)/(w1/d[k-1]+w2/d[k]);
        }
    }
    k = 0;
    while (k < n-2 && xq > x[k+1]) k++;
    {
        double t = (xq - x[k])/h[k], t2 = t*t, t3 = t2*t;
        return (2*t3-3*t2+1)*y[k] + (t3-2*t2+t)*h[k]*dk[k]
             + (-2*t3+3*t2)*y[k+1] + (t3-t2)*h[k]*dk[k+1];
    }
}

/* Bubble-point pressure, bar. T_C in degC, xi = R22 mass fraction. */
double R22DMF_BubbleP(double T_C, double xi)
{
    double T = T_C + 273.15, Pj[NISO], lnT = log(T);
    int j;
    if (xi < ISO_XI[0]) xi = ISO_XI[0];
    if (xi > ISO_XI[NISO-1]) xi = ISO_XI[NISO-1];
    for (j = 0; j < NISO; j++)
        Pj[j] = exp(ISO_A[j] + ISO_B[j]/T + ISO_C[j]*lnT);
    return pchip(ISO_XI, Pj, NISO, xi);
}

/* Bubble-point temperature, degC, by bisection. Returns NAN if P out of range. */
double R22DMF_BubbleT(double P_bar, double xi)
{
    double lo = -25.0, hi = 120.0, mid;
    int i;
    if (P_bar < R22DMF_BubbleP(lo, xi) || P_bar > R22DMF_BubbleP(hi, xi))
        return NAN;
    for (i = 0; i < 60; i++) {
        mid = 0.5*(lo+hi);
        if (R22DMF_BubbleP(mid, xi) < P_bar) lo = mid; else hi = mid;
    }
    return 0.5*(lo+hi);
}

/* ---- Fatouh solution enthalpy (kJ/kg), T_C in degC ---- */
static double fpoly(double F0, double F1, double F2, double T) /* T in K */
{ return F0 + F1*T + F2*T*T; }

double R22DMF_H_R22L(double T_C)   /* R22 saturated liquid */
{
    double T = T_C + 273.15;
    if (T < 323.15) return fpoly(-68.14840, 0.0631300, 0.0020200, T);
    return fpoly(1966.645, -12.09784, 0.02018352, T);
}
double R22DMF_H_R22V(double T_C)   /* R22 saturated vapour */
{
    double T = T_C + 273.15;
    if (T < 323.15) return fpoly(37.22971, 1.599520, -0.002260308, T);
    return fpoly(-2720.182, 18.11784, -0.02699451, T);
}
double R22DMF_H_DMF(double T_C)    /* DMF liquid */
{ return fpoly(-352.2493, 1.317081, 0.001239553, T_C + 273.15); }

/* Raw Fatouh correlation (valid xi<=0.9; hmix does not vanish at xi=1) */
static double h_fatouh(double T_C, double xi)
{
    static const double B[4] = {-1817.206, -4302.679, 9877.574, 0.0};
    static const double C[4] = {-135585.8, 625797.9, -1435546.0, 0.0};
    static const double E1 = -7738.2052, E2 = 0.05627680, E3 = -34.79;
    static const double MR22 = 86.47, MDMF = 73.09, RR = 8.314;
    double T = T_C + 273.15, T2 = T*T, T3 = T2*T, omx = 1.0 - xi;
    double Y0 = xi/omx;
    double Y1 = xi/omx + log(omx);
    double Y2 = 1.0/omx - omx + 2.0*log(omx);
    double Y3 = xi/omx + xi*xi/2.0 + 2.0*xi + 3.0*log(omx);
    double K0 = B[0]/T2 + 2*C[0]/T3 - E1/T2 + E2 + E3/T;
    double K1 = B[1]/T2 + 2*C[1]/T3;
    double K2 = B[2]/T2 + 2*C[2]/T3;
    double K3 = B[3]/T2 + 2*C[3]/T3;
    double Mmix = xi*MR22 + omx*MDMF;
    double hmix = (omx*RR*T2/Mmix)*(K0*Y0 + K1*Y1 + K2*Y2 + K3*Y3);
    return xi*R22DMF_H_R22L(T_C) + omx*R22DMF_H_DMF(T_C) + hmix;
}

/* R22-DMF solution enthalpy (kJ/kg). Linear blend to pure R22 for 0.9<xi<1. */
double R22DMF_Hsol(double T_C, double xi)
{
    double h09;
    if (xi <= 0.0) return R22DMF_H_DMF(T_C);
    if (xi >= 1.0) return R22DMF_H_R22L(T_C);
    if (xi <= 0.9) return h_fatouh(T_C, xi);
    h09 = h_fatouh(T_C, 0.9);
    return h09 + (xi-0.9)/0.1*(R22DMF_H_R22L(T_C)-h09);
}

int main(void)
{
    printf("R22-DMF property check\n");
    printf("BubbleP(40C, 0.50)  = %.3f bar  (data 3.796 @40C)\n", R22DMF_BubbleP(40, .5));
    printf("BubbleP(0C, 0.50)   = %.3f bar  (data 1.317 @0C)\n", R22DMF_BubbleP(0, .5));
    printf("BubbleP(0C, 1.00)   = %.3f bar  (data 5.098, pure R22)\n", R22DMF_BubbleP(0, 1.0));
    printf("BubbleT(3.796bar,.5)= %.2f C\n", R22DMF_BubbleT(3.796, .5));
    printf("H_R22L(0C)  = %.2f kJ/kg (ref 100)\n", R22DMF_H_R22L(0));
    printf("H_DMF(0C)   = %.2f kJ/kg (ref 100)\n", R22DMF_H_DMF(0));
    printf("Hsol(30C,.5)= %.2f kJ/kg\n", R22DMF_Hsol(30, .5));
    printf("Hsol(80C,.4)= %.2f kJ/kg\n", R22DMF_Hsol(80, .4));
    return 0;
}

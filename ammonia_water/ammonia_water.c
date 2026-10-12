/*
 * Ammonia-water mixture: Patek & Klomfar (1995) fast explicit correlations.
 *
 * Reference:
 *   J. Patek, J. Klomfar, "Simple functions for fast calculations of selected
 *   thermodynamic properties of the ammonia-water system",
 *   Int. J. Refrigeration 18(4), 228-234, 1995.
 *
 * Conventions:
 *   x : ammonia MOLE fraction in the liquid phase
 *   y : ammonia MOLE fraction in the gas phase
 *   p : pressure in MPa ; T : temperature in K ; h : kJ/kg
 *
 *   T_bubble_PX  Eq (6): T(p,x),  T0=100 K, p0=2 MPa, 0.002<=p<=2 MPa
 *   T_dew_PY     Eq (7): T(p,y),  T0=100 K, p0=2 MPa, 0.02<=p<=2 MPa
 *   y_equil      Eq (8): y(p,x),  p0=2 MPa,  valid for x>0.05 (mole)
 *   hsol        Eq (9): h_l(T,x), h0=100 kJ/kg, T0=273.16 K
 *   hgas        Eq (10): h_g(T,y), h0=1000 kJ/kg, T0=324 K
 *
 * Reference state: h = 0 for liquid water at the triple point
 * (for both components).
 *
 * NOTE: this C file is cross-checked point-by-point against the Python
 * reference (ammonia_water.py), which itself was verified against the
 * paper's pure-component limits and stated consistency
 * (see verify_transcription.py).
 */
#include <math.h>
#include <stddef.h>

typedef struct { int m; int n; double a; } Term;

/* Eq (6) */
static const Term C6[] = {
    {0,0,  3.22302}, {0,1, -0.384206}, {0,2,  0.0460965},
    {0,3, -0.00378945}, {0,4,  0.000135610},
    {1,0,  0.487755}, {1,1, -0.120108}, {1,2,  0.0106154},
    {2,3, -0.000533589},
    {4,0,  7.85041}, {5,0, -11.5941}, {5,1, -0.0523150},
    {6,0,  4.89596}, {13,1,  0.0421059}
};
#define N6 (sizeof(C6)/sizeof(C6[0]))

/* Eq (7) */
static const Term C7[] = {
    {0,0,  3.24004}, {0,1, -0.395920}, {0,2,  0.0435624},
    {0,3, -0.00218943},
    {1,0, -1.43526}, {1,1,  1.05256}, {1,2, -0.0719281},
    {2,0,  12.2362}, {2,1, -2.24368},
    {3,0, -20.1780}, {3,1,  1.10834},
    {4,0,  14.5399}, {4,2,  0.644312},
    {5,0, -2.21246}, {5,2, -0.756266},
    {6,0, -1.35529},
    {7,2,  0.183541}
};
#define N7 (sizeof(C7)/sizeof(C7[0]))

/* Eq (8) */
static const Term C8[] = {
    {0,0,  19.8022017}, {0,1, -11.8092669},
    {0,6,  27.7479980}, {0,7, -28.8634277},
    {1,0, -59.1616608},
    {2,1,  578.091305}, {2,2, -6.21736743},
    {3,2, -3421.98402},
    {4,3,  11940.3127},
    {5,4, -24541.3777},
    {6,5,  29159.1865},
    {7,6, -18478.2290},
    {7,7,  23.4819434},
    {8,7,  4803.10617}
};
#define N8 (sizeof(C8)/sizeof(C8[0]))

/* Eq (9) */
static const Term C9[] = {
    {0, 1, -7.61080}, {0, 4,  25.6905}, {0, 8, -247.092},
    {0, 9,  325.952}, {0,12, -158.854}, {0,14,  61.9084},
    {1, 0,  11.4314}, {1, 1,   1.18157},
    {2, 1,   2.84179},
    {3, 3,   7.41609},
    {5, 3,  891.844}, {5, 4, -1613.09}, {5, 5,  622.106},
    {6, 2, -207.588}, {6, 4,   -6.87393},
    {8, 0,    3.50716}
};
#define N9 (sizeof(C9)/sizeof(C9[0]))

/* Eq (10) */
static const Term C10[] = {
    {0, 0,  1.28827}, {1, 0,  0.125247},
    {2, 0, -2.08748}, {3, 0,  2.17696},
    {0, 2,  2.35687}, {1, 2, -8.86987},
    {2, 2, 10.2635 }, {3, 2, -2.37440},
    {0, 3, -6.70515}, {1, 3, 16.4508 }, {2, 3, -9.36849},
    {0, 4,  8.42254}, {1, 4, -8.58807},
    {0, 5, -2.77049},
    {4, 6, -0.961248},
    {2, 7,  0.988009},
    {1,10,  0.308482}
};
#define N10 (sizeof(C10)/sizeof(C10[0]))

#define T0_67 100.0
#define P0      2.0
#define H0_9  100.0
#define T0_9  273.16
#define H0_10 1000.0
#define T0_10 324.0

/* Eq (6): bubble-point temperature [K], p in MPa */
double T_bubble_PX(double p_MPa, double x)
{
    double L = log(P0 / p_MPa);
    double omx = 1.0 - x;
    double s = 0.0;
    size_t i;
    for (i = 0; i < N6; i++)
        s += C6[i].a * pow(omx, C6[i].m) * pow(L, C6[i].n);
    return T0_67 * s;
}

/* Eq (7): dew-point temperature [K], p in MPa */
double T_dew_PY(double p_MPa, double y)
{
    double L = log(P0 / p_MPa);
    double omy = 1.0 - y;
    double s = 0.0;
    size_t i;
    if (omy < 0.0) omy = 0.0;
    for (i = 0; i < N7; i++)
        s += C7[i].a * pow(omy, C7[i].m / 4.0) * pow(L, C7[i].n);
    return T0_67 * s;
}

/* Eq (8): equilibrium vapour mole fraction, p in MPa */
double y_equil(double p_MPa, double x)
{
    double pr = p_MPa / P0;
    double s = 0.0;
    size_t i;
    if (x >= 1.0) return 1.0;
    if (x <= 0.0) return 0.0;
    for (i = 0; i < N8; i++)
        s += C8[i].a * pow(pr, C8[i].m) * pow(x, C8[i].n / 3.0);
    return 1.0 - exp(log(1.0 - x) * s);
}

/* Eq (9): saturated-liquid enthalpy [kJ/kg] */
double hsol(double T_K, double x)
{
    double u = T_K / T0_9 - 1.0;
    double s = 0.0;
    size_t i;
    for (i = 0; i < N9; i++)
        s += C9[i].a * pow(u, C9[i].m) * pow(x, C9[i].n);
    return H0_9 * s;
}

/* Eq (10): vapour enthalpy [kJ/kg] */
double hgas(double T_K, double y)
{
    double v = 1.0 - T0_10 / T_K;
    double omy = 1.0 - y;
    double s = 0.0;
    size_t i;
    if (omy < 0.0) omy = 0.0;
    for (i = 0; i < N10; i++)
        s += C10[i].a * pow(v, C10[i].m) * pow(omy, C10[i].n / 4.0);
    return H0_10 * s;
}

/* True temperature glide [K] at (p, overall mole fraction z):
   T_dew(p,z) - T_bubble(p,z). */
double glide_pX(double p_MPa, double z)
{
    return T_dew_PY(p_MPa, z) - T_bubble_PX(p_MPa, z);
}

/* Bubble pressure [MPa] at (T, x): bisection inverse of Eq (6).
   T_bubble(p, x) decreases monotonically in p. */
double psol_TX(double T_K, double x)
{
    double p_lo = 0.002, p_hi = 2.0, flo, fm, pm;
    int k;
    flo = T_bubble_PX(p_lo, x) - T_K;
    for (k = 0; k < 200; k++) {
        pm = 0.5 * (p_lo + p_hi);
        fm = T_bubble_PX(pm, x) - T_K;
        if (fm == 0.0 || (p_hi - p_lo) < 1e-9 * (pm > 1.0 ? pm : 1.0))
            return pm;
        if ((fm > 0.0) == (flo > 0.0)) { p_lo = pm; flo = fm; }
        else p_hi = pm;
    }
    return 0.5 * (p_lo + p_hi);
}

/* NH3 mole fraction x from a dew-point temperature [K] and a solution
   temperature [K]: bisection inverse of psol_TX.
   Construction (pure-NH3 endpoint): P = psol_TX(Tdew_K, x=1), the
   x=1 endpoint of Eq (6); then solve psol_TX(Tsol_K, x) = P by
   80 bisection steps over x in [0, 1] (full domain of Eq (6)).
   NOTE / approximation: the real vapour contains water (y < 1), so
   this is NOT the true mixture dew curve of Eq (7); the dew-point
   temperature is treated as a pure-NH3 saturation temperature, the
   same x=1 endpoint convention used in the dual-adiabatic-chamber
   scans.  NAN if there is no root (e.g. Tsol_K well below Tdew_K). */
double x_by_tsol_tdew(double Tsol_K, double Tdew_K)
{
    double P = psol_TX(Tdew_K, 1.0);
    double lo = 0.0, hi = 1.0, mid;
    int k;
    if (P < psol_TX(Tsol_K, 0.0) || P > psol_TX(Tsol_K, 1.0))
        return NAN;
    for (k = 0; k < 80; k++) {
        mid = 0.5 * (lo + hi);
        if (psol_TX(Tsol_K, mid) < P) lo = mid; else hi = mid;
    }
    return 0.5 * (lo + hi);
}


/* Dew-point temperature [K] of the solution at (T_K, x), under the
   library-wide TdewByTsolXi convention (pure-refrigerant endpoint):
   Tdew = T_bubble_PX(psol_TX(T_K, x), x=1), the pure-ammonia
   saturation temperature on this module's own pure line (x = 1
   endpoint of Eq (6)) at the solution surface pressure Psol.
   CAUTION: the absorbent (water) IS volatile for this pair, so this
   is NOT the true mixture dew point T_dew_PY(p, z) of Eq (7) used
   for the glide figures; do not interchange the two. */
double tdew_from_tsol_x(double T_K, double x)
{
    return T_bubble_PX(psol_TX(T_K, x), 1.0);
}


/* Solution temperature [K] from specific enthalpy h [kJ/kg] and NH3
   mole fraction x: bisection inverse of hsol (Eq 9), which increases
   monotonically with T at fixed x.  Solver bracket T in [240, 480] K.
   NAN if h lies outside the hsol span at x. */
double tsol_by_hsol(double h, double x)
{
    double lo = 240.0, hi = 480.0, mid;
    int k;
    if (h < hsol(lo, x) || h > hsol(hi, x)) return NAN;
    for (k = 0; k < 100; k++) {
        mid = 0.5 * (lo + hi);
        if (hsol(mid, x) < h) lo = mid; else hi = mid;
    }
    return 0.5 * (lo + hi);
}

/* Dew pressure [MPa] at (T, y): bisection inverse of Eq (7). */
double p_dew_TY(double T_K, double y)
{
    double p_lo = 0.02, p_hi = 2.0, flo, fm, pm;
    int k;
    flo = T_dew_PY(p_lo, y) - T_K;
    for (k = 0; k < 200; k++) {
        pm = 0.5 * (p_lo + p_hi);
        fm = T_dew_PY(pm, y) - T_K;
        if (fm == 0.0 || (p_hi - p_lo) < 1e-9 * (pm > 1.0 ? pm : 1.0))
            return pm;
        if ((fm > 0.0) == (flo > 0.0)) { p_lo = pm; flo = fm; }
        else p_hi = pm;
    }
    return 0.5 * (p_lo + p_hi);
}

#ifdef AW_TEST_MAIN
#include <stdio.h>
int main(void)
{
    /* spot values; compare with `python3 ammonia_water.py` */
    printf("T_bub(1.0,0.5)   = %.6f K\n", T_bubble_PX(1.0, 0.5));
    printf("T_dew(1.0,0.5)   = %.6f K\n", T_dew_PY(1.0, 0.5));
    printf("y_eq (1.0,0.5)   = %.8f\n",   y_equil(1.0, 0.5));
    printf("hsol(Tbub,0.5)  = %.6f kJ/kg\n", hsol(T_bubble_PX(1.0,0.5), 0.5));
    printf("hgas(Tbub,y)    = %.6f kJ/kg\n",
           hgas(T_bubble_PX(1.0,0.5), y_equil(1.0,0.5)));
    printf("glide(1.0,0.5)   = %.6f K\n", glide_pX(1.0, 0.5));
    return 0;
}
#endif

/* Thermodynamic correlations for R22-DEGDME (C implementation, pointwise identical to r22_degdme.py)
 * Source: E. Ando, I. Takeshita, Int. J. Refrigeration, Vol.7, No.3, 1984.
 *   Eq. (1) Bubble-point pressure Rankine equation: lnP = ΣAnX^n + (1/T)ΣBnX^n + lnT·ΣCnX^n
 *         P: kg/cm2, T: K, X: R22 mole fraction; valid X=0.1~1.0, T=-20~190°C
 *   Eq. (6) Molar heat capacity: C = ΣAnX^n + t·ΣBnX^n + t^2·ΣCnX^n
 *         C: J/mol/°C, t: °C; t=-30~110°C
 *   Eq. (7) Heat of mixing (10°C): ΔHm = X(1-X)·Σ Gi·(1-2X)^(i-1), i=1..4; J/mol
 *   Eq. (9) Solution enthalpy: H = ΔHm + integral(10°C->t) Cp dτ; reference state: pure-component liquids have enthalpy 0 at 10°C
 * Build: gcc -O2 -Wall -o r22_degdme r22_degdme.c -lm
 */
#include <stdio.h>
#include <math.h>

static const double M_R22 = 86.47;      /* g/mol */
static const double M_DEGDME = 134.17;  /* g/mol */
static const double TM_C = 10.0;        /* °C */
static const double KGCM2_TO_MPA = 0.0980665; /* 1 kg/cm2 = 0.0980665 MPa (exact definition) */

/* Table 2: (A, B, C) of Eq. (1) for n=0..5 */
static const double T2[6][3] = {
    { 5.2167e1, -5.5828e3, -6.3489e0},
    { 1.2753e1,  3.3999e3, -1.4386e0},
    {-1.3901e2, -8.6015e3,  2.2313e1},
    { 7.3205e2, -3.1686e3, -1.1454e2},
    {-1.1910e3,  3.0425e4,  1.8148e2},
    { 5.4717e2, -1.9049e4, -8.1999e1},
};

/* Table 3: (A, B, C) of Eq. (6) for n=0..3 */
static const double T3[4][3] = {
    { 2.7974e2, -4.2015e-2,  2.3114e-3},
    {-1.5075e2,  5.9865e-1, -5.9745e-3},
    { 1.0095e2, -1.3790e0,   3.4322e-3},
    {-1.2802e2,  1.0167e0,   1.0571e-3},
};

/* Eq. (7): G1..G4 */
static const double G4[4] = {-1.9061e4, 8.7280e3, -1.3948e3, -6.4218e2};

static double poly(const double *c, int n, double x)
{
    double s = 0.0, xn = 1.0;
    for (int i = 0; i < n; i++) { s += c[i] * xn; xn *= x; }
    return s;
}

/* Eq. (1): bubble-point pressure kg/cm2, T_K in kelvin */
double r22degdme_psol_kgcm2(double X, double T_K)
{
    double A[6], B[6], C[6];
    for (int i = 0; i < 6; i++) { A[i] = T2[i][0]; B[i] = T2[i][1]; C[i] = T2[i][2]; }
    double sA = poly(A, 6, X), sB = poly(B, 6, X), sC = poly(C, 6, X);
    return exp(sA + sB / T_K + sC * log(T_K));
}

/* Eq. (1): bubble-point pressure MPa, t_C in °C.
 * [Note: the function name r22degdme_psol_bar is the retained original name (renaming pending a ruling); the return unit
 * has been changed from bar to MPa] = native kg/cm2 value x0.0980665. */
double r22degdme_psol_bar(double X, double t_C)
{
    return r22degdme_psol_kgcm2(X, t_C + 273.15) * KGCM2_TO_MPA;
}

/* Solve the concentration X (R22 mole fraction) back from the dew-point temperature and the solution temperature, by 80 bisection steps.
 * The dew point fixes the pressure P = r22degdme_psol_kgcm2(1.0, Tdew_C+273.15) [native kg/cm2
 * ]: at the X=1 end, Eq. (1) is this module's pure-R22 saturation pressure (DEGDME treated as
 * non-volatile); then bisection solves r22degdme_psol_kgcm2(X, Tsol_C+273.15) = P,
 * with the bracket taken as the valid concentration domain of Eq. (1), X in [0.1, 1.0]. Internally the native kg/cm2
 * functions are used throughout (not via the MPa export line), so the concentration output is bit-for-bit unchanged.
 * Returns NAN when there is no root (e.g. Tsol clearly below Tdew). */
double r22degdme_XiByTsolTdew(double Tsol_C, double Tdew_C)
{
    double P = r22degdme_psol_kgcm2(1.0, Tdew_C + 273.15);
    double lo = 0.1, hi = 1.0, mid;
    int k;
    if (P < r22degdme_psol_kgcm2(0.1, Tsol_C + 273.15) || P > r22degdme_psol_kgcm2(1.0, Tsol_C + 273.15))
        return NAN;
    for (k = 0; k < 80; k++) {
        mid = 0.5 * (lo + hi);
        if (r22degdme_psol_kgcm2(mid, Tsol_C + 273.15) < P) lo = mid; else hi = mid;
    }
    return 0.5 * (lo + hi);
}


/* Dew-point temperature [°C] of the solution at (X, t_C) (library-wide TdewByTsolXi convention):
 * the temperature on this module's own pure-R22 line (the X=1 end of Eq. (1)) satisfying
 * r22degdme_psol_kgcm2(1.0, Tdew+273.15) =
 * r22degdme_psol_kgcm2(X, t_C+273.15) [native kg/cm2],
 * inverted by 80 bisection steps, bracket t in [-50, 190] °C. Internally the native kg/cm2
 * functions are used throughout (not via the MPa export line), so the temperature output is bit-for-bit unchanged. Note: Eq. (1)
 * has a nominal temperature domain of -20~190 °C; Tdew < -20 °C is an extrapolation of the pure end. Returns NAN when there is no root. */
double r22degdme_TdewByTsolXi(double X, double t_C)
{
    double P = r22degdme_psol_kgcm2(X, t_C + 273.15);
    double lo = -50.0, hi = 190.0, mid;
    int k;
    if (P < r22degdme_psol_kgcm2(1.0, lo + 273.15) || P > r22degdme_psol_kgcm2(1.0, hi + 273.15))
        return NAN;
    for (k = 0; k < 80; k++) {
        mid = 0.5 * (lo + hi);
        if (r22degdme_psol_kgcm2(1.0, mid + 273.15) < P) lo = mid; else hi = mid;
    }
    return 0.5 * (lo + hi);
}

double r22degdme_hsol(double X, double t_C);  /* forward: defined below */
/* Solve the solution temperature [°C] back from the solution specific enthalpy h [kJ/kg] and R22 mole fraction X:
 * r22degdme_hsol increases monotonically with t at fixed X; inverted by 100 bisection steps,
 * bracket t in [-30, 110] °C. Returns NAN when there is no root. */
double r22degdme_TsolByHsol(double h, double X)
{
    double lo = -30.0, hi = 110.0, mid;
    int k;
    if (h < r22degdme_hsol(X, lo) || h > r22degdme_hsol(X, hi)) return NAN;
    for (k = 0; k < 100; k++) {
        mid = 0.5 * (lo + hi);
        if (r22degdme_hsol(X, mid) < h) lo = mid; else hi = mid;
    }
    return 0.5 * (lo + hi);
}

/* Eq. (6): molar heat capacity J/mol/°C */
double r22degdme_cp_molar(double X, double t_C)
{
    double A[4], B[4], C[4];
    for (int i = 0; i < 4; i++) { A[i] = T3[i][0]; B[i] = T3[i][1]; C[i] = T3[i][2]; }
    double sA = poly(A, 4, X), sB = poly(B, 4, X), sC = poly(C, 4, X);
    return sA + t_C * sB + t_C * t_C * sC;
}

/* Eq. (7): heat of mixing J/mol (measured value at 10°C) */
double r22degdme_heat_of_mixing(double X)
{
    double s = 0.0, p = 1.0, d = 1.0 - 2.0 * X;
    for (int i = 0; i < 4; i++) { s += G4[i] * p; p *= d; }
    return X * (1.0 - X) * s;
}

/* Eq. (9): solution specific enthalpy kJ/kg; reference state: pure-component liquids have enthalpy 0 at 10°C */
double r22degdme_hsol(double X, double t_C)
{
    double A[4], B[4], C[4];
    for (int i = 0; i < 4; i++) { A[i] = T3[i][0]; B[i] = T3[i][1]; C[i] = T3[i][2]; }
    double sA = poly(A, 4, X), sB = poly(B, 4, X), sC = poly(C, 4, X);
    double t0 = TM_C;
    double sensible = sA * (t_C - t0)
                    + sB * (t_C * t_C - t0 * t0) / 2.0
                    + sC * (t_C * t_C * t_C - t0 * t0 * t0) / 3.0; /* J/mol */
    double h_mol = r22degdme_heat_of_mixing(X) + sensible;          /* J/mol */
    double M_mix = X * M_R22 + (1.0 - X) * M_DEGDME;                /* g/mol */
    return h_mol / M_mix;                                           /* kJ/kg */
}

#ifdef R22DEGDME_MAIN
int main(void)
{
    /* Grid self-check output, for pointwise comparison against the Python version */
    double Xs[] = {0.1, 0.3, 0.5, 0.7, 0.9, 1.0};
    double ts[] = {-20.0, 0.0, 10.0, 40.0, 80.0, 110.0};
    for (int i = 0; i < 6; i++)
        for (int j = 0; j < 6; j++) {
            double X = Xs[i], t = ts[j];
            printf("%.1f %.1f %.6f %.6f %.6f %.6f\n", X, t,
                   r22degdme_psol_bar(X, t),
                   r22degdme_cp_molar(X, t),
                   r22degdme_heat_of_mixing(X),
                   r22degdme_hsol(X, t));
        }
    return 0;
}
#endif

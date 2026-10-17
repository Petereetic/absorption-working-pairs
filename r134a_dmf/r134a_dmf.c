/*
 * R134a (1) + DMF (2) solution VLE and enthalpy calculation - C implementation
 * ==================================================
 * Model: NRTL activity coefficients + gamma-phi bubble-point model
 * Data source: Zehioua et al., J. Chem. Eng. Data 2009, DOI: 10.1021/je900440t
 * Validation: 58 experimental points (303.30-353.24 K); bubble-point pressure mean absolute relative error 1.49%
 *        (Note: the 1.49% is only the fit accuracy on the training set. Independent validations: Cui 2007, 90 points, AARD 15.1%;
 *         Han 2011, 112 points, AARD 10.1%; cross-laboratory uncertainty about 300K/8%, 360K/20%.
 *         See the merged-literature study document for R134a-DMF, dated 2026-09-30.)
 *
 * Reference state: saturated-liquid enthalpy at 273.15 K = 100 kJ/kg (unified for R134a and DMF)
 *
 * Build: gcc -O2 -o r134a_dmf r134a_dmf.c -lm
 * Run: ./r134a_dmf
 */

#include <stdio.h>
#include <math.h>

/* ---------- Constants ---------- */
#define R_GAS   8.314462618   /* J/(mol·K) */
#define M1      102.03        /* R134a molar mass, g/mol */
#define M2      73.09         /* DMF molar mass, g/mol */

/* NRTL parameters (fitted within the gamma-phi framework, alpha=0.3) */
#define DG12    868.1         /* J/mol, (g12 - g22) */
#define DG21   -929.1         /* J/mol, (g21 - g11) */
#define ALPHA   0.3

/* ---------- Pure-component saturation pressures (MPa), T in K ---------- */

/* R134a: fitted to Table 3 of Zehioua; error < 0.2% within 298-353K */
double pref_r134a(double T)
{
    return exp(7.89191 - 2310.84 / (T - 19.79));
}

/* DMF: NIST WebBook (Gopal & Rizvi 1968), 303-363K */
double psat_dmf(double T)
{
    return pow(10.0, 3.93068 - 1337.716 / (T - 82.648)) * 0.1;
}

/* ---------- Liquid molar volumes (m3/mol), for the Poynting correction ---------- */

double vl_r134a(double T)
{
    double rho = 1207.0 * (1.0 - 0.35 * (T - 300.0) / 100.0); /* kg/m3 */
    if (rho < 800.0) rho = 800.0;
    return 0.10203 / rho;
}

double vl_dmf(double T)
{
    return 0.07309 / (944.0 * (1.0 - 0.0009 * (T - 293.0)));
}

/* ---------- NRTL activity coefficients ---------- */
/* Input: T(K), x1 (R134a liquid-phase mole fraction); output: *g1, *g2 */
void nrtl_gamma(double T, double x1, double *g1, double *g2)
{
    double x2 = 1.0 - x1;
    double t12 = DG12 / (R_GAS * T);
    double t21 = DG21 / (R_GAS * T);
    double G12 = exp(-ALPHA * t12);
    double G21 = exp(-ALPHA * t21);
    double D1 = x1 + x2 * G21;
    double D2 = x2 + x1 * G12;
    double r1 = G21 / D1, r2 = G12 / D2;
    double ln_g1 = x2 * x2 * (t21 * r1 * r1 + t12 * G12 / (D2 * D2));
    double ln_g2 = x1 * x1 * (t12 * r2 * r2 + t21 * G21 / (D1 * D1));
    *g1 = exp(ln_g1);
    *g2 = exp(ln_g2);
}

/* ---------- NRTL excess molar enthalpy (J/mol), analytic form ---------- */
double nrtl_hE(double T, double x1)
{
    double x2 = 1.0 - x1;
    double t12 = DG12 / (R_GAS * T);
    double t21 = DG21 / (R_GAS * T);
    double G12 = exp(-ALPHA * t12);
    double G21 = exp(-ALPHA * t21);
    double D1 = x1 + x2 * G21;
    double D2 = x2 + x1 * G12;
    double term1 = (t21 * G21 / D1) * (-1.0 + ALPHA * t21 * x1 / D1);
    double term2 = (t12 * G12 / D2) * (-1.0 + ALPHA * t12 * x2 / D2);
    return -R_GAS * T * x1 * x2 * (term1 + term2);
}

/* ---------- Bubble-point pressure ---------- */
/*
 * Input: T(K), x1 (liquid-phase mole fraction)
 * Output: *p_MPa bubble-point pressure, *y1 vapour-phase mole fraction (NULL allowed)
 * Returns: 0 on success
 */
int psol(double T, double x1, double *p_MPa, double *y1)
{
    double x2 = 1.0 - x1;
    double g1, g2, p1s, p2s, V1, V2, p, Poy1, Poy2;
    int i;

    nrtl_gamma(T, x1, &g1, &g2);
    p1s = pref_r134a(T);
    p2s = psat_dmf(T);
    V1 = vl_r134a(T);
    V2 = vl_dmf(T);

    p = x1 * g1 * p1s + x2 * g2 * p2s;
    for (i = 0; i < 40; i++) {
        Poy1 = exp(V1 * (p - p1s) * 1e6 / (R_GAS * T));
        Poy2 = exp(V2 * (p - p2s) * 1e6 / (R_GAS * T));
        p = x1 * g1 * p1s * Poy1 + x2 * g2 * p2s * Poy2;
    }

    *p_MPa = p;
    if (y1) {
        Poy1 = exp(V1 * (p - p1s) * 1e6 / (R_GAS * T));
        *y1 = x1 * g1 * p1s * Poy1 / p;
    }
    return 0;
}

/* ---------- Back-calculate the temperature from the bubble-point pressure (Newton iteration) ---------- */
double bubble_T(double p_MPa, double x1, double Tguess)
{
    double T = Tguess, pc, p2, dpdT, dT = 0.2;
    int i;
    for (i = 0; i < 50; i++) {
        double dummy;
        psol(T, x1, &pc, &dummy);
        psol(T + dT, x1, &p2, &dummy);
        dpdT = (p2 - pc) / dT;
        if (fabs(dpdT) < 1e-12) break;
        T = T - (pc - p_MPa) / dpdT;
        if (fabs(pc - p_MPa) < 1e-9) break;
    }
    return T;
}

/* ---------- Back-calculate the concentration from the dew-point temperature and the solution temperature (80 bisection steps) ---------- */
/*
 * Input: Tdew(K) dew-point temperature, Tsol(K) solution temperature
 * Returns: x1 (R134a liquid-phase mole fraction); NAN when there is no root
 * Principle: DMF is treated as non-volatile; the dew point fixes the pressure P = pref_r134a(Tdew);
 *       then bisection solves psol(Tsol, x1) = P, with the bracket x1 in [0, 1].
 * No-root case: P outside the bubble-point pressure interval under Tsol (e.g. Tsol clearly below Tdew).
 */
double xi_by_tsol_tdew(double Tsol, double Tdew)
{
    double P = pref_r134a(Tdew);
    double Plo, Phi, lo = 0.0, hi = 1.0, mid;
    int i;
    psol(Tsol, 0.0, &Plo, NULL);
    psol(Tsol, 1.0, &Phi, NULL);
    if (P < Plo || P > Phi) return NAN;
    for (i = 0; i < 80; i++) {
        double pm;
        mid = 0.5 * (lo + hi);
        psol(Tsol, mid, &pm, NULL);
        if (pm < P) lo = mid; else hi = mid;
    }
    return 0.5 * (lo + hi);
}

/* ---------- Pure-component liquid enthalpies (kJ/kg), reference state 273.15K = 100 ---------- */

/* R134a saturated liquid: fitted to Tillner-Roth & Baehr (1994), 233-353K */

double hsol(double T, double x1);  /* forward: defined below */
/* R134a saturation temperature [K]: analytic inverse of pref_r134a. */
static double tsat_r134a(double P_MPa)
{
    return 2310.84 / (7.89191 - log(P_MPa)) + 19.79;
}

/* Dew-point temperature [K] of the solution at (T, x1)
   (library-wide TdewByTsolXi convention): tsat_r134a of the Psol
   pressure on this module's own pure-R134a line. */
double tdew_by_tsol_xi(double T, double x1)
{
    double p, y1;
    psol(T, x1, &p, &y1);
    return tsat_r134a(p);
}

/* Solution temperature [K] from h [kJ/kg] and x1: bisection inverse
   of hsol over T in [280, 360] K.  NAN if h is outside the span. */
double tsol_by_hsol(double h, double x1)
{
    double lo = 280.0, hi = 360.0, mid;
    int k;
    if (h < hsol(lo, x1) || h > hsol(hi, x1)) return NAN;
    for (k = 0; k < 100; k++) {
        mid = 0.5 * (lo + hi);
        if (hsol(mid, x1) < h) lo = mid; else hi = mid;
    }
    return 0.5 * (lo + hi);
}

double hliq_r134a(double T)
{
    double t = T - 273.15;
    return 1.310235e-5 * t * t * t
         + 1.34329e-3  * t * t
         + 1.334242    * t
         + 100.0;
}

/* DMF liquid: He et al., Solar Energy 83 (2009), Eq. (5) */
double h_dmf_L(double T)
{
    return -297.61 + 0.89544 * T + 0.0020551 * T * T;
}

/* ---------- Mole fraction <-> mass fraction (R134a) ---------- */
double x_to_w(double x1)
{
    return x1 * M1 / (x1 * M1 + (1.0 - x1) * M2);
}

double w_to_x(double w1)
{
    return (w1 / M1) / (w1 / M1 + (1.0 - w1) / M2);
}

/* ---------- Solution enthalpy (kJ/kg) ---------- */
/* h = w1*h1 + w2*h2 + hE/Mbar */
double hsol(double T, double x1)
{
    double x2 = 1.0 - x1;
    double Mbar = x1 * M1 + x2 * M2;   /* g/mol */
    double w1 = x1 * M1 / Mbar;
    double w2 = x2 * M2 / Mbar;
    double hE = nrtl_hE(T, x1);        /* J/mol */
    return w1 * hliq_r134a(T) + w2 * h_dmf_L(T) + hE / Mbar;
}

/* ---------- Self-check main function ---------- */
int main(void)
{
    double p, y1, T;
    int i;

    /* VLE check points: {T(K), x1, Pexp(kPa)} */
    double chk[][3] = {
        {303.30, 0.4437,  337.0},
        {323.34, 0.7247,  923.8},
        {353.24, 0.6594, 1665.2},
    };

    printf("VLE 验证 (T, x1 -> p):\n");
    for (i = 0; i < 3; i++) {
        psol(chk[i][0], chk[i][1], &p, &y1);
        printf("  T=%.2fK x1=%.4f: p=%.1f kPa (实验 %.1f), y1=%.4f\n",
               chk[i][0], chk[i][1], p * 1000.0, chk[i][2], y1);
    }

    printf("\n反算泡点温度:\n");
    T = bubble_T(0.3370, 0.4437, 330.0);
    printf("  p=0.337MPa x1=0.4437 -> T=%.2fK (期望 ~303.3K)\n", T);
    T = bubble_T(0.9238, 0.7247, 330.0);
    printf("  p=0.9238MPa x1=0.7247 -> T=%.2fK (期望 ~323.3K)\n", T);

    printf("\n溶液焓 h(T,x1) [kJ/kg]:\n");
    {
        double Ts[] = {300.0, 330.0, 350.0};
        double xs[] = {0.2, 0.5, 0.8};
        int ti, xi;
        for (ti = 0; ti < 3; ti++)
            for (xi = 0; xi < 3; xi++)
                printf("  T=%.0fK x1=%.1f: h=%.2f\n",
                       Ts[ti], xs[xi], hsol(Ts[ti], xs[xi]));
    }

    printf("\n质量分数换算示例: w1=0.5 -> x1=%.4f\n", w_to_x(0.5));
    return 0;
}

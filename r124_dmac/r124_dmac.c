/* R124-DMAC working pair: bubble pressure, solution enthalpy, density,
 * viscosity. Transcribed from Borde, Jelinek & Daltrophe, Int. J.
 * Refrigeration 20(4), 256-266, 1997.
 *
 * Conventions: T_C in degC, xi = R124 mass fraction, P in bar,
 * h in kJ/kg (reference: pure liquids = 100 kJ/kg at 0 degC),
 * rho in kg/m3, eta in mPa s.
 *
 * Two printed values are corrected on documented evidence (see
 * Borde1997与硕士论文_核验.md): Table 9 rho_00 exponent (E+01 -> E+00)
 * and Table 8 DMAC eta0/eta1 (x10 too large as printed).
 * NOTE: Eq. (16) runs +13..+23 % above Eq. (15) at xi = 1 (property of
 * the printed fit); use R124DMAC_PsatR124 near xi = 1.
 */
#include <math.h>

static const double M_R124 = 136.50, M_DMAC = 87.12;

/* Eq. (15) pure vapour pressure coefficients (Table 2): A,B,C,D,E,F */
static const double PS_R124[6] = {-119.33446, -1351.341, 0.0, -0.12497, 27.21197, 8.32656e-5};
static const double PS_DMAC[6] = {6.01834, -1800.240, -138.5, 0.0, 0.0, 0.0};

static double psat_eq15(const double c[6], double T_C)
{
    double T = T_C + 273.15;
    return exp(c[0] + c[1] / (T + c[2]) + c[3] * T + c[4] * log(T) + c[5] * T * T);
}

double R124DMAC_PsatR124(double T_C) { return psat_eq15(PS_R124, T_C); }
double R124DMAC_PsatDMAC(double T_C) { return psat_eq15(PS_DMAC, T_C); }

double R124DMAC_DewT(double P_bar)
{
    double lo = -60.0, hi = 120.0, mid;
    int k;
    if (P_bar < R124DMAC_PsatR124(lo) || P_bar > R124DMAC_PsatR124(hi))
        return NAN;
    for (k = 0; k < 80; k++) {
        mid = 0.5 * (lo + hi);
        if (R124DMAC_PsatR124(mid) < P_bar) lo = mid; else hi = mid;
    }
    return 0.5 * (lo + hi);
}

/* Eq. (16) bubble pressure, Table 3: P = sum_j sum_i p_ij xi^i T^j (T in K) */
static const double PTAB[8][8] = {
    { 0.11502e-01, -0.28240e+02,  0.41188e+02, -0.26168e+02,  0.0,          0.18381e+03, -0.31190e+03,  0.13914e+03},
    {-0.13711e-01,  0.24179e+00, -0.26951e+00,  0.0,          0.0,          0.75999e-01,  0.0,          0.0},
    { 0.91911e-04,  0.0,          0.0,          0.0,          0.0,          0.0,          0.0,          0.0},
    { 0.0,         -0.31564e-05,  0.92677e-06,  0.78191e-05, -0.13310e-04,  0.0,          0.12701e-04, -0.65958e-05},
    {-0.86519e-09,  0.0,          0.0,          0.0,          0.0,          0.0,          0.0,          0.0},
    { 0.0,          0.22998e-10,  0.0,          0.0,          0.0,          0.33233e-10,  0.0,         -0.24081e-10},
    { 0.59436e-14,  0.0,         -0.68310e-13,  0.0,         -0.17145e-13,  0.0,          0.0,          0.0},
    {-0.67036e-17, -0.53440e-16,  0.14140e-15, -0.94881e-16,  0.0,          0.56692e-15, -0.10014e-14,  0.53340e-15}
};

double R124DMAC_BubbleP(double T_C, double xi)
{
    double T = T_C + 273.15, s = 0.0, xip, Tp;
    int i, j;
    for (j = 0; j < 8; j++) {
        double row = 0.0;
        xip = 1.0;
        for (i = 0; i < 8; i++) { row += PTAB[j][i] * xip; xip *= xi; }
        Tp = 1.0;
        for (i = 0; i < j; i++) Tp *= T;
        s += row * Tp;
    }
    return s;
}

double R124DMAC_BubbleT(double P_bar, double xi)
{
    double lo = 0.0, hi = 150.0, mid;
    int k;
    if (P_bar < R124DMAC_BubbleP(lo, xi) || P_bar > R124DMAC_BubbleP(hi, xi))
        return NAN;
    for (k = 0; k < 80; k++) {
        mid = 0.5 * (lo + hi);
        if (R124DMAC_BubbleP(mid, xi) < P_bar) lo = mid; else hi = mid;
    }
    return 0.5 * (lo + hi);
}

/* Eq. (19) excess enthalpy, Table 4: hE = 4.1868 sum_j sum_i h_ij x^i T^j */
static const double HTAB[8][8] = {
    {-0.34981e+02, -0.18479e+03,  0.27310e+03, -0.22155e+02,  0.0,         -0.49058e+02,  0.61147e+01,  0.16635e+01},
    { 0.31418e+00,  0.59584e+00, -0.90572e+00,  0.0,          0.0,          0.16399e+00,  0.0,          0.0},
    {-0.80917e-03,  0.0,          0.0,          0.11400e-04,  0.0,          0.0,          0.0,          0.0},
    { 0.0,          0.32184e-07,  0.0,          0.0,          0.14107e-05,  0.0,          0.74883e-06, -0.10444e-05},
    { 0.17947e-08,  0.0,          0.0,          0.0,          0.0,          0.0,          0.0,          0.0},
    { 0.0,         -0.11860e-10,  0.18271e-10,  0.0,          0.0,         -0.22810e-10,  0.0,          0.10914e-10},
    { 0.0,          0.0,          0.0,          0.0,          0.0,          0.0,          0.0,          0.0},
    {-0.43652e-17,  0.34001e-16, -0.50197e-16, -0.10080e-16,  0.0,          0.67800e-16,  0.0,         -0.31527e-16}
};

double R124DMAC_HExcess(double T_C, double xi)
{
    double T = T_C + 273.15, nr = xi / M_R124, na = (1.0 - xi) / M_DMAC;
    double x = nr / (nr + na), s = 0.0, xp, Tp;
    int i, j;
    for (j = 0; j < 8; j++) {
        double row = 0.0;
        xp = 1.0;
        for (i = 0; i < 8; i++) { row += HTAB[j][i] * xp; xp *= x; }
        Tp = 1.0;
        for (i = 0; i < j; i++) Tp *= T;
        s += row * Tp;
    }
    return 4.1868 * s;
}

double R124DMAC_Ha(double T_C)   /* Eq. (20), DMAC, Table 5 */
{
    return 100.0 + 4.1868 * (0.4578 * T_C + 0.5 * 0.000839 * T_C * T_C);
}

double R124DMAC_Hr(double T_C)   /* Eq. (21), R124, Table 6 */
{
    static const double hr[7] = {0.250767, 0.347753e-3, 0.100977e-5,
                                 0.342458e-8, 0.0, 0.0, 0.699612e-14};
    double s = 0.0, tp = T_C;
    int i;
    for (i = 0; i < 7; i++) { s += hr[i] * tp; tp *= T_C; }
    return 100.0 + 4.1868 * s;
}

double R124DMAC_Hsol(double T_C, double xi)   /* Eq. (22) */
{
    return R124DMAC_Hr(T_C) * xi + R124DMAC_Ha(T_C) * (1.0 - xi)
         + R124DMAC_HExcess(T_C, xi);
}

/* Eq. (23) pure densities, Table 7 (result kg/m3) */
double R124DMAC_RhoR124(double T_C)
{
    return 1000.0 * (1.4660 - 0.3394e-2 * T_C - 0.16063e-5 * T_C * T_C
                     - 0.20040e-6 * T_C * T_C * T_C);
}
double R124DMAC_RhoDMAC(double T_C)
{
    return 1000.0 * (0.9528 - 0.5856e-3 * T_C - 0.33632e-5 * T_C * T_C);
}

/* Eq. (25) mixture density, Table 9 (rho_00 corrected to E+00) */
static const double RTAB[4][4] = {
    {0.95521,      0.43672,     -0.28160,      0.35610},
    {-0.15533e-3, -0.37079e-3,  0.0,         -0.29230e-2},
    {-0.13981e-4,  0.0,          0.13550e-4,   0.0},
    {0.60941e-7,  -0.97547e-7,   0.33531e-6,  -0.50554e-6}
};

double R124DMAC_RhoMix(double T_C, double xi)
{
    double s = 0.0, xip, tp;
    int i, j;
    for (j = 0; j < 4; j++) {
        double row = 0.0;
        xip = 1.0;
        for (i = 0; i < 4; i++) { row += RTAB[j][i] * xip; xip *= xi; }
        tp = 1.0;
        for (i = 0; i < j; i++) tp *= T_C;
        s += row * tp;
    }
    return 1000.0 * s;
}

/* Eq. (24) pure viscosities, Table 8 (DMAC row corrected, see header) */
double R124DMAC_EtaR124(double T_C)
{
    double T = T_C + 273.15;
    return exp(-8.9301 + 5094.90 / (T + 357.4));
}
double R124DMAC_EtaDMAC(double T_C)
{
    double T = T_C + 273.15;
    return exp(-1.68400 + 134.880 / (T - 223.2));
}

/* Eq. (26) mixture viscosity, Table 10: ln eta = sum_j sum_i e_ij xi^i T^-j */
static const double ETAB[4][4] = {
    {7.6992,     0.60007,   -8.9875,    -1.7031},
    {-6769.2,    0.0,        4555.4,    0.0},
    {1343400.0,  0.0,        0.0,       0.0},
    {0.0,       -64446000.0, 0.0,      -106310000.0}
};

double R124DMAC_EtaMix(double T_C, double xi)
{
    double T = T_C + 273.15, s = 0.0, xip, tp;
    int i, j;
    for (j = 0; j < 4; j++) {
        double row = 0.0;
        xip = 1.0;
        for (i = 0; i < 4; i++) { row += ETAB[j][i] * xip; xip *= xi; }
        tp = (j == 0) ? 1.0 : pow(T, -j);
        s += row * tp;
    }
    return exp(s);
}

#ifdef LOCAL_TEST
#include <stdio.h>
int main(void)
{
    printf("Psat R124 at -11 C   = %.3f bar (expect ~1.013)\n", R124DMAC_PsatR124(-11.0));
    printf("BubbleP(80 C, 0.5)   = %.3f bar\n", R124DMAC_BubbleP(80.0, 0.5));
    printf("BubbleT(2.977, 0.5)  = %.2f C (expect ~80)\n", R124DMAC_BubbleT(2.977, 0.5));
    printf("HExcess(20 C, 0.557) = %.2f kJ/kg\n", R124DMAC_HExcess(20.0, 0.557));
    printf("Hsol(0 C, 0)         = %.2f kJ/kg (expect ~100)\n", R124DMAC_Hsol(0.0, 0.0));
    printf("RhoMix(0 C, 0.5)     = %.1f kg/m3\n", R124DMAC_RhoMix(0.0, 0.5));
    printf("EtaMix(20 C, 0)      = %.3f mPa s\n", R124DMAC_EtaMix(20.0, 0.0));
    return 0;
}
#endif

/* R124-DMAC working pair: bubble pressure, solution enthalpy, density,
 * viscosity. Transcribed from Borde, Jelinek & Daltrophe, Int. J.
 * Refrigeration 20(4), 256-266, 1997.
 *
 * Conventions: T_C in degC, xi = R124 mass fraction, P in MPa at
 * the public boundary (changed 2026-10-14 from bar; 1 MPa = 10 bar),
 * h in kJ/kg (reference: pure liquids = 100 kJ/kg at 0 degC),
 * rho in kg/m3, eta in mPa s.  The Borde correlations are evaluated
 * internally in their native bar via static *_bar helpers; public
 * functions only scale by 0.1 (outputs) or 10 (inputs).
 *
 * Two printed values are corrected on documented evidence (see
 * Borde1997与硕士论文_核验.md): Table 9 rho_00 exponent (E+01 -> E+00)
 * and Table 8 DMAC eta0/eta1 (x10 too large as printed).
 * NOTE: Eq. (16) runs +13..+23 % above Eq. (15) at xi = 1 (property of
 * the printed fit); use R124DMAC_PrefR124 near xi = 1.
 *
 * Update 2026-10-12: R124DMAC_PrefR124 (and with it DewT,
 * TdewByTsolXi, AbsVapFlow) no longer uses Eq. (15) for R124, which
 * reads systematically low against the NIST saturation table
 * (-5.13 % at -30 C to -1.18 % at 120 C).  It is now the NIST-table
 * Wagner-type fit held in pure_fluids (identical coefficients).
 * psat_eq15 remains for DMAC.  See the module documentation.
 */
#include <math.h>

static const double M_R124 = 136.50, M_DMAC = 87.12;

/* Eq. (15) pure vapour pressure coefficients (Table 2): A,B,C,D,E,F.
 * The R124 row (-119.33446, -1351.341, 0.0, -0.12497, 27.21197,
 * 8.32656e-5) is no longer evaluated since the 2026-10-12 Pref
 * source change below; it is recorded here for reference. */
static const double PS_DMAC[6] = {6.01834, -1800.240, -138.5, 0.0, 0.0, 0.0};

static double psat_eq15(const double c[6], double T_C)
{
    double T = T_C + 273.15;
    return exp(c[0] + c[1] / (T + c[2]) + c[3] * T + c[4] * log(T) + c[5] * T * T);
}

/* Pure-R124 saturation pressure: NIST WebBook saturation-table fit
 * (Wagner type, exponents 1, 1.5, 3, 6), identical to
 * pure_fluids R124_Pref.  Band -40..110 C, max deviation vs the
 * NIST table 0.111 %.  Changed 2026-10-12 from Borde Eq. (15)
 * (coefficients recorded above; no longer evaluated). */
static double pref_r124_bar(double T_C)
{
    static const double W[4] = {-7.401179377235425, 1.4613603991162563,
                                -3.476435267708954, -1.772232810745864};
    double T = T_C + 273.15, tau = 1.0 - T / 395.428;
    return 36.245 * exp((395.428 / T) * (W[0] * tau + W[1] * pow(tau, 1.5)
                                         + W[2] * tau * tau * tau
                                         + W[3] * pow(tau, 6.0)));
}
/* Public: pure R124 saturation pressure in MPa. */
double R124DMAC_PrefR124(double T_C) { return 0.1 * pref_r124_bar(T_C); }
/* Public: pure DMAC saturation pressure in MPa (Eq. (15), native bar). */
double R124DMAC_PsatDMAC(double T_C) { return 0.1 * psat_eq15(PS_DMAC, T_C); }

static double tsat_r124_bar(double P_bar)
{
    double lo = -40.0, hi = 110.0, mid;
    int k;
    if (P_bar < pref_r124_bar(lo) || P_bar > pref_r124_bar(hi))
        return NAN;
    for (k = 0; k < 80; k++) {
        mid = 0.5 * (lo + hi);
        if (pref_r124_bar(mid) < P_bar) lo = mid; else hi = mid;
    }
    return 0.5 * (lo + hi);
}
/* Public: pure-R124 saturation (dew) temperature at P_MPa. */
double R124DMAC_DewT(double P_MPa) { return tsat_r124_bar(P_MPa * 10.0); }

/* Eq. (16) bubble pressure, Table 3: P = sum_j sum_i p_ij xi^i T^j (T in K;
 * source unit bar -- psol_bar() is the native value, public Psol is MPa) */
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

static double psol_bar(double T_C, double xi)
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

/* Public: bubble-point pressure in MPa. */
double R124DMAC_Psol(double T_C, double xi) { return 0.1 * psol_bar(T_C, xi); }

static double bubble_t_bar(double P_bar, double xi)
{
    double lo = 0.0, hi = 150.0, mid;
    int k;
    if (P_bar < psol_bar(lo, xi) || P_bar > psol_bar(hi, xi))
        return NAN;
    for (k = 0; k < 80; k++) {
        mid = 0.5 * (lo + hi);
        if (psol_bar(mid, xi) < P_bar) lo = mid; else hi = mid;
    }
    return 0.5 * (lo + hi);
}

/* Public: bubble-point temperature at P_MPa. */
double R124DMAC_BubbleT(double P_MPa, double xi)
{
    return bubble_t_bar(P_MPa * 10.0, xi);
}

/* Concentration from dew-point temperature and solution temperature:
 * the dew point fixes the pressure, P = PrefR124(Tdew) (DMAC treated as
 * non-volatile), then solve Psol(Tsol, xi) = P for xi by bisection.
 * Returns NAN if no root (P outside the bubble-pressure span at Tsol). */
double R124DMAC_XiByTsolTdew(double Tsol_C, double Tdew_C)
{
    double P = pref_r124_bar(Tdew_C);
    double lo = 0.0, hi = 1.0, mid;
    int k;
    if (P < psol_bar(Tsol_C, 0.0) || P > psol_bar(Tsol_C, 1.0))
        return NAN;
    for (k = 0; k < 80; k++) {
        mid = 0.5 * (lo + hi);
        if (psol_bar(Tsol_C, mid) < P) lo = mid; else hi = mid;
    }
    return 0.5 * (lo + hi);
}


/* Dew-point temperature [degC] of the solution at (T_C, xi)
   (library-wide TdewByTsolXi convention):
   R124DMAC_DewT(R124DMAC_Psol(T_C, xi)) on this module's pure-R124
   NIST-table fit line (PrefR124; Borde Eq (15) before 2026-10-12).
   NAN if DewT has no root. */
double R124DMAC_TdewByTsolXi(double T_C, double xi)
{
    return tsat_r124_bar(psol_bar(T_C, xi));
}

double R124DMAC_hsol(double T_C, double xi);  /* forward: defined below */
/* Solution temperature [degC] from h [kJ/kg] and xi: bisection
   inverse of R124DMAC_hsol over T in [-40, 150] degC.
   NAN if h lies outside the hsol span at xi. */
double R124DMAC_TsolByHsol(double h, double xi)
{
    double lo = -40.0, hi = 150.0, mid;
    int k;
    if (h < R124DMAC_hsol(lo, xi) || h > R124DMAC_hsol(hi, xi)) return NAN;
    for (k = 0; k < 100; k++) {
        mid = 0.5 * (lo + hi);
        if (R124DMAC_hsol(mid, xi) < h) lo = mid; else hi = mid;
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

double R124DMAC_hsol(double T_C, double xi)   /* Eq. (22) */
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
    printf("Psat R124 at 20 C    = %.4f MPa (expect ~0.3269, NIST)\n", R124DMAC_PrefR124(20.0));
    printf("Psol(80 C, 0.5)   = %.4f MPa\n", R124DMAC_Psol(80.0, 0.5));
    printf("BubbleT(0.2977 MPa, 0.5)  = %.2f C (expect ~80)\n", R124DMAC_BubbleT(0.2977, 0.5));
    printf("HExcess(20 C, 0.557) = %.2f kJ/kg\n", R124DMAC_HExcess(20.0, 0.557));
    printf("Hsol(0 C, 0)         = %.2f kJ/kg (expect ~100)\n", R124DMAC_hsol(0.0, 0.0));
    printf("RhoMix(0 C, 0.5)     = %.1f kg/m3\n", R124DMAC_RhoMix(0.0, 0.5));
    printf("EtaMix(20 C, 0)      = %.3f mPa s\n", R124DMAC_EtaMix(20.0, 0.0));
    return 0;
}
#endif

/* ---- Adiabatic absorber ---------------------------------------------------
 * Saturated vapour enthalpy of pure R124 (kJ/kg): NIST WebBook saturation
 * table fit, identical polynomial to pure_fluids R124_hgas. Reference state
 * matches this module (liquid = 100 kJ/kg at 0 degC). Fit band -40..110 C.
 */
static const double HVAP_R124[7] = {
    -4.7606354686130485e-12, -9.020883920792309e-10, 2.036341936229362e-08,
    4.234769176716097e-06, -3.8033802108463233e-04, 5.621038923140594e-01,
    2.5994742998138406e+02
};

static double hgas_R124(double T_C)
{
    double s = 0.0;
    int i;
    for (i = 0; i < 7; i++) s = s * T_C + HVAP_R124[i];
    return s;
}

static double abs_resid(double xr, double xi_w, double hs, double hv,
                        double P_bar)
{
    double Tout = bubble_t_bar(P_bar, xr);
    double r;
    if (isnan(Tout)) return NAN;
    r = (xr - xi_w) / (1.0 - xr);
    return hs + r * hv - (1.0 + r) * R124DMAC_hsol(Tout, xr);
}

/* Vapour flow absorbed in a single-pass adiabatic absorber.
 * Inlets: weak solution (flow ms, Ts_C, xi_w) and saturated vapour at
 * Tv_C; absorber pressure = pref_R124(Tv_C). Outlet is the adiabatic-
 * equilibrium state at that pressure. Returns the vapour flow (same
 * units as ms); Tout_C / xi_r receive the outlet state when non-NULL.
 * NAN if no solution inside the model domain (xi <= 0.95; Tv -40..110).
 */
double R124DMAC_AbsVapFlow(double Ts_C, double xi_w, double ms,
                           double Tv_C, double *Tout_C, double *xi_r)
{
    double P, hv, hs, prev_x = 0.0, prev_f = 0.0, blo = 0.0, bhi = 0.0;
    int i, have_prev = 0, have_bracket = 0;
    const int n = 400;
    if (Tv_C < -40.0 || Tv_C > 110.0 || xi_w >= 0.95) return NAN;
    P = pref_r124_bar(Tv_C);
    hv = hgas_R124(Tv_C);
    hs = R124DMAC_hsol(Ts_C, xi_w);
    for (i = 1; i <= n && !have_bracket; i++) {
        double xr = xi_w + (0.95 - xi_w) * i / n;
        double f = abs_resid(xr, xi_w, hs, hv, P);
        if (isnan(f)) continue;
        if (have_prev && ((prev_f > 0 && f <= 0) || (prev_f < 0 && f >= 0))) {
            blo = prev_x; bhi = xr; have_bracket = 1;
        }
        prev_x = xr; prev_f = f; have_prev = 1;
    }
    if (!have_bracket) return NAN;
    {
        double flo = abs_resid(blo, xi_w, hs, hv, P);
        double xr, r;
        int k;
        for (k = 0; k < 100; k++) {
            double mid = 0.5 * (blo + bhi);
            double fm = abs_resid(mid, xi_w, hs, hv, P);
            if ((flo > 0) == (fm > 0)) { blo = mid; flo = fm; }
            else bhi = mid;
        }
        xr = 0.5 * (blo + bhi);
        r = (xr - xi_w) / (1.0 - xr);
        if (Tout_C) *Tout_C = bubble_t_bar(P, xr);
        if (xi_r) *xi_r = xr;
        return ms * r;
    }
}

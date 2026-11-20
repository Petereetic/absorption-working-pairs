/* H2O-LiCl working pair: properties of aqueous lithium chloride.
 * Source: Conde-Petit, Int. J. Thermal Sciences 43 (2004) 367-382,
 * LiCl branch only (the CaCl2 dilution-enthalpy branch of the same
 * paper does not reproduce its own Fig. 27 and is excluded).
 * Line-by-line mirror of h2o_licl.py in the same directory.
 * Conventions: xi = LiCl mass fraction, T in degC, P in MPa,
 * h kJ/kg, rho kg/m3, eta Pa s, sigma N/m, lambda W/(m K),
 * cp kJ/(kg K), dh_d kJ/kg_H2O.  NAN outside the stated ranges.
 * Enthalpy datum and construction: see h2o_licl.py header /
 * the formula notes (hsol = integral of cp_sol from 0 degC plus
 * the 25 degC excess term e25 built from dh_d). */
#include <math.h>

static const double HL_TC = 647.096, HL_PC = 22.064;
static const double HL_M = 42.394;
static const double HL_A_SW[6] = {-7.858230, 1.839910, -11.781100,
                                  22.670500, -15.939300, 1.775160};
static const double HL_B_RHO[6] = {1.9937718430, 1.0985211604, -0.5094492996,
                                   -1.7619124270, -44.9005480267, -723692.2618632};
static const double HL_PI[10] = {0.28, 4.30, 0.60, 0.21, 5.10,
                                 0.49, 0.362, -4.75, -0.40, 0.03};
static const double HL_RHO[4] = {1.0, 0.540966, -0.303792, 0.100791};
static const double HL_SIG[5] = {2.757115, -12.011299, 14.751818,
                                 2.443204, -3.147739};
static const double HL_ETA[4] = {0.090481, 1.390262, 0.675875, -0.583517};
static const double HL_TAB10[8] = {1.43980, -1.24317, -0.12070, 0.12825,
                                   0.62934, 58.5225, -105.6343, 47.7948};
static const double HL_HD[6] = {0.845, -1.965, -2.265, 0.6, 169.105, 457.850};
static const double HL_CP_W[16] = {4.217, 4.192, 4.182, 4.178, 4.178, 4.179,
                                   4.181, 4.186, 4.193, 4.204, 4.216, 4.229,
                                   4.242, 4.254, 4.267, 4.281};
static const double HL_LAM_W[16] = {0.561, 0.580, 0.598, 0.615, 0.631, 0.644,
                                    0.654, 0.663, 0.670, 0.676, 0.679, 0.683,
                                    0.685, 0.686, 0.685, 0.683};
/* SLE branches (Table 1): A0, A1, A2, exponent; order: ice, 5H2O,
 * 3H2O, 2H2O, H2O, anhydrous */
static const double HL_SLE[6][4] = {
    {0.422088, -0.090410, -2.936350, 2.5},
    {-0.005340, 2.015890, -3.114590, 2.0},
    {-0.560360, 4.723080, -5.811050, 2.0},
    {-0.315220, 2.882480, -2.624330, 2.0},
    {-1.312310, 6.177670, -5.034790, 2.0},
    {-1.356800, 3.448540, 0.0, 2.0}};

static double hl_tab(const double *tab, double T_C)
{
    int i;
    double f;
    if (T_C <= 0.0) return tab[0];
    if (T_C >= 150.0) return tab[15];
    i = (int)(T_C / 10.0);
    f = (T_C - 10.0 * i) / 10.0;
    return tab[i] * (1.0 - f) + tab[i + 1] * f;
}

double H2OLiCl_PrefWater(double T_C)
{
    double T, tau, s;
    if (T_C < -50.0 || T_C > 300.0) return NAN;
    T = T_C + 273.15;
    tau = 1.0 - T / HL_TC;
    s = HL_A_SW[0] * tau + HL_A_SW[1] * pow(tau, 1.5)
        + HL_A_SW[2] * pow(tau, 3.0) + HL_A_SW[3] * pow(tau, 3.5)
        + HL_A_SW[4] * pow(tau, 4.0) + HL_A_SW[5] * pow(tau, 7.5);
    return HL_PC * exp(s / (1.0 - tau));
}

double H2OLiCl_TsatWater(double P_MPa)
{
    double lo = -50.0, hi = 300.0, mid;
    int k;
    if (P_MPa <= 0.0) return NAN;
    if (!(H2OLiCl_PrefWater(lo) <= P_MPa
          && P_MPa <= H2OLiCl_PrefWater(hi))) return NAN;
    for (k = 0; k < 100; k++) {
        mid = 0.5 * (lo + hi);
        if (H2OLiCl_PrefWater(mid) < P_MPa) lo = mid; else hi = mid;
    }
    return 0.5 * (lo + hi);
}

double H2OLiCl_RhoWater(double T_C)
{
    double tau;
    if (T_C < -40.0 || T_C > 150.0) return NAN;
    tau = 1.0 - (T_C + 273.15) / HL_TC;
    return 322.0 * (1.0 + HL_B_RHO[0] * pow(tau, 1.0 / 3.0)
                    + HL_B_RHO[1] * pow(tau, 2.0 / 3.0)
                    + HL_B_RHO[2] * pow(tau, 5.0 / 3.0)
                    + HL_B_RHO[3] * pow(tau, 16.0 / 3.0)
                    + HL_B_RHO[4] * pow(tau, 43.0 / 3.0)
                    + HL_B_RHO[5] * pow(tau, 110.0 / 3.0));
}

double H2OLiCl_CpWater(double T_C)
{
    if (T_C < 0.0 || T_C > 150.0) return NAN;
    return hl_tab(HL_CP_W, T_C);
}

double H2OLiCl_SigmaWater(double T_C)
{
    double th;
    if (T_C < -40.0 || T_C > 150.0) return NAN;
    th = (T_C + 273.15) / HL_TC;
    return 235.8e-3 * (1.0 - 0.625 * (1.0 - th)) * pow(1.0 - th, 1.256);
}

double H2OLiCl_EtaWater(double T_C)
{
    if (T_C < 0.0 || T_C > 150.0) return NAN;
    return 2.414e-5 * pow(10.0, 247.8 / (T_C + 273.15 - 140.0));
}

double H2OLiCl_LambdaWater(double T_C)
{
    double th;
    if (T_C < -20.0 || T_C > 150.0) return NAN;
    if (T_C >= 20.0) return hl_tab(HL_LAM_W, T_C);
    th = (T_C + 273.15) / HL_TC;
    return hl_tab(HL_LAM_W, 20.0) * (0.208496 + 1.747278 * th);
}

double H2OLiCl_PiFactor(double xi, double T_C)
{
    double th, A, B, f, pi25;
    if (xi < 0.0 || xi > 0.56 || T_C < -40.0 || T_C > 150.0) return NAN;
    th = (T_C + 273.15) / HL_TC;
    A = 2.0 - pow(1.0 + pow(xi / HL_PI[0], HL_PI[1]), HL_PI[2]);
    B = pow(1.0 + pow(xi / HL_PI[3], HL_PI[4]), HL_PI[5]) - 1.0;
    f = A + B * th;
    if (xi == 0.0)
        pi25 = 1.0 - HL_PI[9] * exp(-0.01 / 0.005);
    else
        pi25 = 1.0 - pow(1.0 + pow(xi / HL_PI[6], HL_PI[7]), HL_PI[8])
               - HL_PI[9] * exp(-((xi - 0.1) * (xi - 0.1)) / 0.005);
    return pi25 * f;
}

double H2OLiCl_Psol(double T_C, double xi)
{
    double pi = H2OLiCl_PiFactor(xi, T_C);
    if (isnan(pi)) return NAN;
    return pi * H2OLiCl_PrefWater(T_C);
}

double H2OLiCl_BubbleT(double P_MPa, double xi)
{
    double lo = -40.0, hi = 150.0, mid, plo, phi;
    int k;
    plo = H2OLiCl_Psol(lo, xi);
    phi = H2OLiCl_Psol(hi, xi);
    if (isnan(plo) || isnan(phi) || P_MPa < plo || P_MPa > phi) return NAN;
    for (k = 0; k < 80; k++) {
        mid = 0.5 * (lo + hi);
        if (H2OLiCl_Psol(mid, xi) < P_MPa) lo = mid; else hi = mid;
    }
    return 0.5 * (lo + hi);
}

double H2OLiCl_TdewByTsolXi(double T_C, double xi)
{
    double P = H2OLiCl_Psol(T_C, xi);
    if (isnan(P)) return NAN;
    return H2OLiCl_TsatWater(P);
}

double H2OLiCl_XiByTsolTdew(double Tsol_C, double Tdew_C)
{
    double P, pmax, pmin, lo = 0.0, hi = 0.56, mid;
    int k;
    if (Tsol_C < -40.0 || Tsol_C > 150.0) return NAN;
    P = H2OLiCl_PrefWater(Tdew_C);
    if (isnan(P)) return NAN;
    pmax = H2OLiCl_Psol(Tsol_C, 0.0);
    pmin = H2OLiCl_Psol(Tsol_C, 0.56);
    if (isnan(pmax) || isnan(pmin) || P < pmin || P > pmax) return NAN;
    for (k = 0; k < 80; k++) {
        mid = 0.5 * (lo + hi);
        if (H2OLiCl_Psol(Tsol_C, mid) > P) lo = mid; else hi = mid;
    }
    return 0.5 * (lo + hi);
}

double H2OLiCl_RhoSol(double T_C, double xi)
{
    double rw, z, s = 0.0, zk = 1.0;
    int i;
    if (xi < 0.0 || xi > 0.56 || T_C < -40.0 || T_C > 150.0) return NAN;
    rw = H2OLiCl_RhoWater(T_C);
    if (isnan(rw)) return NAN;
    z = xi / (1.0 - xi);
    for (i = 0; i < 4; i++) {
        if (i > 0) zk *= z;
        s += HL_RHO[i] * zk;
    }
    return rw * s;
}

double H2OLiCl_SigmaSol(double T_C, double xi)
{
    double sw, th, ratio;
    if (xi < 0.0 || xi > 0.56 || T_C < -40.0 || T_C > 150.0) return NAN;
    sw = H2OLiCl_SigmaWater(T_C);
    if (isnan(sw)) return NAN;
    th = (T_C + 273.15) / HL_TC;
    ratio = 1.0 + HL_SIG[0] * xi + HL_SIG[1] * xi * th
            + HL_SIG[2] * xi * th * th + HL_SIG[3] * xi * xi
            + HL_SIG[4] * xi * xi * xi;
    return sw * ratio;
}

double H2OLiCl_EtaSol(double T_C, double xi)
{
    double ew, th, zeta;
    if (xi < 0.0 || xi > 0.56 || T_C < 0.0 || T_C > 150.0) return NAN;
    ew = H2OLiCl_EtaWater(T_C);
    if (isnan(ew)) return NAN;
    th = (T_C + 273.15) / HL_TC;
    zeta = xi / pow(1.0 - xi, 1.0 / 0.6);
    return ew * exp(HL_ETA[0] * pow(zeta, 3.6) + HL_ETA[1] * zeta
                    + HL_ETA[2] * zeta / th + HL_ETA[3] * zeta * zeta);
}

double H2OLiCl_LambdaSol(double T_C, double xi)
{
    double lw, rs, zeta_eq;
    if (xi < 0.0 || xi > 0.56 || T_C < -20.0 || T_C > 150.0) return NAN;
    lw = H2OLiCl_LambdaWater(T_C);
    rs = H2OLiCl_RhoSol(T_C, xi);
    if (isnan(lw) || isnan(rs)) return NAN;
    zeta_eq = xi * rs / HL_M;
    return lw - (10.8958e-3 - 11.7882e-3 * xi) * zeta_eq;
}

static double hl_cp_f1(double xi)
{
    if (xi > 0.31) return HL_TAB10[3] + HL_TAB10[4] * xi;
    return HL_TAB10[0] * xi + HL_TAB10[1] * xi * xi
           + HL_TAB10[2] * xi * xi * xi;
}

static double hl_cp_f2(double T_C)
{
    double th = (T_C + 273.15) / 228.0 - 1.0;
    return HL_TAB10[5] * pow(th, 0.02) + HL_TAB10[6] * pow(th, 0.04)
           + HL_TAB10[7] * pow(th, 0.06);
}

double H2OLiCl_CpSol(double T_C, double xi)
{
    double cw;
    if (xi < 0.0 || xi > 0.56 || T_C < 0.0 || T_C > 150.0) return NAN;
    cw = H2OLiCl_CpWater(T_C);
    if (isnan(cw)) return NAN;
    return cw * (1.0 - hl_cp_f1(xi) * hl_cp_f2(T_C));
}

double H2OLiCl_DhD(double xi, double T_C)
{
    double th, dh0, zeta;
    if (xi < 0.0 || xi > 0.55 || T_C < 0.0 || T_C > 150.0) return NAN;
    if (xi == 0.0) return 0.0;
    th = (T_C + 273.15) / 228.0 - 1.0;
    dh0 = HL_HD[4] + HL_HD[5] * th;
    zeta = xi / (HL_HD[3] - xi);
    return dh0 * pow(1.0 + pow(zeta / HL_HD[0], HL_HD[1]), HL_HD[2]);
}

static double hl_g(double s, double Tref_C)
{
    double d;
    if (s <= 0.0) return 0.0;
    d = H2OLiCl_DhD(s, Tref_C);
    if (isnan(d)) return NAN;
    return d / (s * s);
}

double H2OLiCl_HmixExcess(double xi, double Tref_C)
{
    int n = 400, i;
    double h, total;
    if (xi < 0.0 || xi > 0.55) return NAN;
    if (xi == 0.0) return 0.0;
    h = xi / n;
    total = hl_g(0.0, Tref_C) + hl_g(xi, Tref_C);
    for (i = 1; i < n; i++)
        total += ((i % 2 == 1) ? 4.0 : 2.0) * hl_g(i * h, Tref_C);
    return xi * total * h / 3.0;
}

double H2OLiCl_Hsol(double T_C, double xi)
{
    int n = 200, i;
    double e, h, total, c0, cT;
    if (xi < 0.0 || xi > 0.55 || T_C < 0.0 || T_C > 150.0) return NAN;
    e = H2OLiCl_HmixExcess(xi, 25.0);
    if (isnan(e)) return NAN;
    if (T_C == 0.0) return e;
    h = T_C / n;
    c0 = H2OLiCl_CpSol(0.0, xi);
    cT = H2OLiCl_CpSol(T_C, xi);
    if (isnan(c0) || isnan(cT)) return NAN;
    total = c0 + cT;
    for (i = 1; i < n; i++)
        total += ((i % 2 == 1) ? 4.0 : 2.0) * H2OLiCl_CpSol(i * h, xi);
    return total * h / 3.0 + e;
}

double H2OLiCl_TsolByHsol(double h, double xi)
{
    double prev_T = 0.0, prev_h = 0.0, lo = 0.0, hi = 0.0, mid;
    int have_prev = 0, have_bracket = 0, k;
    if (xi < 0.0 || xi > 0.55) return NAN;
    for (k = 0; k <= 30 && !have_bracket; k++) {
        double T = 5.0 * k, hv = H2OLiCl_Hsol(T, xi);
        if (isnan(hv)) continue;
        if (have_prev && prev_h <= h && h <= hv) {
            lo = prev_T; hi = T; have_bracket = 1;
        }
        prev_T = T; prev_h = hv; have_prev = 1;
    }
    if (!have_bracket) return NAN;
    for (k = 0; k < 80; k++) {
        mid = 0.5 * (lo + hi);
        if (H2OLiCl_Hsol(mid, xi) < h) lo = mid; else hi = mid;
    }
    return 0.5 * (lo + hi);
}

double H2OLiCl_SleT(double xi, int branch)
{
    if (xi < 0.0 || xi > 0.65 || branch < 0 || branch > 5) return NAN;
    return (HL_SLE[branch][0] + HL_SLE[branch][1] * xi
            + HL_SLE[branch][2] * pow(xi, HL_SLE[branch][3])) * HL_TC
           - 273.15;
}

double H2OLiCl_CrystallizationT(double xi)
{
    double best, v;
    int b;
    if (xi < 0.0 || xi > 0.65) return NAN;
    best = H2OLiCl_SleT(xi, 0);
    for (b = 1; b < 6; b++) {
        v = H2OLiCl_SleT(xi, b);
        if (v > best) best = v;
    }
    return best;
}

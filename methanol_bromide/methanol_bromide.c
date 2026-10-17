/* Thermodynamic correlations for methanol / (2LiBr-ZnBr2) (C implementation, pointwise identical to methanol_bromide.py)
 * Source: S. El-Shamarka, PhD thesis, Cranfield Institute of Technology, 1981.
 * System: the salt ratio is fixed at LiBr:ZnBr2 = 2:1 (molar); w is the methanol mass fraction; the salt is non-volatile.
 *   Eq. (3.1) Bubble-point pressure: log10 P[mbar] = C1(w) + C2(w)·(1000/T[K] - 2.3)
 *           C1 and C2 are the 8 node values of Table 3.3; between nodes, shape-preserving PCHIP interpolation.
 *           The -C2 of Table 3.3 at w=28.0% (2.7278) breaks monotonicity (2.8197 at 30.1%);
 *           printed as in the original table; PCHIP has zero slope there and produces no overshoot.
 *   Eq. (3.4) Specific heat: Cp = A + B·t[°C], A = 0.652 + 2.139w - 2.077w^2,
 *           B = -0.000205 + 0.00928w - 0.0101w^2.
 *           Sign of the last term: in the original formula on p.86 it is an overprinted glyph; the restatement in Appendix A prints "-", and taking "-"
 *           gives a max deviation of only 0.7% against the measured specific heats of Table 3.7 of the thesis (taking "+" gives 6%~14%); so "-" is taken.
 *   Appendix A enthalpy of vaporisation H' (including the heat of mixing): H' = A + B·w + C·w^2, where A, B, C are
 *           quadratics in T (see below); T is in kelvin (never use °C); valid only for w=0.25~0.356.
 * The density and viscosity (mb_rho_iedema / mb_eta_iedema) are from another source, unrelated to the above:
 *   P. D. Iedema, PhD thesis, TU Delft, 1984 (same system, LiBr/ZnBr2-methanol).
 *   Density (Table 2.7.2.2.2): rho = [rho25(w) + rho'(w)·(t-25)]·(1 + 0.32·w_H),
 *           rho25 and rho' are cubics in w; t in °C; w is the total solvent mass fraction
 *           (methanol + water; for a dry solution it is the methanol mass fraction), w_H is the water mass fraction.
 *           Valid w=0.28~0.42, t=-10~140 °C; the author states a mean deviation of 0.13%.
 *   Viscosity (Table 2.7.3): ln eta = eta0(w) + etaT(w)/T, eta in Pa·s, T in K,
 *           eta0 and etaT are cubics in w. Valid w=0.28~1.0, t=20~120 °C.
 *           In the original table the last term of etaT is printed as w^4 and the coefficient subscript is mislabelled; ruled by 9 measured points,
 *           the w^3 reading is taken (mean deviation 2.8%, matching the author's own claim; the w^4 reading deviates by 36%).
 *   Note: El-Shamarka's own density Eq. (4.10) and viscosity Eq. (4.11) are still unverified; this file
 *   does not implement them; do not confuse them with the Iedema correlations above (see the formula notes file).
 * Pressure unit (library-wide unification of 2026-10-14): public functions return/accept MPa; internal native
 * computation is in bar (private function names carry the suffix _bar); public functions only scale at the boundary
 * (MPa = bar x0.1; MPa inputs x10 back to bar). The private meoh_pref_bar /
 * meoh_tsat_bar are natively in bar, so name and substance agree.
 * Reference state (a convention of this document; the thesis defines no absolute datum):
 *   hsol(0°C, any w) = 100 kJ/kg; hsol = 100 + A·t + B·t^2/2;
 *   hgas = hsol + H'.
 * Build: gcc -O2 -Wall -Wextra -o methanol_bromide methanol_bromide.c -lm
 * main() outputs a verification grid (CSV) for pointwise comparison against the Python version.
 */
#include <stdio.h>
#include <math.h>

/* Table 3.3 (p.74): node compositions and C1, C2 (C2 takes negative values) */
static const double W_NODES[8] = {0.243, 0.250, 0.262, 0.280, 0.301, 0.356, 0.403, 0.509};
static const double C1_NODES[8] = {2.6712, 2.8572, 2.9758, 3.0535, 3.3146, 3.4604, 3.7770, 4.0494};
static const double C2_NODES[8] = {-3.0602, -3.0344, -2.9531, -2.7278, -2.8197, -2.6219, -2.4256, -2.0194};

static double pchip_end_slope(double h0, double h1, double d0, double d1)
{
    double m = ((2.0 * h0 + h1) * d0 - h0 * d1) / (h0 + h1);
    if (m * d0 <= 0.0) return 0.0;
    if (d0 * d1 < 0.0 && fabs(m) > fabs(3.0 * d0)) return 3.0 * d0;
    return m;
}

/* Fritsch-Carlson PCHIP, same algorithm as the Python reference implementation */
static double pchip_eval(const double *xs, const double *ys, double x)
{
    const int n = 8;
    double h[7], d[7], m[8];
    int i;
    for (i = 0; i < n - 1; i++) {
        h[i] = xs[i + 1] - xs[i];
        d[i] = (ys[i + 1] - ys[i]) / h[i];
    }
    for (i = 1; i < n - 1; i++) {
        if (d[i - 1] * d[i] <= 0.0) {
            m[i] = 0.0;
        } else {
            double w1 = 2.0 * h[i] + h[i - 1];
            double w2 = h[i] + 2.0 * h[i - 1];
            m[i] = (w1 + w2) / (w1 / d[i - 1] + w2 / d[i]);
        }
    }
    m[0] = pchip_end_slope(h[0], h[1], d[0], d[1]);
    m[n - 1] = pchip_end_slope(h[n - 2], h[n - 3], d[n - 2], d[n - 3]);
    if (x <= xs[0]) {
        i = 0;
    } else if (x >= xs[n - 1]) {
        i = n - 2;
    } else {
        int lo = 0, hi = n - 1;
        while (hi - lo > 1) {
            int mid = (lo + hi) / 2;
            if (xs[mid] <= x) lo = mid; else hi = mid;
        }
        i = lo;
    }
    {
        double s = (x - xs[i]) / h[i];
        double s2 = s * s, s3 = s2 * s;
        return (2.0 * s3 - 3.0 * s2 + 1.0) * ys[i]
             + h[i] * (s3 - 2.0 * s2 + s) * m[i]
             + (3.0 * s2 - 2.0 * s3) * ys[i + 1]
             + h[i] * (s3 - s2) * m[i + 1];
    }
}

static void cp_AB(double w, double *A, double *B)
{
    *A = 0.652 + 2.139 * w - 2.077 * w * w;
    *B = -0.000205 + 0.00928 * w - 0.0101 * w * w;
}

/* Eq. (3.1) native value (private): bubble-point pressure, bar */
static double psol_TW_bar(double T_K, double w)
{
    double log10p_mbar = pchip_eval(W_NODES, C1_NODES, w)
                       + pchip_eval(W_NODES, C2_NODES, w) * (1000.0 / T_K - 2.3);
    return pow(10.0, log10p_mbar) / 1000.0;
}

/* Eq. (3.1): bubble-point pressure, MPa */
double mb_psol_TW(double T_K, double w)
{
    return psol_TW_bar(T_K, w) * 0.1;
}

/* Eq. (3.1) analytic inverse, native value (private): bubble-point temperature, K; P_bar in bar */
static double T_bubble_PW_bar(double P_bar, double w)
{
    double log10p_mbar = log10(P_bar * 1000.0);
    return 1000.0 / ((log10p_mbar - pchip_eval(W_NODES, C1_NODES, w))
                     / pchip_eval(W_NODES, C2_NODES, w) + 2.3);
}

/* Eq. (3.1) analytic inverse: bubble-point temperature, K; P_MPa in MPa */
double mb_T_bubble_PW(double P_MPa, double w)
{
    return T_bubble_PW_bar(P_MPa * 10.0, w);
}

/* Pure-methanol saturation pressure (private helper, native bar; same constants as _meoh_pref_bar of the Python version):
 * Antoine fit to the table in Appendix A of El-Shamarka (see the header of methanol_bromide.py):
 * log10 P[mmHg] = 8.885298 - 2070.3714/(T[K] + 6.3818), returns bar */
static double meoh_pref_bar(double T_K)
{
    return pow(10.0, 8.885298 - 2070.3714 / (T_K + 6.3818)) * 1.3332239e-3;
}

/* Solve the methanol mass fraction w back from the dew-point temperature and the solution temperature:
 * the dew point fixes the pressure P = meoh_pref_bar(Tdew_K) (internal native value in bar; the salt is non-volatile,
 * the vapour phase is pure methanol); then 80 bisection steps invert psol_TW_bar(Tsol_K, w) = P,
 * with the bracket taken as the bubble-point function's valid concentration domain w = 0.243~0.509.
 * Returns NAN when there is no root (e.g. the solution temperature clearly below the dew-point temperature). */
double mb_XiByTsolTdew(double Tsol_K, double Tdew_K)
{
    double P = meoh_pref_bar(Tdew_K);
    double lo = 0.243, hi = 0.509, mid;
    int k;
    if (P < psol_TW_bar(Tsol_K, lo) || P > psol_TW_bar(Tsol_K, hi))
        return NAN;
    for (k = 0; k < 80; k++) {
        mid = 0.5 * (lo + hi);
        if (psol_TW_bar(Tsol_K, mid) < P) lo = mid; else hi = mid;
    }
    return 0.5 * (lo + hi);
}


/* Pure-methanol saturation temperature [K] (private helper, native bar): analytic inverse of meoh_pref_bar,
 * same formula as _meoh_Tsat_bar of the Python version. */
static double meoh_tsat_bar(double P_bar)
{
    return 2070.3714 / (8.885298 - log10(P_bar / 1.3332239e-3)) - 6.3818;
}

/* Dew-point temperature [K] of the solution at (T_K, w) (library-wide TdewByTsolXi convention):
 * Tdew = meoh_tsat_bar(psol_TW_bar(T_K, w)) (internally via the native-bar private functions;
 * the public convention is meoh_Tsat_bar(psol_TW(...)), MPa), evaluating the solution surface pressure Psol with this module's
 * own pure-methanol line. The salt is non-volatile; the vapour phase is pure methanol. */
double mb_TdewFromTsolW(double T_K, double w)
{
    return meoh_tsat_bar(psol_TW_bar(T_K, w));
}

double mb_hsol(double T_K, double w);  /* forward: defined below */
/* Solve the solution temperature [K] back from the solution specific enthalpy h [kJ/kg] and methanol mass fraction w:
 * mb_hsol increases monotonically with T at fixed w; inverted by 100 bisection steps,
 * with the solution bracket T in [233.15, 423.15] K. Returns NAN when there is no root. */
double mb_TsolByHsol(double h, double w)
{
    double lo = 233.15, hi = 423.15, mid;
    int k;
    if (h < mb_hsol(lo, w) || h > mb_hsol(hi, w)) return NAN;
    for (k = 0; k < 100; k++) {
        mid = 0.5 * (lo + hi);
        if (mb_hsol(mid, w) < h) lo = mid; else hi = mid;
    }
    return 0.5 * (lo + hi);
}

/* Eq. (3.4): solution specific heat, kJ/(kg·K) */
double mb_cp(double T_K, double w)
{
    double A, B;
    cp_AB(w, &A, &B);
    return A + B * (T_K - 273.15);
}

/* Appendix A: enthalpy of vaporisation H' (including the heat of mixing), kJ/kg; T_K in kelvin; only w=0.25~0.356 */
double mb_h_prime(double T_K, double w)
{
    double A = 2202.6 + 9.24 * T_K - 0.0218 * T_K * T_K;
    double B = -(4417.8 + 15.53 * T_K - 0.0392 * T_K * T_K);
    double C = 3570.0 + 10.81 * T_K - 0.0294 * T_K * T_K;
    return A + B * w + C * w * w;
}

/* Solution specific enthalpy, kJ/kg; reference-state convention hsol(0°C) = 100 kJ/kg */
double mb_hsol(double T_K, double w)
{
    double A, B, t = T_K - 273.15;
    cp_AB(w, &A, &B);
    return 100.0 + A * t + B * t * t / 2.0;
}

/* Vapour-phase specific enthalpy, kJ/kg: hgas = hsol + H' */
double mb_hgas(double T_K, double w)
{
    return mb_hsol(T_K, w) + mb_h_prime(T_K, w);
}

/* Iedema Table 2.7.2.2.2: density, kg/m3. T_K in kelvin (converted internally to t[°C]);
 * w is the total solvent mass fraction w_t (methanol + water), w_H is the water mass fraction;
 * for a dry solution (w_H=0), w_t is the methanol mass fraction. Valid w=0.28~0.42, t=-10~140 °C */
double mb_rho_iedema(double T_K, double w, double w_H)
{
    double t = T_K - 273.15;
    double rho25 = 3026.745 - 5369.24 * w + 4082.056 * w * w + 103.8639 * w * w * w;
    double drho = -0.0997537 - 11.77377 * w + 42.24796 * w * w - 44.70839 * w * w * w;
    return (rho25 + drho * (t - 25.0)) * (1.0 + 0.32 * w_H);
}

/* Iedema Table 2.7.3: dynamic viscosity, Pa·s; ln eta = eta0(w) + etaT(w)/T_K.
 * The last term takes the w^3 reading (ruling basis in the header). Valid w=0.28~1.0, t=20~120 °C */
double mb_eta_iedema(double T_K, double w)
{
    double eta0 = -18.29756 + 26.2373 * w - 33.51444 * w * w + 13.86405 * w * w * w;
    double etaT = 5481.757 - 11371.61 * w + 10873.4 * w * w - 3718.145 * w * w * w;
    return exp(eta0 + etaT / T_K);
}

int main(void)
{
    static const double TS[7] = {283.15, 303.15, 323.15, 353.15, 393.15, 433.15, 466.15};
    static const double WS[9] = {0.243, 0.250, 0.262, 0.280, 0.301, 0.330, 0.356, 0.403, 0.509};
    static const double PS[5] = {0.010, 0.039997, 0.060, 0.100, 0.130};  /* MPa */
    int i, j;
    for (i = 0; i < 7; i++)
        for (j = 0; j < 9; j++)
            printf("grid,%.2f,%.3f,%.17g,%.17g,%.17g,%.17g,%.17g\n",
                   TS[i], WS[j],
                   mb_psol_TW(TS[i], WS[j]), mb_cp(TS[i], WS[j]),
                   mb_h_prime(TS[i], WS[j]), mb_hsol(TS[i], WS[j]),
                   mb_hgas(TS[i], WS[j]));
    for (i = 0; i < 5; i++)
        for (j = 0; j < 9; j++)
            printf("inv,%.6f,%.3f,%.17g\n", PS[i], WS[j], mb_T_bubble_PW(PS[i], WS[j]));
    return 0;
}

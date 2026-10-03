/*
 * libr_water.c -- 溴化锂水溶液物性参考实现 (C, Patterson + Chua 混合)
 * =====================================================================
 * Patterson, M.R. & Perez-Blanco, H. (1988)
 * "Numerical fits of the properties of lithium-bromide water solutions",
 * ASHRAE Transactions 94(2), pp. 2059-2077.
 * Chua, H.T. et al. (2000)
 * "Improved thermodynamic property fields of LiBr-H2O solution",
 * Int. J. Refrigeration 23, 412-429 (Dühring 蒸气压 + 密度)。
 * 注: Dühring 限 x≤60% (Table 1 <x-60> 项按印刷值发散, 60-75% 无法重建);
 *     B_12 取 -3.12628E-16 (原文漏印负号, 经 Fig.2 验证)。
 *
 * 与同目录 libr_water.py 逐行对应。gcc -O2 -Wall -Wextra 零警告。
 *
 * 约定: X = LiBr 重量百分数(数字,如 50); T = °C。
 * 返回 SI: h kJ/kg, p Pa, lambda W/(m K), eta Pa s,
 *           rho kg/m^3, sigma N/m; t_dew/crystallization_T 为 °C。
 *
 * 范围/结晶检查: Python 版 raise ValueError; C 版返回 NAN
 * (范围外或结晶区内), 调用方需用 isnan() 检查。
 */
#include <math.h>

/* ------------------------------------------------------------------ */
/* 结晶边界表                                                          */
/* ------------------------------------------------------------------ */
static const double XN[7]    = {57.5, 62.5, 62.5, 67.5, 67.5, 100.0, 100.0};
static const double TN[7]    = {0.0, 10.0, 40.0, 50.0, 90.0, 100.0, 180.0};
static const double XUNKN[4] = {0.0, 37.5, 51.5, 60.5};
static const double TUNKN[4] = {126.7, 137.8, 160.0, 182.2};
/* TCON 按原文照录 °F 数值 */
static const double TUNKN_TCON[4] = {260.0, 280.0, 320.0, 360.0};

/* 返回 0 = 通过, 非 0 = 拒绝(结晶区/未知区) */
static int check_region(double X, double T, int check_unknown,
                        const double *tunkn)
{
    int n;
    double xstar;
    int found = 0;

    for (n = 1; n < 7; n++) {
        if (T > TN[n])
            continue;
        if (XN[n] == XN[n - 1])
            xstar = XN[n];
        else
            xstar = XN[n - 1] + (T - TN[n - 1]) / (TN[n] - TN[n - 1])
                    * (XN[n] - XN[n - 1]);
        found = 1;
        if (X >= xstar)
            return 1;               /* 结晶区 */
        break;
    }
    if (found && !check_unknown)
        return 0;                   /* 冰点通过 → 直接计算 */
    /* 未知区检查 (T>180 时亦至此) */
    for (n = 1; n < 4; n++) {
        if (T > tunkn[n])
            continue;
        if (XUNKN[n] == XUNKN[n - 1])
            xstar = XUNKN[n];
        else
            xstar = XUNKN[n - 1] + (T - tunkn[n - 1]) / (tunkn[n] - tunkn[n - 1])
                    * (XUNKN[n] - XUNKN[n - 1]);
        return (X <= xstar) ? 2 : 0; /* 未知区 or 通过 */
    }
    return 2;                       /* T > TUNKN[3] → 未知区 */
}

static int range_check(double X, double T,
                       double x_lo, double x_hi, double t_lo, double t_hi)
{
    return (X < x_lo || X > x_hi || T < t_lo || T > t_hi);
}

/* 统一多项式 */
static double poly(double X, double T, const double *A, int kup)
{
    double s = 0.0, xk = 1.0;
    int i;
    for (i = 0; i < kup; i++) {
        if (i > 0)
            xk *= X;
        s += xk * (A[i] + T * (A[i + kup] + T * A[i + 2 * kup]));
    }
    return s;
}

/* ------------------------------------------------------------------ */
/* Patterson 系数表                                                    */
/* ------------------------------------------------------------------ */
static const double A_H[18] = {
    1.134125e+00, -4.800450e-01, -2.161438e-03, 2.336235e-04,
    -1.188679e-05, 2.291532e-07, 4.124891e+00, -7.643903e-02,
    2.589577e-03, -9.500522e-05, 1.708026e-06, -1.102363e-08,
    5.743693e-04, 5.870921e-05, -7.375319e-06, 3.277592e-07,
    -6.062304e-09, 3.901897e-11,
};
static const double A_TDEW[18] = {
    -1.313448e-01, 1.820914e-01, -5.177356e-02, 2.827426e-03,
    -6.380541e-05, 4.340498e-07, 9.967944e-01, 1.778069e-03,
    -2.215597e-04, 5.913618e-06, -7.308556e-08, 2.788472e-10,
    1.978788e-05, -1.779481e-05, 2.002427e-06, -7.667546e-08,
    1.201525e-09, -6.641716e-12,
};
static const double A_TC[15] = {
    4.815196e-01, -2.217277e-03, -1.994141e-05, 3.727255e-07,
    -2.489886e-09, 1.858174e-03, 9.614755e-06, -1.139291e-06,
    2.107608e-08, -1.330532e-10, -7.923126e-06, -1.869392e-07,
    1.408951e-08, -2.740806e-10, 1.810818e-12,
};
static const double A_VIS[18] = {
    1.488747e+00, 1.143975e-01, -1.278729e-02, 6.999985e-04,
    -1.638074e-05, 1.456348e-07, -4.164814e-02, 9.636832e-04,
    -5.981025e-05, -1.282435e-07, 5.703002e-08, -9.842266e-10,
    3.404030e-04, -2.794515e-05, 2.580301e-06, -9.737750e-08,
    1.585609e-09, -7.922925e-12,
};
static const double A_RHO[15] = {
    9.939006e-01, 1.046888e-02, -1.667939e-04, 5.332835e-06,
    -3.440005e-08, -5.631094e-04, 1.633541e-05, -1.110273e-06,
    2.882292e-08, -2.523579e-10, 1.392527e-06, -2.801009e-07,
    1.734979e-08, -4.232988e-10, 3.503024e-12,
};
static const double A_SIG[15] = {
    7.626234e+01, 4.583900e-01, -1.463071e-02, 3.834735e-04,
    -2.733854e-06, -1.507474e-01, -9.057263e-03, 4.459087e-04,
    -9.542318e-06, 6.610416e-08, -1.107075e-05, 7.238986e-05,
    -3.822731e-06, 8.077592e-08, -5.681625e-10,
};

/* ------------------------------------------------------------------ */
/* 公开函数 (Patterson)                                                */
/* ------------------------------------------------------------------ */
double h_libr(double X, double T)
{
    if (range_check(X, T, 0, 70, 0, 180))
        return NAN;
    if (check_region(X, T, 1, TUNKN))
        return NAN;
    return poly(X, T, A_H, 6);
}

static double tdew_poly(double X, double T)
{
    double TF = 9.0 / 5.0 * T + 32.0;
    return poly(X, TF, A_TDEW, 6);
}

double t_dew(double X, double T)
{
    if (range_check(X, T, 0, 70, 4.4, 182.2))
        return NAN;
    if (check_region(X, T, 0, TUNKN))
        return NAN;
    return 5.0 / 9.0 * (tdew_poly(X, T) - 32.0);
}

double p_sat(double X, double T)
{
    double tdew_f, TR;
    if (range_check(X, T, 0, 70, 4.4, 182.2))
        return NAN;
    if (check_region(X, T, 0, TUNKN))
        return NAN;
    tdew_f = tdew_poly(X, T);
    TR = tdew_f + 459.7;
    return pow(10.0, 6.21147 - 2886.373 / TR - 337269.46 / (TR * TR))
           * 6894.757;
}

double lambda_libr(double X, double T)
{
    if (range_check(X, T, 0, 70, 4.4, 182.2))
        return NAN;
    if (check_region(X, T, 0, TUNKN_TCON))
        return NAN;
    return poly(X, T, A_TC, 5) * 1.163;
}

double eta_libr(double X, double T)
{
    if (range_check(X, T, 5, 60, 0, 90))
        return NAN;
    if (check_region(X, T, 0, TUNKN))
        return NAN;
    return poly(X, T, A_VIS, 6) * 1e-3;
}

double rho_libr(double X, double T)
{
    if (range_check(X, T, 10, 60, 0, 100))
        return NAN;
    if (check_region(X, T, 0, TUNKN))
        return NAN;
    return poly(X, T, A_RHO, 5) * 1000.0;
}

double sigma_libr(double X, double T)
{
    if (range_check(X, T, 5, 60, 0, 60))
        return NAN;
    if (check_region(X, T, 0, TUNKN))
        return NAN;
    return poly(X, T, A_SIG, 5) * 1e-3;
}

double crystallization_T(double X)
{
    int n;
    double best = NAN, t;
    double x0, x1, t0, t1;
    if (X < 57.5)
        return NAN;
    if (X > 100.0)
        return NAN;
    for (n = 1; n < 7; n++) {
        x0 = XN[n - 1]; x1 = XN[n];
        t0 = TN[n - 1]; t1 = TN[n];
        if (x0 == x1) {
            if (X == x0 && (isnan(best) || t1 > best))
                best = t1;
        } else if (X >= (x0 < x1 ? x0 : x1) && X <= (x0 > x1 ? x0 : x1)) {
            t = t0 + (X - x0) / (x1 - x0) * (t1 - t0);
            if (isnan(best) || t > best)
                best = t;
        }
    }
    return best;
}

/* ------------------------------------------------------------------ */
/* Chua 2000: Dühring 蒸气压 (Table 1) + 密度 (Table 2)                */
/* 注记见 .py: B_12 取 -3.12628E-16 (原文漏负号); B_14 读 E-19;       */
/* A_10 读 E-15; <x-60> 项按印刷值发散, p_sat_chua 限 x≤60%。         */
/* ------------------------------------------------------------------ */
static const double DUHR_A[21] = {
    1.0,
    2.92242e-04, 1.05207e-04, 8.86101e-07, -2.71833e-06, 3.52718e-07,
    -2.03849e-08, 5.68810e-10, -4.32385e-12, -1.42122e-13, 2.37604e-15,
    3.96440e-17, -9.81319e-19, -7.91591e-21, 3.92677e-22, -4.04965e-24,
    1.41694e-26,
    6.51878e-03, -2.57030e-04, 2.43912e-05, -6.86236e-08,
};
static const double DUHR_B[21] = {
    0.0,
    5.22677e-02, -9.78477e-03, 7.82919e-03, -1.62913e-03, 1.64050e-04,
    -8.98817e-06, 2.62640e-07, -2.95400e-09, -3.23145e-11, 7.67888e-13,
    1.36662e-14, -3.12628e-16, -4.91441e-18, 1.87723e-19, -1.92463e-21,
    6.87629e-24,
    1.93956e+00, 8.22588e-02, -1.04537e-02, 4.09856e-04,
};
/* G[k][3] = G_{0,k},G_{1,k},G_{2,k}, k=1..5 */
static const double G_RHO[5][3] = {
    {9.99100e+02, -2.39865e-02, -3.90453e-03},
    {7.74931e+00, -1.28346e-02, -5.55855e-05},
    {5.36509e-03, 2.07232e-04, 1.09879e-05},
    {1.34988e-03, -9.08213e-06, -2.39834e-07},
    {-3.08671e-06, 9.94788e-08, 1.53514e-09},
};

/* 纯水 Psat: Wagner 方程 (IAPWS-95, 6 项) */
static double wagner_psat_water(double T_C)
{
    static const double a[6] = {-7.85951783, 1.84408259, -11.7866497,
                                22.6807411, -15.9618719, 1.80122502};
    static const double e[6] = {1.0, 1.5, 3.0, 3.5, 4.0, 7.5};
    double T = T_C + 273.15, theta = 1.0 - T / 647.096, s = 0.0;
    int i;
    for (i = 0; i < 6; i++)
        s += a[i] * pow(theta, e[i]);
    return 22.064e6 * exp((647.096 / T) * s);
}

double p_sat_chua(double X, double T)
{
    double AD = 0.0, BD = 0.0, xk = 1.0, Tdp_C;
    int i;
    if (X < 0 || X > 60 || T < 0 || T > 190)
        return NAN;
    for (i = 0; i < 17; i++) {
        if (i > 0)
            xk *= X;
        AD += DUHR_A[i] * xk;
        BD += DUHR_B[i] * xk;
    }
    Tdp_C = (T - BD) / AD;
    return wagner_psat_water(Tdp_C);
}

double rho_chua(double X, double T)
{
    double s = 0.0, xk = 1.0;
    int k;
    if (X < 0 || X > 70 || T < 0 || T > 200)
        return NAN;
    for (k = 0; k < 5; k++) {
        if (k > 0)
            xk *= X;
        s += xk * (G_RHO[k][0] + T * (G_RHO[k][1] + T * G_RHO[k][2]));
    }
    return s;
}

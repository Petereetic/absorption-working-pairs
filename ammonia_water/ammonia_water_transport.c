/*
 * ammonia_water_transport.c -- 输运物性参考实现 (C)
 * =================================================
 * M. Conde Engineering (2004)
 * "Thermophysical Properties of NH3 + H2O Solutions for the Industrial
 *  Design of Absorption Refrigeration Equipment", 第 5~15 章 + 附录 A/B/C。
 *
 * 与同目录 ammonia_water_transport.py 逐行对应,双精度计算。
 * gcc -O2 -Wall -Wextra 零警告编译。
 *
 * 约定:
 *   x : 液相氨摩尔分数 ; y : 气相氨摩尔分数 ; T : K
 *   返回 SI: cp kJ/(kg K), lambda W/(m K), eta Pa s,
 *           sigma N/m, rho kg/m^3, D m^2/s ; pc_sol 为 bar(书中原单位)
 *
 * 注意:
 *   附录 A 总式书中印刷为 λ̄0×λ̄1×λ̄2,系排印错误,实为加法
 *   (IAPWS 1998 原文、XSteam 实现、稀薄气体极限物理要求)。
 *   §13 正文"Appendix A"为笔误(水蒸气黏度实为附录 B);
 *   §12 正文"Appendix B"为笔误(水蒸气导热实为附录 A)。
 *   附录 C Δη 求和内印刷为 ρ,按 Fenghour 原文应为 ρ^i(i=2,3,4)。
 */
#include <math.h>

/* ------------------------------------------------------------------ */
/* 临界常数                                                           */
/* ------------------------------------------------------------------ */
#define T_C_NH3   405.4
#define T_C_H2O   647.14
#define RHO_C_NH3 225.0
#define RHO_C_H2O 322.0

/* §5 溶液临界温度/压力: x 的四次多项式 */
static const double A_TC[5] = {647.14, -199.822371, 109.035522,
                               -239.626217, 88.689691};
static const double B_PC[5] = {220.64, -37.923795, 36.424739,
                               -41.851597, -63.805617};

double tc_sol(double x)
{
    double s = 0.0, xp = 1.0;
    int i;
    for (i = 0; i < 5; i++) { s += A_TC[i] * xp; xp *= x; }
    return s;
}

double pc_sol(double x)
{
    double s = 0.0, xp = 1.0;
    int i;
    for (i = 0; i < 5; i++) { s += B_PC[i] * xp; xp *= x; }
    return s;
}

/* 对应状态温度 */
static void tstar(double T, double x, double *Ts_nh3, double *Ts_h2o)
{
    double theta = T / tc_sol(x);
    *Ts_nh3 = theta * T_C_NH3;
    *Ts_h2o = theta * T_C_H2O;
}

/* ------------------------------------------------------------------ */
/* 附录 A: IAPWS 水导热系数(1998 工业用公式)                          */
/* λ = λ0(T̄) + λ1(ρ̄) + λ2(T̄,ρ̄) [W/(m K)]                            */
/* ------------------------------------------------------------------ */
static const double L_TC[4][6] = {
    {0.0102811, 0.0299621, 0.0156146, -0.00422464, 0.0, 0.0},
    {-0.397070, 0.400302, 1.060000, -0.171587, 2.392190, 0.0},
    {0.0701309, 0.0118520, 0.00169937, -1.0200, 0.0, 0.0},
    {0.642857, -4.11717, -6.17937, 0.00308976, 0.0822994, 10.0932},
};
#define TSTAR_W   647.26
#define RHOSTAR_W 317.7

static double iapws_lambda_water(double T, double rho)
{
    double Tb = T / TSTAR_W;
    double rb = rho / RHOSTAR_W;
    double lam0, lam1, lam2, dTb, Lam0, Lam1, term1, term2, term3;
    int j;

    lam0 = 0.0;
    for (j = 0; j < 4; j++)
        lam0 += L_TC[0][j] * pow(Tb, j);
    lam0 *= sqrt(Tb);

    lam1 = L_TC[1][0] + L_TC[1][1] * rb
         + L_TC[1][2] * exp(L_TC[1][3] * pow(rb + L_TC[1][4], 2.0));

    dTb = fabs(Tb - 1.0) + L_TC[3][3];
    Lam0 = (Tb >= 1.0) ? 1.0 / dTb : L_TC[3][5] / pow(dTb, 0.6);
    Lam1 = 2.0 + L_TC[3][4] / pow(dTb, 0.6);
    term1 = (L_TC[2][0] / pow(Tb, 10.0) + L_TC[2][1]) * pow(rb, 1.8)
          * exp(L_TC[3][0] * (1.0 - pow(rb, 2.8)));
    term2 = L_TC[2][2] * Lam0 * pow(rb, Lam1)
          * exp((Lam1 / (1.0 + Lam1)) * (1.0 - pow(rb, 1.0 + Lam1)));
    term3 = L_TC[2][3] * exp(L_TC[3][1] * pow(Tb, 1.5)
                             + L_TC[3][2] / pow(rb, 5.0));
    lam2 = term1 + term2 + term3;
    return lam0 + lam1 + lam2; /* λ* = 1.0 W/(m K) */
}

/* ------------------------------------------------------------------ */
/* 附录 B: IAPWS 水动力黏度(工业用公式), η2 = 1                       */
/* η = η* η̄0(T̄) η̄1(T̄,ρ̄) [Pa s]                                      */
/* ------------------------------------------------------------------ */
static const double H_VISC[4] = {1.000, 0.978197, 0.579829, -0.202354};
static const double G_VISC[6][7] = {
    {0.5132047, 0.2151778, -0.2818107, 0.1778064, -0.0417661, 0.0, 0.0},
    {0.3205656, 0.7317883, -1.070786, 0.4605040, 0.0, -0.01578386, 0.0},
    {0.0, 1.241044, -1.263184, 0.2340379, 0.0, 0.0, 0.0},
    {0.0, 1.476783, 0.0, -0.4924179, 0.1600435, 0.0, -0.003629481},
    {-0.7782567, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0},
    {0.1885447, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0},
};
#define TSTAR_V   647.226
#define RHOSTAR_V 317.763
#define ETASTAR_V 55.071e-6

static double iapws_eta_water(double T, double rho)
{
    double Tb = T / TSTAR_V;
    double rb = rho / RHOSTAR_V;
    double eta0, s, ti, rm;
    int i, j, k;

    eta0 = 0.0;
    for (i = 0; i < 4; i++)
        eta0 += H_VISC[i] * pow(Tb, -i);
    eta0 = sqrt(Tb) / eta0;

    s = 0.0;
    ti = 1.0 / Tb - 1.0;
    rm = rb - 1.0;
    for (i = 0; i < 6; i++) {
        double tip = 1.0;
        for (k = 0; k < i; k++) tip *= ti;
        for (j = 0; j < 7; j++) {
            if (G_VISC[i][j] != 0.0) {
                double rmp = 1.0;
                int m;
                for (m = 0; m < j; m++) rmp *= rm;
                s += G_VISC[i][j] * tip * rmp;
            }
        }
    }
    return ETASTAR_V * eta0 * exp(rb * s);
}

/* ------------------------------------------------------------------ */
/* 附录 C: Fenghour et al.(1995) 氨黏度                               */
/* η(ρ,T) = η0(T) + Δη(ρ,T) [μPa s]; ρ: mol/l                        */
/* ------------------------------------------------------------------ */
static const double F_AETA[5] = {4.99318220, -0.61122364, 0.0,
                                 0.18535124, -0.11160946};
static const double F_CETA[13] = {-1.7999496, 46.692621, -534.60794,
    3360.4074, -13019.164, 33414.230, -58711.743, 71426.686,
    -59834.012, 33652.741, -12027.350, 2434.8205, -208.07957};
static const double F_DETA[3][5] = {
    {0.0, 0.0, 0.219664285, 0.0, -0.083651107},          /* i=2 */
    {0.0017366936, -0.0064250359, 0.0, 0.0, 0.0},        /* i=3 */
    {0.0, 0.0, 1.67668649e-4, -1.49710093e-4, 0.77012274e-4}, /* i=4 */
};
#define F_SIGMA 0.2957
#define F_EPSK  386.0
#define F_M     17.03

static double fenghour_eta_nh3_upas(double T, double rho_mol_l)
{
    double th = T / F_EPSK;
    double lnth = log(th);
    double zeta = 0.0, eta0, sq, b1, d_eta, s;
    int i, j;

    for (i = 0; i < 5; i++)
        zeta += F_AETA[i] * pow(lnth, i);
    zeta = exp(zeta);
    eta0 = 2.1357 * sqrt(T) * sqrt(F_M) / (F_SIGMA * F_SIGMA * zeta);

    sq = sqrt(th);
    b1 = 0.0;
    for (i = 0; i < 13; i++)
        b1 += F_CETA[i] * pow(sq, -i);
    b1 *= 0.6022137 * eta0 * F_SIGMA * F_SIGMA * F_SIGMA;

    d_eta = rho_mol_l * b1;
    for (i = 0; i < 3; i++) {           /* i=2,3,4 */
        s = 0.0;
        for (j = 0; j < 5; j++)
            s += F_DETA[i][j] * pow(th, -j);
        d_eta += pow(rho_mol_l, i + 2) * s;
    }
    return eta0 + d_eta;
}

static double fenghour_eta_nh3(double T, double rho_kg_m3)
{
    return fenghour_eta_nh3_upas(T, rho_kg_m3 / F_M) * 1e-6;
}

/* ------------------------------------------------------------------ */
/* §10 纯组分饱和液体/气体密度                                        */
/* ------------------------------------------------------------------ */
static const double RHOL_A_H2O[7] = {1.0, 1.9937718430, 1.0985211604,
    -0.5094492996, -1.7619124270, -44.9005480267, -723692.2618632};
static const double RHOL_A_NH3[7] = {1.0, 2.02491283, 0.84049667,
    0.30155852, -0.20926619, -74.60250177, 4089.79277506};
static const double RHOL_B[7] = {0.0, 1.0/3.0, 2.0/3.0, 5.0/3.0,
    16.0/3.0, 43.0/3.0, 110.0/3.0};
static const double RHOL_B_NH3_6 = 70.0/3.0; /* NH3 第6项指数为70/3 */

static double rho_liq_pure(double T, int is_nh3)
{
    const double *A = is_nh3 ? RHOL_A_NH3 : RHOL_A_H2O;
    double Tc = is_nh3 ? T_C_NH3 : T_C_H2O;
    double rhoc = is_nh3 ? RHO_C_NH3 : RHO_C_H2O;
    double tau = 1.0 - T / Tc;
    double s = 0.0;
    int i;
    for (i = 0; i < 7; i++) {
        double b = (is_nh3 && i == 6) ? RHOL_B_NH3_6 : RHOL_B[i];
        s += A[i] * pow(tau, b);
    }
    return rhoc * s;
}

/* 纯组分饱和气体密度: 待实现(§10后半) - 暂用占位 */
/* 实际应按书中公式实现,这里先声明 */
static double rho_vap_pure(double T, int is_nh3);

/* ------------------------------------------------------------------ */
/* §6 饱和液相比热 [kJ/(kg K)]                                        */
/* ------------------------------------------------------------------ */
static const double CP_A[2] = {3.875648, 3.665785};   /* NH3, H2O */
static const double CP_B[2] = {0.242125, 0.236312};

double cp_liq(double T, double x)
{
    double Ts_nh3, Ts_h2o, cp = 0.0;
    double Tss[2], Tcs[2], ws[2];
    int i;
    tstar(T, x, &Ts_nh3, &Ts_h2o);
    Tss[0] = Ts_nh3; Tss[1] = Ts_h2o;
    Tcs[0] = T_C_NH3; Tcs[1] = T_C_H2O;
    ws[0] = x; ws[1] = 1.0 - x;
    for (i = 0; i < 2; i++) {
        double tau = 1.0 - Tss[i] / Tcs[i];
        cp += ws[i] * (CP_A[i] + CP_B[i] / tau);
    }
    return cp;
}

/* ------------------------------------------------------------------ */
/* §7 液相导热 [W/(m K)]                                               */
/* ------------------------------------------------------------------ */
static const double LAM_L_NH3[4] = {8.902275e2, -0.69235, -2.4010e-3, 0.0};

double lambda_liq(double T, double x)
{
    double Ts_nh3, Ts_h2o, lam_nh3 = 0.0, lam_h2o;
    int i;
    tstar(T, x, &Ts_nh3, &Ts_h2o);
    for (i = 0; i < 4; i++)
        lam_nh3 += LAM_L_NH3[i] * pow(Ts_nh3, i);
    lam_nh3 *= 1e-3;
    lam_h2o = iapws_lambda_water(Ts_h2o, rho_liq_pure(Ts_h2o, 0));
    return x * lam_nh3 + (1.0 - x) * lam_h2o;
}

/* ------------------------------------------------------------------ */
/* §8 液相动力黏度 [Pa s]                                              */
/* ------------------------------------------------------------------ */
double eta_liq(double T, double x)
{
    double Ts_nh3, Ts_h2o;
    double eta_nh3_upas, eta_h2o_upas, Fx, d_eta, ln_eta;
    tstar(T, x, &Ts_nh3, &Ts_h2o);
    eta_nh3_upas = fenghour_eta_nh3_upas(Ts_nh3,
        rho_liq_pure(Ts_nh3, 1) / F_M);
    eta_h2o_upas = iapws_eta_water(Ts_h2o, rho_liq_pure(Ts_h2o, 0)) * 1e6;
    Fx = 6.38 * pow(1.0 - x, 1.125) * x
       * (1.0 - exp(-0.585 * x * pow(1.0 - x, 0.18)))
       * log(sqrt(eta_nh3_upas * eta_h2o_upas));
    d_eta = (0.534 - 0.815 * T / T_C_H2O) * Fx;
    ln_eta = x * log(eta_nh3_upas) + (1.0 - x) * log(eta_h2o_upas) + d_eta;
    return exp(ln_eta) * 1e-6;
}

/* ------------------------------------------------------------------ */
/* §9 表面张力 [N/m]                                                   */
/* ------------------------------------------------------------------ */
static const double SIG_P[2][3] = {
    {91.2, 1.1028, 0.0},     /* NH3: s0, mu, b */
    {235.8, 1.256, -0.625},  /* H2O */
};

static double sigma_pure(double T, int is_nh3)
{
    double Tc = is_nh3 ? T_C_NH3 : T_C_H2O;
    const double *p = is_nh3 ? SIG_P[0] : SIG_P[1];
    double tau = 1.0 - T / Tc;
    return p[0] * (1.0 + p[2] * tau) * pow(tau, p[1]); /* mN/m */
}

double sigma(double T, double x)
{
    double Ts_nh3, Ts_h2o, s_nh3, s_h2o, Fx, d_sig;
    tstar(T, x, &Ts_nh3, &Ts_h2o);
    s_nh3 = sigma_pure(Ts_nh3, 1);
    s_h2o = sigma_pure(Ts_h2o, 0);
    Fx = 1.442 * (1.0 - x) * (1.0 - exp(-2.5 * pow(x, 4.0)))
       + 1.106 * x * (1.0 - exp(-2.5 * pow(1.0 - x, 6.0)));
    d_sig = -(s_h2o - s_nh3) * Fx;
    return (x * s_nh3 + (1.0 - x) * s_h2o + d_sig) * 1e-3;
}

/* ------------------------------------------------------------------ */
/* §10 液相密度 [kg/m^3]                                               */
/* ------------------------------------------------------------------ */
static const double RHO_A1[3] = {-2.410, 8.310, -6.924};
static const double RHO_A2[3] = {2.118, -4.050, 4.443};

double rho_liq(double T, double x)
{
    double Ts_nh3, Ts_h2o, r_nh3, r_h2o, Td, s1, s2, Ax, d_rho;
    int i;
    tstar(T, x, &Ts_nh3, &Ts_h2o);
    r_nh3 = rho_liq_pure(Ts_nh3, 1);
    r_h2o = rho_liq_pure(Ts_h2o, 0);
    Td = T / T_C_H2O;
    s1 = 0.0; s2 = 0.0;
    for (i = 0; i < 3; i++) {
        s1 += RHO_A1[i] * pow(Td, i);
        s2 += RHO_A2[i] * pow(Td, i);
    }
    Ax = x * s1 + s2;
    d_rho = x * (1.0 - x) * (1.0 - Ax) * sqrt(r_nh3 * r_h2o);
    return x * r_nh3 + (1.0 - x) * r_h2o + d_rho;
}

/* ------------------------------------------------------------------ */
/* §11 质扩散系数 [m^2/s] (修正 Wilke-Chang)                          */
/* ------------------------------------------------------------------ */
double diffusivity(double T, double x)
{
    double psi_sol = x * 1.7 + (1.0 - x) * 2.6;
    double M_sol = x * 17.03 + (1.0 - x) * 18.0152;
    double Vdiff = 17.03 / rho_liq_pure(T, 1);
    double eta = eta_liq(T, x);
    return 117.282e-18 * T * sqrt(psi_sol * M_sol)
         / (eta * pow(Vdiff, 0.6));
}

/* ------------------------------------------------------------------ */
/* §12/§13 混合规则用 φ                                               */
/* ------------------------------------------------------------------ */
static double phi12(double eta1, double eta2)
{
    const double m1 = 17.03, m2 = 18.0152;
    double r = sqrt(eta1 / eta2) * pow(m2 / m1, 0.25);
    return pow(1.0 + r, 2.0) / sqrt(8.0 * (1.0 + m1 / m2));
}

/* ------------------------------------------------------------------ */
/* §12 气相导热 [W/(m K)] (Wassiljewa-Mason-Saxena)                    */
/* ------------------------------------------------------------------ */
static const double LAM_V_NH3[4] = {-0.48173, 20.04383, 0.0, 0.0};

double lambda_vap(double T, double y)
{
    double tau = 1.0 - T / T_C_NH3;
    double lam_nh3 = 0.0, lam_h2o, eta_nh3, eta_h2o, p12, p21;
    int i;
    for (i = 0; i < 4; i++)
        lam_nh3 += LAM_V_NH3[i] * pow(log(1.0 / tau), i);
    lam_nh3 *= 1e-3;
    lam_h2o = iapws_lambda_water(T, rho_vap_pure(T, 0));
    eta_nh3 = fenghour_eta_nh3(T, rho_vap_pure(T, 1));
    eta_h2o = iapws_eta_water(T, rho_vap_pure(T, 0));
    p12 = phi12(eta_nh3, eta_h2o);
    p21 = p12 * (eta_h2o / eta_nh3) * (17.03 / 18.0152);
    return y * lam_nh3 / (y + (1.0 - y) * p12)
         + (1.0 - y) * lam_h2o / ((1.0 - y) + y * p21);
}

/* ------------------------------------------------------------------ */
/* §13 气相动力黏度 [Pa s] (Wilke)                                     */
/* ------------------------------------------------------------------ */
double eta_vap(double T, double y)
{
    double eta_nh3 = fenghour_eta_nh3(T, rho_vap_pure(T, 1));
    double eta_h2o = iapws_eta_water(T, rho_vap_pure(T, 0));
    double p12 = phi12(eta_nh3, eta_h2o);
    double p21 = p12 * (eta_h2o / eta_nh3) * (17.03 / 18.0152);
    return y * eta_nh3 / (y + (1.0 - y) * p12)
         + (1.0 - y) * eta_h2o / ((1.0 - y) + y * p21);
}

/* ------------------------------------------------------------------ */
/* §14 气相密度 [kg/m^3]                                               */
/* ------------------------------------------------------------------ */
double rho_vap(double T, double y)
{
    double Ts_nh3, Ts_h2o, r_nh3, r_h2o, Td, d_rho_max, d_rho;
    tstar(T, y, &Ts_nh3, &Ts_h2o);
    r_nh3 = rho_vap_pure(Ts_nh3, 1);
    r_h2o = rho_vap_pure(Ts_h2o, 0);
    Td = T / T_C_H2O;
    d_rho_max = exp(9.952 - 3.884 / Td);
    d_rho = 82.0 * pow(1.0 - y, 0.5) * (1.0 - exp(-0.05 * pow(y, 2.75)))
          * d_rho_max;
    return y * r_nh3 + (1.0 - y) * r_h2o + d_rho;
}

/* ------------------------------------------------------------------ */
/* §15 气相比热 [kJ/(kg K)]                                            */
/* ------------------------------------------------------------------ */
static const double CPV_NH3[5] = {-1.199197086, 1.240129495, 0.924818752,
                                  0.018199633, -0.245034e-3};
static const double CPV_H2O[5] = {3.461825651, -4.987788063, 2.994381770,
                                  6.259308e-3, -8.262961e-6};

double cp_vap(double T, double y)
{
    double tau = 1.0 - T / tc_sol(y);
    double cp = 0.0;
    const double *Cs[2] = {CPV_NH3, CPV_H2O};
    double ws[2] = {y, 1.0 - y};
    int k;
    for (k = 0; k < 2; k++) {
        const double *C = Cs[k];
        cp += ws[k] * (C[0] + C[1] * pow(tau, -1.0/3.0)
                     + C[2] * pow(tau, -2.0/3.0)
                     + C[3] * pow(tau, -5.0/3.0)
                     + C[4] * pow(tau, -7.5/3.0));
    }
    return cp;
}

/* §10 纯组分饱和气体密度: ρV/ρc = exp(Σ A_i τ^{b_i}) */
static const double RHOV_A_H2O[6] = {-2.025450113, -2.701314216,
    -5.359161836, -17.343964539, -44.618326953, -64.869052901};
static const double RHOV_A_NH3[6] = {-1.43097426, -3.31273638,
    -4.44425769, -16.84466419, -37.79713547, -97.82853834};
static const double RHOV_B[6] = {1.0/3.0, 2.0/3.0, 4.0/3.0, 3.0,
    37.0/6.0, 71.0/6.0};

static double rho_vap_pure(double T, int is_nh3)
{
    const double *A = is_nh3 ? RHOV_A_NH3 : RHOV_A_H2O;
    double Tc = is_nh3 ? T_C_NH3 : T_C_H2O;
    double rhoc = is_nh3 ? RHO_C_NH3 : RHO_C_H2O;
    double tau = 1.0 - T / Tc;
    double s = 0.0;
    int i;
    for (i = 0; i < 6; i++)
        s += A[i] * pow(tau, RHOV_B[i]);
    return rhoc * exp(s);
}

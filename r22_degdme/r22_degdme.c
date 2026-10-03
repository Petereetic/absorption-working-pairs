/* R22-DEGDME 热力学关联式（C 实现，与 r22_degdme.py 逐点一致）
 * 来源：E. Ando, I. Takeshita, Int. J. Refrigeration, Vol.7, No.3, 1984.
 *   式(1) 泡点压力 Rankine 方程：lnP = ΣAnX^n + (1/T)ΣBnX^n + lnT·ΣCnX^n
 *         P: kg/cm2, T: K, X: R22 摩尔分数；适用 X=0.1~1.0, T=-20~190°C
 *   式(6) 摩尔热容：C = ΣAnX^n + t·ΣBnX^n + t^2·ΣCnX^n
 *         C: J/mol/°C, t: °C；t=-30~110°C
 *   式(7) 混合热（10°C）：ΔHm = X(1-X)·Σ Gi·(1-2X)^(i-1), i=1..4；J/mol
 *   式(9) 溶液焓：H = ΔHm + ∫(10°C→t) Cp dτ；参考态：纯组分液体 10°C 焓为 0
 * 编译：gcc -O2 -Wall -o r22_degdme r22_degdme.c -lm
 */
#include <stdio.h>
#include <math.h>

static const double M_R22 = 86.47;      /* g/mol */
static const double M_DEGDME = 134.17;  /* g/mol */
static const double TM_C = 10.0;        /* °C */
static const double KGCM2_TO_BAR = 0.980665;

/* 表2：式(1) n=0..5 (A, B, C) */
static const double T2[6][3] = {
    { 5.2167e1, -5.5828e3, -6.3489e0},
    { 1.2753e1,  3.3999e3, -1.4386e0},
    {-1.3901e2, -8.6015e3,  2.2313e1},
    { 7.3205e2, -3.1686e3, -1.1454e2},
    {-1.1910e3,  3.0425e4,  1.8148e2},
    { 5.4717e2, -1.9049e4, -8.1999e1},
};

/* 表3：式(6) n=0..3 (A, B, C) */
static const double T3[4][3] = {
    { 2.7974e2, -4.2015e-2,  2.3114e-3},
    {-1.5075e2,  5.9865e-1, -5.9745e-3},
    { 1.0095e2, -1.3790e0,   3.4322e-3},
    {-1.2802e2,  1.0167e0,   1.0571e-3},
};

/* 式(7)：G1..G4 */
static const double G4[4] = {-1.9061e4, 8.7280e3, -1.3948e3, -6.4218e2};

static double poly(const double *c, int n, double x)
{
    double s = 0.0, xn = 1.0;
    for (int i = 0; i < n; i++) { s += c[i] * xn; xn *= x; }
    return s;
}

/* 式(1)：泡点压力 kg/cm2，T_K 开尔文 */
double r22degdme_pvap_kgcm2(double X, double T_K)
{
    double A[6], B[6], C[6];
    for (int i = 0; i < 6; i++) { A[i] = T2[i][0]; B[i] = T2[i][1]; C[i] = T2[i][2]; }
    double sA = poly(A, 6, X), sB = poly(B, 6, X), sC = poly(C, 6, X);
    return exp(sA + sB / T_K + sC * log(T_K));
}

/* 式(1)：泡点压力 bar，t_C 摄氏度 */
double r22degdme_pvap_bar(double X, double t_C)
{
    return r22degdme_pvap_kgcm2(X, t_C + 273.15) * KGCM2_TO_BAR;
}

/* 式(6)：摩尔热容 J/mol/°C */
double r22degdme_cp_molar(double X, double t_C)
{
    double A[4], B[4], C[4];
    for (int i = 0; i < 4; i++) { A[i] = T3[i][0]; B[i] = T3[i][1]; C[i] = T3[i][2]; }
    double sA = poly(A, 4, X), sB = poly(B, 4, X), sC = poly(C, 4, X);
    return sA + t_C * sB + t_C * t_C * sC;
}

/* 式(7)：混合热 J/mol（10°C 测定值） */
double r22degdme_heat_of_mixing(double X)
{
    double s = 0.0, p = 1.0, d = 1.0 - 2.0 * X;
    for (int i = 0; i < 4; i++) { s += G4[i] * p; p *= d; }
    return X * (1.0 - X) * s;
}

/* 式(9)：溶液比焓 kJ/kg；参考态：纯组分液体 10°C 焓为 0 */
double r22degdme_h_solution(double X, double t_C)
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
    /* 网格自检输出，供与 Python 版逐点比对 */
    double Xs[] = {0.1, 0.3, 0.5, 0.7, 0.9, 1.0};
    double ts[] = {-20.0, 0.0, 10.0, 40.0, 80.0, 110.0};
    for (int i = 0; i < 6; i++)
        for (int j = 0; j < 6; j++) {
            double X = Xs[i], t = ts[j];
            printf("%.1f %.1f %.6f %.6f %.6f %.6f\n", X, t,
                   r22degdme_pvap_bar(X, t),
                   r22degdme_cp_molar(X, t),
                   r22degdme_heat_of_mixing(X),
                   r22degdme_h_solution(X, t));
        }
    return 0;
}
#endif

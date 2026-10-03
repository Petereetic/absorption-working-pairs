/*
 * R134a (1) + DMF (2) 溶液 VLE 与焓计算 - C 语言实现
 * ==================================================
 * 模型: NRTL 活度系数 + gamma-phi 泡点模型
 * 数据源: Zehioua et al., J. Chem. Eng. Data 2009, DOI: 10.1021/je900440t
 * 验证: 58 个实验点 (303.30-353.24 K), 泡点压力平均绝对相对误差 1.49%
 *        (注: 1.49% 仅为训练集拟合精度。独立验证: Cui 2007 90点 AARD 15.1%,
 *         Han 2011 112点 AARD 10.1%; 跨实验室不确定度约 300K/8%、360K/20%。
 *         详见《文献合并研究-R134a-DMF-2026-09-30.md》)
 *
 * 参考态: 273.15 K 饱和液体焓 = 100 kJ/kg (R134a 与 DMF 统一)
 *
 * 编译: gcc -O2 -o r134a_dmf r134a_dmf.c -lm
 * 运行: ./r134a_dmf
 */

#include <stdio.h>
#include <math.h>

/* ---------- 常数 ---------- */
#define R_GAS   8.314462618   /* J/(mol·K) */
#define M1      102.03        /* R134a 摩尔质量, g/mol */
#define M2      73.09         /* DMF 摩尔质量, g/mol */

/* NRTL 参数 (gamma-phi 框架下拟合, alpha=0.3) */
#define DG12    868.1         /* J/mol, (g12 - g22) */
#define DG21   -929.1         /* J/mol, (g21 - g11) */
#define ALPHA   0.3

/* ---------- 纯组分饱和压力 (MPa), T in K ---------- */

/* R134a: 拟合自 Zehioua 表3, 298-353K 内误差 < 0.2% */
double psat_r134a(double T)
{
    return exp(7.89191 - 2310.84 / (T - 19.79));
}

/* DMF: NIST WebBook (Gopal & Rizvi 1968), 303-363K */
double psat_dmf(double T)
{
    return pow(10.0, 3.93068 - 1337.716 / (T - 82.648)) * 0.1;
}

/* ---------- 液体摩尔体积 (m3/mol), Poynting 校正用 ---------- */

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

/* ---------- NRTL 活度系数 ---------- */
/* 输入: T(K), x1(R134a 液相摩尔分数); 输出: *g1, *g2 */
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

/* ---------- NRTL 超额摩尔焓 (J/mol), 解析式 ---------- */
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

/* ---------- 泡点压力 ---------- */
/*
 * 输入: T(K), x1(液相摩尔分数)
 * 输出: *p_MPa 泡点压力, *y1 气相摩尔分数 (可传 NULL)
 * 返回: 0 成功
 */
int bubble_p(double T, double x1, double *p_MPa, double *y1)
{
    double x2 = 1.0 - x1;
    double g1, g2, p1s, p2s, V1, V2, p, Poy1, Poy2;
    int i;

    nrtl_gamma(T, x1, &g1, &g2);
    p1s = psat_r134a(T);
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

/* ---------- 已知泡点压力反算温度 (牛顿迭代) ---------- */
double bubble_T(double p_MPa, double x1, double Tguess)
{
    double T = Tguess, pc, p2, dpdT, dT = 0.2;
    int i;
    for (i = 0; i < 50; i++) {
        double dummy;
        bubble_p(T, x1, &pc, &dummy);
        bubble_p(T + dT, x1, &p2, &dummy);
        dpdT = (p2 - pc) / dT;
        if (fabs(dpdT) < 1e-12) break;
        T = T - (pc - p_MPa) / dpdT;
        if (fabs(pc - p_MPa) < 1e-9) break;
    }
    return T;
}

/* ---------- 纯组分液体焓 (kJ/kg), 参考态 273.15K=100 ---------- */

/* R134a 饱和液体: 拟合自 Tillner-Roth & Baehr (1994), 233-353K */
double h_r134a_L(double T)
{
    double t = T - 273.15;
    return 1.310235e-5 * t * t * t
         + 1.34329e-3  * t * t
         + 1.334242    * t
         + 100.0;
}

/* DMF 液体: He et al., Solar Energy 83 (2009) 式(5) */
double h_dmf_L(double T)
{
    return -297.61 + 0.89544 * T + 0.0020551 * T * T;
}

/* ---------- 摩尔分数 <-> 质量分数 (R134a) ---------- */
double x_to_w(double x1)
{
    return x1 * M1 / (x1 * M1 + (1.0 - x1) * M2);
}

double w_to_x(double w1)
{
    return (w1 / M1) / (w1 / M1 + (1.0 - w1) / M2);
}

/* ---------- 溶液焓 (kJ/kg) ---------- */
/* h = w1*h1 + w2*h2 + hE/Mbar */
double h_solution(double T, double x1)
{
    double x2 = 1.0 - x1;
    double Mbar = x1 * M1 + x2 * M2;   /* g/mol */
    double w1 = x1 * M1 / Mbar;
    double w2 = x2 * M2 / Mbar;
    double hE = nrtl_hE(T, x1);        /* J/mol */
    return w1 * h_r134a_L(T) + w2 * h_dmf_L(T) + hE / Mbar;
}

/* ---------- 自检主函数 ---------- */
int main(void)
{
    double p, y1, T;
    int i;

    /* VLE 验证点: {T(K), x1, Pexp(kPa)} */
    double chk[][3] = {
        {303.30, 0.4437,  337.0},
        {323.34, 0.7247,  923.8},
        {353.24, 0.6594, 1665.2},
    };

    printf("VLE 验证 (T, x1 -> p):\n");
    for (i = 0; i < 3; i++) {
        bubble_p(chk[i][0], chk[i][1], &p, &y1);
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
                       Ts[ti], xs[xi], h_solution(Ts[ti], xs[xi]));
    }

    printf("\n质量分数换算示例: w1=0.5 -> x1=%.4f\n", w_to_x(0.5));
    return 0;
}

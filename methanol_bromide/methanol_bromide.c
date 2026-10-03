/* 甲醇/(2LiBr-ZnBr2) 热力学关联式（C 实现，与 methanol_bromide.py 逐点一致）
 * 来源：S. El-Shamarka, PhD thesis, Cranfield Institute of Technology, 1981.
 * 体系：盐比固定 LiBr:ZnBr2 = 2:1（摩尔）；w 为甲醇质量分数；盐不挥发。
 *   式(3.1) 泡点压力：log10 P[mbar] = C1(w) + C2(w)·(1000/T[K] - 2.3)
 *           C1、C2 为表 3.3 的 8 个节点值，节点间 PCHIP 保形插值。
 *           表 3.3 的 -C2 在 w=28.0% 处（2.7278）打破单调（30.1% 处 2.8197），
 *           按原表照印，PCHIP 在该处斜率为 0，不产生过冲。
 *   式(3.4) 比热：Cp = A + B·t[°C]，A = 0.652 + 2.139w - 2.077w^2，
 *           B = -0.000205 + 0.00928w - 0.0101w^2。
 *           末项符号：p.86 原式为叠印字形，附录 A 重述印 "-"，且取 "-" 与
 *           论文表 3.7 实测比热的最大偏差仅 0.7%（取 "+" 则 6%~14%），故取 "-"。
 *   附录 A 汽化焓 H'（含混合热）：H' = A + B·w + C·w^2，其中 A、B、C 为
 *           T 的二次式（见下），T 为开尔文（切勿用 °C）；仅 w=0.25~0.356 有效。
 * 密度与黏度（mb_rho_iedema / mb_eta_iedema）为另一来源，与上文无关：
 *   P. D. Iedema, PhD thesis, TU Delft, 1984（同体系 LiBr/ZnBr2-甲醇）。
 *   密度（表 2.7.2.2.2）：rho = [rho25(w) + rho'(w)·(t-25)]·(1 + 0.32·w_H)，
 *           rho25、rho' 为 w 的三次式，t 为 °C；w 为总溶剂质量分数
 *           （甲醇+水，干溶液时即甲醇质量分数），w_H 为水质量分数。
 *           适用 w=0.28~0.42，t=-10~140 °C；作者称平均偏差 0.13%。
 *   黏度（表 2.7.3）：ln eta = eta0(w) + etaT(w)/T，eta 为 Pa·s，T 为 K，
 *           eta0、etaT 为 w 的三次式。适用 w=0.28~1.0，t=20~120 °C。
 *           原表 etaT 末项印作 w^4 且系数下标错标，经 9 个实测点裁决取
 *           w^3 读法（平均偏差 2.8%，与作者自称吻合；w^4 读法偏 36%）。
 *   注：El-Shamarka 自己的式(4.10) 密度、式(4.11) 黏度仍未核实，本文件
 *   未实现，勿与上述 Iedema 关联式混淆（详见 公式说明.md）。
 * 参考态（本文档约定，论文未定义绝对基准）：
 *   h_liq(0°C, 任意 w) = 100 kJ/kg；h_liq = 100 + A·t + B·t^2/2；
 *   h_vap = h_liq + H'。
 * 编译：gcc -O2 -Wall -Wextra -o methanol_bromide methanol_bromide.c -lm
 * main() 输出验证网格（CSV），供与 Python 版逐点比对。
 */
#include <stdio.h>
#include <math.h>

/* 表 3.3（p.74）：节点组成与 C1、C2（C2 为负值） */
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

/* Fritsch-Carlson PCHIP，与 Python 参考实现同算法 */
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

/* 式(3.1)：泡点压力，bar */
double mb_p_bubble_TW(double T_K, double w)
{
    double log10p_mbar = pchip_eval(W_NODES, C1_NODES, w)
                       + pchip_eval(W_NODES, C2_NODES, w) * (1000.0 / T_K - 2.3);
    return pow(10.0, log10p_mbar) / 1000.0;
}

/* 式(3.1) 解析反解：泡点温度，K */
double mb_T_bubble_PW(double P_bar, double w)
{
    double log10p_mbar = log10(P_bar * 1000.0);
    return 1000.0 / ((log10p_mbar - pchip_eval(W_NODES, C1_NODES, w))
                     / pchip_eval(W_NODES, C2_NODES, w) + 2.3);
}

/* 式(3.4)：溶液比热，kJ/(kg·K) */
double mb_cp(double T_K, double w)
{
    double A, B;
    cp_AB(w, &A, &B);
    return A + B * (T_K - 273.15);
}

/* 附录 A：汽化焓 H'（含混合热），kJ/kg；T_K 为开尔文；仅 w=0.25~0.356 */
double mb_h_prime(double T_K, double w)
{
    double A = 2202.6 + 9.24 * T_K - 0.0218 * T_K * T_K;
    double B = -(4417.8 + 15.53 * T_K - 0.0392 * T_K * T_K);
    double C = 3570.0 + 10.81 * T_K - 0.0294 * T_K * T_K;
    return A + B * w + C * w * w;
}

/* 溶液比焓，kJ/kg；参考态约定 h_liq(0°C) = 100 kJ/kg */
double mb_h_liq(double T_K, double w)
{
    double A, B, t = T_K - 273.15;
    cp_AB(w, &A, &B);
    return 100.0 + A * t + B * t * t / 2.0;
}

/* 气相比焓，kJ/kg：h_vap = h_liq + H' */
double mb_h_vap(double T_K, double w)
{
    return mb_h_liq(T_K, w) + mb_h_prime(T_K, w);
}

/* Iedema 表 2.7.2.2.2：密度，kg/m3。T_K 为开尔文（内部换算 t[°C]）；
 * w 为总溶剂质量分数 w_t（甲醇+水），w_H 为水质量分数；
 * 干溶液 w_H=0 时 w_t 即甲醇质量分数。适用 w=0.28~0.42，t=-10~140 °C */
double mb_rho_iedema(double T_K, double w, double w_H)
{
    double t = T_K - 273.15;
    double rho25 = 3026.745 - 5369.24 * w + 4082.056 * w * w + 103.8639 * w * w * w;
    double drho = -0.0997537 - 11.77377 * w + 42.24796 * w * w - 44.70839 * w * w * w;
    return (rho25 + drho * (t - 25.0)) * (1.0 + 0.32 * w_H);
}

/* Iedema 表 2.7.3：动力黏度，Pa·s；ln eta = eta0(w) + etaT(w)/T_K。
 * 末项取 w^3 读法（裁决依据见文件头）。适用 w=0.28~1.0，t=20~120 °C */
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
    static const double PS[5] = {0.10, 0.39997, 0.60, 1.00, 1.30};
    int i, j;
    for (i = 0; i < 7; i++)
        for (j = 0; j < 9; j++)
            printf("grid,%.2f,%.3f,%.17g,%.17g,%.17g,%.17g,%.17g\n",
                   TS[i], WS[j],
                   mb_p_bubble_TW(TS[i], WS[j]), mb_cp(TS[i], WS[j]),
                   mb_h_prime(TS[i], WS[j]), mb_h_liq(TS[i], WS[j]),
                   mb_h_vap(TS[i], WS[j]));
    for (i = 0; i < 5; i++)
        for (j = 0; j < 9; j++)
            printf("inv,%.5f,%.3f,%.17g\n", PS[i], WS[j], mb_T_bubble_PW(PS[i], WS[j]));
    return 0;
}

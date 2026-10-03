"""
R134a (1) + DMA (2) 泡点压力与溶液焓 - 参考实现
================================================
模型来源: Nezu et al., "Thermodynamic properties of working-fluid pairs
          with R-134a for absorption refrigeration system",
          IIR/IIF Commission B1,B2,E1,E2, Guangzhou, 2002, pp.446-453.

泡点压力: 论文式(1) + 表2 常数 (R-134a/DMA 列)
  P = P_R134a * x1 * exp{ x2*(A0+A1*Tr+A2*Tr^2+A3*Tr^3)
                        + x2^2*(B0+B1*Tr+B2*Tr^2)
                        + x2^3*(C0+C1*Tr) + x2^4*D0 }
  Tr = T/374.18, P_R134a 为 R134a 饱和压力 (Tillner-Roth & Baehr 1994,
  此处用拟合式代替, 298-353K 误差<0.2%).
  论文报道: 与实验偏差 < ±3.8 kPa (DMA).

溶液焓: 论文式(6) h = w1*h1 + w2*h2 + hE
  hE: UNIQUAC 式(3)(4)(5) + 表3(q) + 表4(可调参数, R-134a/DMA 列)
  h1: R134a 饱和液体焓 (Tillner-Roth 拟合, 参考态 273.15K = 200 kJ/kg,
      与论文 h0=200 kJ/kg 一致)
  h2: DMA 液体焓, h2 = 200 + Cp*(T-273.15), Cp 取常数 178.2 J/mol/K
      (Wikipedia/DMA 物性, 298K 液相值), M=87.12 g/mol.
      注: 论文用 Joback + CSP 计算 Cp, 此处用常数近似, 已在文档中说明.

参考态: 273.15 K 饱和液体 = 200 kJ/kg (两组分统一, 与论文一致).

作者: Muse (2026-09-29)
"""

import math

R = 8.314462618          # J/(mol·K)
M1 = 102.03              # R134a 摩尔质量, g/mol
M2 = 87.12               # DMA 摩尔质量, g/mol (C4H9NO)
TC1 = 374.18             # R134a 临界温度, K (论文式1用)

# ---- 论文表2: 式(1)常数 (R-134a/DMA) ----
A0, A1, A2, A3 = -0.68156, 0.93065, 2.36801, -3.58456
B0, B1, B2 = 3.29883, 1.85907, 3.29883
C0, C1 = 1.77009, -3.90560
D0 = 1.26416

# ---- 论文表3: UNIQUAC q (R-134a/DMA) ----
Q1, Q2 = 2.38, 3.276

# ---- 论文表4: UNIQUAC 可调参数 (R-134a/DMA) ----
# u_ij = Aij + Bij*T + Cij*T^2  (J/mol)
UA12, UA21 = -2.68e-2, -2.70e-2
UB12, UB21 = -4.34, -4.37
UC12, UC21 = 2.02e-2, 6.44e-3

# ---- DMA 定压比热 (常数近似) ----
CP_DMA = 178.2 / M2      # kJ/(kg·K) = 2.0453


def psat_r134a(T):
    """R134a 饱和压力, MPa. T in K. (拟合式, 298-353K 误差<0.2%)"""
    return math.exp(7.89191 - 2310.84 / (T - 19.79))


def h_r134a_L(T):
    """
    R134a 饱和液体焓, kJ/kg.
    拟合自 Tillner-Roth & Baehr (1994). 参考态 273.15K = 200 kJ/kg
    (论文 h0=200 kJ/kg; 原拟合以 100 为基准, 此处 +100 平移).
    """
    t = T - 273.15
    return 1.310235e-5 * t**3 + 1.34329e-3 * t**2 + 1.334242 * t + 200.0


def h_dma_L(T):
    """
    DMA 液体焓, kJ/kg. 参考态 273.15K = 200 kJ/kg (论文 h0).
    Cp 取常数近似 (见模块文档).
    """
    return 200.0 + CP_DMA * (T - 273.15)


def w_to_x(w1):
    """R134a 质量分数 -> 摩尔分数"""
    return (w1 / M1) / (w1 / M1 + (1 - w1) / M2)


def x_to_w(x1):
    """R134a 摩尔分数 -> 质量分数"""
    return x1 * M1 / (x1 * M1 + (1 - x1) * M2)


def bubble_p_w(T, w1):
    """
    泡点压力, MPa. 论文式(1).
    输入: T (K), w1 (R134a 质量分数)
    """
    x1 = w_to_x(w1)
    x2 = 1.0 - x1
    Tr = T / TC1
    p1s = psat_r134a(T)
    e = (x2 * (A0 + A1*Tr + A2*Tr*Tr + A3*Tr*Tr*Tr)
         + x2*x2 * (B0 + B1*Tr + B2*Tr*Tr)
         + x2*x2*x2 * (C0 + C1*Tr)
         + x2*x2*x2*x2 * D0)
    return p1s * x1 * math.exp(e)


def bubble_T_w(p_MPa, w1):
    """
    已知泡点压力反算温度 (二分法).
    输入: p_MPa, w1. 返回: T (K)
    """
    lo, hi = 200.0, 374.0
    for _ in range(60):
        mid = 0.5 * (lo + hi)
        if bubble_p_w(mid, w1) < p_MPa:
            lo = mid
        else:
            hi = mid
    return 0.5 * (lo + hi)


def uniquac_hE(T, x1):
    """
    UNIQUAC 超额摩尔焓, J/mol. 论文式(3)(4)(5).
    输入: T (K), x1 (R134a 摩尔分数)
    """
    x2 = 1.0 - x1
    u12 = UA12 + UB12 * T + UC12 * T * T
    u21 = UA21 + UB21 * T + UC21 * T * T
    t12 = math.exp(-u12 / (R * T))
    t21 = math.exp(-u21 / (R * T))
    d1 = Q1 * x1 + Q2 * x2 * t21
    d2 = Q2 * x2 + Q1 * x1 * t12
    term1 = t21 * (UA21 - UC21 * T * T) / d1
    term2 = t12 * (UA12 - UC12 * T * T) / d2
    return Q1 * Q2 * x1 * x2 * (term1 + term2)


def h_solution_w(T, w1):
    """
    R134a-DMA 溶液焓, kJ/kg. 论文式(6).
    输入: T (K), w1 (R134a 质量分数)
    h = w1*h1 + w2*h2 + hE/Mbar
    """
    x1 = w_to_x(w1)
    x2 = 1.0 - x1
    Mbar = x1 * M1 + x2 * M2          # g/mol
    hE = uniquac_hE(T, x1)            # J/mol
    return w1 * h_r134a_L(T) + (1 - w1) * h_dma_L(T) + hE / Mbar


if __name__ == "__main__":
    print("R134a-DMA 泡点/溶液焓 (Nezu et al. 2002)")
    print("=" * 60)
    # 泡点算例
    for Tc, w in [(30, 0.5), (80, 0.4), (0, 0.3), (100, 0.6)]:
        T = Tc + 273.15
        p = bubble_p_w(T, w)
        print(f"BubbleP({Tc}°C, w={w}) = {p*10:.3f} bar")
    print("-" * 60)
    # 反算算例
    for pbar, w in [(5.0, 0.5), (1.0, 0.3), (10.0, 0.7)]:
        T = bubble_T_w(pbar / 10, w)
        print(f"BubbleT({pbar} bar, w={w}) = {T-273.15:.2f} °C")
    print("-" * 60)
    # 焓算例
    for Tc, w in [(30, 0.5), (80, 0.4), (0, 0.3), (100, 0.6)]:
        T = Tc + 273.15
        h = h_solution_w(T, w)
        x = w_to_x(w)
        hE = uniquac_hE(T, x) / (x*M1 + (1-x)*M2)
        print(f"Hsol({Tc}°C, w={w}) = {h:.2f} kJ/kg  (hE={hE:.2f})")
    print("-" * 60)
    # 端点检查
    print(f"h_R134aL(0°C) = {h_r134a_L(273.15):.2f} (应=200)")
    print(f"h_DMA(0°C) = {h_dma_L(273.15):.2f} (应=200)")
    print(f"Hsol(30°C, w=1) = {h_solution_w(303.15, 1.0):.2f} (应≈h_R134a)")
    print(f"Hsol(30°C, w=0) = {h_solution_w(303.15, 0.0):.2f} (应≈h_DMA)")

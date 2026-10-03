# -*- coding: utf-8 -*-
"""
iedema_vp.py — Iedema 1984 蒸气压简化关联式（校验版，不并入正式库）

来源：P. D. Iedema 博士论文《The Absorption Heat Pump with Lithium
Bromide/Zinc Bromide/Methanol》，TU Delft，1984。
  - 关联式与系数：表 2.6.4.2（论文 p.97，PDF p.119，300 dpi 读图逐字核对）
  - 混合盐比例：§2.4.1、§2.4.2（论文 p.65，PDF p.87）明文 "LiBr/ZnBr2/
    CH3OH (2 : 1)" —— 摩尔比 LiBr:ZnBr2 = 2:1，与 El-Shamarka 相同；
    附录 1（论文 p.297）以参数 y 表示（1 mol 混合盐 = y mol LiBr +
    (1-y) mol ZnBr2），2:1 即 y = 2/3。本关联式直接以质量分数 w 给出，
    不需要 molality 换算。
  - 实测数据：表 2.4.2（论文 p.66，PDF p.88），4 组成共 44 点
    （点数与表 2.6.2.1 的 N=9/14/7/14 一致）；样品含水 w_H 约 0.007，
    测量精度作者估计为压力的 2%（§2.4.2）。

公式（原表照印，p 以 mbar 计、T 以 K 计）：

    ln{ p0(T) / p(w,T) } = a(w)/T + b(w)
    p0(T) = p1 + p2/T + p3/T^2
    a(w)  = a1 + a2 w + a3 w^2 + a4 w^3 + a5 w^4
    b(w)  = b1 + b2 w + b3 w^2 + b4 w^3 + b5 w^4

注意（实现约定）：按印刷值数值核验，p0(T) 的计算结果等于纯甲醇蒸气压
（mbar）的自然对数：T=313.15 K 时 p0=5.871，exp=354 mbar，与纯甲醇
40°C 蒸气压 354 mbar 吻合；T=338.15 K 时 exp(p0)=1028 mbar vs 沸点
1013 mbar（+1.5%）。故实现为 ln p(w,T) = p0(T) - a(w)/T - b(w)，
p 单位 mbar，最后换算为 bar 返回，与现有库口径一致。

适用范围（原表）：w = 0.30-0.45，t = -20-140°C。
该关联式系作者由其状态方程（表 2.6.3，64 个 b_ij 系数）的计算结果拟合
而来（论文 p.96 明文），并非直接拟合实测；作者未对简化式单独给出偏差。
状态方程对自家 44 点实测（表 2.6.2.1，论文 p.76）蒸气压平均相对偏差
按组成分别为 5.0% / 2.6% / 3.4% / 2.3%。
"""

import math

# ---- 表 2.6.4.2 系数（300 dpi 读图核对） ----
_P = (1.874037e1, -3.498560e3, -1.663928e5)
_A = (-1.959784e5, 1.989094e6, -7.373894e6, 1.194267e7, -7.162617e6)
_B = (5.416153e2, -5.414318e3, 1.996754e4, -3.231367e4, 1.940737e4)

W_MIN, W_MAX = 0.30, 0.45          # 原表适用范围
T_MIN, T_MAX = 253.15, 413.15      # -20 ~ 140 °C


def _poly5(c, w):
    return c[0] + w * (c[1] + w * (c[2] + w * (c[3] + w * c[4])))


def ln_p0_meoh(T_K):
    """p0(T) = p1 + p2/T + p3/T^2；数值上等于纯甲醇蒸气压 [mbar] 的 ln。"""
    return _P[0] + _P[1] / T_K + _P[2] / T_K ** 2


def a_of_w(w):
    return _poly5(_A, w)


def b_of_w(w):
    return _poly5(_B, w)


def p_bubble_iedema(T_K, w):
    """Iedema 表 2.6.4.2 泡点压力，bar。w 为甲醇质量分数。范围外不报错、仅外推。"""
    ln_p_mbar = ln_p0_meoh(T_K) - a_of_w(w) / T_K - b_of_w(w)
    return math.exp(ln_p_mbar) / 1000.0


# ---- 表 2.4.2 实测数据（论文 p.66）：(w_m, w_H, [(t_C, p_kPa), ...]) ----
TABLE_242 = (
    (0.2849, 0.0070, ((36.57, 0.3539), (41.81, 0.4973), (46.82, 0.6786),
                      (52.42, 0.9611), (64.76, 2.021), (72.17, 3.040),
                      (80.32, 4.684), (85.50, 6.039), (89.76, 7.365))),
    (0.3050, 0.0069, ((35.77, 0.4997), (39.51, 0.6312), (43.20, 0.7948),
                      (47.27, 1.029), (47.39, 1.045), (51.75, 1.353),
                      (55.94, 1.734), (60.28, 2.231), (61.29, 2.378),
                      (65.22, 2.942), (69.30, 3.647), (70.62, 3.938),
                      (75.26, 4.988), (79.88, 6.424))),
    (0.3458, 0.0067, ((44.87, 1.992), (49.45, 2.570), (54.66, 3.439),
                      (59.88, 4.562), (64.67, 5.853), (75.89, 10.34),
                      (80.89, 12.89))),
    (0.4035, 0.0066, ((18.69, 1.532), (22.80, 1.951), (24.28, 2.148),
                      (32.72, 3.423), (34.54, 3.866), (37.26, 4.464),
                      (37.80, 4.517), (38.32, 4.681), (41.05, 5.435),
                      (41.43, 5.436), (42.42, 5.727), (44.73, 6.541),
                      (56.67, 11.77), (60.66, 14.46))),
)


def _selfcheck():
    print("== 自验 1：p0(T) 对纯甲醇蒸气压（与现有库 Antoine 式对比） ==")
    import methanol_bromide as mb
    for t_C in (0.0, 25.0, 40.0, 64.7, 100.0, 120.0):
        T = t_C + 273.15
        p0 = math.exp(ln_p0_meoh(T))          # mbar
        pref = mb.meoh_psat_bar(T) * 1000.0   # mbar
        print(f"  t={t_C:6.1f} C  exp(p0)={p0:9.1f} mbar  Antoine={pref:9.1f} mbar"
              f"  dev={100.0 * (p0 - pref) / pref:+.2f}%")
    print("== 自验 2：简化关联式 vs 表 2.4.2 实测 44 点 ==")
    all_dev = []
    for w_m, w_H, pts in TABLE_242:
        devs = []
        for t_C, p_kPa in pts:
            pc = p_bubble_iedema(t_C + 273.15, w_m) * 100.0  # bar -> kPa
            devs.append((pc - p_kPa) / p_kPa)
        all_dev += devs
        mrd = sum(abs(d) for d in devs) / len(devs)
        print(f"  w={w_m:.4f} (w_H={w_H})  N={len(pts):2d}  mean rel dev="
              f"{100 * mrd:5.2f}%  bias={100 * sum(devs) / len(devs):+6.2f}%  "
              f"max|dev|={100 * max(abs(d) for d in devs):5.2f}%")
    print(f"  全部 44 点：mean rel dev={100 * sum(abs(d) for d in all_dev) / len(all_dev):.2f}%  "
          f"bias={100 * sum(all_dev) / len(all_dev):+.2f}%")
    print("  （对照：作者状态方程对同批数据的蒸气压 mean rel dev 按组成 "
          "5.0/2.6/3.4/2.3%，表 2.6.2.1；测量精度估计 2%，§2.4.2）")


if __name__ == "__main__":
    _selfcheck()

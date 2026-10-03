# 甲醇/(2LiBr-ZnBr2) 热力学关联式（参考实现）
# 来源：S. El-Shamarka, "An investigation of methanol and inorganic bromides
#   for thermally operated heat pumps", PhD thesis, Cranfield Institute of
#   Technology, 1981.
#
# 体系：盐混合物比例固定 LiBr:ZnBr2 = 2:1（摩尔比），全文称 "2LiBr-ZnBr2"。
# 浓度变量 w 始终为甲醇质量分数（kg/kg）。盐不挥发，气相视为纯甲醇。
#
# 关联式（常数经原页图像逐字核对）：
#   式(3.1) 泡点压力（论文 p.71，系数表 3.3 于 p.74）：
#           log10 P[mbar] = C1(w) + C2(w)·(1000/T[K] - 2.3)
#           C1、C2 在 8 个实测组成节点上给定，节点间用 PCHIP 保形插值。
#           注意表 3.3 的 -C2 在 w=28.0% 处（2.7278）打破单调趋势
#           （30.1% 处为 2.8197），系按原表照印；PCHIP 在该节点斜率为 0，
#           形成局部平台，不会产生过冲。
#   式(3.4) 比热（p.86，附录 A p.194 重述）：
#           Cp[kJ/(kg·°C)] = A + B·t[°C]
#           A = 0.652 + 2.139w - 2.077w^2
#           B = -0.000205 + 0.00928w - 0.0101w^2
#           【符号裁决】p.86 原式 B 末项符号为叠印字形（∓），附录 A 重述印为
#           "-"。用论文表 3.7 实测比热核对：取 "-" 时最大偏差 0.7%
#           （w=0.403: 51.3°C→1.274 vs 实测 1.27；69.9°C→1.309 vs 1.30；
#            w=0.311: 40.0°C→1.185 vs 1.19；80.6°C→1.254 vs 1.26），
#           取 "+" 时偏差 6%~14%，与论文自称的 2% 平均误差矛盾。
#           故本实现取 "-"，与附录 A 印刷及实测数据一致。
#   附录 A 汽化焓 H'（p.196，含混合热，由蒸气压斜率经 Clausius-Clapeyron 导出）：
#           H'[kJ/kg] = A + B·w + C·w^2
#           A = 2202.6 + 9.24T - 0.0218T^2
#           B = -(4417.8 + 15.53T - 0.0392T^2)
#           C = 3570.0 + 10.81T - 0.0294T^2
#           【陷阱】式中 T 为开尔文（同页数据表按 °C 列表）。已用表中三点验算：
#           (10°C, w=0.25): 1920 vs 表值 1940（-1.0%)；
#           (10°C, w=0.356): 1593 vs 1601（-0.5%)；
#           (100°C, w=0.25): 1646 vs 1645（+0.05%）。
#           拟合区间仅 w≈0.25~0.356，禁止外推（w=1 时给 1672 kJ/kg，
#           纯甲醇真值约 1193）。表中 w=35.6%、110°C 一格印作 1221，
#           破坏平滑趋势（邻值 1352、1288），疑印刷错误，未用作验算点。
#
# 参考态（本文档自行约定，论文未定义溶液焓绝对基准，只用焓差）：
#   h_liq(0°C, 任意 w) = 100 kJ/kg，即 h_liq = 100 + ∫(0°C→t) Cp dt
#   = 100 + A·t + B·t^2/2。焓的浓度依赖经 h_prime 进入气相焓：
#   h_vap(T, w) = h_liq(T, w) + H'(T, w)（组装法与作者 COP 程序相同）。
#
# 适用范围：
#   泡点：w = 0.243~0.509，实测约 15~193°C；Cp：w = 0.249~0.403（论文自称）；
#   H'：w = 0.25~0.356（硬性），T 约 283~472 K（表列 10~199°C）。
#
# 纯甲醇饱和线（仅供滑移图露点用）：附录 A 表（p.194）给出纯甲醇在
# 300~1000 mmHg 下的平衡温度，本模块用其中 7 点拟合 Antoine 方程
# log10 P[mmHg] = A - B/(T + C)，A=8.885298, B=2070.3714, C=6.3818，
# 拟合最大误差 0.11%。表中 400 mmHg 行甲醇温度印作 373.1 K，与该行
# Ratio 列反推值 323.1 K 矛盾（拟合亦给出 323.13 K），判为误印，已剔除。
#
# 未核实式（仅 Python，不进 C/VBA）：
#   式(4.10) 密度：rho = 2.55 - 2.366w - 0.0068t [g/cc]。按印刷 0.0068 与
#   论文表 4.2 实测（如 w=0.253、50°C 约 1914 kg/m3）差约 16%；温度系数
#   若为 0.00068 则差 0.2%。印刷小数点存疑，待按表 4.2 原始数据重拟合。
#   式(4.11) 黏度（Guzman-Andrade 型）：mu = A·exp(B/T)，OCR 数字残损严重
#   （含 A 的 10^-3 量级乘子与 B 的小数点），不可用，待按表 4.3 重拟合。

import math

# ---- 表 3.3（p.74）：节点组成（甲醇质量分数）与 C1、C2（C2 为负值） ----
_W_NODES = (0.243, 0.250, 0.262, 0.280, 0.301, 0.356, 0.403, 0.509)
_C1_NODES = (2.6712, 2.8572, 2.9758, 3.0535, 3.3146, 3.4604, 3.7770, 4.0494)
_C2_NODES = (-3.0602, -3.0344, -2.9531, -2.7278, -2.8197, -2.6219, -2.4256, -2.0194)


def _pchip_end_slope(h0, h1, d0, d1):
    m = ((2.0 * h0 + h1) * d0 - h0 * d1) / (h0 + h1)
    if m * d0 <= 0.0:
        return 0.0
    if d0 * d1 < 0.0 and abs(m) > abs(3.0 * d0):
        return 3.0 * d0
    return m


def _pchip_eval(xs, ys, x):
    """Fritsch-Carlson PCHIP（与 scipy PchipInterpolator 同算法）。"""
    n = len(xs)
    h = [xs[i + 1] - xs[i] for i in range(n - 1)]
    d = [(ys[i + 1] - ys[i]) / h[i] for i in range(n - 1)]
    m = [0.0] * n
    for i in range(1, n - 1):
        if d[i - 1] * d[i] <= 0.0:
            m[i] = 0.0
        else:
            w1 = 2.0 * h[i] + h[i - 1]
            w2 = h[i] + 2.0 * h[i - 1]
            m[i] = (w1 + w2) / (w1 / d[i - 1] + w2 / d[i])
    m[0] = _pchip_end_slope(h[0], h[1], d[0], d[1])
    m[n - 1] = _pchip_end_slope(h[n - 2], h[n - 3], d[n - 2], d[n - 3])
    if x <= xs[0]:
        i = 0
    elif x >= xs[n - 1]:
        i = n - 2
    else:
        lo, hi = 0, n - 1
        while hi - lo > 1:
            mid = (lo + hi) // 2
            if xs[mid] <= x:
                lo = mid
            else:
                hi = mid
        i = lo
    s = (x - xs[i]) / h[i]
    s2, s3 = s * s, s * s * s
    return ((2.0 * s3 - 3.0 * s2 + 1.0) * ys[i]
            + h[i] * (s3 - 2.0 * s2 + s) * m[i]
            + (3.0 * s2 - 2.0 * s3) * ys[i + 1]
            + h[i] * (s3 - s2) * m[i + 1])


def _c1(w):
    return _pchip_eval(_W_NODES, _C1_NODES, w)


def _c2(w):
    return _pchip_eval(_W_NODES, _C2_NODES, w)


def p_bubble_TW(T_K, w):
    """式(3.1)：泡点压力，bar。T_K 开尔文，w 甲醇质量分数（0.243~0.509）。"""
    log10p_mbar = _c1(w) + _c2(w) * (1000.0 / T_K - 2.3)
    return 10.0 ** log10p_mbar / 1000.0


def T_bubble_PW(P_bar, w):
    """式(3.1) 解析反解：泡点温度，K。P_bar 巴，w 甲醇质量分数。"""
    log10p_mbar = math.log10(P_bar * 1000.0)
    return 1000.0 / ((log10p_mbar - _c1(w)) / _c2(w) + 2.3)


def _cp_AB(w):
    A = 0.652 + 2.139 * w - 2.077 * w * w
    B = -0.000205 + 0.00928 * w - 0.0101 * w * w
    return A, B


def cp(T_K, w):
    """式(3.4)：溶液比热，kJ/(kg·K)。t = T_K - 273.15（°C）。"""
    A, B = _cp_AB(w)
    return A + B * (T_K - 273.15)


def h_prime(T_K, w):
    """附录 A：溶液汽化焓 H'（含混合热），kJ/kg。T_K 开尔文（切勿用 °C）。
    仅 w = 0.25~0.356 有效，禁止外推。"""
    A = 2202.6 + 9.24 * T_K - 0.0218 * T_K * T_K
    B = -(4417.8 + 15.53 * T_K - 0.0392 * T_K * T_K)
    C = 3570.0 + 10.81 * T_K - 0.0294 * T_K * T_K
    return A + B * w + C * w * w


def h_liq(T_K, w):
    """溶液比焓，kJ/kg。本文档约定参考态：h_liq(0°C, 任意 w) = 100 kJ/kg，
    h_liq = 100 + A·t + B·t^2/2，t 为 °C（式(3.4) 的解析积分）。"""
    A, B = _cp_AB(w)
    t = T_K - 273.15
    return 100.0 + A * t + B * t * t / 2.0


def h_vap(T_K, w):
    """气相比焓，kJ/kg：h_vap = h_liq + H'（气相为纯甲醇蒸气，
    H' 已含把甲醇从溶液中汽化所需的混合热修正）。"""
    return h_liq(T_K, w) + h_prime(T_K, w)


# ---- 纯甲醇饱和线：Antoine 拟合自论文附录 A 表（见文件头说明） ----
_MEOH_ANT = (8.885298, 2070.3714, 6.3818)  # log10 P[mmHg], T[K]；300~1000 mmHg 内误差 <=0.11%


def meoh_psat_bar(T_K):
    """纯甲醇饱和压力，bar（Antoine，拟合自论文附录 A 数据点）。"""
    A, B, C = _MEOH_ANT
    return (10.0 ** (A - B / (T_K + C))) * 1.3332239e-3


def meoh_Tsat_bar(P_bar):
    """纯甲醇饱和温度，K（上式解析反解）。"""
    A, B, C = _MEOH_ANT
    return B / (A - math.log10(P_bar / 1.3332239e-3)) - C


# ---- 未核实式（仅供存档，勿用于计算；见文件头说明） ----
def density_printed_UNVERIFIED(T_K, w):
    """式(4.10) 按印刷转录：rho = 2.55 - 2.366w - 0.0068t [g/cc]，返回 kg/m3。
    警告：温度系数 0.0068 与论文表 4.2 实测差约 16%，疑应为 0.00068，未核实。"""
    t = T_K - 273.15
    return 1000.0 * (2.55 - 2.366 * w - 0.0068 * t)


def viscosity_eq411_UNVERIFIED(T_K, w):
    """式(4.11) 按 OCR 转录：mu = A·exp(B/T) [cP]，
    A = 2.516 - 5.722w + 3.304w^2，B = -5424 + 22.3009w - 38.558w^2。
    警告：OCR 残损严重（A 疑漏 10^-3 乘子，B 小数点不可靠），数值不可用，
    仅存档待按表 4.3 原始数据重拟合。"""
    A = 2.516 - 5.722 * w + 3.304 * w * w
    B = -5424.0 + 22.3009 * w - 38.558 * w * w
    return A * math.exp(B / T_K)


if __name__ == "__main__":
    # 自检：附录 A 等压温度表（300 mmHg = 0.39997 bar）泡点温度
    print("T_bubble @300mmHg: w=0.250 -> %.2f K (thesis 419.0)" % T_bubble_PW(0.39997, 0.250))
    print("T_bubble @300mmHg: w=0.301 -> %.2f K (thesis 391.4)" % T_bubble_PW(0.39997, 0.301))
    print("T_bubble @300mmHg: w=0.356 -> %.2f K (thesis 380.3)" % T_bubble_PW(0.39997, 0.356))
    # H' 验算点
    print("H'(10C, 0.25)  = %.0f kJ/kg (thesis table 1940)" % h_prime(283.15, 0.25))
    print("H'(10C, 0.356) = %.0f kJ/kg (thesis table 1601)" % h_prime(283.15, 0.356))
    print("H'(100C, 0.25) = %.0f kJ/kg (thesis table 1645)" % h_prime(373.15, 0.25))
    # Cp 验算点（表 3.7）
    print("Cp(51.3C, 0.403) = %.3f (measured 1.27)" % cp(273.15 + 51.3, 0.403))
    print("Cp(69.9C, 0.403) = %.3f (measured 1.30)" % cp(273.15 + 69.9, 0.403))
    print("P_bubble(80C, 0.35) = %.4f bar" % p_bubble_TW(353.15, 0.35))
    print("h_liq(80C, 0.35) = %.1f kJ/kg, h_vap = %.1f kJ/kg"
          % (h_liq(353.15, 0.35), h_vap(353.15, 0.35)))

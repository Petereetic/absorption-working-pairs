#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
nh3_lino3.py -- 氨-硝酸锂 (NH3/LiNO3) 溶液物性参考实现
================================================================
来源: Amaris Castilla, C.F. (2014) 博士论文
"Intensification of NH3 Bubble Absorption Process Using Advanced
Surfaces and Carbon Nanotubes for NH3/LiNO3 Absorption Chillers",
Universitat Rovira i Virgili, 附录 B (pp. A-6 ~ A-8) 转录的关联式:

  泡点压力   Libotean et al. (2007), J. Chem. Eng. Data 52, 1050-1055
             ln P[kPa] = pa(x) + pb(x)/T[K], pa/pb 为 x 的三次多项式
  液体焓     Valles & Salavera (2011, 内部报告), Haltenberger (1939) 法
             H[kJ/kg] = ha(x) + hb(x) T + hc(x) T^2
  比热       Libotean et al. (2008): Cp = cpa(x) + cpb(x) T
  密度       Libotean et al. (2008): rho = 1000 (da(x) + db(x) T)
  导热       Cuenca et al. (2013a): k = ka1 + ka2 T + ka3 T^2 + ka4 x
  结晶界限   Infante Ferreira et al. (1984): XCRIS 十分段多项式
  黏度       Libotean et al. (2008) -- 论文排版残损, 重构式未核实,
             仅 Python 提供并标记 EXPERIMENTAL, C/VBA 不实现

约定
----
* x : 氨质量分数 (小数, 如 0.5), 不是百分数
* T : K (结晶函数 x_cris 的 T 用 °C, 与原文一致)
* p : kPa, h : kJ/kg, cp : kJ/(kg K), rho : kg/m^3, k : W/(m K)

参考态 (焓, 按来源原文)
------------------------
氨的焓以 0 °C 时 0 kJ/kg 为零点; 混合物参考态为 0 °C、氨质量分数 0.5
时 H = 0 kJ/kg。本模块保留来源参考态, 不与本库其他工质对统一。

有效范围 (超出 raise ValueError, 不静默外推)
--------------------------------------------
  psol_TX / T_bubble_PX : T 293.15-353.15 K, x 0.35-0.65
  hsol                     : T 273.15-353.15 K, x 0.35-0.65
                              (下限为参考态温度: 焓式由 Haltenberger 法自
                              273.15 K 积分构造, 参考点按定义精确成立;
                              VLE 数据支撑区间为 293.15-353.15 K)
  cp, rho                   : T 293.15-353.15 K, x 0.35-0.65
  k_therm                   : T 303.15-353.15 K, x 0.35-0.60
  x_cris                    : x 0-1 (原伪代码分支域), T 为 °C

注记
----
* 导热: 论文附录 B 印作 k = ka1 + ka2 T + ka3 T^2 x + ka4 x (ka3 项带 x)。
  本模块按不带额外 x 的读法实现 (ka3 T^2), 两读法在 300 K/x=0.4 处差
  约 3%。详见 公式说明.md。
* x_cris: 原文伪代码 XCRIS = f(TSol[°C], xSol), 以 xSol 分支。本函数
  签名 x_cris(T_C, x); 分支端点归入下限所在段 (原文为严格不等式)。
"""

import math

# ---------------------------------------------------------------------------
# 系数 (逐字转录自论文附录 B; 2026-10-03 pdftotext 提取复核)
# ---------------------------------------------------------------------------

# 泡点压力 Libotean et al. (2007): pa/pb 三次多项式系数 (常数项在前)
_PA = (4.99470524658178, 88.5490906185871, -197.698944465798, 134.938665891525)
_PB = (-1793.21854659273, -22317.1158016582, 61289.3128925447, -45238.5915843719)

# 液体焓 Valles & Salavera (2011): ha/hb/hc 三次多项式系数
_HA = (249.1567745, -1628.297463, -464.3464344, -105.6321057)
_HB = (2.481273559, -5.184392344, -0.775202139, 18.98142102)
_HC = (-0.004240786, 0.025111292, -0.013342843, -0.025956064)

# 比热 Libotean et al. (2008): cpa/cpb 为 x 的一次式 (截距, 斜率)
_CPA = (0.559273057, 3.241167393)      # J/(g K) 基准项
_CPB = (0.00207796, 0.001846907)       # J/(g K^2)

# 密度 Libotean et al. (2008): da/db 为 x 的一次式
_DA = (1.521, -0.4528)
_DB = (-0.00001961, -0.001726)

# 导热 Cuenca et al. (2013a)
_KA1, _KA2, _KA3, _KA4 = 0.446088003, -0.000350326, 2.13849e-07, 0.006538043

# 黏度重构系数 (未核实, 见 mu_visc docstring)
_VA = (1.918, 10.094, -18.394)
_VB = (-1.205, -35.627, 51.529)

# 有效范围
_T_VLE = (293.15, 353.15)   # K (泡点/cp/密度)
_T_H = (273.15, 353.15)     # K (焓: 下限为参考态温度, 见模块头注)
_T_KTH = (303.15, 353.15)   # K (导热)
_X_VLE = (0.35, 0.65)
_X_KTH = (0.35, 0.60)


def _poly(c, x):
    """Horner: c0 + c1 x + c2 x^2 + ..."""
    s = 0.0
    for ci in reversed(c):
        s = s * x + ci
    return s


def _check(T_K, x, t_rng, x_rng, name):
    if not (t_rng[0] <= T_K <= t_rng[1]):
        raise ValueError(f"{name}: T={T_K} K outside {t_rng} K")
    if not (x_rng[0] <= x <= x_rng[1]):
        raise ValueError(f"{name}: x={x} outside {x_rng}")


# ---------------------------------------------------------------------------
# 泡点压力与泡点温度
# ---------------------------------------------------------------------------

def _pa_pb(x):
    return _poly(_PA, x), _poly(_PB, x)


def psol_TX(T_K, x):
    """泡点压力 [kPa]: 温度 T_K [K], 氨质量分数 x 的溶液。

    ln P = pa(x) + pb(x)/T  (Libotean et al. 2007)
    """
    _check(T_K, x, _T_VLE, _X_VLE, "psol_TX")
    pa, pb = _pa_pb(x)
    return math.exp(pa + pb / T_K)


def T_bubble_PX(P_kPa, x):
    """泡点温度 [K]: 压力 P_kPa [kPa], 氨质量分数 x 的溶液。

    解析反解: T = pb / (ln P - pa)。结果须落在 293.15-353.15 K。
    """
    if not (_X_VLE[0] <= x <= _X_VLE[1]):
        raise ValueError(f"T_bubble_PX: x={x} outside {_X_VLE}")
    if P_kPa <= 0.0:
        raise ValueError("T_bubble_PX: P must be > 0")
    pa, pb = _pa_pb(x)
    denom = math.log(P_kPa) - pa
    if denom == 0.0:
        raise ValueError("T_bubble_PX: ln P == pa, no finite solution")
    T_K = pb / denom
    if not (_T_VLE[0] <= T_K <= _T_VLE[1]):
        raise ValueError(
            f"T_bubble_PX: result T={T_K} K outside {_T_VLE} K")
    return T_K


# ---------------------------------------------------------------------------
# 纯氨饱和线 (露点口径, 供 x_by_tsol_tdew 用)
# ---------------------------------------------------------------------------
# LiNO3 不挥发, 气相视为纯氨。本模块自有口径 (见 公式说明.md 滑移图节):
# 纯氨饱和温度由氨水模块 Patek-Klomfar 式 (6) 在氨摩尔分数 = 1 处求得。
# x = 1 时式 (6) 中 (1-x)^m 只剩 m = 0 项, 故纯氨端点为 L 的四次多项式:
#   T_sat[K] = 100 * sum_i a_i L^i,  L = ln(2 MPa / P)
# 系数即式 (6) 系数表 m = 0 的五行 (a: 3.22302, -0.384206, 0.0460965,
# -0.00378945, 0.000135610)。式 (6) 辖区 P = 0.002-2 MPa。

_PK6_PURE = (3.22302, -0.384206, 0.0460965, -0.00378945, 0.000135610)


def _Tsat_NH3_pure(P_kPa):
    """纯氨饱和温度 [K] (Patek-Klomfar 式 (6) 纯氨端点)。P_kPa 为 kPa。"""
    L = math.log(2.0 / (P_kPa / 1000.0))
    s = 0.0
    for a in reversed(_PK6_PURE):
        s = s * L + a
    return 100.0 * s


def _pref_NH3_pure(T_K):
    """纯氨饱和压力 [kPa]: 二分 80 次反解 _Tsat_NH3_pure(P) = T_K。

    辖区 P = 2-2000 kPa (式 (6)); T_K 落在该压力跨度之外时返回 None。
    """
    lo, hi = 2.0, 2000.0
    if not (_Tsat_NH3_pure(lo) <= T_K <= _Tsat_NH3_pure(hi)):
        return None
    for _ in range(80):
        mid = 0.5 * (lo + hi)
        if _Tsat_NH3_pure(mid) < T_K:
            lo = mid
        else:
            hi = mid
    return 0.5 * (lo + hi)


def x_by_tsol_tdew(Tsol_K, Tdew_K):
    """由露点温度与溶液温度反解氨质量分数 x。

    露点定压: P = _pref_NH3_pure(Tdew_K) (纯氨饱和压, 口径见上);
    再二分 80 次反解 psol_TX(Tsol_K, x) = P, 括号取泡点函数
    有效浓度域 x = 0.35-0.65 (泡点压力在该域内随 x 单调增)。
    无根时返回 None (P 落在 Tsol 下泡点压力跨度之外, 如溶液温度
    明显低于露点温度; 或 Tdew_K 超出纯氨式 (6) 辖区)。注意本函数
    按跨工质对统一约定返回 None, 不沿用本模块其余函数的
    raise ValueError 约定。
    """
    P = _pref_NH3_pure(Tdew_K)
    if P is None:
        return None
    if not (_T_VLE[0] <= Tsol_K <= _T_VLE[1]):
        return None
    Plo = psol_TX(Tsol_K, _X_VLE[0])
    Phi = psol_TX(Tsol_K, _X_VLE[1])
    if not (Plo <= P <= Phi):
        return None
    lo, hi = _X_VLE
    for _ in range(80):
        mid = 0.5 * (lo + hi)
        if psol_TX(Tsol_K, mid) < P:
            lo = mid
        else:
            hi = mid
    return 0.5 * (lo + hi)


# ---------------------------------------------------------------------------
# 液体焓 / 比热 / 密度 / 导热
# ---------------------------------------------------------------------------

def hsol(T_K, x):
    """溶液比焓 [kJ/kg] (Valles & Salavera 2011, Haltenberger 法)。

    H = ha(x) + hb(x) T + hc(x) T^2, T 为 K。
    参考态: 0 °C、x=0.5 时 H = 0 (来源原文, 与本库其他工质对不同)。
    """
    _check(T_K, x, _T_H, _X_VLE, "hsol")
    ha = _poly(_HA, x)
    hb = _poly(_HB, x)
    hc = _poly(_HC, x)
    return ha + hb * T_K + hc * T_K * T_K



def tdew_from_tsol_x(T_K, x):
    """溶液在 (T_K, x) 的露点温度 [K]（全库 TdewByTsolXi 约定）：
        Tdew = _Tsat_NH3_pure(psol_TX(T_K, x))，
    即以本模块自有纯氨线（Pátek–Klomfar 式 (6) 纯氨端点）评价溶液
    表面压力 Psol 所对应的饱和温度。LiNO₃ 不挥发，气相视为纯氨，
    无端点约定问题。辖区随 psol_TX（T 293.15–353.15 K，
    x 0.35–0.65），越界时 psol_TX 的 ValueError 照常抛出。"""
    return _Tsat_NH3_pure(psol_TX(T_K, x))


def tsol_by_hsol(h, x):
    """由溶液比焓 h [kJ/kg] 与氨质量分数 x 反解溶液温度 [K]：
    hsol 在固定 x 下随 T 单调增（cp > 0），二分 100 次反解，
    求解括号取 hsol 辖区 T ∈ [273.15, 353.15] K（_T_H）。
    h 超出该 x 下 hsol 值域时返回 None；x 越界时 hsol 的
    ValueError 照常抛出。"""
    lo, hi = 273.15, 353.15
    hlo, hhi = hsol(lo, x), hsol(hi, x)
    if not (hlo <= h <= hhi):
        return None
    for _ in range(100):
        mid = 0.5 * (lo + hi)
        if hsol(mid, x) < h:
            lo = mid
        else:
            hi = mid
    return 0.5 * (lo + hi)


def cp(T_K, x):
    """溶液比热 [kJ/(kg K)] (Libotean et al. 2008)。

    原文 Cp 单位 J/(g K): Cp = cpa(x) + cpb(x) T; 数值与 kJ/(kg K) 相同。
    """
    _check(T_K, x, _T_VLE, _X_VLE, "cp")
    cpa = _CPA[0] + _CPA[1] * x
    cpb = _CPB[0] + _CPB[1] * x
    return cpa + cpb * T_K


def rho(T_K, x):
    """溶液密度 [kg/m^3] (Libotean et al. 2008)。

    rho = 1000 * (da(x) + db(x) T), T 为 K。
    """
    _check(T_K, x, _T_VLE, _X_VLE, "rho")
    da = _DA[0] + _DA[1] * x
    db = _DB[0] + _DB[1] * x
    return 1000.0 * (da + db * T_K)


def k_therm(T_K, x):
    """溶液导热系数 [W/(m K)] (Cuenca et al. 2013a)。

    k = ka1 + ka2 T + ka3 T^2 + ka4 x。
    注: 论文附录 B 印作 ka3 T^2 x (ka3 项带 x); 本实现按不带额外 x
    的读法, 两读法差约 3%, 详见 公式说明.md。
    """
    _check(T_K, x, _T_KTH, _X_KTH, "k_therm")
    return _KA1 + _KA2 * T_K + _KA3 * T_K * T_K + _KA4 * x


# ---------------------------------------------------------------------------
# 结晶界限 (Infante Ferreira et al. 1984, 附录 B 伪代码逐字转录)
# ---------------------------------------------------------------------------

def x_cris(T_C, x):
    """结晶界限量 XCRIS (Infante Ferreira et al. 1984)。

    原文伪代码: XCRIS = f(TSol[°C], xSol), 以溶液氨质量分数 xSol 分支,
    每段为 T[°C] 的多项式。本函数逐字转录十分段; 分支端点归入下限
    所在段 (原文为严格不等式)。x 须在 [0, 1] 内。
    XCRIS 的物理量纲按原文伪代码照录, 使用时与状态点比较的方法
    参见 Infante Ferreira et al. (1984) 原始报告。
    """
    T = T_C
    if x < 0.2911:
        return 0.3021 - 0.00034 * T - 0.00000272 * T * T
    if x < 0.3:
        return x
    if x < 0.3076:
        return -0.000608 * T + 0.3152
    if x < 0.3362:
        return 0.0143 * T + 0.12885
    if x < 0.4304:
        return -0.005402 * T + 0.41318
    if x < 0.5072:
        return 0.443413 + 0.0069 * T + 0.000854 * T * T
    if x < 0.6434:
        return 0.527643 - 0.003126 * T - 0.000019 * T * T
    if x < 0.6649:
        return -0.004605 * T + 0.40761
    if x < 0.7826:
        return 0.0000309 * T * T + 0.57452
    if x <= 1.0:
        return 0.07378 * T + 6.7214
    raise ValueError(f"x_cris: x={x} outside [0, 1]")


# ---------------------------------------------------------------------------
# 黏度 (EXPERIMENTAL / UNVERIFIED -- 仅 Python, C/VBA 不实现)
# ---------------------------------------------------------------------------

def mu_visc(T_K, x):
    """动力黏度 [mPa s] -- **实验性重构, 未核实, 勿用于工程计算**。

    论文附录 B 的黏度式排版残损 (原文呈 "Sol = e^(1000 va / vb / T)"
    的堆叠形式, 算符丢失)。本函数按数值合理性重构为
        mu = exp(va(x) * 1000 / T + vb(x)),
        va = 1.918 + 10.094 x - 18.394 x^2,
        vb = -1.205 - 35.627 x + 51.529 x^2,
    抽检: x=0.45 时 313.15 K -> 约 6.9 mPa s, 293.15 K -> 约 12.6 mPa s
    (量级合理)。入库前必须对照 Libotean et al. (2008),
    J. Chem. Eng. Data 53, 2383-2388 原文核实。
    """
    va = _poly(_VA, x)
    vb = _poly(_VB, x)
    return math.exp(va * 1000.0 / T_K + vb)

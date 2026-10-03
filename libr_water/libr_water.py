#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
libr_water.py -- 溴化锂水溶液物性参考实现 (Patterson + Chua 混合)
================================================================
Patterson, M.R. & Perez-Blanco, H. (1988)
"Numerical fits of the properties of lithium-bromide water solutions",
ASHRAE Transactions 94(2), pp. 2059-2077 (paper OT-88-20-2).
  7 个显式多项式函数: 焓 HLIBR, 露点 TDEW, 蒸气压 PRESS,
  导热 TCON, 黏度 VISCOS, 密度 SPMASS, 表面张力 STEN。
  统一形式: F(X,T) = Σ_{i=0..K} X^i·(A_i + T·A_{i+K+1} + T²·A_{i+2K+2}),
  X = LiBr 重量百分数(数字,如 50), T = °C。

Chua, H.T. et al. (2000)
"Improved thermodynamic property fields of LiBr-H2O solution",
Int. J. Refrigeration 23, 412-429.
  Dühring 蒸气压方程 (Table 1, 42 系数) + 密度关联式 (Table 2, 15 系数),
  范围 0-190°C / 0-75 wt%, 作为高浓度高温段升级选项。

约定
----
* X : LiBr 重量百分数(数字, 0-100,如 50), 不是小数
* T : °C (与 Patterson 原文一致)
* 返回 SI: h kJ/kg, p Pa, lambda W/(m K), eta Pa s,
  rho kg/m^3, sigma N/m ; t_dew / crystallization_T 为 °C

范围与结晶检查
--------------
每个函数先做两项检查,不通过则 raise ValueError(不静默外推):
1. 结晶/未知区检查: Patterson 附录 XN/TN 折线(冰点)与 XUNKN/TUNKN
   折线(未知区),逻辑逐行移植自 Fortran 原代码。
2. 各函数拟合有效范围 (见各函数 docstring)。

2026-10-01 转录自原文 200 dpi 渲染页逐字核对。
注意:
* PRESS 正文说输入 °F/输出 psia,代码实际取 °C 输入、返回 Pa
  (×6894.757),以代码为准;注释 "Horacio says is DEG F" 亦存疑。
* TCON 的 TUNKN 印为华氏度数值 (260/280/320/360) 却与 °C 的 T 比较,
  使其未知区检查恒不触发 —— 按原文照录。
* STEN 并非特殊 K=4 多项式,仍是标准双循环 (KUP=5, 15 系数)。
* 参考态: h(0%, 25°C) = 104.615 kJ/kg ⟹ 纯水 0°C 饱和液体 h=0
  (由系数算得;论文未明示,引自 McNeely 1979 数据基准)。
"""

import math

# --------------------------------------------------------------------------
# 结晶边界表 (Patterson 附录, 7 个函数通用; TCON 的 TUNKN 见注)
# --------------------------------------------------------------------------
_XN = [57.5, 62.5, 62.5, 67.5, 67.5, 100.0, 100.0]   # wt%
_TN = [0.0, 10.0, 40.0, 50.0, 90.0, 100.0, 180.0]     # °C
_XUNKN = [0.0, 37.5, 51.5, 60.5]                       # wt%
_TUNKN = [126.7, 137.8, 160.0, 182.2]                  # °C
_TUNKN_TCON_F = [260.0, 280.0, 320.0, 360.0]           # TCON 按原文照录(°F 数值)


def _check_region(X, T, func_name, check_unknown=True, tunkn=None):
    """Patterson 结晶/未知区检查。返回 None; 不通过则 raise ValueError。

    逻辑逐行对应 Fortran:
      冰点折线: T<=TN[N] 的首个 N 处内插 XSTAR; X>=XSTAR → 结晶区
      T>180 → "TEMPERATURE HIGHER THAN TABLE ALLOWS" 警告后继续未知区检查
      未知区折线: T<=TUNKN[N] 的首个 N 处内插 XSTAR; X<=XSTAR → 未知区
    HLIBR 冰点通过后仍做未知区检查; 其余函数冰点通过后直接计算
    (check_unknown=False), 但 T>180 时一律走未知区检查。
    """
    if tunkn is None:
        tunkn = _TUNKN
    # --- 冰点检查 ---
    star = None
    for n in range(1, 7):
        if T > _TN[n]:
            continue
        if _XN[n] == _XN[n - 1]:
            xstar = _XN[n]
        else:
            xstar = (_XN[n - 1] + (T - _TN[n - 1]) / (_TN[n] - _TN[n - 1])
                     * (_XN[n] - _XN[n - 1]))
        star = xstar
        break
    if star is None:
        # T > 180: 原代码打印警告后继续未知区检查
        pass
    elif X >= star:
        raise ValueError(
            "%s: 点 (X=%.2f%%, T=%.2f°C) 在结晶区内 (冰点浓度 X*=%.2f%%)"
            % (func_name, X, T, star))
    elif not check_unknown:
        return  # 其余函数: 冰点通过 → 直接计算
    # --- 未知区检查 ---
    for n in range(1, 4):
        if T > tunkn[n]:
            continue
        if _XUNKN[n] == _XUNKN[n - 1]:
            xstar = _XUNKN[n]
        else:
            xstar = (_XUNKN[n - 1]
                     + (T - tunkn[n - 1]) / (tunkn[n] - tunkn[n - 1])
                     * (_XUNKN[n] - _XUNKN[n - 1]))
        if X <= xstar:
            raise ValueError(
                "%s: 点 (X=%.2f%%, T=%.2f°C) 在未知区内 (X*<=%.2f%% 无数据)"
                % (func_name, X, T, xstar))
        return
    # T > TUNKN[3]: 原代码落入 150 → 未知区
    raise ValueError(
        "%s: T=%.2f°C 超过未知区表上限 (%.1f°C),无数据" % (func_name, T, tunkn[3]))


def _poly(X, T, A, kup):
    """统一多项式: Σ_{i=0..K} X^i·(A_i + T·A_{i+K+1} + T²·A_{i+2K+2})。
    A 为 0-based 列表, kup = K+1。"""
    K = kup - 1
    s = 0.0
    xk = 1.0
    for i in range(kup):
        if i > 0:
            xk *= X
        s += xk * (A[i] + T * (A[i + kup] + T * A[i + 2 * kup]))
    return s


# --------------------------------------------------------------------------
# Patterson 系数表 (DATA 语句顺序, 0-based)
# --------------------------------------------------------------------------
# HLIBR: 焓 kJ/kg, KUP=6
_A_H = [
    1.134125e+00, -4.800450e-01, -2.161438e-03, 2.336235e-04,
    -1.188679e-05, 2.291532e-07, 4.124891e+00, -7.643903e-02,
    2.589577e-03, -9.500522e-05, 1.708026e-06, -1.102363e-08,
    5.743693e-04, 5.870921e-05, -7.375319e-06, 3.277592e-07,
    -6.062304e-09, 3.901897e-11,
]
# TDEW: 露点 °C (多项式内用 °F, 返回前转回 °C), KUP=6
_A_TDEW = [
    -1.313448e-01, 1.820914e-01, -5.177356e-02, 2.827426e-03,
    -6.380541e-05, 4.340498e-07, 9.967944e-01, 1.778069e-03,
    -2.215597e-04, 5.913618e-06, -7.308556e-08, 2.788472e-10,
    1.978788e-05, -1.779481e-05, 2.002427e-06, -7.667546e-08,
    1.201525e-09, -6.641716e-12,
]
# TCON: 导热 kcal/(h·m·°C), KUP=5
_A_TC = [
    4.815196e-01, -2.217277e-03, -1.994141e-05, 3.727255e-07,
    -2.489886e-09, 1.858174e-03, 9.614755e-06, -1.139291e-06,
    2.107608e-08, -1.330532e-10, -7.923126e-06, -1.869392e-07,
    1.408951e-08, -2.740806e-10, 1.810818e-12,
]
# VISCOS: 黏度 cP, KUP=6
_A_VIS = [
    1.488747e+00, 1.143975e-01, -1.278729e-02, 6.999985e-04,
    -1.638074e-05, 1.456348e-07, -4.164814e-02, 9.636832e-04,
    -5.981025e-05, -1.282435e-07, 5.703002e-08, -9.842266e-10,
    3.404030e-04, -2.794515e-05, 2.580301e-06, -9.737750e-08,
    1.585609e-09, -7.922925e-12,
]
# SPMASS: 密度 kg/L, KUP=5
_A_RHO = [
    9.939006e-01, 1.046888e-02, -1.667939e-04, 5.332835e-06,
    -3.440005e-08, -5.631094e-04, 1.633541e-05, -1.110273e-06,
    2.882292e-08, -2.523579e-10, 1.392527e-06, -2.801009e-07,
    1.734979e-08, -4.232988e-10, 3.503024e-12,
]
# STEN: 表面张力 dyne/cm, KUP=5
_A_SIG = [
    7.626234e+01, 4.583900e-01, -1.463071e-02, 3.834735e-04,
    -2.733854e-06, -1.507474e-01, -9.057263e-03, 4.459087e-04,
    -9.542318e-06, 6.610416e-08, -1.107075e-05, 7.238986e-05,
    -3.822731e-06, 8.077592e-08, -5.681625e-10,
]


def _range_check(X, T, func_name, x_lo, x_hi, t_lo, t_hi):
    if not (x_lo <= X <= x_hi and t_lo <= T <= t_hi):
        raise ValueError(
            "%s: (X=%.2f%%, T=%.2f°C) 超出拟合范围 X∈[%.g,%.g%%], T∈[%.g,%.g°C]"
            % (func_name, X, T, x_lo, x_hi, t_lo, t_hi))


# --------------------------------------------------------------------------
# 公开函数 (Patterson)
# --------------------------------------------------------------------------
def h_libr(X, T):
    """溶液比焓 [kJ/kg]; X wt%, T °C。范围: X∈(0,70), T∈(0,180)。"""
    _range_check(X, T, 'h_libr', 0, 70, 0, 180)
    _check_region(X, T, 'h_libr', check_unknown=True)
    return _poly(X, T, _A_H, 6)


def _tdew_poly(X, T):
    """TDEW 内部多项式 (°F 输入, 返回 °F), 不含结晶检查。"""
    TF = 9.0 / 5.0 * T + 32.0
    return _poly(X, TF, _A_TDEW, 6)


def t_dew(X, T):
    """露点温度 [°C]; X wt%, T °C(溶液温度)。范围: X∈(0,70), T∈(4.4,182.2)。"""
    _range_check(X, T, 't_dew', 0, 70, 4.4, 182.2)
    _check_region(X, T, 't_dew', check_unknown=False)
    return 5.0 / 9.0 * (_tdew_poly(X, T) - 32.0)


def p_sat(X, T):
    """水蒸气分压 [Pa] (Patterson PRESS); X wt%, T °C。
    先由 TDEW 多项式求露点(°F), 再 log10 P[psia]=6.21147-2886.373/TR-337269.46/TR²
    (TR 为 °R), ×6894.757 → Pa。"""
    _range_check(X, T, 'p_sat', 0, 70, 4.4, 182.2)
    _check_region(X, T, 'p_sat', check_unknown=False)
    tdew_f = _tdew_poly(X, T)
    TR = tdew_f + 459.7
    return 10.0 ** (6.21147 - 2886.373 / TR - 337269.46 / TR ** 2) * 6894.757


def lambda_libr(X, T):
    """导热系数 [W/(m K)]; X wt%, T °C。原文 kcal/(h·m·°C)×1.163。"""
    _range_check(X, T, 'lambda_libr', 0, 70, 4.4, 182.2)
    _check_region(X, T, 'lambda_libr', check_unknown=False,
                  tunkn=_TUNKN_TCON_F)
    return _poly(X, T, _A_TC, 5) * 1.163


def eta_libr(X, T):
    """动力黏度 [Pa s]; X wt%, T °C。原文 cP×1e-3。范围: X∈(5,60), T∈(0,90)。"""
    _range_check(X, T, 'eta_libr', 5, 60, 0, 90)
    _check_region(X, T, 'eta_libr', check_unknown=False)
    return _poly(X, T, _A_VIS, 6) * 1e-3


def rho_libr(X, T):
    """密度 [kg/m^3]; X wt%, T °C。原文 kg/L×1000。范围: X∈(10,60), T∈(0,100)。"""
    _range_check(X, T, 'rho_libr', 10, 60, 0, 100)
    _check_region(X, T, 'rho_libr', check_unknown=False)
    return _poly(X, T, _A_RHO, 5) * 1000.0


def sigma_libr(X, T):
    """表面张力 [N/m]; X wt%, T °C。原文 dyne/cm×1e-3。范围: X∈(5,60), T∈(0,60)。"""
    _range_check(X, T, 'sigma_libr', 5, 60, 0, 60)
    _check_region(X, T, 'sigma_libr', check_unknown=False)
    return _poly(X, T, _A_SIG, 5) * 1e-3


def crystallization_T(X):
    """结晶温度 [°C]: 浓度 X wt% 对应的冰点折线温度。
    X<57.5% 在表范围内无结晶边界, 返回 NaN。"""
    if X < 57.5:
        return float('nan')
    if X > 100:
        raise ValueError("crystallization_T: X=%.2f%% 超出 100%%" % X)
    # 冰点折线 XN/TN: 取 X=XSTAR(T) 的最高 T (垂直段取上端点)
    best = None
    for n in range(1, 7):
        x0, x1 = _XN[n - 1], _XN[n]
        t0, t1 = _TN[n - 1], _TN[n]
        if x0 == x1:
            if X == x0:
                best = t1 if best is None else max(best, t1)
        elif min(x0, x1) <= X <= max(x0, x1):
            t = t0 + (X - x0) / (x1 - x0) * (t1 - t0)
            best = t if best is None else max(best, t)
    return best


# --------------------------------------------------------------------------
# Chua 2000: Dühring 蒸气压 (Table 1) + 密度 (Table 2)
# Table 1 系数转录自原文 p.417 (200 dpi 逐字核对), 另见下文注记。
# --------------------------------------------------------------------------
# A_D(x) = Σ_{i=0}^{16} A_i x^i + Σ_{i=17}^{20} A_i ⟨x-60⟩^i, ⟨y⟩=max(y,0)
# B_D(x) 同式。(T-273.15) = A_D·(T_dp-273.15) + B_D(x)
_DUHR_A = [
    1.0,
    2.92242e-04, 1.05207e-04, 8.86101e-07, -2.71833e-06, 3.52718e-07,
    -2.03849e-08, 5.68810e-10, -4.32385e-12, -1.42122e-13, 2.37604e-15,
    3.96440e-17, -9.81319e-19, -7.91591e-21, 3.92677e-22, -4.04965e-24,
    1.41694e-26,
    6.51878e-03, -2.57030e-04, 2.43912e-05, -6.86236e-08,
]
_DUHR_B = [
    0.0,
    5.22677e-02, -9.78477e-03, 7.82919e-03, -1.62913e-03, 1.64050e-04,
    -8.98817e-06, 2.62640e-07, -2.95400e-09, -3.23145e-11, 7.67888e-13,
    1.36662e-14, -3.12628e-16, -4.91441e-18, 1.87723e-19, -1.92463e-21,
    6.87629e-24,
    1.93956e+00, 8.22588e-02, -1.04537e-02, 4.09856e-04,
]
# 注记 (转录核对发现, 均经原文 Fig.1/Fig.2 曲线数值验证):
#  * B_12 原文印刷无负号 ("3.12628E-16"), 但取负时 B_D 方能复现 Fig.2
#    (B_D(30)=4.52 vs  Fig.2 ~4.5; 取正得 336.8, 明显印刷漏负号)。
#    此处取 -3.12628E-16。
#  * B_14 印刷为 "1.87723B-19" (指数位的 B 系字形), 读作 1.87723E-19。
#  * A_10 印刷为 "2.37604E.15", 按指数序列与量级读作 2.37604E-15。
#  * ⟨x-60⟩ 修正项 (i=17..20) 按印刷值在 x>60 时发散
#    (A_D(65)=4.45e9, Fig.1 应 ~1.225), 无法复现原文曲线,
#    故 p_sat_chua 限 x≤60%。60-75% 段原文自称外推, 此处不实现。
#
# Table 2 密度: ρ = Σ_{k=1..5} x^{k-1}[G_{0,k}+T(G_{1,k}+T G_{2,k})],
# x wt%, T °C, ρ kg/m³。G[k] = [G_{0,k},G_{1,k},G_{2,k}] (k=1..5)。
# (i=1,j=4) 印刷为 "-9.08213EB-06", 读作 -9.08213E-06。
_G_RHO_CHUA = [
    [9.99100e+02, -2.39865e-02, -3.90453e-03],
    [7.74931e+00, -1.28346e-02, -5.55855e-05],
    [5.36509e-03, 2.07232e-04, 1.09879e-05],
    [1.34988e-03, -9.08213e-06, -2.39834e-07],
    [-3.08671e-06, 9.94788e-08, 1.53514e-09],
]


def _wagner_psat_water(T_C):
    """纯水饱和蒸气压 [Pa], T °C。Wagner 方程 (IAPWS-95 配套形式,
    Wagner & Pruss 1993):
    ln(p/pc) = (Tc/T)·Σ a_i·θ^e_i, θ = 1-T/Tc。
    Chua 原文用 Haar(1984) NBS/NRC 蒸汽表, 此处等效替代。"""
    T = T_C + 273.15
    Tc = 647.096
    Pc = 22.064e6
    theta = 1.0 - T / Tc
    a = (-7.85951783, 1.84408259, -11.7866497,
         22.6807411, -15.9618719, 1.80122502)
    e = (1.0, 1.5, 3.0, 3.5, 4.0, 7.5)
    s = sum(ai * theta ** ei for ai, ei in zip(a, e))
    return Pc * math.exp((Tc / T) * s)


def p_sat_chua(X, T):
    """水蒸气分压 [Pa] (Chua Dühring); X wt%, T °C。范围: 0-190°C, 0-60%。

    (T-273.15) = A_D(x)·(T_dp-273.15) + B_D(x), T/T_dp 为 K;
    由 T_dp 经 Wagner 方程求纯水 Psat 即得溶液蒸气压 (LiBr 不挥发)。
    x>60% 的 ⟨x-60⟩ 修正项按原文印刷值无法复现 Fig.1/2, 故不实现。"""
    if not (0 <= X <= 60 and 0 <= T <= 190):
        raise ValueError("p_sat_chua: (X=%.2f%%, T=%.2f°C) 超出范围 [0-60%%, 0-190°C]"
                         % (X, T))
    x = X
    AD = sum(a * x ** i for i, a in enumerate(_DUHR_A[:17]))
    BD = sum(b * x ** i for i, b in enumerate(_DUHR_B[:17]))
    # T_C = AD*Tdp_C + BD  →  Tdp_C = (T_C-BD)/AD
    Tdp_C = (T - BD) / AD
    return _wagner_psat_water(Tdp_C)


def rho_chua(X, T):
    """密度 [kg/m^3] (Chua Table 2); X wt%, T °C。范围: 0-200°C, 0-70%。

    ρ = Σ_{k=1..5} x^{k-1}·[G_{0,k} + T·(G_{1,k} + T·G_{2,k})]"""
    if not (0 <= X <= 70 and 0 <= T <= 200):
        raise ValueError("rho_chua: (X=%.2f%%, T=%.2f°C) 超出范围" % (X, T))
    G = _G_RHO_CHUA  # 5×3: G[k][0..2] = G_{0,k},G_{1,k},G_{2,k}
    s = 0.0
    xk = 1.0
    for k in range(5):
        if k > 0:
            xk *= X
        s += xk * (G[k][0] + T * (G[k][1] + T * G[k][2]))
    return s


if __name__ == '__main__':
    # 快速自检
    print('h(0%%,25°C) = %.3f kJ/kg (期望 ~104.6)' % h_libr(0.0, 25.0))
    print('rho(60%%,25°C) = %.1f kg/m³ (期望 ~1700)' % rho_libr(60.0, 25.0))
    print('eta(60%%,25°C) = %.2f mPa·s (期望 ~10 量级)' % (eta_libr(60.0, 25.0) * 1e3))
    print('p_sat(50%%,80°C) = %.0f Pa' % p_sat(50.0, 80.0))
    print('t_dew(50%%,80°C) = %.2f °C' % t_dew(50.0, 80.0))
    print('lambda(50%%,80°C) = %.4f W/(m K)' % lambda_libr(50.0, 80.0))
    print('sigma(50%%,25°C) = %.1f mN/m' % (sigma_libr(50.0, 25.0) * 1e3))
    print('T_cryst(60%%) = %.1f °C' % crystallization_T(60.0))
    print('T_cryst(65%%) = %.1f °C' % crystallization_T(65.0))

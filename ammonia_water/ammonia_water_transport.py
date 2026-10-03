#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
ammonia_water_transport.py -- 输运物性参考实现
=================================================
M. Conde Engineering (2004)
"Thermophysical Properties of NH3 + H2O Solutions for the Industrial
Design of Absorption Refrigeration Equipment", 第 5~15 章 + 附录 A/B/C。

第 4 章(VLE+焓, Patek & Klomfar 1995)见同目录 ammonia_water.py。

约定
----
* x : 液相氨摩尔分数 ; y : 气相氨摩尔分数
* T : K ; p : MPa(本模块内部按需换算) ; pc_sol 返回 bar(书中单位)
* 返回值均为 SI: cp kJ/(kg K), lambda W/(m K), eta Pa s,
  sigma N/m, rho kg/m^3, D m^2/s ; pc_sol 为 bar(书中原单位)

气相函数取 (T, y), T 为气相温度。饱和态下 T 取对应露点温度
(用 ammonia_water.py 的 T_dew_P_y 求), 文档中给出调用示例。

拟对应状态温度(§6~§10, §14):
    theta = T_sol / T_c,sol(x)
    T*_NH3 = theta * T_c,NH3 ; T*_H2O = theta * T_c,H2O
纯组分物性在各自 T* 下求值,再按摩尔分数加权(+超额项)。

2026-10-01 转录自 Conde 2004 全文核对。
注意:
* §13 正文"Appendix A"为笔误,水蒸气黏度实为附录 B(IAPWS 黏度);
  §12 正文"Appendix B"为笔误,水蒸气导热实为附录 A(IAPWS 导热)。
* 附录 C 的 Δη(ρ,T) 式中内层求和印刷为 ρ,按 Fenghour 原文及
  Table 5 列标 dη_{2,j},dη_{3,j},dη_{4,j} 应为 ρ^i(i=2,3,4);
  另按 ρ 实现与图 12 差一个量级,已用图 12 验证 ρ^i 正确。
* 附录 C 的 Δηc(临界增强项)书中未给系数,按书中说明取 0。
"""

import math

# --------------------------------------------------------------------------
# 临界常数(PDF p9 表)
# --------------------------------------------------------------------------
T_C_NH3 = 405.4          # K
T_C_H2O = 647.14         # K
P_C_NH3 = 113.336        # bar
P_C_H2O = 220.64         # bar
RHO_C_NH3 = 225.0        # kg/m^3
RHO_C_H2O = 322.0        # kg/m^3
M_NH3 = 17.03026         # kg/kmol
M_H2O = 18.015268        # kg/kmol

# --------------------------------------------------------------------------
# §5 溶液临界温度/压力: x 的四次多项式(Sassen et al. 1990 数据拟合)
# --------------------------------------------------------------------------
_A_TC = [647.14, -199.822371, 109.035522, -239.626217, 88.689691]
_B_PC = [220.64, -37.923795, 36.424739, -41.851597, -63.805617]


def tc_sol(x):
    """溶液临界温度 [K], x = 氨摩尔分数。"""
    return sum(a * x ** i for i, a in enumerate(_A_TC))


def pc_sol(x):
    """溶液临界压力 [bar], x = 氨摩尔分数。"""
    return sum(b * x ** i for i, b in enumerate(_B_PC))


def _tstar(T, x):
    """对应状态温度 (T*_NH3, T*_H2O)。"""
    theta = T / tc_sol(x)
    return theta * T_C_NH3, theta * T_C_H2O


# --------------------------------------------------------------------------
# 附录 A: IAPWS 水导热系数(工业用公式, IAPWS 1998)
# --------------------------------------------------------------------------
# Table 1, L[i][j]: i=0..3, j=0..5
_L = [
    [0.0102811, 0.0299621, 0.0156146, -0.00422464, 0.0, 0.0],       # i=0
    [-0.397070, 0.400302, 1.060000, -0.171587, 2.392190, 0.0],      # i=1
    [0.0701309, 0.0118520, 0.00169937, -1.0200, 0.0, 0.0],          # i=2
    [0.642857, -4.11717, -6.17937, 0.00308976, 0.0822994, 10.0932], # i=3
]
_TSTAR_W = 647.26       # K
_RHOSTAR_W = 317.7      # kg/m^3
_LAMSTAR_W = 1.0        # W/(m K)


def _iapws_lambda_water(T, rho):
    """水导热系数 [W/(m K)], T[K], rho[kg/m^3]。
    IAPWS 1998 工业用公式: λ = λ0(T̄) + λ1(ρ̄) + λ2(T̄,ρ̄)。
    注意: Conde 书中总式印刷为 λ̄0×λ̄1×λ̄2,系排印错误。
    乘法在稀薄气体极限(ρ̄→0)给出 λ→0,物理上不成立;
    唯有加法给出 298.15K/998kg/m^3 = 0.6077 W/(m K) 的验证值,
    与 IAPWS 原文及 XSteam 实现一致。"""
    Tb = T / _TSTAR_W
    rb = rho / _RHOSTAR_W
    lam0 = math.sqrt(Tb) * sum(_L[0][j] * Tb ** j for j in range(4))
    lam1 = (_L[1][0] + _L[1][1] * rb
            + _L[1][2] * math.exp(_L[1][3] * (rb + _L[1][4]) ** 2))
    dTb = abs(Tb - 1.0) + _L[3][3]
    Lam0 = 1.0 / dTb if Tb >= 1.0 else _L[3][5] / dTb ** 0.6
    Lam1 = 2.0 + _L[3][4] / dTb ** 0.6
    term1 = (_L[2][0] / Tb ** 10 + _L[2][1]) * rb ** 1.8 \
        * math.exp(_L[3][0] * (1.0 - rb ** 2.8))
    term2 = _L[2][2] * Lam0 * rb ** Lam1 \
        * math.exp((Lam1 / (1.0 + Lam1)) * (1.0 - rb ** (1.0 + Lam1)))
    term3 = _L[2][3] * math.exp(_L[3][1] * Tb ** 1.5 + _L[3][2] / rb ** 5)
    lam2 = term1 + term2 + term3
    return _LAMSTAR_W * (lam0 + lam1 + lam2)


# --------------------------------------------------------------------------
# 附录 B: IAPWS 水动力黏度(工业用公式), η2 取 1(书中说明)
# --------------------------------------------------------------------------
_H = [1.000, 0.978197, 0.579829, -0.202354]
# Table 3, G[i][j]: i=0..5, j=0..6
_G = [
    [0.5132047, 0.2151778, -0.2818107, 0.1778064, -0.0417661, 0.0, 0.0],
    [0.3205656, 0.7317883, -1.070786, 0.4605040, 0.0, -0.01578386, 0.0],
    [0.0, 1.241044, -1.263184, 0.2340379, 0.0, 0.0, 0.0],
    [0.0, 1.476783, 0.0, -0.4924179, 0.1600435, 0.0, -0.003629481],
    [-0.7782567, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
    [0.1885447, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
]
_TSTAR_V = 647.226      # K
_RHOSTAR_V = 317.763    # kg/m^3
_ETASTAR_V = 55.071e-6  # Pa s


def _iapws_eta_water(T, rho):
    """水动力黏度 [Pa s], T[K], rho[kg/m^3]。"""
    Tb = T / _TSTAR_V
    rb = rho / _RHOSTAR_V
    eta0 = math.sqrt(Tb) / sum(_H[i] * Tb ** (-i) for i in range(4))
    s = 0.0
    ti = 1.0 / Tb - 1.0
    rm = rb - 1.0
    for i in range(6):
        for j in range(7):
            g = _G[i][j]
            if g:
                s += g * ti ** i * rm ** j
    eta1 = math.exp(rb * s)
    return _ETASTAR_V * eta0 * eta1  # η2 = 1


# --------------------------------------------------------------------------
# 附录 C: Fenghour et al.(1995) 氨黏度
# η(ρ,T) = η0(T) + Δη(ρ,T) (+Δηc, 书中未给,取 0)
# ρ: mol/l ; 返回 μPa s
# --------------------------------------------------------------------------
_F_AETA = [4.99318220, -0.61122364, 0.0, 0.18535124, -0.11160946]
_F_CETA = [-1.7999496, 46.692621, -534.60794, 3360.4074, -13019.164,
           33414.230, -58711.743, 71426.686, -59834.012, 33652.741,
           -12027.350, 2434.8205, -208.07957]
# Table 5: dη[i][j], i=2..4, j=0..4
_F_DETA = {
    2: [0.0, 0.0, 0.219664285, 0.0, -0.083651107],
    3: [0.0017366936, -0.0064250359, 0.0, 0.0, 0.0],
    4: [0.0, 0.0, 1.67668649e-4, -1.49710093e-4, 0.77012274e-4],
}
_F_SIGMA = 0.2957       # nm
_F_EPSK = 386.0         # K, ε/κ
_F_M = 17.03            # g/mol(书中表值)


def _fenghour_eta_nh3_upas(T, rho_mol_l):
    """氨黏度 [μPa s]; T[K], rho[mol/l]。"""
    th = T / _F_EPSK
    lnth = math.log(th)
    zeta = math.exp(sum(_F_AETA[i] * lnth ** i for i in range(5)))
    eta0 = 2.1357 * math.sqrt(T) * math.sqrt(_F_M) / (_F_SIGMA ** 2 * zeta)
    sq = math.sqrt(th)
    b1 = (0.6022137 * eta0 * _F_SIGMA ** 3
          * sum(_F_CETA[i] * sq ** (-i) for i in range(13)))
    d_eta = rho_mol_l * b1
    for i in (2, 3, 4):
        s = sum(_F_DETA[i][j] * th ** (-j) for j in range(5))
        d_eta += rho_mol_l ** i * s
    return eta0 + d_eta


def _fenghour_eta_nh3(T, rho_kg_m3):
    """氨黏度 [Pa s]; T[K], rho[kg/m^3]。"""
    rho_mol_l = rho_kg_m3 / _F_M  # kg/m^3 / (g/mol) = mol/l(数值)
    return _fenghour_eta_nh3_upas(T, rho_mol_l) * 1e-6


# --------------------------------------------------------------------------
# §10 纯组分饱和液体密度: ρL/ρc = Σ A_i τ^{b_i}, τ = 1-T/Tc
# --------------------------------------------------------------------------
_RHOL_A = {  # [H2O..., NH3...]
    'H2O': [1.0, 1.9937718430, 1.0985211604, -0.5094492996,
            -1.7619124270, -44.9005480267, -723692.2618632],
    'NH3': [1.0, 2.02491283, 0.84049667, 0.30155852,
            -0.20926619, -74.60250177, 4089.79277506],
}
_RHOL_B = [0.0, 1.0 / 3.0, 2.0 / 3.0, 5.0 / 3.0, 16.0 / 3.0,
           43.0 / 3.0, 110.0 / 3.0]
_RHOL_B_NH3 = [0.0, 1.0 / 3.0, 2.0 / 3.0, 5.0 / 3.0, 16.0 / 3.0,
               43.0 / 3.0, 70.0 / 3.0]  # NH3 第 6 项指数为 70/3


def _rho_liq_pure(T, which):
    """纯组分饱和液体密度 [kg/m^3]。"""
    Tc = T_C_H2O if which == 'H2O' else T_C_NH3
    rhoc = RHO_C_H2O if which == 'H2O' else RHO_C_NH3
    tau = 1.0 - T / Tc
    b = _RHOL_B if which == 'H2O' else _RHOL_B_NH3
    return rhoc * sum(a * tau ** bi for a, bi in zip(_RHOL_A[which], b))


# --------------------------------------------------------------------------
# §14 纯组分饱和蒸气密度: ln(ρG/ρc) = Σ A_i τ^{b_i}
# --------------------------------------------------------------------------
_RHOV_A = {
    'H2O': [-2.025450113, -2.701314216, -5.359161836,
            -17.343964539, -44.618326953, -64.869052901],
    'NH3': [-1.43097426, -3.31273638, -4.44425769,
            -16.84466419, -37.79713547, -97.82853834],
}
_RHOV_B = [1.0 / 3.0, 2.0 / 3.0, 4.0 / 3.0, 3.0, 37.0 / 6.0, 71.0 / 6.0]


def _rho_vap_pure(T, which):
    """纯组分饱和蒸气密度 [kg/m^3]。"""
    Tc = T_C_H2O if which == 'H2O' else T_C_NH3
    rhoc = RHO_C_H2O if which == 'H2O' else RHO_C_NH3
    tau = 1.0 - T / Tc
    return rhoc * math.exp(
        sum(a * tau ** b for a, b in zip(_RHOV_A[which], _RHOV_B)))


# --------------------------------------------------------------------------
# §6 饱和液体定压比热: Cp_m = x Cp_NH3(T*) + (1-x) Cp_H2O(T*)
#      Cp(T*) = A_cp + B_cp / τ, τ = 1 - T*/Tc ; [kJ/(kg K)]
# --------------------------------------------------------------------------
_CP = {'NH3': (3.875648, 0.242125), 'H2O': (3.665785, 0.236312)}


def cp_liq(T, x):
    """饱和液相比热 [kJ/(kg K)]。"""
    Ts_nh3, Ts_h2o = _tstar(T, x)
    cp = 0.0
    for Ts, Tc, key, w in ((Ts_nh3, T_C_NH3, 'NH3', x),
                          (Ts_h2o, T_C_H2O, 'H2O', 1.0 - x)):
        A, B = _CP[key]
        tau = 1.0 - Ts / Tc
        cp += w * (A + B / tau)
    return cp


# --------------------------------------------------------------------------
# §7 液相导热: λ_m = x λ_NH3(T*) + (1-x) λ_H2O(T*) ; [W/(m K)]
# 纯 NH3: λ = Σ A_i T^i [mW/(m K)], T[K]
# --------------------------------------------------------------------------
_LAM_L_NH3 = [8.902275e2, -0.69235, -2.4010e-3, 0.0]


def lambda_liq(T, x):
    """饱和液体导热系数 [W/(m K)]。"""
    Ts_nh3, Ts_h2o = _tstar(T, x)
    lam_nh3 = sum(a * Ts_nh3 ** i for i, a in enumerate(_LAM_L_NH3)) * 1e-3
    lam_h2o = _iapws_lambda_water(Ts_h2o, _rho_liq_pure(Ts_h2o, 'H2O'))
    return x * lam_nh3 + (1.0 - x) * lam_h2o


# --------------------------------------------------------------------------
# §8 液相动力黏度:
#   ln η_m = x ln η_NH3(T*) + (1-x) ln η_H2O(T*) + Δη
#   Δη = (0.534 - 0.815 T_sol/T_c,H2O) F(x)
#   F(x) = 6.38(1-x)^1.125 x (1-e^{-0.585 x (1-x)^0.18})
#          ln(η_NH3^0.5 η_H2O^0.5)   [η 取 μPa s, 见验证说明]
# --------------------------------------------------------------------------
def eta_liq(T, x):
    """饱和液体动力黏度 [Pa s]。"""
    Ts_nh3, Ts_h2o = _tstar(T, x)
    eta_nh3_upas = _fenghour_eta_nh3_upas(
        Ts_nh3, _rho_liq_pure(Ts_nh3, 'NH3') / _F_M)
    eta_h2o_upas = _iapws_eta_water(
        Ts_h2o, _rho_liq_pure(Ts_h2o, 'H2O')) * 1e6
    Fx = (6.38 * (1.0 - x) ** 1.125 * x
          * (1.0 - math.exp(-0.585 * x * (1.0 - x) ** 0.18))
          * math.log(math.sqrt(eta_nh3_upas * eta_h2o_upas)))
    d_eta = (0.534 - 0.815 * T / T_C_H2O) * Fx
    ln_eta = (x * math.log(eta_nh3_upas)
              + (1.0 - x) * math.log(eta_h2o_upas) + d_eta)
    return math.exp(ln_eta) * 1e-6


# --------------------------------------------------------------------------
# §9 表面张力: σ_m = x σ_NH3(T*) + (1-x) σ_H2O(T*) + Δσ ; [N/m]
#   σ = σ0 (1+bτ) τ^μ ; Δσ = -(σ_H2O - σ_NH3) F(x)
#   F(x) = 1.442(1-x)[1-e^{-2.5x^4}] + 1.106x[1-e^{-2.5(1-x)^6}]
# --------------------------------------------------------------------------
_SIG = {'NH3': (91.2, 1.1028, 0.0), 'H2O': (235.8, 1.256, -0.625)}


def _sigma_pure(T, which):
    Tc = T_C_H2O if which == 'H2O' else T_C_NH3
    s0, mu, b = _SIG[which]
    tau = 1.0 - T / Tc
    return s0 * (1.0 + b * tau) * tau ** mu  # mN/m


def sigma(T, x):
    """溶液表面张力 [N/m]。"""
    Ts_nh3, Ts_h2o = _tstar(T, x)
    s_nh3 = _sigma_pure(Ts_nh3, 'NH3')
    s_h2o = _sigma_pure(Ts_h2o, 'H2O')
    Fx = (1.442 * (1.0 - x) * (1.0 - math.exp(-2.5 * x ** 4))
          + 1.106 * x * (1.0 - math.exp(-2.5 * (1.0 - x) ** 6)))
    d_sig = -(s_h2o - s_nh3) * Fx
    return (x * s_nh3 + (1.0 - x) * s_h2o + d_sig) * 1e-3


# --------------------------------------------------------------------------
# §10 液相密度: ρ_m = x ρ_NH3(T*) + (1-x) ρ_H2O(T*) + Δρ ; [kg/m^3]
#   Δρ = x(1-x)(1 - A x) sqrt(ρ_NH3 ρ_H2O)
#   A = Σ A1_i T‡^i + Σ A2_i T‡^i / x,  T‡ = T_sol/T_c,H2O
#   (写成 A x = x ΣA1 T‡^i + ΣA2 T‡^i 避免 x=0 奇点)
# --------------------------------------------------------------------------
_RHO_A1 = [-2.410, 8.310, -6.924]
_RHO_A2 = [2.118, -4.050, 4.443]


def rho_liq(T, x):
    """饱和液体密度 [kg/m^3]。"""
    Ts_nh3, Ts_h2o = _tstar(T, x)
    r_nh3 = _rho_liq_pure(Ts_nh3, 'NH3')
    r_h2o = _rho_liq_pure(Ts_h2o, 'H2O')
    Td = T / T_C_H2O
    s1 = sum(a * Td ** i for i, a in enumerate(_RHO_A1))
    s2 = sum(a * Td ** i for i, a in enumerate(_RHO_A2))
    Ax = x * s1 + s2
    d_rho = x * (1.0 - x) * (1.0 - Ax) * math.sqrt(r_nh3 * r_h2o)
    return x * r_nh3 + (1.0 - x) * r_h2o + d_rho


# --------------------------------------------------------------------------
# §11 质扩散系数(修正 Wilke-Chang): [m^2/s]
#   D = 117.282e-18 T_sol sqrt(ψ_sol M_sol) / (η_sol Ṽ_diff^0.6)
#   ψ_sol, M_sol 摩尔分数加权; Ṽ_diff = M_NH3[g/mol]/ρ_NH3(T_sol)[kg/m^3]
#   η_sol[Pa s] 取 §8
# --------------------------------------------------------------------------
_WC_PSI = {'NH3': 1.7, 'H2O': 2.6}
_WC_M = {'NH3': 17.03, 'H2O': 18.0152}


def diffusivity(T, x):
    """氨蒸气向氨水溶液的质扩散系数 [m^2/s]。"""
    psi_sol = x * _WC_PSI['NH3'] + (1.0 - x) * _WC_PSI['H2O']
    M_sol = x * _WC_M['NH3'] + (1.0 - x) * _WC_M['H2O']
    Vdiff = _WC_M['NH3'] / _rho_liq_pure(T, 'NH3')
    eta = eta_liq(T, x)
    return (117.282e-18 * T * math.sqrt(psi_sol * M_sol)
            / (eta * Vdiff ** 0.6))


# --------------------------------------------------------------------------
# §12 气相导热: Wassiljewa-Mason-Saxena 混合规则 ; [W/(m K)]
#   λ_m = y λ_NH3/(y+(1-y)φ12) + (1-y) λ_H2O/((1-y)+y φ21)
#   纯 NH3 气: λ = Σ A_i [ln(1/τ)]^i [mW/(m K)], τ=1-T/T_c,NH3
#   纯 H2O 气: IAPWS 附录 A
# --------------------------------------------------------------------------
_LAM_V_NH3 = [-0.48173, 20.04383, 0.0, 0.0]


def _phi12(eta1, eta2):
    """Mason-Saxena φ12 ; eta1=NH3, eta2=H2O(单位一致即可)。"""
    m1, m2 = _WC_M['NH3'], _WC_M['H2O']
    return ((1.0 + math.sqrt(eta1 / eta2) * (m2 / m1) ** 0.25) ** 2
            / math.sqrt(8.0 * (1.0 + m1 / m2)))


def lambda_vap(T, y):
    """饱和气相导热系数 [W/(m K)] ; T[K] 气相温度, y 气相氨摩尔分数。"""
    tau = 1.0 - T / T_C_NH3
    lam_nh3 = sum(a * math.log(1.0 / tau) ** i
                  for i, a in enumerate(_LAM_V_NH3)) * 1e-3
    lam_h2o = _iapws_lambda_water(T, _rho_vap_pure(T, 'H2O'))
    eta_nh3 = _fenghour_eta_nh3(T, _rho_vap_pure(T, 'NH3'))
    eta_h2o = _iapws_eta_water(T, _rho_vap_pure(T, 'H2O'))
    p12 = _phi12(eta_nh3, eta_h2o)
    p21 = p12 * (eta_h2o / eta_nh3) * (_WC_M['NH3'] / _WC_M['H2O'])
    return (y * lam_nh3 / (y + (1.0 - y) * p12)
            + (1.0 - y) * lam_h2o / ((1.0 - y) + y * p21))


# --------------------------------------------------------------------------
# §13 气相动力黏度: Wilke 混合规则 ; [Pa s]
#   η_m = y η_NH3/(y+(1-y)φ12) + (1-y) η_H2O/((1-y)+y φ21)
#   纯 NH3 气: Fenghour 附录 C ; 纯 H2O 气: IAPWS 附录 B
# --------------------------------------------------------------------------
def eta_vap(T, y):
    """饱和气相动力黏度 [Pa s]。"""
    eta_nh3 = _fenghour_eta_nh3(T, _rho_vap_pure(T, 'NH3'))
    eta_h2o = _iapws_eta_water(T, _rho_vap_pure(T, 'H2O'))
    p12 = _phi12(eta_nh3, eta_h2o)
    p21 = p12 * (eta_h2o / eta_nh3) * (_WC_M['NH3'] / _WC_M['H2O'])
    return (y * eta_nh3 / (y + (1.0 - y) * p12)
            + (1.0 - y) * eta_h2o / ((1.0 - y) + y * p21))


# --------------------------------------------------------------------------
# §14 气相密度: ρ_m = y ρ_NH3(T*) + (1-y) ρ_H2O(T*) + Δρ ; [kg/m^3]
#   Δρ = A(1-y)^B (1-e^{C y^D}) Δρmax ; Δρmax = e^{J-K/T‡}
#   T‡ = T_sol/T_c,H2O
# --------------------------------------------------------------------------
_RV_A, _RV_B, _RV_C = 82.0, 0.5, -0.05
_RV_D, _RV_J, _RV_K = 2.75, 9.952, 3.884


def rho_vap(T, y):
    """饱和气相密度 [kg/m^3] ; T[K] 气相温度。"""
    Ts_nh3, Ts_h2o = _tstar(T, y)
    r_nh3 = _rho_vap_pure(Ts_nh3, 'NH3')
    r_h2o = _rho_vap_pure(Ts_h2o, 'H2O')
    Td = T / T_C_H2O
    d_rho_max = math.exp(_RV_J - _RV_K / Td)
    d_rho = (_RV_A * (1.0 - y) ** _RV_B * (1.0 - math.exp(_RV_C * y ** _RV_D))
             * d_rho_max)
    return y * r_nh3 + (1.0 - y) * r_h2o + d_rho


# --------------------------------------------------------------------------
# §15 气相比热: Cp_m = y Cp_NH3(τ) + (1-y) Cp_H2O(τ) ; [kJ/(kg K)]
#   Cp(τ) = A + B τ^{-1/3} + C τ^{-2/3} + D τ^{-5/3} + E τ^{-7.5/3}
#   τ = 1 - T_vap/T_c,sol(y)
# --------------------------------------------------------------------------
_CPV = {
    'NH3': (-1.199197086, 1.240129495, 0.924818752, 0.018199633, -0.245034e-3),
    'H2O': (3.461825651, -4.987788063, 2.994381770, 6.259308e-3, -8.262961e-6),
}


def cp_vap(T, y):
    """饱和气相比热 [kJ/(kg K)]。"""
    tau = 1.0 - T / tc_sol(y)
    cp = 0.0
    for key, w in (('NH3', y), ('H2O', 1.0 - y)):
        A, B, C, D, E = _CPV[key]
        cp += w * (A + B * tau ** (-1.0 / 3.0) + C * tau ** (-2.0 / 3.0)
                   + D * tau ** (-5.0 / 3.0) + E * tau ** (-7.5 / 3.0))
    return cp


if __name__ == '__main__':
    # 快速自检: 20°C 纯水/纯氨端点
    T = 293.15
    print('water 20C: eta=%.4g Pa s (exp 1.002e-3)' % _iapws_eta_water(T, 998.2))
    print('water 20C: lam=%.4g W/m/K (exp 0.598)' % _iapws_lambda_water(T, 998.2))
    print('cp_liq water=%.3f kJ/kg/K (exp 4.18)' % cp_liq(T, 0.0))
    print('cp_liq NH3  =%.3f kJ/kg/K (exp ~4.7)' % cp_liq(T, 1.0))
    print('rho_liq water=%.1f (exp 998.2)' % rho_liq(T, 0.0))
    print('rho_liq NH3  =%.1f (exp ~610)' % rho_liq(T, 1.0))
    print('sigma water=%.4f N/m (exp 0.0728)' % sigma(T, 0.0))
    print('Tc/Pc x=0.5: %.1f K, %.1f bar' % (tc_sol(0.5), pc_sol(0.5)))

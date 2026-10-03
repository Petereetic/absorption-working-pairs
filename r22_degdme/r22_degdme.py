# R22-DEGDME 热力学关联式（参考实现）
# 来源：E. Ando, I. Takeshita,
#   "Residential gas-fired absorption heat pump based on R22-DEGDME pair.
#    Part I Thermodynamic properties of the R22-DEGDME pair",
#   Int. J. Refrigeration, Vol.7, No.3, pp.181-186, 1984.
#
# 三个关联式全部可算，常数直接取自论文表2、表3及式(7)：
#   式(1) 泡点压力 Rankine 方程   lnP = ΣAnX^n + (1/T)ΣBnX^n + lnT·ΣCnX^n
#         P: kg/cm2, T: K, X: R22 摩尔分数；适用 X=0.1~1.0, P=0.1~30 kg/cm2,
#         T=-20~190°C；151点，平均相对偏差 0.79%
#   式(6) 摩尔热容多项式        C = ΣAnX^n + t·ΣBnX^n + t^2·ΣCnX^n
#         C: J/mol/°C, t: °C；全浓度，t=-30~110°C；193点，平均相对偏差 0.83%
#   式(7) 混合热 Redlich-Kister  ΔHm = X(1-X)·Σ Gi·(1-2X)^(i-1), i=1..4
#         ΔHm: J/mol, 测于 10°C；11点，平均相对偏差 0.72%
#   式(9) 溶液焓组装            H(T,X) = (1-X)H1 + X·H2 + ΔHm + ∫(Tm→T) Cp dτ
#
# 参考态（本文档自行约定，论文 Part I 未固定绝对焓值）：
#   纯组分液体在 Tm=10°C 时焓为 0；
#   则 H(T,X) = ΔHm(X) + ∫(10°C→t) Cp(X,τ) dτ   [J/mol]，再换算为 kJ/kg。
# 注意 X 是 R22 摩尔分数（论文体系），不是质量分数。

import math

# ---- 常数 ----
_M_R22 = 86.47      # g/mol, CHClF2
_M_DEGDME = 134.17  # g/mol, C6H14O3 (bis(2-methoxyethyl)ether)
_TM_C = 10.0        # 混合热测定温度 / 焓参考温度，°C
_KGCM2_TO_BAR = 0.980665

# 表2：式(1) n=0..5 的 (A, B, C)
_T2 = [
    ( 5.2167e1, -5.5828e3, -6.3489e0),
    ( 1.2753e1,  3.3999e3, -1.4386e0),
    (-1.3901e2, -8.6015e3,  2.2313e1),
    ( 7.3205e2, -3.1686e3, -1.1454e2),
    (-1.1910e3,  3.0425e4,  1.8148e2),
    ( 5.4717e2, -1.9049e4, -8.1999e1),
]

# 表3：式(6) n=0..3 的 (A, B, C)
_T3 = [
    ( 2.7974e2, -4.2015e-2,  2.3114e-3),
    (-1.5075e2,  5.9865e-1, -5.9745e-3),
    ( 1.0095e2, -1.3790e0,   3.4322e-3),
    (-1.2802e2,  1.0167e0,   1.0571e-3),
]

# 式(7)：G1..G4
_G = (-1.9061e4, 8.7280e3, -1.3948e3, -6.4218e2)


def _poly(coefs, X):
    s = 0.0
    for n, c in enumerate(coefs):
        s += c * X ** n
    return s


def p_vap_kgcm2(X, T_K):
    """式(1)：泡点压力，kg/cm2。X=R22摩尔分数，T_K=开尔文。"""
    sA = _poly([r[0] for r in _T2], X)
    sB = _poly([r[1] for r in _T2], X)
    sC = _poly([r[2] for r in _T2], X)
    return math.exp(sA + sB / T_K + sC * math.log(T_K))


def p_vap_bar(X, t_C):
    """式(1)：泡点压力，bar。t_C=摄氏度。"""
    return p_vap_kgcm2(X, t_C + 273.15) * _KGCM2_TO_BAR


def cp_molar(X, t_C):
    """式(6)：混合物摩尔定压热容，J/mol/°C。"""
    sA = _poly([r[0] for r in _T3], X)
    sB = _poly([r[1] for r in _T3], X)
    sC = _poly([r[2] for r in _T3], X)
    return sA + t_C * sB + t_C * t_C * sC


def heat_of_mixing(X):
    """式(7)：摩尔混合热（10°C 下测定），J/mol。放热为负。"""
    return X * (1.0 - X) * sum(g * (1.0 - 2.0 * X) ** i for i, g in enumerate(_G))


def h_solution_kJkg(X, t_C):
    """式(9)：溶液比焓，kJ/kg。
    参考态：纯组分液体在 10°C 时焓为 0（本文档约定）。"""
    sA = _poly([r[0] for r in _T3], X)
    sB = _poly([r[1] for r in _T3], X)
    sC = _poly([r[2] for r in _T3], X)
    t0 = _TM_C
    sensible = (sA * (t_C - t0)
                + sB * (t_C * t_C - t0 * t0) / 2.0
                + sC * (t_C ** 3 - t0 ** 3) / 3.0)  # J/mol
    h_mol = heat_of_mixing(X) + sensible  # J/mol
    M_mix = X * _M_R22 + (1.0 - X) * _M_DEGDME  # g/mol
    return h_mol / M_mix  # kJ/kg


if __name__ == "__main__":
    # 自检：与论文图6（ΔHm 最低点约 -5000 J/mol）及物理量级对照
    print("Pvap(X=1.0, 10°C)  = %.3f kg/cm2" % p_vap_kgcm2(1.0, 283.15))
    print("Pvap(X=0.5, 10°C)  = %.3f bar" % p_vap_bar(0.5, 10.0))
    print("Pvap(X=0.5, 80°C)  = %.3f bar" % p_vap_bar(0.5, 80.0))
    print("Cp  (X=0.5, 10°C)  = %.1f J/mol/K" % cp_molar(0.5, 10.0))
    print("dHm (X=0.5)        = %.0f J/mol" % heat_of_mixing(0.5))
    print("Hsol(X=0.5, 10°C)  = %.2f kJ/kg" % h_solution_kJkg(0.5, 10.0))
    print("Hsol(X=0.5, 80°C)  = %.2f kJ/kg" % h_solution_kJkg(0.5, 80.0))
    print("Hsol(X=0.5,-20°C)  = %.2f kJ/kg" % h_solution_kJkg(0.5, -20.0))

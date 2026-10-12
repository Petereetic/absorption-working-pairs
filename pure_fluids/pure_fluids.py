# R134a / R22 / R124 纯物质饱和性质（参考实现）
#
# 基准：CoolProp 内置参考状态方程
#   R134a: Tillner-Roth & Baehr (1994)；R22: CoolProp 参考 EOS
# 参考态（与用户现有模型统一）：0°C 饱和液体焓 = 100 kJ/kg
#   （CoolProp 默认 200 kJ/kg，已整体平移 -100）
#   R124: NIST WebBook 饱和表（276 点，-153~122°C）拟合，见
#     工质对公式素材库《R124纯工质-NIST表拟合与Borde仲裁》；
#     表焓基准同为 0°C 饱和液体 = 200 kJ/kg，已整体平移 -100（潜热不变）。
#     Psat 为 Wagner 型（指数 1, 1.5, 3, 6）：Tc=395.428K, Pc=36.245bar，
#     适用 -40~110°C, 对表最大偏差 0.111%；hL/hV 同带最大偏差 1.11/1.63 kJ/kg
#
# 拟合式：
#   饱和压力 Wagner 方程：ln(P/Pc) = (Tc/T)·(a1·τ + a2·τ^1.5 + a3·τ^2.5 + a4·τ^5),
#     τ = 1-T/Tc, T in K, P in bar
#     R134a: Tc=374.21K, Pc=40.59bar, 适用 -50~95°C, 最大偏差 0.031%
#     R22:   Tc=369.30K, Pc=49.90bar, 适用 -50~90°C, 最大偏差 0.0065%
#   饱和液体/蒸气焓：6 次多项式 h(t), t in °C, kJ/kg
#     R134a hL 偏差 0.41, hV 偏差 0.61 kJ/kg
#     R22   hL 偏差 0.42, hV 偏差 0.59 kJ/kg
# 饱和温度 Tsat(P)：对 Psat 二分反算。

import math

# ---------------- R134a ----------------
_R134a_Tc = 374.21
_R134a_Pc = 40.59
_R134a_W = (-7.6391282, 1.7650117, -2.6103553, -3.3657380)
_R134a_hL = (3.5283163e-11, -2.2259203e-09, -7.2651551e-08, 1.3659406e-05,
             1.4602205e-03, 1.3386046e+00, 9.9982381e+01)
_R134a_hV = (-5.4059642e-11, 3.2801028e-09, 1.2592287e-07, -2.1005140e-05,
             -1.2602316e-03, 5.9085680e-01, 2.9863031e+02)
_R134a_TLO, _R134a_THI = -50.0, 95.0

# ---------------- R22 ----------------
_R22_Tc = 369.30
_R22_Pc = 49.90
_R22_W = (-7.0486230, 1.4828095, -1.8223105, -2.8257753)
_R22_hL = (4.6681599e-11, -2.2286115e-09, -1.2586426e-07, 1.4969301e-05,
           1.5173919e-03, 1.1678030e+00, 9.9972867e+01)
_R22_hV = (-6.5412360e-11, 3.1584987e-09, 1.6628519e-07, -2.1606737e-05,
           -1.9128189e-03, 3.7574587e-01, 3.0508640e+02)
_R22_TLO, _R22_THI = -50.0, 90.0

# ---------------- R124 ----------------
# 源：NIST WebBook 饱和表拟合（Wagner 指数 1, 1.5, 3, 6；焓 6 次多项式，
# 已由表基准 0°C 液体 = 200 整体平移 -100 至本模块统一基准）
_R124_Tc = 395.428
_R124_Pc = 36.245
_R124_W = (-7.401179377235425, 1.4613603991162563, -3.476435267708954,
           -1.772232810745864)
_R124_hL = (3.101121704716488e-12, 6.118884579625834e-10, -1.0126584362284601e-08,
            -3.744431218418699e-06, 9.264564201937477e-04, 1.0995525531984227,
            1.0004767130193036e+02)
_R124_hV = (-4.7606354686130485e-12, -9.020883920792309e-10, 2.036341936229362e-08,
            4.234769176716097e-06, -3.8033802108463233e-04, 5.621038923140594e-01,
            2.5994742998138406e+02)
_R124_TLO, _R124_THI = -40.0, 110.0


def _wagner_pref(t_C, Tc, Pc, a):
    T = t_C + 273.15
    tau = 1.0 - T / Tc
    return Pc * math.exp((Tc / T) * (a[0] * tau + a[1] * tau ** 1.5
                                    + a[2] * tau ** 2.5 + a[3] * tau ** 5.0))


def _wagner_pref36(t_C, Tc, Pc, a):
    """Wagner 变体（指数 1, 1.5, 3, 6），R124 拟合所用式形。"""
    T = t_C + 273.15
    tau = 1.0 - T / Tc
    return Pc * math.exp((Tc / T) * (a[0] * tau + a[1] * tau ** 1.5
                                    + a[2] * tau ** 3.0 + a[3] * tau ** 6.0))


def _poly6(c, t):
    return (((((c[0] * t + c[1]) * t + c[2]) * t + c[3]) * t + c[4]) * t + c[5]) * t + c[6]


def _tsat_bisect(P_bar, pref_fn, t_lo, t_hi):
    Plo, Phi = pref_fn(t_lo), pref_fn(t_hi)
    if not (Plo <= P_bar <= Phi):
        return None
    lo, hi = t_lo, t_hi
    for _ in range(60):
        mid = 0.5 * (lo + hi)
        if pref_fn(mid) < P_bar:
            lo = mid
        else:
            hi = mid
    return 0.5 * (lo + hi)


def R134a_Pref(t_C):
    """R134a 饱和压力，bar。t_C: °C，适用 -50~95°C。"""
    return _wagner_pref(t_C, _R134a_Tc, _R134a_Pc, _R134a_W)


def R134a_Tsat(P_bar):
    """R134a 饱和温度，°C。P_bar: bar。超出范围返回 None。"""
    return _tsat_bisect(P_bar, R134a_Pref, _R134a_TLO, _R134a_THI)


def R134a_hliq(t_C):
    """R134a 饱和液体焓，kJ/kg。参考态 0°C 饱和液体 = 100 kJ/kg。"""
    return _poly6(_R134a_hL, t_C)


def R134a_hgas(t_C):
    """R134a 饱和蒸气焓，kJ/kg。参考态 0°C 饱和液体 = 100 kJ/kg。"""
    return _poly6(_R134a_hV, t_C)


def R134a_hlat(t_C):
    """R134a 饱和潜热，kJ/kg = hgas - hliq（同一参考态，两焓同基准）。"""
    return R134a_hgas(t_C) - R134a_hliq(t_C)


def R22_Pref(t_C):
    """R22 饱和压力，bar。t_C: °C，适用 -50~90°C。"""
    return _wagner_pref(t_C, _R22_Tc, _R22_Pc, _R22_W)


def R22_Tsat(P_bar):
    """R22 饱和温度，°C。P_bar: bar。超出范围返回 None。"""
    return _tsat_bisect(P_bar, R22_Pref, _R22_TLO, _R22_THI)


def R22_hliq(t_C):
    """R22 饱和液体焓，kJ/kg。参考态 0°C 饱和液体 = 100 kJ/kg。"""
    return _poly6(_R22_hL, t_C)


def R22_hgas(t_C):
    """R22 饱和蒸气焓，kJ/kg。参考态 0°C 饱和液体 = 100 kJ/kg。"""
    return _poly6(_R22_hV, t_C)


def R22_hlat(t_C):
    """R22 饱和潜热，kJ/kg = hgas - hliq（同一参考态，两焓同基准）。"""
    return R22_hgas(t_C) - R22_hliq(t_C)


def R124_Pref(t_C):
    """R124 饱和压力，bar。t_C: °C，适用 -40~110°C（NIST 表 Wagner 拟合）。"""
    return _wagner_pref36(t_C, _R124_Tc, _R124_Pc, _R124_W)


def R124_Tsat(P_bar):
    """R124 饱和温度，°C。P_bar: bar。超出范围返回 None。"""
    return _tsat_bisect(P_bar, R124_Pref, _R124_TLO, _R124_THI)


def R124_hliq(t_C):
    """R124 饱和液体焓，kJ/kg。参考态 0°C 饱和液体 = 100 kJ/kg。"""
    return _poly6(_R124_hL, t_C)


def R124_hgas(t_C):
    """R124 饱和蒸气焓，kJ/kg。参考态 0°C 饱和液体 = 100 kJ/kg。"""
    return _poly6(_R124_hV, t_C)


def R124_hlat(t_C):
    """R124 饱和潜热，kJ/kg = hgas - hliq（同一参考态，两焓同基准）。"""
    return R124_hgas(t_C) - R124_hliq(t_C)


if __name__ == "__main__":
    for name, P, hL, hV, Ts in [
            ("R134a", R134a_Pref, R134a_hliq, R134a_hgas, R134a_Tsat),
            ("R22", R22_Pref, R22_hliq, R22_hgas, R22_Tsat),
            ("R124", R124_Pref, R124_hliq, R124_hgas, R124_Tsat)]:
        print(f"== {name} ==")
        for t in [-40, -10, 0, 25, 50, 80]:
            print(f"  {t:4d}C: Pref={P(t):7.3f} bar  hliq={hL(t):7.2f}  hgas={hV(t):7.2f} kJ/kg")
        print(f"  Tsat(10 bar) = {Ts(10):.2f} C")

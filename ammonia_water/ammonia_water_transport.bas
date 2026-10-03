Attribute VB_Name = "AmmoniaWaterTransport"
' ==========================================================================
' 氨水溶液输运物性 VBA 工作表函数
' ==========================================================================
' M. Conde Engineering (2004)
' "Thermophysical Properties of NH3 + H2O Solutions for the Industrial
'  Design of Absorption Refrigeration Equipment", 第 5~15 章 + 附录 A/B/C。
'
' 与 ammonia_water_transport.py 逐行对应。双精度。
'
' 工作表函数 (T 单位 K; x 液相氨摩尔分数; y 气相氨摩尔分数):
'   AW_TcSol(x)      溶液临界温度 [K]               (§5)
'   AW_PcSol(x)      溶液临界压力 [bar]             (§5)
'   AW_CpLiq(T,x)    饱和液相比热 [kJ/(kg K)]       (§6)
'   AW_LamLiq(T,x)   饱和液相导热 [W/(m K)]         (§7)
'   AW_EtaLiq(T,x)   饱和液相动力黏度 [Pa s]        (§8)
'   AW_Sigma(T,x)    表面张力 [N/m]                 (§9)
'   AW_RhoLiq(T,x)   饱和液相密度 [kg/m^3]          (§10)
'   AW_Diff(T,x)     质扩散系数 [m^2/s]             (§11)
'   AW_LamVap(T,y)   饱和气相导热 [W/(m K)]         (§12)
'   AW_EtaVap(T,y)   饱和气相动力黏度 [Pa s]        (§13)
'   AW_RhoVap(T,y)   饱和气相密度 [kg/m^3]          (§14)
'   AW_CpVap(T,y)    饱和气相比热 [kJ/(kg K)]       (§15)
'
' 注意:
'   本 .bas 未在真实 Excel 中编译或运行,系由 Python 参考实现逐行移植。
'   附录 A 总式书中印刷为乘法,实为加法(见 py/c 注释)。
'   §12/§13 正文附录引用有笔误,此处按目录(A=导热,B=黏度)实现。
' ==========================================================================
Option Explicit

Private Const T_C_NH3 As Double = 405.4
Private Const T_C_H2O As Double = 647.14
Private Const RHO_C_NH3 As Double = 225#
Private Const RHO_C_H2O As Double = 322#

' ---------- §5 ----------
Public Function AW_TcSol(ByVal x As Double) As Double
    AW_TcSol = 647.14 - 199.822371 * x + 109.035522 * x ^ 2 _
             - 239.626217 * x ^ 3 + 88.689691 * x ^ 4
End Function

Public Function AW_PcSol(ByVal x As Double) As Double
    AW_PcSol = 220.64 - 37.923795 * x + 36.424739 * x ^ 2 _
             - 41.851597 * x ^ 3 - 63.805617 * x ^ 4
End Function

Private Sub TStar(ByVal T As Double, ByVal x As Double, _
                  ByRef TsNH3 As Double, ByRef TsH2O As Double)
    Dim th As Double
    th = T / AW_TcSol(x)
    TsNH3 = th * T_C_NH3
    TsH2O = th * T_C_H2O
End Sub

' ---------- 附录 A: IAPWS 水导热 ----------
Private Function IapwsLambdaWater(ByVal T As Double, ByVal rho As Double) As Double
    Dim Tb As Double, rb As Double
    Dim lam0 As Double, lam1 As Double, lam2 As Double
    Dim dTb As Double, Lam0 As Double, Lam1 As Double
    Dim t1 As Double, t2 As Double, t3 As Double
    Tb = T / 647.26
    rb = rho / 317.7
    lam0 = Sqr(Tb) * (0.0102811 + 0.0299621 * Tb _
         + 0.0156146 * Tb ^ 2 - 0.00422464 * Tb ^ 3)
    lam1 = -0.39707 + 0.400302 * rb _
         + 1.06 * Exp(-0.171587 * (rb + 2.39219) ^ 2)
    dTb = Abs(Tb - 1#) + 0.00308976
    If Tb >= 1# Then Lam0 = 1# / dTb Else Lam0 = 10.0932 / dTb ^ 0.6
    Lam1 = 2# + 0.0822994 / dTb ^ 0.6
    t1 = (0.0701309 / Tb ^ 10 + 0.011852) * rb ^ 1.8 _
       * Exp(0.642857 * (1# - rb ^ 2.8))
    t2 = 0.00169937 * Lam0 * rb ^ Lam1 _
       * Exp((Lam1 / (1# + Lam1)) * (1# - rb ^ (1# + Lam1)))
    t3 = -1.02 * Exp(-4.11717 * Tb ^ 1.5 - 6.17937 / rb ^ 5)
    lam2 = t1 + t2 + t3
    IapwsLambdaWater = lam0 + lam1 + lam2
End Function

' ---------- 附录 B: IAPWS 水黏度 ----------
Private Function IapwsEtaWater(ByVal T As Double, ByVal rho As Double) As Double
    Dim Tb As Double, rb As Double, eta0 As Double
    Dim s As Double, ti As Double, rm As Double
    Dim i As Integer, j As Integer
    Dim G As Variant
    G = Array( _
        Array(0.5132047, 0.2151778, -0.2818107, 0.1778064, -0.0417661, 0#, 0#), _
        Array(0.3205656, 0.7317883, -1.070786, 0.460504, 0#, -0.01578386, 0#), _
        Array(0#, 1.241044, -1.263184, 0.2340379, 0#, 0#, 0#), _
        Array(0#, 1.476783, 0#, -0.4924179, 0.1600435, 0#, -0.003629481), _
        Array(-0.7782567, 0#, 0#, 0#, 0#, 0#, 0#), _
        Array(0.1885447, 0#, 0#, 0#, 0#, 0#, 0#))
    Tb = T / 647.226
    rb = rho / 317.763
    eta0 = Sqr(Tb) / (1# + 0.978197 / Tb + 0.579829 / Tb ^ 2 - 0.202354 / Tb ^ 3)
    s = 0#: ti = 1# / Tb - 1#: rm = rb - 1#
    For i = 0 To 5
        For j = 0 To 6
            If G(i)(j) <> 0# Then s = s + G(i)(j) * ti ^ i * rm ^ j
        Next j
    Next i
    IapwsEtaWater = 55.071E-06 * eta0 * Exp(rb * s)
End Function

' ---------- 附录 C: Fenghour 氨黏度 [μPa s] ----------
Private Function FenghourEtaUpas(ByVal T As Double, ByVal rhoMolL As Double) As Double
    Dim th As Double, lnth As Double, zeta As Double
    Dim eta0 As Double, sq As Double, b1 As Double, dEta As Double, s As Double
    Dim i As Integer, j As Integer
    Dim aEta As Variant, cEta As Variant, dEtaT As Variant
    aEta = Array(4.9931822, -0.61122364, 0#, 0.18535124, -0.11160946)
    cEta = Array(-1.7999496, 46.692621, -534.60794, 3360.4074, -13019.164, _
        33414.23, -58711.743, 71426.686, -59834.012, 33652.741, _
        -12027.35, 2434.8205, -208.07957)
    dEtaT = Array( _
        Array(0#, 0#, 0.219664285, 0#, -0.083651107), _
        Array(0.0017366936, -0.0064250359, 0#, 0#, 0#), _
        Array(0#, 0#, 0.000167668649, -0.000149710093, 0.000077012274))
    th = T / 386#
    lnth = Log(th)
    zeta = 0#
    For i = 0 To 4: zeta = zeta + aEta(i) * lnth ^ i: Next i
    zeta = Exp(zeta)
    eta0 = 2.1357 * Sqr(T) * Sqr(17.03) / (0.2957 ^ 2 * zeta)
    sq = Sqr(th)
    b1 = 0#
    For i = 0 To 12: b1 = b1 + cEta(i) * sq ^ (-i): Next i
    b1 = b1 * 0.6022137 * eta0 * 0.2957 ^ 3
    dEta = rhoMolL * b1
    For i = 0 To 2
        s = 0#
        For j = 0 To 4: s = s + dEtaT(i)(j) * th ^ (-j): Next j
        dEta = dEta + rhoMolL ^ (i + 2) * s
    Next i
    FenghourEtaUpas = eta0 + dEta
End Function

Private Function FenghourEta(ByVal T As Double, ByVal rhoKgM3 As Double) As Double
    FenghourEta = FenghourEtaUpas(T, rhoKgM3 / 17.03) * 1E-06
End Function

' ---------- §10 纯组分密度 ----------
Private Function RhoLiqPure(ByVal T As Double, ByVal isNH3 As Boolean) As Double
    Dim A As Variant, B As Variant
    Dim Tc As Double, rhoc As Double, tau As Double, s As Double
    Dim i As Integer
    If isNH3 Then
        A = Array(1#, 2.02491283, 0.84049667, 0.30155852, -0.20926619, _
            -74.60250177, 4089.79277506)
        Tc = T_C_NH3: rhoc = RHO_C_NH3
    Else
        A = Array(1#, 1.993771843, 1.0985211604, -0.5094492996, _
            -1.761912427, -44.9005480267, -723692.2618632)
        Tc = T_C_H2O: rhoc = RHO_C_H2O
    End If
    B = Array(0#, 1# / 3#, 2# / 3#, 5# / 3#, 16# / 3#, 43# / 3#, 110# / 3#)
    tau = 1# - T / Tc
    s = 0#
    For i = 0 To 6
        Dim bi As Double: bi = B(i)
        If isNH3 And i = 6 Then bi = 70# / 3#
        s = s + A(i) * tau ^ bi
    Next i
    RhoLiqPure = rhoc * s
End Function

Private Function RhoVapPure(ByVal T As Double, ByVal isNH3 As Boolean) As Double
    Dim A As Variant
    Dim B As Variant
    Dim Tc As Double, rhoc As Double, tau As Double, s As Double
    Dim i As Integer
    If isNH3 Then
        A = Array(-1.43097426, -3.31273638, -4.44425769, _
            -16.84466419, -37.79713547, -97.82853834)
        Tc = T_C_NH3: rhoc = RHO_C_NH3
    Else
        A = Array(-2.025450113, -2.701314216, -5.359161836, _
            -17.343964539, -44.618326953, -64.869052901)
        Tc = T_C_H2O: rhoc = RHO_C_H2O
    End If
    B = Array(1# / 3#, 2# / 3#, 4# / 3#, 3#, 37# / 6#, 71# / 6#)
    tau = 1# - T / Tc
    s = 0#
    For i = 0 To 5: s = s + A(i) * tau ^ B(i): Next i
    RhoVapPure = rhoc * Exp(s)
End Function

' ---------- §6 ----------
Public Function AW_CpLiq(ByVal T As Double, ByVal x As Double) As Double
    Dim TsNH3 As Double, TsH2O As Double
    Dim tauN As Double, tauW As Double
    TStar T, x, TsNH3, TsH2O
    tauN = 1# - TsNH3 / T_C_NH3
    tauW = 1# - TsH2O / T_C_H2O
    AW_CpLiq = x * (3.875648 + 0.242125 / tauN) _
             + (1# - x) * (3.665785 + 0.236312 / tauW)
End Function

' ---------- §7 ----------
Public Function AW_LamLiq(ByVal T As Double, ByVal x As Double) As Double
    Dim TsNH3 As Double, TsH2O As Double
    Dim lamN As Double, lamW As Double
    TStar T, x, TsNH3, TsH2O
    lamN = (890.2275 - 0.69235 * TsNH3 - 0.002401 * TsNH3 ^ 2) * 0.001
    lamW = IapwsLambdaWater(TsH2O, RhoLiqPure(TsH2O, False))
    AW_LamLiq = x * lamN + (1# - x) * lamW
End Function

' ---------- §8 ----------
Public Function AW_EtaLiq(ByVal T As Double, ByVal x As Double) As Double
    Dim TsNH3 As Double, TsH2O As Double
    Dim eN As Double, eW As Double, Fx As Double, dEta As Double
    TStar T, x, TsNH3, TsH2O
    eN = FenghourEtaUpas(TsNH3, RhoLiqPure(TsNH3, True) / 17.03)
    eW = IapwsEtaWater(TsH2O, RhoLiqPure(TsH2O, False)) * 1000000#
    Fx = 6.38 * (1# - x) ^ 1.125 * x _
       * (1# - Exp(-0.585 * x * (1# - x) ^ 0.18)) _
       * Log(Sqr(eN * eW))
    dEta = (0.534 - 0.815 * T / T_C_H2O) * Fx
    AW_EtaLiq = Exp(x * Log(eN) + (1# - x) * Log(eW) + dEta) * 0.000001
End Function

' ---------- §9 ----------
Public Function AW_Sigma(ByVal T As Double, ByVal x As Double) As Double
    Dim TsNH3 As Double, TsH2O As Double
    Dim sN As Double, sW As Double, Fx As Double
    Dim tauN As Double, tauW As Double
    TStar T, x, TsNH3, TsH2O
    tauN = 1# - TsNH3 / T_C_NH3
    tauW = 1# - TsH2O / T_C_H2O
    sN = 91.2 * tauN ^ 1.1028
    sW = 235.8 * (1# - 0.625 * tauW) * tauW ^ 1.256
    Fx = 1.442 * (1# - x) * (1# - Exp(-2.5 * x ^ 4)) _
       + 1.106 * x * (1# - Exp(-2.5 * (1# - x) ^ 6))
    AW_Sigma = (x * sN + (1# - x) * sW - (sW - sN) * Fx) * 0.001
End Function

' ---------- §10 ----------
Public Function AW_RhoLiq(ByVal T As Double, ByVal x As Double) As Double
    Dim TsNH3 As Double, TsH2O As Double
    Dim rN As Double, rW As Double, Td As Double
    Dim s1 As Double, s2 As Double, Ax As Double
    TStar T, x, TsNH3, TsH2O
    rN = RhoLiqPure(TsNH3, True)
    rW = RhoLiqPure(TsH2O, False)
    Td = T / T_C_H2O
    s1 = -2.41 + 8.31 * Td - 6.924 * Td ^ 2
    s2 = 2.118 - 4.05 * Td + 4.443 * Td ^ 2
    Ax = x * s1 + s2
    AW_RhoLiq = x * rN + (1# - x) * rW _
              + x * (1# - x) * (1# - Ax) * Sqr(rN * rW)
End Function

' ---------- §11 ----------
Public Function AW_Diff(ByVal T As Double, ByVal x As Double) As Double
    Dim psi As Double, Msol As Double, Vd As Double, eta As Double
    psi = x * 1.7 + (1# - x) * 2.6
    Msol = x * 17.03 + (1# - x) * 18.0152
    Vd = 17.03 / RhoLiqPure(T, True)
    eta = AW_EtaLiq(T, x)
    AW_Diff = 117.282E-18 * T * Sqr(psi * Msol) / (eta * Vd ^ 0.6)
End Function

' ---------- §12/§13 共用 φ ----------
Private Function Phi12(ByVal e1 As Double, ByVal e2 As Double) As Double
    Dim r As Double
    r = Sqr(e1 / e2) * (18.0152 / 17.03) ^ 0.25
    Phi12 = (1# + r) ^ 2 / Sqr(8# * (1# + 17.03 / 18.0152))
End Function

' ---------- §12 ----------
Public Function AW_LamVap(ByVal T As Double, ByVal y As Double) As Double
    Dim tau As Double, lamN As Double, lamW As Double
    Dim eN As Double, eW As Double, p12 As Double, p21 As Double
    tau = 1# - T / T_C_NH3
    lamN = (-0.48173 + 20.04383 * Log(1# / tau)) * 0.001
    lamW = IapwsLambdaWater(T, RhoVapPure(T, False))
    eN = FenghourEta(T, RhoVapPure(T, True))
    eW = IapwsEtaWater(T, RhoVapPure(T, False))
    p12 = Phi12(eN, eW)
    p21 = p12 * (eW / eN) * (17.03 / 18.0152)
    AW_LamVap = y * lamN / (y + (1# - y) * p12) _
              + (1# - y) * lamW / ((1# - y) + y * p21)
End Function

' ---------- §13 ----------
Public Function AW_EtaVap(ByVal T As Double, ByVal y As Double) As Double
    Dim eN As Double, eW As Double, p12 As Double, p21 As Double
    eN = FenghourEta(T, RhoVapPure(T, True))
    eW = IapwsEtaWater(T, RhoVapPure(T, False))
    p12 = Phi12(eN, eW)
    p21 = p12 * (eW / eN) * (17.03 / 18.0152)
    AW_EtaVap = y * eN / (y + (1# - y) * p12) _
              + (1# - y) * eW / ((1# - y) + y * p21)
End Function

' ---------- §14 ----------
Public Function AW_RhoVap(ByVal T As Double, ByVal y As Double) As Double
    Dim TsNH3 As Double, TsH2O As Double
    Dim rN As Double, rW As Double, Td As Double
    Dim dMax As Double, dRho As Double
    TStar T, y, TsNH3, TsH2O
    rN = RhoVapPure(TsNH3, True)
    rW = RhoVapPure(TsH2O, False)
    Td = T / T_C_H2O
    dMax = Exp(9.952 - 3.884 / Td)
    dRho = 82# * (1# - y) ^ 0.5 * (1# - Exp(-0.05 * y ^ 2.75)) * dMax
    AW_RhoVap = y * rN + (1# - y) * rW + dRho
End Function

' ---------- §15 ----------
Public Function AW_CpVap(ByVal T As Double, ByVal y As Double) As Double
    Dim tau As Double, cpN As Double, cpW As Double
    tau = 1# - T / AW_TcSol(y)
    cpN = -1.199197086 + 1.240129495 * tau ^ (-1# / 3#) _
        + 0.924818752 * tau ^ (-2# / 3#) _
        + 0.018199633 * tau ^ (-5# / 3#) _
        - 0.000245034 * tau ^ (-7.5 / 3#)
    cpW = 3.461825651 - 4.987788063 * tau ^ (-1# / 3#) _
        + 2.99438177 * tau ^ (-2# / 3#) _
        + 0.006259308 * tau ^ (-5# / 3#) _
        - 0.000008262961 * tau ^ (-7.5 / 3#)
    AW_CpVap = y * cpN + (1# - y) * cpW
End Function

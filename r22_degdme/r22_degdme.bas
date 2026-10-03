Attribute VB_Name = "R22DEGDME"
' R22-DEGDME 热力学关联式（Excel VBA 工作表函数）
' 来源：E. Ando, I. Takeshita, Int. J. Refrigeration, Vol.7, No.3, 1984.
'   式(1) 泡点压力 Rankine 方程：lnP = ΣAnX^n + (1/T)ΣBnX^n + lnT·ΣCnX^n
'         P: kg/cm2, T: K, X: R22 摩尔分数；适用 X=0.1~1.0, T=-20~190°C
'   式(6) 摩尔热容：C = ΣAnX^n + t·ΣBnX^n + t^2·ΣCnX^n；C: J/mol/°C, t: °C
'   式(7) 混合热（10°C）：ΔHm = X(1-X)·Σ Gi·(1-2X)^(i-1)；J/mol
'   式(9) 溶液比焓 kJ/kg；参考态：纯组分液体 10°C 焓为 0（本文档约定）
'
' 工作表函数：
'   =R22DEGDME_Pvap(X, t_C)    泡点压力，bar
'   =R22DEGDME_CpMol(X, t_C)   摩尔热容，J/mol/°C
'   =R22DEGDME_dHm(X)          混合热，J/mol（10°C 测定）
'   =R22DEGDME_Hsol(X, t_C)    溶液比焓，kJ/kg
'
' 注意：本模块未在真实 Excel 中编译运行过，使用前请先编译验证。

Option Explicit

Private Const M_R22 As Double = 86.47        ' g/mol
Private Const M_DEGDME As Double = 134.17    ' g/mol
Private Const TM_C As Double = 10#           ' °C
Private Const KGCM2_TO_BAR As Double = 0.980665

' 表2：式(1) n=0..5 (A, B, C)
Private Function T2A(ByVal n As Long) As Double
    Select Case n
        Case 0: T2A = 5.2167E+01
        Case 1: T2A = 1.2753E+01
        Case 2: T2A = -1.3901E+02
        Case 3: T2A = 7.3205E+02
        Case 4: T2A = -1.191E+03
        Case 5: T2A = 5.4717E+02
    End Select
End Function
Private Function T2B(ByVal n As Long) As Double
    Select Case n
        Case 0: T2B = -5.5828E+03
        Case 1: T2B = 3.3999E+03
        Case 2: T2B = -8.6015E+03
        Case 3: T2B = -3.1686E+03
        Case 4: T2B = 3.0425E+04
        Case 5: T2B = -1.9049E+04
    End Select
End Function
Private Function T2C(ByVal n As Long) As Double
    Select Case n
        Case 0: T2C = -6.3489E+00
        Case 1: T2C = -1.4386E+00
        Case 2: T2C = 2.2313E+01
        Case 3: T2C = -1.1454E+02
        Case 4: T2C = 1.8148E+02
        Case 5: T2C = -8.1999E+01
    End Select
End Function

' 表3：式(6) n=0..3 (A, B, C)
Private Function T3A(ByVal n As Long) As Double
    Select Case n
        Case 0: T3A = 2.7974E+02
        Case 1: T3A = -1.5075E+02
        Case 2: T3A = 1.0095E+02
        Case 3: T3A = -1.2802E+02
    End Select
End Function
Private Function T3B(ByVal n As Long) As Double
    Select Case n
        Case 0: T3B = -4.2015E-02
        Case 1: T3B = 5.9865E-01
        Case 2: T3B = -1.379E+00
        Case 3: T3B = 1.0167E+00
    End Select
End Function
Private Function T3C(ByVal n As Long) As Double
    Select Case n
        Case 0: T3C = 2.3114E-03
        Case 1: T3C = -5.9745E-03
        Case 2: T3C = 3.4322E-03
        Case 3: T3C = 1.0571E-03
    End Select
End Function

' 式(7)：G1..G4
Private Function Gk(ByVal i As Long) As Double
    Select Case i
        Case 1: Gk = -1.9061E+04
        Case 2: Gk = 8.728E+03
        Case 3: Gk = -1.3948E+03
        Case 4: Gk = -6.4218E+02
    End Select
End Function

' 式(1)：泡点压力，kg/cm2（T_K 开尔文）
Public Function R22DEGDME_Pvap_kgcm2(ByVal X As Double, ByVal T_K As Double) As Double
    Dim sA As Double, sB As Double, sC As Double, xn As Double, n As Long
    xn = 1#
    For n = 0 To 5
        sA = sA + T2A(n) * xn
        sB = sB + T2B(n) * xn
        sC = sC + T2C(n) * xn
        xn = xn * X
    Next n
    R22DEGDME_Pvap_kgcm2 = Exp(sA + sB / T_K + sC * Log(T_K))
End Function

' 式(1)：泡点压力，bar（t_C 摄氏度）
Public Function R22DEGDME_Pvap(ByVal X As Double, ByVal t_C As Double) As Double
    R22DEGDME_Pvap = R22DEGDME_Pvap_kgcm2(X, t_C + 273.15) * KGCM2_TO_BAR
End Function

' 式(6)：摩尔热容，J/mol/°C
Public Function R22DEGDME_CpMol(ByVal X As Double, ByVal t_C As Double) As Double
    Dim sA As Double, sB As Double, sC As Double, xn As Double, n As Long
    xn = 1#
    For n = 0 To 3
        sA = sA + T3A(n) * xn
        sB = sB + T3B(n) * xn
        sC = sC + T3C(n) * xn
        xn = xn * X
    Next n
    R22DEGDME_CpMol = sA + t_C * sB + t_C * t_C * sC
End Function

' 式(7)：混合热，J/mol（10°C 测定，放热为负）
Public Function R22DEGDME_dHm(ByVal X As Double) As Double
    Dim s As Double, p As Double, d As Double, i As Long
    d = 1# - 2# * X: p = 1#: s = 0#
    For i = 1 To 4
        s = s + Gk(i) * p
        p = p * d
    Next i
    R22DEGDME_dHm = X * (1# - X) * s
End Function

' 式(9)：溶液比焓，kJ/kg；参考态：纯组分液体 10°C 焓为 0
Public Function R22DEGDME_Hsol(ByVal X As Double, ByVal t_C As Double) As Double
    Dim sA As Double, sB As Double, sC As Double, xn As Double, n As Long
    Dim sensible As Double, h_mol As Double, M_mix As Double, t0 As Double
    xn = 1#
    For n = 0 To 3
        sA = sA + T3A(n) * xn
        sB = sB + T3B(n) * xn
        sC = sC + T3C(n) * xn
        xn = xn * X
    Next n
    t0 = TM_C
    sensible = sA * (t_C - t0) _
             + sB * (t_C * t_C - t0 * t0) / 2# _
             + sC * (t_C * t_C * t_C - t0 * t0 * t0) / 3#
    h_mol = R22DEGDME_dHm(X) + sensible
    M_mix = X * M_R22 + (1# - X) * M_DEGDME
    R22DEGDME_Hsol = h_mol / M_mix
End Function

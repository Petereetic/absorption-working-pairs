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
'   =Psol_R22DEGDME(X, t_C)    泡点压力，MPa（注意：函数名为原名保留、改名待裁，返回值单位已由 bar 改为 MPa）
'   =XiByTsolTdew_R22DEGDME(Tdew_C, Tsol_C)  由露点/溶液温度反解 X，无根返回 Empty
'   =CpMol_R22DEGDME(X, t_C)   摩尔热容，J/mol/°C
'   =dHm_R22DEGDME(X)          混合热，J/mol（10°C 测定）
'   =hsol_R22DEGDME(X, t_C)    溶液比焓，kJ/kg
'
' 注意：本模块未在真实 Excel 中编译运行过，使用前请先编译验证。

Option Explicit

Private Const M_R22 As Double = 86.47        ' g/mol
Private Const M_DEGDME As Double = 134.17    ' g/mol
Private Const TM_C As Double = 10#           ' °C
Private Const KGCM2_TO_MPA As Double = 0.0980665  ' 1 kg/cm2 = 0.0980665 MPa（精确定义）

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
Public Function Psol_kgcm2_R22DEGDME(ByVal X As Double, ByVal T_K As Double) As Double
    Dim sA As Double, sB As Double, sC As Double, xn As Double, n As Long
    xn = 1#
    For n = 0 To 5
        sA = sA + T2A(n) * xn
        sB = sB + T2B(n) * xn
        sC = sC + T2C(n) * xn
        xn = xn * X
    Next n
    Psol_kgcm2_R22DEGDME = Exp(sA + sB / T_K + sC * Log(T_K))
End Function

' 式(1)：泡点压力，MPa（t_C 摄氏度）
' 【注意：函数名 Psol_R22DEGDME 为原名保留（改名待裁），返回值单位
' 已由 bar 改为 MPa】＝原生 kg/cm2 值 ×0.0980665。
Public Function Psol_R22DEGDME(ByVal X As Double, ByVal t_C As Double) As Double
    Psol_R22DEGDME = Psol_kgcm2_R22DEGDME(X, t_C + 273.15) * KGCM2_TO_MPA
End Function

' 由露点温度与溶液温度反解浓度 X（R22 摩尔分数），二分 80 次。
' 露点定压 P = Psol_kgcm2_R22DEGDME(1, Tdew_C + 273.15) [kg/cm2 原生]：
' 式(1) 在 X=1 端即本模块的纯 R22 饱和压力（DEGDME 视为不挥发）；再二分求
' Psol_kgcm2_R22DEGDME(X, Tsol_C + 273.15) = P，括号取式(1) 有效浓度域 X ∈ [0.1, 1]。
' 内部一律走原生 kg/cm2 函数（不经 MPa 导出线），保证浓度输出逐位不变。
' 无根时返回 Empty（如 Tsol 明显低于 Tdew）。
' 注：与 C/Python 同算法，本 VBA 未在真实 Excel 中编译测试。
Public Function XiByTsolTdew_R22DEGDME(ByVal Tsol_C As Double, ByVal Tdew_C As Double) As Variant
    Dim P As Double, lo As Double, hi As Double, mid As Double, k As Long
    P = Psol_kgcm2_R22DEGDME(1#, Tdew_C + 273.15)
    If P < Psol_kgcm2_R22DEGDME(0.1, Tsol_C + 273.15) Or P > Psol_kgcm2_R22DEGDME(1#, Tsol_C + 273.15) Then
        XiByTsolTdew_R22DEGDME = Empty
        Exit Function
    End If
    lo = 0.1: hi = 1#
    For k = 1 To 80
        mid = 0.5 * (lo + hi)
        If Psol_kgcm2_R22DEGDME(mid, Tsol_C + 273.15) < P Then lo = mid Else hi = mid
    Next k
    XiByTsolTdew_R22DEGDME = 0.5 * (lo + hi)
End Function


' ---------- 露点温度（溶液）[°C]：全库 TdewByTsolXi 约定 ----------
' Tdew 为本模块自有纯 R22 线（式(1) X=1 端）上满足
' Psol_kgcm2_R22DEGDME(1, Tdew + 273.15) = Psol_kgcm2_R22DEGDME(X, t_C + 273.15)
' [kg/cm2 原生] 的温度，二分 80 次反解，括号 t ∈ [-50, 190] °C。
' 内部一律走原生 kg/cm2 函数（不经 MPa 导出线），保证温度输出逐位不变。
' 注意：式(1) 标称温度辖区 -20~190 °C，Tdew < -20 °C 为纯端外推，引用须标注。
' DEGDME 视为不挥发。无根返回 Empty。
' （本模块函数惯例为 (X, T) 参数序，本函数从之。）
Public Function TdewByTsolXi_R22DEGDME(ByVal X As Double, ByVal t_C As Double) As Variant
    Dim P As Double, lo As Double, hi As Double, mid As Double, k As Long
    P = Psol_kgcm2_R22DEGDME(X, t_C + 273.15)
    lo = -50#: hi = 190#
    If P < Psol_kgcm2_R22DEGDME(1#, lo + 273.15) Or P > Psol_kgcm2_R22DEGDME(1#, hi + 273.15) Then
        TdewByTsolXi_R22DEGDME = Empty: Exit Function
    End If
    For k = 1 To 80
        mid = 0.5 * (lo + hi)
        If Psol_kgcm2_R22DEGDME(1#, mid + 273.15) < P Then lo = mid Else hi = mid
    Next k
    TdewByTsolXi_R22DEGDME = 0.5 * (lo + hi)
End Function

' ---------- 由溶液比焓反解溶液温度 [°C] ----------
' hsol_R22DEGDME 在固定 X 下随 t 单调增，二分 100 次反解，
' 求解括号 t ∈ [-30, 110] °C。h 超出值域返回 Empty。
' 与 C/Python 同算法；本函数未在真实 Excel 中编译运行。
Public Function TsolByHsol_R22DEGDME(ByVal h As Double, ByVal X As Double) As Variant
    Dim lo As Double, hi As Double, mid As Double, k As Long
    lo = -30#: hi = 110#
    If h < hsol_R22DEGDME(X, lo) Or h > hsol_R22DEGDME(X, hi) Then
        TsolByHsol_R22DEGDME = Empty: Exit Function
    End If
    For k = 1 To 100
        mid = 0.5 * (lo + hi)
        If hsol_R22DEGDME(X, mid) < h Then lo = mid Else hi = mid
    Next k
    TsolByHsol_R22DEGDME = 0.5 * (lo + hi)
End Function

' 式(6)：摩尔热容，J/mol/°C
Public Function CpMol_R22DEGDME(ByVal X As Double, ByVal t_C As Double) As Double
    Dim sA As Double, sB As Double, sC As Double, xn As Double, n As Long
    xn = 1#
    For n = 0 To 3
        sA = sA + T3A(n) * xn
        sB = sB + T3B(n) * xn
        sC = sC + T3C(n) * xn
        xn = xn * X
    Next n
    CpMol_R22DEGDME = sA + t_C * sB + t_C * t_C * sC
End Function

' 式(7)：混合热，J/mol（10°C 测定，放热为负）
Public Function dHm_R22DEGDME(ByVal X As Double) As Double
    Dim s As Double, p As Double, d As Double, i As Long
    d = 1# - 2# * X: p = 1#: s = 0#
    For i = 1 To 4
        s = s + Gk(i) * p
        p = p * d
    Next i
    dHm_R22DEGDME = X * (1# - X) * s
End Function

' 式(9)：溶液比焓，kJ/kg；参考态：纯组分液体 10°C 焓为 0
Public Function hsol_R22DEGDME(ByVal X As Double, ByVal t_C As Double) As Double
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
    h_mol = dHm_R22DEGDME(X) + sensible
    M_mix = X * M_R22 + (1# - X) * M_DEGDME
    hsol_R22DEGDME = h_mol / M_mix
End Function

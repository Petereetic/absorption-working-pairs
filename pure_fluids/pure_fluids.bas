Attribute VB_Name = "PureFluids"
' R134a / R22 纯物质饱和性质（Excel VBA 工作表函数）
' 基准：CoolProp 内置参考状态方程（R134a: Tillner-Roth & Baehr 1994）
' 参考态：0°C 饱和液体焓 = 100 kJ/kg（与用户现有模型统一）
'
' 工作表函数：
'   =Pref_R134a(t_C)  饱和压力 bar，t_C: °C（-50~95）
'   =R134a_Tsat(P_bar) 饱和温度 °C，P_bar: bar
'   =hliq_R134a(t_C)    饱和液体焓 kJ/kg
'   =hgas_R134a(t_C)    饱和蒸气焓 kJ/kg
'   =Pref_R22(t_C)    饱和压力 bar（-50~90）
'   =R22_Tsat(P_bar)  饱和温度 °C
'   =hliq_R22(t_C)      饱和液体焓 kJ/kg
'   =hgas_R22(t_C)      饱和蒸气焓 kJ/kg
'   =Pref_R124(t_C)   R124 饱和压力 bar（-40~110；NIST 表 Wagner 拟合）
'   =Tsat_R124(P_bar) R124 饱和温度 °C
'   =hliq_R124(t_C)     R124 饱和液体焓 kJ/kg（基准同上，已平移）
'   =hgas_R124(t_C)     R124 饱和蒸气焓 kJ/kg
' （R124 函数名用"属性在前"式：Excel 工作表不接受 R+数字打头的函数名）
'
' 注意：本模块未在真实 Excel 中编译运行过，使用前请先编译验证。

Option Explicit

' ---------- R134a 常数 ----------
Private Const R134A_TC As Double = 374.21
Private Const R134A_PC As Double = 40.59
Private Const R134A_TLO As Double = -50#
Private Const R134A_THI As Double = 95#

Private Function R134aW(ByVal i As Long) As Double
    Select Case i
        Case 0: R134aW = -7.6391282
        Case 1: R134aW = 1.7650117
        Case 2: R134aW = -2.6103553
        Case 3: R134aW = -3.365738
    End Select
End Function

Private Function R134aHLc(ByVal i As Long) As Double
    Select Case i
        Case 0: R134aHLc = 3.5283163E-11
        Case 1: R134aHLc = -2.2259203E-09
        Case 2: R134aHLc = -7.2651551E-08
        Case 3: R134aHLc = 1.3659406E-05
        Case 4: R134aHLc = 1.4602205E-03
        Case 5: R134aHLc = 1.3386046E+00
        Case 6: R134aHLc = 9.9982381E+01
    End Select
End Function

Private Function R134aHVc(ByVal i As Long) As Double
    Select Case i
        Case 0: R134aHVc = -5.4059642E-11
        Case 1: R134aHVc = 3.2801028E-09
        Case 2: R134aHVc = 1.2592287E-07
        Case 3: R134aHVc = -2.100514E-05
        Case 4: R134aHVc = -1.2602316E-03
        Case 5: R134aHVc = 5.908568E-01
        Case 6: R134aHVc = 2.9863031E+02
    End Select
End Function

' ---------- R22 常数 ----------
Private Const R22_TC As Double = 369.3
Private Const R22_PC As Double = 49.9
Private Const R22_TLO As Double = -50#
Private Const R22_THI As Double = 90#

Private Function R22W(ByVal i As Long) As Double
    Select Case i
        Case 0: R22W = -7.048623
        Case 1: R22W = 1.4828095
        Case 2: R22W = -1.8223105
        Case 3: R22W = -2.8257753
    End Select
End Function

Private Function R22HLc(ByVal i As Long) As Double
    Select Case i
        Case 0: R22HLc = 4.6681599E-11
        Case 1: R22HLc = -2.2286115E-09
        Case 2: R22HLc = -1.2586426E-07
        Case 3: R22HLc = 1.4969301E-05
        Case 4: R22HLc = 1.5173919E-03
        Case 5: R22HLc = 1.167803E+00
        Case 6: R22HLc = 9.9972867E+01
    End Select
End Function

Private Function R22HVc(ByVal i As Long) As Double
    Select Case i
        Case 0: R22HVc = -6.541236E-11
        Case 1: R22HVc = 3.1584987E-09
        Case 2: R22HVc = 1.6628519E-07
        Case 3: R22HVc = -2.1606737E-05
        Case 4: R22HVc = -1.9128189E-03
        Case 5: R22HVc = 3.7574587E-01
        Case 6: R22HVc = 3.050864E+02
    End Select
End Function

' ---------- 内部：Wagner 饱和压力 ----------
Private Function WagnerPref(ByVal t_C As Double, ByVal Tc As Double, _
    ByVal Pc As Double, ByVal fluid As Long) As Double
    Dim T As Double, tau As Double, s As Double, i As Long
    T = t_C + 273.15
    tau = 1# - T / Tc
    s = 0#
    For i = 0 To 3
        Dim a As Double
        If fluid = 1 Then a = R134aW(i) Else a = R22W(i)
        Select Case i
            Case 0: s = s + a * tau
            Case 1: s = s + a * tau ^ 1.5
            Case 2: s = s + a * tau ^ 2.5
            Case 3: s = s + a * tau ^ 5#
        End Select
    Next i
    WagnerPref = Pc * Exp((Tc / T) * s)
End Function

' ---------- 内部：6 次多项式 ----------
Private Function Poly6(ByVal t As Double, ByVal fluid As Long, ByVal isVap As Boolean) As Double
    Dim c(0 To 6) As Double, i As Long, r As Double
    For i = 0 To 6
        If fluid = 1 Then
            If isVap Then c(i) = R134aHVc(i) Else c(i) = R134aHLc(i)
        Else
            If isVap Then c(i) = R22HVc(i) Else c(i) = R22HLc(i)
        End If
    Next i
    r = c(0)
    For i = 1 To 6
        r = r * t + c(i)
    Next i
    Poly6 = r
End Function

' ---------- 内部：二分法反算饱和温度 ----------
Private Function TsatBisect(ByVal P_bar As Double, ByVal fluid As Long) As Double
    Dim lo As Double, hi As Double, mid As Double, i As Long
    Dim tlo As Double, thi As Double, Tc As Double, Pc As Double
    If fluid = 1 Then
        tlo = R134A_TLO: thi = R134A_THI: Tc = R134A_TC: Pc = R134A_PC
    Else
        tlo = R22_TLO: thi = R22_THI: Tc = R22_TC: Pc = R22_PC
    End If
    If P_bar < WagnerPref(tlo, Tc, Pc, fluid) Or P_bar > WagnerPref(thi, Tc, Pc, fluid) Then
        TsatBisect = CVErr(xlErrNum)
        Exit Function
    End If
    lo = tlo: hi = thi
    For i = 1 To 60
        mid = 0.5 * (lo + hi)
        If WagnerPref(mid, Tc, Pc, fluid) < P_bar Then lo = mid Else hi = mid
    Next i
    TsatBisect = 0.5 * (lo + hi)
End Function

' ================= R134a 工作表函数 =================
Public Function Pref_R134a(ByVal t_C As Double) As Double
    Pref_R134a = WagnerPref(t_C, R134A_TC, R134A_PC, 1)
End Function

Public Function R134a_Tsat(ByVal P_bar As Double) As Variant
    R134a_Tsat = TsatBisect(P_bar, 1)
End Function

Public Function hliq_R134a(ByVal t_C As Double) As Double
    hliq_R134a = Poly6(t_C, 1, False)
End Function

Public Function hgas_R134a(ByVal t_C As Double) As Double
    hgas_R134a = Poly6(t_C, 1, True)
End Function

' R134a 饱和潜热 kJ/kg = hgas - hliq（同一参考态）
Public Function hlat_R134a(ByVal t_C As Double) As Double
    hlat_R134a = hgas_R134a(t_C) - hliq_R134a(t_C)
End Function

' ================= R22 工作表函数 =================
Public Function Pref_R22(ByVal t_C As Double) As Double
    Pref_R22 = WagnerPref(t_C, R22_TC, R22_PC, 2)
End Function

Public Function R22_Tsat(ByVal P_bar As Double) As Variant
    R22_Tsat = TsatBisect(P_bar, 2)
End Function

Public Function hliq_R22(ByVal t_C As Double) As Double
    hliq_R22 = Poly6(t_C, 2, False)
End Function

Public Function hgas_R22(ByVal t_C As Double) As Double
    hgas_R22 = Poly6(t_C, 2, True)
End Function

' R22 饱和潜热 kJ/kg = hgas - hliq（同一参考态）
Public Function hlat_R22(ByVal t_C As Double) As Double
    hlat_R22 = hgas_R22(t_C) - hliq_R22(t_C)
End Function

' ================= R124（NIST WebBook 饱和表拟合） =================
' Psat: Wagner 变体 ln(P/Pc)=(Tc/T)(a1 τ+a2 τ^1.5+a3 τ^3+a4 τ^6)，τ=1-T/Tc
'   Tc=395.428K, Pc=36.245bar；适用 -40~110°C，对表最大偏差 0.111%
' 焓: 6 次多项式；表基准 0°C 液体 = 200 kJ/kg，已整体平移 -100 与本模块统一
'   同带最大偏差 hf 1.11、hg 1.63 kJ/kg
Private Const R124_TC As Double = 395.428
Private Const R124_PC As Double = 36.245
Private Const R124_TLO As Double = -40#
Private Const R124_THI As Double = 110#

Private Function R124W(ByVal i As Long) As Double
    Select Case i
        Case 0: R124W = -7.401179377235425
        Case 1: R124W = 1.4613603991162563
        Case 2: R124W = -3.476435267708954
        Case 3: R124W = -1.772232810745864
    End Select
End Function

Private Function R124HLc(ByVal i As Long) As Double
    Select Case i
        Case 0: R124HLc = 3.101121704716488E-12
        Case 1: R124HLc = 6.118884579625834E-10
        Case 2: R124HLc = -1.0126584362284601E-08
        Case 3: R124HLc = -3.744431218418699E-06
        Case 4: R124HLc = 9.264564201937477E-04
        Case 5: R124HLc = 1.0995525531984227
        Case 6: R124HLc = 1.0004767130193036E+02
    End Select
End Function

Private Function R124HVc(ByVal i As Long) As Double
    Select Case i
        Case 0: R124HVc = -4.7606354686130485E-12
        Case 1: R124HVc = -9.020883920792309E-10
        Case 2: R124HVc = 2.036341936229362E-08
        Case 3: R124HVc = 4.234769176716097E-06
        Case 4: R124HVc = -3.8033802108463233E-04
        Case 5: R124HVc = 5.621038923140594E-01
        Case 6: R124HVc = 2.5994742998138406E+02
    End Select
End Function

Private Function WagnerPref36_R124(ByVal t_C As Double) As Double
    Dim T As Double, tau As Double, s As Double
    T = t_C + 273.15
    tau = 1# - T / R124_TC
    s = R124W(0) * tau + R124W(1) * tau ^ 1.5 + R124W(2) * tau ^ 3# + R124W(3) * tau ^ 6#
    WagnerPref36_R124 = R124_PC * Exp((R124_TC / T) * s)
End Function

Private Function Poly6_R124(ByVal t As Double, ByVal isVap As Boolean) As Double
    Dim c(0 To 6) As Double, i As Long, r As Double
    For i = 0 To 6
        If isVap Then c(i) = R124HVc(i) Else c(i) = R124HLc(i)
    Next i
    r = c(0)
    For i = 1 To 6
        r = r * t + c(i)
    Next i
    Poly6_R124 = r
End Function

Private Function TsatBisect_R124(ByVal P_bar As Double) As Double
    Dim lo As Double, hi As Double, mid As Double, i As Long
    If P_bar < WagnerPref36_R124(R124_TLO) Or P_bar > WagnerPref36_R124(R124_THI) Then
        TsatBisect_R124 = CVErr(xlErrNum)
        Exit Function
    End If
    lo = R124_TLO: hi = R124_THI
    For i = 1 To 60
        mid = 0.5 * (lo + hi)
        If WagnerPref36_R124(mid) < P_bar Then lo = mid Else hi = mid
    Next i
    TsatBisect_R124 = 0.5 * (lo + hi)
End Function

Public Function Pref_R124(ByVal t_C As Double) As Double
    Pref_R124 = WagnerPref36_R124(t_C)
End Function

Public Function Tsat_R124(ByVal P_bar As Double) As Variant
    Tsat_R124 = TsatBisect_R124(P_bar)
End Function

Public Function hliq_R124(ByVal t_C As Double) As Double
    hliq_R124 = Poly6_R124(t_C, False)
End Function

Public Function hgas_R124(ByVal t_C As Double) As Double
    hgas_R124 = Poly6_R124(t_C, True)
End Function

' R124 饱和潜热 kJ/kg = hgas - hliq（同一参考态）
Public Function hlat_R124(ByVal t_C As Double) As Double
    hlat_R124 = hgas_R124(t_C) - hliq_R124(t_C)
End Function

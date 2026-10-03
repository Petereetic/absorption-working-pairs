Attribute VB_Name = "PureFluids"
' R134a / R22 纯物质饱和性质（Excel VBA 工作表函数）
' 基准：CoolProp 内置参考状态方程（R134a: Tillner-Roth & Baehr 1994）
' 参考态：0°C 饱和液体焓 = 100 kJ/kg（与用户现有模型统一）
'
' 工作表函数：
'   =R134a_Psat(t_C)  饱和压力 bar，t_C: °C（-50~95）
'   =R134a_Tsat(P_bar) 饱和温度 °C，P_bar: bar
'   =R134a_hL(t_C)    饱和液体焓 kJ/kg
'   =R134a_hV(t_C)    饱和蒸气焓 kJ/kg
'   =R22_Psat(t_C)    饱和压力 bar（-50~90）
'   =R22_Tsat(P_bar)  饱和温度 °C
'   =R22_hL(t_C)      饱和液体焓 kJ/kg
'   =R22_hV(t_C)      饱和蒸气焓 kJ/kg
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
Private Function WagnerPsat(ByVal t_C As Double, ByVal Tc As Double, _
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
    WagnerPsat = Pc * Exp((Tc / T) * s)
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
    If P_bar < WagnerPsat(tlo, Tc, Pc, fluid) Or P_bar > WagnerPsat(thi, Tc, Pc, fluid) Then
        TsatBisect = CVErr(xlErrNum)
        Exit Function
    End If
    lo = tlo: hi = thi
    For i = 1 To 60
        mid = 0.5 * (lo + hi)
        If WagnerPsat(mid, Tc, Pc, fluid) < P_bar Then lo = mid Else hi = mid
    Next i
    TsatBisect = 0.5 * (lo + hi)
End Function

' ================= R134a 工作表函数 =================
Public Function R134a_Psat(ByVal t_C As Double) As Double
    R134a_Psat = WagnerPsat(t_C, R134A_TC, R134A_PC, 1)
End Function

Public Function R134a_Tsat(ByVal P_bar As Double) As Variant
    R134a_Tsat = TsatBisect(P_bar, 1)
End Function

Public Function R134a_hL(ByVal t_C As Double) As Double
    R134a_hL = Poly6(t_C, 1, False)
End Function

Public Function R134a_hV(ByVal t_C As Double) As Double
    R134a_hV = Poly6(t_C, 1, True)
End Function

' ================= R22 工作表函数 =================
Public Function R22_Psat(ByVal t_C As Double) As Double
    R22_Psat = WagnerPsat(t_C, R22_TC, R22_PC, 2)
End Function

Public Function R22_Tsat(ByVal P_bar As Double) As Variant
    R22_Tsat = TsatBisect(P_bar, 2)
End Function

Public Function R22_hL(ByVal t_C As Double) As Double
    R22_hL = Poly6(t_C, 2, False)
End Function

Public Function R22_hV(ByVal t_C As Double) As Double
    R22_hV = Poly6(t_C, 2, True)
End Function

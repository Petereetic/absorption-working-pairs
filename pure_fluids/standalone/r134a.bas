Attribute VB_Name = "R134a"
' R134a 纯物质饱和性质（单独计算文件，Excel VBA 工作表函数；与合并模块 pure_fluids.bas 系数逐字同源）
' 源：CoolProp 参考状态方程（Tillner-Roth & Baehr 1994）拟合，与合并模块 pure_fluids 系数逐字相同；Wagner 饱和压最大偏差 0.031%，焓偏差 0.41/0.61 kJ/kg；参考态 0°C 饱和液体 = 100 kJ/kg。
' 参考态：0°C 饱和液体焓 = 100 kJ/kg（模块统一基准）。Pref 返回 bar；Tsat 超界返回 #NUM!。
' 注意：本模块未在真实 Excel 中编译运行过，使用前请先编译验证。

Option Explicit

Private Const TC As Double = 374.21
Private Const PC As Double = 40.59
Private Const TLO As Double = -50.0
Private Const THI As Double = 95.0

Private Function Wc(ByVal i As Long) As Double
    Select Case i
        Case 0: Wc = -7.6391282
        Case 1: Wc = 1.7650117
        Case 2: Wc = -2.6103553
        Case 3: Wc = -3.365738
    End Select
End Function

Private Function HLc(ByVal i As Long) As Double
    Select Case i
        Case 0: HLc = 3.5283163E-11
        Case 1: HLc = -2.2259203E-09
        Case 2: HLc = -7.2651551E-08
        Case 3: HLc = 1.3659406E-05
        Case 4: HLc = 0.0014602205
        Case 5: HLc = 1.3386046
        Case 6: HLc = 99.982381
    End Select
End Function

Private Function HVc(ByVal i As Long) As Double
    Select Case i
        Case 0: HVc = -5.4059642E-11
        Case 1: HVc = 3.2801028E-09
        Case 2: HVc = 1.2592287E-07
        Case 3: HVc = -2.100514E-05
        Case 4: HVc = -0.0012602316
        Case 5: HVc = 0.5908568
        Case 6: HVc = 298.63031
    End Select
End Function

Private Function PrefRaw(ByVal t_C As Double) As Double
    Dim T As Double, tau As Double, s As Double
    T = t_C + 273.15
    tau = 1# - T / TC
    s = Wc(0) * tau + Wc(1) * tau ^ 1.5 + Wc(2) * tau ^ 2.5 + Wc(3) * tau ^ 5#
    PrefRaw = PC * Exp((TC / T) * s)
End Function

Private Function Poly6(ByVal t As Double, ByVal isVap As Boolean) As Double
    Dim c(0 To 6) As Double, i As Long, r As Double
    For i = 0 To 6
        If isVap Then c(i) = HVc(i) Else c(i) = HLc(i)
    Next i
    r = c(0)
    For i = 1 To 6
        r = r * t + c(i)
    Next i
    Poly6 = r
End Function

Private Function TsatBisect(ByVal P_bar As Double) As Double
    Dim lo As Double, hi As Double, mid As Double, i As Long
    If P_bar < PrefRaw(TLO) Or P_bar > PrefRaw(THI) Then
        TsatBisect = CVErr(xlErrNum)
        Exit Function
    End If
    lo = TLO: hi = THI
    For i = 1 To 60
        mid = 0.5 * (lo + hi)
        If PrefRaw(mid) < P_bar Then lo = mid Else hi = mid
    Next i
    TsatBisect = 0.5 * (lo + hi)
End Function

Public Function Pref_R134a(ByVal t_C As Double) As Double
    Pref_R134a = PrefRaw(t_C)
End Function

Public Function R134a_Tsat(ByVal P_bar As Double) As Variant
    R134a_Tsat = TsatBisect(P_bar)
End Function

Public Function hliq_R134a(ByVal t_C As Double) As Double
    hliq_R134a = Poly6(t_C, False)
End Function

Public Function hgas_R134a(ByVal t_C As Double) As Double
    hgas_R134a = Poly6(t_C, True)
End Function

' R134a 饱和潜热 kJ/kg = hgas - hliq（同一参考态）
Public Function hlat_R134a(ByVal t_C As Double) As Double
    hlat_R134a = hgas_R134a(t_C) - hliq_R134a(t_C)
End Function

Attribute VB_Name = "R218"
' R218 纯物质饱和性质（单独计算文件，Excel VBA 工作表函数；与合并模块 pure_fluids.bas 系数逐字同源）
' 源：NIST WebBook 饱和表紧凑拟合（笔记见 ../fit-notes/R218饱和性质拟合-NIST表.md）；饱和压 lnP-t 7 次式，对表全程最大 0.1495%、常用带（-100~50°C）0.0396%；焓已由表基准平移 -100.177980782 至统一基准。
' 参考态：0°C 饱和液体焓 = 100 kJ/kg（模块统一基准）。Pref 返回 MPa；Tsat 入参 MPa 超界返回 #NUM!。
' 注意：本模块未在真实 Excel 中编译运行过，使用前请先编译验证。

Option Explicit

Private Const TLO As Double = -147.0
Private Const THI As Double = 71.0

Private Function LnPc(ByVal i As Long) As Double
    Select Case i
        Case 0: LnPc = 8.255415504414131E-16
        Case 1: LnPc = 7.344897883851216E-14
        Case 2: LnPc = 1.093452574911193E-11
        Case 3: LnPc = -2.800385114611927E-09
        Case 4: LnPc = 6.13844960232108E-07
        Case 5: LnPc = -0.00013063706572324828
        Case 6: LnPc = 0.03248293004447796
        Case 7: LnPc = -0.8809937809605295
    End Select
End Function

Private Function HLc(ByVal i As Long) As Double
    Select Case i
        Case 0: HLc = 7.040720312389206E-12
        Case 1: HLc = 2.1911253182755153E-09
        Case 2: HLc = 1.9931060577128075E-07
        Case 3: HLc = 4.329266994236428E-06
        Case 4: HLc = 0.0010980864706317968
        Case 5: HLc = 1.070171579409284
        Case 6: HLc = 100.0
    End Select
End Function

Private Function HVc(ByVal i As Long) As Double
    Select Case i
        Case 0: HVc = -1.0731550245287959E-11
        Case 1: HVc = -3.374732945181214E-09
        Case 2: HVc = -3.125522092678402E-07
        Case 3: HVc = -8.835005867404636E-06
        Case 4: HVc = -2.3183839296438865E-05
        Case 5: HVc = 0.596775089781136
        Case 6: HVc = 189.38572453841817
    End Select
End Function

Private Function LnPPref(ByVal t_C As Double) As Double
    Dim c(0 To 7) As Double, i As Long, r As Double
    For i = 0 To 7
        c(i) = LnPc(i)
    Next i
    r = c(0)
    For i = 1 To 7
        r = r * t_C + c(i)
    Next i
    LnPPref = Exp(r)
End Function

Private Function PrefRaw(ByVal t_C As Double) As Double
    PrefRaw = LnPPref(t_C)
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

Private Function TsatBisect(ByVal P_MPa As Double) As Double
    Dim lo As Double, hi As Double, mid As Double, i As Long
    If P_MPa < PrefRaw(TLO) Or P_MPa > PrefRaw(THI) Then
        TsatBisect = CVErr(xlErrNum)
        Exit Function
    End If
    lo = TLO: hi = THI
    For i = 1 To 60
        mid = 0.5 * (lo + hi)
        If PrefRaw(mid) < P_MPa Then lo = mid Else hi = mid
    Next i
    TsatBisect = 0.5 * (lo + hi)
End Function

Public Function Pref_R218(ByVal t_C As Double) As Double
    Pref_R218 = PrefRaw(t_C)
End Function

Public Function Tsat_R218(ByVal P_MPa As Double) As Variant
    Tsat_R218 = TsatBisect(P_MPa)
End Function

Public Function hliq_R218(ByVal t_C As Double) As Double
    hliq_R218 = Poly6(t_C, False)
End Function

Public Function hgas_R218(ByVal t_C As Double) As Double
    hgas_R218 = Poly6(t_C, True)
End Function

' R218 饱和潜热 kJ/kg = hgas - hliq（同一参考态）
Public Function hlat_R218(ByVal t_C As Double) As Double
    hlat_R218 = hgas_R218(t_C) - hliq_R218(t_C)
End Function

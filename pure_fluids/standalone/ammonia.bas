Attribute VB_Name = "Ammonia"
' NH3 纯物质饱和性质（单独计算文件，Excel VBA 工作表函数；与合并模块 pure_fluids.bas 系数逐字同源）
' 源：NIST WebBook 饱和表紧凑拟合（笔记见 ../fit-notes/纯氨饱和性质拟合-NIST表.md）；饱和压 lnP-t 7 次式，对表全程最大 0.0272%、常用带（-50~60°C）0.0027%；焓已由表基准平移 -244.768062686 至统一基准。
' 参考态：0°C 饱和液体焓 = 100 kJ/kg（模块统一基准）。Pref 返回 MPa；Tsat 入参 MPa 超界返回 #NUM!。
' 注意：本模块未在真实 Excel 中编译运行过，使用前请先编译验证。

Option Explicit

Private Const TLO As Double = -77.0
Private Const THI As Double = 132.0

Private Function LnPc(ByVal i As Long) As Double
    Select Case i
        Case 0: LnPc = 1.1501679663496297E-16
        Case 1: LnPc = -3.681466540446358E-14
        Case 2: LnPc = 9.070213653911228E-12
        Case 3: LnPc = -2.4759314474490567E-09
        Case 4: LnPc = 6.551063627525382E-07
        Case 5: LnPc = -0.00015333383280607642
        Case 6: LnPc = 0.03739502393748032
        Case 7: LnPc = -0.8457026848887617
    End Select
End Function

Private Function HLc(ByVal i As Long) As Double
    Select Case i
        Case 0: HLc = 1.0230389195910096E-10
        Case 1: HLc = -9.01173619674778E-09
        Case 2: HLc = -7.693180171285098E-07
        Case 3: HLc = 8.148925711345767E-05
        Case 4: HLc = 0.0049020842504556555
        Case 5: HLc = 4.529640315972919
        Case 6: HLc = 100.0
    End Select
End Function

Private Function HVc(ByVal i As Long) As Double
    Select Case i
        Case 0: HVc = -1.5323246964436346E-10
        Case 1: HVc = 1.341154075047321E-08
        Case 2: HVc = 1.181178610537754E-06
        Case 3: HVc = -0.000132743256804236
        Case 4: HVc = -0.01090080493286388
        Case 5: HVc = 1.2129121114680004
        Case 6: HVc = 1364.0392422964662
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

Public Function Pref_NH3(ByVal t_C As Double) As Double
    Pref_NH3 = PrefRaw(t_C)
End Function

Public Function Tsat_NH3(ByVal P_MPa As Double) As Variant
    Tsat_NH3 = TsatBisect(P_MPa)
End Function

Public Function hliq_NH3(ByVal t_C As Double) As Double
    hliq_NH3 = Poly6(t_C, False)
End Function

Public Function hgas_NH3(ByVal t_C As Double) As Double
    hgas_NH3 = Poly6(t_C, True)
End Function

' NH3 饱和潜热 kJ/kg = hgas - hliq（同一参考态）
Public Function hlat_NH3(ByVal t_C As Double) As Double
    hlat_NH3 = hgas_NH3(t_C) - hliq_NH3(t_C)
End Function

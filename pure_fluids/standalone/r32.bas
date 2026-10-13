Attribute VB_Name = "R32"
' R32 纯物质饱和性质（单独计算文件，Excel VBA 工作表函数；与合并模块 pure_fluids.bas 系数逐字同源）
' 源：NIST WebBook 饱和表紧凑拟合（笔记见 ../fit-notes/R32饱和性质拟合-NIST表.md）；饱和压 lnP-t 7 次式，对表全程最大 0.0609%、常用带（-40~60°C）0.0147%；焓已由表基准平移 -100.673431938 至统一基准。
' 参考态：0°C 饱和液体焓 = 100 kJ/kg（模块统一基准）。Pref 返回 bar；Tsat 超界返回 #NUM!。
' 注意：本模块未在真实 Excel 中编译运行过，使用前请先编译验证。

Option Explicit

Private Const TLO As Double = -136.0
Private Const THI As Double = 78.0

Private Function LnPc(ByVal i As Long) As Double
    Select Case i
        Case 0: LnPc = 4.985734545925537E-16
        Case 1: LnPc = 8.088993550316065E-15
        Case 2: LnPc = 7.23916818285453E-12
        Case 3: LnPc = -2.4123562470111985E-09
        Case 4: LnPc = 5.690865248769261E-07
        Case 5: LnPc = -0.00012346886007261548
        Case 6: LnPc = 0.032029536226752524
        Case 7: LnPc = -0.20703267077542895
    End Select
End Function

Private Function HLc(ByVal i As Long) As Double
    Select Case i
        Case 0: HLc = 3.052117712232615E-11
        Case 1: HLc = 7.669342242883148E-09
        Case 2: HLc = 4.426168044128746E-07
        Case 3: HLc = -6.097377922612308E-06
        Case 4: HLc = 0.0010654645657896644
        Case 5: HLc = 1.7643249519580528
        Case 6: HLc = 100.0
    End Select
End Function

Private Function HVc(ByVal i As Long) As Double
    Select Case i
        Case 0: HVc = -4.488337246373621E-11
        Case 1: HVc = -1.1379788910261148E-08
        Case 2: HVc = -6.764615880681746E-07
        Case 3: HVc = 7.561508556936408E-06
        Case 4: HVc = -0.0024175577393345023
        Case 5: HVc = 0.1589860001017608
        Case 6: HVc = 413.6297944744754
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
    LnPPref = 10# * Exp(r)
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

Public Function Pref_R32(ByVal t_C As Double) As Double
    Pref_R32 = PrefRaw(t_C)
End Function

Public Function Tsat_R32(ByVal P_bar As Double) As Variant
    Tsat_R32 = TsatBisect(P_bar)
End Function

Public Function hliq_R32(ByVal t_C As Double) As Double
    hliq_R32 = Poly6(t_C, False)
End Function

Public Function hgas_R32(ByVal t_C As Double) As Double
    hgas_R32 = Poly6(t_C, True)
End Function

' R32 饱和潜热 kJ/kg = hgas - hliq（同一参考态）
Public Function hlat_R32(ByVal t_C As Double) As Double
    hlat_R32 = hgas_R32(t_C) - hliq_R32(t_C)
End Function

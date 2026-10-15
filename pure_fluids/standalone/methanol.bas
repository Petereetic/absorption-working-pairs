Attribute VB_Name = "Methanol"
' CH3OH 纯物质饱和性质（单独计算文件，Excel VBA 工作表函数；与合并模块 pure_fluids.bas 系数逐字同源）
' 源：NIST WebBook 饱和表紧凑拟合（笔记见 ../fit-notes/甲醇饱和性质拟合-NIST表.md；源表为网页取整输出，残差含取整噪声）；饱和压 lnP-t 7 次式，对表全程最大 0.1064%、常用带（-40~90°C）0.0321%；焓已由表基准平移 +266.341441575 至统一基准。
' 参考态：0°C 饱和液体焓 = 100 kJ/kg（模块统一基准）。Pref 返回 MPa；Tsat 入参 MPa 超界返回 #NUM!。
' 注意：本模块未在真实 Excel 中编译运行过，使用前请先编译验证。

Option Explicit

Private Const TLO As Double = -90.0
Private Const THI As Double = 239.0

Private Function LnPc(ByVal i As Long) As Double
    Select Case i
        Case 0: LnPc = 6.071697789417314E-17
        Case 1: LnPc = -4.474383382147671E-14
        Case 2: LnPc = 1.4922332158687438E-11
        Case 3: LnPc = -3.713389940921318E-09
        Case 4: LnPc = 9.643627950530163E-07
        Case 5: LnPc = -0.00025454685882528256
        Case 6: LnPc = 0.06310145783702696
        Case 7: LnPc = -5.507805919357708
    End Select
End Function

Private Function HLc(ByVal i As Long) As Double
    Select Case i
        Case 0: HLc = 5.573934158642428E-12
        Case 1: HLc = -1.8104866695124476E-09
        Case 2: HLc = 8.709794689054448E-08
        Case 3: HLc = 2.7396583808978296E-05
        Case 4: HLc = 0.001358520746256356
        Case 5: HLc = 2.362545782283046
        Case 6: HLc = 100.0
    End Select
End Function

Private Function HVc(ByVal i As Long) As Double
    Select Case i
        Case 0: HVc = -1.228628960059207E-11
        Case 1: HVc = 4.469399531774273E-09
        Case 2: HVc = -3.1756317512396483E-07
        Case 3: HVc = -4.548213600653677E-05
        Case 4: HVc = 0.002018557942790822
        Case 5: HVc = 1.156097552141014
        Case 6: HVc = 1301.565002270651
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

Public Function Pref_CH3OH(ByVal t_C As Double) As Double
    Pref_CH3OH = PrefRaw(t_C)
End Function

Public Function Tsat_CH3OH(ByVal P_MPa As Double) As Variant
    Tsat_CH3OH = TsatBisect(P_MPa)
End Function

Public Function hliq_CH3OH(ByVal t_C As Double) As Double
    hliq_CH3OH = Poly6(t_C, False)
End Function

Public Function hgas_CH3OH(ByVal t_C As Double) As Double
    hgas_CH3OH = Poly6(t_C, True)
End Function

' CH3OH 饱和潜热 kJ/kg = hgas - hliq（同一参考态）
Public Function hlat_CH3OH(ByVal t_C As Double) As Double
    hlat_CH3OH = hgas_CH3OH(t_C) - hliq_CH3OH(t_C)
End Function

Attribute VB_Name = "CO2"
' CO2 纯物质饱和性质（单独计算文件，Excel VBA 工作表函数；与合并模块 pure_fluids.bas 系数逐字同源）
' 源：NIST WebBook 饱和表紧凑拟合（笔记见 ../fit-notes/二氧化碳饱和性质拟合-NIST表.md；源表有取整）；饱和压 lnP-t 7 次式，对表全程最大 0.0099%、常用带（-50~25°C）0.0059%；焓已由表基准平移 -100.255791821 至统一基准。
' 参考态：0°C 饱和液体焓 = 100 kJ/kg（模块统一基准）。Pref 返回 MPa；Tsat 入参 MPa 超界返回 #NUM!。
' 注意：本模块未在真实 Excel 中编译运行过，使用前请先编译验证。

Option Explicit

Private Const TLO As Double = -56.0
Private Const THI As Double = 30.0

Private Function LnPc(ByVal i As Long) As Double
    Select Case i
        Case 0: LnPc = 7.349267422320306E-15
        Case 1: LnPc = 9.714937274844203E-13
        Case 2: LnPc = 5.722737962459257E-11
        Case 3: LnPc = -5.000472245728414E-10
        Case 4: LnPc = 5.236317080887681E-07
        Case 5: LnPc = -9.20196795346934E-05
        Case 6: LnPc = 0.02647312340946483
        Case 7: LnPc = 1.2485141855617028
    End Select
End Function

Private Function HLc(ByVal i As Long) As Double
    Select Case i
        Case 0: HLc = 2.948691221375449E-09
        Case 1: HLc = 3.3584601264848553E-07
        Case 2: HLc = 1.0969134467517922E-05
        Case 3: HLc = 9.865777775779578E-05
        Case 4: HLc = 0.006887751259917945
        Case 5: HLc = 2.4420397272329732
        Case 6: HLc = 100.0
    End Select
End Function

Private Function HVc(ByVal i As Long) As Double
    Select Case i
        Case 0: HVc = -4.280078787604416E-09
        Case 1: HVc = -4.893910288449988E-07
        Case 2: HVc = -1.62198769938507E-05
        Case 3: HVc = -0.00015811780903671123
        Case 4: HVc = -0.012470655351837747
        Case 5: HVc = -0.5840479229797425
        Case 6: HVc = 330.2675971498235
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

Public Function Pref_CO2(ByVal t_C As Double) As Double
    Pref_CO2 = PrefRaw(t_C)
End Function

Public Function Tsat_CO2(ByVal P_MPa As Double) As Variant
    Tsat_CO2 = TsatBisect(P_MPa)
End Function

Public Function hliq_CO2(ByVal t_C As Double) As Double
    hliq_CO2 = Poly6(t_C, False)
End Function

Public Function hgas_CO2(ByVal t_C As Double) As Double
    hgas_CO2 = Poly6(t_C, True)
End Function

' CO2 饱和潜热 kJ/kg = hgas - hliq（同一参考态）
Public Function hlat_CO2(ByVal t_C As Double) As Double
    hlat_CO2 = hgas_CO2(t_C) - hliq_CO2(t_C)
End Function

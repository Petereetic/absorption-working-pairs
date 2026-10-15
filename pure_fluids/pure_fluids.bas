Attribute VB_Name = "PureFluids"
' 九工质纯物质饱和性质（Excel VBA 工作表函数）：R134a / R22 / R124 / H2O / NH3 / CH3OH / R32 / R218 / CO2
' 基准：CoolProp 内置参考状态方程（R134a: Tillner-Roth & Baehr 1994）
' 参考态：0°C 饱和液体焓 = 100 kJ/kg（与用户现有模型统一）
' 压力公开单位 MPa（2026-10-14 改）：Wagner 拟合内部以 bar 计（Pc 为 bar），公开函数边界换算；lnP 六工质原生 MPa。
'
' 工作表函数：
'   =Pref_R134a(t_C)  饱和压力 MPa，t_C: °C（-50~95）
'   =Tsat_R134a(P_MPa) 饱和温度 °C，P_MPa: MPa
'   =hliq_R134a(t_C)    饱和液体焓 kJ/kg
'   =hgas_R134a(t_C)    饱和蒸气焓 kJ/kg
'   =Pref_R22(t_C)    饱和压力 MPa（-50~90）
'   =Tsat_R22(P_MPa)  饱和温度 °C
'   =hliq_R22(t_C)      饱和液体焓 kJ/kg
'   =hgas_R22(t_C)      饱和蒸气焓 kJ/kg
'   =Pref_R124(t_C)   R124 饱和压力 MPa（-40~110；NIST 表 Wagner 拟合）
'   =Tsat_R124(P_MPa) R124 饱和温度 °C
'   =hliq_R124(t_C)     R124 饱和液体焓 kJ/kg（基准同上，已平移）
'   =hgas_R124(t_C)     R124 饱和蒸气焓 kJ/kg
' （R124 函数名用"属性在前"式：Excel 工作表不接受 R+数字打头的函数名）
' 2026-10-13 增补六工质（NIST WebBook 饱和表拟合，笔记见 fit-notes/）：
'   =Pref_H2O(t_C) / =Tsat_H2O(P_MPa) / =hliq_H2O / =hgas_H2O / =hlat_H2O（1~373°C）
'   =Pref_NH3 / =Tsat_NH3 / =hliq_NH3 / =hgas_NH3 / =hlat_NH3（-77~132°C）
'   =Pref_CH3OH / =Tsat_CH3OH / =hliq_CH3OH / =hgas_CH3OH / =hlat_CH3OH（-90~239°C）
'   =Pref_R32 / =Tsat_R32 / =hliq_R32 / =hgas_R32 / =hlat_R32（-136~78°C）
'   =Pref_R218 / =Tsat_R218 / =hliq_R218 / =hgas_R218 / =hlat_R218（-147~71°C）
'   =Pref_CO2 / =Tsat_CO2 / =hliq_CO2 / =hgas_CO2 / =hlat_CO2（-56~30°C）
'   六工质焓已平移到统一基准，平移量见各工质段注；饱和压以 MPa 返回。
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
    Pref_R134a = 0.1 * WagnerPref(t_C, R134A_TC, R134A_PC, 1)
End Function

Public Function Tsat_R134a(ByVal P_MPa As Double) As Variant
    Tsat_R134a = TsatBisect(10# * P_MPa, 1)
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
    Pref_R22 = 0.1 * WagnerPref(t_C, R22_TC, R22_PC, 2)
End Function

Public Function Tsat_R22(ByVal P_MPa As Double) As Variant
    Tsat_R22 = TsatBisect(10# * P_MPa, 2)
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
    Pref_R124 = 0.1 * WagnerPref36_R124(t_C)
End Function

Public Function Tsat_R124(ByVal P_MPa As Double) As Variant
    Tsat_R124 = TsatBisect_R124(10# * P_MPa)
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

' =============== NIST WebBook 表拟合六工质（2026-10-13 增补）===============
' 饱和压：lnP-t 7 次多项式（笔记取定式，ln(P/MPa)；此处直接以 MPa 返回）；
' 焓：6 次多项式，常数项已平移到统一基准（0°C 饱和液体 = 100 kJ/kg），
' 平移量见各工质段注（仅常数项变动，潜热不变）。
' fluid 编号：3=H2O，4=NH3，5=CH3OH，6=R32，7=R218，8=CO2。

' ---------- H2O 常数（平移 +93.351889719 kJ/kg） ----------
Private Const H2O_TLO As Double = 1.0
Private Const H2O_THI As Double = 373.0

Private Function H2OLnPc(ByVal i As Long) As Double
    Select Case i
        Case 0: H2OLnPc = 5.54627791673895E-18
        Case 1: H2OLnPc = -8.99249875691861E-15
        Case 2: H2OLnPc = 6.660700555390007E-12
        Case 3: H2OLnPc = -3.088083641876246E-09
        Case 4: H2OLnPc = 1.056735995405781E-06
        Case 5: H2OLnPc = -0.0002954387998568004
        Case 6: H2OLnPc = 0.07259423527358563
        Case 7: H2OLnPc = -7.399704960820133
    End Select
End Function

Private Function H2OHLc(ByVal i As Long) As Double
    Select Case i
        Case 0: H2OHLc = 4.9253814056437E-12
        Case 1: H2OHLc = -4.8364685293173926E-09
        Case 2: H2OHLc = 1.8115766448129802E-06
        Case 3: H2OHLc = -0.0003141174119157094
        Case 4: H2OHLc = 0.02553352332697852
        Case 5: H2OHLc = 3.3541747407753046
        Case 6: H2OHLc = 100.0
    End Select
End Function

Private Function H2OHVc(ByVal i As Long) As Double
    Select Case i
        Case 0: H2OHVc = -8.083632440447619E-12
        Case 1: H2OHVc = 7.910908004577575E-09
        Case 2: H2OHVc = -2.951073494811462E-06
        Case 3: H2OHVc = 0.0005046392594921277
        Case 4: H2OHVc = -0.04153882947643235
        Case 5: H2OHVc = 3.1701433360694287
        Case 6: H2OHVc = 2583.8464687067276
    End Select
End Function

' ---------- NH3 常数（平移 -244.76806269 kJ/kg） ----------
Private Const NH3_TLO As Double = -77.0
Private Const NH3_THI As Double = 132.0

Private Function NH3LnPc(ByVal i As Long) As Double
    Select Case i
        Case 0: NH3LnPc = 1.1501679663496297E-16
        Case 1: NH3LnPc = -3.681466540446358E-14
        Case 2: NH3LnPc = 9.070213653911228E-12
        Case 3: NH3LnPc = -2.4759314474490567E-09
        Case 4: NH3LnPc = 6.551063627525382E-07
        Case 5: NH3LnPc = -0.00015333383280607642
        Case 6: NH3LnPc = 0.03739502393748032
        Case 7: NH3LnPc = -0.8457026848887617
    End Select
End Function

Private Function NH3HLc(ByVal i As Long) As Double
    Select Case i
        Case 0: NH3HLc = 1.0230389195910096E-10
        Case 1: NH3HLc = -9.01173619674778E-09
        Case 2: NH3HLc = -7.693180171285098E-07
        Case 3: NH3HLc = 8.148925711345767E-05
        Case 4: NH3HLc = 0.0049020842504556555
        Case 5: NH3HLc = 4.529640315972919
        Case 6: NH3HLc = 100.0
    End Select
End Function

Private Function NH3HVc(ByVal i As Long) As Double
    Select Case i
        Case 0: NH3HVc = -1.5323246964436346E-10
        Case 1: NH3HVc = 1.341154075047321E-08
        Case 2: NH3HVc = 1.181178610537754E-06
        Case 3: NH3HVc = -0.000132743256804236
        Case 4: NH3HVc = -0.01090080493286388
        Case 5: NH3HVc = 1.2129121114680004
        Case 6: NH3HVc = 1364.0392422964662
    End Select
End Function

' ---------- CH3OH 常数（平移 +266.34144157 kJ/kg） ----------
Private Const CH3OH_TLO As Double = -90.0
Private Const CH3OH_THI As Double = 239.0

Private Function CH3OHLnPc(ByVal i As Long) As Double
    Select Case i
        Case 0: CH3OHLnPc = 6.071697789417314E-17
        Case 1: CH3OHLnPc = -4.474383382147671E-14
        Case 2: CH3OHLnPc = 1.4922332158687438E-11
        Case 3: CH3OHLnPc = -3.713389940921318E-09
        Case 4: CH3OHLnPc = 9.643627950530163E-07
        Case 5: CH3OHLnPc = -0.00025454685882528256
        Case 6: CH3OHLnPc = 0.06310145783702696
        Case 7: CH3OHLnPc = -5.507805919357708
    End Select
End Function

Private Function CH3OHHLc(ByVal i As Long) As Double
    Select Case i
        Case 0: CH3OHHLc = 5.573934158642428E-12
        Case 1: CH3OHHLc = -1.8104866695124476E-09
        Case 2: CH3OHHLc = 8.709794689054448E-08
        Case 3: CH3OHHLc = 2.7396583808978296E-05
        Case 4: CH3OHHLc = 0.001358520746256356
        Case 5: CH3OHHLc = 2.362545782283046
        Case 6: CH3OHHLc = 100.0
    End Select
End Function

Private Function CH3OHHVc(ByVal i As Long) As Double
    Select Case i
        Case 0: CH3OHHVc = -1.228628960059207E-11
        Case 1: CH3OHHVc = 4.469399531774273E-09
        Case 2: CH3OHHVc = -3.1756317512396483E-07
        Case 3: CH3OHHVc = -4.548213600653677E-05
        Case 4: CH3OHHVc = 0.002018557942790822
        Case 5: CH3OHHVc = 1.156097552141014
        Case 6: CH3OHHVc = 1301.565002270651
    End Select
End Function

' ---------- R32 常数（平移 -100.67343194 kJ/kg） ----------
Private Const R32_TLO As Double = -136.0
Private Const R32_THI As Double = 78.0

Private Function R32LnPc(ByVal i As Long) As Double
    Select Case i
        Case 0: R32LnPc = 4.985734545925537E-16
        Case 1: R32LnPc = 8.088993550316065E-15
        Case 2: R32LnPc = 7.23916818285453E-12
        Case 3: R32LnPc = -2.4123562470111985E-09
        Case 4: R32LnPc = 5.690865248769261E-07
        Case 5: R32LnPc = -0.00012346886007261548
        Case 6: R32LnPc = 0.032029536226752524
        Case 7: R32LnPc = -0.20703267077542895
    End Select
End Function

Private Function R32HLc(ByVal i As Long) As Double
    Select Case i
        Case 0: R32HLc = 3.052117712232615E-11
        Case 1: R32HLc = 7.669342242883148E-09
        Case 2: R32HLc = 4.426168044128746E-07
        Case 3: R32HLc = -6.097377922612308E-06
        Case 4: R32HLc = 0.0010654645657896644
        Case 5: R32HLc = 1.7643249519580528
        Case 6: R32HLc = 100.0
    End Select
End Function

Private Function R32HVc(ByVal i As Long) As Double
    Select Case i
        Case 0: R32HVc = -4.488337246373621E-11
        Case 1: R32HVc = -1.1379788910261148E-08
        Case 2: R32HVc = -6.764615880681746E-07
        Case 3: R32HVc = 7.561508556936408E-06
        Case 4: R32HVc = -0.0024175577393345023
        Case 5: R32HVc = 0.1589860001017608
        Case 6: R32HVc = 413.6297944744754
    End Select
End Function

' ---------- R218 常数（平移 -100.17798078 kJ/kg） ----------
Private Const R218_TLO As Double = -147.0
Private Const R218_THI As Double = 71.0

Private Function R218LnPc(ByVal i As Long) As Double
    Select Case i
        Case 0: R218LnPc = 8.255415504414131E-16
        Case 1: R218LnPc = 7.344897883851216E-14
        Case 2: R218LnPc = 1.093452574911193E-11
        Case 3: R218LnPc = -2.800385114611927E-09
        Case 4: R218LnPc = 6.13844960232108E-07
        Case 5: R218LnPc = -0.00013063706572324828
        Case 6: R218LnPc = 0.03248293004447796
        Case 7: R218LnPc = -0.8809937809605295
    End Select
End Function

Private Function R218HLc(ByVal i As Long) As Double
    Select Case i
        Case 0: R218HLc = 7.040720312389206E-12
        Case 1: R218HLc = 2.1911253182755153E-09
        Case 2: R218HLc = 1.9931060577128075E-07
        Case 3: R218HLc = 4.329266994236428E-06
        Case 4: R218HLc = 0.0010980864706317968
        Case 5: R218HLc = 1.070171579409284
        Case 6: R218HLc = 100.0
    End Select
End Function

Private Function R218HVc(ByVal i As Long) As Double
    Select Case i
        Case 0: R218HVc = -1.0731550245287959E-11
        Case 1: R218HVc = -3.374732945181214E-09
        Case 2: R218HVc = -3.125522092678402E-07
        Case 3: R218HVc = -8.835005867404636E-06
        Case 4: R218HVc = -2.3183839296438865E-05
        Case 5: R218HVc = 0.596775089781136
        Case 6: R218HVc = 189.38572453841817
    End Select
End Function

' ---------- CO2 常数（平移 -100.25579182 kJ/kg） ----------
Private Const CO2_TLO As Double = -56.0
Private Const CO2_THI As Double = 30.0

Private Function CO2LnPc(ByVal i As Long) As Double
    Select Case i
        Case 0: CO2LnPc = 7.349267422320306E-15
        Case 1: CO2LnPc = 9.714937274844203E-13
        Case 2: CO2LnPc = 5.722737962459257E-11
        Case 3: CO2LnPc = -5.000472245728414E-10
        Case 4: CO2LnPc = 5.236317080887681E-07
        Case 5: CO2LnPc = -9.20196795346934E-05
        Case 6: CO2LnPc = 0.02647312340946483
        Case 7: CO2LnPc = 1.2485141855617028
    End Select
End Function

Private Function CO2HLc(ByVal i As Long) As Double
    Select Case i
        Case 0: CO2HLc = 2.948691221375449E-09
        Case 1: CO2HLc = 3.3584601264848553E-07
        Case 2: CO2HLc = 1.0969134467517922E-05
        Case 3: CO2HLc = 9.865777775779578E-05
        Case 4: CO2HLc = 0.006887751259917945
        Case 5: CO2HLc = 2.4420397272329732
        Case 6: CO2HLc = 100.0
    End Select
End Function

Private Function CO2HVc(ByVal i As Long) As Double
    Select Case i
        Case 0: CO2HVc = -4.280078787604416E-09
        Case 1: CO2HVc = -4.893910288449988E-07
        Case 2: CO2HVc = -1.62198769938507E-05
        Case 3: CO2HVc = -0.00015811780903671123
        Case 4: CO2HVc = -0.012470655351837747
        Case 5: CO2HVc = -0.5840479229797425
        Case 6: CO2HVc = 330.2675971498235
    End Select
End Function

' ---------- 内部：六工质分发 ----------
Private Function LnpCoef(ByVal fluid As Long, ByVal i As Long) As Double
    Select Case fluid
        Case 3: LnpCoef = H2OLnPc(i)
        Case 4: LnpCoef = NH3LnPc(i)
        Case 5: LnpCoef = CH3OHLnPc(i)
        Case 6: LnpCoef = R32LnPc(i)
        Case 7: LnpCoef = R218LnPc(i)
        Case 8: LnpCoef = CO2LnPc(i)
    End Select
End Function

Private Function HCoefL(ByVal fluid As Long, ByVal i As Long) As Double
    Select Case fluid
        Case 3: HCoefL = H2OHLc(i)
        Case 4: HCoefL = NH3HLc(i)
        Case 5: HCoefL = CH3OHHLc(i)
        Case 6: HCoefL = R32HLc(i)
        Case 7: HCoefL = R218HLc(i)
        Case 8: HCoefL = CO2HLc(i)
    End Select
End Function

Private Function HCoefV(ByVal fluid As Long, ByVal i As Long) As Double
    Select Case fluid
        Case 3: HCoefV = H2OHVc(i)
        Case 4: HCoefV = NH3HVc(i)
        Case 5: HCoefV = CH3OHHVc(i)
        Case 6: HCoefV = R32HVc(i)
        Case 7: HCoefV = R218HVc(i)
        Case 8: HCoefV = CO2HVc(i)
    End Select
End Function

Private Function FluidTlo(ByVal fluid As Long) As Double
    Select Case fluid
        Case 3: FluidTlo = H2O_TLO
        Case 4: FluidTlo = NH3_TLO
        Case 5: FluidTlo = CH3OH_TLO
        Case 6: FluidTlo = R32_TLO
        Case 7: FluidTlo = R218_TLO
        Case 8: FluidTlo = CO2_TLO
    End Select
End Function

Private Function FluidThi(ByVal fluid As Long) As Double
    Select Case fluid
        Case 3: FluidThi = H2O_THI
        Case 4: FluidThi = NH3_THI
        Case 5: FluidThi = CH3OH_THI
        Case 6: FluidThi = R32_THI
        Case 7: FluidThi = R218_THI
        Case 8: FluidThi = CO2_THI
    End Select
End Function

Private Function LnpPref(ByVal t_C As Double, ByVal fluid As Long) As Double
    Dim c(0 To 7) As Double, i As Long, r As Double
    For i = 0 To 7
        c(i) = LnpCoef(fluid, i)
    Next i
    r = c(0)
    For i = 1 To 7
        r = r * t_C + c(i)
    Next i
    LnpPref = Exp(r)
End Function

Private Function Poly6F(ByVal t As Double, ByVal fluid As Long, ByVal isVap As Boolean) As Double
    Dim c(0 To 6) As Double, i As Long, r As Double
    For i = 0 To 6
        If isVap Then c(i) = HCoefV(fluid, i) Else c(i) = HCoefL(fluid, i)
    Next i
    r = c(0)
    For i = 1 To 6
        r = r * t + c(i)
    Next i
    Poly6F = r
End Function

Private Function TsatBisectF(ByVal P_MPa As Double, ByVal fluid As Long) As Double
    Dim lo As Double, hi As Double, mid As Double, i As Long
    Dim tlo As Double, thi As Double
    tlo = FluidTlo(fluid): thi = FluidThi(fluid)
    If P_MPa < LnpPref(tlo, fluid) Or P_MPa > LnpPref(thi, fluid) Then
        TsatBisectF = CVErr(xlErrNum)
        Exit Function
    End If
    lo = tlo: hi = thi
    For i = 1 To 60
        mid = 0.5 * (lo + hi)
        If LnpPref(mid, fluid) < P_MPa Then lo = mid Else hi = mid
    Next i
    TsatBisectF = 0.5 * (lo + hi)
End Function

' ================= H2O 工作表函数 =================
Public Function Pref_H2O(ByVal t_C As Double) As Double
    Pref_H2O = LnpPref(t_C, 3)
End Function

Public Function Tsat_H2O(ByVal P_MPa As Double) As Variant
    Tsat_H2O = TsatBisectF(P_MPa, 3)
End Function

Public Function hliq_H2O(ByVal t_C As Double) As Double
    hliq_H2O = Poly6F(t_C, 3, False)
End Function

Public Function hgas_H2O(ByVal t_C As Double) As Double
    hgas_H2O = Poly6F(t_C, 3, True)
End Function

' H2O 饱和潜热 kJ/kg = hgas - hliq（同一参考态）
Public Function hlat_H2O(ByVal t_C As Double) As Double
    hlat_H2O = hgas_H2O(t_C) - hliq_H2O(t_C)
End Function

' ================= NH3 工作表函数 =================
Public Function Pref_NH3(ByVal t_C As Double) As Double
    Pref_NH3 = LnpPref(t_C, 4)
End Function

Public Function Tsat_NH3(ByVal P_MPa As Double) As Variant
    Tsat_NH3 = TsatBisectF(P_MPa, 4)
End Function

Public Function hliq_NH3(ByVal t_C As Double) As Double
    hliq_NH3 = Poly6F(t_C, 4, False)
End Function

Public Function hgas_NH3(ByVal t_C As Double) As Double
    hgas_NH3 = Poly6F(t_C, 4, True)
End Function

' NH3 饱和潜热 kJ/kg = hgas - hliq（同一参考态）
Public Function hlat_NH3(ByVal t_C As Double) As Double
    hlat_NH3 = hgas_NH3(t_C) - hliq_NH3(t_C)
End Function

' ================= CH3OH 工作表函数 =================
Public Function Pref_CH3OH(ByVal t_C As Double) As Double
    Pref_CH3OH = LnpPref(t_C, 5)
End Function

Public Function Tsat_CH3OH(ByVal P_MPa As Double) As Variant
    Tsat_CH3OH = TsatBisectF(P_MPa, 5)
End Function

Public Function hliq_CH3OH(ByVal t_C As Double) As Double
    hliq_CH3OH = Poly6F(t_C, 5, False)
End Function

Public Function hgas_CH3OH(ByVal t_C As Double) As Double
    hgas_CH3OH = Poly6F(t_C, 5, True)
End Function

' CH3OH 饱和潜热 kJ/kg = hgas - hliq（同一参考态）
Public Function hlat_CH3OH(ByVal t_C As Double) As Double
    hlat_CH3OH = hgas_CH3OH(t_C) - hliq_CH3OH(t_C)
End Function

' ================= R32 工作表函数 =================
Public Function Pref_R32(ByVal t_C As Double) As Double
    Pref_R32 = LnpPref(t_C, 6)
End Function

Public Function Tsat_R32(ByVal P_MPa As Double) As Variant
    Tsat_R32 = TsatBisectF(P_MPa, 6)
End Function

Public Function hliq_R32(ByVal t_C As Double) As Double
    hliq_R32 = Poly6F(t_C, 6, False)
End Function

Public Function hgas_R32(ByVal t_C As Double) As Double
    hgas_R32 = Poly6F(t_C, 6, True)
End Function

' R32 饱和潜热 kJ/kg = hgas - hliq（同一参考态）
Public Function hlat_R32(ByVal t_C As Double) As Double
    hlat_R32 = hgas_R32(t_C) - hliq_R32(t_C)
End Function

' ================= R218 工作表函数 =================
Public Function Pref_R218(ByVal t_C As Double) As Double
    Pref_R218 = LnpPref(t_C, 7)
End Function

Public Function Tsat_R218(ByVal P_MPa As Double) As Variant
    Tsat_R218 = TsatBisectF(P_MPa, 7)
End Function

Public Function hliq_R218(ByVal t_C As Double) As Double
    hliq_R218 = Poly6F(t_C, 7, False)
End Function

Public Function hgas_R218(ByVal t_C As Double) As Double
    hgas_R218 = Poly6F(t_C, 7, True)
End Function

' R218 饱和潜热 kJ/kg = hgas - hliq（同一参考态）
Public Function hlat_R218(ByVal t_C As Double) As Double
    hlat_R218 = hgas_R218(t_C) - hliq_R218(t_C)
End Function

' ================= CO2 工作表函数 =================
Public Function Pref_CO2(ByVal t_C As Double) As Double
    Pref_CO2 = LnpPref(t_C, 8)
End Function

Public Function Tsat_CO2(ByVal P_MPa As Double) As Variant
    Tsat_CO2 = TsatBisectF(P_MPa, 8)
End Function

Public Function hliq_CO2(ByVal t_C As Double) As Double
    hliq_CO2 = Poly6F(t_C, 8, False)
End Function

Public Function hgas_CO2(ByVal t_C As Double) As Double
    hgas_CO2 = Poly6F(t_C, 8, True)
End Function

' CO2 饱和潜热 kJ/kg = hgas - hliq（同一参考态）
Public Function hlat_CO2(ByVal t_C As Double) As Double
    hlat_CO2 = hgas_CO2(t_C) - hliq_CO2(t_C)
End Function

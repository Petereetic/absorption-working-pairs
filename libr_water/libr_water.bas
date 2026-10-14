Attribute VB_Name = "LiBrWater"
' ==========================================================================
' 溴化锂水溶液物性 VBA 工作表函数 (Patterson + Chua 混合)
' ==========================================================================
' Patterson, M.R. & Perez-Blanco, H. (1988)
' "Numerical fits of the properties of lithium-bromide water solutions",
' ASHRAE Transactions 94(2), pp. 2059-2077.
' Chua, H.T. et al. (2000), Int. J. Refrigeration 23, 412-429
' (Dühring 蒸气压 + 密度)。
'
' *** 本 .bas 未在真实 Excel 中编译或运行,系由 Python 参考实现 ***
' *** 逐行移植,使用前请在 Excel 中实测。                        ***
'
' 工作表函数 (X = LiBr 重量百分数数字,如 50; T = °C):
'   LW_hsol(X,T)        溶液比焓 [kJ/kg]
'   LW_Tdew(X,T)     露点温度 [°C]
'   LW_Psol(X,T)     水蒸气分压 [MPa] (Patterson)
'   LW_Lambda(X,T)   导热系数 [W/(m K)]
'   LW_Eta(X,T)      动力黏度 [Pa s]
'   LW_Rho(X,T)      密度 [kg/m^3]
'   LW_Sigma(X,T)    表面张力 [N/m]
'   LW_Tcryst(X)     结晶温度 [°C]
'   LW_PsolChua(X,T) 水蒸气分压 [MPa] (Chua Dühring, 0-190°C/0-60wt%;
'                      x>60 的 <x-60> 项按原文印刷值无法复现, 不实现)
'   LW_RhoChua(X,T)  密度 [kg/m^3] (Chua, 0-200°C/0-70%)
'   LW_XByTsolTdewChua(Tdew,Tsol)  由露点温度与溶液温度反解浓度 X [wt%]
'                      (Chua 路线, Wagner 纯水定压; 无根返回 Empty)
'
' 范围外或结晶区内返回 #VALUE! 错误值。
' 压力单位 (2026-10-14 规矩): 公开函数返回 MPa; 拟合原生值与内部
' 算术仍为 Pa —— 私有 PsolPa / PsolChuaPa 返回 Pa 原生值, 公开
' LW_Psol / LW_PsolChua = 原生值 ×0.000001, 内部反解一律走私有函数。
' ==========================================================================
Option Explicit

' ---------- 统一多项式 ----------
Private Function PolyLW(ByVal X As Double, ByVal T As Double, _
                        ByRef A As Variant, ByVal kup As Integer) As Double
    Dim s As Double, xk As Double, i As Integer
    s = 0#: xk = 1#
    For i = 0 To kup - 1
        If i > 0 Then xk = xk * X
        s = s + xk * (A(i) + T * (A(i + kup) + T * A(i + 2 * kup)))
    Next i
    PolyLW = s
End Function

' ---------- 结晶/未知区检查, 返回 ""=通过,否则错误信息 ----------
Private Function CheckRegion(ByVal X As Double, ByVal T As Double, _
        ByVal checkUnknown As Boolean, ByRef tunkn As Variant) As String
    Dim XN As Variant, TN As Variant, XUNKN As Variant
    Dim n As Integer, xstar As Double, found As Boolean
    XN = Array(57.5, 62.5, 62.5, 67.5, 67.5, 100#, 100#)
    TN = Array(0#, 10#, 40#, 50#, 90#, 100#, 180#)
    XUNKN = Array(0#, 37.5, 51.5, 60.5)
    found = False
    For n = 1 To 6
        If T > TN(n) Then GoTo NextN1
        If XN(n) = XN(n - 1) Then
            xstar = XN(n)
        Else
            xstar = XN(n - 1) + (T - TN(n - 1)) / (TN(n) - TN(n - 1)) _
                    * (XN(n) - XN(n - 1))
        End If
        found = True
        If X >= xstar Then
            CheckRegion = "结晶区": Exit Function
        End If
        Exit For
NextN1:
    Next n
    If found And Not checkUnknown Then CheckRegion = "": Exit Function
    For n = 1 To 3
        If T > tunkn(n) Then GoTo NextN2
        If XUNKN(n) = XUNKN(n - 1) Then
            xstar = XUNKN(n)
        Else
            xstar = XUNKN(n - 1) + (T - tunkn(n - 1)) _
                    / (tunkn(n) - tunkn(n - 1)) * (XUNKN(n) - XUNKN(n - 1))
        End If
        If X <= xstar Then CheckRegion = "未知区(无数据)": Exit Function
        CheckRegion = "": Exit Function
NextN2:
    Next n
    CheckRegion = "未知区(无数据)"
End Function

Private Function InRange(ByVal X As Double, ByVal T As Double, _
        ByVal xLo As Double, ByVal xHi As Double, _
        ByVal tLo As Double, ByVal tHi As Double) As Boolean
    InRange = (X >= xLo And X <= xHi And T >= tLo And T <= tHi)
End Function

' ---------- 系数表 ----------
Private Function CoefH() As Variant
    CoefH = Array(1.134125, -0.480045, -0.002161438, 0.0002336235, _
        -0.00001188679, 2.291532E-07, 4.124891, -0.07643903, _
        0.002589577, -0.00009500522, 0.000001708026, -1.102363E-08, _
        0.0005743693, 0.00005870921, -0.000007375319, 3.277592E-07, _
        -6.062304E-09, 3.901897E-11)
End Function

Private Function CoefTdew() As Variant
    CoefTdew = Array(-0.1313448, 0.1820914, -0.05177356, 0.002827426, _
        -0.00006380541, 4.340498E-07, 0.9967944, 0.001778069, _
        -0.0002215597, 0.000005913618, -7.308556E-08, 2.788472E-10, _
        0.00001978788, -0.00001779481, 0.000002002427, -7.667546E-08, _
        1.201525E-09, -6.641716E-12)
End Function

Private Function CoefTc() As Variant
    CoefTc = Array(0.4815196, -0.002217277, -0.00001994141, 3.727255E-07, _
        -2.489886E-09, 0.001858174, 0.000009614755, -0.000001139291, _
        2.107608E-08, -1.330532E-10, -0.000007923126, -1.869392E-07, _
        1.408951E-08, -2.740806E-10, 1.810818E-12)
End Function

Private Function CoefVis() As Variant
    CoefVis = Array(1.488747, 0.1143975, -0.01278729, 0.0006999985, _
        -0.00001638074, 1.456348E-07, -0.04164814, 0.0009636832, _
        -0.00005981025, -1.282435E-07, 5.703002E-08, -9.842266E-10, _
        0.000340403, -0.00002794515, 0.000002580301, -9.73775E-08, _
        1.585609E-09, -7.922925E-12)
End Function

Private Function CoefRho() As Variant
    CoefRho = Array(0.9939006, 0.01046888, -0.0001667939, 0.000005332835, _
        -3.44E-08, -0.0005631094, 0.00001633541, -0.000001110273, _
        2.882292E-08, -2.523579E-10, 0.000001392527, -2.801009E-07, _
        1.734979E-08, -4.232988E-10, 3.503024E-12)
End Function

Private Function CoefSig() As Variant
    CoefSig = Array(76.26234, 0.45839, -0.01463071, 0.0003834735, _
        -0.000002733854, -0.1507474, -0.009057263, 0.0004459087, _
        -0.000009542318, 6.610416E-08, -0.00001107075, 0.00007238986, _
        -0.000003822731, 8.077592E-08, -5.681625E-10)
End Function

Private Function TunknStd() As Variant
    TunknStd = Array(126.7, 137.8, 160#, 182.2)
End Function

Private Function TunknTcon() As Variant
    TunknTcon = Array(260#, 280#, 320#, 360#)
End Function

' ---------- 公开函数 ----------
Public Function LW_hsol(ByVal X As Double, ByVal T As Double) As Variant
    If Not InRange(X, T, 0, 70, 0, 180) Then LW_hsol = CVErr(xlErrValue): Exit Function
    If CheckRegion(X, T, True, TunknStd()) <> "" Then LW_hsol = CVErr(xlErrValue): Exit Function
    LW_hsol = PolyLW(X, T, CoefH(), 6)
End Function

Private Function TdewPolyF(ByVal X As Double, ByVal T As Double) As Double
    Dim TF As Double
    TF = 9# / 5# * T + 32#
    TdewPolyF = PolyLW(X, TF, CoefTdew(), 6)
End Function

Public Function LW_Tdew(ByVal X As Double, ByVal T As Double) As Variant
    If Not InRange(X, T, 0, 70, 4.4, 182.2) Then LW_Tdew = CVErr(xlErrValue): Exit Function
    If CheckRegion(X, T, False, TunknStd()) <> "" Then LW_Tdew = CVErr(xlErrValue): Exit Function
    LW_Tdew = 5# / 9# * (TdewPolyF(X, T) - 32#)
End Function

' 水蒸气分压原生值 [Pa] (Patterson PRESS, 私有); 内部算术走此值
Private Function PsolPa(ByVal X As Double, ByVal T As Double) As Variant
    Dim tdewF As Double, TR As Double
    If Not InRange(X, T, 0, 70, 4.4, 182.2) Then PsolPa = CVErr(xlErrValue): Exit Function
    If CheckRegion(X, T, False, TunknStd()) <> "" Then PsolPa = CVErr(xlErrValue): Exit Function
    tdewF = TdewPolyF(X, T)
    TR = tdewF + 459.7
    PsolPa = 10# ^ (6.21147 - 2886.373 / TR - 337269.46 / TR ^ 2) * 6894.757
End Function

' 水蒸气分压 [MPa] (Patterson PRESS): 公开边界 = PsolPa ×0.000001
Public Function LW_Psol(ByVal X As Double, ByVal T As Double) As Variant
    Dim v As Variant
    v = PsolPa(X, T)
    If IsError(v) Then LW_Psol = CVErr(xlErrValue): Exit Function
    LW_Psol = v * 0.000001
End Function

Public Function LW_Lambda(ByVal X As Double, ByVal T As Double) As Variant
    If Not InRange(X, T, 0, 70, 4.4, 182.2) Then LW_Lambda = CVErr(xlErrValue): Exit Function
    If CheckRegion(X, T, False, TunknTcon()) <> "" Then LW_Lambda = CVErr(xlErrValue): Exit Function
    LW_Lambda = PolyLW(X, T, CoefTc(), 5) * 1.163
End Function

Public Function LW_Eta(ByVal X As Double, ByVal T As Double) As Variant
    If Not InRange(X, T, 5, 60, 0, 90) Then LW_Eta = CVErr(xlErrValue): Exit Function
    If CheckRegion(X, T, False, TunknStd()) <> "" Then LW_Eta = CVErr(xlErrValue): Exit Function
    LW_Eta = PolyLW(X, T, CoefVis(), 6) * 0.001
End Function

Public Function LW_Rho(ByVal X As Double, ByVal T As Double) As Variant
    If Not InRange(X, T, 10, 60, 0, 100) Then LW_Rho = CVErr(xlErrValue): Exit Function
    If CheckRegion(X, T, False, TunknStd()) <> "" Then LW_Rho = CVErr(xlErrValue): Exit Function
    LW_Rho = PolyLW(X, T, CoefRho(), 5) * 1000#
End Function

Public Function LW_Sigma(ByVal X As Double, ByVal T As Double) As Variant
    If Not InRange(X, T, 5, 60, 0, 60) Then LW_Sigma = CVErr(xlErrValue): Exit Function
    If CheckRegion(X, T, False, TunknStd()) <> "" Then LW_Sigma = CVErr(xlErrValue): Exit Function
    LW_Sigma = PolyLW(X, T, CoefSig(), 5) * 0.001
End Function

Public Function LW_Tcryst(ByVal X As Double) As Variant
    Dim XN As Variant, TN As Variant
    Dim n As Integer, x0 As Double, x1 As Double
    Dim t0 As Double, t1 As Double, t As Double
    Dim best As Double, hasBest As Boolean
    XN = Array(57.5, 62.5, 62.5, 67.5, 67.5, 100#, 100#)
    TN = Array(0#, 10#, 40#, 50#, 90#, 100#, 180#)
    If X < 57.5 Or X > 100 Then LW_Tcryst = CVErr(xlErrValue): Exit Function
    hasBest = False
    For n = 1 To 6
        x0 = XN(n - 1): x1 = XN(n): t0 = TN(n - 1): t1 = TN(n)
        If x0 = x1 Then
            If X = x0 Then
                If Not hasBest Or t1 > best Then best = t1: hasBest = True
            End If
        ElseIf X >= WorksheetFunction.Min(x0, x1) _
           And X <= WorksheetFunction.Max(x0, x1) Then
            t = t0 + (X - x0) / (x1 - x0) * (t1 - t0)
            If Not hasBest Or t > best Then best = t: hasBest = True
        End If
    Next n
    If hasBest Then LW_Tcryst = best Else LW_Tcryst = CVErr(xlErrNA)
End Function

' ---------- Chua 2000 ----------
' Dühring 系数 (Table 1, p.417)。注记:
' B_12 取 -3.12628E-16 (原文印刷漏负号, 经 Fig.2 验证);
' B_14 读 1.87723E-19; A_10 读 2.37604E-15;
' <x-60> 项 (i=17..20) 按印刷值在 x>60 发散, LW_PsolChua 限 x≤60%。
Private Function DuhrA() As Variant
    DuhrA = Array(1#, 2.92242E-04, 1.05207E-04, 8.86101E-07, _
        -2.71833E-06, 3.52718E-07, -2.03849E-08, 5.6881E-10, _
        -4.32385E-12, -1.42122E-13, 2.37604E-15, 3.9644E-17, _
        -9.81319E-19, -7.91591E-21, 3.92677E-22, -4.04965E-24, _
        1.41694E-26)
End Function

Private Function DuhrB() As Variant
    DuhrB = Array(0#, 5.22677E-02, -9.78477E-03, 7.82919E-03, _
        -1.62913E-03, 1.6405E-04, -8.98817E-06, 2.6264E-07, _
        -2.954E-09, -3.23145E-11, 7.67888E-13, 1.36662E-14, _
        -3.12628E-16, -4.91441E-18, 1.87723E-19, -1.92463E-21, _
        6.87629E-24)
End Function

Private Function WagnerPref(ByVal Tc As Double) As Double
    Dim T As Double, th As Double, s As Double, i As Integer
    Dim a As Variant, e As Variant
    a = Array(-7.85951783, 1.84408259, -11.7866497, _
              22.6807411, -15.9618719, 1.80122502)
    e = Array(1#, 1.5, 3#, 3.5, 4#, 7.5)
    T = Tc + 273.15
    th = 1# - T / 647.096
    s = 0#
    For i = 0 To 5
        s = s + a(i) * th ^ e(i)
    Next i
    WagnerPref = 22.064E+06 * Exp((647.096 / T) * s)
End Function

' 水蒸气分压原生值 [Pa] (Chua Dühring, 私有); 内部算术走此值
Private Function PsolChuaPa(ByVal X As Double, ByVal T As Double) As Variant
    Dim AD As Double, BD As Double, xk As Double, i As Integer
    Dim A As Variant, B As Variant, TdpC As Double
    If X < 0 Or X > 60 Or T < 0 Or T > 190 Then
        PsolChuaPa = CVErr(xlErrValue): Exit Function
    End If
    A = DuhrA(): B = DuhrB()
    AD = 0#: BD = 0#: xk = 1#
    For i = 0 To 16
        If i > 0 Then xk = xk * X
        AD = AD + A(i) * xk
        BD = BD + B(i) * xk
    Next i
    TdpC = (T - BD) / AD
    PsolChuaPa = WagnerPref(TdpC)
End Function

' 水蒸气分压 [MPa] (Chua Dühring): 公开边界 = PsolChuaPa ×0.000001
Public Function LW_PsolChua(ByVal X As Double, ByVal T As Double) As Variant
    Dim v As Variant
    v = PsolChuaPa(X, T)
    If IsError(v) Then LW_PsolChua = CVErr(xlErrValue): Exit Function
    LW_PsolChua = v * 0.000001
End Function

' 由露点温度与溶液温度反解 LiBr 浓度 X [wt%] (Chua 路线):
' P = 纯水在 Tdew 下的饱和压 (模块自有 WagnerPref 纯水函数);
' 二分 80 次反解 PsolChuaPa(X, Tsol) = P (内部一律 Pa, 与公开
' LW_PsolChua 的 MPa 边界分账), 括号 X∈[0,60]
' (LW_PsolChua 有效浓度域)。PsolChuaPa 随 X 单调递减,
' 二分方向与递增型相反。与 Python/C 同算法。
' 无根返回 Empty (如 Tsol 明显低于 Tdew)。
Public Function LW_XByTsolTdewChua(ByVal Tsol_C As Double, ByVal Tdew_C As Double) As Variant
    Dim P As Double, Pmin As Double, Pmax As Double
    Dim lo As Double, hi As Double, mid As Double, k As Long
    P = WagnerPref(Tdew_C)
    Pmax = PsolChuaPa(0#, Tsol_C)
    Pmin = PsolChuaPa(60#, Tsol_C)
    If P < Pmin Or P > Pmax Then
        LW_XByTsolTdewChua = Empty
        Exit Function
    End If
    lo = 0#: hi = 60#
    For k = 1 To 80
        mid = 0.5 * (lo + hi)
        If PsolChuaPa(mid, Tsol_C) > P Then lo = mid Else hi = mid
    Next k
    LW_XByTsolTdewChua = 0.5 * (lo + hi)
End Function


' ---------- 露点温度（溶液）[°C]：全库 TdewByTsolXi 约定 ----------
' Tdew = 纯水饱和温度(PsolPa(X, T))：对 psol 内置的 Patterson 纯水
' log10 关系式解析反解（对 1/TR 的二次方程）。内部用 Pa 原生值
' PsolPa（公开 LW_Psol 返回 MPa）。构造上与 LW_Tdew
' （Patterson TDEW 多项式）相等；LiBr 不挥发，无端点约定问题。
' 超辖区时与 LW_Tdew 同样返回 #VALUE!。
Public Function LW_TdewByTsolX(ByVal X As Double, ByVal T As Double) As Variant
    Dim P As Variant, L As Double, disc As Double, u As Double
    If Not InRange(X, T, 0, 70, 4.4, 182.2) Then LW_TdewByTsolX = CVErr(xlErrValue): Exit Function
    If CheckRegion(X, T, False, TunknStd()) <> "" Then LW_TdewByTsolX = CVErr(xlErrValue): Exit Function
    P = PsolPa(X, T)
    If IsError(P) Then LW_TdewByTsolX = CVErr(xlErrValue): Exit Function
    L = Log(P / 6894.757) / Log(10#)
    disc = 2886.373 ^ 2 - 4# * 337269.46 * (L - 6.21147)
    If disc < 0# Then LW_TdewByTsolX = CVErr(xlErrValue): Exit Function
    u = (-2886.373 + Sqr(disc)) / (2# * 337269.46)
    LW_TdewByTsolX = (1# / u - 459.7 - 32#) * 5# / 9#
End Function

' ---------- 由溶液比焓反解溶液温度 [°C] ----------
' hsol 只在 Patterson 标准区有定义（未知区返回 #VALUE!），故先以
' 5 °C 步长扫描 T = 0..180 °C 找可评价的括号，再二分 80 次反解
' LW_hsol(X, T) = h（hsol 在固定 X 下随 T 单调增）。无括号返回
' Empty。与 C/Python 同算法；本函数未在真实 Excel 中编译运行。
Public Function LW_TsolByHsol(ByVal h As Double, ByVal X As Double) As Variant
    Dim prevT As Double, prevH As Double, havePrev As Boolean
    Dim lo As Double, hi As Double, mid As Double, k As Long
    Dim hv As Variant, haveBracket As Boolean
    havePrev = False: haveBracket = False
    For k = 0 To 36
        hv = LW_hsol(X, 5# * k)
        If Not IsError(hv) Then
            If havePrev And prevH <= h And h <= hv Then
                lo = prevT: hi = 5# * k: haveBracket = True: Exit For
            End If
            prevT = 5# * k: prevH = hv: havePrev = True
        End If
    Next k
    If Not haveBracket Then LW_TsolByHsol = Empty: Exit Function
    For k = 1 To 80
        mid = 0.5 * (lo + hi)
        If LW_hsol(X, mid) < h Then lo = mid Else hi = mid
    Next k
    LW_TsolByHsol = 0.5 * (lo + hi)
End Function

Public Function LW_RhoChua(ByVal X As Double, ByVal T As Double) As Variant
    Dim G As Variant, s As Double, xk As Double, k As Integer
    If X < 0 Or X > 70 Or T < 0 Or T > 200 Then
        LW_RhoChua = CVErr(xlErrValue): Exit Function
    End If
    G = Array(Array(999.1, -0.0239865, -0.00390453), _
              Array(7.74931, -0.0128346, -0.0000555855), _
              Array(0.00536509, 0.000207232, 0.0000109879), _
              Array(0.00134988, -0.00000908213, -2.39834E-07), _
              Array(-0.00000308671, 9.94788E-08, 1.53514E-09))
    s = 0#: xk = 1#
    For k = 0 To 4
        If k > 0 Then xk = xk * X
        s = s + xk * (G(k)(0) + T * (G(k)(1) + T * G(k)(2)))
    Next k
    LW_RhoChua = s
End Function

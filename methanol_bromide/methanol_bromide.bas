Attribute VB_Name = "MethanolBromide"
' 甲醇/(2LiBr-ZnBr2) 热力学关联式（Excel VBA 工作表函数）
' 来源：S. El-Shamarka, PhD thesis, Cranfield Institute of Technology, 1981.
' 体系：盐比固定 LiBr:ZnBr2 = 2:1（摩尔）；w 为甲醇质量分数；盐不挥发。
'   式(3.1) 泡点压力：log10 P[mbar] = C1(w) + C2(w)·(1000/T[K] - 2.3)
'           C1、C2 为表 3.3 的 8 个节点值，节点间 PCHIP 保形插值。
'           表 3.3 的 -C2 在 w=28.0% 处（2.7278）打破单调（30.1% 处 2.8197），
'           按原表照印，PCHIP 在该处斜率为 0，不产生过冲。
'   式(3.4) 比热：Cp = A + B·t[°C]，A = 0.652 + 2.139w - 2.077w^2，
'           B = -0.000205 + 0.00928w - 0.0101w^2。
'           末项符号：p.86 原式为叠印字形，附录 A 重述印 "-"，且取 "-" 与
'           论文表 3.7 实测比热的最大偏差仅 0.7%（取 "+" 则 6%~14%），故取 "-"。
'   附录 A 汽化焓 H'（含混合热）：H' = A + B·w + C·w^2，A/B/C 为 T 的二次式；
'           T 为开尔文（切勿用 °C）；仅 w=0.25~0.356 有效，禁止外推。
' 密度与黏度（MB_RhoIedema / MB_EtaIedema）为另一来源，与上文无关：
'   P. D. Iedema, PhD thesis, TU Delft, 1984（同体系 LiBr/ZnBr2-甲醇）。
'   密度（表 2.7.2.2.2）：rho = [rho25(w) + rho'(w)·(t-25)]·(1 + 0.32·w_H)，
'           rho25、rho' 为 w 的三次式，t 为 °C；w 为总溶剂质量分数
'           （甲醇+水，干溶液时即甲醇质量分数），w_H 为水质量分数。
'           适用 w=0.28~0.42，t=-10~140 °C；作者称平均偏差 0.13%。
'   黏度（表 2.7.3）：ln eta = eta0(w) + etaT(w)/T，eta 为 Pa·s，T 为 K，
'           eta0、etaT 为 w 的三次式。适用 w=0.28~1.0，t=20~120 °C。
'           原表 etaT 末项印作 w^4 且系数下标错标，经 9 个实测点裁决取
'           w^3 读法（平均偏差 2.8%，与作者自称吻合；w^4 读法偏 36%）。
'   注：El-Shamarka 自己的式(4.10) 密度、式(4.11) 黏度仍未核实，本模块
'   未实现，勿与上述 Iedema 关联式混淆（详见 公式说明.md）。
' 参考态（本文档约定，论文未定义绝对基准）：
'   h_liq(0°C, 任意 w) = 100 kJ/kg；h_vap = h_liq + H'。
'
' 工作表函数：
'   =MB_Pbub(T_K, w)    泡点压力，bar
'   =MB_Tbub(P_bar, w)  泡点温度，K
'   =MB_Cp(T_K, w)      溶液比热，kJ/(kg·K)
'   =MB_Hprime(T_K, w)  汽化焓 H'，kJ/kg（仅 w=0.25~0.356）
'   =MB_Hliq(T_K, w)    溶液比焓，kJ/kg
'   =MB_Hvap(T_K, w)    气相比焓，kJ/kg
'   =MB_RhoIedema(T_K, w, w_H)  密度（Iedema 1984），kg/m3
'   =MB_EtaIedema(T_K, w)       动力黏度（Iedema 1984），Pa·s
'
' 注意：本模块未在真实 Excel 中编译运行过，使用前请先编译验证。

Option Explicit

' 表 3.3（p.74）节点：甲醇质量分数
Private Function NodeW(ByVal i As Long) As Double
    Select Case i
        Case 0: NodeW = 0.243
        Case 1: NodeW = 0.25
        Case 2: NodeW = 0.262
        Case 3: NodeW = 0.28
        Case 4: NodeW = 0.301
        Case 5: NodeW = 0.356
        Case 6: NodeW = 0.403
        Case 7: NodeW = 0.509
    End Select
End Function

Private Function NodeC1(ByVal i As Long) As Double
    Select Case i
        Case 0: NodeC1 = 2.6712
        Case 1: NodeC1 = 2.8572
        Case 2: NodeC1 = 2.9758
        Case 3: NodeC1 = 3.0535
        Case 4: NodeC1 = 3.3146
        Case 5: NodeC1 = 3.4604
        Case 6: NodeC1 = 3.777
        Case 7: NodeC1 = 4.0494
    End Select
End Function

Private Function NodeC2(ByVal i As Long) As Double
    Select Case i
        Case 0: NodeC2 = -3.0602
        Case 1: NodeC2 = -3.0344
        Case 2: NodeC2 = -2.9531
        Case 3: NodeC2 = -2.7278
        Case 4: NodeC2 = -2.8197
        Case 5: NodeC2 = -2.6219
        Case 6: NodeC2 = -2.4256
        Case 7: NodeC2 = -2.0194
    End Select
End Function

Private Function PchipEndSlope(ByVal h0 As Double, ByVal h1 As Double, _
                               ByVal d0 As Double, ByVal d1 As Double) As Double
    Dim m As Double
    m = ((2# * h0 + h1) * d0 - h0 * d1) / (h0 + h1)
    If m * d0 <= 0# Then
        PchipEndSlope = 0#
    ElseIf d0 * d1 < 0# And Abs(m) > Abs(3# * d0) Then
        PchipEndSlope = 3# * d0
    Else
        PchipEndSlope = m
    End If
End Function

' Fritsch-Carlson PCHIP；which=1 取 C1，which=2 取 C2
Private Function PchipEval(ByVal which As Long, ByVal w As Double) As Double
    Dim xs(0 To 7) As Double, ys(0 To 7) As Double
    Dim h(0 To 6) As Double, d(0 To 6) As Double, m(0 To 7) As Double
    Dim i As Long, lo As Long, hi As Long, mid As Long
    Dim w1 As Double, w2 As Double, s As Double, s2 As Double, s3 As Double
    For i = 0 To 7
        xs(i) = NodeW(i)
        If which = 1 Then ys(i) = NodeC1(i) Else ys(i) = NodeC2(i)
    Next i
    For i = 0 To 6
        h(i) = xs(i + 1) - xs(i)
        d(i) = (ys(i + 1) - ys(i)) / h(i)
    Next i
    For i = 1 To 6
        If d(i - 1) * d(i) <= 0# Then
            m(i) = 0#
        Else
            w1 = 2# * h(i) + h(i - 1)
            w2 = h(i) + 2# * h(i - 1)
            m(i) = (w1 + w2) / (w1 / d(i - 1) + w2 / d(i))
        End If
    Next i
    m(0) = PchipEndSlope(h(0), h(1), d(0), d(1))
    m(7) = PchipEndSlope(h(6), h(5), d(6), d(5))
    If w <= xs(0) Then
        i = 0
    ElseIf w >= xs(7) Then
        i = 6
    Else
        lo = 0: hi = 7
        Do While hi - lo > 1
            mid = (lo + hi) \ 2
            If xs(mid) <= w Then lo = mid Else hi = mid
        Loop
        i = lo
    End If
    s = (w - xs(i)) / h(i)
    s2 = s * s: s3 = s2 * s
    PchipEval = (2# * s3 - 3# * s2 + 1#) * ys(i) _
              + h(i) * (s3 - 2# * s2 + s) * m(i) _
              + (3# * s2 - 2# * s3) * ys(i + 1) _
              + h(i) * (s3 - s2) * m(i + 1)
End Function

Private Sub CpAB(ByVal w As Double, ByRef A As Double, ByRef B As Double)
    A = 0.652 + 2.139 * w - 2.077 * w * w
    B = -0.000205 + 0.00928 * w - 0.0101 * w * w
End Sub

' 式(3.1)：泡点压力，bar
Public Function MB_Pbub(ByVal T_K As Double, ByVal w As Double) As Double
    Dim log10p As Double
    log10p = PchipEval(1, w) + PchipEval(2, w) * (1000# / T_K - 2.3)
    MB_Pbub = 10# ^ log10p / 1000#
End Function

' 式(3.1) 解析反解：泡点温度，K
Public Function MB_Tbub(ByVal P_bar As Double, ByVal w As Double) As Double
    Dim log10p As Double
    log10p = Log(P_bar * 1000#) / Log(10#)
    MB_Tbub = 1000# / ((log10p - PchipEval(1, w)) / PchipEval(2, w) + 2.3)
End Function

' 式(3.4)：溶液比热，kJ/(kg·K)
Public Function MB_Cp(ByVal T_K As Double, ByVal w As Double) As Double
    Dim A As Double, B As Double
    CpAB w, A, B
    MB_Cp = A + B * (T_K - 273.15)
End Function

' 附录 A：汽化焓 H'（含混合热），kJ/kg；T_K 为开尔文；仅 w=0.25~0.356
Public Function MB_Hprime(ByVal T_K As Double, ByVal w As Double) As Double
    Dim A As Double, B As Double, C As Double
    A = 2202.6 + 9.24 * T_K - 0.0218 * T_K * T_K
    B = -(4417.8 + 15.53 * T_K - 0.0392 * T_K * T_K)
    C = 3570# + 10.81 * T_K - 0.0294 * T_K * T_K
    MB_Hprime = A + B * w + C * w * w
End Function

' 溶液比焓，kJ/kg；参考态约定 h_liq(0°C) = 100 kJ/kg
Public Function MB_Hliq(ByVal T_K As Double, ByVal w As Double) As Double
    Dim A As Double, B As Double, t As Double
    CpAB w, A, B
    t = T_K - 273.15
    MB_Hliq = 100# + A * t + B * t * t / 2#
End Function

' 气相比焓，kJ/kg：h_vap = h_liq + H'
Public Function MB_Hvap(ByVal T_K As Double, ByVal w As Double) As Double
    MB_Hvap = MB_Hliq(T_K, w) + MB_Hprime(T_K, w)
End Function

' Iedema 表 2.7.2.2.2：密度，kg/m3。T_K 为开尔文（内部换算 t[°C]）；
' w 为总溶剂质量分数 w_t（甲醇+水），w_H 为水质量分数；
' 干溶液 w_H=0 时 w_t 即甲醇质量分数。适用 w=0.28~0.42，t=-10~140 °C
Public Function MB_RhoIedema(ByVal T_K As Double, ByVal w As Double, _
                             ByVal w_H As Double) As Double
    Dim t As Double, rho25 As Double, drho As Double
    t = T_K - 273.15
    rho25 = 3026.745 - 5369.24 * w + 4082.056 * w * w + 103.8639 * w * w * w
    drho = -0.0997537 - 11.77377 * w + 42.24796 * w * w - 44.70839 * w * w * w
    MB_RhoIedema = (rho25 + drho * (t - 25#)) * (1# + 0.32 * w_H)
End Function

' Iedema 表 2.7.3：动力黏度，Pa·s；ln eta = eta0(w) + etaT(w)/T_K。
' 末项取 w^3 读法（裁决依据见模块头）。适用 w=0.28~1.0，t=20~120 °C
Public Function MB_EtaIedema(ByVal T_K As Double, ByVal w As Double) As Double
    Dim eta0 As Double, etaT As Double
    eta0 = -18.29756 + 26.2373 * w - 33.51444 * w * w + 13.86405 * w * w * w
    etaT = 5481.757 - 11371.61 * w + 10873.4 * w * w - 3718.145 * w * w * w
    MB_EtaIedema = Exp(eta0 + etaT / T_K)
End Function

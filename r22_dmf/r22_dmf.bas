Attribute VB_Name = "R22DMF"
'==============================================================================
' R22-DMF 泡点压力与溶液焓 —— Excel 工作表函数
' 泡点压力: 对 Agarwal(1982) VLE 数据(经 Ardita 论文附录转录,132 点,xi>=0.10)
'   按浓度分层拟合 Antoine 式 ln(P/bar)=A+B/T+C*ln(T) (T 为 K),
'   再对 R22 质量分数 xi 做保单调 PCHIP 插值。AARD 2.38%, 最大 9.6%。
'   适用: T -25~120 C, xi 0.10~1.00 (xi>0.80 且 T>65C 时为外推, 慎用)。
' 溶液焓: Fatouh 等 1993 关联式 (Ardita 论文 2.38~2.43), kJ/kg,
'   参考态 273.15K 饱和液体=100 kJ/kg。适用约 T -20~95C。
' 用法: =R22DMF_BubbleP(40, 0.5)   -> 泡点压力 bar
'       =R22DMF_BubbleT(3.8, 0.5)  -> 泡点温度 C
'       =R22DMF_Hsol(30, 0.5)      -> 溶液焓 kJ/kg
'==============================================================================
Option Explicit

Private Const NISO As Long = 10

Private Function IsoXi(i As Long) As Double
    Dim v As Variant
    v = Array(0.1, 0.23076, 0.32, 0.40348, 0.5, 0.6022, 0.7, 0.8, 0.9, 1#)
    IsoXi = v(i)
End Function
Private Function IsoA(i As Long) As Double
    Dim v As Variant
    v = Array(30.772744, 10.400862, 10.271208, -5.84816, 39.598401, _
              27.566449, 28.096798, 51.969188, 99.166678, 18.47413)
    IsoA = v(i)
End Function
Private Function IsoB(i As Long) As Double
    Dim v As Variant
    v = Array(-3182.9395, -2459.9752, -2405.5462, -1618.6504, -3709.7856, _
              -3089.5702, -3022.7056, -4223.6822, -6197.2, -2766.7568)
    IsoB = v(i)
End Function
Private Function IsoC(i As Long) As Double
    Dim v As Variant
    v = Array(-3.629138, -0.388685, -0.311415, 2.088399, -4.591025, _
              -2.81985, -2.907606, -6.297351, -13.369886, -1.197267)
    IsoC = v(i)
End Function

' 内部: 给定 T(K), 对 xi 做 PCHIP 求泡点压力
Private Function BubbleP_K(T As Double, xi As Double) As Double
    Dim x(9) As Double, y(9) As Double, h(8) As Double, d(8) As Double, dk(9) As Double
    Dim i As Long, k As Long, xc As Double, lnT As Double, t As Double, t2 As Double, t3 As Double
    xc = xi
    If xc < 0.1 Then xc = 0.1
    If xc > 1# Then xc = 1#
    lnT = Log(T)
    For i = 0 To 9
        x(i) = IsoXi(i)
        y(i) = Exp(IsoA(i) + IsoB(i) / T + IsoC(i) * lnT)
    Next i
    For i = 0 To 8
        h(i) = x(i + 1) - x(i)
        d(i) = (y(i + 1) - y(i)) / h(i)
    Next i
    dk(0) = d(0): dk(9) = d(8)
    For k = 1 To 8
        If d(k - 1) * d(k) <= 0 Then
            dk(k) = 0
        Else
            Dim w1 As Double, w2 As Double
            w1 = 2 * h(k) + h(k - 1): w2 = h(k) + 2 * h(k - 1)
            dk(k) = (w1 + w2) / (w1 / d(k - 1) + w2 / d(k))
        End If
    Next k
    k = 0
    Do While k < 8 And xc > x(k + 1)
        k = k + 1
    Loop
    t = (xc - x(k)) / h(k): t2 = t * t: t3 = t2 * t
    BubbleP_K = (2 * t3 - 3 * t2 + 1) * y(k) + (t3 - 2 * t2 + t) * h(k) * dk(k) _
              + (-2 * t3 + 3 * t2) * y(k + 1) + (t3 - t2) * h(k) * dk(k + 1)
End Function

Public Function R22DMF_BubbleP(T_C As Double, xi As Double) As Double
    ' 泡点压力 bar; T_C 摄氏度, xi 为 R22 质量分数
    R22DMF_BubbleP = BubbleP_K(T_C + 273.15, xi)
End Function

Public Function R22DMF_BubbleT(P_bar As Double, xi As Double) As Variant
    ' 泡点温度 摄氏度 (二分法反算); 超出范围返回 #N/A
    Dim lo As Double, hi As Double, mid As Double, i As Long
    lo = -25#: hi = 120#
    If P_bar < BubbleP_K(lo + 273.15, xi) Or P_bar > BubbleP_K(hi + 273.15, xi) Then
        R22DMF_BubbleT = CVErr(xlErrNA): Exit Function
    End If
    For i = 1 To 60
        mid = 0.5 * (lo + hi)
        If BubbleP_K(mid + 273.15, xi) < P_bar Then lo = mid Else hi = mid
    Next i
    R22DMF_BubbleT = 0.5 * (lo + hi)
End Function

Private Function FPoly(F0 As Double, F1 As Double, F2 As Double, T As Double) As Double
    FPoly = F0 + F1 * T + F2 * T * T   ' T 为 K
End Function

Public Function R22DMF_H_R22L(T_C As Double) As Double
    Dim T As Double: T = T_C + 273.15
    If T < 323.15 Then R22DMF_H_R22L = FPoly(-68.1484, 0.06313, 0.00202, T) _
    Else R22DMF_H_R22L = FPoly(1966.645, -12.09784, 0.02018352, T)
End Function

Public Function R22DMF_H_R22V(T_C As Double) As Double
    Dim T As Double: T = T_C + 273.15
    If T < 323.15 Then R22DMF_H_R22V = FPoly(37.22971, 1.59952, -0.002260308, T) _
    Else R22DMF_H_R22V = FPoly(-2720.182, 18.11784, -0.02699451, T)
End Function

Public Function R22DMF_H_DMF(T_C As Double) As Double
    R22DMF_H_DMF = FPoly(-352.2493, 1.317081, 0.001239553, T_C + 273.15)
End Function

Private Function H_Fatouh(T_C As Double, xi As Double) As Double
    ' Fatouh 原始关联式 (xi<=0.9 有效; hmix 在 xi=1 处不归零)
    Dim T As Double, T2 As Double, T3 As Double, omx As Double
    Dim Y0 As Double, Y1 As Double, Y2 As Double, Y3 As Double
    Dim K0 As Double, K1 As Double, K2 As Double, K3 As Double
    Dim Mmix As Double, hmix As Double
    Const B0 = -1817.206, B1 = -4302.679, B2 = 9877.574
    Const C0 = -135585.8, C1 = 625797.9, C2 = -1435546#
    Const E1 = -7738.2052, E2 = 0.0562768, E3 = -34.79
    Const MR22 = 86.47, MDMF = 73.09, RR = 8.314
    T = T_C + 273.15: T2 = T * T: T3 = T2 * T
    omx = 1 - xi
    Y0 = xi / omx
    Y1 = xi / omx + Log(omx)
    Y2 = 1 / omx - omx + 2 * Log(omx)
    Y3 = xi / omx + xi * xi / 2 + 2 * xi + 3 * Log(omx)
    K0 = B0 / T2 + 2 * C0 / T3 - E1 / T2 + E2 + E3 / T
    K1 = B1 / T2 + 2 * C1 / T3
    K2 = B2 / T2 + 2 * C2 / T3
    K3 = 0
    Mmix = xi * MR22 + omx * MDMF
    hmix = (omx * RR * T2 / Mmix) * (K0 * Y0 + K1 * Y1 + K2 * Y2 + K3 * Y3)
    H_Fatouh = xi * R22DMF_H_R22L(T_C) + omx * R22DMF_H_DMF(T_C) + hmix
End Function

Public Function R22DMF_Hsol(T_C As Double, xi As Double) As Double
    ' R22-DMF 溶液焓 kJ/kg; 0.9<xi<1 时线性过渡到纯 R22 (保证 xi=1 连续)
    Dim h09 As Double
    If xi <= 0 Then R22DMF_Hsol = R22DMF_H_DMF(T_C): Exit Function
    If xi >= 1 Then R22DMF_Hsol = R22DMF_H_R22L(T_C): Exit Function
    If xi <= 0.9 Then R22DMF_Hsol = H_Fatouh(T_C, xi): Exit Function
    h09 = H_Fatouh(T_C, 0.9)
    R22DMF_Hsol = h09 + (xi - 0.9) / 0.1 * (R22DMF_H_R22L(T_C) - h09)
End Function

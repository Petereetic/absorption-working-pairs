Attribute VB_Name = "R134a_DMF"
'======================================================================
' R134a (1) + DMF (2) 溶液 VLE 与焓计算 - Excel VBA 模块
'======================================================================
' 模型: NRTL 活度系数 + gamma-phi 泡点模型
' 数据源: Zehioua et al., J. Chem. Eng. Data 2009, DOI: 10.1021/je900440t
' 验证: 58 个实验点 (303.30-353.24 K), 泡点压力平均绝对相对误差 1.49%
'        (注: 1.49% 仅为训练集拟合精度。独立验证: Cui 2007 90点 AARD 15.1%,
'         Han 2011 112点 AARD 10.1%; 跨实验室不确定度约 300K/8%、360K/20%。
'         详见《文献合并研究-R134a-DMF-2026-09-30.md》)
' 参考态: 273.15 K 饱和液体焓 = 100 kJ/kg (两组分统一)
'
' 使用方法:
'   1. Excel 中按 Alt+F11 打开 VBA 编辑器
'   2. 菜单: 文件 -> 导入文件 -> 选择本文件 (r134a_dmf.bas)
'   3. 在工作表中直接调用, 例如:
'        =Bubble_P(303.3, 0.4437)        求泡点压力 (MPa)
'        =Bubble_T(0.337, 0.4437)        已知压力反算温度 (K)
'        =H_Solution(330, 0.5)           求溶液焓 (kJ/kg)
'        =Psat_R134a(303.15)             R134a 饱和压力 (MPa)
'======================================================================
Option Explicit

Private Const R_GAS As Double = 8.314462618  ' J/(mol·K)
Private Const M1 As Double = 102.03          ' R134a 摩尔质量 g/mol
Private Const M2 As Double = 73.09           ' DMF 摩尔质量 g/mol
Private Const DG12 As Double = 868.1         ' NRTL, J/mol
Private Const DG21 As Double = -929.1        ' NRTL, J/mol
Private Const ALPHA As Double = 0.3

'---------- 纯组分饱和压力 (MPa), T in K ----------

Public Function Psat_R134a(T As Double) As Double
    Psat_R134a = Exp(7.89191 - 2310.84 / (T - 19.79))
End Function

Public Function Psat_DMF(T As Double) As Double
    Psat_DMF = (10# ^ (3.93068 - 1337.716 / (T - 82.648))) * 0.1
End Function

'---------- 液体摩尔体积 (m3/mol), Poynting 校正用 ----------

Private Function VL_R134a(T As Double) As Double
    Dim rho As Double
    rho = 1207# * (1# - 0.35 * (T - 300#) / 100#)
    If rho < 800# Then rho = 800#
    VL_R134a = 0.10203 / rho
End Function

Private Function VL_DMF(T As Double) As Double
    VL_DMF = 0.07309 / (944# * (1# - 0.0009 * (T - 293#)))
End Function

'---------- NRTL 活度系数 ----------
' 输入 T(K), x1 ; 输出 g1, g2 (ByRef)

Public Sub NRTL_Gamma(T As Double, x1 As Double, ByRef g1 As Double, ByRef g2 As Double)
    Dim x2 As Double, t12 As Double, t21 As Double
    Dim G12 As Double, G21 As Double, D1 As Double, D2 As Double
    Dim r1 As Double, r2 As Double
    x2 = 1# - x1
    t12 = DG12 / (R_GAS * T)
    t21 = DG21 / (R_GAS * T)
    G12 = Exp(-ALPHA * t12)
    G21 = Exp(-ALPHA * t21)
    D1 = x1 + x2 * G21
    D2 = x2 + x1 * G12
    r1 = G21 / D1
    r2 = G12 / D2
    g1 = Exp(x2 ^ 2 * (t21 * r1 ^ 2 + t12 * G12 / D2 ^ 2))
    g2 = Exp(x1 ^ 2 * (t12 * r2 ^ 2 + t21 * G21 / D1 ^ 2))
End Sub

'---------- NRTL 超额摩尔焓 (J/mol) ----------

Public Function NRTL_hE(T As Double, x1 As Double) As Double
    Dim x2 As Double, t12 As Double, t21 As Double
    Dim G12 As Double, G21 As Double, D1 As Double, D2 As Double
    Dim term1 As Double, term2 As Double
    x2 = 1# - x1
    t12 = DG12 / (R_GAS * T)
    t21 = DG21 / (R_GAS * T)
    G12 = Exp(-ALPHA * t12)
    G21 = Exp(-ALPHA * t21)
    D1 = x1 + x2 * G21
    D2 = x2 + x1 * G12
    term1 = (t21 * G21 / D1) * (-1# + ALPHA * t21 * x1 / D1)
    term2 = (t12 * G12 / D2) * (-1# + ALPHA * t12 * x2 / D2)
    NRTL_hE = -R_GAS * T * x1 * x2 * (term1 + term2)
End Function

'---------- 泡点压力 (MPa) ----------
' 输入 T(K), x1 ; y1 为气相摩尔分数 (ByRef 输出, 可忽略)
' 气相几乎为纯 R134a (y1 > 0.99)

Public Function Bubble_P(T As Double, x1 As Double, Optional ByRef y1 As Double = -1#) As Double
    Dim x2 As Double, g1 As Double, g2 As Double
    Dim p1s As Double, p2s As Double, V1 As Double, V2 As Double
    Dim p As Double, Poy1 As Double, Poy2 As Double, i As Integer
    x2 = 1# - x1
    NRTL_Gamma T, x1, g1, g2
    p1s = Psat_R134a(T)
    p2s = Psat_DMF(T)
    V1 = VL_R134a(T)
    V2 = VL_DMF(T)
    p = x1 * g1 * p1s + x2 * g2 * p2s
    For i = 1 To 40
        Poy1 = Exp(V1 * (p - p1s) * 1000000# / (R_GAS * T))
        Poy2 = Exp(V2 * (p - p2s) * 1000000# / (R_GAS * T))
        p = x1 * g1 * p1s * Poy1 + x2 * g2 * p2s * Poy2
    Next i
    Poy1 = Exp(V1 * (p - p1s) * 1000000# / (R_GAS * T))
    y1 = x1 * g1 * p1s * Poy1 / p
    Bubble_P = p
End Function

'---------- 已知泡点压力反算温度 (K), 牛顿迭代 ----------

Public Function Bubble_T(p_MPa As Double, x1 As Double, Optional Tguess As Double = 330#) As Double
    Dim T As Double, pc As Double, p2 As Double, dpdT As Double
    Dim dT As Double, dummy As Double, i As Integer
    T = Tguess
    dT = 0.2
    For i = 1 To 50
        pc = Bubble_P(T, x1, dummy)
        p2 = Bubble_P(T + dT, x1, dummy)
        dpdT = (p2 - pc) / dT
        If Abs(dpdT) < 0.000000000001 Then Exit For
        T = T - (pc - p_MPa) / dpdT
        If Abs(pc - p_MPa) < 0.000000001 Then Exit For
    Next i
    Bubble_T = T
End Function

'---------- 纯组分液体焓 (kJ/kg) ----------

Public Function H_R134a_L(T As Double) As Double
    Dim tt As Double
    tt = T - 273.15
    H_R134a_L = 0.00001310235 * tt ^ 3 + 0.00134329 * tt ^ 2 + 1.334242 * tt + 100#
End Function

Public Function H_DMF_L(T As Double) As Double
    H_DMF_L = -297.61 + 0.89544 * T + 0.0020551 * T * T
End Function

'---------- 摩尔分数 <-> 质量分数 (R134a) ----------

Public Function X_to_W(x1 As Double) As Double
    X_to_W = x1 * M1 / (x1 * M1 + (1# - x1) * M2)
End Function

Public Function W_to_X(w1 As Double) As Double
    W_to_X = (w1 / M1) / (w1 / M1 + (1# - w1) / M2)
End Function

'---------- 溶液焓 (kJ/kg) ----------
' h = w1*h1 + w2*h2 + hE/Mbar

Public Function H_Solution(T As Double, x1 As Double) As Double
    Dim x2 As Double, Mbar As Double, w1 As Double, w2 As Double, hE As Double
    x2 = 1# - x1
    Mbar = x1 * M1 + x2 * M2
    w1 = x1 * M1 / Mbar
    w2 = x2 * M2 / Mbar
    hE = NRTL_hE(T, x1)
    H_Solution = w1 * H_R134a_L(T) + w2 * H_DMF_L(T) + hE / Mbar
End Function

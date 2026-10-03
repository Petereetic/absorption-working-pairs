Attribute VB_Name = "NH3LiNO3"
' ==========================================================================
' 氨-硝酸锂 (NH3/LiNO3) 溶液物性 VBA 工作表函数
' ==========================================================================
' 来源: Amaris Castilla, C.F. (2014) 博士论文, Universitat Rovira i
' Virgili, 附录 B (pp. A-6~A-8) 转录的关联式:
'   泡点压力 Libotean et al. (2007); 液体焓 Valles & Salavera (2011,
'   Haltenberger 法); 比热/密度 Libotean et al. (2008); 导热 Cuenca
'   et al. (2013a); 结晶界限 Infante Ferreira et al. (1984)。
' 黏度不实现: 论文附录 B 黏度式排版残损, 重构式未经核实
' (仅 Python 版以 EXPERIMENTAL 标记提供)。
'
' *** 本 .bas 未在真实 Excel 中编译或运行, 系由 Python 参考实现 ***
' *** 逐行移植, 使用前请在 Excel 中实测。                      ***
'
' 约定: x = 氨质量分数 (小数, 如 0.5); T 为 K (NL_Xcris 用 °C)。
' 工作表函数:
'   NL_Pbub(T_K, x)     泡点压力 [kPa]      (T 293.15-353.15, x 0.35-0.65)
'   NL_Tbub(P_kPa, x)   泡点温度 [K]        (解析反解; 结果须在上述 T 域)
'   NL_Hliq(T_K, x)     溶液比焓 [kJ/kg]    (T 273.15-353.15, x 0.35-0.65)
'   NL_Cp(T_K, x)       比热 [kJ/(kg K)]    (T 293.15-353.15, x 0.35-0.65)
'   NL_Rho(T_K, x)      密度 [kg/m^3]       (T 293.15-353.15, x 0.35-0.65)
'   NL_K(T_K, x)        导热系数 [W/(m K)]  (T 303.15-353.15, x 0.35-0.60)
'   NL_Xcris(T_C, x)    结晶界限量 XCRIS    (x 0-1, 原文十分段伪代码)
'
' 焓参考态 (来源原文): 0 °C、x=0.5 时 H = 0 kJ/kg。与本库其他工质对
' 的参考态不同, 跨工质对作焓差比较时注意。
' 导热注记: 论文印作 ka3 T^2 x (ka3 项带 x), 本实现按不带额外 x 的
' 读法, 两读法差约 3%, 详见 公式说明.md。
' 范围外返回 #VALUE! 错误值。
' ==========================================================================
Option Explicit

' ---------- 三次多项式 (Horner, 系数常数项在前, 存于 Variant 数组) ----------
Private Function Poly3(ByRef c As Variant, ByVal x As Double) As Double
    Poly3 = ((c(3) * x + c(2)) * x + c(1)) * x + c(0)
End Function

Private Function PaPb(ByVal x As Double, ByRef pa As Double, ByRef pb As Double)
    Dim cpa As Variant, cpb As Variant
    cpa = Array(4.99470524658178, 88.5490906185871, _
                -197.698944465798, 134.938665891525)
    cpb = Array(-1793.21854659273, -22317.1158016582, _
                61289.3128925447, -45238.5915843719)
    pa = Poly3(cpa, x)
    pb = Poly3(cpb, x)
End Function

Private Function InRng(ByVal v As Double, ByVal lo As Double, _
                       ByVal hi As Double) As Boolean
    InRng = (v >= lo And v <= hi)
End Function

' ---------- 泡点压力 [kPa]: ln P = pa(x) + pb(x)/T ----------
Public Function NL_Pbub(ByVal T_K As Double, ByVal x As Double) As Variant
    Dim pa As Double, pb As Double
    If Not InRng(T_K, 293.15, 353.15) Or Not InRng(x, 0.35, 0.65) Then
        NL_Pbub = CVErr(xlErrValue): Exit Function
    End If
    PaPb x, pa, pb
    NL_Pbub = Exp(pa + pb / T_K)
End Function

' ---------- 泡点温度 [K]: T = pb / (ln P - pa) ----------
Public Function NL_Tbub(ByVal P_kPa As Double, ByVal x As Double) As Variant
    Dim pa As Double, pb As Double, denom As Double, T_K As Double
    If Not InRng(x, 0.35, 0.65) Or P_kPa <= 0# Then
        NL_Tbub = CVErr(xlErrValue): Exit Function
    End If
    PaPb x, pa, pb
    denom = Log(P_kPa) - pa
    If denom = 0# Then
        NL_Tbub = CVErr(xlErrValue): Exit Function
    End If
    T_K = pb / denom
    If Not InRng(T_K, 293.15, 353.15) Then
        NL_Tbub = CVErr(xlErrValue): Exit Function
    End If
    NL_Tbub = T_K
End Function

' ---------- 溶液比焓 [kJ/kg]: H = ha + hb T + hc T^2 ----------
Public Function NL_Hliq(ByVal T_K As Double, ByVal x As Double) As Variant
    Dim cha As Variant, chb As Variant, chc As Variant
    If Not InRng(T_K, 273.15, 353.15) Or Not InRng(x, 0.35, 0.65) Then
        NL_Hliq = CVErr(xlErrValue): Exit Function
    End If
    cha = Array(249.1567745, -1628.297463, -464.3464344, -105.6321057)
    chb = Array(2.481273559, -5.184392344, -0.775202139, 18.98142102)
    chc = Array(-0.004240786, 0.025111292, -0.013342843, -0.025956064)
    NL_Hliq = Poly3(cha, x) + Poly3(chb, x) * T_K _
              + Poly3(chc, x) * T_K * T_K
End Function

' ---------- 比热 [kJ/(kg K)] (原文 J/(g K), 数值相同) ----------
Public Function NL_Cp(ByVal T_K As Double, ByVal x As Double) As Variant
    Dim cpa As Double, cpb As Double
    If Not InRng(T_K, 293.15, 353.15) Or Not InRng(x, 0.35, 0.65) Then
        NL_Cp = CVErr(xlErrValue): Exit Function
    End If
    cpa = 0.559273057 + 3.241167393 * x
    cpb = 0.00207796 + 0.001846907 * x
    NL_Cp = cpa + cpb * T_K
End Function

' ---------- 密度 [kg/m^3]: rho = 1000 (da + db T) ----------
Public Function NL_Rho(ByVal T_K As Double, ByVal x As Double) As Variant
    Dim da As Double, db As Double
    If Not InRng(T_K, 293.15, 353.15) Or Not InRng(x, 0.35, 0.65) Then
        NL_Rho = CVErr(xlErrValue): Exit Function
    End If
    da = 1.521 - 0.4528 * x
    db = -0.00001961 - 0.001726 * x
    NL_Rho = 1000# * (da + db * T_K)
End Function

' ---------- 导热系数 [W/(m K)]: k = ka1 + ka2 T + ka3 T^2 + ka4 x ----------
Public Function NL_K(ByVal T_K As Double, ByVal x As Double) As Variant
    If Not InRng(T_K, 303.15, 353.15) Or Not InRng(x, 0.35, 0.6) Then
        NL_K = CVErr(xlErrValue): Exit Function
    End If
    NL_K = 0.446088003 - 0.000350326 * T_K _
           + 0.000000213849 * T_K * T_K + 0.006538043 * x
End Function

' ---------- 结晶界限 XCRIS (Infante Ferreira 1984, 十分段逐字转录) ----------
Public Function NL_Xcris(ByVal T_C As Double, ByVal x As Double) As Variant
    Dim T As Double
    T = T_C
    If x < 0.2911 Then
        NL_Xcris = 0.3021 - 0.00034 * T - 0.00000272 * T * T
    ElseIf x < 0.3 Then
        NL_Xcris = x
    ElseIf x < 0.3076 Then
        NL_Xcris = -0.000608 * T + 0.3152
    ElseIf x < 0.3362 Then
        NL_Xcris = 0.0143 * T + 0.12885
    ElseIf x < 0.4304 Then
        NL_Xcris = -0.005402 * T + 0.41318
    ElseIf x < 0.5072 Then
        NL_Xcris = 0.443413 + 0.0069 * T + 0.000854 * T * T
    ElseIf x < 0.6434 Then
        NL_Xcris = 0.527643 - 0.003126 * T - 0.000019 * T * T
    ElseIf x < 0.6649 Then
        NL_Xcris = -0.004605 * T + 0.40761
    ElseIf x < 0.7826 Then
        NL_Xcris = 0.0000309 * T * T + 0.57452
    ElseIf x <= 1# Then
        NL_Xcris = 0.07378 * T + 6.7214
    Else
        NL_Xcris = CVErr(xlErrValue)
    End If
End Function

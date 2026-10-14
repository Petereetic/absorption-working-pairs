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
' 压力: 公开工作表函数边界一律 MPa; 内部算术与源式仍为 kPa,
' 公开函数只在边界作 MPa <-> kPa 换算 (私有函数 Psol_TX_kPa /
' T_bubble_PX_kPa 为内部 kPa 原生值)。
' 工作表函数:
'   NL_Psol(T_K, x)     泡点压力 [MPa]      (T 293.15-353.15, x 0.35-0.65)
'   NL_Tbub(P_MPa, x)   泡点温度 [K]        (解析反解; 结果须在上述 T 域)
'   NL_hsol(T_K, x)     溶液比焓 [kJ/kg]    (T 273.15-353.15, x 0.35-0.65)
'   NL_Cp(T_K, x)       比热 [kJ/(kg K)]    (T 293.15-353.15, x 0.35-0.65)
'   NL_Rho(T_K, x)      密度 [kg/m^3]       (T 293.15-353.15, x 0.35-0.65)
'   NL_K(T_K, x)        导热系数 [W/(m K)]  (T 303.15-353.15, x 0.35-0.60)
'   NL_Xcris(T_C, x)    结晶界限量 XCRIS    (x 0-1, 原文十分段伪代码)
'   NL_XiByTsolTdew(Tdew_K, Tsol_K)  由露点温度与溶液温度反解 x;
'                       无根返回 Empty (本函数按跨工质对统一约定,
'                       不用本模块其余函数的 #VALUE! 约定)
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

' ---------- (私有, 内部原生值) 泡点压力 [kPa]: ln P = pa(x) + pb(x)/T ----------
Private Function Psol_TX_kPa(ByVal T_K As Double, ByVal x As Double) As Variant
    Dim pa As Double, pb As Double
    If Not InRng(T_K, 293.15, 353.15) Or Not InRng(x, 0.35, 0.65) Then
        Psol_TX_kPa = CVErr(xlErrValue): Exit Function
    End If
    PaPb x, pa, pb
    Psol_TX_kPa = Exp(pa + pb / T_K)
End Function

' ---------- 泡点压力 [MPa]: 公开边界只作换算 = Psol_TX_kPa * 1e-3 ----------
Public Function NL_Psol(ByVal T_K As Double, ByVal x As Double) As Variant
    Dim p As Variant
    p = Psol_TX_kPa(T_K, x)
    If IsError(p) Then
        NL_Psol = p
    Else
        NL_Psol = p * 0.001
    End If
End Function

' ---------- (私有, 内部原生值) 泡点温度 [K]: T = pb / (ln P - pa), P 为 kPa ----------
Private Function T_bubble_PX_kPa(ByVal P_kPa As Double, ByVal x As Double) As Variant
    Dim pa As Double, pb As Double, denom As Double, T_K As Double
    If Not InRng(x, 0.35, 0.65) Or P_kPa <= 0# Then
        T_bubble_PX_kPa = CVErr(xlErrValue): Exit Function
    End If
    PaPb x, pa, pb
    denom = Log(P_kPa) - pa
    If denom = 0# Then
        T_bubble_PX_kPa = CVErr(xlErrValue): Exit Function
    End If
    T_K = pb / denom
    If Not InRng(T_K, 293.15, 353.15) Then
        T_bubble_PX_kPa = CVErr(xlErrValue): Exit Function
    End If
    T_bubble_PX_kPa = T_K
End Function

' ---------- 泡点温度 [K]: 公开边界入参 P_MPa [MPa], 换回 kPa 交私有原生函数 ----------
Public Function NL_Tbub(ByVal P_MPa As Double, ByVal x As Double) As Variant
    NL_Tbub = T_bubble_PX_kPa(P_MPa * 1000#, x)
End Function

' ---------- 纯氨饱和线 (露点口径, 供 NL_XiByTsolTdew 用) ----------
' LiNO3 不挥发, 气相视为纯氨。纯氨线 2026-10-12 换源: 改用氨 NIST
' 饱和表紧凑拟合 (lnP-t 7 次多项式, P 以 MPa 计, t 为 degC; 源:
' NIST WebBook 饱和表 210 点 -77~132 degC; 常用带 -50~+60 degC
' 最大偏差 0.0027%)。此前用 Patek-Klomfar 式 (6) 纯氨端点, 其
' 25 degC 给 1012 kPa, 较 NIST 表值 1002.69 kPa 高约 0.9%, 自此
' 只作历史口径分账。混合物泡点式不变。辖区 t = -77~132 degC。
Private Function PrefNH3Pure(ByVal T_K As Double) As Variant
    Dim t As Double, lnP As Double, k As Long, c As Variant
    t = T_K - 273.15
    If t < -77# Or t > 132# Then
        PrefNH3Pure = Empty: Exit Function
    End If
    c = Array(-0.8457026848887617, 0.03739502393748032, _
              -0.00015333383280607642, 6.551063627525382E-07, _
              -2.4759314474490567E-09, 9.070213653911228E-12, _
              -3.681466540446358E-14, 1.1501679663496297E-16)
    lnP = 0#
    For k = 7 To 0 Step -1
        lnP = lnP * t + c(k)
    Next k
    PrefNH3Pure = 1000# * Exp(lnP)
End Function

' 纯氨饱和温度 [K]: 二分 80 次反解 PrefNH3Pure(T) = P_kPa;
' P 落在拟合辖区压力跨度 (约 6.4~11280 kPa) 之外时返回 Empty。
Private Function TsatNH3Pure(ByVal P_kPa As Double) As Variant
    Dim lo As Double, hi As Double, mid As Double, k As Long
    lo = 196.15: hi = 405.15
    If P_kPa < PrefNH3Pure(lo) Or P_kPa > PrefNH3Pure(hi) Then
        TsatNH3Pure = Empty: Exit Function
    End If
    For k = 1 To 80
        mid = 0.5 * (lo + hi)
        If PrefNH3Pure(mid) < P_kPa Then lo = mid Else hi = mid
    Next k
    TsatNH3Pure = 0.5 * (lo + hi)
End Function

' ---------- 由露点温度与溶液温度反解氨质量分数 x ----------
' 露点定压 P = PrefNH3Pure(Tdew_K) (纯氨饱和压, 口径见上);
' 再二分 80 次反解 Psol_TX_kPa(Tsol_K, x) = P (全程内部 kPa,
' 不经公开 MPa 边界), 括号取泡点函数有效
' 浓度域 x = 0.35-0.65。无根时返回 Empty (P 落在 Tsol 下泡点压力
' 跨度之外, 如溶液温度明显低于露点温度; 或 Tdew 超出纯氨 NIST
' 拟合辖区; 或 Tsol 越界)。与 C/Python 同算法; 未在真实 Excel 编译。
Public Function NL_XiByTsolTdew(ByVal Tsol_K As Double, ByVal Tdew_K As Double) As Variant
    Dim P As Variant, lo As Double, hi As Double, mid As Double, k As Long
    P = PrefNH3Pure(Tdew_K)
    If IsEmpty(P) Then
        NL_XiByTsolTdew = Empty: Exit Function
    End If
    If Not InRng(Tsol_K, 293.15, 353.15) Then
        NL_XiByTsolTdew = Empty: Exit Function
    End If
    If P < Psol_TX_kPa(Tsol_K, 0.35) Or P > Psol_TX_kPa(Tsol_K, 0.65) Then
        NL_XiByTsolTdew = Empty: Exit Function
    End If
    lo = 0.35: hi = 0.65
    For k = 1 To 80
        mid = 0.5 * (lo + hi)
        If Psol_TX_kPa(Tsol_K, mid) < P Then lo = mid Else hi = mid
    Next k
    NL_XiByTsolTdew = 0.5 * (lo + hi)
End Function


' ---------- 露点温度（溶液）[K]：全库 TdewByTsolXi 约定 ----------
' Tdew = TsatNH3Pure(Psol_TX_kPa(T_K, x))：以纯氨 NIST 拟合线
' （2026-10-12 换源，见上）评价溶液表面压力 Psol 所对应的饱和
' 温度（全程内部 kPa，不经公开 MPa 边界）。LiNO3 不挥发，
' 气相视为纯氨。Psol_TX_kPa 无解或 P 超出纯氨
' 拟合辖区压力跨度时返回 Empty。
Public Function NL_TdewByTsolX(ByVal T_K As Double, ByVal x As Double) As Variant
    Dim P As Variant, T As Variant
    P = Psol_TX_kPa(T_K, x)
    If IsEmpty(P) Then NL_TdewByTsolX = Empty: Exit Function
    T = TsatNH3Pure(P)
    If IsEmpty(T) Then NL_TdewByTsolX = Empty: Exit Function
    NL_TdewByTsolX = T
End Function

' ---------- 由溶液比焓反解溶液温度 [K] ----------
' NL_hsol 在固定 x 下随 T 单调增，在其辖区 T ∈ [273.15, 353.15] K
' 内二分 100 次反解。h 超出该 x 下 hsol 值域、或 x 超辖区
' （端点求值为 Empty）时返回 Empty。与 C/Python 同算法；
' 本函数未在真实 Excel 中编译运行。
Public Function NL_TsolByHsol(ByVal h As Double, ByVal x As Double) As Variant
    Dim hlo As Variant, hhi As Variant
    Dim lo As Double, hi As Double, mid As Double, k As Long
    hlo = NL_hsol(273.15, x): hhi = NL_hsol(353.15, x)
    If IsEmpty(hlo) Or IsEmpty(hhi) Then NL_TsolByHsol = Empty: Exit Function
    If h < hlo Or h > hhi Then NL_TsolByHsol = Empty: Exit Function
    lo = 273.15: hi = 353.15
    For k = 1 To 100
        mid = 0.5 * (lo + hi)
        If NL_hsol(mid, x) < h Then lo = mid Else hi = mid
    Next k
    NL_TsolByHsol = 0.5 * (lo + hi)
End Function

' ---------- 溶液比焓 [kJ/kg]: H = ha + hb T + hc T^2 ----------
Public Function NL_hsol(ByVal T_K As Double, ByVal x As Double) As Variant
    Dim cha As Variant, chb As Variant, chc As Variant
    If Not InRng(T_K, 273.15, 353.15) Or Not InRng(x, 0.35, 0.65) Then
        NL_hsol = CVErr(xlErrValue): Exit Function
    End If
    cha = Array(249.1567745, -1628.297463, -464.3464344, -105.6321057)
    chb = Array(2.481273559, -5.184392344, -0.775202139, 18.98142102)
    chc = Array(-0.004240786, 0.025111292, -0.013342843, -0.025956064)
    NL_hsol = Poly3(cha, x) + Poly3(chb, x) * T_K _
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

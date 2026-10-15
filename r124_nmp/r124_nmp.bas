Attribute VB_Name = "R124NMP"
' R124-NMP working pair: bubble pressure / bubble temperature (VLE only).
' Source: Xu, Wang, Wu, Hu & Jiang, J. Chem. Eng. Data 2017, 62, 3414-3422
' (five-parameter NRTL Eqs. 4-11, parameters Table 8; Antoine psat and VL
' fits to the paper's Table 5 REFPROP values).
' Conventions: T_C in degC, xi = R124 mass fraction, P in MPa
' (public boundary, 2026-10-14).  Internal native unit is bar:
' the Private *_Bar functions hold the original bodies; public
' functions only scale at the boundary (returned pressure
' MPa = bar x 0.1; input pressure MPa x 10 back to bar), so
' temperature/concentration outputs are unchanged.
' Validated range 30-90 degC; functions return Empty outside it.
' Verified vs the paper's 53 measured points: AARD 1.25 %.
' NOTE: this VBA has NOT been compiled/tested in real Excel.

Option Explicit

Private Function PrefBar_R124NMP(T_C As Double) As Double
    Dim T As Double
    T = T_C + 273.15
    PrefBar_R124NMP = Exp(14.750463 - 2527.6371 / (T - 10.9815)) / 100#
End Function

Public Function Pref_R124NMP(T_C As Double) As Double
    Pref_R124NMP = PrefBar_R124NMP(T_C) * 0.1
End Function

Private Function TsatR124Bar_R124NMP(P_bar As Double) As Variant
    If P_bar <= 0# Then
        TsatR124Bar_R124NMP = Empty
        Exit Function
    End If
    TsatR124Bar_R124NMP = 2527.6371 / (14.750463 - Log(P_bar * 100#)) + 10.9815 - 273.15
End Function

Public Function TsatR124_R124NMP(P_MPa As Double) As Variant
    If P_MPa <= 0# Then
        TsatR124_R124NMP = Empty
        Exit Function
    End If
    TsatR124_R124NMP = TsatR124Bar_R124NMP(P_MPa * 10#)
End Function

Private Function VL_R124NMP(T_C As Double) As Double   ' m3/mol
    VL_R124NMP = (0.00000343888821 * T_C * T_C + 0.00000521631071 * T_C + 0.0989804979) / 1000#
End Function

Public Function XiToX_R124NMP(xi As Double) As Double
    Dim n1 As Double
    n1 = xi / 136.5
    XiToX_R124NMP = n1 / (n1 + (1# - xi) / 99.13)
End Function

Public Function XToXi_R124NMP(x As Double) As Double
    Dim m1 As Double
    m1 = x * 136.5
    XToXi_R124NMP = m1 / (m1 + (1# - x) * 99.13)
End Function

Public Function Gamma1_R124NMP(T_C As Double, xi As Double) As Variant
    Dim T As Double, x1 As Double, x2 As Double, lnT As Double
    Dim t12 As Double, t21 As Double, G12 As Double, G21 As Double
    If T_C < 30# Or T_C > 90# Then
        Gamma1_R124NMP = Empty
        Exit Function
    End If
    T = T_C + 273.15
    x1 = XiToX_R124NMP(xi)
    x2 = 1# - x1
    If x1 <= 0# Then
        Gamma1_R124NMP = Empty
        Exit Function
    End If
    If x1 >= 1# Then
        Gamma1_R124NMP = 1#
        Exit Function
    End If
    lnT = Log(T)
    t12 = (242408# + (-46295.3) * lnT) / (8.314 * T)
    t21 = (-166747# + (30875.3) * lnT) / (8.314 * T)
    G12 = Exp(-(-0.0515) * t12)
    G21 = Exp(-(-0.0515) * t21)
    Gamma1_R124NMP = Exp(x2 * x2 * (t21 * (G21 / (x1 + x2 * G21)) ^ 2 _
                      + t12 * G12 / (x2 + x1 * G12) ^ 2))
End Function

Private Function PsolBar_R124NMP(T_C As Double, xi As Double) As Variant
    Dim T As Double, ps1 As Double, x1 As Double, g1 As Variant
    Dim vl As Double, p As Double, pn As Double, k As Long
    If T_C < 30# Or T_C > 90# Or xi <= 0# Or xi >= 1# Then
        PsolBar_R124NMP = Empty
        Exit Function
    End If
    T = T_C + 273.15
    ps1 = PrefBar_R124NMP(T_C)
    x1 = XiToX_R124NMP(xi)
    g1 = Gamma1_R124NMP(T_C, xi)
    vl = VL_R124NMP(T_C)
    p = ps1 * x1 * g1
    For k = 1 To 50
        pn = ps1 * x1 * g1 * Exp(vl * (p - ps1) * 100000# / (8.314 * T))
        If Abs(pn - p) < 0.0000000001 Then
            p = pn
            Exit For
        End If
        p = pn
    Next k
    PsolBar_R124NMP = p
End Function

Public Function Psol_R124NMP(T_C As Double, xi As Double) As Variant
    Dim Pv As Variant
    Pv = PsolBar_R124NMP(T_C, xi)
    If IsEmpty(Pv) Then
        Psol_R124NMP = Empty
    Else
        Psol_R124NMP = Pv * 0.1
    End If
End Function

Private Function BubbleTBar_R124NMP(P_bar As Double, xi As Double) As Variant
    Dim lo As Double, hi As Double, mid As Double, k As Long
    lo = 30#: hi = 90#
    If P_bar < PsolBar_R124NMP(lo, xi) Or P_bar > PsolBar_R124NMP(hi, xi) Then
        BubbleTBar_R124NMP = Empty
        Exit Function
    End If
    For k = 1 To 60
        mid = 0.5 * (lo + hi)
        If PsolBar_R124NMP(mid, xi) < P_bar Then lo = mid Else hi = mid
    Next k
    BubbleTBar_R124NMP = 0.5 * (lo + hi)
End Function

Public Function BubbleT_R124NMP(P_MPa As Double, xi As Double) As Variant
    BubbleT_R124NMP = BubbleTBar_R124NMP(P_MPa * 10#, xi)
End Function

' Concentration from dew-point temperature and solution temperature:
' the dew point fixes the pressure, P = PrefR124(Tdew) (NMP treated as
' non-volatile), then solve Psol(Tsol, xi) = P for xi by bisection.
' Psol is only defined on the open interval 0 < xi < 1; its limits
' there, 0 (xi -> 0) and PrefR124(Tsol) (xi -> 1), serve as the
' bracket - the bisection only ever evaluates interior points.
' Returns Empty if no root (e.g. Tsol below Tdew, or Tsol outside the
' validated 30-90 degC window).
' (Internal calls use the Private native bar functions, so the
' result is unchanged.)
Public Function XiByTsolTdew_R124NMP(Tsol_C As Double, Tdew_C As Double) As Variant
    Dim P As Double, lo As Double, hi As Double, mid As Double, k As Long
    If Tsol_C < 30# Or Tsol_C > 90# Then
        XiByTsolTdew_R124NMP = Empty
        Exit Function
    End If
    P = PrefBar_R124NMP(Tdew_C)
    If P > PrefBar_R124NMP(Tsol_C) Then
        XiByTsolTdew_R124NMP = Empty
        Exit Function
    End If
    lo = 0#: hi = 1#
    For k = 1 To 80
        mid = 0.5 * (lo + hi)
        If PsolBar_R124NMP(Tsol_C, mid) < P Then lo = mid Else hi = mid
    Next k
    XiByTsolTdew_R124NMP = 0.5 * (lo + hi)
End Function


' ---------- 露点温度（溶液）[°C]：全库 TdewByTsolXi 约定 ----------
' Tdew = DewT_R124NMP(Psol_R124NMP(T_C, xi))：以本模块自有纯 R124
' Antoine 线评价溶液表面压力 Psol 所对应的饱和温度。吸收剂视为
' 不挥发。Psol 无解（Empty）时返回 Empty。
' （内部走 Private 原生 bar 函数，结果不变。）
Public Function TdewByTsolXi_R124NMP(T_C As Double, xi As Double) As Variant
    Dim Pv As Variant
    Pv = PsolBar_R124NMP(T_C, xi)
    If IsEmpty(Pv) Then
        TdewByTsolXi_R124NMP = Empty
    Else
        TdewByTsolXi_R124NMP = DewTBar_R124NMP(Pv)
    End If
End Function

Private Function DewTBar_R124NMP(P_bar As Double) As Variant   ' absorbent non-volatile
    Dim T As Variant
    T = TsatR124Bar_R124NMP(P_bar)
    If IsEmpty(T) Or T < -30# Or T > 90# Then
        DewTBar_R124NMP = Empty
    Else
        DewTBar_R124NMP = T
    End If
End Function

Public Function DewT_R124NMP(P_MPa As Double) As Variant   ' absorbent non-volatile
    DewT_R124NMP = DewTBar_R124NMP(P_MPa * 10#)
End Function

Attribute VB_Name = "R124DMF"
' R124-DMF working pair: bubble pressure / bubble temperature (VLE only).
' Source: Xu, Wang, Wu, Hu & Jiang, J. Chem. Eng. Data 2017, 62, 3414-3422
' (five-parameter NRTL Eqs. 4-11, parameters Table 8; Antoine psat and VL
' fits to the paper's Table 5 REFPROP values).
' Conventions: T_C in degC, xi = R124 mass fraction, P in bar.
' Validated range 30-90 degC; functions return Empty outside it.
' Verified vs the paper's 60 measured points: AARD 1.17 %.
' NOTE: this VBA has NOT been compiled/tested in real Excel.

Option Explicit

Public Function R124DMF_PsatR124(T_C As Double) As Double
    Dim T As Double
    T = T_C + 273.15
    R124DMF_PsatR124 = Exp(14.750463 - 2527.6371 / (T - 10.9815)) / 100#
End Function

Public Function R124DMF_TsatR124(P_bar As Double) As Variant
    If P_bar <= 0# Then
        R124DMF_TsatR124 = Empty
        Exit Function
    End If
    R124DMF_TsatR124 = 2527.6371 / (14.750463 - Log(P_bar * 100#)) - 10.9815 - 273.15
End Function

Private Function R124DMF_VL(T_C As Double) As Double   ' m3/mol
    R124DMF_VL = (0.00000343888821 * T_C * T_C + 0.00000521631071 * T_C + 0.0989804979) / 1000#
End Function

Public Function R124DMF_XiToX(xi As Double) As Double
    Dim n1 As Double
    n1 = xi / 136.5
    R124DMF_XiToX = n1 / (n1 + (1# - xi) / 73.09)
End Function

Public Function R124DMF_XToXi(x As Double) As Double
    Dim m1 As Double
    m1 = x * 136.5
    R124DMF_XToXi = m1 / (m1 + (1# - x) * 73.09)
End Function

Public Function R124DMF_Gamma1(T_C As Double, xi As Double) As Variant
    Dim T As Double, x1 As Double, x2 As Double, lnT As Double
    Dim t12 As Double, t21 As Double, G12 As Double, G21 As Double
    If T_C < 30# Or T_C > 90# Then
        R124DMF_Gamma1 = Empty
        Exit Function
    End If
    T = T_C + 273.15
    x1 = R124DMF_XiToX(xi)
    x2 = 1# - x1
    If x1 <= 0# Then
        R124DMF_Gamma1 = Empty
        Exit Function
    End If
    If x1 >= 1# Then
        R124DMF_Gamma1 = 1#
        Exit Function
    End If
    lnT = Log(T)
    t12 = (-52406.6 + (4671.8) * lnT) / (8.314 * T)
    t21 = (-88324# + (14735.9) * lnT) / (8.314 * T)
    G12 = Exp(-(-0.5116) * t12)
    G21 = Exp(-(-0.5116) * t21)
    R124DMF_Gamma1 = Exp(x2 * x2 * (t21 * (G21 / (x1 + x2 * G21)) ^ 2 _
                      + t12 * G12 / (x2 + x1 * G12) ^ 2))
End Function

Public Function R124DMF_BubbleP(T_C As Double, xi As Double) As Variant
    Dim T As Double, ps1 As Double, x1 As Double, g1 As Variant
    Dim vl As Double, p As Double, pn As Double, k As Long
    If T_C < 30# Or T_C > 90# Or xi <= 0# Or xi >= 1# Then
        R124DMF_BubbleP = Empty
        Exit Function
    End If
    T = T_C + 273.15
    ps1 = R124DMF_PsatR124(T_C)
    x1 = R124DMF_XiToX(xi)
    g1 = R124DMF_Gamma1(T_C, xi)
    vl = R124DMF_VL(T_C)
    p = ps1 * x1 * g1
    For k = 1 To 50
        pn = ps1 * x1 * g1 * Exp(vl * (p - ps1) * 100000# / (8.314 * T))
        If Abs(pn - p) < 0.0000000001 Then
            p = pn
            Exit For
        End If
        p = pn
    Next k
    R124DMF_BubbleP = p
End Function

Public Function R124DMF_BubbleT(P_bar As Double, xi As Double) As Variant
    Dim lo As Double, hi As Double, mid As Double, k As Long
    lo = 30#: hi = 90#
    If P_bar < R124DMF_BubbleP(lo, xi) Or P_bar > R124DMF_BubbleP(hi, xi) Then
        R124DMF_BubbleT = Empty
        Exit Function
    End If
    For k = 1 To 60
        mid = 0.5 * (lo + hi)
        If R124DMF_BubbleP(mid, xi) < P_bar Then lo = mid Else hi = mid
    Next k
    R124DMF_BubbleT = 0.5 * (lo + hi)
End Function

Public Function R124DMF_DewT(P_bar As Double) As Variant   ' absorbent non-volatile
    Dim T As Variant
    T = R124DMF_TsatR124(P_bar)
    If IsEmpty(T) Or T < -30# Or T > 90# Then
        R124DMF_DewT = Empty
    Else
        R124DMF_DewT = T
    End If
End Function

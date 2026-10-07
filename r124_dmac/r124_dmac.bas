' R124-DMAC working pair: bubble pressure, solution enthalpy, density,
' viscosity. Transcribed from Borde, Jelinek & Daltrophe, Int. J.
' Refrigeration 20(4), 256-266, 1997.
'
' Conventions: T_C in degC, xi = R124 mass fraction, P in bar,
' h in kJ/kg (reference: pure liquids = 100 kJ/kg at 0 degC),
' rho in kg/m3, eta in mPa s.
'
' Two printed values are corrected on documented evidence (see the
' verification record in this folder): Table 9 rho_00 exponent
' (E+01 -> E+00) and Table 8 DMAC eta0/eta1 (x10 too large as printed).
' NOTE: Eq. (16) runs +13..+23 % above Eq. (15) at xi = 1 (property of
' the printed fit); use R124DMAC_PsatR124 near xi = 1.
' NOTE: this VBA has NOT been compiled/tested in real Excel.

Option Explicit

Private Function PsatEq15(A As Double, B As Double, C As Double, _
                          D As Double, E As Double, F As Double, _
                          T_C As Double) As Double
    Dim T As Double
    T = T_C + 273.15
    PsatEq15 = Exp(A + B / (T + C) + D * T + E * Log(T) + F * T * T)
End Function

Public Function R124DMAC_PsatR124(T_C As Double) As Double
    R124DMAC_PsatR124 = PsatEq15(-119.33446, -1351.341, 0#, -0.12497, 27.21197, 0.0000832656, T_C)
End Function

Public Function R124DMAC_PsatDMAC(T_C As Double) As Double
    R124DMAC_PsatDMAC = PsatEq15(6.01834, -1800.24, -138.5, 0#, 0#, 0#, T_C)
End Function

Public Function R124DMAC_DewT(P_bar As Double) As Variant
    Dim lo As Double, hi As Double, mid As Double, k As Long
    lo = -60#: hi = 120#
    If P_bar < R124DMAC_PsatR124(lo) Or P_bar > R124DMAC_PsatR124(hi) Then
        R124DMAC_DewT = Empty
        Exit Function
    End If
    For k = 1 To 80
        mid = 0.5 * (lo + hi)
        If R124DMAC_PsatR124(mid) < P_bar Then lo = mid Else hi = mid
    Next k
    R124DMAC_DewT = 0.5 * (lo + hi)
End Function

Private Function PCoef() As Variant
    PCoef = Array( _
        Array(0.011502, -28.24, 41.188, -26.168, 0#, 183.81, -311.9, 139.14), _
        Array(-0.013711, 0.24179, -0.26951, 0#, 0#, 0.075999, 0#, 0#), _
        Array(0.000091911, 0#, 0#, 0#, 0#, 0#, 0#, 0#), _
        Array(0#, -0.0000031564, 0.00000092677, 0.0000078191, -0.00001331, 0#, 0.000012701, -0.0000065958), _
        Array(-8.6519E-10, 0#, 0#, 0#, 0#, 0#, 0#, 0#), _
        Array(0#, 2.2998E-11, 0#, 0#, 0#, 3.3233E-11, 0#, -2.4081E-11), _
        Array(5.9436E-15, 0#, -6.831E-14, 0#, -1.7145E-14, 0#, 0#, 0#), _
        Array(-6.7036E-18, -5.344E-17, 1.414E-16, -9.4881E-17, 0#, 5.6692E-16, -1.0014E-15, 5.334E-16))
End Function

Public Function R124DMAC_BubbleP(T_C As Double, xi As Double) As Double
    Dim pc As Variant, T As Double, s As Double, row As Double
    Dim i As Long, j As Long
    pc = PCoef()
    T = T_C + 273.15
    s = 0#
    For j = 0 To 7
        row = 0#
        For i = 0 To 7
            row = row + pc(j)(i) * xi ^ i
        Next i
        s = s + row * T ^ j
    Next j
    R124DMAC_BubbleP = s
End Function

Public Function R124DMAC_BubbleT(P_bar As Double, xi As Double) As Variant
    Dim lo As Double, hi As Double, mid As Double, k As Long
    lo = 0#: hi = 150#
    If P_bar < R124DMAC_BubbleP(lo, xi) Or P_bar > R124DMAC_BubbleP(hi, xi) Then
        R124DMAC_BubbleT = Empty
        Exit Function
    End If
    For k = 1 To 80
        mid = 0.5 * (lo + hi)
        If R124DMAC_BubbleP(mid, xi) < P_bar Then lo = mid Else hi = mid
    Next k
    R124DMAC_BubbleT = 0.5 * (lo + hi)
End Function

Private Function HCoef() As Variant
    HCoef = Array( _
        Array(-34.981, -184.79, 273.1, -22.155, 0#, -49.058, 6.1147, 1.6635), _
        Array(0.31418, 0.59584, -0.90572, 0#, 0#, 0.16399, 0#, 0#), _
        Array(-0.00080917, 0#, 0#, 0.0000114, 0#, 0#, 0#, 0#), _
        Array(0#, 3.2184E-08, 0#, 0#, 0.0000014107, 0#, 7.4883E-07, -1.0444E-06), _
        Array(1.7947E-09, 0#, 0#, 0#, 0#, 0#, 0#, 0#), _
        Array(0#, -1.186E-11, 1.8271E-11, 0#, 0#, -2.281E-11, 0#, 1.0914E-11), _
        Array(0#, 0#, 0#, 0#, 0#, 0#, 0#, 0#), _
        Array(-4.3652E-18, 3.4001E-17, -5.0197E-17, -1.008E-17, 0#, 6.78E-17, 0#, -3.1527E-17))
End Function

Public Function R124DMAC_HExcess(T_C As Double, xi As Double) As Double
    Dim hc As Variant, T As Double, x As Double, s As Double, row As Double
    Dim nr As Double, na As Double, i As Long, j As Long
    hc = HCoef()
    T = T_C + 273.15
    nr = xi / 136.5
    na = (1# - xi) / 87.12
    x = nr / (nr + na)
    s = 0#
    For j = 0 To 7
        row = 0#
        For i = 0 To 7
            row = row + hc(j)(i) * x ^ i
        Next i
        s = s + row * T ^ j
    Next j
    R124DMAC_HExcess = 4.1868 * s
End Function

Public Function R124DMAC_Ha(T_C As Double) As Double
    R124DMAC_Ha = 100# + 4.1868 * (0.4578 * T_C + 0.5 * 0.000839 * T_C ^ 2)
End Function

Public Function R124DMAC_Hr(T_C As Double) As Double
    Dim hr As Variant, s As Double, i As Long
    hr = Array(0.250767, 0.000347753, 0.00000100977, 3.42458E-09, 0#, 0#, 6.99612E-15)
    s = 0#
    For i = 1 To 7
        s = s + hr(i - 1) * T_C ^ i
    Next i
    R124DMAC_Hr = 100# + 4.1868 * s
End Function

Public Function R124DMAC_Hsol(T_C As Double, xi As Double) As Double
    R124DMAC_Hsol = R124DMAC_Hr(T_C) * xi + R124DMAC_Ha(T_C) * (1# - xi) _
                  + R124DMAC_HExcess(T_C, xi)
End Function

Public Function R124DMAC_RhoR124(T_C As Double) As Double
    R124DMAC_RhoR124 = 1000# * (1.466 - 0.003394 * T_C - 0.0000016063 * T_C ^ 2 _
                                - 2.004E-07 * T_C ^ 3)
End Function

Public Function R124DMAC_RhoDMAC(T_C As Double) As Double
    R124DMAC_RhoDMAC = 1000# * (0.9528 - 0.0005856 * T_C - 0.0000033632 * T_C ^ 2)
End Function

Private Function RCoef() As Variant
    RCoef = Array( _
        Array(0.95521, 0.43672, -0.2816, 0.3561), _
        Array(-0.00015533, -0.00037079, 0#, -0.002923), _
        Array(-0.000013981, 0#, 0.00001355, 0#), _
        Array(6.0941E-08, -9.7547E-08, 3.3531E-07, -5.0554E-07))
End Function

Public Function R124DMAC_RhoMix(T_C As Double, xi As Double) As Double
    Dim rc As Variant, s As Double, row As Double, i As Long, j As Long
    rc = RCoef()
    s = 0#
    For j = 0 To 3
        row = 0#
        For i = 0 To 3
            row = row + rc(j)(i) * xi ^ i
        Next i
        s = s + row * T_C ^ j
    Next j
    R124DMAC_RhoMix = 1000# * s
End Function

Public Function R124DMAC_EtaR124(T_C As Double) As Double
    Dim T As Double
    T = T_C + 273.15
    R124DMAC_EtaR124 = Exp(-8.9301 + 5094.9 / (T + 357.4))
End Function

Public Function R124DMAC_EtaDMAC(T_C As Double) As Double
    ' Corrected coefficients; printed Table 8 values are x10 (see notes).
    Dim T As Double
    T = T_C + 273.15
    R124DMAC_EtaDMAC = Exp(-1.684 + 134.88 / (T - 223.2))
End Function

Private Function ECoef() As Variant
    ECoef = Array( _
        Array(7.6992, 0.60007, -8.9875, -1.7031), _
        Array(-6769.2, 0#, 4555.4, 0#), _
        Array(1343400#, 0#, 0#, 0#), _
        Array(0#, -64446000#, 0#, -106310000#))
End Function

Public Function R124DMAC_EtaMix(T_C As Double, xi As Double) As Double
    Dim ec As Variant, T As Double, s As Double, row As Double
    Dim i As Long, j As Long
    ec = ECoef()
    T = T_C + 273.15
    s = 0#
    For j = 0 To 3
        row = 0#
        For i = 0 To 3
            row = row + ec(j)(i) * xi ^ i
        Next i
        If j = 0 Then
            s = s + row
        Else
            s = s + row * T ^ (-j)
        End If
    Next j
    R124DMAC_EtaMix = Exp(s)
End Function

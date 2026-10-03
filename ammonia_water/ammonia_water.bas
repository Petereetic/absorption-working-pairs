Attribute VB_Name = "AmmoniaWater"
' =====================================================================
'  Ammonia-water mixture: Patek & Klomfar (1995) fast explicit correlations
'  Reference: J. Patek, J. Klomfar, Int. J. Refrigeration 18(4), 228-234, 1995.
'
'  x : ammonia MOLE fraction, liquid phase     y : ammonia MOLE fraction, gas phase
'  p : MPa   T : K   h : kJ/kg
'
'  AW_Tbub_P(p, x)  Eq(6) bubble-point T [K]    0.002<=p<=2 MPa
'  AW_Tdew_P(p, y)  Eq(7) dew-point T [K]       0.02<=p<=2 MPa
'  AW_Yeq(p, x)     Eq(8) equilibrium vapour mole fraction, x>0.05 (mole)
'  AW_Hliq(T, x)    Eq(9) saturated-liquid enthalpy [kJ/kg]
'  AW_Hvap(T, y)    Eq(10) vapour enthalpy [kJ/kg]
'  AW_Glide(p, z)   true glide [K] = T_dew(p,z)-T_bubble(p,z)
'  AW_Xi2X(xi)      NH3 mass fraction -> mole fraction
'  AW_X2Xi(x)       NH3 mole fraction -> mass fraction
'
'  Reference state: h = 0 for liquid water at the triple point (both components).
'  Unlike DMF/DEGDME pairs both components are volatile: the dew curve is the
'  true mixture dew curve Eq(7), and the generator needs a rectifier.
'
'  NOTE: coefficients transcribed from the paper's Tables 1-5 and verified
'  against pure-component limits in Python (see verify_transcription.py).
'  This VBA module has NOT been compiled/run in real Excel.
' =====================================================================
Option Explicit

Private Const T0_67 As Double = 100#
Private Const P0 As Double = 2#
Private Const H0_9 As Double = 100#
Private Const T0_9 As Double = 273.16
Private Const H0_10 As Double = 1000#
Private Const T0_10 As Double = 324#
Private Const M_NH3 As Double = 17.03052
Private Const M_H2O As Double = 18.01528

' Eq(6) coefficients: (m, n, a)
Private Function C6(ByVal i As Long, ByVal k As Long) As Double
    Dim m(1 To 14) As Long, n(1 To 14) As Long, a(1 To 14) As Double
    m(1) = 0: n(1) = 0: a(1) = 3.22302
    m(2) = 0: n(2) = 1: a(2) = -0.384206
    m(3) = 0: n(3) = 2: a(3) = 0.0460965
    m(4) = 0: n(4) = 3: a(4) = -0.00378945
    m(5) = 0: n(5) = 4: a(5) = 0.00013561
    m(6) = 1: n(6) = 0: a(6) = 0.487755
    m(7) = 1: n(7) = 1: a(7) = -0.120108
    m(8) = 1: n(8) = 2: a(8) = 0.0106154
    m(9) = 2: n(9) = 3: a(9) = -0.000533589
    m(10) = 4: n(10) = 0: a(10) = 7.85041
    m(11) = 5: n(11) = 0: a(11) = -11.5941
    m(12) = 5: n(12) = 1: a(12) = -0.052315
    m(13) = 6: n(13) = 0: a(13) = 4.89596
    m(14) = 13: n(14) = 1: a(14) = 0.0421059
    If k = 0 Then C6 = m(i) Else If k = 1 Then C6 = n(i) Else C6 = a(i)
End Function

' Eq(7) coefficients
Private Function C7(ByVal i As Long, ByVal k As Long) As Double
    Dim m(1 To 17) As Long, n(1 To 17) As Long, a(1 To 17) As Double
    m(1) = 0: n(1) = 0: a(1) = 3.24004
    m(2) = 0: n(2) = 1: a(2) = -0.39592
    m(3) = 0: n(3) = 2: a(3) = 0.0435624
    m(4) = 0: n(4) = 3: a(4) = -0.00218943
    m(5) = 1: n(5) = 0: a(5) = -1.43526
    m(6) = 1: n(6) = 1: a(6) = 1.05256
    m(7) = 1: n(7) = 2: a(7) = -0.0719281
    m(8) = 2: n(8) = 0: a(8) = 12.2362
    m(9) = 2: n(9) = 1: a(9) = -2.24368
    m(10) = 3: n(10) = 0: a(10) = -20.178
    m(11) = 3: n(11) = 1: a(11) = 1.10834
    m(12) = 4: n(12) = 0: a(12) = 14.5399
    m(13) = 4: n(13) = 2: a(13) = 0.644312
    m(14) = 5: n(14) = 0: a(14) = -2.21246
    m(15) = 5: n(15) = 2: a(15) = -0.756266
    m(16) = 6: n(16) = 0: a(16) = -1.35529
    m(17) = 7: n(17) = 2: a(17) = 0.183541
    If k = 0 Then C7 = m(i) Else If k = 1 Then C7 = n(i) Else C7 = a(i)
End Function

' Eq(8) coefficients
Private Function C8(ByVal i As Long, ByVal k As Long) As Double
    Dim m(1 To 14) As Long, n(1 To 14) As Long, a(1 To 14) As Double
    m(1) = 0: n(1) = 0: a(1) = 19.8022017
    m(2) = 0: n(2) = 1: a(2) = -11.8092669
    m(3) = 0: n(3) = 6: a(3) = 27.747998
    m(4) = 0: n(4) = 7: a(4) = -28.8634277
    m(5) = 1: n(5) = 0: a(5) = -59.1616608
    m(6) = 2: n(6) = 1: a(6) = 578.091305
    m(7) = 2: n(7) = 2: a(7) = -6.21736743
    m(8) = 3: n(8) = 2: a(8) = -3421.98402
    m(9) = 4: n(9) = 3: a(9) = 11940.3127
    m(10) = 5: n(10) = 4: a(10) = -24541.3777
    m(11) = 6: n(11) = 5: a(11) = 29159.1865
    m(12) = 7: n(12) = 6: a(12) = -18478.229
    m(13) = 7: n(13) = 7: a(13) = 23.4819434
    m(14) = 8: n(14) = 7: a(14) = 4803.10617
    If k = 0 Then C8 = m(i) Else If k = 1 Then C8 = n(i) Else C8 = a(i)
End Function

' Eq(9) coefficients
Private Function C9(ByVal i As Long, ByVal k As Long) As Double
    Dim m(1 To 16) As Long, n(1 To 16) As Long, a(1 To 16) As Double
    m(1) = 0: n(1) = 1: a(1) = -7.6108
    m(2) = 0: n(2) = 4: a(2) = 25.6905
    m(3) = 0: n(3) = 8: a(3) = -247.092
    m(4) = 0: n(4) = 9: a(4) = 325.952
    m(5) = 0: n(5) = 12: a(5) = -158.854
    m(6) = 0: n(6) = 14: a(6) = 61.9084
    m(7) = 1: n(7) = 0: a(7) = 11.4314
    m(8) = 1: n(8) = 1: a(8) = 1.18157
    m(9) = 2: n(9) = 1: a(9) = 2.84179
    m(10) = 3: n(10) = 3: a(10) = 7.41609
    m(11) = 5: n(11) = 3: a(11) = 891.844
    m(12) = 5: n(12) = 4: a(12) = -1613.09
    m(13) = 5: n(13) = 5: a(13) = 622.106
    m(14) = 6: n(14) = 2: a(14) = -207.588
    m(15) = 6: n(15) = 4: a(15) = -6.87393
    m(16) = 8: n(16) = 0: a(16) = 3.50716
    If k = 0 Then C9 = m(i) Else If k = 1 Then C9 = n(i) Else C9 = a(i)
End Function

' Eq(10) coefficients
Private Function C10(ByVal i As Long, ByVal k As Long) As Double
    Dim m(1 To 17) As Long, n(1 To 17) As Long, a(1 To 17) As Double
    m(1) = 0: n(1) = 0: a(1) = 1.28827
    m(2) = 1: n(2) = 0: a(2) = 0.125247
    m(3) = 2: n(3) = 0: a(3) = -2.08748
    m(4) = 3: n(4) = 0: a(4) = 2.17696
    m(5) = 0: n(5) = 2: a(5) = 2.35687
    m(6) = 1: n(6) = 2: a(6) = -8.86987
    m(7) = 2: n(7) = 2: a(7) = 10.2635
    m(8) = 3: n(8) = 2: a(8) = -2.3744
    m(9) = 0: n(9) = 3: a(9) = -6.70515
    m(10) = 1: n(10) = 3: a(10) = 16.4508
    m(11) = 2: n(11) = 3: a(11) = -9.36849
    m(12) = 0: n(12) = 4: a(12) = 8.42254
    m(13) = 1: n(13) = 4: a(13) = -8.58807
    m(14) = 0: n(14) = 5: a(14) = -2.77049
    m(15) = 4: n(15) = 6: a(15) = -0.961248
    m(16) = 2: n(16) = 7: a(16) = 0.988009
    m(17) = 1: n(17) = 10: a(17) = 0.308482
    If k = 0 Then C10 = m(i) Else If k = 1 Then C10 = n(i) Else C10 = a(i)
End Function

Public Function AW_Tbub_P(ByVal p_MPa As Double, ByVal x As Double) As Double
    Dim L As Double, omx As Double, s As Double, i As Long
    L = Log(P0 / p_MPa): omx = 1# - x: s = 0#
    For i = 1 To 14
        s = s + C6(i, 2) * omx ^ C6(i, 0) * L ^ C6(i, 1)
    Next i
    AW_Tbub_P = T0_67 * s
End Function

Public Function AW_Tdew_P(ByVal p_MPa As Double, ByVal y As Double) As Double
    Dim L As Double, omy As Double, s As Double, i As Long
    L = Log(P0 / p_MPa): omy = 1# - y: s = 0#
    If omy < 0# Then omy = 0#
    For i = 1 To 17
        s = s + C7(i, 2) * omy ^ (C7(i, 0) / 4#) * L ^ C7(i, 1)
    Next i
    AW_Tdew_P = T0_67 * s
End Function

Public Function AW_Yeq(ByVal p_MPa As Double, ByVal x As Double) As Double
    Dim pr As Double, s As Double, i As Long
    If x >= 1# Then AW_Yeq = 1#: Exit Function
    If x <= 0# Then AW_Yeq = 0#: Exit Function
    pr = p_MPa / P0: s = 0#
    For i = 1 To 14
        s = s + C8(i, 2) * pr ^ C8(i, 0) * x ^ (C8(i, 1) / 3#)
    Next i
    AW_Yeq = 1# - Exp(Log(1# - x) * s)
End Function

Public Function AW_Hliq(ByVal T_K As Double, ByVal x As Double) As Double
    Dim u As Double, s As Double, i As Long
    u = T_K / T0_9 - 1#: s = 0#
    For i = 1 To 16
        s = s + C9(i, 2) * u ^ C9(i, 0) * x ^ C9(i, 1)
    Next i
    AW_Hliq = H0_9 * s
End Function

Public Function AW_Hvap(ByVal T_K As Double, ByVal y As Double) As Double
    Dim v As Double, omy As Double, s As Double, i As Long
    v = 1# - T0_10 / T_K: omy = 1# - y: s = 0#
    If omy < 0# Then omy = 0#
    For i = 1 To 17
        s = s + C10(i, 2) * v ^ C10(i, 0) * omy ^ (C10(i, 1) / 4#)
    Next i
    AW_Hvap = H0_10 * s
End Function

Public Function AW_Glide(ByVal p_MPa As Double, ByVal z As Double) As Double
    AW_Glide = AW_Tdew_P(p_MPa, z) - AW_Tbub_P(p_MPa, z)
End Function

Public Function AW_Pbub_T(ByVal T_K As Double, ByVal x As Double) As Double
    Dim p_lo As Double, p_hi As Double, flo As Double, fm As Double, pm As Double, k As Long
    p_lo = 0.002: p_hi = 2#: flo = AW_Tbub_P(p_lo, x) - T_K
    For k = 1 To 200
        pm = 0.5 * (p_lo + p_hi): fm = AW_Tbub_P(pm, x) - T_K
        If fm = 0# Or (p_hi - p_lo) < 0.000000001 * IIf(pm > 1#, pm, 1#) Then AW_Pbub_T = pm: Exit Function
        If (fm > 0#) = (flo > 0#) Then p_lo = pm: flo = fm Else p_hi = pm
    Next k
    AW_Pbub_T = 0.5 * (p_lo + p_hi)
End Function

Public Function AW_Pdew_T(ByVal T_K As Double, ByVal y As Double) As Double
    Dim p_lo As Double, p_hi As Double, flo As Double, fm As Double, pm As Double, k As Long
    p_lo = 0.02: p_hi = 2#: flo = AW_Tdew_P(p_lo, y) - T_K
    For k = 1 To 200
        pm = 0.5 * (p_lo + p_hi): fm = AW_Tdew_P(pm, y) - T_K
        If fm = 0# Or (p_hi - p_lo) < 0.000000001 * IIf(pm > 1#, pm, 1#) Then AW_Pdew_T = pm: Exit Function
        If (fm > 0#) = (flo > 0#) Then p_lo = pm: flo = fm Else p_hi = pm
    Next k
    AW_Pdew_T = 0.5 * (p_lo + p_hi)
End Function

Public Function AW_Xi2X(ByVal xi As Double) As Double
    AW_Xi2X = (xi / M_NH3) / (xi / M_NH3 + (1# - xi) / M_H2O)
End Function

Public Function AW_X2Xi(ByVal x As Double) As Double
    AW_X2Xi = x * M_NH3 / (x * M_NH3 + (1# - x) * M_H2O)
End Function

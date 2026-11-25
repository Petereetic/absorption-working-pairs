Attribute VB_Name = "H2OLiCl"
' ==========================================================================
' H2O-LiCl working pair: properties of aqueous lithium chloride (VBA)
' ==========================================================================
' Source: Conde-Petit, M. R., Int. J. Thermal Sciences 43 (2004)
' 367-382, LiCl branch only (the CaCl2 branch of the same paper
' lives in the sibling H2OCaCl2 module).
' Line-by-line port of h2o_licl.py (Python reference) in the same
' directory; C version h2o_licl.c is identical in algorithm and was
' cross-checked against Python at 371 points (max rel. diff. 3e-16).
'
' This .bas is verified in real Excel as part of the bas.xlsm
' build (see the bas repo devnotes).
'
' Dilution enthalpy (Sec.8): theta = theta_r = T_K / 647.096 per
' the paper's Nomenclature default and the dossier Sec.8 ruling of
' 2026-11-19.  This module originally used theta_s (T_K/228 - 1)
' in DhD; changed to theta_r on 2026-11-24 by Peter's order.  The
' Sato theta_s applies only to the Sec.7 cp section (CpF2).
'
' Conventions: xi = LiCl mass fraction (e.g. 0.3), T in degC,
' P in MPa, h kJ/kg, rho kg/m3, eta Pa s, sigma N/m,
' lambda W/(m K), cp kJ/(kg K), dh_d kJ/kg_H2O.
' Out of range: functions return Empty.
'
' Enthalpy datum (hsol): hsol(0 degC, xi=0) = 0 (pure liquid water
' at 0 degC); hsol(T, xi) = integral of cp_sol from 0 degC plus the
' 25 degC excess term H2OLiCl_HmixExcess(xi) built from the
' differential dilution enthalpy.  Use enthalpy differences within
' this module only.  See the formula notes for the full statement.
' ==========================================================================
Option Explicit

Private Const HL_TC As Double = 647.096
Private Const HL_PC As Double = 22.064

Private Function CpWTab() As Variant
    CpWTab = Array(4.217, 4.192, 4.182, 4.178, 4.178, 4.179, 4.181, 4.186, _
                   4.193, 4.204, 4.216, 4.229, 4.242, 4.254, 4.267, 4.281)
End Function

Private Function LamWTab() As Variant
    LamWTab = Array(0.561, 0.58, 0.598, 0.615, 0.631, 0.644, 0.654, 0.663, _
                    0.67, 0.676, 0.679, 0.683, 0.685, 0.686, 0.685, 0.683)
End Function

' NOTE: the table parameter is named tbl, not tab. A parameter named
' tab breaks compilation in Excel VBA (Tab is a built-in function
' name; the compiler then reports this function as not defined).
' Found by real-Excel test, 2026-11-24.
Private Function TabInterp(ByRef tbl As Variant, ByVal T_C As Double) As Double
    Dim i As Integer, f As Double
    If T_C <= 0# Then TabInterp = tbl(0): Exit Function
    If T_C >= 150# Then TabInterp = tbl(15): Exit Function
    i = Int(T_C / 10#)
    f = (T_C - 10# * i) / 10#
    TabInterp = tbl(i) * (1# - f) + tbl(i + 1) * f
End Function

' ---------- Pure water ----------
Public Function H2OLiCl_PrefWater(ByVal T_C As Double) As Variant
    Dim T As Double, tau As Double, s As Double
    If T_C < -50# Or T_C > 300# Then H2OLiCl_PrefWater = Empty: Exit Function
    T = T_C + 273.15
    tau = 1# - T / HL_TC
    s = -7.85823 * tau + 1.83991 * tau ^ 1.5 - 11.7811 * tau ^ 3 _
        + 22.6705 * tau ^ 3.5 - 15.9393 * tau ^ 4 + 1.77516 * tau ^ 7.5
    H2OLiCl_PrefWater = HL_PC * Exp(s / (1# - tau))
End Function

Public Function H2OLiCl_TsatWater(ByVal P_MPa As Double) As Variant
    Dim lo As Double, hi As Double, mid As Double, k As Long
    If P_MPa <= 0# Then H2OLiCl_TsatWater = Empty: Exit Function
    If P_MPa < H2OLiCl_PrefWater(-50#) Or P_MPa > H2OLiCl_PrefWater(300#) Then
        H2OLiCl_TsatWater = Empty: Exit Function
    End If
    lo = -50#: hi = 300#
    For k = 1 To 100
        mid = 0.5 * (lo + hi)
        If H2OLiCl_PrefWater(mid) < P_MPa Then lo = mid Else hi = mid
    Next k
    H2OLiCl_TsatWater = 0.5 * (lo + hi)
End Function

Public Function H2OLiCl_RhoWater(ByVal T_C As Double) As Variant
    Dim tau As Double
    If T_C < -40# Or T_C > 150# Then H2OLiCl_RhoWater = Empty: Exit Function
    tau = 1# - (T_C + 273.15) / HL_TC
    H2OLiCl_RhoWater = 322# * (1# + 1.993771843 * tau ^ (1# / 3#) _
        + 1.0985211604 * tau ^ (2# / 3#) - 0.5094492996 * tau ^ (5# / 3#) _
        - 1.761912427 * tau ^ (16# / 3#) - 44.9005480267 * tau ^ (43# / 3#) _
        - 723692.2618632 * tau ^ (110# / 3#))
End Function

Public Function H2OLiCl_CpWater(ByVal T_C As Double) As Variant
    If T_C < 0# Or T_C > 150# Then H2OLiCl_CpWater = Empty: Exit Function
    H2OLiCl_CpWater = TabInterp(CpWTab(), T_C)
End Function

Public Function H2OLiCl_SigmaWater(ByVal T_C As Double) As Variant
    Dim th As Double
    If T_C < -40# Or T_C > 150# Then H2OLiCl_SigmaWater = Empty: Exit Function
    th = (T_C + 273.15) / HL_TC
    H2OLiCl_SigmaWater = 0.2358 * (1# - 0.625 * (1# - th)) * (1# - th) ^ 1.256
End Function

Public Function H2OLiCl_EtaWater(ByVal T_C As Double) As Variant
    If T_C < 0# Or T_C > 150# Then H2OLiCl_EtaWater = Empty: Exit Function
    H2OLiCl_EtaWater = 0.00002414 * 10# ^ (247.8 / (T_C + 273.15 - 140#))
End Function

Public Function H2OLiCl_LambdaWater(ByVal T_C As Double) As Variant
    Dim th As Double
    If T_C < -20# Or T_C > 150# Then H2OLiCl_LambdaWater = Empty: Exit Function
    If T_C >= 20# Then
        H2OLiCl_LambdaWater = TabInterp(LamWTab(), T_C)
    Else
        th = (T_C + 273.15) / HL_TC
        H2OLiCl_LambdaWater = TabInterp(LamWTab(), 20#) * (0.208496 + 1.747278 * th)
    End If
End Function

' ---------- Vapour pressure (paper Sec.1) ----------
Public Function H2OLiCl_PiFactor(ByVal xi As Double, ByVal T_C As Double) As Variant
    Dim th As Double, A As Double, B As Double, pi25 As Double
    If xi < 0# Or xi > 0.56 Or T_C < -40# Or T_C > 150# Then
        H2OLiCl_PiFactor = Empty: Exit Function
    End If
    th = (T_C + 273.15) / HL_TC
    A = 2# - (1# + (xi / 0.28) ^ 4.3) ^ 0.6
    B = (1# + (xi / 0.21) ^ 5.1) ^ 0.49 - 1#
    If xi = 0# Then
        pi25 = 1# - 0.03 * Exp(-0.01 / 0.005)
    Else
        pi25 = 1# - (1# + (xi / 0.362) ^ (-4.75)) ^ (-0.4) _
               - 0.03 * Exp(-((xi - 0.1) ^ 2) / 0.005)
    End If
    H2OLiCl_PiFactor = pi25 * (A + B * th)
End Function

Public Function H2OLiCl_Psol(ByVal T_C As Double, ByVal xi As Double) As Variant
    Dim pi As Variant
    pi = H2OLiCl_PiFactor(xi, T_C)
    If IsEmpty(pi) Then H2OLiCl_Psol = Empty: Exit Function
    H2OLiCl_Psol = pi * H2OLiCl_PrefWater(T_C)
End Function

Public Function H2OLiCl_BubbleT(ByVal P_MPa As Double, ByVal xi As Double) As Variant
    Dim lo As Double, hi As Double, mid As Double, k As Long
    Dim plo As Variant, phi As Variant
    lo = -40#: hi = 150#
    plo = H2OLiCl_Psol(lo, xi): phi = H2OLiCl_Psol(hi, xi)
    If IsEmpty(plo) Or IsEmpty(phi) Then H2OLiCl_BubbleT = Empty: Exit Function
    If P_MPa < plo Or P_MPa > phi Then H2OLiCl_BubbleT = Empty: Exit Function
    For k = 1 To 80
        mid = 0.5 * (lo + hi)
        If H2OLiCl_Psol(mid, xi) < P_MPa Then lo = mid Else hi = mid
    Next k
    H2OLiCl_BubbleT = 0.5 * (lo + hi)
End Function

Public Function H2OLiCl_TdewByTsolXi(ByVal T_C As Double, ByVal xi As Double) As Variant
    Dim P As Variant
    P = H2OLiCl_Psol(T_C, xi)
    If IsEmpty(P) Then H2OLiCl_TdewByTsolXi = Empty: Exit Function
    H2OLiCl_TdewByTsolXi = H2OLiCl_TsatWater(P)
End Function

Public Function H2OLiCl_XiByTsolTdew(ByVal Tsol_C As Double, ByVal Tdew_C As Double) As Variant
    Dim P As Variant, pmax As Variant, pmin As Variant
    Dim lo As Double, hi As Double, mid As Double, k As Long
    If Tsol_C < -40# Or Tsol_C > 150# Then H2OLiCl_XiByTsolTdew = Empty: Exit Function
    P = H2OLiCl_PrefWater(Tdew_C)
    If IsEmpty(P) Then H2OLiCl_XiByTsolTdew = Empty: Exit Function
    pmax = H2OLiCl_Psol(Tsol_C, 0#): pmin = H2OLiCl_Psol(Tsol_C, 0.56)
    If IsEmpty(pmax) Or IsEmpty(pmin) Then H2OLiCl_XiByTsolTdew = Empty: Exit Function
    If P < pmin Or P > pmax Then H2OLiCl_XiByTsolTdew = Empty: Exit Function
    lo = 0#: hi = 0.56
    For k = 1 To 80
        mid = 0.5 * (lo + hi)
        If H2OLiCl_Psol(Tsol_C, mid) > P Then lo = mid Else hi = mid
    Next k
    H2OLiCl_XiByTsolTdew = 0.5 * (lo + hi)
End Function

' ---------- Density / surface tension / viscosity / conductivity / cp ----------
Public Function H2OLiCl_RhoSol(ByVal T_C As Double, ByVal xi As Double) As Variant
    Dim rw As Variant, z As Double
    If xi < 0# Or xi > 0.56 Or T_C < -40# Or T_C > 150# Then
        H2OLiCl_RhoSol = Empty: Exit Function
    End If
    rw = H2OLiCl_RhoWater(T_C)
    If IsEmpty(rw) Then H2OLiCl_RhoSol = Empty: Exit Function
    z = xi / (1# - xi)
    H2OLiCl_RhoSol = rw * (1# + 0.540966 * z - 0.303792 * z ^ 2 + 0.100791 * z ^ 3)
End Function

Public Function H2OLiCl_SigmaSol(ByVal T_C As Double, ByVal xi As Double) As Variant
    Dim sw As Variant, th As Double
    If xi < 0# Or xi > 0.56 Or T_C < -40# Or T_C > 150# Then
        H2OLiCl_SigmaSol = Empty: Exit Function
    End If
    sw = H2OLiCl_SigmaWater(T_C)
    If IsEmpty(sw) Then H2OLiCl_SigmaSol = Empty: Exit Function
    th = (T_C + 273.15) / HL_TC
    H2OLiCl_SigmaSol = sw * (1# + 2.757115 * xi - 12.011299 * xi * th _
        + 14.751818 * xi * th ^ 2 + 2.443204 * xi ^ 2 - 3.147739 * xi ^ 3)
End Function

Public Function H2OLiCl_EtaSol(ByVal T_C As Double, ByVal xi As Double) As Variant
    Dim ew As Variant, th As Double, zeta As Double
    If xi < 0# Or xi > 0.56 Or T_C < 0# Or T_C > 150# Then
        H2OLiCl_EtaSol = Empty: Exit Function
    End If
    ew = H2OLiCl_EtaWater(T_C)
    If IsEmpty(ew) Then H2OLiCl_EtaSol = Empty: Exit Function
    th = (T_C + 273.15) / HL_TC
    zeta = xi / (1# - xi) ^ (1# / 0.6)
    H2OLiCl_EtaSol = ew * Exp(0.090481 * zeta ^ 3.6 + 1.390262 * zeta _
        + 0.675875 * zeta / th - 0.583517 * zeta ^ 2)
End Function

Public Function H2OLiCl_LambdaSol(ByVal T_C As Double, ByVal xi As Double) As Variant
    Dim lw As Variant, rs As Variant, zetaEq As Double
    If xi < 0# Or xi > 0.56 Or T_C < -20# Or T_C > 150# Then
        H2OLiCl_LambdaSol = Empty: Exit Function
    End If
    lw = H2OLiCl_LambdaWater(T_C): rs = H2OLiCl_RhoSol(T_C, xi)
    If IsEmpty(lw) Or IsEmpty(rs) Then H2OLiCl_LambdaSol = Empty: Exit Function
    zetaEq = xi * rs / 42.394
    H2OLiCl_LambdaSol = lw - (0.0108958 - 0.0117882 * xi) * zetaEq
End Function

Private Function CpF1(ByVal xi As Double) As Double
    If xi > 0.31 Then
        CpF1 = 0.12825 + 0.62934 * xi
    Else
        CpF1 = 1.4398 * xi - 1.24317 * xi ^ 2 - 0.1207 * xi ^ 3
    End If
End Function

Private Function CpF2(ByVal T_C As Double) As Double
    Dim th As Double
    th = (T_C + 273.15) / 228# - 1#
    CpF2 = 58.5225 * th ^ 0.02 - 105.6343 * th ^ 0.04 + 47.7948 * th ^ 0.06
End Function

Public Function H2OLiCl_CpSol(ByVal T_C As Double, ByVal xi As Double) As Variant
    Dim cw As Variant
    If xi < 0# Or xi > 0.56 Or T_C < 0# Or T_C > 150# Then
        H2OLiCl_CpSol = Empty: Exit Function
    End If
    cw = H2OLiCl_CpWater(T_C)
    If IsEmpty(cw) Then H2OLiCl_CpSol = Empty: Exit Function
    H2OLiCl_CpSol = cw * (1# - CpF1(xi) * CpF2(T_C))
End Function

' ---------- Dilution enthalpy (Sec.8, theta = theta_r) and solution enthalpy ----------
Public Function H2OLiCl_DhD(ByVal xi As Double, ByVal T_C As Double) As Variant
    Dim th As Double, dh0 As Double, zeta As Double
    If xi < 0# Or xi > 0.55 Or T_C < 0# Or T_C > 150# Then
        H2OLiCl_DhD = Empty: Exit Function
    End If
    If xi = 0# Then H2OLiCl_DhD = 0#: Exit Function
    th = (T_C + 273.15) / HL_TC
    dh0 = 169.105 + 457.85 * th
    zeta = xi / (0.6 - xi)
    H2OLiCl_DhD = dh0 * (1# + (zeta / 0.845) ^ (-1.965)) ^ (-2.265)
End Function

Private Function GDh(ByVal s As Double, ByVal Tref_C As Double) As Double
    If s <= 0# Then GDh = 0#: Exit Function
    GDh = H2OLiCl_DhD(s, Tref_C) / (s * s)
End Function

Public Function H2OLiCl_HmixExcess(ByVal xi As Double, _
        Optional ByVal Tref_C As Double = 25#) As Variant
    Dim n As Long, i As Long, h As Double, tot As Double
    If xi < 0# Or xi > 0.55 Then H2OLiCl_HmixExcess = Empty: Exit Function
    If xi = 0# Then H2OLiCl_HmixExcess = 0#: Exit Function
    n = 400: h = xi / n
    tot = GDh(0#, Tref_C) + GDh(xi, Tref_C)
    For i = 1 To n - 1
        If i Mod 2 = 1 Then tot = tot + 4# * GDh(i * h, Tref_C) _
                       Else tot = tot + 2# * GDh(i * h, Tref_C)
    Next i
    H2OLiCl_HmixExcess = xi * tot * h / 3#
End Function

Public Function H2OLiCl_Hsol(ByVal T_C As Double, ByVal xi As Double) As Variant
    Dim e As Variant, n As Long, i As Long, h As Double, tot As Double
    If xi < 0# Or xi > 0.55 Or T_C < 0# Or T_C > 150# Then
        H2OLiCl_Hsol = Empty: Exit Function
    End If
    e = H2OLiCl_HmixExcess(xi, 25#)
    If IsEmpty(e) Then H2OLiCl_Hsol = Empty: Exit Function
    If T_C = 0# Then H2OLiCl_Hsol = e: Exit Function
    n = 200: h = T_C / n
    tot = H2OLiCl_CpSol(0#, xi) + H2OLiCl_CpSol(T_C, xi)
    For i = 1 To n - 1
        If i Mod 2 = 1 Then tot = tot + 4# * H2OLiCl_CpSol(i * h, xi) _
                       Else tot = tot + 2# * H2OLiCl_CpSol(i * h, xi)
    Next i
    H2OLiCl_Hsol = tot * h / 3# + e
End Function

Public Function H2OLiCl_TsolByHsol(ByVal h As Double, ByVal xi As Double) As Variant
    Dim prevT As Double, prevH As Double, havePrev As Boolean
    Dim lo As Double, hi As Double, mid As Double, k As Long
    Dim hv As Variant, haveBracket As Boolean
    If xi < 0# Or xi > 0.55 Then H2OLiCl_TsolByHsol = Empty: Exit Function
    havePrev = False: haveBracket = False
    For k = 0 To 30
        hv = H2OLiCl_Hsol(5# * k, xi)
        If Not IsEmpty(hv) Then
            If havePrev And prevH <= h And h <= hv Then
                lo = prevT: hi = 5# * k: haveBracket = True: Exit For
            End If
            prevT = 5# * k: prevH = hv: havePrev = True
        End If
    Next k
    If Not haveBracket Then H2OLiCl_TsolByHsol = Empty: Exit Function
    For k = 1 To 80
        mid = 0.5 * (lo + hi)
        If H2OLiCl_Hsol(mid, xi) < h Then lo = mid Else hi = mid
    Next k
    H2OLiCl_TsolByHsol = 0.5 * (lo + hi)
End Function

' ---------- Crystallisation / SLE boundary (Sec.2, Table 1) ----------
' branch: "ice", "LiCl.5H2O", "LiCl.3H2O", "LiCl.2H2O", "LiCl.H2O", "LiCl"
Public Function H2OLiCl_SleT(ByVal xi As Double, ByVal branch As String) As Variant
    Dim A0 As Double, A1 As Double, A2 As Double, e As Double
    If xi < 0# Or xi > 0.65 Then H2OLiCl_SleT = Empty: Exit Function
    Select Case branch
        Case "ice":       A0 = 0.422088:  A1 = -0.09041:  A2 = -2.93635:  e = 2.5
        Case "LiCl.5H2O": A0 = -0.00534:  A1 = 2.01589:   A2 = -3.11459:  e = 2#
        Case "LiCl.3H2O": A0 = -0.56036:  A1 = 4.72308:   A2 = -5.81105:  e = 2#
        Case "LiCl.2H2O": A0 = -0.31522:  A1 = 2.88248:   A2 = -2.62433:  e = 2#
        Case "LiCl.H2O":  A0 = -1.31231:  A1 = 6.17767:   A2 = -5.03479:  e = 2#
        Case "LiCl":      A0 = -1.3568:   A1 = 3.44854:   A2 = 0#:       e = 2#
        Case Else: H2OLiCl_SleT = Empty: Exit Function
    End Select
    H2OLiCl_SleT = (A0 + A1 * xi + A2 * xi ^ e) * HL_TC - 273.15
End Function

Public Function H2OLiCl_CrystallizationT(ByVal xi As Double) As Variant
    Dim names As Variant, i As Integer, v As Variant, best As Double
    If xi < 0# Or xi > 0.65 Then H2OLiCl_CrystallizationT = Empty: Exit Function
    names = Array("ice", "LiCl.5H2O", "LiCl.3H2O", "LiCl.2H2O", "LiCl.H2O", "LiCl")
    best = -1E+30
    For i = 0 To 5
        v = H2OLiCl_SleT(xi, names(i))
        If v > best Then best = v
    Next i
    H2OLiCl_CrystallizationT = best
End Function

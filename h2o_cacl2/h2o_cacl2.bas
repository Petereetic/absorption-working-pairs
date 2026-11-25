Attribute VB_Name = "H2OCaCl2"
' ==========================================================================
' H2O-CaCl2 working pair: properties of aqueous calcium chloride (VBA)
' ==========================================================================
' Source: Conde-Petit, M. R., Int. J. Thermal Sciences 43 (2004)
' 367-382, CaCl2 branch only.  Coefficients and verification anchors:
' dossiers/H2O-LiCl-CaCl2-Conde.md in the formula material library
' (~/workspace/your_files/工质对公式素材库/).
' Line-by-line port of h2o_cacl2.py (Python reference) in the same
' directory; the Python version is verified against the dossier
' anchors (vapour pressure, density, cp factors, dilution enthalpy
' figure anchors, SLE eutectic).  This .bas is verified in real
' Excel as part of the bas.xlsm build (see the bas repo devnotes).
'
' Dilution enthalpy (Sec.8): theta = theta_r = T_K / 647.096 per
' the paper's Nomenclature default and the dossier Sec.8 ruling of
' 2026-11-19 (the Sec.8 text does not redefine theta; the Sato
' theta_s = T_K/228 - 1 applies only to the Sec.7 cp section).
' NOTE: the sibling H2OLiCl module as first built used theta_s in
' its DhD; it was changed to theta_r on 2026-11-24 by Peter's
' order, so both branches now follow the 2026-11-19 ruling.
'
' Conventions: xi = CaCl2 mass fraction (e.g. 0.3), T in degC,
' P in MPa, h kJ/kg, rho kg/m3, eta Pa s, sigma N/m,
' lambda W/(m K), cp kJ/(kg K), dh_d kJ/kg_H2O.
' Out of range: functions return Empty.
'
' Enthalpy datum (hsol): hsol(0 degC, xi=0) = 0 (pure liquid water
' at 0 degC); hsol(T, xi) = integral of cp_sol from 0 degC plus the
' 25 degC excess term H2OCaCl2_HmixExcess(xi) built from the
' differential dilution enthalpy.  Use enthalpy differences within
' this module only.  See the formula notes for the full statement.
' ==========================================================================
Option Explicit

Private Const HC_TC As Double = 647.096
Private Const HC_PC As Double = 22.064

Private Function CpWTab() As Variant
    CpWTab = Array(4.217, 4.192, 4.182, 4.178, 4.178, 4.179, 4.181, 4.186, _
                   4.193, 4.204, 4.216, 4.229, 4.242, 4.254, 4.267, 4.281)
End Function

Private Function LamWTab() As Variant
    LamWTab = Array(0.561, 0.58, 0.598, 0.615, 0.631, 0.644, 0.654, 0.663, _
                    0.67, 0.676, 0.679, 0.683, 0.685, 0.686, 0.685, 0.683)
End Function

Private Function TabInterp(ByRef tab As Variant, ByVal T_C As Double) As Double
    Dim i As Integer, f As Double
    If T_C <= 0# Then TabInterp = tab(0): Exit Function
    If T_C >= 150# Then TabInterp = tab(15): Exit Function
    i = Int(T_C / 10#)
    f = (T_C - 10# * i) / 10#
    TabInterp = tab(i) * (1# - f) + tab(i + 1) * f
End Function

' ---------- Pure water ----------
Public Function H2OCaCl2_PrefWater(ByVal T_C As Double) As Variant
    Dim T As Double, tau As Double, s As Double
    If T_C < -50# Or T_C > 300# Then H2OCaCl2_PrefWater = Empty: Exit Function
    T = T_C + 273.15
    tau = 1# - T / HC_TC
    s = -7.85823 * tau + 1.83991 * tau ^ 1.5 - 11.7811 * tau ^ 3 _
        + 22.6705 * tau ^ 3.5 - 15.9393 * tau ^ 4 + 1.77516 * tau ^ 7.5
    H2OCaCl2_PrefWater = HC_PC * Exp(s / (1# - tau))
End Function

Public Function H2OCaCl2_TsatWater(ByVal P_MPa As Double) As Variant
    Dim lo As Double, hi As Double, mid As Double, k As Long
    If P_MPa <= 0# Then H2OCaCl2_TsatWater = Empty: Exit Function
    If P_MPa < H2OCaCl2_PrefWater(-50#) Or P_MPa > H2OCaCl2_PrefWater(300#) Then
        H2OCaCl2_TsatWater = Empty: Exit Function
    End If
    lo = -50#: hi = 300#
    For k = 1 To 100
        mid = 0.5 * (lo + hi)
        If H2OCaCl2_PrefWater(mid) < P_MPa Then lo = mid Else hi = mid
    Next k
    H2OCaCl2_TsatWater = 0.5 * (lo + hi)
End Function

Public Function H2OCaCl2_RhoWater(ByVal T_C As Double) As Variant
    Dim tau As Double
    If T_C < -40# Or T_C > 150# Then H2OCaCl2_RhoWater = Empty: Exit Function
    tau = 1# - (T_C + 273.15) / HC_TC
    H2OCaCl2_RhoWater = 322# * (1# + 1.993771843 * tau ^ (1# / 3#) _
        + 1.0985211604 * tau ^ (2# / 3#) - 0.5094492996 * tau ^ (5# / 3#) _
        - 1.761912427 * tau ^ (16# / 3#) - 44.9005480267 * tau ^ (43# / 3#) _
        - 723692.2618632 * tau ^ (110# / 3#))
End Function

Public Function H2OCaCl2_CpWater(ByVal T_C As Double) As Variant
    If T_C < 0# Or T_C > 150# Then H2OCaCl2_CpWater = Empty: Exit Function
    H2OCaCl2_CpWater = TabInterp(CpWTab(), T_C)
End Function

Public Function H2OCaCl2_SigmaWater(ByVal T_C As Double) As Variant
    Dim th As Double
    If T_C < -40# Or T_C > 150# Then H2OCaCl2_SigmaWater = Empty: Exit Function
    th = (T_C + 273.15) / HC_TC
    H2OCaCl2_SigmaWater = 0.2358 * (1# - 0.625 * (1# - th)) * (1# - th) ^ 1.256
End Function

Public Function H2OCaCl2_EtaWater(ByVal T_C As Double) As Variant
    If T_C < 0# Or T_C > 150# Then H2OCaCl2_EtaWater = Empty: Exit Function
    H2OCaCl2_EtaWater = 0.00002414 * 10# ^ (247.8 / (T_C + 273.15 - 140#))
End Function

Public Function H2OCaCl2_LambdaWater(ByVal T_C As Double) As Variant
    Dim th As Double
    If T_C < -20# Or T_C > 150# Then H2OCaCl2_LambdaWater = Empty: Exit Function
    If T_C >= 20# Then
        H2OCaCl2_LambdaWater = TabInterp(LamWTab(), T_C)
    Else
        th = (T_C + 273.15) / HC_TC
        H2OCaCl2_LambdaWater = TabInterp(LamWTab(), 20#) * (0.208496 + 1.747278 * th)
    End If
End Function

' ---------- Vapour pressure (paper Sec.1) ----------
Public Function H2OCaCl2_PiFactor(ByVal xi As Double, ByVal T_C As Double) As Variant
    Dim th As Double, A As Double, B As Double, pi25 As Double
    If xi < 0# Or xi > 0.6 Or T_C < -40# Or T_C > 150# Then
        H2OCaCl2_PiFactor = Empty: Exit Function
    End If
    th = (T_C + 273.15) / HC_TC
    A = 2# - (1# + (xi / 0.31) ^ 3.698) ^ 0.6
    B = (1# + (xi / 0.231) ^ 4.584) ^ 0.49 - 1#
    If xi = 0# Then
        pi25 = 1# - 0.018 * Exp(-0.01 / 0.005)
    Else
        pi25 = 1# - (1# + (xi / 0.478) ^ (-5.2)) ^ (-0.4) _
               - 0.018 * Exp(-((xi - 0.1) ^ 2) / 0.005)
    End If
    H2OCaCl2_PiFactor = pi25 * (A + B * th)
End Function

Public Function H2OCaCl2_Psol(ByVal T_C As Double, ByVal xi As Double) As Variant
    Dim pi As Variant
    pi = H2OCaCl2_PiFactor(xi, T_C)
    If IsEmpty(pi) Then H2OCaCl2_Psol = Empty: Exit Function
    H2OCaCl2_Psol = pi * H2OCaCl2_PrefWater(T_C)
End Function

Public Function H2OCaCl2_BubbleT(ByVal P_MPa As Double, ByVal xi As Double) As Variant
    Dim lo As Double, hi As Double, mid As Double, k As Long
    Dim plo As Variant, phi As Variant
    lo = -40#: hi = 150#
    plo = H2OCaCl2_Psol(lo, xi): phi = H2OCaCl2_Psol(hi, xi)
    If IsEmpty(plo) Or IsEmpty(phi) Then H2OCaCl2_BubbleT = Empty: Exit Function
    If P_MPa < plo Or P_MPa > phi Then H2OCaCl2_BubbleT = Empty: Exit Function
    For k = 1 To 80
        mid = 0.5 * (lo + hi)
        If H2OCaCl2_Psol(mid, xi) < P_MPa Then lo = mid Else hi = mid
    Next k
    H2OCaCl2_BubbleT = 0.5 * (lo + hi)
End Function

Public Function H2OCaCl2_TdewByTsolXi(ByVal T_C As Double, ByVal xi As Double) As Variant
    Dim P As Variant
    P = H2OCaCl2_Psol(T_C, xi)
    If IsEmpty(P) Then H2OCaCl2_TdewByTsolXi = Empty: Exit Function
    H2OCaCl2_TdewByTsolXi = H2OCaCl2_TsatWater(P)
End Function

Public Function H2OCaCl2_XiByTsolTdew(ByVal Tsol_C As Double, ByVal Tdew_C As Double) As Variant
    Dim P As Variant, pmax As Variant, pmin As Variant
    Dim lo As Double, hi As Double, mid As Double, k As Long
    If Tsol_C < -40# Or Tsol_C > 150# Then H2OCaCl2_XiByTsolTdew = Empty: Exit Function
    P = H2OCaCl2_PrefWater(Tdew_C)
    If IsEmpty(P) Then H2OCaCl2_XiByTsolTdew = Empty: Exit Function
    pmax = H2OCaCl2_Psol(Tsol_C, 0#): pmin = H2OCaCl2_Psol(Tsol_C, 0.6)
    If IsEmpty(pmax) Or IsEmpty(pmin) Then H2OCaCl2_XiByTsolTdew = Empty: Exit Function
    If P < pmin Or P > pmax Then H2OCaCl2_XiByTsolTdew = Empty: Exit Function
    lo = 0#: hi = 0.6
    For k = 1 To 80
        mid = 0.5 * (lo + hi)
        If H2OCaCl2_Psol(Tsol_C, mid) > P Then lo = mid Else hi = mid
    Next k
    H2OCaCl2_XiByTsolTdew = 0.5 * (lo + hi)
End Function

' ---------- Density / surface tension / viscosity / conductivity / cp ----------
Public Function H2OCaCl2_RhoSol(ByVal T_C As Double, ByVal xi As Double) As Variant
    Dim rw As Variant, z As Double
    If xi < 0# Or xi > 0.6 Or T_C < -40# Or T_C > 150# Then
        H2OCaCl2_RhoSol = Empty: Exit Function
    End If
    rw = H2OCaCl2_RhoWater(T_C)
    If IsEmpty(rw) Then H2OCaCl2_RhoSol = Empty: Exit Function
    z = xi / (1# - xi)
    H2OCaCl2_RhoSol = rw * (1# + 0.836014 * z - 0.4363 * z ^ 2 + 0.105642 * z ^ 3)
End Function

Public Function H2OCaCl2_SigmaSol(ByVal T_C As Double, ByVal xi As Double) As Variant
    Dim sw As Variant, th As Double
    If xi < 0# Or xi > 0.6 Or T_C < -40# Or T_C > 150# Then
        H2OCaCl2_SigmaSol = Empty: Exit Function
    End If
    sw = H2OCaCl2_SigmaWater(T_C)
    If IsEmpty(sw) Then H2OCaCl2_SigmaSol = Empty: Exit Function
    th = (T_C + 273.15) / HC_TC
    H2OCaCl2_SigmaSol = sw * (1# + 2.33067 * xi - 10.78779 * xi * th _
        + 13.56611 * xi * th ^ 2 + 1.95017 * xi ^ 2 - 1.7799 * xi ^ 3)
End Function

Public Function H2OCaCl2_EtaSol(ByVal T_C As Double, ByVal xi As Double) As Variant
    Dim ew As Variant, th As Double, zeta As Double
    If xi < 0# Or xi > 0.6 Or T_C < 0# Or T_C > 150# Then
        H2OCaCl2_EtaSol = Empty: Exit Function
    End If
    ew = H2OCaCl2_EtaWater(T_C)
    If IsEmpty(ew) Then H2OCaCl2_EtaSol = Empty: Exit Function
    th = (T_C + 273.15) / HC_TC
    zeta = xi / (1# - xi) ^ (1# / 0.6)
    H2OCaCl2_EtaSol = ew * Exp(-0.16931 * zeta ^ 3.6 + 0.81735 * zeta _
        + 0.57423 * zeta / th + 0.39875 * zeta ^ 2)
End Function

Public Function H2OCaCl2_LambdaSol(ByVal T_C As Double, ByVal xi As Double) As Variant
    Dim lw As Variant, rs As Variant, zetaEq As Double
    If xi < 0# Or xi > 0.6 Or T_C < -20# Or T_C > 150# Then
        H2OCaCl2_LambdaSol = Empty: Exit Function
    End If
    lw = H2OCaCl2_LambdaWater(T_C): rs = H2OCaCl2_RhoSol(T_C, xi)
    If IsEmpty(lw) Or IsEmpty(rs) Then H2OCaCl2_LambdaSol = Empty: Exit Function
    zetaEq = xi * rs * 2# / 110.98
    H2OCaCl2_LambdaSol = lw - (0.0059473 - 0.0013988 * xi) * zetaEq
End Function

Private Function CpF1(ByVal xi As Double) As Double
    CpF1 = 1.63799 * xi - 1.69002 * xi ^ 2 + 1.05124 * xi ^ 3
End Function

Private Function CpF2(ByVal T_C As Double) As Double
    Dim th As Double
    th = (T_C + 273.15) / 228# - 1#
    CpF2 = 58.5225 * th ^ 0.02 - 105.6343 * th ^ 0.04 + 47.7948 * th ^ 0.06
End Function

Public Function H2OCaCl2_CpSol(ByVal T_C As Double, ByVal xi As Double) As Variant
    Dim cw As Variant
    If xi < 0# Or xi > 0.6 Or T_C < 0# Or T_C > 150# Then
        H2OCaCl2_CpSol = Empty: Exit Function
    End If
    cw = H2OCaCl2_CpWater(T_C)
    If IsEmpty(cw) Then H2OCaCl2_CpSol = Empty: Exit Function
    H2OCaCl2_CpSol = cw * (1# - CpF1(xi) * CpF2(T_C))
End Function

' ---------- Dilution enthalpy (Sec.8, theta = theta_r) and solution enthalpy ----------
Public Function H2OCaCl2_DhD(ByVal xi As Double, ByVal T_C As Double) As Variant
    Dim th As Double, dh0 As Double, zeta As Double
    If xi < 0# Or xi > 0.6 Or T_C < 0# Or T_C > 150# Then
        H2OCaCl2_DhD = Empty: Exit Function
    End If
    If xi = 0# Then H2OCaCl2_DhD = 0#: Exit Function
    th = (T_C + 273.15) / HC_TC
    dh0 = -955.69 + 3011.974 * th
    zeta = xi / (0.8 - xi)
    H2OCaCl2_DhD = dh0 * (1# + (zeta / 0.855) ^ (-1.965)) ^ (-2.265)
End Function

Private Function GDh(ByVal s As Double, ByVal Tref_C As Double) As Double
    If s <= 0# Then GDh = 0#: Exit Function
    GDh = H2OCaCl2_DhD(s, Tref_C) / (s * s)
End Function

Public Function H2OCaCl2_HmixExcess(ByVal xi As Double, _
        Optional ByVal Tref_C As Double = 25#) As Variant
    Dim n As Long, i As Long, h As Double, tot As Double
    If xi < 0# Or xi > 0.6 Then H2OCaCl2_HmixExcess = Empty: Exit Function
    If xi = 0# Then H2OCaCl2_HmixExcess = 0#: Exit Function
    n = 400: h = xi / n
    tot = GDh(0#, Tref_C) + GDh(xi, Tref_C)
    For i = 1 To n - 1
        If i Mod 2 = 1 Then tot = tot + 4# * GDh(i * h, Tref_C) _
                       Else tot = tot + 2# * GDh(i * h, Tref_C)
    Next i
    H2OCaCl2_HmixExcess = xi * tot * h / 3#
End Function

Public Function H2OCaCl2_Hsol(ByVal T_C As Double, ByVal xi As Double) As Variant
    Dim e As Variant, n As Long, i As Long, h As Double, tot As Double
    If xi < 0# Or xi > 0.6 Or T_C < 0# Or T_C > 150# Then
        H2OCaCl2_Hsol = Empty: Exit Function
    End If
    e = H2OCaCl2_HmixExcess(xi, 25#)
    If IsEmpty(e) Then H2OCaCl2_Hsol = Empty: Exit Function
    If T_C = 0# Then H2OCaCl2_Hsol = e: Exit Function
    n = 200: h = T_C / n
    tot = H2OCaCl2_CpSol(0#, xi) + H2OCaCl2_CpSol(T_C, xi)
    For i = 1 To n - 1
        If i Mod 2 = 1 Then tot = tot + 4# * H2OCaCl2_CpSol(i * h, xi) _
                       Else tot = tot + 2# * H2OCaCl2_CpSol(i * h, xi)
    Next i
    H2OCaCl2_Hsol = tot * h / 3# + e
End Function

Public Function H2OCaCl2_TsolByHsol(ByVal h As Double, ByVal xi As Double) As Variant
    Dim prevT As Double, prevH As Double, havePrev As Boolean
    Dim lo As Double, hi As Double, mid As Double, k As Long
    Dim hv As Variant, haveBracket As Boolean
    If xi < 0# Or xi > 0.6 Then H2OCaCl2_TsolByHsol = Empty: Exit Function
    havePrev = False: haveBracket = False
    For k = 0 To 30
        hv = H2OCaCl2_Hsol(5# * k, xi)
        If Not IsEmpty(hv) Then
            If havePrev And prevH <= h And h <= hv Then
                lo = prevT: hi = 5# * k: haveBracket = True: Exit For
            End If
            prevT = 5# * k: prevH = hv: havePrev = True
        End If
    Next k
    If Not haveBracket Then H2OCaCl2_TsolByHsol = Empty: Exit Function
    For k = 1 To 80
        mid = 0.5 * (lo + hi)
        If H2OCaCl2_Hsol(mid, xi) < h Then lo = mid Else hi = mid
    Next k
    H2OCaCl2_TsolByHsol = 0.5 * (lo + hi)
End Function

' ---------- Crystallisation / SLE boundary (Sec.2, Table 2) ----------
' branch: "ice", "CaCl2.6H2O", "CaCl2.4H2Oa", "CaCl2.4H2Ob",
'         "CaCl2.2H2O", "CaCl2"
Public Function H2OCaCl2_SleT(ByVal xi As Double, ByVal branch As String) As Variant
    Dim A0 As Double, A1 As Double, A2 As Double, A3 As Double
    If xi < 0# Or xi > 0.8 Then H2OCaCl2_SleT = Empty: Exit Function
    Select Case branch
        Case "ice":         A0 = 0.422088:  A1 = -0.066933: A2 = -0.282395: A3 = -355.514247
        Case "CaCl2.6H2O":  A0 = -0.37895:  A1 = 3.4569:    A2 = -3.53131:  A3 = 0#
        Case "CaCl2.4H2Oa": A0 = -0.51997:  A1 = 3.40097:   A2 = -2.85129:  A3 = 0#
        Case "CaCl2.4H2Ob": A0 = -1.149044: A1 = 5.509111:  A2 = -4.642544: A3 = 0#
        Case "CaCl2.2H2O":  A0 = -2.385836: A1 = 8.084829:  A2 = -5.303476: A3 = 0#
        Case "CaCl2":       A0 = -2.80756:  A1 = 4.67825:   A2 = 0#:       A3 = 0#
        Case Else: H2OCaCl2_SleT = Empty: Exit Function
    End Select
    H2OCaCl2_SleT = (A0 + A1 * xi + A2 * xi ^ 2 + A3 * xi ^ 7.5) * HC_TC - 273.15
End Function

Public Function H2OCaCl2_CrystallizationT(ByVal xi As Double) As Variant
    Dim names As Variant, i As Integer, v As Variant, best As Double
    If xi < 0# Or xi > 0.8 Then H2OCaCl2_CrystallizationT = Empty: Exit Function
    names = Array("ice", "CaCl2.6H2O", "CaCl2.4H2Oa", "CaCl2.4H2Ob", "CaCl2.2H2O", "CaCl2")
    best = -1E+30
    For i = 0 To 5
        v = H2OCaCl2_SleT(xi, names(i))
        If v > best Then best = v
    Next i
    H2OCaCl2_CrystallizationT = best
End Function

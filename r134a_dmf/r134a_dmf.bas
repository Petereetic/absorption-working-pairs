Attribute VB_Name = "R134a_DMF"
'======================================================================
' R134a (1) + DMF (2) solution VLE and enthalpy calculation - Excel VBA module
'======================================================================
' Model: NRTL activity coefficients + gamma-phi bubble-point model
' Data source: Zehioua et al., J. Chem. Eng. Data 2009, DOI: 10.1021/je900440t
' Validation: 58 experimental points (303.30-353.24 K); bubble-point pressure mean absolute relative error 1.49%
'       (Note: the 1.49% is only the fit accuracy on the training set. Independent validations: Cui 2007, 90 points, AARD 15.1%;
'        Han 2011, 112 points, AARD 10.1%; cross-laboratory uncertainty about 300K/8%, 360K/20%.
'        See the merged-literature study document for R134a-DMF, dated 2026-09-30.)
' Reference state: saturated-liquid enthalpy at 273.15 K = 100 kJ/kg (unified for both components)
'
' How to use:
'   1. In Excel, press Alt+F11 to open the VBA editor
'   2. Menu: File -> Import File -> select this file (r134a_dmf.bas)
'   3. Call the functions directly in a worksheet, e.g.:
'        =Psol(303.3, 0.4437)        bubble-point pressure (MPa)
'        =Bubble_T(0.337, 0.4437)        temperature back-calculated from pressure (K)
'        =hsol(330, 0.5)           solution enthalpy (kJ/kg)
'        =Pref_R134a(303.15)             R134a saturation pressure (MPa)
'======================================================================
Option Explicit

Private Const R_GAS As Double = 8.314462618  ' J/(mol·K)
Private Const M1 As Double = 102.03          ' R134a molar mass g/mol
Private Const M2 As Double = 73.09           ' DMF molar mass g/mol
Private Const DG12 As Double = 868.1         ' NRTL, J/mol
Private Const DG21 As Double = -929.1        ' NRTL, J/mol
Private Const ALPHA As Double = 0.3

'---------- Pure-component saturation pressures (MPa), T in K ----------

Public Function Pref_R134a(T As Double) As Double
    Pref_R134a = Exp(7.89191 - 2310.84 / (T - 19.79))
End Function

Public Function Psat_DMF(T As Double) As Double
    Psat_DMF = (10# ^ (3.93068 - 1337.716 / (T - 82.648))) * 0.1
End Function

'---------- Liquid molar volumes (m3/mol), for the Poynting correction ----------

Private Function VL_R134a(T As Double) As Double
    Dim rho As Double
    rho = 1207# * (1# - 0.35 * (T - 300#) / 100#)
    If rho < 800# Then rho = 800#
    VL_R134a = 0.10203 / rho
End Function

Private Function VL_DMF(T As Double) As Double
    VL_DMF = 0.07309 / (944# * (1# - 0.0009 * (T - 293#)))
End Function

'---------- NRTL activity coefficients ----------
' Input T(K), x1 ; output g1, g2 (ByRef)

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

'---------- NRTL excess molar enthalpy (J/mol) ----------

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

'---------- Bubble-point pressure (MPa) ----------
' Input T(K), x1 ; y1 is the vapour-phase mole fraction (ByRef output, may be ignored)
' The vapour phase is almost pure R134a (y1 > 0.99)

Public Function Psol(T As Double, x1 As Double, Optional ByRef y1 As Double = -1#) As Double
    Dim x2 As Double, g1 As Double, g2 As Double
    Dim p1s As Double, p2s As Double, V1 As Double, V2 As Double
    Dim p As Double, Poy1 As Double, Poy2 As Double, i As Integer
    x2 = 1# - x1
    NRTL_Gamma T, x1, g1, g2
    p1s = Pref_R134a(T)
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
    Psol = p
End Function

'---------- Back-calculate the temperature (K) from the bubble-point pressure, Newton iteration ----------

Public Function Bubble_T(p_MPa As Double, x1 As Double, Optional Tguess As Double = 330#) As Double
    Dim T As Double, pc As Double, p2 As Double, dpdT As Double
    Dim dT As Double, dummy As Double, i As Integer
    T = Tguess
    dT = 0.2
    For i = 1 To 50
        pc = Psol(T, x1, dummy)
        p2 = Psol(T + dT, x1, dummy)
        dpdT = (p2 - pc) / dT
        If Abs(dpdT) < 0.000000000001 Then Exit For
        T = T - (pc - p_MPa) / dpdT
        If Abs(pc - p_MPa) < 0.000000001 Then Exit For
    Next i
    Bubble_T = T
End Function

'---------- Back-calculate the concentration from the dew-point temperature and the solution temperature (80 bisection steps) ----------
' Input: Tdew(K) dew-point temperature, Tsol(K) solution temperature
' Returns: x1 (R134a liquid-phase mole fraction); Empty when there is no root
' Principle: DMF is treated as non-volatile; the dew point fixes the pressure P = Pref_R134a(Tdew);
'       then bisection solves Psol(Tsol, x1) = P, with the bracket x1 in [0, 1].
' No-root case: P outside the bubble-point pressure interval under Tsol (e.g. Tsol clearly below Tdew).
' Note: same algorithm as C/Python; this VBA has not been compiled or tested in real Excel.

Public Function Xi_By_Tsol_Tdew(Tsol As Double, Tdew As Double) As Variant
    Dim P As Double, Plo As Double, Phi As Double
    Dim lo As Double, hi As Double, mid As Double, dummy As Double, k As Long
    P = Pref_R134a(Tdew)
    Plo = Psol(Tsol, 0#, dummy)
    Phi = Psol(Tsol, 1#, dummy)
    If P < Plo Or P > Phi Then
        Xi_By_Tsol_Tdew = Empty
        Exit Function
    End If
    lo = 0#: hi = 1#
    For k = 1 To 80
        mid = 0.5 * (lo + hi)
        If Psol(Tsol, mid, dummy) < P Then lo = mid Else hi = mid
    Next k
    Xi_By_Tsol_Tdew = 0.5 * (lo + hi)
End Function


'---------- R134a saturation temperature (K): analytic inverse of Pref_R134a ----------

Private Function Tsat_R134a(ByVal P_MPa As Double) As Double
    Tsat_R134a = 2310.84 / (7.89191 - Log(P_MPa)) + 19.79
End Function

'---------- Dew-point temperature (solution) (K): library-wide TdewByTsolXi convention ----------
' Tdew = Tsat_R134a(the pressure from Psol(T, x1)): the saturation temperature corresponding to the solution surface
' pressure Psol, evaluated with this module's own pure-R134a line. DMF is treated as non-volatile.

Public Function Tdew_By_Tsol_Xi(T As Double, x1 As Double) As Double
    Dim dummy As Double
    Tdew_By_Tsol_Xi = Tsat_R134a(Psol(T, x1, dummy))
End Function

'---------- Solve the solution temperature (K) back from the solution specific enthalpy ----------
' hsol increases monotonically with T at fixed x1; inverted by 100 bisection steps,
' with the solution bracket T in [280, 360] K. Returns Empty when h is outside the range.
' Note: same algorithm as C/Python; this VBA has not been compiled or tested in real Excel.

Public Function Tsol_By_Hsol(h As Double, x1 As Double) As Variant
    Dim lo As Double, hi As Double, mid As Double, k As Long
    lo = 280#: hi = 360#
    If h < hsol(lo, x1) Or h > hsol(hi, x1) Then
        Tsol_By_Hsol = Empty: Exit Function
    End If
    For k = 1 To 100
        mid = 0.5 * (lo + hi)
        If hsol(mid, x1) < h Then lo = mid Else hi = mid
    Next k
    Tsol_By_Hsol = 0.5 * (lo + hi)
End Function

'---------- Pure-component liquid enthalpies (kJ/kg) ----------

Public Function hliq_R134a(T As Double) As Double
    Dim tt As Double
    tt = T - 273.15
    hliq_R134a = 0.00001310235 * tt ^ 3 + 0.00134329 * tt ^ 2 + 1.334242 * tt + 100#
End Function

Public Function H_DMF_L(T As Double) As Double
    H_DMF_L = -297.61 + 0.89544 * T + 0.0020551 * T * T
End Function

'---------- Mole fraction <-> mass fraction (R134a) ----------

Public Function X_to_W(x1 As Double) As Double
    X_to_W = x1 * M1 / (x1 * M1 + (1# - x1) * M2)
End Function

Public Function W_to_X(w1 As Double) As Double
    W_to_X = (w1 / M1) / (w1 / M1 + (1# - w1) / M2)
End Function

'---------- Solution enthalpy (kJ/kg) ----------
' h = w1*h1 + w2*h2 + hE/Mbar

Public Function hsol(T As Double, x1 As Double) As Double
    Dim x2 As Double, Mbar As Double, w1 As Double, w2 As Double, hE As Double
    x2 = 1# - x1
    Mbar = x1 * M1 + x2 * M2
    w1 = x1 * M1 / Mbar
    w2 = x2 * M2 / Mbar
    hE = NRTL_hE(T, x1)
    hsol = w1 * hliq_R134a(T) + w2 * H_DMF_L(T) + hE / Mbar
End Function

Attribute VB_Name = "R22DEGDME"
' Thermodynamic correlations for R22-DEGDME (Excel VBA worksheet functions)
' Source: E. Ando, I. Takeshita, Int. J. Refrigeration, Vol.7, No.3, 1984.
'   Eq. (1) Bubble-point pressure Rankine equation: lnP = ΣAnX^n + (1/T)ΣBnX^n + lnT·ΣCnX^n
'         P: kg/cm2, T: K, X: R22 mole fraction; valid X=0.1~1.0, T=-20~190°C
'   Eq. (6) Molar heat capacity: C = ΣAnX^n + t·ΣBnX^n + t^2·ΣCnX^n; C: J/mol/°C, t: °C
'   Eq. (7) Heat of mixing (10°C): ΔHm = X(1-X)·Σ Gi·(1-2X)^(i-1); J/mol
'   Eq. (9) Solution specific enthalpy kJ/kg; reference state: pure-component liquids have enthalpy 0 at 10°C (a convention of this document)
'
' Worksheet functions:
'   =Psol_R22DEGDME(X, t_C)    bubble-point pressure, MPa (note: the function name is the retained original name, renaming pending a ruling; the return unit has been changed from bar to MPa)
'   =XiByTsolTdew_R22DEGDME(Tdew_C, Tsol_C)  solves X back from the dew-point/solution temperatures; returns Empty when there is no root
'   =CpMol_R22DEGDME(X, t_C)   molar heat capacity, J/mol/°C
'   =dHm_R22DEGDME(X)          heat of mixing, J/mol (measured at 10°C)
'   =hsol_R22DEGDME(X, t_C)    solution specific enthalpy, kJ/kg
'
' Note: this module has not been compiled or run in real Excel; compile and verify before use.

Option Explicit

Private Const M_R22 As Double = 86.47        ' g/mol
Private Const M_DEGDME As Double = 134.17    ' g/mol
Private Const TM_C As Double = 10#           ' °C
Private Const KGCM2_TO_MPA As Double = 0.0980665  ' 1 kg/cm2 = 0.0980665 MPa (exact definition)

' Table 2: (A, B, C) of Eq. (1) for n=0..5
Private Function T2A(ByVal n As Long) As Double
    Select Case n
        Case 0: T2A = 5.2167E+01
        Case 1: T2A = 1.2753E+01
        Case 2: T2A = -1.3901E+02
        Case 3: T2A = 7.3205E+02
        Case 4: T2A = -1.191E+03
        Case 5: T2A = 5.4717E+02
    End Select
End Function
Private Function T2B(ByVal n As Long) As Double
    Select Case n
        Case 0: T2B = -5.5828E+03
        Case 1: T2B = 3.3999E+03
        Case 2: T2B = -8.6015E+03
        Case 3: T2B = -3.1686E+03
        Case 4: T2B = 3.0425E+04
        Case 5: T2B = -1.9049E+04
    End Select
End Function
Private Function T2C(ByVal n As Long) As Double
    Select Case n
        Case 0: T2C = -6.3489E+00
        Case 1: T2C = -1.4386E+00
        Case 2: T2C = 2.2313E+01
        Case 3: T2C = -1.1454E+02
        Case 4: T2C = 1.8148E+02
        Case 5: T2C = -8.1999E+01
    End Select
End Function

' Table 3: (A, B, C) of Eq. (6) for n=0..3
Private Function T3A(ByVal n As Long) As Double
    Select Case n
        Case 0: T3A = 2.7974E+02
        Case 1: T3A = -1.5075E+02
        Case 2: T3A = 1.0095E+02
        Case 3: T3A = -1.2802E+02
    End Select
End Function
Private Function T3B(ByVal n As Long) As Double
    Select Case n
        Case 0: T3B = -4.2015E-02
        Case 1: T3B = 5.9865E-01
        Case 2: T3B = -1.379E+00
        Case 3: T3B = 1.0167E+00
    End Select
End Function
Private Function T3C(ByVal n As Long) As Double
    Select Case n
        Case 0: T3C = 2.3114E-03
        Case 1: T3C = -5.9745E-03
        Case 2: T3C = 3.4322E-03
        Case 3: T3C = 1.0571E-03
    End Select
End Function

' Eq. (7): G1..G4
Private Function Gk(ByVal i As Long) As Double
    Select Case i
        Case 1: Gk = -1.9061E+04
        Case 2: Gk = 8.728E+03
        Case 3: Gk = -1.3948E+03
        Case 4: Gk = -6.4218E+02
    End Select
End Function

' Eq. (1): bubble-point pressure, kg/cm2 (T_K in kelvin)
Public Function Psol_kgcm2_R22DEGDME(ByVal X As Double, ByVal T_K As Double) As Double
    Dim sA As Double, sB As Double, sC As Double, xn As Double, n As Long
    xn = 1#
    For n = 0 To 5
        sA = sA + T2A(n) * xn
        sB = sB + T2B(n) * xn
        sC = sC + T2C(n) * xn
        xn = xn * X
    Next n
    Psol_kgcm2_R22DEGDME = Exp(sA + sB / T_K + sC * Log(T_K))
End Function

' Eq. (1): bubble-point pressure, MPa (t_C in °C)
' [Note: the function name Psol_R22DEGDME is the retained original name (renaming pending a ruling); the return unit
' has been changed from bar to MPa] = native kg/cm2 value x0.0980665.
Public Function Psol_R22DEGDME(ByVal X As Double, ByVal t_C As Double) As Double
    Psol_R22DEGDME = Psol_kgcm2_R22DEGDME(X, t_C + 273.15) * KGCM2_TO_MPA
End Function

' Solve the concentration X (R22 mole fraction) back from the dew-point temperature and the solution temperature, by 80 bisection steps.
' The dew point fixes the pressure P = Psol_kgcm2_R22DEGDME(1, Tdew_C + 273.15) [native kg/cm2]:
' at the X=1 end, Eq. (1) is this module's pure R22 saturation pressure (DEGDME treated as non-volatile); then bisection solves
' Psol_kgcm2_R22DEGDME(X, Tsol_C + 273.15) = P, with the bracket taken as the valid concentration domain of Eq. (1), X in [0.1, 1].
' Internally the native kg/cm2 functions are used throughout (not via the MPa export line), so the concentration output is bit-for-bit unchanged.
' Returns Empty when there is no root (e.g. Tsol clearly below Tdew).
' Note: same algorithm as C/Python; this VBA has not been compiled or tested in real Excel.
Public Function XiByTsolTdew_R22DEGDME(ByVal Tsol_C As Double, ByVal Tdew_C As Double) As Variant
    Dim P As Double, lo As Double, hi As Double, mid As Double, k As Long
    P = Psol_kgcm2_R22DEGDME(1#, Tdew_C + 273.15)
    If P < Psol_kgcm2_R22DEGDME(0.1, Tsol_C + 273.15) Or P > Psol_kgcm2_R22DEGDME(1#, Tsol_C + 273.15) Then
        XiByTsolTdew_R22DEGDME = Empty
        Exit Function
    End If
    lo = 0.1: hi = 1#
    For k = 1 To 80
        mid = 0.5 * (lo + hi)
        If Psol_kgcm2_R22DEGDME(mid, Tsol_C + 273.15) < P Then lo = mid Else hi = mid
    Next k
    XiByTsolTdew_R22DEGDME = 0.5 * (lo + hi)
End Function


' ---------- Dew-point temperature (solution) [°C]: library-wide TdewByTsolXi convention ----------
' Tdew is the temperature on this module's own pure R22 line (the X=1 end of Eq. (1)) satisfying
' Psol_kgcm2_R22DEGDME(1, Tdew + 273.15) = Psol_kgcm2_R22DEGDME(X, t_C + 273.15)
' [native kg/cm2], inverted by 80 bisection steps, bracket t in [-50, 190] °C.
' Internally the native kg/cm2 functions are used throughout (not via the MPa export line), so the temperature output is bit-for-bit unchanged.
' Note: Eq. (1) has a nominal temperature domain of -20~190 °C; Tdew < -20 °C is an extrapolation of the pure end and must be noted when cited.
' DEGDME is treated as non-volatile. Returns Empty when there is no root.
' (This module's function convention is the (X, T) parameter order; this function follows it.)
Public Function TdewByTsolXi_R22DEGDME(ByVal X As Double, ByVal t_C As Double) As Variant
    Dim P As Double, lo As Double, hi As Double, mid As Double, k As Long
    P = Psol_kgcm2_R22DEGDME(X, t_C + 273.15)
    lo = -50#: hi = 190#
    If P < Psol_kgcm2_R22DEGDME(1#, lo + 273.15) Or P > Psol_kgcm2_R22DEGDME(1#, hi + 273.15) Then
        TdewByTsolXi_R22DEGDME = Empty: Exit Function
    End If
    For k = 1 To 80
        mid = 0.5 * (lo + hi)
        If Psol_kgcm2_R22DEGDME(1#, mid + 273.15) < P Then lo = mid Else hi = mid
    Next k
    TdewByTsolXi_R22DEGDME = 0.5 * (lo + hi)
End Function

' ---------- Solve the solution temperature [°C] back from the solution specific enthalpy ----------
' hsol_R22DEGDME increases monotonically with t at fixed X; inverted by 100 bisection steps,
' with the solution bracket t in [-30, 110] °C. Returns Empty when h is outside the range.
' Same algorithm as C/Python; this function has not been compiled or run in real Excel.
Public Function TsolByHsol_R22DEGDME(ByVal h As Double, ByVal X As Double) As Variant
    Dim lo As Double, hi As Double, mid As Double, k As Long
    lo = -30#: hi = 110#
    If h < hsol_R22DEGDME(X, lo) Or h > hsol_R22DEGDME(X, hi) Then
        TsolByHsol_R22DEGDME = Empty: Exit Function
    End If
    For k = 1 To 100
        mid = 0.5 * (lo + hi)
        If hsol_R22DEGDME(X, mid) < h Then lo = mid Else hi = mid
    Next k
    TsolByHsol_R22DEGDME = 0.5 * (lo + hi)
End Function

' Eq. (6): molar heat capacity, J/mol/°C
Public Function CpMol_R22DEGDME(ByVal X As Double, ByVal t_C As Double) As Double
    Dim sA As Double, sB As Double, sC As Double, xn As Double, n As Long
    xn = 1#
    For n = 0 To 3
        sA = sA + T3A(n) * xn
        sB = sB + T3B(n) * xn
        sC = sC + T3C(n) * xn
        xn = xn * X
    Next n
    CpMol_R22DEGDME = sA + t_C * sB + t_C * t_C * sC
End Function

' Eq. (7): heat of mixing, J/mol (measured at 10°C; negative when exothermic)
Public Function dHm_R22DEGDME(ByVal X As Double) As Double
    Dim s As Double, p As Double, d As Double, i As Long
    d = 1# - 2# * X: p = 1#: s = 0#
    For i = 1 To 4
        s = s + Gk(i) * p
        p = p * d
    Next i
    dHm_R22DEGDME = X * (1# - X) * s
End Function

' Eq. (9): solution specific enthalpy, kJ/kg; reference state: pure-component liquids have enthalpy 0 at 10°C
Public Function hsol_R22DEGDME(ByVal X As Double, ByVal t_C As Double) As Double
    Dim sA As Double, sB As Double, sC As Double, xn As Double, n As Long
    Dim sensible As Double, h_mol As Double, M_mix As Double, t0 As Double
    xn = 1#
    For n = 0 To 3
        sA = sA + T3A(n) * xn
        sB = sB + T3B(n) * xn
        sC = sC + T3C(n) * xn
        xn = xn * X
    Next n
    t0 = TM_C
    sensible = sA * (t_C - t0) _
             + sB * (t_C * t_C - t0 * t0) / 2# _
             + sC * (t_C * t_C * t_C - t0 * t0 * t0) / 3#
    h_mol = dHm_R22DEGDME(X) + sensible
    M_mix = X * M_R22 + (1# - X) * M_DEGDME
    hsol_R22DEGDME = h_mol / M_mix
End Function

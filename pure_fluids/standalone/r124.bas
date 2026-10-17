Attribute VB_Name = "R124"
' R124 pure-substance saturation properties (standalone calculation file, Excel VBA worksheet functions; coefficients verbatim identical to the merged module pure_fluids.bas)
' Source: fit to the NIST WebBook saturation table (see fit notes in ../fit-notes/, "R124 pure fluid - NIST table fit and Borde arbitration"), coefficients verbatim identical to the merged module pure_fluids; Wagner variant (1, 1.5, 3, 6) saturation pressure max deviation vs. table 0.111%; enthalpy shifted from the table datum by -100 to the uniform reference.
' Reference state: saturated-liquid enthalpy at 0°C = 100 kJ/kg (uniform module reference). Pref returns MPa; Tsat takes MPa and returns #NUM! when out of range.
' Note: this module has not been compiled or run in real Excel; compile and verify before use.

Option Explicit

Private Const TC As Double = 395.428
Private Const PC As Double = 36.245
Private Const TLO As Double = -40.0
Private Const THI As Double = 110.0

Private Function Wc(ByVal i As Long) As Double
    Select Case i
        Case 0: Wc = -7.401179377235425
        Case 1: Wc = 1.4613603991162563
        Case 2: Wc = -3.476435267708954
        Case 3: Wc = -1.772232810745864
    End Select
End Function

Private Function HLc(ByVal i As Long) As Double
    Select Case i
        Case 0: HLc = 3.101121704716488E-12
        Case 1: HLc = 6.118884579625834E-10
        Case 2: HLc = -1.0126584362284601E-08
        Case 3: HLc = -3.744431218418699E-06
        Case 4: HLc = 0.0009264564201937477
        Case 5: HLc = 1.0995525531984227
        Case 6: HLc = 100.04767130193036
    End Select
End Function

Private Function HVc(ByVal i As Long) As Double
    Select Case i
        Case 0: HVc = -4.7606354686130485E-12
        Case 1: HVc = -9.020883920792309E-10
        Case 2: HVc = 2.036341936229362E-08
        Case 3: HVc = 4.234769176716097E-06
        Case 4: HVc = -0.00038033802108463233
        Case 5: HVc = 0.5621038923140594
        Case 6: HVc = 259.94742998138406
    End Select
End Function

Private Function PrefRaw(ByVal t_C As Double) As Double
    Dim T As Double, tau As Double, s As Double
    T = t_C + 273.15
    tau = 1# - T / TC
    s = Wc(0) * tau + Wc(1) * tau ^ 1.5 + Wc(2) * tau ^ 3# + Wc(3) * tau ^ 6#
    PrefRaw = PC * Exp((TC / T) * s)
End Function

Private Function Poly6(ByVal t As Double, ByVal isVap As Boolean) As Double
    Dim c(0 To 6) As Double, i As Long, r As Double
    For i = 0 To 6
        If isVap Then c(i) = HVc(i) Else c(i) = HLc(i)
    Next i
    r = c(0)
    For i = 1 To 6
        r = r * t + c(i)
    Next i
    Poly6 = r
End Function

Private Function TsatBisect(ByVal P_bar As Double) As Double
    Dim lo As Double, hi As Double, mid As Double, i As Long
    If P_bar < PrefRaw(TLO) Or P_bar > PrefRaw(THI) Then
        TsatBisect = CVErr(xlErrNum)
        Exit Function
    End If
    lo = TLO: hi = THI
    For i = 1 To 60
        mid = 0.5 * (lo + hi)
        If PrefRaw(mid) < P_bar Then lo = mid Else hi = mid
    Next i
    TsatBisect = 0.5 * (lo + hi)
End Function

Public Function Pref_R124(ByVal t_C As Double) As Double
    Pref_R124 = 0.1 * PrefRaw(t_C)
End Function

Public Function Tsat_R124(ByVal P_MPa As Double) As Variant
    Tsat_R124 = TsatBisect(10# * P_MPa)
End Function

Public Function hliq_R124(ByVal t_C As Double) As Double
    hliq_R124 = Poly6(t_C, False)
End Function

Public Function hgas_R124(ByVal t_C As Double) As Double
    hgas_R124 = Poly6(t_C, True)
End Function

' R124 saturation latent heat, kJ/kg = hgas - hliq (same reference state)
Public Function hlat_R124(ByVal t_C As Double) As Double
    hlat_R124 = hgas_R124(t_C) - hliq_R124(t_C)
End Function

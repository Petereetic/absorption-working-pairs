Attribute VB_Name = "R22"
' R22 pure-substance saturation properties (standalone calculation file, Excel VBA worksheet functions; coefficients verbatim identical to the merged module pure_fluids.bas)
' Source: fit to the CoolProp reference equation of state, coefficients verbatim identical to the merged module pure_fluids; Wagner saturation pressure max deviation 0.0065%, enthalpy deviations 0.42/0.59 kJ/kg; reference state: saturated liquid at 0°C = 100 kJ/kg.
' Reference state: saturated-liquid enthalpy at 0°C = 100 kJ/kg (uniform module reference). Pref returns MPa; Tsat takes MPa and returns #NUM! when out of range.
' Note: this module has not been compiled or run in real Excel; compile and verify before use.

Option Explicit

Private Const TC As Double = 369.3
Private Const PC As Double = 49.9
Private Const TLO As Double = -50.0
Private Const THI As Double = 90.0

Private Function Wc(ByVal i As Long) As Double
    Select Case i
        Case 0: Wc = -7.048623
        Case 1: Wc = 1.4828095
        Case 2: Wc = -1.8223105
        Case 3: Wc = -2.8257753
    End Select
End Function

Private Function HLc(ByVal i As Long) As Double
    Select Case i
        Case 0: HLc = 4.6681599E-11
        Case 1: HLc = -2.2286115E-09
        Case 2: HLc = -1.2586426E-07
        Case 3: HLc = 1.4969301E-05
        Case 4: HLc = 0.0015173919
        Case 5: HLc = 1.167803
        Case 6: HLc = 99.972867
    End Select
End Function

Private Function HVc(ByVal i As Long) As Double
    Select Case i
        Case 0: HVc = -6.541236E-11
        Case 1: HVc = 3.1584987E-09
        Case 2: HVc = 1.6628519E-07
        Case 3: HVc = -2.1606737E-05
        Case 4: HVc = -0.0019128189
        Case 5: HVc = 0.37574587
        Case 6: HVc = 305.0864
    End Select
End Function

Private Function PrefRaw(ByVal t_C As Double) As Double
    Dim T As Double, tau As Double, s As Double
    T = t_C + 273.15
    tau = 1# - T / TC
    s = Wc(0) * tau + Wc(1) * tau ^ 1.5 + Wc(2) * tau ^ 2.5 + Wc(3) * tau ^ 5#
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

Public Function Pref_R22(ByVal t_C As Double) As Double
    Pref_R22 = 0.1 * PrefRaw(t_C)
End Function

Public Function R22_Tsat(ByVal P_MPa As Double) As Variant
    R22_Tsat = TsatBisect(10# * P_MPa)
End Function

Public Function hliq_R22(ByVal t_C As Double) As Double
    hliq_R22 = Poly6(t_C, False)
End Function

Public Function hgas_R22(ByVal t_C As Double) As Double
    hgas_R22 = Poly6(t_C, True)
End Function

' R22 saturation latent heat, kJ/kg = hgas - hliq (same reference state)
Public Function hlat_R22(ByVal t_C As Double) As Double
    hlat_R22 = hgas_R22(t_C) - hliq_R22(t_C)
End Function

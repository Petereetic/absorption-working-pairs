Attribute VB_Name = "R134a"
' R134a pure-substance saturation properties (standalone calculation file, Excel VBA worksheet functions; coefficients verbatim identical to the merged module pure_fluids.bas)
' Source: fit to the CoolProp reference equation of state (Tillner-Roth & Baehr 1994), coefficients verbatim identical to the merged module pure_fluids; Wagner saturation pressure max deviation 0.031%, enthalpy deviations 0.41/0.61 kJ/kg; reference state: saturated liquid at 0°C = 100 kJ/kg.
' Reference state: saturated-liquid enthalpy at 0°C = 100 kJ/kg (uniform module reference). Pref returns MPa; Tsat takes MPa and returns #NUM! when out of range.
' Note: this module has not been compiled or run in real Excel; compile and verify before use.

Option Explicit

Private Const TC As Double = 374.21
Private Const PC As Double = 40.59
Private Const TLO As Double = -50.0
Private Const THI As Double = 95.0

Private Function Wc(ByVal i As Long) As Double
    Select Case i
        Case 0: Wc = -7.6391282
        Case 1: Wc = 1.7650117
        Case 2: Wc = -2.6103553
        Case 3: Wc = -3.365738
    End Select
End Function

Private Function HLc(ByVal i As Long) As Double
    Select Case i
        Case 0: HLc = 3.5283163E-11
        Case 1: HLc = -2.2259203E-09
        Case 2: HLc = -7.2651551E-08
        Case 3: HLc = 1.3659406E-05
        Case 4: HLc = 0.0014602205
        Case 5: HLc = 1.3386046
        Case 6: HLc = 99.982381
    End Select
End Function

Private Function HVc(ByVal i As Long) As Double
    Select Case i
        Case 0: HVc = -5.4059642E-11
        Case 1: HVc = 3.2801028E-09
        Case 2: HVc = 1.2592287E-07
        Case 3: HVc = -2.100514E-05
        Case 4: HVc = -0.0012602316
        Case 5: HVc = 0.5908568
        Case 6: HVc = 298.63031
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

Public Function Pref_R134a(ByVal t_C As Double) As Double
    Pref_R134a = 0.1 * PrefRaw(t_C)
End Function

Public Function R134a_Tsat(ByVal P_MPa As Double) As Variant
    R134a_Tsat = TsatBisect(10# * P_MPa)
End Function

Public Function hliq_R134a(ByVal t_C As Double) As Double
    hliq_R134a = Poly6(t_C, False)
End Function

Public Function hgas_R134a(ByVal t_C As Double) As Double
    hgas_R134a = Poly6(t_C, True)
End Function

' R134a saturation latent heat, kJ/kg = hgas - hliq (same reference state)
Public Function hlat_R134a(ByVal t_C As Double) As Double
    hlat_R134a = hgas_R134a(t_C) - hliq_R134a(t_C)
End Function

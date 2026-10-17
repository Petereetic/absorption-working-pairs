Attribute VB_Name = "Water"
' H2O pure-substance saturation properties (standalone calculation file, Excel VBA worksheet functions; coefficients verbatim identical to the merged module pure_fluids.bas)
' Source: compact fit to the NIST WebBook saturation table (see fit notes in ../fit-notes/, "water saturation-property fit - NIST table"); saturation pressure as a degree-7 lnP-t polynomial, max deviation vs. table 0.0291% over the full range and 0.0128% in the usual band (5~300°C); enthalpy shifted from the table datum by +93.351889719 to the uniform reference. The authoritative standard for water is the IAPWS formulation; this is a portable compact fit.
' Reference state: saturated-liquid enthalpy at 0°C = 100 kJ/kg (uniform module reference). Pref returns MPa; Tsat takes MPa and returns #NUM! when out of range.
' Note: this module has not been compiled or run in real Excel; compile and verify before use.

Option Explicit

Private Const TLO As Double = 1.0
Private Const THI As Double = 373.0

Private Function LnPc(ByVal i As Long) As Double
    Select Case i
        Case 0: LnPc = 5.54627791673895E-18
        Case 1: LnPc = -8.99249875691861E-15
        Case 2: LnPc = 6.660700555390007E-12
        Case 3: LnPc = -3.088083641876246E-09
        Case 4: LnPc = 1.056735995405781E-06
        Case 5: LnPc = -0.0002954387998568004
        Case 6: LnPc = 0.07259423527358563
        Case 7: LnPc = -7.399704960820133
    End Select
End Function

Private Function HLc(ByVal i As Long) As Double
    Select Case i
        Case 0: HLc = 4.9253814056437E-12
        Case 1: HLc = -4.8364685293173926E-09
        Case 2: HLc = 1.8115766448129802E-06
        Case 3: HLc = -0.0003141174119157094
        Case 4: HLc = 0.02553352332697852
        Case 5: HLc = 3.3541747407753046
        Case 6: HLc = 100.0
    End Select
End Function

Private Function HVc(ByVal i As Long) As Double
    Select Case i
        Case 0: HVc = -8.083632440447619E-12
        Case 1: HVc = 7.910908004577575E-09
        Case 2: HVc = -2.951073494811462E-06
        Case 3: HVc = 0.0005046392594921277
        Case 4: HVc = -0.04153882947643235
        Case 5: HVc = 3.1701433360694287
        Case 6: HVc = 2583.8464687067276
    End Select
End Function

Private Function LnPPref(ByVal t_C As Double) As Double
    Dim c(0 To 7) As Double, i As Long, r As Double
    For i = 0 To 7
        c(i) = LnPc(i)
    Next i
    r = c(0)
    For i = 1 To 7
        r = r * t_C + c(i)
    Next i
    LnPPref = Exp(r)
End Function

Private Function PrefRaw(ByVal t_C As Double) As Double
    PrefRaw = LnPPref(t_C)
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

Private Function TsatBisect(ByVal P_MPa As Double) As Double
    Dim lo As Double, hi As Double, mid As Double, i As Long
    If P_MPa < PrefRaw(TLO) Or P_MPa > PrefRaw(THI) Then
        TsatBisect = CVErr(xlErrNum)
        Exit Function
    End If
    lo = TLO: hi = THI
    For i = 1 To 60
        mid = 0.5 * (lo + hi)
        If PrefRaw(mid) < P_MPa Then lo = mid Else hi = mid
    Next i
    TsatBisect = 0.5 * (lo + hi)
End Function

Public Function Pref_H2O(ByVal t_C As Double) As Double
    Pref_H2O = PrefRaw(t_C)
End Function

Public Function Tsat_H2O(ByVal P_MPa As Double) As Variant
    Tsat_H2O = TsatBisect(P_MPa)
End Function

Public Function hliq_H2O(ByVal t_C As Double) As Double
    hliq_H2O = Poly6(t_C, False)
End Function

Public Function hgas_H2O(ByVal t_C As Double) As Double
    hgas_H2O = Poly6(t_C, True)
End Function

' H2O saturation latent heat, kJ/kg = hgas - hliq (same reference state)
Public Function hlat_H2O(ByVal t_C As Double) As Double
    hlat_H2O = hgas_H2O(t_C) - hliq_H2O(t_C)
End Function

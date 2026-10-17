Attribute VB_Name = "CO2"
' CO2 pure-substance saturation properties (standalone calculation file, Excel VBA worksheet functions; coefficients verbatim identical to the merged module pure_fluids.bas)
' Source: compact fit to the NIST WebBook saturation table (see fit notes in ../fit-notes/, "carbon-dioxide saturation-property fit - NIST table"; the source table is rounded); saturation pressure as a degree-7 lnP-t polynomial, max deviation vs. table 0.0099% over the full range and 0.0059% in the usual band (-50~25°C); enthalpy shifted from the table datum by -100.255791821 to the uniform reference.
' Reference state: saturated-liquid enthalpy at 0°C = 100 kJ/kg (uniform module reference). Pref returns MPa; Tsat takes MPa and returns #NUM! when out of range.
' Note: this module has not been compiled or run in real Excel; compile and verify before use.

Option Explicit

Private Const TLO As Double = -56.0
Private Const THI As Double = 30.0

Private Function LnPc(ByVal i As Long) As Double
    Select Case i
        Case 0: LnPc = 7.349267422320306E-15
        Case 1: LnPc = 9.714937274844203E-13
        Case 2: LnPc = 5.722737962459257E-11
        Case 3: LnPc = -5.000472245728414E-10
        Case 4: LnPc = 5.236317080887681E-07
        Case 5: LnPc = -9.20196795346934E-05
        Case 6: LnPc = 0.02647312340946483
        Case 7: LnPc = 1.2485141855617028
    End Select
End Function

Private Function HLc(ByVal i As Long) As Double
    Select Case i
        Case 0: HLc = 2.948691221375449E-09
        Case 1: HLc = 3.3584601264848553E-07
        Case 2: HLc = 1.0969134467517922E-05
        Case 3: HLc = 9.865777775779578E-05
        Case 4: HLc = 0.006887751259917945
        Case 5: HLc = 2.4420397272329732
        Case 6: HLc = 100.0
    End Select
End Function

Private Function HVc(ByVal i As Long) As Double
    Select Case i
        Case 0: HVc = -4.280078787604416E-09
        Case 1: HVc = -4.893910288449988E-07
        Case 2: HVc = -1.62198769938507E-05
        Case 3: HVc = -0.00015811780903671123
        Case 4: HVc = -0.012470655351837747
        Case 5: HVc = -0.5840479229797425
        Case 6: HVc = 330.2675971498235
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

Public Function Pref_CO2(ByVal t_C As Double) As Double
    Pref_CO2 = PrefRaw(t_C)
End Function

Public Function Tsat_CO2(ByVal P_MPa As Double) As Variant
    Tsat_CO2 = TsatBisect(P_MPa)
End Function

Public Function hliq_CO2(ByVal t_C As Double) As Double
    hliq_CO2 = Poly6(t_C, False)
End Function

Public Function hgas_CO2(ByVal t_C As Double) As Double
    hgas_CO2 = Poly6(t_C, True)
End Function

' CO2 saturation latent heat, kJ/kg = hgas - hliq (same reference state)
Public Function hlat_CO2(ByVal t_C As Double) As Double
    hlat_CO2 = hgas_CO2(t_C) - hliq_CO2(t_C)
End Function

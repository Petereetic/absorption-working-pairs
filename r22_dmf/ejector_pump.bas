Attribute VB_Name = "EjectorPump"
' =====================================================================
' ejector_pump.bas - Pump-driven liquid-jet ejector for R22-DMF
'                    vapour lifting: complete pump-power calculation.
'
' VBA mirror of ejector_pump.c. Self-contained module: the EJP_*
' property functions are copies of the R22-DMF library (r22_dmf.bas)
' correlations - bubble pressure from Agarwal (1982) VLE fits (valid
' T -25..120 degC, xi 0.10..1.00, AARD 2.38%) and Fatouh et al. 1993
' solution enthalpy (valid approx T -20..95 degC). xi = R22 mass
' fraction everywhere. All Ej_* functions are worksheet-usable.
'
' Model (1-D constant-pressure mixing, momentum balance):
'   w_is  = k/(k-1) * R * Ts * (pi^((k-1)/k) - 1)     [kJ/kg vapour]
'   v_j   = phi_n * Sqr(2 (Pm-Ps)/rho_l)
'   v_m   = ml * v_j/(ml+1)
'   rho_m = (ml+1)/(ml/rho_l + 1/rho_vd)
'   eta_d * 0.5 * rho_m * v_m^2 >= Pd - Ps   -> min motive ratio ml
'   W     = ml * (Pm-Pd)/(rho_l * eta_p)     [pump shaft, kJ/kg vapour]
'   Tout from: ml*h(Tl,xi_l) + h_vap(Tv) + W = (ml+1)*h(Tout, xi_out)
' Coefficients used in the notes: phi_n=0.95, eta_d=0.85, eta_p=0.75,
' k=1.17. rho_l is an input (no density correlation in the library;
' notes use estimates 1100 / 1075 kg/m3). Model estimates, NOT
' experimental data. (Not compiled/tested in real Excel.)
' =====================================================================
Option Explicit

Private Const EJ_KAPPA As Double = 1.17
Private Const EJ_RS As Double = 8314# / 86.47#   ' J/(kg K)

' ---------- copied R22-DMF property block (prefix EJP_) ----------
Private Function IsoXi(i As Long) As Double
    Select Case i
        Case 0: IsoXi = 0.1: Case 1: IsoXi = 0.23076: Case 2: IsoXi = 0.32
        Case 3: IsoXi = 0.40348: Case 4: IsoXi = 0.5: Case 5: IsoXi = 0.6022
        Case 6: IsoXi = 0.7: Case 7: IsoXi = 0.8: Case 8: IsoXi = 0.9
        Case 9: IsoXi = 1#
    End Select
End Function
Private Function IsoA(i As Long) As Double
    Select Case i
        Case 0: IsoA = 30.772744: Case 1: IsoA = 10.400862: Case 2: IsoA = 10.271208
        Case 3: IsoA = -5.84816: Case 4: IsoA = 39.598401: Case 5: IsoA = 27.566449
        Case 6: IsoA = 28.096798: Case 7: IsoA = 51.969188: Case 8: IsoA = 99.166678
        Case 9: IsoA = 18.47413
    End Select
End Function
Private Function IsoB(i As Long) As Double
    Select Case i
        Case 0: IsoB = -3182.9395: Case 1: IsoB = -2459.9752: Case 2: IsoB = -2405.5462
        Case 3: IsoB = -1618.6504: Case 4: IsoB = -3709.7856: Case 5: IsoB = -3089.5702
        Case 6: IsoB = -3022.7056: Case 7: IsoB = -4223.6822: Case 8: IsoB = -6197.2
        Case 9: IsoB = -2766.7568
    End Select
End Function
Private Function IsoC(i As Long) As Double
    Select Case i
        Case 0: IsoC = -3.629138: Case 1: IsoC = -0.388685: Case 2: IsoC = -0.311415
        Case 3: IsoC = 2.088399: Case 4: IsoC = -4.591025: Case 5: IsoC = -2.81985
        Case 6: IsoC = -2.907606: Case 7: IsoC = -6.297351: Case 8: IsoC = -13.369886
        Case 9: IsoC = -1.197267
    End Select
End Function

' Monotone cubic (PCHIP, Fritsch-Carlson) interpolation.
Private Function EJPchip(x() As Double, y() As Double, xq As Double) As Double
    Dim n As Long, i As Long, k As Long
    Dim h(0 To 8) As Double, d(0 To 8) As Double, dk(0 To 9) As Double
    Dim w1 As Double, w2 As Double, t As Double, t2 As Double, t3 As Double
    n = 10
    For i = 0 To n - 2
        h(i) = x(i + 1) - x(i): d(i) = (y(i + 1) - y(i)) / h(i)
    Next i
    dk(0) = d(0): dk(n - 1) = d(n - 2)
    For k = 1 To n - 2
        If d(k - 1) * d(k) <= 0 Then
            dk(k) = 0
        Else
            w1 = 2 * h(k) + h(k - 1): w2 = h(k) + 2 * h(k - 1)
            dk(k) = (w1 + w2) / (w1 / d(k - 1) + w2 / d(k))
        End If
    Next k
    k = 0
    Do While k < n - 2 And xq > x(k + 1): k = k + 1: Loop
    t = (xq - x(k)) / h(k): t2 = t * t: t3 = t2 * t
    EJPchip = (2 * t3 - 3 * t2 + 1) * y(k) + (t3 - 2 * t2 + t) * h(k) * dk(k) _
            + (-2 * t3 + 3 * t2) * y(k + 1) + (t3 - t2) * h(k) * dk(k + 1)
End Function

' Private native value: bubble-point pressure [bar]. T_C [degC], xi = R22 mass fraction.
Private Function EJP_BubbleP_bar(T_C As Double, xi As Double) As Double
    Dim T As Double, lnT As Double, j As Long
    Dim X(0 To 9) As Double, Pj(0 To 9) As Double
    T = T_C + 273.15: lnT = Log(T)
    If xi < IsoXi(0) Then xi = IsoXi(0)
    If xi > IsoXi(9) Then xi = IsoXi(9)
    For j = 0 To 9
        X(j) = IsoXi(j)
        Pj(j) = Exp(IsoA(j) + IsoB(j) / T + IsoC(j) * lnT)
    Next j
    EJP_BubbleP_bar = EJPchip(X, Pj, xi)
End Function

' Bubble-point pressure [MPa]. T_C [degC], xi = R22 mass fraction.
Public Function EJP_BubbleP(T_C As Double, xi As Double) As Double
    EJP_BubbleP = EJP_BubbleP_bar(T_C, xi) * 0.1
End Function

Private Function EjFpoly(F0 As Double, F1 As Double, F2 As Double, T As Double) As Double
    EjFpoly = F0 + F1 * T + F2 * T * T
End Function

Public Function EJP_H_R22L(T_C As Double) As Double
    Dim T As Double: T = T_C + 273.15
    If T < 323.15 Then
        EJP_H_R22L = EjFpoly(-68.1484, 0.06313, 0.00202, T)
    Else
        EJP_H_R22L = EjFpoly(1966.645, -12.09784, 0.02018352, T)
    End If
End Function

Public Function EJP_H_R22V(T_C As Double) As Double
    Dim T As Double: T = T_C + 273.15
    If T < 323.15 Then
        EJP_H_R22V = EjFpoly(37.22971, 1.59952, -0.002260308, T)
    Else
        EJP_H_R22V = EjFpoly(-2720.182, 18.11784, -0.02699451, T)
    End If
End Function

Public Function EJP_H_DMF(T_C As Double) As Double
    EJP_H_DMF = EjFpoly(-352.2493, 1.317081, 0.001239553, T_C + 273.15)
End Function

Private Function EjHFatouh(T_C As Double, xi As Double) As Double
    Dim B(0 To 3) As Double, C(0 To 3) As Double
    Dim E1 As Double, E2 As Double, E3 As Double
    Dim T As Double, T2 As Double, T3 As Double, omx As Double
    Dim Y0 As Double, Y1 As Double, Y2 As Double, Y3 As Double
    Dim K0 As Double, K1 As Double, K2 As Double, K3 As Double
    Dim Mmix As Double, hmix As Double
    B(0) = -1817.206: B(1) = -4302.679: B(2) = 9877.574: B(3) = 0
    C(0) = -135585.8: C(1) = 625797.9: C(2) = -1435546#: C(3) = 0
    E1 = -7738.2052: E2 = 0.0562768: E3 = -34.79
    T = T_C + 273.15: T2 = T * T: T3 = T2 * T: omx = 1 - xi
    Y0 = xi / omx
    Y1 = xi / omx + Log(omx)
    Y2 = 1 / omx - omx + 2 * Log(omx)
    Y3 = xi / omx + xi * xi / 2 + 2 * xi + 3 * Log(omx)
    K0 = B(0) / T2 + 2 * C(0) / T3 - E1 / T2 + E2 + E3 / T
    K1 = B(1) / T2 + 2 * C(1) / T3
    K2 = B(2) / T2 + 2 * C(2) / T3
    K3 = B(3) / T2 + 2 * C(3) / T3
    Mmix = xi * 86.47 + omx * 73.09
    hmix = (omx * 8.314 * T2 / Mmix) * (K0 * Y0 + K1 * Y1 + K2 * Y2 + K3 * Y3)
    EjHFatouh = xi * EJP_H_R22L(T_C) + omx * EJP_H_DMF(T_C) + hmix
End Function

' Solution enthalpy [kJ/kg].
Public Function EJP_Hsol(T_C As Double, xi As Double) As Double
    Dim h09 As Double
    If xi <= 0 Then EJP_Hsol = EJP_H_DMF(T_C): Exit Function
    If xi >= 1 Then EJP_Hsol = EJP_H_R22L(T_C): Exit Function
    If xi <= 0.9 Then EJP_Hsol = EjHFatouh(T_C, xi): Exit Function
    h09 = EjHFatouh(T_C, 0.9)
    EJP_Hsol = h09 + (xi - 0.9) / 0.1 * (EJP_H_R22L(T_C) - h09)
End Function

' ---------- ejector model ----------
' Isentropic lift work of the vapour [kJ/kg]. Ts_C = suction vapour temp.
Public Function Ej_Wisen(Ps_MPa As Double, Pd_MPa As Double, Ts_C As Double) As Double
    Dim pi As Double, Ts As Double
    pi = Pd_MPa / Ps_MPa: Ts = Ts_C + 273.15
    Ej_Wisen = EJ_KAPPA / (EJ_KAPPA - 1) * EJ_RS * Ts * _
               (pi ^ ((EJ_KAPPA - 1) / EJ_KAPPA) - 1) / 1000
End Function

' Ideal-gas vapour density [kg/m3] (pure R22; DMF vapour neglected).
Public Function Ej_RhoVap(P_MPa As Double, T_C As Double) As Double
    Ej_RhoVap = P_MPa * 1000000# / (EJ_RS * (T_C + 273.15))
End Function

' Minimum motive ratio ml [kg liquid / kg vapour] from the diffuser
' recovery condition. Tmix_C = temperature used for the vapour density
' inside the mixture (engineering estimate).
Public Function Ej_MinMotive(Pm_MPa As Double, Ps_MPa As Double, Pd_MPa As Double, _
                             Tmix_C As Double, rho_l As Double, _
                             phi_n As Double, eta_d As Double) As Double
    Dim Pm As Double, Ps As Double, Pd As Double
    Dim rho_vd As Double, vj As Double
    Dim lo As Double, hi As Double, mid As Double
    Dim vm As Double, rho_m As Double, i As Long
    Pm = Pm_MPa * 1000000#: Ps = Ps_MPa * 1000000#: Pd = Pd_MPa * 1000000#
    rho_vd = Ej_RhoVap(Pd_MPa, Tmix_C)
    vj = phi_n * Sqr(2 * (Pm - Ps) / rho_l)
    lo = 0.3: hi = 5000#
    For i = 1 To 100
        mid = 0.5 * (lo + hi)
        vm = mid * vj / (mid + 1)
        rho_m = (mid + 1) / (mid / rho_l + 1 / rho_vd)
        If eta_d * 0.5 * rho_m * vm * vm >= Pd - Ps Then hi = mid Else lo = mid
    Next i
    Ej_MinMotive = hi
End Function

' Pump shaft work per kg of entrained vapour [kJ/kg].
' Pump draws solution from the discharge vessel (Pd) up to Pm.
Public Function Ej_PumpWork(ml As Double, Pm_MPa As Double, Pd_MPa As Double, _
                            rho_l As Double, eta_p As Double) As Double
    Ej_PumpWork = ml * (Pm_MPa - Pd_MPa) * 1000000# / (rho_l * eta_p) / 1000
End Function

' Adiabatic outlet liquid temperature [degC]: ml kg of solution
' (Tliq_C, xi_l) absorbs 1 kg of R22 vapour (Tvap_C); pump work W_kJ
' (per kg vapour) ends up as heat in the liquid.
Public Function Ej_Tout(ml As Double, Tliq_C As Double, xi_l As Double, _
                        Tvap_C As Double, W_kJ As Double) As Double
    Dim xi_out As Double, Hin As Double
    Dim lo As Double, hi As Double, mid As Double, i As Long
    xi_out = (xi_l * ml + 1) / (ml + 1)
    Hin = ml * EJP_Hsol(Tliq_C, xi_l) + EJP_H_R22V(Tvap_C) + W_kJ
    lo = Tliq_C: hi = Tliq_C + 80
    For i = 1 To 80
        mid = 0.5 * (lo + hi)
        If (ml + 1) * EJP_Hsol(mid, xi_out) < Hin Then lo = mid Else hi = mid
    Next i
    Ej_Tout = 0.5 * (lo + hi)
End Function

' ---------- verification against the two calculation notes ----------
Public Sub TestEjectorPump()
    Dim Ps As Double, Pd As Double, wis As Double
    Dim ml As Double, W As Double
    ' Note 1: liquid xi=0.40 @ 5C, vapour source xi=0.20 @ 30C, rho_l=1100
    Ps = EJP_BubbleP(30, 0.2): Pd = EJP_BubbleP(5, 0.4)
    wis = Ej_Wisen(Ps, Pd, 30)
    Debug.Print "Note 1: Ps="; Ps; " Pd="; Pd; " pi="; Pd / Ps; " w_is="; wis
    ml = Ej_MinMotive(0.9, Ps, Pd, 9.85, 1100, 0.95, 0.85)
    W = Ej_PumpWork(ml, 0.9, Pd, 1100, 0.75)
    Debug.Print "  Pm=0.9 MPa: ml="; ml; " W="; W; " eta="; wis / W
    W = Ej_PumpWork(9, 0.9, Pd, 1100, 0.75)
    Debug.Print "  Design ml=9, Pm=0.9 MPa: W="; W; " eta="; wis / W
    ' Note 2: liquid xi=0.40 @ 18C, vapour source xi=0.20 @ 42C, rho_l=1075
    Ps = EJP_BubbleP(42, 0.2): Pd = EJP_BubbleP(18, 0.4)
    wis = Ej_Wisen(Ps, Pd, 42)
    Debug.Print "Note 2: Ps="; Ps; " Pd="; Pd; " pi="; Pd / Ps; " w_is="; wis
    ml = Ej_MinMotive(0.4, Ps, Pd, 23.85, 1075, 0.95, 0.85)
    W = Ej_PumpWork(ml, 0.4, Pd, 1075, 0.75)
    Debug.Print "  Pm=0.4 MPa: ml="; ml; " W="; W; " eta="; wis / W; _
                " T_out="; Ej_Tout(ml, 18, 0.4, 42, W)
End Sub

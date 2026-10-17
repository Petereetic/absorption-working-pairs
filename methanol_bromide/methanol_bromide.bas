Attribute VB_Name = "MethanolBromide"
' Thermodynamic correlations for methanol / (2LiBr-ZnBr2) (Excel VBA worksheet functions)
' Source: S. El-Shamarka, PhD thesis, Cranfield Institute of Technology, 1981.
' System: the salt ratio is fixed at LiBr:ZnBr2 = 2:1 (molar); w is the methanol mass fraction; the salt is non-volatile.
'   Eq. (3.1) Bubble-point pressure: log10 P[mbar] = C1(w) + C2(w)·(1000/T[K] - 2.3)
'           C1 and C2 are the 8 node values of Table 3.3; between nodes, shape-preserving PCHIP interpolation.
'           The -C2 of Table 3.3 at w=28.0% (2.7278) breaks monotonicity (2.8197 at 30.1%);
'           printed as in the original table; PCHIP has zero slope there and produces no overshoot.
'   Eq. (3.4) Specific heat: Cp = A + B·t[°C], A = 0.652 + 2.139w - 2.077w^2,
'           B = -0.000205 + 0.00928w - 0.0101w^2.
'           Sign of the last term: in the original formula on p.86 it is an overprinted glyph; the restatement in Appendix A prints "-", and taking "-"
'           gives a max deviation of only 0.7% against the measured specific heats of Table 3.7 of the thesis (taking "+" gives 6%~14%); so "-" is taken.
'   Appendix A enthalpy of vaporisation H' (including the heat of mixing): H' = A + B·w + C·w^2, where A/B/C are quadratics in T;
'           T is in kelvin (never use °C); valid only for w=0.25~0.356; extrapolation forbidden.
' The density and viscosity (MB_RhoIedema / MB_EtaIedema) are from another source, unrelated to the above:
'   P. D. Iedema, PhD thesis, TU Delft, 1984 (same system, LiBr/ZnBr2-methanol).
'   Density (Table 2.7.2.2.2): rho = [rho25(w) + rho'(w)·(t-25)]·(1 + 0.32·w_H),
'           rho25 and rho' are cubics in w; t in °C; w is the total solvent mass fraction
'           (methanol + water; for a dry solution it is the methanol mass fraction), w_H is the water mass fraction.
'           Valid w=0.28~0.42, t=-10~140 °C; the author states a mean deviation of 0.13%.
'   Viscosity (Table 2.7.3): ln eta = eta0(w) + etaT(w)/T, eta in Pa·s, T in K,
'           eta0 and etaT are cubics in w. Valid w=0.28~1.0, t=20~120 °C.
'           In the original table the last term of etaT is printed as w^4 and the coefficient subscript is mislabelled; ruled by 9 measured points,
'           the w^3 reading is taken (mean deviation 2.8%, matching the author's own claim; the w^4 reading deviates by 36%).
'   Note: El-Shamarka's own density Eq. (4.10) and viscosity Eq. (4.11) are still unverified; this module
'   does not implement them; do not confuse them with the Iedema correlations above (see the formula notes file).
' Reference state (a convention of this document; the thesis defines no absolute datum):
'   hsol(0°C, any w) = 100 kJ/kg; hgas = hsol + H'.
'
' Pressure unit (library-wide unification of 2026-10-14): public functions return/accept MPa; internal native
' computation is in bar (private functions PsolBar / TbubBar and MeohPrefBar /
' MeohTsatBar); public functions only scale at the boundary (MPa = bar x0.1; MPa inputs x10
' back to bar).
'
' Worksheet functions:
'   =MB_Psol(T_K, w)    bubble-point pressure, MPa
'   =MB_Tbub(P_MPa, w)  bubble-point temperature, K
'   =MB_Cp(T_K, w)      solution specific heat, kJ/(kg·K)
'   =MB_Hprime(T_K, w)  enthalpy of vaporisation H', kJ/kg (only w=0.25~0.356)
'   =MB_hsol(T_K, w)    solution specific enthalpy, kJ/kg
'   =MB_hgas(T_K, w)    vapour-phase specific enthalpy, kJ/kg
'   =MB_RhoIedema(T_K, w, w_H)  density (Iedema 1984), kg/m3
'   =MB_EtaIedema(T_K, w)       dynamic viscosity (Iedema 1984), Pa·s
'   =MB_XiByTsolTdew(Tdew_K, Tsol_K)  solves w back from the dew-point temperature and the solution temperature; returns Empty when there is no root
'
' Note: this module has not been compiled or run in real Excel; compile and verify before use.

Option Explicit

' Table 3.3 (p.74) nodes: methanol mass fractions
Private Function NodeW(ByVal i As Long) As Double
    Select Case i
        Case 0: NodeW = 0.243
        Case 1: NodeW = 0.25
        Case 2: NodeW = 0.262
        Case 3: NodeW = 0.28
        Case 4: NodeW = 0.301
        Case 5: NodeW = 0.356
        Case 6: NodeW = 0.403
        Case 7: NodeW = 0.509
    End Select
End Function

Private Function NodeC1(ByVal i As Long) As Double
    Select Case i
        Case 0: NodeC1 = 2.6712
        Case 1: NodeC1 = 2.8572
        Case 2: NodeC1 = 2.9758
        Case 3: NodeC1 = 3.0535
        Case 4: NodeC1 = 3.3146
        Case 5: NodeC1 = 3.4604
        Case 6: NodeC1 = 3.777
        Case 7: NodeC1 = 4.0494
    End Select
End Function

Private Function NodeC2(ByVal i As Long) As Double
    Select Case i
        Case 0: NodeC2 = -3.0602
        Case 1: NodeC2 = -3.0344
        Case 2: NodeC2 = -2.9531
        Case 3: NodeC2 = -2.7278
        Case 4: NodeC2 = -2.8197
        Case 5: NodeC2 = -2.6219
        Case 6: NodeC2 = -2.4256
        Case 7: NodeC2 = -2.0194
    End Select
End Function

Private Function PchipEndSlope(ByVal h0 As Double, ByVal h1 As Double, _
                               ByVal d0 As Double, ByVal d1 As Double) As Double
    Dim m As Double
    m = ((2# * h0 + h1) * d0 - h0 * d1) / (h0 + h1)
    If m * d0 <= 0# Then
        PchipEndSlope = 0#
    ElseIf d0 * d1 < 0# And Abs(m) > Abs(3# * d0) Then
        PchipEndSlope = 3# * d0
    Else
        PchipEndSlope = m
    End If
End Function

' Fritsch-Carlson PCHIP; which=1 takes C1, which=2 takes C2
Private Function PchipEval(ByVal which As Long, ByVal w As Double) As Double
    Dim xs(0 To 7) As Double, ys(0 To 7) As Double
    Dim h(0 To 6) As Double, d(0 To 6) As Double, m(0 To 7) As Double
    Dim i As Long, lo As Long, hi As Long, mid As Long
    Dim w1 As Double, w2 As Double, s As Double, s2 As Double, s3 As Double
    For i = 0 To 7
        xs(i) = NodeW(i)
        If which = 1 Then ys(i) = NodeC1(i) Else ys(i) = NodeC2(i)
    Next i
    For i = 0 To 6
        h(i) = xs(i + 1) - xs(i)
        d(i) = (ys(i + 1) - ys(i)) / h(i)
    Next i
    For i = 1 To 6
        If d(i - 1) * d(i) <= 0# Then
            m(i) = 0#
        Else
            w1 = 2# * h(i) + h(i - 1)
            w2 = h(i) + 2# * h(i - 1)
            m(i) = (w1 + w2) / (w1 / d(i - 1) + w2 / d(i))
        End If
    Next i
    m(0) = PchipEndSlope(h(0), h(1), d(0), d(1))
    m(7) = PchipEndSlope(h(6), h(5), d(6), d(5))
    If w <= xs(0) Then
        i = 0
    ElseIf w >= xs(7) Then
        i = 6
    Else
        lo = 0: hi = 7
        Do While hi - lo > 1
            mid = (lo + hi) \ 2
            If xs(mid) <= w Then lo = mid Else hi = mid
        Loop
        i = lo
    End If
    s = (w - xs(i)) / h(i)
    s2 = s * s: s3 = s2 * s
    PchipEval = (2# * s3 - 3# * s2 + 1#) * ys(i) _
              + h(i) * (s3 - 2# * s2 + s) * m(i) _
              + (3# * s2 - 2# * s3) * ys(i + 1) _
              + h(i) * (s3 - s2) * m(i + 1)
End Function

Private Sub CpAB(ByVal w As Double, ByRef A As Double, ByRef B As Double)
    A = 0.652 + 2.139 * w - 2.077 * w * w
    B = -0.000205 + 0.00928 * w - 0.0101 * w * w
End Sub

' Eq. (3.1) native value (private): bubble-point pressure, bar
Private Function PsolBar(ByVal T_K As Double, ByVal w As Double) As Double
    Dim log10p As Double
    log10p = PchipEval(1, w) + PchipEval(2, w) * (1000# / T_K - 2.3)
    PsolBar = 10# ^ log10p / 1000#
End Function

' Eq. (3.1): bubble-point pressure, MPa
Public Function MB_Psol(ByVal T_K As Double, ByVal w As Double) As Double
    MB_Psol = PsolBar(T_K, w) * 0.1
End Function

' Eq. (3.1) analytic inverse, native value (private): bubble-point temperature, K; P_bar in bar
Private Function TbubBar(ByVal P_bar As Double, ByVal w As Double) As Double
    Dim log10p As Double
    log10p = Log(P_bar * 1000#) / Log(10#)
    TbubBar = 1000# / ((log10p - PchipEval(1, w)) / PchipEval(2, w) + 2.3)
End Function

' Eq. (3.1) analytic inverse: bubble-point temperature, K; P_MPa in MPa
Public Function MB_Tbub(ByVal P_MPa As Double, ByVal w As Double) As Double
    MB_Tbub = TbubBar(P_MPa * 10#, w)
End Function

' Pure-methanol saturation pressure (private helper, native bar; same constants as _meoh_pref_bar of the Python version):
' Antoine fit to the table in Appendix A of the thesis: log10 P[mmHg] = 8.885298 - 2070.3714/(T[K] + 6.3818)
Private Function MeohPrefBar(ByVal T_K As Double) As Double
    MeohPrefBar = 10# ^ (8.885298 - 2070.3714 / (T_K + 6.3818)) * 0.0013332239
End Function

' Solve the methanol mass fraction w back from the dew-point temperature and the solution temperature:
' the dew point fixes the pressure P = MeohPrefBar(Tdew_K) (internal native value in bar; the salt is non-volatile,
' the vapour phase is pure methanol); then 80 bisection steps invert PsolBar(Tsol_K, w) = P,
' with the bracket taken as the bubble-point function's valid concentration domain w = 0.243~0.509.
' Returns Empty when there is no root (e.g. the solution temperature clearly below the dew-point temperature).
' Same algorithm as C/Python; this function has not been compiled or run in real Excel.
Public Function MB_XiByTsolTdew(ByVal Tsol_K As Double, ByVal Tdew_K As Double) As Variant
    Dim P As Double, lo As Double, hi As Double, mid As Double, k As Long
    P = MeohPrefBar(Tdew_K)
    If P < PsolBar(Tsol_K, 0.243) Or P > PsolBar(Tsol_K, 0.509) Then
        MB_XiByTsolTdew = Empty
        Exit Function
    End If
    lo = 0.243: hi = 0.509
    For k = 1 To 80
        mid = 0.5 * (lo + hi)
        If PsolBar(Tsol_K, mid) < P Then lo = mid Else hi = mid
    Next k
    MB_XiByTsolTdew = 0.5 * (lo + hi)
End Function


' Pure-methanol saturation temperature [K] (private helper, native bar): analytic inverse of MeohPrefBar,
' same formula as _meoh_Tsat_bar of the Python version.
Private Function MeohTsatBar(ByVal P_bar As Double) As Double
    MeohTsatBar = 2070.3714 / (8.885298 - Log(P_bar / 0.0013332239) / Log(10#)) - 6.3818
End Function

' Dew-point temperature [K] of the solution at (T_K, w) (library-wide TdewByTsolXi convention):
' Tdew = MeohTsatBar(PsolBar(T_K, w)) (internally via the native-bar private functions;
' the public convention is MPa), evaluating the solution surface pressure Psol with this module's own pure-methanol line.
' The salt is non-volatile; the vapour phase is pure methanol.
Public Function MB_TdewByTsolW(ByVal T_K As Double, ByVal w As Double) As Double
    MB_TdewByTsolW = MeohTsatBar(PsolBar(T_K, w))
End Function

' Solve the solution temperature [K] back from the solution specific enthalpy h [kJ/kg] and methanol mass fraction w:
' MB_hsol increases monotonically with T at fixed w; inverted by 100 bisection steps,
' with the solution bracket T in [233.15, 423.15] K. Returns Empty when h is outside the range.
' Same algorithm as C/Python; this function has not been compiled or run in real Excel.
Public Function MB_TsolByHsol(ByVal h As Double, ByVal w As Double) As Variant
    Dim lo As Double, hi As Double, mid As Double, k As Long
    lo = 233.15: hi = 423.15
    If h < MB_hsol(lo, w) Or h > MB_hsol(hi, w) Then
        MB_TsolByHsol = Empty: Exit Function
    End If
    For k = 1 To 100
        mid = 0.5 * (lo + hi)
        If MB_hsol(mid, w) < h Then lo = mid Else hi = mid
    Next k
    MB_TsolByHsol = 0.5 * (lo + hi)
End Function

' Eq. (3.4): solution specific heat, kJ/(kg·K)
Public Function MB_Cp(ByVal T_K As Double, ByVal w As Double) As Double
    Dim A As Double, B As Double
    CpAB w, A, B
    MB_Cp = A + B * (T_K - 273.15)
End Function

' Appendix A: enthalpy of vaporisation H' (including the heat of mixing), kJ/kg; T_K in kelvin; only w=0.25~0.356
Public Function MB_Hprime(ByVal T_K As Double, ByVal w As Double) As Double
    Dim A As Double, B As Double, C As Double
    A = 2202.6 + 9.24 * T_K - 0.0218 * T_K * T_K
    B = -(4417.8 + 15.53 * T_K - 0.0392 * T_K * T_K)
    C = 3570# + 10.81 * T_K - 0.0294 * T_K * T_K
    MB_Hprime = A + B * w + C * w * w
End Function

' Solution specific enthalpy, kJ/kg; reference-state convention hsol(0°C) = 100 kJ/kg
Public Function MB_hsol(ByVal T_K As Double, ByVal w As Double) As Double
    Dim A As Double, B As Double, t As Double
    CpAB w, A, B
    t = T_K - 273.15
    MB_hsol = 100# + A * t + B * t * t / 2#
End Function

' Vapour-phase specific enthalpy, kJ/kg: hgas = hsol + H'
Public Function MB_hgas(ByVal T_K As Double, ByVal w As Double) As Double
    MB_hgas = MB_hsol(T_K, w) + MB_Hprime(T_K, w)
End Function

' Iedema Table 2.7.2.2.2: density, kg/m3. T_K in kelvin (converted internally to t[°C]);
' w is the total solvent mass fraction w_t (methanol + water), w_H is the water mass fraction;
' for a dry solution (w_H=0), w_t is the methanol mass fraction. Valid w=0.28~0.42, t=-10~140 °C
Public Function MB_RhoIedema(ByVal T_K As Double, ByVal w As Double, _
                             ByVal w_H As Double) As Double
    Dim t As Double, rho25 As Double, drho As Double
    t = T_K - 273.15
    rho25 = 3026.745 - 5369.24 * w + 4082.056 * w * w + 103.8639 * w * w * w
    drho = -0.0997537 - 11.77377 * w + 42.24796 * w * w - 44.70839 * w * w * w
    MB_RhoIedema = (rho25 + drho * (t - 25#)) * (1# + 0.32 * w_H)
End Function

' Iedema Table 2.7.3: dynamic viscosity, Pa·s; ln eta = eta0(w) + etaT(w)/T_K.
' The last term takes the w^3 reading (ruling basis in the module header). Valid w=0.28~1.0, t=20~120 °C
Public Function MB_EtaIedema(ByVal T_K As Double, ByVal w As Double) As Double
    Dim eta0 As Double, etaT As Double
    eta0 = -18.29756 + 26.2373 * w - 33.51444 * w * w + 13.86405 * w * w * w
    etaT = 5481.757 - 11371.61 * w + 10873.4 * w * w - 3718.145 * w * w * w
    MB_EtaIedema = Exp(eta0 + etaT / T_K)
End Function

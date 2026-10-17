Attribute VB_Name = "R22DMF"
'==============================================================================
' R22-DMF bubble-point pressure and solution enthalpy - Excel worksheet functions
' Bubble-point pressure: fitted to the Agarwal (1982) VLE data (transcribed via the appendix of the Ardita thesis, 132 points, xi>=0.10),
'   stratified by concentration, with the Antoine form ln(P/bar)=A+B/T+C*ln(T) (T in K),
'   then shape-preserving monotone PCHIP interpolation over the R22 mass fraction xi. AARD 2.38%, maximum 9.6%.
'   Valid: T -25~120 C, xi 0.10~1.00 (for xi>0.80 and T>65C it is an extrapolation; use with care).
' Solution enthalpy: the correlation of Fatouh et al. 1993 (Eqs. 2.38-2.43 of the Ardita thesis), kJ/kg,
'   reference state: saturated liquid at 273.15K = 100 kJ/kg. Valid approx. T -20~95C.
' Usage: =Psol_R22DMF(40, 0.5)   -> bubble-point pressure MPa
'       =BubbleT_R22DMF(0.38, 0.5)  -> bubble-point temperature C
'       =XiByTsolTdew_R22DMF(0, 60)  -> solves the concentration xi back from the dew-point/solution temperatures
'       =hsol_R22DMF(30, 0.5)      -> solution enthalpy kJ/kg
'==============================================================================
Option Explicit

Private Const NISO As Long = 10

Private Function IsoXi(i As Long) As Double
    Dim v As Variant
    v = Array(0.1, 0.23076, 0.32, 0.40348, 0.5, 0.6022, 0.7, 0.8, 0.9, 1#)
    IsoXi = v(i)
End Function
Private Function IsoA(i As Long) As Double
    Dim v As Variant
    v = Array(30.772744, 10.400862, 10.271208, -5.84816, 39.598401, _
              27.566449, 28.096798, 51.969188, 99.166678, 18.47413)
    IsoA = v(i)
End Function
Private Function IsoB(i As Long) As Double
    Dim v As Variant
    v = Array(-3182.9395, -2459.9752, -2405.5462, -1618.6504, -3709.7856, _
              -3089.5702, -3022.7056, -4223.6822, -6197.2, -2766.7568)
    IsoB = v(i)
End Function
Private Function IsoC(i As Long) As Double
    Dim v As Variant
    v = Array(-3.629138, -0.388685, -0.311415, 2.088399, -4.591025, _
              -2.81985, -2.907606, -6.297351, -13.369886, -1.197267)
    IsoC = v(i)
End Function

' Internal: at a given T(K), PCHIP over xi for the bubble-point pressure
Private Function Psol_K(T As Double, xi As Double) As Double
    Dim x(9) As Double, y(9) As Double, h(8) As Double, d(8) As Double, dk(9) As Double
    Dim i As Long, k As Long, xc As Double, lnT As Double, t As Double, t2 As Double, t3 As Double
    xc = xi
    If xc < 0.1 Then xc = 0.1
    If xc > 1# Then xc = 1#
    lnT = Log(T)
    For i = 0 To 9
        x(i) = IsoXi(i)
        y(i) = Exp(IsoA(i) + IsoB(i) / T + IsoC(i) * lnT)
    Next i
    For i = 0 To 8
        h(i) = x(i + 1) - x(i)
        d(i) = (y(i + 1) - y(i)) / h(i)
    Next i
    dk(0) = d(0): dk(9) = d(8)
    For k = 1 To 8
        If d(k - 1) * d(k) <= 0 Then
            dk(k) = 0
        Else
            Dim w1 As Double, w2 As Double
            w1 = 2 * h(k) + h(k - 1): w2 = h(k) + 2 * h(k - 1)
            dk(k) = (w1 + w2) / (w1 / d(k - 1) + w2 / d(k))
        End If
    Next k
    k = 0
    Do While k < 8 And xc > x(k + 1)
        k = k + 1
    Loop
    t = (xc - x(k)) / h(k): t2 = t * t: t3 = t2 * t
    Psol_K = (2 * t3 - 3 * t2 + 1) * y(k) + (t3 - 2 * t2 + t) * h(k) * dk(k) _
              + (-2 * t3 + 3 * t2) * y(k + 1) + (t3 - t2) * h(k) * dk(k + 1)
End Function

Public Function Psol_R22DMF(T_C As Double, xi As Double) As Double
    ' Bubble-point pressure MPa; T_C in °C, xi is the R22 mass fraction (internally Psol_K is the native value in bar; x0.1 at the exit)
    Psol_R22DMF = Psol_K(T_C + 273.15, xi) * 0.1
End Function

' Internal: back-calculate the bubble-point temperature in °C from the native pressure in bar (bisection); returns #N/A when out of range
Private Function BubbleT_K(P_bar As Double, xi As Double) As Variant
    Dim lo As Double, hi As Double, mid As Double, i As Long
    lo = -25#: hi = 120#
    If P_bar < Psol_K(lo + 273.15, xi) Or P_bar > Psol_K(hi + 273.15, xi) Then
        BubbleT_K = CVErr(xlErrNA): Exit Function
    End If
    For i = 1 To 60
        mid = 0.5 * (lo + hi)
        If Psol_K(mid + 273.15, xi) < P_bar Then lo = mid Else hi = mid
    Next i
    BubbleT_K = 0.5 * (lo + hi)
End Function

Public Function BubbleT_R22DMF(P_MPa As Double, xi As Double) As Variant
    ' Bubble-point temperature in °C (back-calculated by bisection); the input P_MPa is in MPa (x10 back to bar at the entry); returns #N/A when out of range
    BubbleT_R22DMF = BubbleT_K(P_MPa * 10#, xi)
End Function

Public Function XiByTsolTdew_R22DMF(Tsol_C As Double, Tdew_C As Double) As Variant
    ' Solve the concentration xi (R22 mass fraction) back from the dew-point temperature and the solution temperature:
    ' the dew point fixes the pressure P = the pure-R22 saturation pressure (this module's xi=1.0 iso-concentration line; DMF treated as non-volatile),
    ' then bisection (80 steps) solves Psol(Tsol, xi) = P, with the bracket taken as the bubble-point valid concentration domain 0.10~1.00.
    ' Returns Empty when there is no root (P outside the span of bubble-point pressures at Tsol, e.g. the solution temperature below the dew-point temperature).
    ' Note: same algorithm as C/Python; this VBA has not been compile-tested in real Excel.
    Dim P As Double, lo As Double, hi As Double, mid As Double, i As Long
    P = Psol_K(Tdew_C + 273.15, 1#)
    If P < Psol_K(Tsol_C + 273.15, 0.1) Or P > Psol_K(Tsol_C + 273.15, 1#) Then
        XiByTsolTdew_R22DMF = Empty: Exit Function
    End If
    lo = 0.1: hi = 1#
    For i = 1 To 80
        mid = 0.5 * (lo + hi)
        If Psol_K(Tsol_C + 273.15, mid) < P Then lo = mid Else hi = mid
    Next i
    XiByTsolTdew_R22DMF = 0.5 * (lo + hi)
End Function


' ---------- Dew-point temperature (solution) [°C]: library-wide TdewByTsolXi convention ----------
' Tdew = BubbleT_K(Psol_K(T_C + 273.15, xi), 1) (internally via the native-bar private functions,
' equivalent to the original composite path BubbleT_R22DMF(Psol_R22DMF(...))): the saturation temperature corresponding to the solution
' surface pressure Psol, evaluated with this module's own pure-R22 iso-concentration line (the xi=1 end).
' DMF is treated as non-volatile. When there is no root, it returns #N/A along with BubbleT_K.
Public Function TdewByTsolXi_R22DMF(T_C As Double, xi As Double) As Variant
    TdewByTsolXi_R22DMF = BubbleT_K(Psol_K(T_C + 273.15, xi), 1#)
End Function

' ---------- Solve the solution temperature [°C] back from the solution specific enthalpy ----------
' hsol_R22DMF increases monotonically with T at fixed xi; inverted by 100 bisection steps,
' with the solution bracket T in [-20, 95] °C. Returns Empty when h is outside the range.
' Same algorithm as C/Python; this function has not been compiled or run in real Excel.
Public Function TsolByHsol_R22DMF(h As Double, xi As Double) As Variant
    Dim lo As Double, hi As Double, mid As Double, k As Long
    lo = -20#: hi = 95#
    If h < hsol_R22DMF(lo, xi) Or h > hsol_R22DMF(hi, xi) Then
        TsolByHsol_R22DMF = Empty: Exit Function
    End If
    For k = 1 To 100
        mid = 0.5 * (lo + hi)
        If hsol_R22DMF(mid, xi) < h Then lo = mid Else hi = mid
    Next k
    TsolByHsol_R22DMF = 0.5 * (lo + hi)
End Function

Private Function FPoly(F0 As Double, F1 As Double, F2 As Double, T As Double) As Double
    FPoly = F0 + F1 * T + F2 * T * T   ' T in K
End Function

Public Function hliq_R22_R22DMF(T_C As Double) As Double
    Dim T As Double: T = T_C + 273.15
    If T < 323.15 Then hliq_R22_R22DMF = FPoly(-68.1484, 0.06313, 0.00202, T) _
    Else hliq_R22_R22DMF = FPoly(1966.645, -12.09784, 0.02018352, T)
End Function

Public Function hgas_R22_R22DMF(T_C As Double) As Double
    Dim T As Double: T = T_C + 273.15
    If T < 323.15 Then hgas_R22_R22DMF = FPoly(37.22971, 1.59952, -0.002260308, T) _
    Else hgas_R22_R22DMF = FPoly(-2720.182, 18.11784, -0.02699451, T)
End Function

Public Function H_DMF_R22DMF(T_C As Double) As Double
    H_DMF_R22DMF = FPoly(-352.2493, 1.317081, 0.001239553, T_C + 273.15)
End Function

Private Function H_Fatouh(T_C As Double, xi As Double) As Double
    ' Original Fatouh correlation (valid for xi<=0.9; hmix does not go to zero at xi=1)
    Dim T As Double, T2 As Double, T3 As Double, omx As Double
    Dim Y0 As Double, Y1 As Double, Y2 As Double, Y3 As Double
    Dim K0 As Double, K1 As Double, K2 As Double, K3 As Double
    Dim Mmix As Double, hmix As Double
    Const B0 = -1817.206, B1 = -4302.679, B2 = 9877.574
    Const C0 = -135585.8, C1 = 625797.9, C2 = -1435546#
    Const E1 = -7738.2052, E2 = 0.0562768, E3 = -34.79
    Const MR22 = 86.47, MDMF = 73.09, RR = 8.314
    T = T_C + 273.15: T2 = T * T: T3 = T2 * T
    omx = 1 - xi
    Y0 = xi / omx
    Y1 = xi / omx + Log(omx)
    Y2 = 1 / omx - omx + 2 * Log(omx)
    Y3 = xi / omx + xi * xi / 2 + 2 * xi + 3 * Log(omx)
    K0 = B0 / T2 + 2 * C0 / T3 - E1 / T2 + E2 + E3 / T
    K1 = B1 / T2 + 2 * C1 / T3
    K2 = B2 / T2 + 2 * C2 / T3
    K3 = 0
    Mmix = xi * MR22 + omx * MDMF
    hmix = (omx * RR * T2 / Mmix) * (K0 * Y0 + K1 * Y1 + K2 * Y2 + K3 * Y3)
    H_Fatouh = xi * hliq_R22_R22DMF(T_C) + omx * H_DMF_R22DMF(T_C) + hmix
End Function

Public Function hsol_R22DMF(T_C As Double, xi As Double) As Double
    ' R22-DMF solution enthalpy kJ/kg; for 0.9<xi<1, a linear transition to pure R22 (ensuring continuity at xi=1)
    Dim h09 As Double
    If xi <= 0 Then hsol_R22DMF = H_DMF_R22DMF(T_C): Exit Function
    If xi >= 1 Then hsol_R22DMF = hliq_R22_R22DMF(T_C): Exit Function
    If xi <= 0.9 Then hsol_R22DMF = H_Fatouh(T_C, xi): Exit Function
    h09 = H_Fatouh(T_C, 0.9)
    hsol_R22DMF = h09 + (xi - 0.9) / 0.1 * (hliq_R22_R22DMF(T_C) - h09)
End Function

' R124-DMAC working pair: bubble pressure, solution enthalpy, density,
' viscosity. Transcribed from Borde, Jelinek & Daltrophe, Int. J.
' Refrigeration 20(4), 256-266, 1997.
'
' Conventions: T_C in degC, xi = R124 mass fraction, P in bar,
' h in kJ/kg (reference: pure liquids = 100 kJ/kg at 0 degC),
' rho in kg/m3, eta in mPa s.
'
' Two printed values are corrected on documented evidence (see the
' verification record in this folder): Table 9 rho_00 exponent
' (E+01 -> E+00) and Table 8 DMAC eta0/eta1 (x10 too large as printed).
' NOTE: Eq. (16) runs +13..+23 % above Eq. (15) at xi = 1 (property of
' the printed fit); use Pref_R124DMAC near xi = 1.
' NOTE: this VBA has NOT been compiled/tested in real Excel.

Option Explicit

Private Function PsatEq15(A As Double, B As Double, C As Double, _
                          D As Double, E As Double, F As Double, _
                          T_C As Double) As Double
    Dim T As Double
    T = T_C + 273.15
    PsatEq15 = Exp(A + B / (T + C) + D * T + E * Log(T) + F * T * T)
End Function

Public Function Pref_R124DMAC(T_C As Double) As Double
    Pref_R124DMAC = PsatEq15(-119.33446, -1351.341, 0#, -0.12497, 27.21197, 0.0000832656, T_C)
End Function

Public Function PsatDMAC_R124DMAC(T_C As Double) As Double
    PsatDMAC_R124DMAC = PsatEq15(6.01834, -1800.24, -138.5, 0#, 0#, 0#, T_C)
End Function

Public Function DewT_R124DMAC(P_bar As Double) As Variant
    Dim lo As Double, hi As Double, mid As Double, k As Long
    lo = -60#: hi = 120#
    If P_bar < Pref_R124DMAC(lo) Or P_bar > Pref_R124DMAC(hi) Then
        DewT_R124DMAC = Empty
        Exit Function
    End If
    For k = 1 To 80
        mid = 0.5 * (lo + hi)
        If Pref_R124DMAC(mid) < P_bar Then lo = mid Else hi = mid
    Next k
    DewT_R124DMAC = 0.5 * (lo + hi)
End Function

Private Function PCoef() As Variant
    PCoef = Array( _
        Array(0.011502, -28.24, 41.188, -26.168, 0#, 183.81, -311.9, 139.14), _
        Array(-0.013711, 0.24179, -0.26951, 0#, 0#, 0.075999, 0#, 0#), _
        Array(0.000091911, 0#, 0#, 0#, 0#, 0#, 0#, 0#), _
        Array(0#, -0.0000031564, 0.00000092677, 0.0000078191, -0.00001331, 0#, 0.000012701, -0.0000065958), _
        Array(-8.6519E-10, 0#, 0#, 0#, 0#, 0#, 0#, 0#), _
        Array(0#, 2.2998E-11, 0#, 0#, 0#, 3.3233E-11, 0#, -2.4081E-11), _
        Array(5.9436E-15, 0#, -6.831E-14, 0#, -1.7145E-14, 0#, 0#, 0#), _
        Array(-6.7036E-18, -5.344E-17, 1.414E-16, -9.4881E-17, 0#, 5.6692E-16, -1.0014E-15, 5.334E-16))
End Function

Public Function Psol_R124DMAC(T_C As Double, xi As Double) As Double
    Dim pc As Variant, T As Double, s As Double, row As Double
    Dim i As Long, j As Long
    pc = PCoef()
    T = T_C + 273.15
    s = 0#
    For j = 0 To 7
        row = 0#
        For i = 0 To 7
            row = row + pc(j)(i) * xi ^ i
        Next i
        s = s + row * T ^ j
    Next j
    Psol_R124DMAC = s
End Function

Public Function BubbleT_R124DMAC(P_bar As Double, xi As Double) As Variant
    Dim lo As Double, hi As Double, mid As Double, k As Long
    lo = 0#: hi = 150#
    If P_bar < Psol_R124DMAC(lo, xi) Or P_bar > Psol_R124DMAC(hi, xi) Then
        BubbleT_R124DMAC = Empty
        Exit Function
    End If
    For k = 1 To 80
        mid = 0.5 * (lo + hi)
        If Psol_R124DMAC(mid, xi) < P_bar Then lo = mid Else hi = mid
    Next k
    BubbleT_R124DMAC = 0.5 * (lo + hi)
End Function

' Concentration from dew-point temperature and solution temperature:
' the dew point fixes the pressure, P = PrefR124(Tdew) (DMAC treated as
' non-volatile), then solve Psol(Tsol, xi) = P for xi by bisection.
' Returns Empty if no root (P outside the bubble-pressure span at Tsol).
Public Function XiByTsolTdew_R124DMAC(Tsol_C As Double, Tdew_C As Double) As Variant
    Dim P As Double, lo As Double, hi As Double, mid As Double, k As Long
    P = Pref_R124DMAC(Tdew_C)
    If P < Psol_R124DMAC(Tsol_C, 0#) Or P > Psol_R124DMAC(Tsol_C, 1#) Then
        XiByTsolTdew_R124DMAC = Empty
        Exit Function
    End If
    lo = 0#: hi = 1#
    For k = 1 To 80
        mid = 0.5 * (lo + hi)
        If Psol_R124DMAC(Tsol_C, mid) < P Then lo = mid Else hi = mid
    Next k
    XiByTsolTdew_R124DMAC = 0.5 * (lo + hi)
End Function


' ---------- 露点温度（溶液）[°C]：全库 TdewByTsolXi 约定 ----------
' Tdew = DewT_R124DMAC(Psol_R124DMAC(T_C, xi))：以本模块自有纯
' R124 线（Borde 式(15)）评价溶液表面压力 Psol 所对应的饱和温度。
' DMAC 视为不挥发。压力超出 DewT 二分跨度时返回 Empty。
Public Function TdewByTsolXi_R124DMAC(T_C As Double, xi As Double) As Variant
    TdewByTsolXi_R124DMAC = DewT_R124DMAC(Psol_R124DMAC(T_C, xi))
End Function

' ---------- 由溶液比焓反解溶液温度 [°C] ----------
' hsol_R124DMAC 在固定 xi 下随 T 单调增，二分 100 次反解，
' 求解括号 T ∈ [-40, 150] °C。h 超出该 xi 下 hsol 值域返回 Empty。
' 与 C/Python 同算法；本函数未在真实 Excel 中编译运行。
Public Function TsolByHsol_R124DMAC(h As Double, xi As Double) As Variant
    Dim lo As Double, hi As Double, mid As Double, k As Long
    lo = -40#: hi = 150#
    If h < hsol_R124DMAC(lo, xi) Or h > hsol_R124DMAC(hi, xi) Then
        TsolByHsol_R124DMAC = Empty: Exit Function
    End If
    For k = 1 To 100
        mid = 0.5 * (lo + hi)
        If hsol_R124DMAC(mid, xi) < h Then lo = mid Else hi = mid
    Next k
    TsolByHsol_R124DMAC = 0.5 * (lo + hi)
End Function

Private Function HCoef() As Variant
    HCoef = Array( _
        Array(-34.981, -184.79, 273.1, -22.155, 0#, -49.058, 6.1147, 1.6635), _
        Array(0.31418, 0.59584, -0.90572, 0#, 0#, 0.16399, 0#, 0#), _
        Array(-0.00080917, 0#, 0#, 0.0000114, 0#, 0#, 0#, 0#), _
        Array(0#, 3.2184E-08, 0#, 0#, 0.0000014107, 0#, 7.4883E-07, -1.0444E-06), _
        Array(1.7947E-09, 0#, 0#, 0#, 0#, 0#, 0#, 0#), _
        Array(0#, -1.186E-11, 1.8271E-11, 0#, 0#, -2.281E-11, 0#, 1.0914E-11), _
        Array(0#, 0#, 0#, 0#, 0#, 0#, 0#, 0#), _
        Array(-4.3652E-18, 3.4001E-17, -5.0197E-17, -1.008E-17, 0#, 6.78E-17, 0#, -3.1527E-17))
End Function

Public Function HExcess_R124DMAC(T_C As Double, xi As Double) As Double
    Dim hc As Variant, T As Double, x As Double, s As Double, row As Double
    Dim nr As Double, na As Double, i As Long, j As Long
    hc = HCoef()
    T = T_C + 273.15
    nr = xi / 136.5
    na = (1# - xi) / 87.12
    x = nr / (nr + na)
    s = 0#
    For j = 0 To 7
        row = 0#
        For i = 0 To 7
            row = row + hc(j)(i) * x ^ i
        Next i
        s = s + row * T ^ j
    Next j
    HExcess_R124DMAC = 4.1868 * s
End Function

Public Function Ha_R124DMAC(T_C As Double) As Double
    Ha_R124DMAC = 100# + 4.1868 * (0.4578 * T_C + 0.5 * 0.000839 * T_C ^ 2)
End Function

Public Function Hr_R124DMAC(T_C As Double) As Double
    Dim hr As Variant, s As Double, i As Long
    hr = Array(0.250767, 0.000347753, 0.00000100977, 3.42458E-09, 0#, 0#, 6.99612E-15)
    s = 0#
    For i = 1 To 7
        s = s + hr(i - 1) * T_C ^ i
    Next i
    Hr_R124DMAC = 100# + 4.1868 * s
End Function

Public Function hsol_R124DMAC(T_C As Double, xi As Double) As Double
    hsol_R124DMAC = Hr_R124DMAC(T_C) * xi + Ha_R124DMAC(T_C) * (1# - xi) _
                  + HExcess_R124DMAC(T_C, xi)
End Function

Public Function RhoR124_R124DMAC(T_C As Double) As Double
    RhoR124_R124DMAC = 1000# * (1.466 - 0.003394 * T_C - 0.0000016063 * T_C ^ 2 _
                                - 2.004E-07 * T_C ^ 3)
End Function

Public Function RhoDMAC_R124DMAC(T_C As Double) As Double
    RhoDMAC_R124DMAC = 1000# * (0.9528 - 0.0005856 * T_C - 0.0000033632 * T_C ^ 2)
End Function

Private Function RCoef() As Variant
    RCoef = Array( _
        Array(0.95521, 0.43672, -0.2816, 0.3561), _
        Array(-0.00015533, -0.00037079, 0#, -0.002923), _
        Array(-0.000013981, 0#, 0.00001355, 0#), _
        Array(6.0941E-08, -9.7547E-08, 3.3531E-07, -5.0554E-07))
End Function

Public Function RhoMix_R124DMAC(T_C As Double, xi As Double) As Double
    Dim rc As Variant, s As Double, row As Double, i As Long, j As Long
    rc = RCoef()
    s = 0#
    For j = 0 To 3
        row = 0#
        For i = 0 To 3
            row = row + rc(j)(i) * xi ^ i
        Next i
        s = s + row * T_C ^ j
    Next j
    RhoMix_R124DMAC = 1000# * s
End Function

Public Function EtaR124_R124DMAC(T_C As Double) As Double
    Dim T As Double
    T = T_C + 273.15
    EtaR124_R124DMAC = Exp(-8.9301 + 5094.9 / (T + 357.4))
End Function

Public Function EtaDMAC_R124DMAC(T_C As Double) As Double
    ' Corrected coefficients; printed Table 8 values are x10 (see notes).
    Dim T As Double
    T = T_C + 273.15
    EtaDMAC_R124DMAC = Exp(-1.684 + 134.88 / (T - 223.2))
End Function

Private Function ECoef() As Variant
    ECoef = Array( _
        Array(7.6992, 0.60007, -8.9875, -1.7031), _
        Array(-6769.2, 0#, 4555.4, 0#), _
        Array(1343400#, 0#, 0#, 0#), _
        Array(0#, -64446000#, 0#, -106310000#))
End Function

Public Function EtaMix_R124DMAC(T_C As Double, xi As Double) As Double
    Dim ec As Variant, T As Double, s As Double, row As Double
    Dim i As Long, j As Long
    ec = ECoef()
    T = T_C + 273.15
    s = 0#
    For j = 0 To 3
        row = 0#
        For i = 0 To 3
            row = row + ec(j)(i) * xi ^ i
        Next i
        If j = 0 Then
            s = s + row
        Else
            s = s + row * T ^ (-j)
        End If
    Next j
    EtaMix_R124DMAC = Exp(s)
End Function

' ---- Adiabatic absorber -------------------------------------------------
Private Function hgas_R124DMAC(T_C As Double) As Double
    ' Saturated vapour enthalpy of pure R124 [kJ/kg]: NIST WebBook table
    ' fit, identical polynomial to pure_fluids hgas_R124. Reference state
    ' matches this module: liquid = 100 kJ/kg at 0 degC. Band -40..110.
    hgas_R124DMAC = (((((-4.7606354686130485E-12 * T_C _
        - 9.020883920792309E-10) * T_C + 2.036341936229362E-08) * T_C _
        + 4.234769176716097E-06) * T_C - 3.8033802108463233E-04) * T_C _
        + 5.621038923140594E-01) * T_C + 2.5994742998138406E+02
End Function

Private Function AbsResid_R124DMAC(xr As Double, xi_w As Double, _
        hs As Double, hv As Double, P_bar As Double) As Variant
    Dim Tout As Variant, r As Double
    Tout = BubbleT_R124DMAC(P_bar, xr)
    If IsEmpty(Tout) Then
        AbsResid_R124DMAC = Empty
        Exit Function
    End If
    r = (xr - xi_w) / (1# - xr)
    AbsResid_R124DMAC = hs + r * hv - (1# + r) * hsol_R124DMAC(Tout, xr)
End Function

Public Function AbsVapFlow_R124DMAC(Ts_C As Double, xi_w As Double, _
        ms As Double, Tv_C As Double) As Variant
    ' Vapour flow absorbed in a single-pass adiabatic absorber [same
    ' units as ms]. Inlets: weak solution (ms, Ts_C, xi_w) and saturated
    ' R124 vapour at Tv_C. Absorber pressure = PrefR124(Tv_C); outlet is
    ' the adiabatic-equilibrium state at that pressure. Empty if no
    ' solution inside the model domain (xi <= 0.95; Tv -40..110 degC).
    Dim P As Double, hv As Double, hs As Double
    Dim i As Long, xr As Double, f As Variant
    Dim prev_x As Double, prev_f As Double, havePrev As Boolean
    Dim blo As Double, bhi As Double, haveBracket As Boolean
    Dim flo As Double, mid As Double, fm As Double, k As Long
    If Tv_C < -40# Or Tv_C > 110# Or xi_w >= 0.95 Then
        AbsVapFlow_R124DMAC = Empty
        Exit Function
    End If
    P = Pref_R124DMAC(Tv_C)
    hv = hgas_R124DMAC(Tv_C)
    hs = hsol_R124DMAC(Ts_C, xi_w)
    havePrev = False
    haveBracket = False
    For i = 1 To 400
        xr = xi_w + (0.95 - xi_w) * i / 400#
        f = AbsResid_R124DMAC(xr, xi_w, hs, hv, P)
        If Not IsEmpty(f) Then
            If havePrev And ((prev_f > 0 And f <= 0) _
                    Or (prev_f < 0 And f >= 0)) Then
                blo = prev_x
                bhi = xr
                haveBracket = True
                Exit For
            End If
            prev_x = xr
            prev_f = f
            havePrev = True
        End If
    Next i
    If Not haveBracket Then
        AbsVapFlow_R124DMAC = Empty
        Exit Function
    End If
    flo = AbsResid_R124DMAC(blo, xi_w, hs, hv, P)
    For k = 1 To 100
        mid = 0.5 * (blo + bhi)
        fm = AbsResid_R124DMAC(mid, xi_w, hs, hv, P)
        If (flo > 0) = (fm > 0) Then
            blo = mid
            flo = fm
        Else
            bhi = mid
        End If
    Next k
    xr = 0.5 * (blo + bhi)
    AbsVapFlow_R124DMAC = ms * (xr - xi_w) / (1# - xr)
End Function

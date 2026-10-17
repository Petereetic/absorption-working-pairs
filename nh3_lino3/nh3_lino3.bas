Attribute VB_Name = "NH3LiNO3"
' ==========================================================================
' Ammonia-lithium nitrate (NH3/LiNO3) solution properties - VBA worksheet functions
' ==========================================================================
' Source: Amaris Castilla, C.F. (2014), doctoral thesis, Universitat Rovira i
' Virgili, correlations transcribed in Appendix B (pp. A-6~A-8):
'   Bubble-point pressure Libotean et al. (2007); liquid enthalpy Valles & Salavera (2011,
'   Haltenberger method); specific heat / density Libotean et al. (2008); thermal conductivity Cuenca
'   et al. (2013a); crystallisation limit Infante Ferreira et al. (1984).
' Viscosity is not implemented: the viscosity formula in Appendix B of the thesis is typeset in damaged form and the reconstructed form is unverified
' (provided in the Python version only, marked EXPERIMENTAL).
'
' *** This .bas has not been compiled or run in real Excel; it is a line-by-line port of the Python reference implementation. ***
' *** Verify it in Excel before use.                      ***
'
' Conventions: x = ammonia mass fraction (a fraction, e.g. 0.5); T in K (NL_Xcris uses °C).
' Pressure: worksheet-function boundaries are always MPa; internal arithmetic and the source formulas remain in kPa;
' public functions convert MPa <-> kPa only at the boundary (the private functions Psol_TX_kPa /
' T_bubble_PX_kPa are internal native values in kPa).
' Worksheet functions:
'   NL_Psol(T_K, x)     bubble-point pressure [MPa]      (T 293.15-353.15, x 0.35-0.65)
'   NL_Tbub(P_MPa, x)   bubble-point temperature [K]        (analytic inverse; the result must lie in the T domain above)
'   NL_hsol(T_K, x)     solution specific enthalpy [kJ/kg]    (T 273.15-353.15, x 0.35-0.65)
'   NL_Cp(T_K, x)       specific heat [kJ/(kg K)]    (T 293.15-353.15, x 0.35-0.65)
'   NL_Rho(T_K, x)      density [kg/m^3]       (T 293.15-353.15, x 0.35-0.65)
'   NL_K(T_K, x)        thermal conductivity [W/(m K)]  (T 303.15-353.15, x 0.35-0.60)
'   NL_Xcris(T_C, x)    crystallisation-limit quantity XCRIS    (x 0-1, ten-segment pseudocode of the original)
'   NL_XiByTsolTdew(Tdew_K, Tsol_K)  solves x back from the dew-point temperature and the solution temperature;
'                       returns Empty when there is no root (this function follows the cross-pair library convention,
'                       not the #VALUE! convention of the rest of this module)
'
' Enthalpy reference state (per the source): H = 0 kJ/kg at 0 °C and x=0.5. This differs from the reference states of the other pairs
' in this library; take care when comparing enthalpy differences across pairs.
' Thermal-conductivity note: the thesis prints ka3 T^2 x (the ka3 term carries an x); this implementation follows the reading without the extra x;
' the two readings differ by about 3%; see the formula notes file.
' Out-of-range inputs return the #VALUE! error value.
' ==========================================================================
Option Explicit

' ---------- Cubic polynomial (Horner; coefficients with the constant term first, stored in Variant arrays) ----------
Private Function Poly3(ByRef c As Variant, ByVal x As Double) As Double
    Poly3 = ((c(3) * x + c(2)) * x + c(1)) * x + c(0)
End Function

Private Function PaPb(ByVal x As Double, ByRef pa As Double, ByRef pb As Double)
    Dim cpa As Variant, cpb As Variant
    cpa = Array(4.99470524658178, 88.5490906185871, _
                -197.698944465798, 134.938665891525)
    cpb = Array(-1793.21854659273, -22317.1158016582, _
                61289.3128925447, -45238.5915843719)
    pa = Poly3(cpa, x)
    pb = Poly3(cpb, x)
End Function

Private Function InRng(ByVal v As Double, ByVal lo As Double, _
                       ByVal hi As Double) As Boolean
    InRng = (v >= lo And v <= hi)
End Function

' ---------- (private, internal native value) Bubble-point pressure [kPa]: ln P = pa(x) + pb(x)/T ----------
Private Function Psol_TX_kPa(ByVal T_K As Double, ByVal x As Double) As Variant
    Dim pa As Double, pb As Double
    If Not InRng(T_K, 293.15, 353.15) Or Not InRng(x, 0.35, 0.65) Then
        Psol_TX_kPa = CVErr(xlErrValue): Exit Function
    End If
    PaPb x, pa, pb
    Psol_TX_kPa = Exp(pa + pb / T_K)
End Function

' ---------- Bubble-point pressure [MPa]: the public boundary only converts = Psol_TX_kPa * 1e-3 ----------
Public Function NL_Psol(ByVal T_K As Double, ByVal x As Double) As Variant
    Dim p As Variant
    p = Psol_TX_kPa(T_K, x)
    If IsError(p) Then
        NL_Psol = p
    Else
        NL_Psol = p * 0.001
    End If
End Function

' ---------- (private, internal native value) Bubble-point temperature [K]: T = pb / (ln P - pa), P in kPa ----------
Private Function T_bubble_PX_kPa(ByVal P_kPa As Double, ByVal x As Double) As Variant
    Dim pa As Double, pb As Double, denom As Double, T_K As Double
    If Not InRng(x, 0.35, 0.65) Or P_kPa <= 0# Then
        T_bubble_PX_kPa = CVErr(xlErrValue): Exit Function
    End If
    PaPb x, pa, pb
    denom = Log(P_kPa) - pa
    If denom = 0# Then
        T_bubble_PX_kPa = CVErr(xlErrValue): Exit Function
    End If
    T_K = pb / denom
    If Not InRng(T_K, 293.15, 353.15) Then
        T_bubble_PX_kPa = CVErr(xlErrValue): Exit Function
    End If
    T_bubble_PX_kPa = T_K
End Function

' ---------- Bubble-point temperature [K]: the public boundary takes P_MPa [MPa], converts back to kPa and passes to the private native function ----------
Public Function NL_Tbub(ByVal P_MPa As Double, ByVal x As Double) As Variant
    NL_Tbub = T_bubble_PX_kPa(P_MPa * 1000#, x)
End Function

' ---------- Pure-ammonia saturation line (dew-point convention, for NL_XiByTsolTdew) ----------
' LiNO3 is non-volatile; the vapour phase is treated as pure ammonia. The pure-ammonia line was re-sourced on 2026-10-12: it now uses a compact
' fit to the ammonia NIST saturation table (lnP-t degree-7 polynomial; P in MPa, t in degC; source:
' NIST WebBook saturation table, 210 points, -77~132 degC; max deviation over the usual band -50~+60 degC
' is 0.0027%). Previously the pure-ammonia endpoint of the Patek-Klomfar Eq. (6) was used; at
' 25 degC it gives 1012 kPa, about 0.9% above the NIST table value 1002.69 kPa; from now on
' it is kept only as a historical convention, accounted separately. The mixture bubble-point formula is unchanged. Domain t = -77~132 degC.
Private Function PrefNH3Pure(ByVal T_K As Double) As Variant
    Dim t As Double, lnP As Double, k As Long, c As Variant
    t = T_K - 273.15
    If t < -77# Or t > 132# Then
        PrefNH3Pure = Empty: Exit Function
    End If
    c = Array(-0.8457026848887617, 0.03739502393748032, _
              -0.00015333383280607642, 6.551063627525382E-07, _
              -2.4759314474490567E-09, 9.070213653911228E-12, _
              -3.681466540446358E-14, 1.1501679663496297E-16)
    lnP = 0#
    For k = 7 To 0 Step -1
        lnP = lnP * t + c(k)
    Next k
    PrefNH3Pure = 1000# * Exp(lnP)
End Function

' Pure-ammonia saturation temperature [K]: inverted from PrefNH3Pure(T) = P_kPa by 80 bisection steps;
' returns Empty when P lies outside the pressure span of the fit domain (approx. 6.4~11280 kPa).
Private Function TsatNH3Pure(ByVal P_kPa As Double) As Variant
    Dim lo As Double, hi As Double, mid As Double, k As Long
    lo = 196.15: hi = 405.15
    If P_kPa < PrefNH3Pure(lo) Or P_kPa > PrefNH3Pure(hi) Then
        TsatNH3Pure = Empty: Exit Function
    End If
    For k = 1 To 80
        mid = 0.5 * (lo + hi)
        If PrefNH3Pure(mid) < P_kPa Then lo = mid Else hi = mid
    Next k
    TsatNH3Pure = 0.5 * (lo + hi)
End Function

' ---------- Solve the ammonia mass fraction x back from the dew-point temperature and the solution temperature ----------
' Dew-point pressure P = PrefNH3Pure(Tdew_K) (pure-ammonia saturation pressure; convention above);
' then 80 bisection steps invert Psol_TX_kPa(Tsol_K, x) = P (internal kPa throughout,
' not via the public MPa boundary); the bracket is the bubble-point function's valid
' concentration domain x = 0.35-0.65. Returns Empty when there is no root (P outside the span of bubble-point pressures under Tsol,
' e.g. the solution temperature clearly below the dew-point temperature; or Tdew outside the pure-ammonia NIST
' fit domain; or Tsol out of domain). Same algorithm as C/Python; not compiled in real Excel.
Public Function NL_XiByTsolTdew(ByVal Tsol_K As Double, ByVal Tdew_K As Double) As Variant
    Dim P As Variant, lo As Double, hi As Double, mid As Double, k As Long
    P = PrefNH3Pure(Tdew_K)
    If IsEmpty(P) Then
        NL_XiByTsolTdew = Empty: Exit Function
    End If
    If Not InRng(Tsol_K, 293.15, 353.15) Then
        NL_XiByTsolTdew = Empty: Exit Function
    End If
    If P < Psol_TX_kPa(Tsol_K, 0.35) Or P > Psol_TX_kPa(Tsol_K, 0.65) Then
        NL_XiByTsolTdew = Empty: Exit Function
    End If
    lo = 0.35: hi = 0.65
    For k = 1 To 80
        mid = 0.5 * (lo + hi)
        If Psol_TX_kPa(Tsol_K, mid) < P Then lo = mid Else hi = mid
    Next k
    NL_XiByTsolTdew = 0.5 * (lo + hi)
End Function


' ---------- Dew-point temperature (solution) [K]: library-wide TdewByTsolXi convention ----------
' Tdew = TsatNH3Pure(Psol_TX_kPa(T_K, x)): the saturation temperature corresponding to the solution surface pressure Psol,
' evaluated with the pure-ammonia NIST fit line (re-sourced on 2026-10-12; see above)
' (internal kPa throughout, not via the public MPa boundary). LiNO3 is non-volatile,
' the vapour phase is treated as pure ammonia. Returns Empty when Psol_TX_kPa has no solution or P lies outside
' the pressure span of the pure-ammonia fit domain.
Public Function NL_TdewByTsolX(ByVal T_K As Double, ByVal x As Double) As Variant
    Dim P As Variant, T As Variant
    P = Psol_TX_kPa(T_K, x)
    If IsEmpty(P) Then NL_TdewByTsolX = Empty: Exit Function
    T = TsatNH3Pure(P)
    If IsEmpty(T) Then NL_TdewByTsolX = Empty: Exit Function
    NL_TdewByTsolX = T
End Function

' ---------- Solve the solution temperature [K] back from the solution specific enthalpy ----------
' NL_hsol increases monotonically with T at fixed x; inverted by 100 bisection steps within its domain T in [273.15, 353.15] K.
' Returns Empty when h lies outside the range of hsol at that x, or x is out of domain
' (endpoint evaluations return Empty). Same algorithm as C/Python;
' this function has not been compiled or run in real Excel.
Public Function NL_TsolByHsol(ByVal h As Double, ByVal x As Double) As Variant
    Dim hlo As Variant, hhi As Variant
    Dim lo As Double, hi As Double, mid As Double, k As Long
    hlo = NL_hsol(273.15, x): hhi = NL_hsol(353.15, x)
    If IsEmpty(hlo) Or IsEmpty(hhi) Then NL_TsolByHsol = Empty: Exit Function
    If h < hlo Or h > hhi Then NL_TsolByHsol = Empty: Exit Function
    lo = 273.15: hi = 353.15
    For k = 1 To 100
        mid = 0.5 * (lo + hi)
        If NL_hsol(mid, x) < h Then lo = mid Else hi = mid
    Next k
    NL_TsolByHsol = 0.5 * (lo + hi)
End Function

' ---------- Solution specific enthalpy [kJ/kg]: H = ha + hb T + hc T^2 ----------
Public Function NL_hsol(ByVal T_K As Double, ByVal x As Double) As Variant
    Dim cha As Variant, chb As Variant, chc As Variant
    If Not InRng(T_K, 273.15, 353.15) Or Not InRng(x, 0.35, 0.65) Then
        NL_hsol = CVErr(xlErrValue): Exit Function
    End If
    cha = Array(249.1567745, -1628.297463, -464.3464344, -105.6321057)
    chb = Array(2.481273559, -5.184392344, -0.775202139, 18.98142102)
    chc = Array(-0.004240786, 0.025111292, -0.013342843, -0.025956064)
    NL_hsol = Poly3(cha, x) + Poly3(chb, x) * T_K _
              + Poly3(chc, x) * T_K * T_K
End Function

' ---------- Specific heat [kJ/(kg K)] (the original is in J/(g K); the numerical value is the same) ----------
Public Function NL_Cp(ByVal T_K As Double, ByVal x As Double) As Variant
    Dim cpa As Double, cpb As Double
    If Not InRng(T_K, 293.15, 353.15) Or Not InRng(x, 0.35, 0.65) Then
        NL_Cp = CVErr(xlErrValue): Exit Function
    End If
    cpa = 0.559273057 + 3.241167393 * x
    cpb = 0.00207796 + 0.001846907 * x
    NL_Cp = cpa + cpb * T_K
End Function

' ---------- Density [kg/m^3]: rho = 1000 (da + db T) ----------
Public Function NL_Rho(ByVal T_K As Double, ByVal x As Double) As Variant
    Dim da As Double, db As Double
    If Not InRng(T_K, 293.15, 353.15) Or Not InRng(x, 0.35, 0.65) Then
        NL_Rho = CVErr(xlErrValue): Exit Function
    End If
    da = 1.521 - 0.4528 * x
    db = -0.00001961 - 0.001726 * x
    NL_Rho = 1000# * (da + db * T_K)
End Function

' ---------- Thermal conductivity [W/(m K)]: k = ka1 + ka2 T + ka3 T^2 + ka4 x ----------
Public Function NL_K(ByVal T_K As Double, ByVal x As Double) As Variant
    If Not InRng(T_K, 303.15, 353.15) Or Not InRng(x, 0.35, 0.6) Then
        NL_K = CVErr(xlErrValue): Exit Function
    End If
    NL_K = 0.446088003 - 0.000350326 * T_K _
           + 0.000000213849 * T_K * T_K + 0.006538043 * x
End Function

' ---------- Crystallisation limit XCRIS (Infante Ferreira 1984; the ten segments transcribed verbatim) ----------
Public Function NL_Xcris(ByVal T_C As Double, ByVal x As Double) As Variant
    Dim T As Double
    T = T_C
    If x < 0.2911 Then
        NL_Xcris = 0.3021 - 0.00034 * T - 0.00000272 * T * T
    ElseIf x < 0.3 Then
        NL_Xcris = x
    ElseIf x < 0.3076 Then
        NL_Xcris = -0.000608 * T + 0.3152
    ElseIf x < 0.3362 Then
        NL_Xcris = 0.0143 * T + 0.12885
    ElseIf x < 0.4304 Then
        NL_Xcris = -0.005402 * T + 0.41318
    ElseIf x < 0.5072 Then
        NL_Xcris = 0.443413 + 0.0069 * T + 0.000854 * T * T
    ElseIf x < 0.6434 Then
        NL_Xcris = 0.527643 - 0.003126 * T - 0.000019 * T * T
    ElseIf x < 0.6649 Then
        NL_Xcris = -0.004605 * T + 0.40761
    ElseIf x < 0.7826 Then
        NL_Xcris = 0.0000309 * T * T + 0.57452
    ElseIf x <= 1# Then
        NL_Xcris = 0.07378 * T + 6.7214
    Else
        NL_Xcris = CVErr(xlErrValue)
    End If
End Function

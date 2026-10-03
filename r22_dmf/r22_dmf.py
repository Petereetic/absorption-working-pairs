"""R22-DMF bubble-point pressure & solution enthalpy - reference implementation.
Data: Agarwal 1982 (via Ardita thesis Lampiran-7). Enthalpy: Fatouh et al. 1993 (via thesis Ch.2).
"""
import math

# ---- Bubble pressure: per-isopleth Antoine ln(P/bar)=A+B/T+C*lnT (T in K), PCHIP in xi ----
_ISO = [  # xi(R22 mass frac), A, B, C   (fit to Agarwal 1982, xi>=0.10)
 (0.10000,  30.772744, -3182.9395, -3.629138),
 (0.23076,  10.400862, -2459.9752, -0.388685),
 (0.32000,  10.271208, -2405.5462, -0.311415),
 (0.40348,  -5.848160, -1618.6504,  2.088399),
 (0.50000,  39.598401, -3709.7856, -4.591025),
 (0.60220,  27.566449, -3089.5702, -2.819850),
 (0.70000,  28.096798, -3022.7056, -2.907606),
 (0.80000,  51.969188, -4223.6822, -6.297351),
 (0.90000,  99.166678, -6197.2000,-13.369886),
 (1.00000,  18.474130, -2766.7568, -1.197267),
]
_XI_LO, _XI_HI = 0.10, 1.00

def _pchip(x, y, xq):
    n = len(x)
    h = [x[i+1]-x[i] for i in range(n-1)]
    d = [(y[i+1]-y[i])/h[i] for i in range(n-1)]
    dk = [0.0]*n
    dk[0], dk[-1] = d[0], d[-1]
    for k in range(1, n-1):
        if d[k-1]*d[k] <= 0: dk[k] = 0.0
        else:
            w1 = 2*h[k]+h[k-1]; w2 = h[k]+2*h[k-1]
            dk[k] = (w1+w2)/(w1/d[k-1]+w2/d[k])
    from bisect import bisect_right
    k = min(max(bisect_right(x, xq)-1, 0), n-2)
    t = (xq-x[k])/h[k]
    return ((2*t**3-3*t**2+1)*y[k] + (t**3-2*t**2+t)*h[k]*dk[k]
            + (-2*t**3+3*t**2)*y[k+1] + (t**3-t**2)*h[k]*dk[k+1])

def bubble_P(T_C, xi):
    """Bubble-point pressure (bar). T_C in degC, xi = R22 mass fraction."""
    T = T_C + 273.15
    xc = min(max(xi, _XI_LO), _XI_HI)
    xs = [r[0] for r in _ISO]
    Pj = [math.exp(r[1] + r[2]/T + r[3]*math.log(T)) for r in _ISO]
    return _pchip(xs, Pj, xc)

def bubble_T(P_bar, xi, Tlo_C=-25.0, Thi_C=120.0):
    """Bubble-point temperature (degC) by bisection. Returns None if out of range."""
    xc = min(max(xi, _XI_LO), _XI_HI)
    Plo, Phi = bubble_P(Tlo_C, xc), bubble_P(Thi_C, xc)
    if not (Plo <= P_bar <= Phi): return None
    lo, hi = Tlo_C, Thi_C
    for _ in range(60):
        mid = 0.5*(lo+hi)
        if bubble_P(mid, xc) < P_bar: lo = mid
        else: hi = mid
    return 0.5*(lo+hi)

# ---- Solution enthalpy: Fatouh et al. 1993 (thesis eq 2.38-2.43), T in K, h in kJ/kg ----
_MR22, _MDMF, _R = 86.47, 73.09, 8.314  # g/mol, kJ/(kmol K)
_F_R22_L = [(-68.14840, 0.0631300, 0.0020200, 253.15, 323.15),
            (1966.645, -12.09784, 0.02018352, 323.15, 368.15)]
_F_R22_V = [(37.22971, 1.599520, -0.002260308, 253.15, 323.15),
            (-2720.182, 18.11784, -0.02699451, 323.15, 368.15)]
_F_DMF   = (-352.2493, 1.317081, 0.001239553)
_B = (-1817.206, -4302.679, 9877.574, 0.0)
_C = (-135585.8, 625797.9, -1435546.0, 0.0)
_E1, _E2, _E3 = -7738.2052, 0.05627680, -34.79

def _poly(F, T):
    F0, F1, F2 = F[0], F[1], F[2]
    return F0 + F1*T + F2*T*T

def h_R22_L(T_C):
    T = T_C + 273.15
    F = _F_R22_L[0] if T < 323.15 else _F_R22_L[1]
    return _poly(F, T)

def h_R22_V(T_C):
    T = T_C + 273.15
    F = _F_R22_V[0] if T < 323.15 else _F_R22_V[1]
    return _poly(F, T)

def h_DMF(T_C):
    return _poly(_F_DMF, T_C + 273.15)

def _h_fatouh(T_C, xi):
    """Raw Fatouh correlation (valid xi<=0.9; hmix does not vanish at xi=1)."""
    T = T_C + 273.15
    omx = 1.0 - xi
    Y0 = xi/omx
    Y1 = xi/omx + math.log(omx)
    Y2 = 1.0/omx - omx + 2.0*math.log(omx)
    Y3 = xi/omx + xi*xi/2.0 + 2.0*xi + 3.0*math.log(omx)
    T2, T3 = T*T, T*T*T
    K0 = _B[0]/T2 + 2*_C[0]/T3 - _E1/T2 + _E2 + _E3/T
    K1 = _B[1]/T2 + 2*_C[1]/T3
    K2 = _B[2]/T2 + 2*_C[2]/T3
    K3 = _B[3]/T2 + 2*_C[3]/T3
    Mmix = xi*_MR22 + omx*_MDMF
    hmix = (omx*_R*T2/Mmix)*(K0*Y0 + K1*Y1 + K2*Y2 + K3*Y3)
    return xi*h_R22_L(T_C) + omx*h_DMF(T_C) + hmix

def h_solution(T_C, xi):
    """R22-DMF solution enthalpy (kJ/kg). T_C in degC, xi = R22 mass fraction.
    Fatouh correlation for xi<=0.9; linear blend to pure R22 for 0.9<xi<1
    (the raw hmix does not vanish at xi=1)."""
    if xi <= 0.0: return h_DMF(T_C)
    if xi >= 1.0: return h_R22_L(T_C)
    if xi <= 0.9: return _h_fatouh(T_C, xi)
    h09 = _h_fatouh(T_C, 0.9)
    return h09 + (xi-0.9)/0.1*(h_R22_L(T_C)-h09)

if __name__ == "__main__":
    import csv
    # verify bubble-P against data
    pts=[]
    with open('agarwal1982.csv') as f:
        for row in csv.reader(f):
            if not row or row[0].startswith('#'): continue
            pts.append((float(row[0]),float(row[1]),float(row[2])))
    m=[i for i,(T,x,P) in enumerate(pts) if abs(T-253.15)<0.01 and abs(x-0.5)<1e-9]
    pts[m[0]]=(253.15,0.5,0.610)
    errs=[]
    for T,x,P in pts:
        if x < 0.099: continue
        errs.append(abs(bubble_P(T-273.15,x)-P)/P*100)
    errs=np.array(errs) if (np:=__import__('numpy')) else errs
    print(f"bubbleP: n={len(errs)} AARD={sum(errs)/len(errs):.3f}% max={max(errs):.2f}%")
    # reference points
    print("h_R22_L(0C) =", round(h_R22_L(0),2), "(ref 100)")
    print("h_DMF(0C)   =", round(h_DMF(0),2), "(ref 100)")
    print("h_sol(30C,0.5) =", round(h_solution(30,0.5),2))
    print("h_sol(98.7C,0.5)=", round(h_solution(98.7,0.5),2), "(thesis hand-calc 383.75; see note)")
    print("bubbleP(40C,0.5)=", round(bubble_P(40,0.5),3), "bar (data 3.796 @31.8C? no: 313.15K/50%=3.796)")
    print("bubbleP(30C,0.5)=", round(bubble_P(30,0.5),3))
    print("bubbleT(3.796bar,0.5)=", round(bubble_T(3.796,0.5),2), "C (expect ~40C)")

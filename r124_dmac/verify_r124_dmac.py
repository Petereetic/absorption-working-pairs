"""Verification of r124_dmac.py against Borde et al. 1997's own data.

Checks (each is internal to the paper unless marked [fig]):
 1. Eq. (15) vapour pressures at the Table 1 normal boiling points -> 1.013 bar
 2. Eq. (16) bubble polynomial at xi=1 / xi=0 vs Eq. (15) pure vapour pressures
 3. Eq. (16) vs Figure 2 spot readings [fig, eyeball tolerance]
 4. Eq. (19) excess enthalpy vs Figure 3 curve minima [fig]
 5. hE(x=0) = hE(x=1) = 0 and Eq. (22) endpoints h(0 degC) = 100 kJ/kg
 6. Eq. (25) mixture density endpoints vs Table 7 / Eq. (23); Figure 5 spot [fig]
 7. Eq. (26) mixture viscosity at xi=0 vs Eq. (24) DMAC (corrected Table 8)
    and at xi=1 vs Eq. (24) R124 -- this is the arbitration for the Table 8
    DMAC misprint: the printed (x10) coefficients are printed too, for contrast.
"""
import math
import r124_dmac as m

print("== 1. Eq.(15) at normal boiling points (Table 1) ==")
TB = {"R124": -11.0, "DMAC": 165.0, "NMP": 203.0, "MCL": 235.8,
      "DMEU": 223.0, "DMETEG": 275.3}
for c, tb in TB.items():
    print(f"  {c:7s} tb={tb:7.1f} C  Psat={m.psat(c, tb):.3f} bar  (target 1.013)")

print("== 2. Eq.(16) endpoints vs Eq.(15) ==")
# Documented characteristic of the printed fit (see 核验 record S.4.1):
# at xi=1 the polynomial runs +13..+23 % above Eq. (15); at xi=0 the
# absolute deviation stays <= 0.03 bar.
for T in range(0, 141, 20):
    pp, ps = m.bubble_P(T, 1.0), m.psat("R124", T)
    print(f"  xi=1, T={T:3d} C: poly={pp:8.3f}, psat={ps:8.3f}, dev={100*(pp/ps-1):+6.1f} %")
for T in (0, 60, 120):
    pp, ps = m.bubble_P(T, 0.0), m.psat("DMAC", T)
    print(f"  xi=0, T={T:3d} C: poly={pp:.4f}, psat={ps:.4f}, abs err={pp-ps:+.4f} bar")

print("== 3. Eq.(16) vs Figure 2 spot readings [fig] ==")
for xi, T, p_fig in ((0.6, 100, 7.3), (0.4, 80, 3.3), (0.8, 120, 13.0),
                     (0.2, 60, 1.1), (1.0, 140, 23.5)):
    p = m.bubble_P(T, xi)
    print(f"  xi={xi}, T={T} C: model {p:6.2f} bar, figure ~{p_fig} bar")

print("== 4. Eq.(19) excess enthalpy vs Figure 3 [fig] ==")
for T in (0, 20, 60, 100, 140):
    xs = [i / 100 for i in range(1, 100)]
    vals = [(m.h_excess(T, m_xi), m_xi) for m_xi in
            [x * m._M_R124 / (x * m._M_R124 + (1 - x) * m._M_DMAC)
             for x in xs]]  # h_excess takes xi; convert x->xi properly below
    # redo cleanly: scan over mole fraction x
    best = (1e9, None)
    for i in range(1, 100):
        x = i / 100
        xi = x * m._M_R124 / (x * m._M_R124 + (1 - x) * m._M_DMAC)
        v = m.h_excess(T, xi)
        if v < best[0]:
            best = (v, x)
    print(f"  T={T:3d} C: min hE = {best[0]:7.2f} kJ/kg at x={best[1]:.2f}"
          f"  ({best[0]/4.1868:.2f} kcal/kg)")

print("== 5. hE endpoints and Eq.(22) reference state ==")
for T in (0, 60, 120):
    print(f"  T={T:3d} C: hE(xi=0)={m.h_excess(T, 0.0):+.3f}, "
          f"hE(xi=1)={m.h_excess(T, 1.0):+.3f} kJ/kg")
print(f"  h_liq(0 C, xi=0) = {m.h_liq(0, 0.0):.2f}, "
      f"h_liq(0 C, xi=1) = {m.h_liq(0, 1.0):.2f} kJ/kg (target 100)")

print("== 6. Density: Eq.(25) endpoints vs Eq.(23), Figure 5 spot ==")
print(f"  rho_mix(0 C, 0) = {m.rho_mix(0, 0.0):.1f} vs pure DMAC "
      f"{m.rho_pure('DMAC', 0):.1f} kg/m3")
print(f"  rho_mix(0 C, 1) = {m.rho_mix(0, 1.0):.1f} vs pure R124 "
      f"{m.rho_pure('R124', 0):.1f} kg/m3")
print(f"  rho_mix(0 C, 0.5) = {m.rho_mix(0, 0.5):.1f} kg/m3 (Figure 5 ~1148)")

print("== 7. Viscosity arbitration (Table 8 DMAC misprint) ==")
def eta_dmac_printed(T_C):
    T = T_C + 273.15
    return math.exp(-16.8400 + 1348.80 / (T - 223.2))
for T in (20, 40, 80, 120):
    print(f"  T={T:3d} C: eta_mix(xi=0)={m.eta_mix(T, 0.0):.3f}, "
          f"eta_pure DMAC corrected={m.eta_pure('DMAC', T):.3f}, "
          f"printed={eta_dmac_printed(T):.3f} mPa s")
for T in (20, 60, 100):
    print(f"  T={T:3d} C: eta_mix(xi=1)={m.eta_mix(T, 1.0):.3f} vs "
          f"eta_pure R124={m.eta_pure('R124', T):.3f} mPa s")

print("== 8. The Dalian master's thesis Table 2.7 (altered copy of Table 3) ==")
_TH = [
    [1.15e-2, 2.82e3, 4.12e3, 2.62e3, 0, 1.84e4, -3.12e2, 1.39e2],
    [1.37e-2, 0.2418, -0.2695, 0, 0, 7.6, 0, 0],
    [9.19e-3, 0, 0, 0, 0, 0, 0, 0],
    [0, -3.16e-4, 9.27e-5, 7.82e-4, -1.31e-3, 0, 1.27e-3, -6.59e-4],
    [-8.65e-8, 0, 0, 0, 0, 0, 0, 0],
    [0, 2.3e-9, 0, 0, 0, 3.33e-9, 0, -2.4e-9],
    [5.94e-13, 0, -6.83e-12, 0, -1.71e-12, 0, 0, 0],
    [-0.67, -5.34e-15, 1.41e-15, -9.49e-15, 0, 5.66e-14, -1.01e-13, 5.33e-11],
]
def _thP(xi, Tv):
    return sum(_TH[j][i] * xi ** i * Tv ** j for j in range(8) for i in range(8))
for xi, T in ((0.5, 80), (0.8, 100)):
    print(f"  xi={xi}, T={T} C: thesis table (T in C, as its text states) "
          f"P={_thP(xi, float(T)):.4g} bar; (T in K) P={_thP(xi, T + 273.15):.4g} bar; "
          f"Borde original P={m.bubble_P(T, xi):.3f} bar")

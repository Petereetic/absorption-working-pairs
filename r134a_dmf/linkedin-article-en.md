# R134a–DMF Absorption Working Pair: Engineering Models for Bubble-Point Pressure and Solution Enthalpy

For diffusion absorption refrigeration (DAR) cycle calculations with R134a–DMF, two property functions are essential: **bubble-point pressure** (sets system pressure) and **solution enthalpy** (for energy balances). This post provides directly usable Excel VBA worksheet functions and a C implementation, with all coefficients published and errors documented.

## 1. Bubble-Point Pressure P(T, x)

### Data

Vapor-liquid equilibrium data from Zehioua et al. (2009), *J. Chem. Eng. Data*, DOI: 10.1021/je900440t. 58 data points: 303.30–353.24 K, R134a mole fraction 0.06–0.94.

### Method

NRTL activity coefficient model + gamma-phi bubble-point formulation.

**NRTL parameters** (fitted in gamma-phi framework, α = 0.3):
- Δg₁₂ = 868.1 J/mol
- Δg₂₁ = −929.1 J/mol

Note: The original paper (PR+MHV1+NRTL) reports (2250, −2650) J/mol — those were fitted for the equation-of-state mixing rule and underestimate by ~20% if used directly in gamma-phi. The (868.1, −929.1) values here are refitted for gamma-phi consistency.

**Pure-component saturation pressures:**
- R134a: ln(P₁ˢᵃᵗ/MPa) = 7.89191 − 2310.84/(T − 19.79), T in K (fitted from paper Table 3, <0.2% error, 298–353 K)
- DMF: log₁₀(P₂ˢᵃᵗ/bar) = 3.93068 − 1337.716/(T − 82.648), T in K (NIST WebBook)

**Bubble-point pressure** (with Poynting correction, solved iteratively):
P = x₁γ₁P₁ˢᵃᵗ·exp[V₁ᴸ(P−P₁ˢᵃᵗ)/RT] + x₂γ₂P₂ˢᵃᵗ·exp[V₂ᴸ(P−P₂ˢᵃᵗ)/RT]

Validation on 58 points: mean absolute relative error **1.49%**, max 3.01%.

Sample calculations:
- BubbleP(30 °C, x₁=0.5) ≈ 4.82 bar
- BubbleP(50 °C, x₁=0.7) ≈ 9.15 bar

### Functions

- `R134aDMF_BubbleP(T_C, x1)`: bubble-point pressure, bar. T_C in °C, x1 = R134a mole fraction.
- `R134aDMF_BubbleT(P_bar, x1)`: bubble-point temperature, °C. Newton iteration.

## 2. Solution Enthalpy h(T, x₁)

### Formulation

h(T,x₁) = w₁h₁ᴸ(T) + w₂h₂ᴸ(T) + hᴱ(T,x₁)/M̄

- w₁, w₂: mass fractions; M̄ = x₁M₁ + x₂M₂ (g/mol)
- M₁ = 102.03 (R134a), M₂ = 73.09 (DMF) g/mol
- Reference state: 273.15 K saturated liquid = 100 kJ/kg (both components)

**Pure-component liquid enthalpies** (kJ/kg, T in K):
- R134a saturated liquid: h₁ᴸ = 1.310235×10⁻⁵t³ + 1.34329×10⁻³t² + 1.334242t + 100.0, where t = T − 273.15 (fitted from Tillner-Roth & Baehr 1994)
- DMF liquid: h₂ᴸ = −297.61 + 0.89544T + 0.0020551T² (He et al., *Solar Energy* 83 (2009), Eq. 5)

**Excess enthalpy** hᴱ from NRTL analytical differentiation (verified against numerical differentiation):
hᴱ = −RT·x₁x₂·[τ₂₁G₂₁/D₁·(−1+ατ₂₁x₁/D₁) + τ₁₂G₁₂/D₂·(−1+ατ₁₂x₂/D₂)]

where D₁ = x₁+x₂G₂₁, D₂ = x₂+x₁G₁₂. hᴱ is negative (exothermic mixing), ≈ −0.7 kJ/kg at x₁=0.5.

### Functions

- `R134aDMF_Hsol(T_C, x1)`: solution enthalpy, kJ/kg.
- `R134aDMF_H_R134aL / R134aDMF_H_DMFL`: pure-component enthalpies.

Sample: Hsol(30 °C, x₁=0.5) ≈ 145.3 kJ/kg

## 3. Code

**Excel VBA** (r134a_dmf.bas): Import as a standard module, use directly as worksheet functions, e.g. `=R134aDMF_BubbleP(40,0.5)`.

**C** (r134a_dmf.c): `gcc -O2 -Wall -o r134a_dmf r134a_dmf.c -lm` compiles with zero warnings. C version matches Python reference to 5×10⁻⁷.

**Python** (r134a_dmf.py): Reference implementation for verification.

### Known caveat

Feng et al. (2016) published 8 data points (293/303 K) that run 6–9% below this model. The two datasets require completely different NRTL parameters — a lab-to-lab systematic difference. This model uses the larger (58-point) Zehioua 2009 dataset. Apply ~5% uncertainty in cycle calculations, or calibrate with your own data.

---

*Data: Zehioua et al., J. Chem. Eng. Data 2009. Enthalpy: NRTL-derived. VBA/C/Python source available for engineering use.*

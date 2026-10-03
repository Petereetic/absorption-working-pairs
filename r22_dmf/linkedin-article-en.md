# R22–DMF Absorption Working Pair: Engineering Models for Bubble-Point Pressure and Solution Enthalpy

For R22–DMF diffusion absorption refrigeration (DAR) cycle calculations, two property functions are essential: **bubble-point pressure** and **solution enthalpy**. This post provides directly usable Excel VBA worksheet functions and a C implementation, with all coefficients published and errors documented.

## 1. Bubble-Point Pressure P(T, ξ)

### Data

Vapor-liquid equilibrium data from Agarwal et al. (1982), transcribed and cross-checked against Ardita (2008) thesis Appendix 7. 132 valid points: temperature −25 to 120 °C, R22 mass fraction 0.10–1.00, pressure in bar.

Transcription note: at 253.15 K, ξ=0.5, the original table shows 0.610 bar (verified character-by-character against the scanned original — confirmed correct). Individual points show experimental scatter; all are retained as-is in the fit.

### Method

R22–DMF is a strongly non-ideal system; a single global polynomial would oscillate at the boundaries. Two-stage approach:

1. Split into 10 constant-concentration lines; fit each with an Antoine form:
   ln(P/bar) = A + B/T + C·lnT, T in K
2. At a given temperature, compute pressure on all 10 lines, then interpolate over concentration ξ with **monotonicity-preserving PCHIP** (Fritsch–Carlson), guaranteeing P increases monotonically with ξ, no oscillation.

Antoine coefficients for the 10 lines (ξ = R22 mass fraction):

ξ=0.10000: A=30.772744, B=−3182.9395, C=−3.629138
ξ=0.23076: A=10.400862, B=−2459.9752, C=−0.388685
ξ=0.32000: A=10.271208, B=−2405.5462, C=−0.311415
ξ=0.40348: A=−5.848160, B=−1618.6504, C=2.088399
ξ=0.50000: A=39.598401, B=−3709.7856, C=−4.591025
ξ=0.60220: A=27.566449, B=−3089.5702, C=−2.819850
ξ=0.70000: A=28.096798, B=−3022.7056, C=−2.907606
ξ=0.80000: A=51.969188, B=−4223.6822, C=−6.297351
ξ=0.90000: A=99.166678, B=−6197.2000, C=−13.369886
ξ=1.00000: A=18.474130, B=−2766.7568, C=−1.197267

Back-calculation on 132 points: mean absolute relative error **2.38%**, max 9.6%.

### Functions

- `R22DMF_BubbleP(T_C, ξ)`: bubble-point pressure, bar. T_C in °C, ξ = R22 mass fraction.
- `R22DMF_BubbleT(P_bar, ξ)`: bubble-point temperature, °C. Bisection; returns #N/A out of range.

Sample calculations:
- BubbleP(30 °C, 0.5) = 3.086 bar
- BubbleP(80 °C, 0.4) = 6.120 bar
- BubbleP(0 °C, 0.3) = 0.690 bar
- BubbleT(5.0 bar, 0.5) = 50.88 °C
- BubbleT(1.0 bar, 0.3) = 12.37 °C

## 2. Solution Enthalpy h(T, ξ)

### Formulation

Fatouh et al. (1993) correlation (Ardita thesis Eqs. 2.38–2.43):

h_s(T,ξ) = ξ·h_L,R22(T) + (1−ξ)·h_DMF(T) + h_mix(T,ξ)

where

h_mix = [(1−ξ)·R·T²/M_mix]·(K0·Y0 + K1·Y1 + K2·Y2 + K3·Y3)

Y0 = ξ/(1−ξ)
Y1 = ξ/(1−ξ) + ln(1−ξ)
Y2 = 1/(1−ξ) − (1−ξ) + 2·ln(1−ξ)
Y3 = ξ/(1−ξ) + ξ²/2 + 2ξ + 3·ln(1−ξ)

K0 = B0/T² + 2C0/T³ − E1/T² + E2 + E3/T
K1 = B1/T² + 2C1/T³
K2 = B2/T² + 2C2/T³
K3 = 0 (B3 = C3 = 0)

Constants: B=(−1817.206, −4302.679, 9877.574, 0), C=(−135585.8, 625797.9, −1435546, 0),
E1=−7738.2052, E2=0.05627680, E3=−34.79.
M_R22=86.47, M_DMF=73.09 g/mol, M_mix=ξ·M_R22+(1−ξ)·M_DMF, R=8.314 kJ/(kmol·K).

Pure-component enthalpies (kJ/kg, T in K, reference state: 273.15 K saturated liquid = 100 kJ/kg):

- R22 saturated liquid: h=F0+F1·T+F2·T². 253.15–323.15 K: F=(−68.14840, 0.0631300, 0.0020200); 323.15–368.15 K: F=(1966.645, −12.09784, 0.02018352).
- R22 saturated vapor: 253.15–323.15 K: F=(37.22971, 1.599520, −0.002260308); 323.15–368.15 K: F=(−2720.182, 18.11784, −0.02699451).
- DMF liquid: F=(−352.2493, 1.317081, 0.001239553).

Reference check: h_R22 liquid(0 °C)=99.81, h_DMF(0 °C)=100.00 kJ/kg, consistent with the 273.15 K = 100 reference state.

### Two notes

1. **Unit issue in the paper's worked example.** The thesis §4.3 hand-calculates solution enthalpy at ξ=0.5, 98.7 °C as 383.75 kJ/kg. But computing per the paper's own stated "T in K" convention gives **283.6 kJ/kg**; plugging 98.7 (the °C value) directly into the K-calibrated correlation gives ~379.5 kJ/kg, close to the hand-calculated value. Judged as a unit mix-up in the hand calculation. This implementation strictly follows the stated K convention.

2. **Continuity at ξ→1.** Fatouh's h_mix does not vanish at ξ=1 (fit data only reached ξ=0.9); direct extrapolation would create a discontinuity at pure R22. The code linearly blends to pure R22 enthalpy over 0.9<ξ<1, guaranteeing continuity.

### Functions and samples

- `R22DMF_Hsol(T_C, ξ)`: solution enthalpy, kJ/kg.
- `R22DMF_H_R22L / R22DMF_H_R22V / R22DMF_H_DMF`: pure-component enthalpies.

- Hsol(30 °C, 0.5) = 130.26 kJ/kg
- Hsol(80 °C, 0.4) = 237.71 kJ/kg
- Hsol(0 °C, 0.3) = 88.57 kJ/kg

## 3. Code

**Excel VBA** (r22_dmf.bas): Import as a standard module, use directly as worksheet functions, e.g. `=R22DMF_BubbleP(40,0.5)`, `=R22DMF_Hsol(30,0.5)`.

**C** (r22_dmf.c): `gcc -O2 -Wall -o r22_dmf r22_dmf.c -lm` compiles with zero warnings. C matches the Python reference point-by-point, max deviation 5×10⁻⁷.

**Python** (r22_dmf.py): Reference implementation.

## 4. Validity range

- Bubble pressure: T −25 to 120 °C, ξ 0.10–1.00. Above ξ=0.80 and T>65 °C exceeds measured range (R22 near/above critical) — extrapolation, use with care.
- Solution enthalpy: T −20 to 95 °C, ξ 0–1.
- Pressure in bar, enthalpy in kJ/kg, temperature inputs in °C (converted to K internally).

---

*Data: Agarwal et al., 1982 (transcribed via Ardita, 2008); enthalpy correlation: Fatouh et al., 1993.*
*VBA and C source included, ready for engineering calculations.*

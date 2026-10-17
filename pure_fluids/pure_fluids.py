# R134a / R22 / R124 / H2O / NH3 / CH3OH / R32 / R218 / CO2 pure-substance saturation properties (reference implementation)
#
# Datum: CoolProp's built-in reference equations of state
#   R134a: Tillner-Roth & Baehr (1994); R22: CoolProp reference EOS
# Reference state (unified with the user's existing models): saturated-liquid enthalpy at 0°C = 100 kJ/kg
#   (CoolProp's default is 200 kJ/kg; shifted as a whole by -100)
#   R124: fit to the NIST WebBook saturation table (276 points, -153~122°C), see
#     the working-pair formula materials library document "R124 pure fluid - NIST table fit and Borde arbitration";
#     the table's enthalpy datum is likewise saturated liquid at 0°C = 200 kJ/kg, shifted as a whole by -100 (latent heat unchanged).
#     Psat is of Wagner type (exponents 1, 1.5, 3, 6): Tc=395.428K, Pc=36.245bar,
#     valid -40~110°C, max deviation vs. table 0.111%; hL/hV max deviations in the same band 1.11/1.63 kJ/kg
#
# Fitted forms:
#   Saturation pressure, Wagner equation: ln(P/Pc) = (Tc/T)·(a1·τ + a2·τ^1.5 + a3·τ^2.5 + a4·τ^5),
#     τ = 1-T/Tc, T in K, P in bar (the fit's internal unit; Pc is in bar;
#     the public interface Pref returns MPa and Tsat takes MPa, converting by x0.1 / x10 at the boundary)
#     R134a: Tc=374.21K, Pc=40.59bar, valid -50~95°C, max deviation 0.031%
#     R22:   Tc=369.30K, Pc=49.90bar, valid -50~90°C, max deviation 0.0065%
#   Saturated-liquid/vapour enthalpy: degree-6 polynomial h(t), t in °C, kJ/kg
#     R134a hL deviation 0.41, hV deviation 0.61 kJ/kg
#     R22   hL deviation 0.42, hV deviation 0.59 kJ/kg
# Saturation temperature Tsat(P): inverted from Psat by bisection.
#
# Six fluids added 2026-10-13 (source: compact fits to the NIST WebBook saturation tables; the full notes are in
#   fit-notes/): H2O (373 points, 1~373°C), NH3 (210 points, -77~132°C),
#   CH3OH (330 points, -90~239°C), R32 (215 points, -136~78°C),
#   R218 (219 points, -147~71°C), CO2 (601 points, -56~30°C).
#   Saturation pressures use the notes' adopted lnP-t degree-7 polynomial (ln(P/MPa)); this module returns MPa directly,
#   max deviations vs. table (full range / usual band): H2O 0.0291%/0.0128%, NH3 0.0272%/0.0027%,
#   CH3OH 0.1064%/0.0321%, R32 0.0609%/0.0147%, R218 0.1495%/0.0396%,
#   CO2 0.0099%/0.0059%; enthalpy degree-6 polynomials (max deviation in the usual band 0.29~5.51 kJ/kg,
#   larger near the critical end; per-band figures in each note). The enthalpies have been shifted from each table's own datum to the uniform datum
#   (saturated liquid at 0°C = 100 kJ/kg); shifts (kJ/kg): H2O +93.351889719,
#   NH3 -244.768062686, CH3OH +266.341441575, R32 -100.673431938,
#   R218 -100.177980782, CO2 -100.255791821 (constant term only; latent heats unchanged).
#   The authoritative standard for water remains the IAPWS formulation; this fit is a portable compact form and does not replace it.

import math

# ---------------- R134a ----------------
_R134a_Tc = 374.21
_R134a_Pc = 40.59
_R134a_W = (-7.6391282, 1.7650117, -2.6103553, -3.3657380)
_R134a_hL = (3.5283163e-11, -2.2259203e-09, -7.2651551e-08, 1.3659406e-05,
             1.4602205e-03, 1.3386046e+00, 9.9982381e+01)
_R134a_hV = (-5.4059642e-11, 3.2801028e-09, 1.2592287e-07, -2.1005140e-05,
             -1.2602316e-03, 5.9085680e-01, 2.9863031e+02)
_R134a_TLO, _R134a_THI = -50.0, 95.0

# ---------------- R22 ----------------
_R22_Tc = 369.30
_R22_Pc = 49.90
_R22_W = (-7.0486230, 1.4828095, -1.8223105, -2.8257753)
_R22_hL = (4.6681599e-11, -2.2286115e-09, -1.2586426e-07, 1.4969301e-05,
           1.5173919e-03, 1.1678030e+00, 9.9972867e+01)
_R22_hV = (-6.5412360e-11, 3.1584987e-09, 1.6628519e-07, -2.1606737e-05,
           -1.9128189e-03, 3.7574587e-01, 3.0508640e+02)
_R22_TLO, _R22_THI = -50.0, 90.0

# ---------------- R124 ----------------
# Source: fit to the NIST WebBook saturation table (Wagner exponents 1, 1.5, 3, 6; enthalpy degree-6 polynomial,
# shifted as a whole by -100 from the table datum (saturated liquid at 0°C = 200) to this module's uniform datum)
_R124_Tc = 395.428
_R124_Pc = 36.245
_R124_W = (-7.401179377235425, 1.4613603991162563, -3.476435267708954,
           -1.772232810745864)
_R124_hL = (3.101121704716488e-12, 6.118884579625834e-10, -1.0126584362284601e-08,
            -3.744431218418699e-06, 9.264564201937477e-04, 1.0995525531984227,
            1.0004767130193036e+02)
_R124_hV = (-4.7606354686130485e-12, -9.020883920792309e-10, 2.036341936229362e-08,
            4.234769176716097e-06, -3.8033802108463233e-04, 5.621038923140594e-01,
            2.5994742998138406e+02)
_R124_TLO, _R124_THI = -40.0, 110.0


def _wagner_pref(t_C, Tc, Pc, a):
    T = t_C + 273.15
    tau = 1.0 - T / Tc
    return Pc * math.exp((Tc / T) * (a[0] * tau + a[1] * tau ** 1.5
                                    + a[2] * tau ** 2.5 + a[3] * tau ** 5.0))


def _wagner_pref36(t_C, Tc, Pc, a):
    """Wagner variant (exponents 1, 1.5, 3, 6), the form used for the R124 fit."""
    T = t_C + 273.15
    tau = 1.0 - T / Tc
    return Pc * math.exp((Tc / T) * (a[0] * tau + a[1] * tau ** 1.5
                                    + a[2] * tau ** 3.0 + a[3] * tau ** 6.0))


def _poly6(c, t):
    return (((((c[0] * t + c[1]) * t + c[2]) * t + c[3]) * t + c[4]) * t + c[5]) * t + c[6]


def _tsat_bisect(P, pref_fn, t_lo, t_hi):
    # The unit of P is the same as the return unit of pref_fn (the caller is responsible for conversion)
    Plo, Phi = pref_fn(t_lo), pref_fn(t_hi)
    if not (Plo <= P <= Phi):
        return None
    lo, hi = t_lo, t_hi
    for _ in range(60):
        mid = 0.5 * (lo + hi)
        if pref_fn(mid) < P:
            lo = mid
        else:
            hi = mid
    return 0.5 * (lo + hi)


def _R134a_pref_bar(t_C):
    """R134a saturation pressure, internal value, bar (native unit of the Wagner fit)."""
    return _wagner_pref(t_C, _R134a_Tc, _R134a_Pc, _R134a_W)


def R134a_Pref(t_C):
    """R134a saturation pressure, MPa. t_C: °C, valid -50~95°C."""
    return 0.1 * _R134a_pref_bar(t_C)


def R134a_Tsat(P_MPa):
    """R134a saturation temperature, °C. P_MPa: MPa. Returns None when out of range."""
    return _tsat_bisect(10.0 * P_MPa, _R134a_pref_bar, _R134a_TLO, _R134a_THI)


def R134a_hliq(t_C):
    """R134a saturated-liquid enthalpy, kJ/kg. Reference state: saturated liquid at 0°C = 100 kJ/kg."""
    return _poly6(_R134a_hL, t_C)


def R134a_hgas(t_C):
    """R134a saturated-vapour enthalpy, kJ/kg. Reference state: saturated liquid at 0°C = 100 kJ/kg."""
    return _poly6(_R134a_hV, t_C)


def R134a_hlat(t_C):
    """R134a saturation latent heat, kJ/kg = hgas - hliq (same reference state; both enthalpies on the same datum)."""
    return R134a_hgas(t_C) - R134a_hliq(t_C)


def _R22_pref_bar(t_C):
    """R22 saturation pressure, internal value, bar (native unit of the Wagner fit)."""
    return _wagner_pref(t_C, _R22_Tc, _R22_Pc, _R22_W)


def R22_Pref(t_C):
    """R22 saturation pressure, MPa. t_C: °C, valid -50~90°C."""
    return 0.1 * _R22_pref_bar(t_C)


def R22_Tsat(P_MPa):
    """R22 saturation temperature, °C. P_MPa: MPa. Returns None when out of range."""
    return _tsat_bisect(10.0 * P_MPa, _R22_pref_bar, _R22_TLO, _R22_THI)


def R22_hliq(t_C):
    """R22 saturated-liquid enthalpy, kJ/kg. Reference state: saturated liquid at 0°C = 100 kJ/kg."""
    return _poly6(_R22_hL, t_C)


def R22_hgas(t_C):
    """R22 saturated-vapour enthalpy, kJ/kg. Reference state: saturated liquid at 0°C = 100 kJ/kg."""
    return _poly6(_R22_hV, t_C)


def R22_hlat(t_C):
    """R22 saturation latent heat, kJ/kg = hgas - hliq (same reference state; both enthalpies on the same datum)."""
    return R22_hgas(t_C) - R22_hliq(t_C)


def _R124_pref_bar(t_C):
    """R124 saturation pressure, internal value, bar (native unit of the Wagner fit)."""
    return _wagner_pref36(t_C, _R124_Tc, _R124_Pc, _R124_W)


def R124_Pref(t_C):
    """R124 saturation pressure, MPa. t_C: °C, valid -40~110°C (NIST-table Wagner fit)."""
    return 0.1 * _R124_pref_bar(t_C)


def R124_Tsat(P_MPa):
    """R124 saturation temperature, °C. P_MPa: MPa. Returns None when out of range."""
    return _tsat_bisect(10.0 * P_MPa, _R124_pref_bar, _R124_TLO, _R124_THI)


def R124_hliq(t_C):
    """R124 saturated-liquid enthalpy, kJ/kg. Reference state: saturated liquid at 0°C = 100 kJ/kg."""
    return _poly6(_R124_hL, t_C)


def R124_hgas(t_C):
    """R124 saturated-vapour enthalpy, kJ/kg. Reference state: saturated liquid at 0°C = 100 kJ/kg."""
    return _poly6(_R124_hV, t_C)


def R124_hlat(t_C):
    """R124 saturation latent heat, kJ/kg = hgas - hliq (same reference state; both enthalpies on the same datum)."""
    return R124_hgas(t_C) - R124_hliq(t_C)



# =============== Six fluids fitted to the NIST WebBook tables (added 2026-10-13) ===============
# Form: saturation pressure as an lnP-t degree-7 polynomial (the notes' adopted form, ln(P/MPa)=Σc_k t^k,
#   returned directly in MPa within the entry); enthalpy as a degree-6 polynomial (coefficients in descending powers, same order as _poly6).
# The enthalpy constant terms have been shifted from each table's own datum to this module's uniform datum (saturated liquid at 0°C = 100 kJ/kg);
#   see each fluid's note for the shift (constant term only; latent heats unchanged). Valid ranges and residuals: see the header note and fit-notes/.

# ---------------- H2O (shift +93.351889719 kJ/kg) ----------------
_H2O_LNP = (5.54627791673895e-18, -8.99249875691861e-15, 6.660700555390007e-12, -3.088083641876246e-09,
             1.056735995405781e-06, -0.0002954387998568004, 0.07259423527358563, -7.399704960820133)
_H2O_hL = (4.9253814056437e-12, -4.8364685293173926e-09, 1.8115766448129802e-06, -0.0003141174119157094,
             0.02553352332697852, 3.3541747407753046, 100.0)
_H2O_hV = (-8.083632440447619e-12, 7.910908004577575e-09, -2.951073494811462e-06, 0.0005046392594921277,
             -0.04153882947643235, 3.1701433360694287, 2583.8464687067276)
_H2O_TLO, _H2O_THI = 1.0, 373.0

# ---------------- NH3 (shift -244.76806269 kJ/kg) ----------------
_NH3_LNP = (1.1501679663496297e-16, -3.681466540446358e-14, 9.070213653911228e-12, -2.4759314474490567e-09,
             6.551063627525382e-07, -0.00015333383280607642, 0.03739502393748032, -0.8457026848887617)
_NH3_hL = (1.0230389195910096e-10, -9.01173619674778e-09, -7.693180171285098e-07, 8.148925711345767e-05,
             0.0049020842504556555, 4.529640315972919, 100.0)
_NH3_hV = (-1.5323246964436346e-10, 1.341154075047321e-08, 1.181178610537754e-06, -0.000132743256804236,
             -0.01090080493286388, 1.2129121114680004, 1364.0392422964662)
_NH3_TLO, _NH3_THI = -77.0, 132.0

# ---------------- CH3OH (shift +266.34144157 kJ/kg) ----------------
_CH3OH_LNP = (6.071697789417314e-17, -4.474383382147671e-14, 1.4922332158687438e-11, -3.713389940921318e-09,
             9.643627950530163e-07, -0.00025454685882528256, 0.06310145783702696, -5.507805919357708)
_CH3OH_hL = (5.573934158642428e-12, -1.8104866695124476e-09, 8.709794689054448e-08, 2.7396583808978296e-05,
             0.001358520746256356, 2.362545782283046, 100.0)
_CH3OH_hV = (-1.228628960059207e-11, 4.469399531774273e-09, -3.1756317512396483e-07, -4.548213600653677e-05,
             0.002018557942790822, 1.156097552141014, 1301.565002270651)
_CH3OH_TLO, _CH3OH_THI = -90.0, 239.0

# ---------------- R32 (shift -100.67343194 kJ/kg) ----------------
_R32_LNP = (4.985734545925537e-16, 8.088993550316065e-15, 7.23916818285453e-12, -2.4123562470111985e-09,
             5.690865248769261e-07, -0.00012346886007261548, 0.032029536226752524, -0.20703267077542895)
_R32_hL = (3.052117712232615e-11, 7.669342242883148e-09, 4.426168044128746e-07, -6.097377922612308e-06,
             0.0010654645657896644, 1.7643249519580528, 100.0)
_R32_hV = (-4.488337246373621e-11, -1.1379788910261148e-08, -6.764615880681746e-07, 7.561508556936408e-06,
             -0.0024175577393345023, 0.1589860001017608, 413.6297944744754)
_R32_TLO, _R32_THI = -136.0, 78.0

# ---------------- R218 (shift -100.17798078 kJ/kg) ----------------
_R218_LNP = (8.255415504414131e-16, 7.344897883851216e-14, 1.093452574911193e-11, -2.800385114611927e-09,
             6.13844960232108e-07, -0.00013063706572324828, 0.03248293004447796, -0.8809937809605295)
_R218_hL = (7.040720312389206e-12, 2.1911253182755153e-09, 1.9931060577128075e-07, 4.329266994236428e-06,
             0.0010980864706317968, 1.070171579409284, 100.0)
_R218_hV = (-1.0731550245287959e-11, -3.374732945181214e-09, -3.125522092678402e-07, -8.835005867404636e-06,
             -2.3183839296438865e-05, 0.596775089781136, 189.38572453841817)
_R218_TLO, _R218_THI = -147.0, 71.0

# ---------------- CO2 (shift -100.25579182 kJ/kg) ----------------
_CO2_LNP = (7.349267422320306e-15, 9.714937274844203e-13, 5.722737962459257e-11, -5.000472245728414e-10,
             5.236317080887681e-07, -9.20196795346934e-05, 0.02647312340946483, 1.2485141855617028)
_CO2_hL = (2.948691221375449e-09, 3.3584601264848553e-07, 1.0969134467517922e-05, 9.865777775779578e-05,
             0.006887751259917945, 2.4420397272329732, 100.0)
_CO2_hV = (-4.280078787604416e-09, -4.893910288449988e-07, -1.62198769938507e-05, -0.00015811780903671123,
             -0.012470655351837747, -0.5840479229797425, 330.2675971498235)
_CO2_TLO, _CO2_THI = -56.0, 30.0


def _poly7(c, t):
    return ((((((c[0] * t + c[1]) * t + c[2]) * t + c[3]) * t + c[4]) * t + c[5]) * t + c[6]) * t + c[7]


def _lnp_pref(t_C, c):
    """Saturation pressure from the lnP-t degree-7 polynomial: the notes' formula is natively in MPa; this module returns MPa directly."""
    return math.exp(_poly7(c, t_C))


def H2O_Pref(t_C):
    """H2O saturation pressure, MPa. t_C: °C (NIST-table fit, lnP-t degree-7 polynomial)."""
    return _lnp_pref(t_C, _H2O_LNP)


def H2O_Tsat(P_MPa):
    """H2O saturation temperature, °C. P_MPa: MPa. Returns None when out of range."""
    return _tsat_bisect(P_MPa, H2O_Pref, _H2O_TLO, _H2O_THI)


def H2O_hliq(t_C):
    """H2O saturated-liquid enthalpy, kJ/kg. Reference state: saturated liquid at 0°C = 100 kJ/kg (after the shift)."""
    return _poly6(_H2O_hL, t_C)


def H2O_hgas(t_C):
    """H2O saturated-vapour enthalpy, kJ/kg. Reference state as for hliq (after the shift)."""
    return _poly6(_H2O_hV, t_C)


def H2O_hlat(t_C):
    """H2O saturation latent heat, kJ/kg = hgas - hliq (the shift cancels; independent of the table reference state)."""
    return H2O_hgas(t_C) - H2O_hliq(t_C)


def NH3_Pref(t_C):
    """NH3 saturation pressure, MPa. t_C: °C (NIST-table fit, lnP-t degree-7 polynomial)."""
    return _lnp_pref(t_C, _NH3_LNP)


def NH3_Tsat(P_MPa):
    """NH3 saturation temperature, °C. P_MPa: MPa. Returns None when out of range."""
    return _tsat_bisect(P_MPa, NH3_Pref, _NH3_TLO, _NH3_THI)


def NH3_hliq(t_C):
    """NH3 saturated-liquid enthalpy, kJ/kg. Reference state: saturated liquid at 0°C = 100 kJ/kg (after the shift)."""
    return _poly6(_NH3_hL, t_C)


def NH3_hgas(t_C):
    """NH3 saturated-vapour enthalpy, kJ/kg. Reference state as for hliq (after the shift)."""
    return _poly6(_NH3_hV, t_C)


def NH3_hlat(t_C):
    """NH3 saturation latent heat, kJ/kg = hgas - hliq (the shift cancels; independent of the table reference state)."""
    return NH3_hgas(t_C) - NH3_hliq(t_C)


def CH3OH_Pref(t_C):
    """CH3OH saturation pressure, MPa. t_C: °C (NIST-table fit, lnP-t degree-7 polynomial)."""
    return _lnp_pref(t_C, _CH3OH_LNP)


def CH3OH_Tsat(P_MPa):
    """CH3OH saturation temperature, °C. P_MPa: MPa. Returns None when out of range."""
    return _tsat_bisect(P_MPa, CH3OH_Pref, _CH3OH_TLO, _CH3OH_THI)


def CH3OH_hliq(t_C):
    """CH3OH saturated-liquid enthalpy, kJ/kg. Reference state: saturated liquid at 0°C = 100 kJ/kg (after the shift)."""
    return _poly6(_CH3OH_hL, t_C)


def CH3OH_hgas(t_C):
    """CH3OH saturated-vapour enthalpy, kJ/kg. Reference state as for hliq (after the shift)."""
    return _poly6(_CH3OH_hV, t_C)


def CH3OH_hlat(t_C):
    """CH3OH saturation latent heat, kJ/kg = hgas - hliq (the shift cancels; independent of the table reference state)."""
    return CH3OH_hgas(t_C) - CH3OH_hliq(t_C)


def R32_Pref(t_C):
    """R32 saturation pressure, MPa. t_C: °C (NIST-table fit, lnP-t degree-7 polynomial)."""
    return _lnp_pref(t_C, _R32_LNP)


def R32_Tsat(P_MPa):
    """R32 saturation temperature, °C. P_MPa: MPa. Returns None when out of range."""
    return _tsat_bisect(P_MPa, R32_Pref, _R32_TLO, _R32_THI)


def R32_hliq(t_C):
    """R32 saturated-liquid enthalpy, kJ/kg. Reference state: saturated liquid at 0°C = 100 kJ/kg (after the shift)."""
    return _poly6(_R32_hL, t_C)


def R32_hgas(t_C):
    """R32 saturated-vapour enthalpy, kJ/kg. Reference state as for hliq (after the shift)."""
    return _poly6(_R32_hV, t_C)


def R32_hlat(t_C):
    """R32 saturation latent heat, kJ/kg = hgas - hliq (the shift cancels; independent of the table reference state)."""
    return R32_hgas(t_C) - R32_hliq(t_C)


def R218_Pref(t_C):
    """R218 saturation pressure, MPa. t_C: °C (NIST-table fit, lnP-t degree-7 polynomial)."""
    return _lnp_pref(t_C, _R218_LNP)


def R218_Tsat(P_MPa):
    """R218 saturation temperature, °C. P_MPa: MPa. Returns None when out of range."""
    return _tsat_bisect(P_MPa, R218_Pref, _R218_TLO, _R218_THI)


def R218_hliq(t_C):
    """R218 saturated-liquid enthalpy, kJ/kg. Reference state: saturated liquid at 0°C = 100 kJ/kg (after the shift)."""
    return _poly6(_R218_hL, t_C)


def R218_hgas(t_C):
    """R218 saturated-vapour enthalpy, kJ/kg. Reference state as for hliq (after the shift)."""
    return _poly6(_R218_hV, t_C)


def R218_hlat(t_C):
    """R218 saturation latent heat, kJ/kg = hgas - hliq (the shift cancels; independent of the table reference state)."""
    return R218_hgas(t_C) - R218_hliq(t_C)


def CO2_Pref(t_C):
    """CO2 saturation pressure, MPa. t_C: °C (NIST-table fit, lnP-t degree-7 polynomial)."""
    return _lnp_pref(t_C, _CO2_LNP)


def CO2_Tsat(P_MPa):
    """CO2 saturation temperature, °C. P_MPa: MPa. Returns None when out of range."""
    return _tsat_bisect(P_MPa, CO2_Pref, _CO2_TLO, _CO2_THI)


def CO2_hliq(t_C):
    """CO2 saturated-liquid enthalpy, kJ/kg. Reference state: saturated liquid at 0°C = 100 kJ/kg (after the shift)."""
    return _poly6(_CO2_hL, t_C)


def CO2_hgas(t_C):
    """CO2 saturated-vapour enthalpy, kJ/kg. Reference state as for hliq (after the shift)."""
    return _poly6(_CO2_hV, t_C)


def CO2_hlat(t_C):
    """CO2 saturation latent heat, kJ/kg = hgas - hliq (the shift cancels; independent of the table reference state)."""
    return CO2_hgas(t_C) - CO2_hliq(t_C)


if __name__ == "__main__":
    for name, P, hL, hV, Ts in [
            ("R134a", R134a_Pref, R134a_hliq, R134a_hgas, R134a_Tsat),
            ("R22", R22_Pref, R22_hliq, R22_hgas, R22_Tsat),
            ("R124", R124_Pref, R124_hliq, R124_hgas, R124_Tsat)]:
        print(f"== {name} ==")
        for t in [-40, -10, 0, 25, 50, 80]:
            print(f"  {t:4d}C: Pref={P(t):7.3f} MPa  hliq={hL(t):7.2f}  hgas={hV(t):7.2f} kJ/kg")
        print(f"  Tsat(1.0 MPa) = {Ts(1.0):.2f} C")

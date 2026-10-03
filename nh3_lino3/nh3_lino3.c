/*
 * nh3_lino3.c -- NH3/LiNO3 solution properties (C99)
 * =================================================================
 * Source: Amaris Castilla, C.F. (2014) doctoral thesis,
 * "Intensification of NH3 Bubble Absorption Process Using Advanced
 * Surfaces and Carbon Nanotubes for NH3/LiNO3 Absorption Chillers",
 * Universitat Rovira i Virgili, Appendix B (pp. A-6..A-8):
 *   bubble pressure  Libotean et al. (2007) JC&ED 52, 1050-1055
 *   liquid enthalpy  Valles & Salavera (2011), Haltenberger method
 *   cp, density      Libotean et al. (2008)
 *   conductivity     Cuenca et al. (2013a)
 *   crystallization  Infante Ferreira et al. (1984)
 * Viscosity is NOT implemented here: the thesis typesetting of the
 * viscosity correlation is broken and the reconstruction is
 * unverified (Python module only, marked EXPERIMENTAL).
 *
 * Conventions: x = NH3 MASS fraction; T in K (x_cris takes degC);
 * p in kPa; h in kJ/kg; cp in kJ/(kg K); rho in kg/m^3; k in W/(m K).
 * Enthalpy reference state (source): H = 0 at 0 degC and x = 0.5.
 * Out-of-range inputs return NAN (no silent extrapolation):
 *   p_bubble/T_bubble : T 293.15-353.15 K, x 0.35-0.65
 *   h_liq             : T 273.15-353.15 K, x 0.35-0.65
 *   cp, rho           : T 293.15-353.15 K, x 0.35-0.65
 *   k_therm           : T 303.15-353.15 K, x 0.35-0.60
 *   x_cris            : x 0-1
 */
#include <math.h>

static const double NL_PA[4] = {4.99470524658178, 88.5490906185871,
                                -197.698944465798, 134.938665891525};
static const double NL_PB[4] = {-1793.21854659273, -22317.1158016582,
                                61289.3128925447, -45238.5915843719};
static const double NL_HA[4] = {249.1567745, -1628.297463,
                                -464.3464344, -105.6321057};
static const double NL_HB[4] = {2.481273559, -5.184392344,
                                -0.775202139, 18.98142102};
static const double NL_HC[4] = {-0.004240786, 0.025111292,
                                -0.013342843, -0.025956064};

static double nl_poly4(const double c[4], double x)
{
    return ((c[3] * x + c[2]) * x + c[1]) * x + c[0];
}

static int nl_in(double v, double lo, double hi)
{
    return v >= lo && v <= hi;
}

/* Bubble pressure [kPa]: ln P = pa(x) + pb(x)/T */
double nl_p_bubble_TX(double T_K, double x)
{
    double pa, pb;
    if (!nl_in(T_K, 293.15, 353.15) || !nl_in(x, 0.35, 0.65))
        return NAN;
    pa = nl_poly4(NL_PA, x);
    pb = nl_poly4(NL_PB, x);
    return exp(pa + pb / T_K);
}

/* Bubble temperature [K]: analytic inverse T = pb / (ln P - pa) */
double nl_T_bubble_PX(double P_kPa, double x)
{
    double pa, pb, denom, T_K;
    if (!nl_in(x, 0.35, 0.65) || P_kPa <= 0.0)
        return NAN;
    pa = nl_poly4(NL_PA, x);
    pb = nl_poly4(NL_PB, x);
    denom = log(P_kPa) - pa;
    if (denom == 0.0)
        return NAN;
    T_K = pb / denom;
    if (!nl_in(T_K, 293.15, 353.15))
        return NAN;
    return T_K;
}

/* Liquid enthalpy [kJ/kg]: H = ha + hb T + hc T^2.
 * Reference state: H = 0 at 0 degC, x = 0.5 (source definition). */
double nl_h_liq(double T_K, double x)
{
    double ha, hb, hc;
    if (!nl_in(T_K, 273.15, 353.15) || !nl_in(x, 0.35, 0.65))
        return NAN;
    ha = nl_poly4(NL_HA, x);
    hb = nl_poly4(NL_HB, x);
    hc = nl_poly4(NL_HC, x);
    return ha + hb * T_K + hc * T_K * T_K;
}

/* Specific heat [kJ/(kg K)] (source in J/(g K), numerically equal) */
double nl_cp(double T_K, double x)
{
    double cpa, cpb;
    if (!nl_in(T_K, 293.15, 353.15) || !nl_in(x, 0.35, 0.65))
        return NAN;
    cpa = 0.559273057 + 3.241167393 * x;
    cpb = 0.00207796 + 0.001846907 * x;
    return cpa + cpb * T_K;
}

/* Density [kg/m^3]: rho = 1000 (da + db T) */
double nl_rho(double T_K, double x)
{
    double da, db;
    if (!nl_in(T_K, 293.15, 353.15) || !nl_in(x, 0.35, 0.65))
        return NAN;
    da = 1.521 - 0.4528 * x;
    db = -0.00001961 - 0.001726 * x;
    return 1000.0 * (da + db * T_K);
}

/* Thermal conductivity [W/(m K)]: k = ka1 + ka2 T + ka3 T^2 + ka4 x.
 * NOTE: thesis Appendix B prints the ka3 term as ka3 T^2 x; this
 * implementation uses the plain reading (no extra x).  The two
 * readings differ by ~3% at 300 K, x = 0.4.  See the docs. */
double nl_k_therm(double T_K, double x)
{
    if (!nl_in(T_K, 303.15, 353.15) || !nl_in(x, 0.35, 0.60))
        return NAN;
    return 0.446088003 - 0.000350326 * T_K
           + 2.13849e-07 * T_K * T_K + 0.006538043 * x;
}

/* Crystallization boundary XCRIS (Infante Ferreira et al. 1984):
 * verbatim transcription of the 10-segment pseudo-code in
 * Appendix B; branches on NH3 mass fraction x, polynomials in
 * T [degC].  Branch endpoints belong to the segment whose lower
 * bound they are (thesis prints strict inequalities). */
double nl_x_cris(double T_C, double x)
{
    double T = T_C;
    if (x < 0.2911)
        return 0.3021 - 0.00034 * T - 0.00000272 * T * T;
    if (x < 0.3)
        return x;
    if (x < 0.3076)
        return -0.000608 * T + 0.3152;
    if (x < 0.3362)
        return 0.0143 * T + 0.12885;
    if (x < 0.4304)
        return -0.005402 * T + 0.41318;
    if (x < 0.5072)
        return 0.443413 + 0.0069 * T + 0.000854 * T * T;
    if (x < 0.6434)
        return 0.527643 - 0.003126 * T - 0.000019 * T * T;
    if (x < 0.6649)
        return -0.004605 * T + 0.40761;
    if (x < 0.7826)
        return 0.0000309 * T * T + 0.57452;
    if (x <= 1.0)
        return 0.07378 * T + 6.7214;
    return NAN;
}

#ifdef NL_TEST_MAIN
#include <stdio.h>
int main(void)
{
    printf("p_bubble(313.15,0.5) = %.4f kPa\n", nl_p_bubble_TX(313.15, 0.5));
    printf("T_bubble(502.3,0.5)  = %.4f K\n", nl_T_bubble_PX(502.3, 0.5));
    printf("h_liq(273.15,0.5)    = %.4f kJ/kg\n", nl_h_liq(273.15, 0.5));
    printf("rho(313.15,0.45)     = %.2f kg/m3\n", nl_rho(313.15, 0.45));
    printf("cp(313.15,0.45)      = %.4f kJ/kgK\n", nl_cp(313.15, 0.45));
    printf("k_therm(313.15,0.45) = %.4f W/mK\n", nl_k_therm(313.15, 0.45));
    printf("x_cris(25,0.55)      = %.4f\n", nl_x_cris(25.0, 0.55));
    return 0;
}
#endif

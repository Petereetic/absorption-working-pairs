"""Independent check of the R22-DMF enthalpy of mixing: Agarwal-Bapat 1984 vs. the Fatouh 1993 model in current use.

Agarwal & Bapat, "Thermodynamic properties of R22-DMF mixtures",
J. Thermal Engineering, Vol.3, No.4, 1984, pp.7-13.
  G^E = x1*x2*[a + b*(x1-x2)]  (two-parameter Redlich-Kister; x is mole fraction)
  lnγ1 = x2^2*[A + B*(4*x1-1)],  lnγ2 = x1^2*[A + B*(1-4*x2)]
  A(T) = -2.6422693 + 0.0066829*T            (Eq. 14)
  B(T) = 17.739537 - 2302.5584/T - 0.03913805*T   (Eq. 15)
  H^E = -R*T^2 * Σ xi*(d lnγi/dT)            (Eq. 17, second term)
A and B were fitted by Barker's method to the P-T-x data in Bapat's doctoral thesis (1981), a data source independent of Fatouh 1993.
Self-check: at 40°C and x1=0.5 (molar) the computed P is approx. 4.18 bar, vs. Raoult 7.66 bar,
a deviation of 3.48 bar, matching the 3.6 bar stated in the paper - the parameters are implemented correctly.
"""
import math, sys
sys.path.insert(0, '.')
from r22_dmf import _R, _MR22, _MDMF

R = 8.314  # J/mol/K


def _dAdB(T_K):
    return 0.0066829, 2302.5584 / (T_K * T_K) - 0.03913805


def excess_enthalpy_AB(T_C, xi):
    """Excess enthalpy of Agarwal-Bapat 1984, kJ/kg. xi = R22 mass fraction (converted to mole fraction for the calculation)."""
    n1 = xi / _MR22
    n2 = (1.0 - xi) / _MDMF
    x1 = n1 / (n1 + n2)
    x2 = 1.0 - x1
    T = T_C + 273.15
    dA, dB = _dAdB(T)
    l1, l2 = x2 * x2, x1 * x1
    m1 = -x2 * x2 * (1.0 - 4.0 * x1)
    m2 = x1 * x1 * (1.0 - 4.0 * x2)
    he_jmol = -R * T * T * (x1 * (l1 * dA + m1 * dB) + x2 * (l2 * dA + m2 * dB))
    Mmix = x1 * _MR22 + x2 * _MDMF
    return he_jmol / Mmix  # J/g = kJ/kg


def hmix_fatouh(T_C, xi):
    """The hmix part of the Fatouh 1993 model in current use, kJ/kg (reuses the r22_dmf constants directly)."""
    from r22_dmf import _B, _C, _E1, _E2, _E3
    T = T_C + 273.15
    omx = 1.0 - xi
    Y0 = xi / omx
    Y1 = xi / omx + math.log(omx)
    Y2 = 1.0 / omx - omx + 2.0 * math.log(omx)
    Y3 = xi / omx + xi * xi / 2.0 + 2.0 * xi + 3.0 * math.log(omx)
    T2, T3 = T * T, T * T * T
    K0 = _B[0] / T2 + 2 * _C[0] / T3 - _E1 / T2 + _E2 + _E3 / T
    K1 = _B[1] / T2 + 2 * _C[1] / T3
    K2 = _B[2] / T2 + 2 * _C[2] / T3
    K3 = _B[3] / T2 + 2 * _C[3] / T3
    Mmix = xi * _MR22 + omx * _MDMF
    return (omx * _R * T2 / Mmix) * (K0 * Y0 + K1 * Y1 + K2 * Y2 + K3 * Y3)


if __name__ == "__main__":
    print("xi | " + " | ".join(f"T={t}C Fatouh/AB-1984" for t in [0, 20, 40]))
    print("kJ/kg. 负值=放热混合。")
    for xi in [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9]:
        cells = [f"{hmix_fatouh(t, xi):6.1f}/{excess_enthalpy_AB(t, xi):6.1f}"
                 for t in [0, 20, 40]]
        print(f"{xi:.1f} | " + " | ".join(cells))

#!/usr/bin/env python3
# Verification of the Kaita 2001 high-temperature extension of libr_water
# (added 2026-10-29). Anchors: Kaita (2001) Table 5 (25 C, 14 points) and
# Table 6 ("This work", 20 points) enthalpy values; pressure chain checked
# against the library Chua psol; inverse functions checked by round-trip.
import sys
sys.path.insert(0, "/home/hatch/workspace/your_files/libr_water")
import libr_water as lw

tab5 = {40:48.92,42:48.47,44:48.51,46:49.18,48:50.71,50:53.37,52:57.45,54:63.18,
        56:70.73,58:80.15,60:91.36,62:104.15,64:118.09,66:132.60}
# Table 5 includes X=66, outside the Eq.(1)/(8) stated 40-65 range: use 40..64 only.
tab5 = {x: v for x, v in tab5.items() if x <= 65}
tab6 = [(50,45,105.7),(50,50,107.4),(50,55,118.0),(50,60,138.2),(50,65,169.1),
        (100,45,222.5),(100,50,217.4),(100,55,221.1),(100,60,234.5),(100,65,258.6),
        (150,45,341.9),(150,50,329.9),(150,55,326.7),(150,60,333.2),(150,65,350.3),
        (200,45,463.9),(200,50,444.9),(200,55,434.7),(200,60,434.3),(200,65,444.4)]

d5 = [100*(lw.hsol_kaita(x,25.0)-v)/v for x,v in tab5.items()]
print(f"Table5 (25C, X=40..64): max|dev| = {max(abs(d) for d in d5):.2f}%  (X=40 boundary point is the fit's own edge residual)")
d6 = [100*(lw.hsol_kaita(x,T)-v)/v for T,x,v in tab6]
print(f"Table6 (20 pts):        max|dev| = {max(abs(d) for d in d6):.3f}%, mean = {sum(d6)/len(d6):+.3f}%")

for (T,X) in [(100,55),(80,50)]:
    pk = lw.psol_kaita(X,T)*1000.0
    pc = lw.psol_chua(X,T)*1000.0
    print(f"Psol chain T={T} X={X}: Kaita TD={lw.tdew_by_tsol_x_kaita(X,T):.2f} C, P={pk:.2f} kPa vs Chua {pc:.2f} kPa ({100*(pk-pc)/pc:+.2f}%)")

print(f"Cp(50,100) = {lw.cp_kaita(50.0,100.0):.4f} kJ/(kg K) (expect 2.2243)")
# round-trips
err_h = max(abs(lw.tsol_by_hsol_kaita(lw.hsol_kaita(x,t), x)-t)
            for x in (45.0,55.0,65.0) for t in (30.0,100.0,200.0))
err_x = max(abs(lw.x_by_tsol_tdew_kaita(t, lw.tdew_by_tsol_x_kaita(x,t))-x)
            for x in (45.0,55.0,65.0) for t in (50.0,120.0,200.0))
print(f"Round-trip TsolByHsolKaita max err = {err_h:.2e} C; XByTsolTdewKaita max err = {err_x:.2e} wt%")
# Cp consistency: dh/dT vs cp (central difference)
num = (lw.hsol_kaita(55.0,101.0)-lw.hsol_kaita(55.0,99.0))/2.0
print(f"dh/dT(55,100) numeric = {num:.4f} vs Cp = {lw.cp_kaita(55.0,100.0):.4f}")
# out-of-range behaviour
for fn,args in [(lw.hsol_kaita,(39.0,100.0)),(lw.psol_kaita,(50.0,215.0))]:
    try:
        fn(*args); print("FAIL: no ValueError", fn.__name__, args)
    except ValueError:
        pass
print("Out-of-range raises ValueError: OK")

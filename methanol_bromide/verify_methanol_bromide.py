# 验证：C 与 Python 逐点一致性 + 对论文自身数据的抽查
# 运行：python3 verify_methanol_bromide.py（需 gcc、scipy 仅用于 PCHIP 对照）
import math
import subprocess
import sys

sys.path.insert(0, ".")
import methanol_bromide as mb

subprocess.run(["gcc", "-O2", "-Wall", "-Wextra", "-o", "/tmp/mb_c",
                "methanol_bromide.c", "-lm"], check=True)
out = subprocess.run(["/tmp/mb_c"], capture_output=True, text=True, check=True).stdout

maxdev = 0.0
for line in out.strip().splitlines():
    f = line.split(",")
    if f[0] == "grid":
        T, w = float(f[1]), float(f[2])
        py = [mb.p_bubble_TW(T, w), mb.cp(T, w), mb.h_prime(T, w),
              mb.h_liq(T, w), mb.h_vap(T, w)]
        for cv, pv in zip(f[3:], py):
            maxdev = max(maxdev, abs(float(cv) - pv))
    elif f[0] == "inv":
        P, w = float(f[1]), float(f[2])
        maxdev = max(maxdev, abs(float(f[3]) - mb.T_bubble_PW(P, w)))
print("C vs Python  最大偏差: %.3g" % maxdev)

# PCHIP 与 scipy 对照（仅核对自研实现与标准算法一致）
try:
    from scipy.interpolate import PchipInterpolator
    p1 = PchipInterpolator(mb._W_NODES, mb._C1_NODES)
    p2 = PchipInterpolator(mb._W_NODES, mb._C2_NODES)
    dmax = 0.0
    for i in range(2001):
        w = 0.243 + (0.509 - 0.243) * i / 2000
        dmax = max(dmax, abs(p1(w) - mb._c1(w)), abs(p2(w) - mb._c2(w)))
    print("PCHIP vs scipy 最大偏差: %.3g" % dmax)
except ImportError:
    print("scipy 不可用，跳过 PCHIP 对照")

# 论文附录 A 等压温度表：P = 300 mmHg = 0.39997 bar 时的泡点温度
print("\n泡点温度抽查（附录 A，300 mmHg）:")
for w, tref in [(0.250, 419.0), (0.262, 411.7), (0.301, 391.4), (0.356, 380.3)]:
    t = mb.T_bubble_PW(0.39997, w)
    print("  w=%.3f  计算 %7.2f K  论文 %6.1f K  偏差 %+.2f K" % (w, t, tref, t - tref))

# 论文附录 A 汽化焓表
print("\nH' 抽查（附录 A 表，p.196）:")
for T, w, href in [(283.15, 0.25, 1940.0), (283.15, 0.356, 1601.0), (373.15, 0.25, 1645.0)]:
    hv = mb.h_prime(T, w)
    print("  T=%.0fC w=%.3f  计算 %7.1f  论文 %6.0f  偏差 %+.2f%%"
          % (T - 273.15, w, hv, href, 100.0 * (hv - href) / href))

# 论文表 3.7 实测比热（兼作式(3.4) B 末项符号的裁决证据：取 "-"）
print("\nCp 抽查（表 3.7 实测）:")
for tc, w, cref in [(51.3, 0.403, 1.27), (69.9, 0.403, 1.30),
                    (40.0, 0.311, 1.19), (80.6, 0.311, 1.26)]:
    cv = mb.cp(tc + 273.15, w)
    print("  t=%.1fC w=%.3f  计算 %.3f  实测 %.2f  偏差 %+.2f%%"
          % (tc, w, cv, cref, 100.0 * (cv - cref) / cref))

# 纯甲醇 Antoine 拟合误差（附录 A 的 7 个数据点）
print("\n纯甲醇 Antoine 拟合（附录 A 数据点）:")
for mmhg, tk in [(300, 316.7), (500, 328.3), (600, 332.6), (700, 336.4),
                 (800, 339.7), (900, 342.7), (1000, 345.4)]:
    pc = mb.meoh_psat_bar(tk) / 1.3332239e-3
    print("  T=%.1f K  计算 %7.2f mmHg  论文 %d mmHg  偏差 %+.2f%%"
          % (tk, pc, mmhg, 100.0 * (pc - mmhg) / mmhg))
print("  400 mmHg 处拟合温度 %.2f K（论文印 373.1 K，Ratio 列反推 323.1 K，判误印）"
      % mb.meoh_Tsat_bar(400 * 1.3332239e-3))

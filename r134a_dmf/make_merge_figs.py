# -*- coding: utf-8 -*-
"""合并研究配图(含 Han 2011):
图1 偏差随温度变化: Cui vs Han 并排对比;
图2 303.15K p-x 对比 (+Han 实验点);
图3 分温度 AARD: Cui vs Han。"""
import csv, sys, os
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np

from matplotlib.font_manager import FontProperties, fontManager
fontManager.addfont("/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc")
fp = FontProperties(fname="/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc")
matplotlib.rcParams["font.family"] = [fp.get_name()]
matplotlib.rcParams["axes.unicode_minus"] = False

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from r134a_dmf import bubble_p, psat_r134a, psat_dmf

W = os.path.dirname(os.path.abspath(__file__))
D = W + "/merge_figs/"
os.makedirs(D, exist_ok=True)

def load(name):
    pts = []
    with open(f"{W}/{name}") as f:
        for r in csv.DictReader(f):
            T, x1, pe = float(r["T_K"]), float(r["x1"]), float(r["p_kPa"])
            pc = bubble_p(T, x1)[0] * 1000.0
            pts.append((T, x1, pe, pc, (pc - pe) / pe * 100.0))
    return pts

cui = load("cui2007.csv")
han = load("han2011.csv")

# ---------- 图1: Cui vs Han 偏差线并排 ----------
fig, axes = plt.subplots(1, 2, figsize=(11, 4.6), sharey=True)
for ax, pts, title, ls, mk in [
    (axes[0], cui, "Cui 2007（90点）", "-", "o"),
    (axes[1], han, "Han 2011（112点）", "--", "^"),
]:
    Ts = sorted(set(p[0] for p in pts))
    cmap = plt.cm.coolwarm
    for i, T in enumerate(Ts):
        sub = sorted([p for p in pts if p[0] == T], key=lambda p: p[1])
        ax.plot([p[1] for p in sub], [p[4] for p in sub], ls + mk, ms=4, lw=1,
                color=cmap(i / max(len(Ts) - 1, 1)), label=f"{T:.0f}K")
    ax.axhline(0, color="k", lw=0.8, ls=":")
    ax.set_xlabel("R134a 液相摩尔分数 x1")
    ax.set_title(title, fontsize=11)
    ax.legend(ncol=3, fontsize=7)
    ax.grid(True, alpha=0.3)
axes[0].set_ylabel("相对偏差 (p_模型 − p_实验)/p_实验 [%]")
fig.suptitle("交付模型 vs 两套浙江大学数据：偏差都随温度系统性增大", fontsize=12)
fig.tight_layout()
fig.savefig(D + "fig1-dev-vs-T.png", dpi=300)
plt.close(fig)

# ---------- 图2: 303.15K p-x 对比 ----------
T0 = 303.15
p1s = psat_r134a(T0) * 1000.0
p2s = psat_dmf(T0) * 1000.0
xg = np.linspace(0.001, 0.999, 200)
pm = np.array([bubble_p(T0, x)[0] * 1000.0 for x in xg])
praoult = xg * p1s + (1 - xg) * p2s
sub_c = sorted([p for p in cui if abs(p[0] - T0) < 0.01], key=lambda p: p[1])
sub_h = sorted([p for p in han if abs(p[0] - T0) < 0.01], key=lambda p: p[1])

fig, ax = plt.subplots(figsize=(8, 4.6))
ax.plot(xg, praoult, "--", color="gray", lw=1.2, label="Raoult 理想溶液")
ax.plot(xg, pm, "-", color="#1f77b4", lw=1.8, label="交付模型（拟合自 Zehioua 2009）")
ax.plot([p[1] for p in sub_c], [p[2] for p in sub_c], "o",
        color="#d62728", ms=6, label="Cui 2007 实验点")
ax.plot([p[1] for p in sub_h], [p[2] for p in sub_h], "s",
        color="#2ca02c", ms=6, mfc="none", mew=1.6, label="Han 2011 实验点")
ax.set_xlabel("R134a 液相摩尔分数 x1")
ax.set_ylabel("泡点压力 p / kPa")
ax.set_title("303.15 K 等温线：两套浙江数据都落在模型曲线下方", fontsize=12)
ax.legend(fontsize=9)
ax.grid(True, alpha=0.3)
fig.tight_layout()
fig.savefig(D + "fig2-px-303K.png", dpi=300)
plt.close(fig)

# ---------- 图3: 分温度 AARD 对比 ----------
def aard_by_T(pts):
    out = {}
    for T in sorted(set(p[0] for p in pts)):
        sub = [p for p in pts if p[0] == T]
        out[T] = sum(abs(p[4]) for p in sub) / len(sub)
    return out

ac, ah = aard_by_T(cui), aard_by_T(han)
fig, ax = plt.subplots(figsize=(8, 4.6))
ax.plot(list(ac.keys()), list(ac.values()), "o-", color="#d62728", lw=1.6, ms=6, label="Cui 2007（90点）")
ax.plot(list(ah.keys()), list(ah.values()), "s--", color="#2ca02c", lw=1.6, ms=6, label="Han 2011（112点）")
ax.set_xlabel("温度 T / K")
ax.set_ylabel("AARD [%]")
ax.set_title("分温度 AARD：Han 2011 整体低于 Cui 2007，低温段模型外推良好", fontsize=12)
ax.legend(fontsize=9)
ax.grid(True, alpha=0.3)
for T, v in ah.items():
    if T in (263.15, 273.15, 283.15):
        ax.annotate(f"{v:.1f}%", (T, v), textcoords="offset points", xytext=(0, 8),
                    fontsize=8, ha="center", color="#2ca02c")
fig.tight_layout()
fig.savefig(D + "fig3-aard-vs-T.png", dpi=300)
plt.close(fig)
print("figures saved to", D)

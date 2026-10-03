# Absorption Working Pairs

A library of thermophysical property models for absorption refrigeration /
heat-pump working pairs. Every model is implemented three ways — a Python
reference implementation, a C implementation, and Excel VBA worksheet
functions — transcribed from the cited literature, numerically verified
against the source data, and shipped with its verification scripts and
bubble-point/dew-point temperature-glide figures.

The emphasis of this project is *provenance and checking*: each correlation
names its source, printed equations found to be inconsistent with their own
papers' data are documented and excluded rather than silently "fixed", and
cross-laboratory disagreements are reported with quantitative uncertainty
bands instead of being averaged away.

> **Note on sources.** The original papers and theses are **not**
> redistributed here (they remain under their publishers' copyright). Every
> model cites its source precisely so you can locate the original. Only our
> own code, formula notes, verification reports and figures are included.

> **VBA caveat.** The `.bas` modules were ported line-by-line from the
> verified Python/C code, but they have **not** been compiled or run in a
> real Excel session. Test them before relying on them.

## Working pairs

| Directory | Pair | Model source | Status |
|---|---|---|---|
| `ammonia_water/` | NH₃–H₂O | Pátek & Klomfar 1995 explicit correlations (bubble/dew temperature, vapour composition, enthalpies); transport properties after Conde Engineering (2004) | Transcription verified against the paper; C and Python agree to six decimals |
| `libr_water/` | LiBr–H₂O | Patterson & Perez-Blanco 1988 (ASHRAE Trans. 94(2)) full property set, with Chua et al. 2000 vapour-pressure and density correlations | C and Python cross-checked point-by-point (Patterson 36 pts × 8 functions; Chua 25 pts × 2) |
| `methanol_bromide/` | CH₃OH–(2LiBr–ZnBr₂), salt ratio 2:1 | El-Shamarka 1981 (PhD thesis, Cranfield) bubble point / Cp / enthalpies; density, viscosity and vapour pressure from Iedema 1984 (PhD thesis, TU Delft) | Verified against both theses' tables; the two sources agree on density within 0.5 % but differ on vapour pressure by up to ~20 % at w ≈ 0.35–0.40 — see the comparison note in the directory |
| `nh3_lino3/` | NH₃–LiNO₃ | Correlations compiled in Amaris (2014, PhD thesis, URV) App. B: Libotean et al. bubble pressure / Cp / density, Cuenca et al. thermal conductivity, Infante Ferreira et al. crystallisation limit | C and Python cross-checked on 1715 points; viscosity correlation not included (source not yet verified — see notes) |
| `pure_fluids/` | R134a, R22 (pure) | Wagner saturation-pressure equations and enthalpy polynomials fitted to the CoolProp reference EOS (Tillner-Roth & Baehr 1994 for R134a) | Max. deviation 0.031 % (R134a) / 0.0065 % (R22) on saturation pressure |
| `r134a_dma/` | R134a–DMA | Nezu et al. 2002 (IIR Commissions B1/B2/E1/E2, Guangzhou) bubble pressure and solution enthalpy | Python reference implementation only |
| `r134a_dmf/` | R134a–DMF | NRTL (γ–φ) model with parameters re-fitted here to Zehioua et al. 2009 data (the paper's own NRTL parameters belong to a PR+MHV1 framework and do not transfer) | Fit AARD 1.49 % on 58 training points; cross-laboratory validation vs. Han 2011, Cui 2007 and Deng 2014 gives an honest uncertainty of ≈8 % at 300 K and ≈20 % at 360 K — see the merge study in the directory |
| `r22_degdme/` | R22–DEGDME | Ando & Takeshita 1984 (Int. J. Refrigeration 7(3)) bubble pressure, heat capacity and mixing-heat correlations | Paper-reported deviations 0.79 % / 0.83 % / 0.72 % reproduced |
| `r22_dmf/` | R22–DMF | Bubble pressure fitted to Agarwal 1982 VLE data; solution enthalpy after Fatouh 1993 | Fit AARD 2.38 % on 132 points; a reconstruction report on Borde et al. 1978 shows two of its printed equations to be numerically inconsistent — they are documented and excluded |

## Repository layout

- One directory per working pair. Inside each you will find:
  - `<pair>.py` — Python reference implementation;
  - `<pair>.c` — C implementation (compiles warning-free with
    `gcc -O2 -Wall`);
  - `<pair>.bas` — Excel VBA worksheet functions (see the caveat above);
  - `公式说明.md` — formula notes (in Chinese): sources, equations,
    conventions, valid ranges and verification records;
  - `verify_*.py` / `validate_*.py` — verification scripts, with the
    extracted literature data (CSV) they check against;
  - `fig-glide-*.png` — temperature-glide figures (T–ξ diagram,
    ΔT vs. composition, ΔT vs. pressure). For pairs with a volatile
    absorbent (ammonia–water) ΔT is the true glide
    T_dew(p,z) − T_bubble(p,z); for non-volatile absorbents it is
    T_bubble − T_sat,pure — each figure caption states which convention
    applies.
- `docs/` — longer documents:
  - `喷射式三压吸收制冷循环文献综述.docx` — literature review (in Chinese)
    of the ejector three-pressure absorption cycle;
  - `吸收工质对泡点-露点温差曲线.docx` — bubble/dew temperature-difference
    summary across pairs (in Chinese);
  - `docs/research-notes/` — research notes on ionic-liquid working pairs
    ([mmim]DMP/CH₃OH, [bmim]Zn₂Cl₅/NH₃, EMISE/H₂O, [EMIM]DEP/H₂O).
    **Extraction in progress — no model code yet.**

## License

MIT — see [LICENSE](LICENSE). Copyright (c) 2026 Peng Li.

Model parameters remain the intellectual product of their original authors;
if you use this library in published work, please cite the original sources
listed in each directory's formula notes, not only this repository.

---

## 中文简介

本仓库是吸收式制冷/热泵工质对的热物性模型库。每个模型均以三种形式实现：
Python 参考实现、C 实现、Excel VBA 工作表函数；全部关联式转录自所标注的
原始文献，并已用原文数据逐点验算，附验证脚本与泡点–露点温差（温度滑移）
曲线图。已收录的工质对：氨–水、溴化锂–水、甲醇–(2LiBr–ZnBr₂)、
氨–硝酸锂、R134a/R22 纯物质、R134a–DMA、R134a–DMF、R22–DEGDME、
R22–DMF。编写原则是"出处可溯、数字可验"：印刷公式若与论文自身数据矛盾，
记录并排除，不私自修补；跨实验室分歧以定量不确定度如实报告。原始文献
PDF 不随仓库发布（版权原因），每对的公式说明中均给出精确出处。离子液体
工质对的提取工作在 `docs/research-notes/` 中进行，尚无模型代码。

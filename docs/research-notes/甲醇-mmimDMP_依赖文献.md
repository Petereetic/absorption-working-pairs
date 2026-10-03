# 甲醇/[mmim]DMP 工质对 — 陈伟博论模型依赖文献清单

对象：陈伟博士论文（中国科学院工程热物理研究所，2014）第 2–4 章 [mmim]DMP/CH₃OH 模型的全部外部文献依赖。
并入比对的三份已到手材料：郭媛媛等 2013（《制冷与空调》）、陈伟等 2013（《工程热物理学报》34(4): 689–693）、Chen & Liang 2016（Applied Thermal Engineering 99: 846–856）。
引用条目按各文献自身参考文献表原文转录（博论条目已经 200 dpi 读图核对）；标注存疑/未能核实处明确标"待核对"，未做任何补全猜测。

---

## 0. 依赖链总览

博论第 2 章的模型不是自测数据的产物，而是一条四级链：

**实测数据**（赵杰 2010 浓溶液 VLE + 赵瑾 2006 稀溶液 VLE）
→ **参数关联**（陈伟本人以 UNIFAC、Wilson 重新拟合，表 2.3/2.4 为作者自拟结果）
→ **焓组装**（纯组分 Cp 式 + Chen 方程潜热 + 甲醇气相 Cp 式，其中 Cp 式在博论中**未标注出处**）
→ **循环仿真**（第 2 章单效、第 4 章双效动态；第 4 章无新增物性依赖）。

第 3 章热导率是作者自测（数据在博论表 3.1 内完备），外部文献只承担方法与校验角色。

同批数据还有三个"平行版本"在外流通，依赖关系交错（详见 §5–§7）：
- 陈伟等 2013（工程热物理学报）= 博论第 2 章的中文期刊版（UNIFAC/Wilson 同一套）；
- Chen & Liang 2016（ATE）= 换用 **NRTL + 溶液 Cp 多项式 + Redlich–Kister 型过量焓** 的另一套参数化，参数分别引自梁世强 2010、梁世强 2011、He 2010；
- 郭媛媛等 2013 = 北航组用 He 2010 的经验关联式（密度/黏度/Cp/蒸气压）+ 梁世强 2010 的 NRTL 焓做的循环计算。

---

## 1. 博论第 2 章逐项溯源

### 1.1 蒸气压 / UNIFAC（§2.1，表 2.1–2.3）

**实测数据（表 2.1 的唯一来源，两篇）**：§2.1 正文写明——赵杰等测定 303.15–363.15 K、x_IL = 0.299–0.471（浓溶液）；赵瑾等测定 280–370 K、x_IL = 0.03–0.18（稀溶液）；表 2.1 即两家数据的合并转录。两篇原文还各自含一套 NRTL 参数（博论未转录，博论改用 UNIFAC/Wilson 重拟）。

- 博论 [86]：赵杰，梁世强．离子液体 [mmim]DMP-甲醇浓溶液气液平衡 [J]．化学工程，2010，38(3)：52-56．
- 博论 [87]：Zhao J, Jiang X C, Li C X. Vapor Pressure Measurement for Binary and Ternary Systems Containing a Phosphoric Ionic Liquid [J]. Fluid Phase Equilibria, 2006, 247(1-2): 190-198.

注：博论引言（论文 p.17）把数据来源标注为"[97,98]"，与参考文献表对不上（[97] 苏国萍 3ω 博士论文、[98] 徐宜发热系数测量，均热导率方法文献）——系博论标注错误，实际出处以 §2.1 正文的 [86]/[87] 为准（已读图核对）。

**表 2.3 UNIFAC 交互参数**：作者本人回归结果（§2.5 小结："基于已有文献报道的……饱和蒸气压实验数据，关联了……UNIFAC 模型"），回归对象即上两篇数据。**无外部参数文献依赖**，不需要上传任何参数表；但要复核回归，必须有 [86]/[87] 的原始数据（博论表 2.1 已转录数据点，可作临时替代，点数完整性待与原文核对）。

**表 2.2 基团 R/Q 参数**：表题标注博论 [90]：

- 博论 [90]（原文转录）：Juan A G, Isaies G F. Thermodynamics of mixtures with strongly negative deviations from Raoult's Law Part 4. Application of the DISQUAC model to mixtures of 1-alkanols with primary or secondary linear amines. Comparison with Dortmund UNIFAC and ERAS results [J]. Fluid Phase Equilibria, 2000, 168(1): 31-58.

⚠️ **标注存疑（重要）**：该文是 1-烷醇+胺体系的 DISQUAC 研究，不含离子液体基团的 UNIFAC 体积/表面积参数，不可能是 [mmim]（R=4.213、Q=4.105）与 DMP（R=2.984、Q=1.739）的真实出处。陈伟 2013 期刊版表 1 同样标注此文（其 [15]，作者全名 Juan Antonio González、Isaías García de la Fuente），两版标注一致地错。CH₃/OH 两值（0.901/0.848、1.000/1.200）是标准 UNIFAC 值；IL 基团值的真实出处**待核对**，候选为博论 [89]（Wang J F 等 2008，离子液体 UNIFAC 无限稀活度系数关联，文中应含 IL 基团划分与参数）。上传 [90] 只能证伪标注、不能解决问题；如需溯源应优先核对 [89]。

**UNIFAC 模型形式出处**（仅方法引用，非参数来源）：博论 [88] Wang D, Xuan A G. Study on gas-liquid equilibria with the UNIFAC model for the systems of synthesizing dimethyl carbonate [J]. Fluid Phase Equilibria, 2011, 302(1-2): 269-273；博论 [89] Wang J F, Sun W, Li C X, Wang Z H. Correlation of infinite dilution activity coefficient of solute in ionic liquid using UNIFAC model [J]. Fluid Phase Equilibria, 2008, 264(1-2): 235-241。

**纯甲醇饱和蒸气压**：博论未给 Antoine 式及其出处（其 UNIFAC 关联直接对溶液压力数据拟合）。Chen 2016 版另行给出了 Antoine 常数（见 §6)。复现博论路线时此项按博论原样处理即可，不构成上传需求。

### 1.2 过量焓 / Wilson（§2.2.1，表 2.4）

**表 2.4 参数为作者本人回归**（a₁、b₁、a₂、b₂，ARD = 0.0067；正文"关联的结果如表 2.3 所示"系笔误，应为表 2.4）。论文没有任何 [mmim]DMP/CH₃OH 过量焓实测数据，回归对象只能是与 UNIFAC 同一的 VLE 数据（由活度系数的温度依赖导出 H^E）——此点论文未明言，属据文本的推断，标**待核对**。因此 Wilson 一路**无独立的外部数据依赖**，数据源同 [86]/[87]。

模型形式出处（方法引用）：博论 [91] 王皓，陆康，彭璇．基于 Wilson、UNIQUAC 和 NRTL 活度系数模型的离子液体体系的相平衡比较 [J]．低温学报，2013，40(1)：10-15（刊名与卷号按博论原文转录，待核对）；博论 [92] 李胜迎．醇+（酮、离子液体）二元体系的过量焓测定、关联和 COSMO-type 模型应用 [D]．2008，杭州：浙江大学．

注意：Wilson 式中的纯组分摩尔体积比 V_m1/V_m2，博论未给数值（复现缺口，非文献依赖问题；可由 [mmim]DMP 分子量 208.19 与其密度 1.22 g/cm³ 推算，但博论未写明，提取时须注明所采用值）。

### 1.3 溶液焓组装（§2.2.2–2.2.3）

- **纯组分定压比热式 (2.21)/(2.22)**：c_p,IL = 1.6673 + 0.0028·t；c_p,methanol = 1.6894 + 0.0273·t（t 为 °C；式 (2.22) 下标在博论中误印为 c_p,IL，已读图确认）。**两式在博论中均无任何出处标注**（已逐页读图核对）。这是博论依赖链上唯一的"无名"环节。疑似出处为博论 [79]（见 §2）——梁世强、赵杰的浓溶液热物性实验研究，且陈伟 2013 期刊版把同页的纯 IL 物性（分解温度 551 K、玻璃化温度 195 K、密度 1.22 g/cm³、黏度 223.67 mPa·s）明确标注为该文 [10]（即博论 [79]）；博论引言同一组数值则未标注。**待原文核对**。
- **甲醇气化潜热（Chen 方程，式 2.23）**：博论 [93] Chen N H. Generalized correlation for latent heat of vaporization [J]. Journal of Chemical Engineering Data, 1965, 10(1): 207-210。方程与甲醇常数（T_b = 337.75 K、T_c = 512.58 K）博论已完整转录，原文仅作核对。
- **甲醇过热蒸气比热式 (2.25)**：博论 [94] 房鼎业，应卫勇，朱炳辰．加压下含甲醇混合气体定压热容、粘度与导热系数 [J]．化肥设计，1989，6(1)：31-38。公式博论已完整转录（含全部系数与单位说明），原文仅作核对。
- 焓参考态（0 °C 时两纯组分比焓均取 418.60 kJ/kg）为作者自定约定，无文献依赖。

### 1.4 纯 [mmim]DMP 物性（第 2 章引言）

分解温度 551 K、玻璃化温度 195 K、密度 1.22 g/cm³、黏度 223.67 mPa·s：博论未标注；陈伟 2013 期刊版同组数值标注其 [10] = 博论 [79]（梁世强，赵杰 2011，见 §2 条目）。密度、黏度在博论中再无其他出现（全博论无密度/黏度关联式）。

## 2. 关键条目：博论 [79]（多链交汇点）

- 博论 [79]：梁世强，赵杰．离子液体 [mmim]DMP-甲醇浓溶液热物性实验研究 [J]．工程热物理学报，2011，32(3)：441-444．（Chen 2016 [23] 给出英文题名 "Experimental study on the thermal properties of ionic liquids [mmim]DMP/methanol solution" 及作者 S.Q. Liang, J. Zhao, Y.X. Guo, L.L. Jia。）

它在四条链中反复出现：博论 §1.3 称本研究"基于赵杰等[79]前期……气液相平衡及热力学性质研究的基础"；陈伟 2013 文以其为纯 IL 物性出处（[10]）；Chen 2016 的溶液 Cp 系数（表 3，甲醇对）引自它（[23]）；郭媛媛 2013 亦引（其 [2]）。博论 Cp 式 (2.21)/(2.22) 的真实出处极可能在此文（浓溶液 Cp 实测与拟合），**须原文核对**。

## 3. 博论第 3 章热导率（自测，无数据类外部依赖）

表 3.1 数据与表 3.2 Random mixing 参数均为作者自测自拟，博论内完备，**不需要上传任何数据文献**。外部文献仅三类：

- 方法源头（独立探头 3ω）：博论 [108] 邱琳，郑兴华，苏国萍，唐大伟．具有独立探头的 3ω 技术测量固体热导率 [J]．工程热物理学报，2011，32(4)：621-624；[109] Qiu L, Zheng X H, Zhu J, Tang D W. Non-destructive measurement of thermal effusivity of a solid and liquid using a freestanding serpentine sensor-based 3ω technique [J]. Review of Scientific Instruments, 2011, 82(8): 086110；[110] Qiu L, Tang D W, Zheng X H, Su G P. The freestanding sensor-based 3ω technique for measuring thermal conductivity of solids: Principle and examination [J]. Review of Scientific Instruments, 2011, 82(4): 045106；多层导热模型式 (3.1) 引 [111] Dames C, Chen G. 1ω, 2ω, and 3ω methods for measurements of thermal properties [J]. Review of Scientific Instruments, 2005, 76(12): 124902（正文称"Borça 推导"，与所引条目名实不符，附带记录）；温升公式 (3.7) 引 [112] Qiu L, Zheng X H, Su G P, Tang D W. Design and application of a freestanding sensor based on 3ω technique for thermal conductivity measurement of solids, liquids and nanopowders [J]. International Journal of Thermophysics, 2011, 34(12): 2261-2275（年份与卷号在博论中自相矛盾，按原文转录，待核对）。装置背景另引 [101] 王建立，朱建军，宋辰兴，张兴．3ω 法测量纳米流体热导率 [J]．化工学报，2011，62(S1)：81-86。
- 校验值（仅对比、不参与拟合）：纯甲醇 λ = 0.201 [113]、0.198 [114] W/(m·K)；纯水 λ = 0.611 [115]、0.601 [116] W/(m·K)。[113] Naziev M Y, Bashirov M M, Abdulagatovb I M（姓按博论原文转录，疑为 Abdulagatov 之误植，待核对）. High-temperature and high-pressure experimental thermal conductivity for the pure methanol and binary systems methanol + n-propanol, methanol + n-octanol, and methanol + n-undecanol [J]. Fluid Phase Equilibria, 2004, 226(2): 221-235；[114] Assael M J, Charitidou E, Wakeham W A. Absolute Measurements of the Thermal Conductivity of Mixtures of Alcohols with Water [J]. International Journal of Thermophysics, 1989, 10(4): 793-803；[115] Chandrasekar M, Suresh S, Chandra A. Experimental investigations and theoretical determination of thermal conductivity and viscosity of Al₂O₃/water nanofluid [J]. Experimental Thermal and Fluid Science, 2010, 34(2): 210-216；[116] Mintsa H A, Roy G, Nguyen C T, Doucet D. New temperature dependent thermal conductivity data for water-based nanofluids [J]. International Journal of Thermal Sciences, 2009, 48(2): 363-371。
- Random mixing 模型理论源：[117] Mayer J E. Statistical mechanics of condensing systems. V. Two-component Systems [J]. Journal of Physical Chemistry, 1939, 43(1): 71-95；当量摩尔分数修正引 [118] Yokozeki A. Solubility of refrigerants in various lubricants [J]. International Journal of Thermophysics, 2001, 22(4): 1057-1071。模型式与参数博论已全给。
- 期刊版：博论 [121] Chen W, Qiu L, Liang S Q, Zheng X H, Tang D W. Measurement of thermal conductivities of [mmim]DMP/CH₃OH and [mmim]DMP/H₂O by freestanding sensor-based 3ω technique [J]. Thermochimica Acta, 2013, 560(1): 1-6 —— 与博论第 3 章同内容，博论在手即无须此文。

## 4. 博论第 4 章（无新增物性依赖）

动态模型直接沿用第 2 章物性模型；外部引用只有：建模方法背景 [119] Bittanti 等（会议论文，博论条目不全，按原文）；验证对比的 H₂O/LiBr 双效实验运行条件引 [120] Fu D G, Poncia G, Lu Z. Implementation of an object-oriented dynamic modeling library for absorption refrigeration systems [J]. Applied Thermal Engineer（刊名按博论原文，疑为 Applied Thermal Engineering 之误植）, 2006, 26(2-3): 217-225 —— 仅定性对比，不参与物性计算。
注：第 4 章引言"前期研究结果[83, 107, 121]"与同章"Cai[79]"均为编号错位（[83] 为 Kim 2012、[107] 为 Wang & Sen 3ω 分析、[79] 为梁世强 2011，均与上下文不符；Cai 的 CO₂/[bmim]PF₆ 动态模型实为参考文献表 [75]）。属博论著录混乱，不产生新的上传需求。

## 5. 郭媛媛等 2013（已到手）§1 物性方程与出处

郭媛媛，朱磊，赵竞全．以 [mmim]DMP-甲醇为工质对的吸收式制冷循环研究 [J]．制冷与空调，2013，13(3)：57-60．（北京航空航天大学）其 §1 全部方程如下（系数表均印在郭文内，文内自足）：

| 节 | 物性 | 方程 | 标注出处 | 数据范围（原文） |
|---|---|---|---|---|
| §1.1 | 密度 | ρ = α + βT，α、β 为 IL 质量分数 x₂ 的四次多项式（表 1） | [3] | 295–325 K；x_IL（摩尔分数）= 0.203/0.399/0.603/0.805/1.000 |
| §1.2 | 黏度 | η = η_∞·exp(E_a/RT)，η_∞、E_a 为 x₂ 的五次多项式（表 2） | [3] | 298.15–323.15 K；同上浓度 |
| §1.3 | 比热容 | c_p = c_p0 + aT，c_p0、a 为 x₂ 的五次多项式（表 3） | [3] | 298.15–323.15 K；x = 0.203/0.399/0.591/0.810/1.000（正文误写"密度"，应为比热容） |
| §1.4 | 蒸气压 | 实测 ln p 对 1/(T−33.424) 线性；郭自拟式 (4)：T = 1/(0.00457 − 0.0015ε − 0.000261115 ln p) + 33.424，与 [3] 实测平均相对误差 0.056% | [3]（数据）；式 (4) 为郭自拟 | IL 质量分数 ε = 0.500/0.413/0.303/0.203/0.104 |
| §1.5 | 溶液焓 | 式 (5)：h(ε,T) 多项式 + h^E；h^E 用 NRTL 式 (6)，g 差取 A+BT 形式 | [4] | 三参数 NRTL（表 4）用于 ε∈(0.1773, 0.7492)；五参数（表 5）用于 ε∈(0.7492, 0.8745) |
| §1.6 | 甲醇蒸气焓 | Watson 汽化潜热式 (7)（ΔH₁ = 9.129 kcal/mol @0 °C，n 的三次多项式系数全给）+ 液相焓取式 (5) 在 ε=0 的特例 | [5] | — |

郭文参考文献（物性相关条目全文转录）：
- [1] 赵杰，王立，梁世强，等．离子液体在吸收式制冷中的应用研究进展 [C]// 2009 中国制冷学会学术年会．北京，2009: 28．（综述，非物性数据源）
- [2] 梁世强，赵杰，郭永献，等．离子液体 [mmim]DMP-甲醇溶液热物性实验研究 [J]．工程热物理学报，2011，32(3)：441-444．（= 博论 [79]；郭文仅在引言 [1-3] 并引中出现，§1 方程未单独引它）
- [3] He Zongbao, Zhao Zongchang, Zhang Xiaodong, et al. Thermodynamic properties of new heat pump working pairs: 1, 3-Dimethylimidazolium dimethylphosphate and water, ethanol and methanol [J]. Fluid Phase Equilibria, 2010 (298): 83-91．（= 博论 [38]）
- [4] 梁世强，赵杰，王立，等．离子液体型新工质对吸收式制冷循环 [J]．工程热物理学报，2010 (10)：1627-1630．（= Chen 2016 [15]；博论参考文献表中无此条）
- [5] 唐宏青．甲醇的基础物性数据公式 [J]．兰化科技，1989，7(1)：44-48．
- [6] 吴业正．制冷原理及设备 [M]．西安交通大学出版社，1996．（教材）
- [7] Yokozeki A. Theoretical Performances of Various Refrigerant-Absorbent Pairs in a Vapor-Absorption Refrigeration Cycle by the Use of Equations of State [J]. Applied Energy, 2005, 80(4): 383-399．（仅作传统工质对对比工况来源）

**与博论依赖链的同源性判定**：
- 郭文的密度/黏度/Cp/蒸气压全部溯源到 **He 等 2010**（大连理工大学赵宗昌组），与博论第 2 章的数据源（北京组赵杰/赵瑾）**不同源**；He 文在博论中只是绪论综述条目 [38]，未被博论第 2 章采用。注意郭 §1.4 的蒸气压是 He 的数据（ε = 0.104–0.500 质量分数，折摩尔分数约 0.017–0.134，稀溶液区），与赵瑾的稀溶液数据是不同实验室的平行测量。
- 郭文的焓/NRTL 溯源到梁世强 2010（与博论同组），与 Chen 2016 的 NRTL 参数同源（见 §6）。
- **郭文能否替代必需清单中的某篇**：不能替代赵杰 [86]/赵瑾 [87]（体系不同源、且郭蒸气压只是 5 个组成的自拟合式）；可以**临时替代 He 2010 的 ρ/η/Cp 关联式**（系数已转录在郭表 1–3 中，属二手转录，正式提取仍应以 He 原文为准）；郭文自身又依赖 He 2010 [3] 与梁世强 2010 [4] 两篇原文。

## 6. Chen & Liang 2016（已到手）物性模型清单与溯源

Wei Chen, Shiqiang Liang. Thermodynamic analysis of absorption heat transformers using [mmim]DMP-H₂O and [mmim]DMP-CH₃OH as working fluids [J]. Applied Thermal Engineering, 99 (2016): 846–856. 其 §2 对 [mmim]DMP/CH₃OH 用的模型与博论**不是同一套**：

| 物性 | 2016 文模型 | 参数表 | 标注出处 | 博论对应 |
|---|---|---|---|---|
| 蒸气压 | NRTL：P = x₂γ₂P₂^S，τ 取 τ⁽⁰⁾+τ⁽¹⁾/T 形式 | 表 1（α = 0.700 等 5 参数） | [15] 梁世强 2010 | 博论为 UNIFAC（表 2.3），无对应 |
| 纯甲醇饱和压 | Antoine 式 (5) | 表 2（A = 7.205，B = 1581.993，C = −33.439） | [22] Senol 2013 | 博论未给 |
| 溶液 Cp | 式 (6)：ω（IL 质量分数）二次 × (1, T, T²) 多项式 | 表 3（甲醇对 C_i 全为 0，实际只剩线性 T 项） | [23] 梁世强 2011（= 博论 [79]） | 博论为纯组分线性式 (2.21)/(2.22)，形式不同 |
| 过量焓（298.15 K） | 式 (7)：Redlich–Kister 型 x₁x₂ΣA_i(2x₂−1)^i | 表 4（A = −8.190, −3.257, 0.371） | [24] He 2010（= 博论 [38]） | 博论为 Wilson 温度依赖式，无对应 |
| 溶液焓组装 | 式 (8)/(9)：h₂₉₈.₁₅ + ∫Cp dT | — | [25] Cai 2014 组装法；[26] Kim & Kohl 2014 | 对应博论 §2.2.2 |
| 甲醇过热蒸气焓 | 式 (10) + Chen 方程潜热 | 表 5 临界参数（T_c = 512.58 K 等，出处未标注，推定教科书 [30]，待核对） | 蒸气焓式引 [27]（作者自引 [bmim]Zn₂Cl₅/NH₃ 文）；Chen 方程正文误标 [28]，实为 [29] Chen N H 1965（其条目年份误印 1962） | 对应博论 §2.2.3 |

2016 文物性相关条目（原文转录）：[14] L. Dong, D.X. Zheng, J. Li, N. Nie, X.H. Wu, Suitability prediction and affinity regularity assessment of H2O + imidazolium ionic liquid working pairs of absorption cycle by excess property criteria and UNIFAC model, Appl. Energy 98 (2012) 326–332（= 博论 [84]，供 H₂O 对参数，与甲醇对无关）；[15] S.Q. Liang, J. Zhao, L. Wang, X.L. Huai, Absorption refrigeration cycle utilizing a new working pair of ionic liquid type, J. Eng. Thermophys. 31 (2010) 1627–1630；[18] A.W. Islam, M.H. Rahman, A review of Barker's activity coefficient method and VLE data reduction, J. Chem. Thermodyn. 44 (2012) 31–37（= 博论 [126]，VLE 归约方法）；[22] A. Senol, Solvation-based vapour pressure model for (solvent + salt) systems in conjunction with the Antoine equation, J. Chem. Thermodyn. 67 (2013) 28–39；[23] S.Q. Liang, J. Zhao, Y.X. Guo, L.L. Jia, Experimental study on the thermal properties of ionic liquids [mmim]DMP/methanol solution, J. Eng. Thermophys. 32 (2011) 441–444（= 博论 [79]）；[24] Z.B. He, Z.C. Zhao, X.D. Zhang, H. Feng, Thermodynamic properties of new heat pump working pairs: 1,3-dimethylimidazolium dimethylphosphate and water, ethanol and methanol, Fluid Phase Equilib. 298 (2010) 83–91（= 博论 [38]）；[29] N.H. Chen, Generalized correlation for latent heat of vaporization, J. Chem. Eng. Data 10 (1962) 207–210（年份按 2016 文原文，实为 1965，待核对）。

**评估（能否作首要提取源）**：
- 对 2016 文自己的 NRTL 模型栈：**可以**。式 (1)–(11) 与表 1–5 在出版商 PDF 中齐全、文本层干净，做 [mmim]DMP/CH₃OH 的 NRTL 版泡点/Cp/焓模型无须回博论抠图（唯多列表格的列对应关系在提取时仍须对 PDF 版面核一眼，纯文本抽取会错位）。
- 但它**替代不了博论**：① 无 UNIFAC/Wilson 模型（博论的核心关联）；② 无表 2.1 原始 VLE 数据全表；③ 无热导率（第 3 章）与双效动态模型（第 4 章）；④ 无密度、黏度（两版都没有）；⑤ 其 Cp 是溶液多项式，与博论纯组分式 (2.21)/(2.22) 互不能替代。
- 其参数仍是二手转录：NRTL 参数的原始拟合在 [15] 梁世强 2010、Cp 系数的原始实验在 [23] 梁世强 2011、H^E 系数在 [24] He 2010——正式建库时这三篇是 2016 文的"上游"，见 §8 清单。

## 7. 陈伟等 2013 期刊版（已到手）与博论参数表核对

陈伟，李兰兰，梁世强，郭永献，成克用，唐大伟．[mmim]DMP/CH₃OH 吸收式制冷热力性能研究 [J]．工程热物理学报，2013，34(4)：689-693．（博论 [96] 是其姊妹英文版：Chen W, Liang S Q, Guo Y X, Cheng K Y, Gui X H, Tang D W. Thermodynamic performances of [mmim]DMP/methanol absorption refrigeration [J]. Journal of Thermal Science, 2012, 21(6): 557-563。）

其文献 [11]、[12]（全文转录，期刊附英文著录）：
- [11] Zhao Jie, Liang Shiqiang. Vapor Liquid Equilibrium for High Concentration Solution of 1, 3-dimethylimidazolium Dimethylphosphate/Methanol [J]. Chemical Engineering, 2010, 38(3): 52–56．（赵杰，梁世强．离子液体 [mmim]DMP-甲醇浓溶液气液平衡 [J]．化学工程，2010，38(3)：52-56．）= 博论 [86]
- [12] Zhao J, Jiang X C, Li C X, et al. Vapor Pressure Measurement for Binary and Ternary Systems Containing a Phosphoric Ionic Liquid [J]. Fluid Phase Equilibria, 2006, 247(1/2): 190–198．= 博论 [87]

即 2013 文引言"实测饱和蒸气压数据来自 [11]、[12]"与博论 §2.1 的 [86]/[87] 完全同源同篇。

**参数表逐值核对结果**：
- UNIFAC 基团 R/Q（2013 表 1 vs 博论表 2.2）：**一致**。2013 给更多有效位（R：0.9011、1.000、4.2132、2.9844；Q：0.848、1.200、4.105、1.739），博论为三位小数舍入值。两文同标出处为 González & García de la Fuente 2000（2013 [15] = 博论 [90]），标注存疑问题同 §1.1。
- UNIFAC 交互参数（2013 表 2 vs 博论表 2.3）：36 个数值（a_nm、b_nm、c_nm × 12 个基团对）**逐一对应一致**（差异仅印刷位数多少，如博论 −793.811 对 2013 的 −793.81、博论 58.399 对 2013 的 58.400）。**结论：UNIFAC 部分（博论表 2.2/2.3）可直接以 2013 期刊版为提取源，无须回博论扫描件抠图。**
- Wilson 参数（2013 表 3 vs 博论表 2.4）：b₁ = −32.060、a₂ = −36231.025、b₂ = 101.863 三项一致；**a₁ 不一致：2013 为 4.832 J/mol，博论为 54.83184**。两数呈"54.83184 ≈ 5|4.83184、4.832 ≈ 4.83184 舍入"的关系，疑博论多植一个"5"，但仅凭版面不能裁决——提取 Wilson 时须先以表 2.1 数据复算 ARD（博论自报 0.0067）定夺，或以英文姊妹版（博论 [96]，J. Thermal Science 2012）为第三票。此为当前两版之间**唯一**的实质性数值分歧。
- 其余物性：纯 IL 物性（551 K/195 K/1.22 g·cm⁻³/223.67 mPa·s）在 2013 文中标注其 [10]（梁世强，赵杰．离子液体 [mmim]DMP-甲醇溶液热物性实验研究 [J]．工程热物理学报，2011，32(3)：441-444 ＝ 博论 [79]）；溶液焓只给混合式 h = (1−ω)h₁ + ωh₂ + h^E（式 13），**未印**纯组分 Cp 式、Chen 方程与甲醇气相 Cp 式（这三件仍只有博论 §2.2.2–2.2.3 有全文，且 Cp 式无出处）；2013 文无密度、无黏度、无热导率内容。其方法引用 [13]（= 博论 [88]）、[14]（= 博论 [89]）、[16]（李胜迎 2008 学位论文 = 博论 [92]）与博论一致。

## 8. 需要用户上传的分级清单

### A. 必需（没有原文就无法复现或无法核对，且论文内无完备替代）

1. **赵杰，梁世强．离子液体 [mmim]DMP-甲醇浓溶液气液平衡 [J]．化学工程，2010，38(3)：52-56．**（博论 [86] / 陈伟 2013 [11]）
   用途：博论表 2.1 高浓度段（x_IL = 0.299–0.471）VLE 原始数据的唯一出处，UNIFAC（表 2.3）与 Wilson（表 2.4）两套回归的拟合对象；其自带 NRTL 参数博论未转录。论文内替代：博论表 2.1 转录了数据点（可临时用），但点数完整性、实验条件与 NRTL 原参数须原文。
2. **Zhao J, Jiang X C, Li C X. Vapor Pressure Measurement for Binary and Ternary Systems Containing a Phosphoric Ionic Liquid [J]. Fluid Phase Equilibria, 2006, 247(1-2): 190-198.**（博论 [87] / 陈伟 2013 [12]）
   用途：表 2.1 低浓度段（x_IL = 0.03–0.18）VLE 原始数据唯一出处，同上。论文内替代：同上（博论表 2.1 转录）。
3. **梁世强，赵杰，郭永献，贾丽丽．离子液体 [mmim]DMP-甲醇溶液热物性实验研究 [J]．工程热物理学报，2011，32(3)：441-444．**（博论 [79] / 陈伟 2013 [10] / 郭 2013 [2] / Chen 2016 [23]；作者英文著录 S.Q. Liang, J. Zhao, Y.X. Guo, L.L. Jia）
   用途：四条链的交汇点——纯 [mmim]DMP 物性（分解温度、密度、黏度）的标注出处；博论 Cp 式 (2.21)/(2.22) 的疑似原始出处（博论未标注，须此文裁决）；Chen 2016 溶液 Cp 系数（表 3）的原始实验。论文内替代：无。
4. **He Z B, Zhao Z C, Zhang X D, Feng H. Thermodynamic properties of new heat pump working pairs: 1,3-Dimethylimidazolium dimethylphosphate and water, ethanol and methanol [J]. Fluid Phase Equilibria, 2010, 298: 83-91.**（博论 [38] / 郭 2013 [3] / Chen 2016 [24]）
   用途：密度、黏度关联式的源头（博论完全缺失此两项，郭文 §1.1/§1.2 为二手转录）；Chen 2016 过量焓系数（表 4）的原始出处；另含一套独立 VLE 数据可作第三方校验。论文内替代：郭文表 1–3 转录了 ρ/η/Cp 关联式系数（临时可用，正式提取应以原文为准）。
5. **梁世强，赵杰，王立，怀秀兰．离子液体型新工质对吸收式制冷循环 [J]．工程热物理学报，2010，31(10)：1627-1630．**（Chen 2016 [15] / 郭 2013 [4]；博论未著录）
   用途：Chen 2016 表 1 甲醇对 NRTL 参数的原始拟合出处；郭文 §1.5 焓/NRTL 的来源。条件性必需：采用 2016 版 NRTL 模型栈时必需；只做博论 UNIFAC/Wilson 版时可缺。论文内替代：参数已转录于 Chen 2016 表 1 与郭文表 4/表 5（两处可互校）。

### B. 有更好、无亦可（论文内已转录完备，原文仅作核对/溯源）

6. **Chen N H. Generalized correlation for latent heat of vaporization [J]. Journal of Chemical Engineering Data, 1965, 10(1): 207-210.**（博论 [93] / Chen 2016 [29]）—— Chen 方程博论已完整转录；注意 Chen 2016 条目把年份误印为 1962。
7. **房鼎业，应卫勇，朱炳辰．加压下含甲醇混合气体定压热容、粘度与导热系数 [J]．化肥设计，1989，6(1)：31-38．**（博论 [94]）—— 甲醇气相 Cp 式 (2.25) 博论已完整转录。
8. **González J A, García de la Fuente I. Thermodynamics of mixtures with strongly negative deviations from Raoult's Law. Part 4… [J]. Fluid Phase Equilibria, 2000, 168(1): 31-58.**（博论 [90] / 陈伟 2013 [15]，博论条目作者名简写为 "Juan A G, Isaies G F"）—— 表 2.2 R/Q 的标注出处，但内容为 DISQUAC、不含 IL 基团参数，上传只能证伪标注；R/Q 真实出处待核对，候选为下一条。
9. **Wang J F, Sun W, Li C X, Wang Z H. Correlation of infinite dilution activity coefficient of solute in ionic liquid using UNIFAC model [J]. Fluid Phase Equilibria, 2008, 264(1-2): 235-241.**（博论 [89] / 陈伟 2013 [14]）—— 博论引作 UNIFAC 方法参考；同时是 IL 基团 R/Q 真实出处的候选（待核对）。
10. **Wang D, Xuan A G. Study on gas-liquid equilibria with the UNIFAC model for the systems of synthesizing dimethyl carbonate [J]. Fluid Phase Equilibria, 2011, 302(1-2): 269-273.**（博论 [88] / 陈伟 2013 [13]）—— 仅方法参考。
11. **王皓，陆康，彭璇．基于 Wilson、UNIQUAC 和 NRTL 活度系数模型的离子液体体系的相平衡比较 [J]．低温学报，2013，40(1)：10-15**（博论 [91]，刊名卷号待核对）与**李胜迎．醇+（酮、离子液体）二元体系的过量焓测定、关联和 COSMO-type 模型应用 [D]．浙江大学，2008**（博论 [92] / 陈伟 2013 [16]）—— Wilson 模型形式参考，非参数来源。
12. **Naziev et al. 2004（博论 [113]）、Assael et al. 1989（博论 [114]）** —— 热导率校验值（0.201/0.198 W/(m·K)）博论已转录；水的校验值 [115]/[116] 同理。
13. **Mayer 1939（博论 [117]）、Yokozeki 2001（博论 [118]）** —— Random mixing 模型理论源，模型式博论已全给。
14. **Fu D G, Poncia G, Lu Z. Applied Thermal Engineering, 2006, 26(2-3): 217-225**（博论 [120]）—— 第 4 章定性验证用，与物性参数无关。
15. **Chen W, et al. Journal of Thermal Science, 2012, 21(6): 557-563**（博论 [96]）—— 博论第 2 章英文姊妹版；已有 2013 中文版在手时可缺，但可作 Wilson a₁ 之争（4.832 vs 54.83184）的第三票。
16. **唐宏青．甲醇的基础物性数据公式 [J]．兰化科技，1989，7(1)：44-48**（郭 2013 [5]）—— 郭文 §1.6 的 Watson 潜热式已在郭文内完整转录。

### C. 已在手、无须上传

- 陈伟博论（2014）本体；郭媛媛等 2013；陈伟等 2013（工程热物理学报）；Chen & Liang 2016（ATE）。
- 博论第 3 章热导率的方法文献（[101]、[108]–[112]）：数据与模型在博论内完备，均不需上传。

## 9. 附：博论著录问题汇总（提取时须知）

1. 引言数据来源误标 [97,98]（实为 [86]/[87]）；参考文献表 [37]、[55]、[86] 三条为同一篇（赵杰 2010）的重复著录。
2. 表 2.2 的 R/Q 出处 [90] 标注错误（见 §1.1）；式 (2.22) 下标误印（两式同标 c_p,IL，后者应为甲醇）；§2.2.1 正文"表 2.3"应为表 2.4；图 2.2 题注"UNIFAC"应为 Wilson。
3. 第 4 章 [83, 107, 121] 与 Cai[79] 编号错位（见 §4）。
4. Wilson a₁ 两版分歧：博论 54.83184 vs 陈伟 2013 的 4.832（见 §7），提取前必须裁决。
5. Chen 2016 的小瑕疵：Chen 方程引文号误标 [28]（应 [29]），[29] 年份误印 1962（应 1965）；表 5 临界参数未标注出处。

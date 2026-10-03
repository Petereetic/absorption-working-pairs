# 用 Aspen Plus 模拟 R134a–DMF 吸收循环的文献调研（物性设置交代情况）

调研日期：2026-09-30。范围：公开可检索的期刊/会议论文，只收录明确用 Aspen Plus 建模 **R134a–DMF** 吸收循环的文献。

## 结论（先说）

**没有找到一篇把 Aspen Plus 物性设置（property method、二元交互参数来源/数值）交代清楚到可复现程度的 R134a–DMF 论文。**
唯一能核实全文的一篇（Wang 2021）恰恰是物性方法完全没写的典型。找到的 4 篇 Aspen+R134a/DMF 文献全部出自同一个课题组（山东建筑大学王强组），建模思路一脉相承，但没人写清楚物性方法。

## 一、用了 Aspen Plus 的 R134a–DMF 文献（按证据强度排序）

### 1. Wang et al. 2021 —— 全文已核实，物性方法没写 ❌

- 标题：Simulation analysis of R134a/DMF absorption refrigeration system based on Aspen Plus
- 出处：IOP Conf. Ser.: Earth Environ. Sci. 766, 012075
- DOI：https://doi.org/10.1088/1755-1315/766/1/012075
- 已有全文（原文 PDF 未随本仓库发布）
- 交代了的：模块选型（蒸发器/冷凝器/吸收器=Heater、精馏塔=RadFrac、节流阀=VALVE2、溶液换热器=HeatX）；初始参数引自 Yokozeki 2005（注：正文引文编号错位，[4]实为 Zehioua 2010a、[5]才是 Yokozeki）；结论（回流比 0.5~0.7、R134a 56 wt%、发生 131°C、吸收 28°C 时 COP 最优 0.494；69°C 热源可驱动，COP 0.44；热量衡算偏差 0.68%<1%）。
- **缺的**：全文没写 property method、没写二元交互参数来源与数值，**不可复现**。吸收器用 Heater 绕开了吸收过程建模。

### 2. Hui, Hao, Yan, Wang 2017 —— 摘要确认用了 Aspen，物性方法未知（未能核实全文）⚠️

- 标题：The Collector Matching Analysis of Solar Cooling System Based on Three Kinds of Working Medium
- 出处：Procedia Engineering 205 (2017)
- DOI：https://doi.org/10.1016/j.proeng.2017.10.090
- 摘要原文确认："With the help of Aspen Plus software, the three working fluid systems of **LiBr/H2O, NH3/H2O, and R134a/DMF** are established."（与 Wang 2021 同一课题组）
- 开放全文地址：https://www.sciencedirect.com/science/article/pii/S1877705817346465/pdf
- **缺的**：开放全文被 Cloudflare 拦住自动下载（需真人浏览器打开），未能核实正文是否写了物性方法。→ 建议用浏览器人工打开上址核对。

### 3. Zhang, Cai, Zhou 2020（ book chapter）—— 标题确认基于 Aspen Plus，物性方法未知（未能核实全文）⚠️

- 全题：Performance Studies of R134a-Dimethylformamide Absorption Refrigeration System for Utilizing Bus Exhaust Gas **Based on Aspen Plus Software**
- 出处：Springer《Environmental Science and Engineering》, 2020, pp. 307–319（与 Wang 2021、Hui 2017 同一学校/课题组）
- DOI：https://doi.org/10.1007/978-981-13-9524-6_33
- **缺的**：Springer 闭源章节，未能核实全文，不知是否交代物性方法。

### 4. Chen, Ripin, Wang 2026 —— 摘要确认用 Aspen Plus 建模，物性方法未知（未能核实全文）⚠️

- 标题：Multi-Objective System Optimization of an R134a/DMF Absorption Refrigerator Based on an Artificial Neural Network Algorithm and Particle Swarm Optimization
- 出处：IEEE SECE 2026（会议论文，closed access）
- DOI：10.1109/sece68717.2026.11519049
- 摘要原文确认："the process modeling software **Aspen Plus** is used to model and simulate a single-effect R134a/DMF absorption refrigeration system"（ANN 6-11-2 结构拟合 COP 与㶲效率，R²>0.99；PSO 优化得 COP 0.523、㶲效率 10.7%）
- **缺的**：IEEE 闭源，未能核实全文。

## 二、容易误判、实际不是 Aspen+R134a/DMF 的（排除说明）

- **Deng et al. 2014**（Int. J. Refrigeration 43, 176–186）：循环仿真用的是 **REFPROP（纯 R161 物性）+ NRTL**，不是 Aspen Plus。——排除。
- **Chen, Ripin, Wang 2024**（MDPI Energies 17, 4038）：Aspen Plus V12 只用于 PAFC（磷酸燃料电池）部分；R134a/DMF 吸收部分是**自建质量/能量衡算方程（式 13–15）**，全文无 "property method"/"NRTL" 字样。——吸收部分非 Aspen。
- **Kong et al. 2025**（Energy 328, 136440）：60 多对低 GWP 工质对的 VLE 用 **UNIFAC-DMD 预测**，不是 Aspen。链接：https://econpapers.repec.org/article/eeeenergy/v_3a328_3ay_3a2025_3ai_3ac_3as0360544225020821.htm
- **Gkouletsos et al. 2019**（Chem. Eng. Trans. 76, 121）：Aspen Plus V9 只用于 **NH3/H2O**（ASPENPCD/eNRTL 等），R134a/DMF 只出现在参考文献里。全文：http://www.aidic.it/cet/19/76/121.pdf
- **Suresh & Mani 系列、He 2009**：实验或自建模型，非 Aspen。

## 三、可复现的替代参照（非 Aspen，但方程写全了）

- **MDPI Energies 2024, 17, 4038** 的 R134a/DMF 吸收部分：质量/能量衡算方程（式 13–15）自建，参数透明，可复现；并有对 Yokozeki 2005 的验证算例（表 7：发生器 100°C/10.15 bar、蒸发 10°C/4.14 bar、吸收 30→26°C、冷凝 40°C/10.15 bar，COP 0.47→0.46）。DOI：https://doi.org/10.3390/en1704038
- **Yokozeki 2005**（Wang 2021 引为初始参数来源）：自建状态方程模型，非 Aspen。

## 四、给建模的工程建议

1. 这些论文都没交代的关键点，恰恰是 Aspen 复现 R134a–DMF 最难的一步：**Aspen databank 里 R134a–DMF 的二元交互参数缺省/不可靠，必须自己用 VLE 数据回归**（可用 Han et al. 2011 的 112 点或 Zehioua 2009 的 58 点）。
2. 若用户要在 Aspen 里复现，建议 property method 选 **NRTL-RK**（液相 NRTL + 气相 Redlich-Kwong，γ–φ 框架，与本研究的冻结模型口径一致），NRTL 参数用 Han 2011 数据自回归，而不是照搬文献里为 PR+MHV1 拟合的那套（Δg₁₂=2250、Δg₂₁=−2650 那套直接用于 γ–φ 会低估约 20%，见冻结模型说明）。
3. 待补核实（需真人浏览器）：Hui 2017 开放全文（上址 PDF）、Zhang 2020 Springer 章节、Chen 2026 IEEE 全文——三篇都可能是"交代了物性方法"的漏网之鱼，尤其是 Hui 2017（开放获取，打开即看）。

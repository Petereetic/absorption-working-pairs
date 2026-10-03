import os
# -*- coding: utf-8 -*-
"""生成《R134a-DMF 文献合并研究：四套数据、两次反转、一次证伪》.docx
(2026-09-30 修订版: 并入 Han et al. 2011 全文数据)"""
from docx import Document
from docx.shared import Pt, Inches, RGBColor
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.enum.table import WD_TABLE_ALIGNMENT
from docx.oxml.ns import qn
from docx.oxml import OxmlElement

FONT = "Microsoft YaHei"
IMG_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "merge_figs") + os.sep
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "R134a-DMF文献合并研究-四套数据两次反转一次证伪.docx")

TITLE = "R134a\u2013DMF 文献合并研究：四套数据、两次反转、一次证伪"
SUBTITLE = "Han 2011 全文到手：112 个点录入、验证、并入（2026-09-30 修订版）"

BODY = [
    ("text", "昨天把 Han et al. 2011 的全文拿到了\u2014\u2014《Solubility of Refrigerant 1,1,1,2-Tetrafluoroethane "
     "in the N,N-Dimethyl Formamide in the Temperature Range from (263.15 to 363.15) K》，"
     "J. Chem. Eng. Data 2011, 56, 1821\u20131826。第一个问题：它和 Cui 2007 是不是同一套数据换了个标题发表？"),
    ("text", "结论先行：不是。112 个点，温度网格、组成网格都和 Cui 2007 对不上，是同一实验室"
     "（浙江大学陈光明组，作者里有 Cui 2007 的第一作者 Xiaolong Cui）的另一次独立测量。"
     "合并研究从三套数据变成四套，本报告是上一版《三套数据、一次反转、一次证伪》的修订版。"),
    ("h2", "一、五篇文献的家谱（更新版）"),
    ("text", "五篇文献，四套独立实验数据："),
    ("table", "genealogy", [
        ["文献", "VLE 数据点数", "温度范围", "在本研究中的角色"],
        ["Zehioua et al., J. Chem. Eng. Data 2009", "58", "303.30\u2013353.24 K",
         "训练集：交付模型的 NRTL 参数拟合自此（静态法）"],
        ["Cui et al., ICR07, 北京 2007", "90", "283.15\u2013363.15 K",
         "独立验证集：循环法，温度跨度最大"],
        ["Han et al., J. Chem. Eng. Data 2011", "112", "263.15\u2013363.15 K",
         "新增独立验证集：称重合成法，点数最多、温区最宽"],
        ["Feng et al. 2016", "8", "293.15 / 303.15 K", "第三方参照（装置验证数据）"],
        ["He et al., Solar Energy 2009", "0（无独立数据）", "\u2014",
         "VLE 引自 Cui 2006a/b；贡献是 DMF 液体焓式(5)与循环仿真"],
    ]),
    ("text", "Han 的实验方法是合成法：称量 DMF 和 R134a 的质量进釜，气相按纯 R134a 处理"
     "（GC 验证气相中几乎无 DMF），气相持有量用 REFPROP 修正。不确定度：x₁ ±0.002；"
     "压力 120 kPa 以下 ±0.05 kPa、以上 ±1.6 kPa。11 条等温线，每 10 K 一档。"),
    ("h2", "二、112 个点是怎么录入的"),
    ("text", "表 3 是双栏排版，转录后做了三重校验：(1) 每行的 δp 列与 (pexp−pcal)/pexp "
     "逐行自洽，112 点最大差 0.012%（纯舍入）；(2) 293.15/303.15 K 的 x≈0.236 点与 "
     "Feng 2016 表 2 的装置验证点对上（115.98 / 155.83 kPa）；(3) 各等温线的 γ1,cal "
     "随温度单调下降、趋势光滑。数据存 han2011.csv，核查脚本 validate_han2011.py 可复现全部计算。"),
    ("h2", "三、同实验室自洽性：Han vs Cui"),
    ("text", "同一实验室、相隔四年的两批测量，在 293−313 K 吻合到约 1%：293 K 平均|偏差| 1.08%，"
     "303 K 1.13%，313 K 1.06%——这是实验室内部重复性的上限水平。但在两端分歧放大："
     "283 K 平均差 8.5%，333 K 以上 5−8%。"),
    ("text", "分歧最大的点：283.15 K、x=0.2412，Han 测得 96.35 kPa，Cui 同条件插值只有 73.33 kPa，"
     "差 31%。这正是上一版报告里 Cui 表 1 的疑似坏点（283.15 K / 0.2380 / 71.64 kPa）。"
     "Han 的独立测量和模型的独立预测（93.7 kPa）都站在 Han 一边——Cui 这个点是坏点，实锤了。"
     "方向纠正：它是偏低，不是上一版写的偏高。"),
    ("h2", "四、冻结模型验证 Han：AARD 10.1%"),
    ("text", "同样的苛刻条件：参数冻结（NRTL Δg12=868.1 J/mol、Δg21=−929.1 J/mol、α=0.3），"
     "直接预测 112 个点，一个参数都不许动。"),
    ("text", "结果：总体 AARD 10.07%，最大偏差 +24.40%（363.15 K，x1=0.7041）。"
     "偏差依然系统性为正、随温度单调增大："),
    ("table", "aard-han", [
        ["温度 (K)", "263.15", "273.15", "283.15", "293.15", "303.15", "313.15",
         "323.15", "333.15", "343.15", "353.15", "363.15"],
        ["AARD (%)", "2.60", "1.34", "3.02", "6.71", "8.24", "10.10",
         "11.40", "12.04", "13.53", "17.55", "18.57"],
    ]),
    ("img", "fig1-dev-vs-T.png",
     "图1  交付模型 vs 两套浙江大学数据：相对偏差都随温度系统性增大。左图 Cui 2007 的 283K 线"
     "在 x≈0.24 处的尖峰即上一版揪出的坏点；右图 Han 2011 的线系光滑、无尖峰。", 6.5),
    ("img", "fig3-aard-vs-T.png",
     "图3  分温度 AARD 对比：Han 2011（绿）整体低于 Cui 2007（红）。"
     "263/273K 是模型训练温区之外的外推，AARD 仅 1−3%——低温外推可信。", 6.0),
    ("text", "物理含义和上一版一致：两套浙江数据都呈现比 Zehioua 更强的 Raoult 负偏差，"
     "且偏差随温度放大。常数 Δg 的 NRTL 调和不了这两套数据——"
     "这是模型形式的问题，真要调和至少需要温度依赖的 Δg。"),
    ("text", "好消息在低温端：263/273 K 是 Han 独有、超出模型训练温区的部分，"
     "AARD 只有 2.6%/1.3%。模型向低温外推是好的，吸收制冷最常用的 270−300 K 区间反而最可信。"),
    ("h2", "五、第二次反转：283K 的 8.5% 里，一大半是坏点的锅"),
    ("text", "上一版我说“模型在 283K 的 AARD 是 8.53%”。现在 Han 来了："
     "模型 vs Han 在 283K 只有 3.02%。差的那 5 个百分点，是 Cui 的坏点贡献的——"
     "不是模型的错，是数据的错。上一版把这笔账记在了模型头上，这一版纠正。"),
    ("text", "连带修正上一版的坏点表：283.15 K / 0.2380 / 71.64 kPa 那一行，"
     "异常方向改为“偏低（Han 同条件 96.35 kPa，模型预测 93.7 kPa）”。"),
    ("h2", "六、票数更新：从 2:1 到 3:1（数据集计）"),
    ("text", "实验室版图现在是：浙江大学两套（Cui 2007 + Han 2011）+ 北京化工大学（Feng 2016）"
     " vs 巴黎高矿（Zehioua 2009）。三套数据集在 293−313 K 一致地给出比 Zehioua 更低的压力"
     "（更强的负偏差）。严格说浙大两套不完全独立（同一课题组），票数记 2.5:1，口头上说 3:1。"),
    ("img", "fig2-px-303K.png",
     "图2  303.15 K 等温线：Cui（红圈）与 Han（绿方块）实验点相互重合，"
     "都系统性落在模型曲线（蓝，拟合自 Zehioua 2009）下方。", 6.0),
    ("text", "不确定度口径更新：300K 附近维持约 8%；360K 附近从约 25% 收窄到约 20%"
     "（Han 18.6%、Cui 26.2% 取中间，Cui 那头还含坏点水分）。"),
    ("text", "一个诚实的注脚：Han 文中说他们的数据与 Zehioua 在 303K “偏差多在 2.3% 以内”、"
     "高温段最大约 8%，这和我们算出的 8.2%/17.5% 对不上。我们的模型对 Zehioua 训练集的最大拟合残差"
     "是 3.01%，所以这 8.2% 里最多 3% 能甩锅给拟合误差，剩下的是真实的数据分歧——"
     "最可能的解释是 Han 只在部分组成点上做了比较（他们自己也说高温段分歧集中在 DMF 摩尔分数 25−85% 的区间）。"
     "要彻底裁决，需要拿到 Zehioua 2009 表 5 的原始数据，这也是合并重拟合的前置条件。"),
    ("h2", "七、He 2009 式(8)：证伪结论维持"),
    ("text", "He et al.（Solar Energy, 2009）的 VLE 关联式（式8），上一版已用纯组分极限证伪："
     "X→1（纯 R134a）时给出 ln(p/kPa)=238.8，物理值约 6.6；X→0（纯 DMF）时给出约 42.6，"
     "物理值约 −0.7。差几十个数量级，不是漏个负号能解释的——印刷必有误，继续弃用。"),
    ("text", "连带推论不变：He 2009 基于该式做的吸收循环仿真定量结论需谨慎对待；"
     "同文 R22/R32 姊妹篇若用相同模板同样存疑，用前先做纯组分极限检验。"
     "He 2009 的式(5)（DMF 液体焓）不受影响，仍是交付模型 DMF 焓的来源。"),
    ("h2", "八、Cui 2007 坏点表（更新版）"),
    ("text", "做逐点 ln p−1/T 光滑性检查揪出的三个点，其中第一个已被 Han 2011 实锤："),
    ("table", "badpts", [
        ["温度 (K)", "x1", "p (kPa)", "异常（更新）"],
        ["283.15", "0.2380", "71.64", "偏低，已被 Han 2011 同条件点（96.35 kPa）证伪"],
        ["313.15", "0.1146", "101.65", "偏高（与 323.15K 点两者必有一误）"],
        ["333.15", "0.4966", "652.27", "偏低"],
    ]),
    ("text", "原始数据按原样存档（cui2007.csv），未做任何修改。后续合并拟合时这三点应剔除或降权。"),
    ("h2", "九、模型怎么办：参数仍不动"),
    ("text", "读者最可能问的问题：Han 都来了，模型要不要重拟合？"),
    ("text", "我的决定：参数暂时不动。理由有四："),
    ("text", "第一，现有参数对训练集（Zehioua）的描述是好的（1.49%），动参数等于丢掉已验证的部分；"),
    ("text", "第二，四套数据分歧的原因未明，此时做“平均意义上的拟合”等于用数学调和掩盖物理分歧；"),
    ("text", "第三，常数 Δg 的 NRTL 已被证明调和不了浙江数据与 Zehioua，真要合并至少需要"
     "Δg = a + bT，这是模型形式的升级，不是调参；"),
    ("text", "第四，Han 的低温段（263/273K）证明模型向低温外推是好的——"
     "恰好是吸收制冷最常用的温区，动参数的风险收益比更差了。"),
    ("text", "所以交付模型维持现状，caveat 按本报告第六节更新。需要合并重拟合（温度依赖 NRTL）的话，那是下一篇。"),
    ("h2", "十、一句话总结"),
    ("text", "五篇文献，四套数据；两次反转（Feng 不是离群值；283K 的偏差是 Cui 坏点的锅不是模型的锅），"
     "一次证伪（He 2009 式8印刷错误）；模型参数不动，不确定度：300K 附近 8%，360K 附近 20%。"),
    ("text", "1.49% 是拟合精度，10.1%（Han）/ 15.1%（Cui）是跨实验室验证精度——"
     "我选择把几个数字都摆出来，读者自己判断。"),
    ("h2", "参考文献"),
    ("text", "Han X. et al. Solubility of refrigerant 1,1,1,2-tetrafluoroethane in the N,N-dimethyl formamide "
     "in the temperature range from (263.15 to 363.15) K. J. Chem. Eng. Data 2011, 56, 1821−1826. "
     "（112 点，263.15−363.15 K；本报告新增数据 han2011.csv）"),
    ("text", "Cui X., Chen G., Li P., Wang Q. Vapor liquid equilibrium study of an absorption refrigeration "
     "working fluid of HFC-134a/DMF. Proc. 22nd Int. Congr. Refrigeration (ICR07), Beijing, 2007.（90 点）"),
    ("text", "Zehioua R. et al. Isothermal vapor-liquid equilibrium data of 1,1,1,2-tetrafluoroethane (R134a) "
     "+ dimethylformamide (DMF) working fluids for an absorption heat transformer. "
     "J. Chem. Eng. Data 2010, 55, 985−988.（58 点，交付模型训练集）"),
    ("text", "Feng L. et al. Measurement and correlation of isothermal vapor–liquid equilibrium of "
     "fluoroethane + dimethyl ether triethylene glycol, 1,1-difluoroethane + dimethyl ether triethylene glycol, "
     "and 1,1-difluoroethane + N-methyl-2-pyrrolidone systems. J. Chem. Eng. Data 2016, 61, 1146−1154. "
     "（表 2 的 8 个 R134a+DMF 点为装置验证数据，对照 Han 2011）"),
    ("text", "He Y. et al. Vapor–liquid equilibrium and refrigeration cycle simulation of HFC-134a/DMF. "
     "Solar Energy, 2009.（VLE 数据引自 Cui 2006a/b；式(8)印刷有误已弃用；式(5) DMF 焓在用）"),
]


def set_font(run, size=11, bold=False, color=None):
    run.font.size = Pt(size)
    run.font.bold = bold
    run.font.name = FONT
    r = run._element
    rPr = r.get_or_add_rPr()
    rFonts = rPr.find(qn("w:rFonts"))
    if rFonts is None:
        rFonts = OxmlElement("w:rFonts")
        rPr.append(rFonts)
    rFonts.set(qn("w:ascii"), FONT)
    rFonts.set(qn("w:hAnsi"), FONT)
    rFonts.set(qn("w:eastAsia"), FONT)
    rFonts.set(qn("w:cs"), FONT)
    if color is not None:
        run.font.color.rgb = color


def shade_cell(cell, color="D9E2F3"):
    tcPr = cell._tc.get_or_add_tcPr()
    shd = OxmlElement("w:shd")
    shd.set(qn("w:val"), "clear")
    tcPr.append(shd)


def add_para(doc, text, size=11, bold=False, space_after=6, align=None):
    p = doc.add_paragraph()
    p.paragraph_format.space_after = Pt(space_after)
    p.paragraph_format.line_spacing = 1.3
    if align is not None:
        p.alignment = align
    run = p.add_run(text)
    set_font(run, size=size, bold=bold)
    return p


def main():
    doc = Document()
    for section in doc.sections:
        section.top_margin = Inches(0.9)
        section.bottom_margin = Inches(0.9)
        section.left_margin = Inches(1.0)
        section.right_margin = Inches(1.0)

    style = doc.styles["Normal"]
    style.font.name = FONT

    add_para(doc, TITLE, size=20, bold=True, space_after=4)
    add_para(doc, SUBTITLE, size=12, bold=False, space_after=2)
    add_para(doc, "2026年9月30日", size=10, space_after=14)

    for kind, *rest in BODY:
        if kind == "text":
            add_para(doc, rest[0])
        elif kind == "h2":
            p = doc.add_paragraph()
            p.paragraph_format.space_before = Pt(14)
            p.paragraph_format.space_after = Pt(6)
            run = p.add_run(rest[0])
            set_font(run, size=14, bold=True, color=RGBColor(0x1F, 0x3A, 0x5F))
        elif kind == "table":
            _, rows = rest
            t = doc.add_table(rows=len(rows), cols=len(rows[0]))
            t.style = "Table Grid"
            t.alignment = WD_TABLE_ALIGNMENT.CENTER
            for i, row in enumerate(rows):
                for j, val in enumerate(row):
                    cell = t.cell(i, j)
                    cell.text = ""
                    pr = cell.paragraphs[0]
                    pr.paragraph_format.space_after = Pt(2)
                    pr.paragraph_format.space_before = Pt(2)
                    run = pr.add_run(val)
                    set_font(run, size=9.5, bold=(i == 0))
                    if i == 0:
                        shade_cell(cell)
            doc.add_paragraph().paragraph_format.space_after = Pt(6)
        elif kind == "img":
            fname, caption, width = rest
            p = doc.add_paragraph()
            p.alignment = WD_ALIGN_PARAGRAPH.CENTER
            p.add_run().add_picture(IMG_DIR + fname, width=Inches(width))
            add_para(doc, caption, size=9.5, space_after=10,
                     align=WD_ALIGN_PARAGRAPH.CENTER)

    doc.save(OUT)
    print("saved:", OUT)


if __name__ == "__main__":
    main()

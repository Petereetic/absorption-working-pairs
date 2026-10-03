/* Iedema 密度/黏度验算点测试（test_methanol_bromide.c）
 * 编译：gcc -O2 -Wall -Wextra -o test_mb test_methanol_bromide.c -lm
 * 验算点取自 Iedema1984_密度黏度提取.md（对论文表 2.7.2.2.1/2.7.3 数据）：
 *   rho(0.3483, 19.5°C, w_H=0) = 1661.5 kg/m3（提取记录计算值；实测 1664.5）
 *   rho(0.35,   25.0°C, w_H=0) = 1652.0 kg/m3
 *   eta(0.3916, 20°C) = 0.0204 Pa·s（实测 0.0212）
 *   eta(0.2919, 20°C) = 0.0535 Pa·s（实测 0.0524）
 * 容差：密度 ±1.5 kg/m3；黏度 ±3%（相对）。
 */
#include <stdio.h>
#include <math.h>

#define main mb_grid_main_unused
#include "methanol_bromide.c"
#undef main

static int chk(const char *name, double got, double expect, double tol)
{
    double d = got - expect;
    int ok = fabs(d) <= tol;
    printf("%s: got %.10g  expect %.10g  diff %+.4g  tol %.3g  -> %s\n",
           name, got, expect, d, tol, ok ? "OK" : "FAIL");
    return ok;
}

int main(void)
{
    int ok = 1;
    ok &= chk("rho(0.3483,292.65K,wH=0)", mb_rho_iedema(292.65, 0.3483, 0.0),
              1661.5, 1.5);
    ok &= chk("rho(0.35,298.15K,wH=0)", mb_rho_iedema(298.15, 0.35, 0.0),
              1652.0, 1.5);
    ok &= chk("eta(0.3916,293.15K)", mb_eta_iedema(293.15, 0.3916),
              0.0204, 0.0204 * 0.03);
    ok &= chk("eta(0.2919,293.15K)", mb_eta_iedema(293.15, 0.2919),
              0.0535, 0.0535 * 0.03);
    printf("%s\n", ok ? "ALL OK" : "SOME FAILED");
    return ok ? 0 : 1;
}

# FitTracker 视觉审查报告（impeccable · 2026-11）

> 工具：impeccable（npx，官方 detector CLI + audit/critique 方法论）
> 分报告：`test_run\visual-audit\web-audit.md`（官网）· `test_run\visual-audit\app-static\audit.md`（双端 app 静态）
> 证据：`test_run\visual-audit\detector\{web-src,legal,url-desktop,url-mobile}.json` + `url-detail.txt` + `app-static\wcag-contrast.txt`

## 结论摘要

无 P0（无「用户无法完成任务」级阻断）。官网 12/20 分，双端静态审计 18/19 色对达标。**最该修的 4 件事**：

| 优先级 | 问题 | 位置 |
|---|---|---|
| P1 | 肌群矩阵「未练到」标注对比度 2.7:1（需 4.5:1） | 官网 `span.pending`，detector 渲染实测 |
| P1 | 移动视口 16 处 9px 功能性文字（肌肉名），低于 11px 下限 | 官网 muscle-cell，detector 390×844 实测 |
| P1 | 双端 app 均无文字缩放处理（鸿蒙 maxFontScaleSize / Android fontScale 全目录 0 命中） | 双端，需设备大字号实拍确认截断 |
| P2 | legacy.css 约 60/130 个 class 零引用（已删复刻版遗留死重） | `web\src\legacy.css`，对账探针实跑 |

其余 finding（gradient-text/dark-glow/kicker 等 detector slop 签名）多数为官网**有意**的设计语言，建议在 `.impeccable` ignores 登记例外而非修改；详见分报告 P0–P3 表（web 12 项 + app 7 项）。

## 双端顺带发现（归 dual-parity 管辖，本审查只登记）

双端色板不同源：主背景 #09100F vs #0F0F0F、卡片底 #16211F vs #171717、错误态 #D77C78（红）vs #FFD7C5（浅杏）——同一品牌同一屏颜色差一个色阶/色族。

## 未验证项（诚实声明）

1. **模拟器截图采样未执行**：`hdc list targets` 返回 [Empty]、`adb devices` 空列表（本会话实测），双端设备均离线。按计划降级路径：静态审计已覆盖可测面，截图目检请用官网已有 7 屏实机截图（`web\public\*.jpg`）或后续设备上线时补采。
2. **主控模型不可看图**：视觉审美终裁归用户目检，本报告的确定性测量（对比度数学、detector 渲染测量、AST/正则对账）不替代人眼。
3. 文字缩放的实际截断行为、36/28 触控档位消费点可点性——静态零命中/待核实，标待验证假设。

## 修复建议

按优先级见分报告「修复建议」节。全部属后续独立任务：本审查零源码改动（`git status` 仅本报告与证据文件，证据目录 test_run 已 gitignore）。

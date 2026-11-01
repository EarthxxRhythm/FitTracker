# FitTracker 视觉审查报告（impeccable · 2026-11）

> 工具：impeccable（npx，官方 detector CLI + audit/critique 方法论）
> 分报告：`test_run\visual-audit\web-audit.md`（官网）· `test_run\visual-audit\app-static\audit.md`（双端 app 静态）
> 证据：`test_run\visual-audit\detector\{web-src,legal,url-desktop,url-mobile}.json` + `url-detail.txt` + `app-static\wcag-contrast.txt` + `test_run\visual-audit\fix-verify\`（修复复扫）

## 状态更新（2026-11-01 修复波：/team 全修已执行）

| 优先级 | 问题 | 状态 |
|---|---|---|
| P1 | 官网 `span.pending` 对比度 2.7:1 | ✅ 已修：根因是 `opacity:.6` 叠加压暗（#7A8D85×60% 合成 #4F5B55，算术复算 2.69:1 与 detector 一致）；改 `color:var(--text-3); opacity:1`，实测 5.44:1（`web\src\legacy.css`） |
| P1 | 移动视口 16 处 9px 肌群字 | ✅ 已修：≤1024px 断点 10→11px；≤720px 断点 9px→`clamp(11px,3vw,12px)`（390 视口 11.7px、320 保底 11px）+ `.muscle-row-k` 10→11px；detector 复扫 url-mobile 28→14，undersized 与 pending 全消失、0 新增 |
| P1 | 产品截图 alt 空 | ✅ 已修：`App.tsx`、`JourneyFilm.tsx` 两处补 `` alt={`${stop.label}界面截图`} `` |
| P1 | 双端无文字缩放处理 | ✅ 已修：鸿蒙 `FontTokens.MAX_SCALE=1.3` + 关键屏 10 处 `.maxFontScale()`（PencilAppShell 4 + ActiveContent 6，逐处注释几何理由）；SDK 实测**无 `maxFontScaleSize`**，实际能力是 `maxFontScale`（API 12）且无应用级开关。安卓 `FtTheme.kt` 加 `LocalMaxFontScale` + `Density(fontScale.coerceAtMost(1.3f))` 主题根夹取。**遗留**：Home/Plan/Review/Profile 屏未覆盖，真机 2.0 字号冒烟未做 |
| P2 | legacy.css 死代码 | ✅ 已修（保守清理）：规则块级对账 + classList 运行时类豁免（PointerFx 5 类）后删除 **100 块**（56KB→34KB）；复合选择器片段与混合块保守保留。detector 复扫 web-src 仅剩 board 2 条（非目标） |
| P2 | 版本号漂移 v1.1.0 | ✅ 已修：`App.tsx` 抽 `PRODUCT_VERSION` 常量，hero-badge 与 footer 两处引用（worker 披露的 footer 残留一并收口） |
| P2 | 法务页 cramped-padding | ✅ 已修：`site.css` .table-wrap 加 12px 14px 内边距，detector 复扫 legal 9→6（cramped-padding 3→0，0 新增） |
| P3 | detector slop 签名登记例外 | ✅ 已修：新增 `.impeccable\config.json`，6 条有意设计登记（bounce-easing/gradient-text/kicker-above-heading/dark-glow/codex-grid-background/radial-spotlight-glow，均带 reason）；`--no-config` 对照复现证明忽略仅来自配置。**遗留**：kicker/dark-glow/radial 三条页面级规则在 URL 扫描中不受 files glob 抑制（finding.file 为 http:// URL） |

## 遗留项（未修，如实保留）

1. **真机大字号冒烟**：双端系统字号 2.0 实拍未做（hdc/adb 当时无设备）；鸿蒙仅覆盖壳层胶囊 + 训练页，其余屏随系统字号放大行为未验证。
2. 双端色板不同源（鸿蒙 #09100F/#16211F/ERROR 红 vs 安卓 #0F0F0F/#171717/warn 浅杏）——归 dual-platform-parity 管辖，修复需用户拍板色阶方向。
3. legacy.css 约 20 个类名仍在「零 JSX 引用」清单但属保守保留（复合片段 + 运行时 classList + 与活类同块），后续如需可二次精修。
4. 根级 `node tools/run-tests.mjs` 未跑（`tools\run-tests.mjs` 有并发会话未提交改动，混跑污染归因）。

## 修复波验证汇总（本轮 /team 执行）

- 官网：`npm run typecheck` ✓、`npm run build` ✓、detector 复扫 web-src 2 条（全 board 非目标）✓、url-mobile 28→14 ✓、legal 9→6 ✓
- 鸿蒙：`check-gates.mjs` 完整门禁 11 项全绿含 `devecocli 1.3.4` ArkTS 编译 ✓
- 安卓：`./gradlew :app:compileDebugKotlin` BUILD SUCCESSFUL ✓
- 双端 parity 门禁在 check-gates 内 passed ✓

## 审查结论摘要（原始，未修复时的基线）

无 P0。官网 audit 12/20 分，双端静态审计 18/19 色对达标。修复前详情见 `test_run\visual-audit\web-audit.md` 与 `app-static\audit.md`（历史基线，保留不覆盖）。

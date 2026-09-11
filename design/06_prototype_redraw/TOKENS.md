# FitTracker 界面重建 · 令牌审计（TOKENS）

> 对照：`design/06_prototype_redraw/src/*.html` `:root` 与 
> `entry/src/main/ets/common/styles/DesignTokens.ets`（运行时解析，非人工抄写）。
> 审计基于冻结基线；基线更新后重跑：
> `python design/06_prototype_redraw/scripts/audit_tokens.py`

## 1. 跨屏 CSS 变量一致性

| CSS 变量 | 规范值（多数屏） | 偏离屏（值） |
|---|---|---|
| `--accent` | `#50ECA7` | — |
| `--accent-07` | `rgba(80,236,167,.07)` | — |
| `--accent-10` | `rgba(80,236,167,.10)` | — |
| `--accent-12` | `rgba(80,236,167,.12)` | — |
| `--accent-17` | `rgba(80,236,167,.17)` | — |
| `--accent-18` | `rgba(69,201,161,.18)` | — |
| `--accent-20` | `rgba(80,236,167,.20)` | — |
| `--accent-32` | `rgba(69,201,161,.32)` | — |
| `--accent-40` | `rgba(80,236,167,.40)` | — |
| `--accent-deep` | `#45C9A1` | — |
| `--accent-soft` | `#8CEBCC` | — |
| `--active-scale` | `0.90698` | — |
| `--complete-bg` | `#07100F` | — |
| `--complete-check` | `#7EF0CB` | — |
| `--complete-circle` | `#122D28` | — |
| `--complete-circle-border` | `rgba(80,236,167,.23)` | — |
| `--complete-sub` | `rgba(255,255,255,.72)` | — |
| `--cta-a` | `#47D994` | — |
| `--cta-b` | `#53E7A5` | — |
| `--cta-hover-a` | `#5BE3A5` | — |
| `--cta-hover-b` | `#6BEDB5` | — |
| `--ease` | `cubic-bezier(.2, .7, .2, 1)` | — |
| `--font-cn` | `"Noto Sans SC", "HarmonyOS Sans SC", "PingFang SC", "Microsoft YaHei", "Microsoft YaHei UI", sans-serif` | — |
| `--font-mono` | `"Geist Mono", "JetBrains Mono", "SF Mono", Consolas, "Courier New", monospace` | — |
| `--font-num` | `"Inter", "SF Pro Text", -apple-system, "Segoe UI", "Microsoft YaHei", sans-serif` | — |
| `--glass-10` | `rgba(255,255,255,.10)` | — |
| `--glass-4` | `rgba(255,255,255,.04)` | — |
| `--glass-6` | `rgba(255,255,255,.06)` | — |
| `--glass-8` | `rgba(255,255,255,.08)` | — |
| `--gold` | `#D3B487` | — |
| `--gold-12` | `rgba(211,180,135,.12)` | — |
| `--hairline` | `rgba(255,255,255,.06)` | — |
| `--ink-0` | `#0B0F13` | — |
| `--ink-1` | `#0A0D12` | — |
| `--ink-welcome-0` | `#10171B` | — |
| `--line-10` | `rgba(255,255,255,.10)` | — |
| `--line-14` | `rgba(255,255,255,.078)` | — |
| `--line-16` | `rgba(255,255,255,.16)` | — |
| `--nav-active` | `#F3FBF7` | — |
| `--nav-inactive` | `rgba(243,251,247,.56)` | — |
| `--on-accent` | `#07100B` | — |
| `--on-accent-2` | `#08110D` | — |
| `--ring-inner` | `#0D1117` | — |
| `--scale` | `0.90698` | — |
| `--stat-bg` | `#14181E` | — |
| `--streak-bg` | `#171C23` | — |
| `--streak-day-off` | `rgba(255,255,255,.078)` | — |
| `--streak-day-on` | `#50ECA7` | — |
| `--streak-surface` | `#171C23` | — |
| `--surface-stat` | `#171D24` | — |
| `--tab-pill` | `#141F1D` | — |
| `--tab-pill-active` | `#182422` | — |
| `--txt-body` | `#EDF6F2` | — |
| `--txt-hi` | `#F7FBF8` | — |
| `--visual-a` | `#14241F` | — |
| `--visual-b` | `#0D1616` | — |
| `--warn` | `#FFD7C5` | — |
| `--warn-border` | `rgba(255,176,150,.55)` | — |
| `--white-32` | `rgba(255,255,255,.32)` | — |
| `--white-40` | `rgba(255,255,255,.40)` | — |
| `--white-48` | `rgba(255,255,255,.478)` | — |
| `--white-54` | `rgba(255,255,255,.54)` | — |
| `--white-56` | `rgba(255,255,255,.561)` | — |
| `--white-60` | `rgba(255,255,255,.60)` | — |
| `--white-62` | `rgba(255,255,255,.62)` | — |
| `--white-65` | `rgba(255,255,255,.65)` | — |
| `--white-70` | `rgba(255,255,255,.70)` | — |
| `--white-87` | `rgba(255,255,255,.87)` | — |
| `--white-90` | `rgba(243,251,247,.90)` | — |

## 2. 色值语义映射（HTML -> 现有 DesignTokens）

| CSS 变量（规范值） | 现有令牌建议 |
|---|---|
| `--accent` `#50ECA7` | ColorTokens.ACCENT_PRIMARY (#50ECA7) |
| `--accent-deep` `#45C9A1` | ColorTokens.ACCENT_DEEP (#45C9A1) |
| `--accent-soft` `#8CEBCC` | ColorTokens.ACCENT_SOFT (#8CEBCC) |
| `--cta-a` `#47D994` | ColorTokens.ACCENT_PRIMARY 系（渐变起点 #47D994） |
| `--cta-b` `#53E7A5` | ColorTokens.ACCENT_HOVER (#53E7A5) |
| `--hairline` `rgba(255,255,255,.06)` | ColorTokens.BORDER_HAIRLINE / DIVIDER |
| `--nav-active` `#F3FBF7` | ColorTokens.NAV_ACTIVE 语境（文本/激活） |
| `--on-accent` `#07100B` | ColorTokens.TEXT_ON_PRIMARY (#09100F) -> html #07100B 微差 |
| `--txt-body` `#EDF6F2` | ColorTokens.TEXT_PRIMARY (#EDF6F2) |
| `--txt-hi` `#F7FBF8` | ColorTokens.TEXT_ON_DARK (#F3FBF7) / html #F7FBF8 接近 |
| `--white-70` `rgba(255,255,255,.70)` | ColorTokens.TEXT_ON_DARK_SECONDARY 类 alpha |

## 3. 还原时须新增/对齐的令牌（GAP，颜色）

> 仅列高频且与现有令牌语义对应的候选；页面专用值就地写，不强行入 token。

- `--ink-0`（规范值 #0B0F13）-> 页面背景主色（现 BG_PRIMARY='#09100F'）。还原屏时若色差 > 1 L* 需新增语义成员，否则页面级直写。
- `--ink-1`（规范值 #0A0D12）-> 页面背景次级（现 BG_SECONDARY='#0F1716'）。还原屏时若色差 > 1 L* 需新增语义成员，否则页面级直写。
- `--surface`（规范值 ?）-> 卡片面（现 SURFACE_PRIMARY='#16211F'）。还原屏时若色差 > 1 L* 需新增语义成员，否则页面级直写。
- `--bg`（规范值 ?）-> 最外层背景（现 APP_BG_HOME='#0A1110'）。还原屏时若色差 > 1 L* 需新增语义成员，否则页面级直写。
- `--accent-12/20/32/40`（规范值 rgba(80,236,167,.12)）-> 强调 alpha 蒙层/描边（现 OVERLAY_PRIMARY / BORDER_ACCENT）。还原屏时若色差 > 1 L* 需新增语义成员，否则页面级直写。

## 4. MotionTokens 覆盖审计（HTML 动效值 -> 令牌）

### 4.1 跨屏出现的时长 / 曲线

- 时长（.Ns）: 1, 2, 3, 05, 5, 6, 06, 12, 14, 16, 18, 22, 26, 28, 35, 36, 45, 46
- 曲线 cubic-bezier: .16, .7, .3, 1, .2, .55, .35, 1, .2, .7, .2, 1, .32, .72, .3, 1, .32, .72, 0, 1, .32,.72,.3,1

### 4.2 现有 MotionTokens 成员

| 成员 | 值 | 对应 HTML 值 |
|---|---|---|
| `DURATION_PRESS` | 120 | .12s 按压 (120) |
| `DURATION_COLOR_FAST` | 160 | .16s 色/边框 (160) |
| `DURATION_COLOR_BASE` | 180 | .18s 色 (180) |
| `DURATION_OVERLAY` | 220 | .22s backdrop/modal/veil (220) |
| `DURATION_PANEL` | 280 | .28s~.3s sheet (280) |
| `DURATION_RECORD` | 180 | recordIn .18s (180) |
| `DURATION_MARKER` | 300 | markerPop .3s (300) |
| `DURATION_CORE` | 460 | coreIn .46s (460) |
| `DURATION_SEG_POP` | 460 | segPop .46s (460) |
| `DURATION_CONFETTI_FLY` | 1100 | confettiFly 1.1s (1100) |
| `DURATION_CONFETTI_FALL` | 2600 | cf-fall 2.6s (2600) |
| `DURATION_PULSE` | 1600 | livePulse 1.6s (1600) |
| `DURATION_CF_POP` | 500 | cf-pop .5s (500) |
| `DURATION_CF_RISE_FAST` | 450 | cf-rise .45s (450) |
| `DURATION_CF_RISE_BASE` | 500 | cf-rise .5s (500) |
| `EASE_MOTION` | curves.cubicBezierCurve(0.2, 0.7, 0.2, 1) | --ease 默认 (bezier(0.2,0.7,0.2,1)) |
| `EASE_PANEL` | curves.cubicBezierCurve(0.32, 0.72, 0.3, 1) | sheet/面板 (bezier(0.32,0.72,0.3,1)) |
| `EASE_FLY` | curves.cubicBezierCurve(0.16, 0.7, 0.3, 1) | confettiFly (bezier(0.16,0.7,0.3,1)) |
| `EASE_FALL` | curves.cubicBezierCurve(0.2, 0.55, 0.35, 1) | cf-fall (bezier(0.2,0.55,0.35,1)) |

**结论**：MotionTokens 已覆盖训练执行/完成全部关键帧与通用转场；新增屏如 body-data `.goal-fill width .35s` 建议补 `DURATION_PROGRESS=350`，sheet `.3s` 与 `DURATION_PANEL=280` 差异在观感容差内沿用 PANEL。

## 5. 校准建议汇总

1. 页面还原一律引用上述映射后的令牌成员，不写魔法值。
2. 色系以 #0B0F13/#50ECA7/#EDF6F2 为规范；现 ColorTokens 的 ACCENT/TEXT 族已一致，
   BG/SURFACE 旧值与 HTML 微差：还原屏时优先页面级直写或新增语义成员，不做全局覆盖。
3. MotionTokens 建议补 `DURATION_PROGRESS=350`（进度条 fill）。

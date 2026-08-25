# 原型动效 1:1 还原流程（FitTracker / Open Design）

> 目标：把 Open Design 原型（`fittracker-*.html` / `index.html`）里的 CSS 动效（按压反馈、关键帧、转场）在 HarmonyOS ArkUI 页面做到「观感一致」。本文是可复用流程，也附「给 agent 的任务模板」。

## 0. 口径与前置

- 「观感一致」= 原型与设备同状态截图并排/热力图肉眼一致，落定态与按压态数值接近；不强制逐条 CSS 曲线值相等（值相等是映射手段，不是验收终点）。
- 前置：原型 HTML 目录、ArkUI 工程、Chrome、`hdc` 与在线设备/模拟器、Python（`lxml/PIL/numpy`）。
- 动画是时间序列，静态截图只能验证「落定态」和「可停留的中间态」；120ms 级按压反馈与 200ms 级转场在无录屏能力时无法逐帧静态捕获（见 §7 限制）。

## 1. 提取动效规格

对每个原型 HTML 用 `rg` 抽取动画声明，整理成「元素 → 属性 → 时长/缓动/关键帧% → 触发条件」表：

```text
rg -n "@keyframes|transition:|animation:|:active|cubic-bezier" <原型目录>/fittracker-*.html
```

重点字段：

- `transition:` 与 `:active { transform: scale(...) }` → 按压/颜色过渡。
- `@keyframes <name>` 与 `animation: <name> <dur> <curve> [<delay>]` → 入场/关键帧。
- `cubic-bezier(a,b,c,d)` → 缓动曲线。

## 2. 映射到 ArkUI

| 原型 CSS | ArkUI |
|---|---|
| `cubic-bezier(a,b,c,d)` | `curves.cubicBezierCurve(a,b,c,d)`（类型 `ICurve`） |
| 时长 / delay（ms） | 原值直填 |
| `transform: scale(.985)`（`:active`） | `@State pressed` + `onTouch(Down/Up/Cancel)` + `.scale(...)` + `.animation({duration:120, curve:...})` |
| `transform: translateX/Y`、`opacity` | `.translate({x,y})` / `.opacity(...)` |
| 单段 `transition` | `animateTo({duration, curve, delay}, ...)` |
| 多关键帧 `@keyframes` | `keyframeAnimateTo({delay}, [{duration,curve,event}, ...])` |
| 背景/边框/颜色过渡 | `.animation({duration:160|180, curve: Curve.EaseInOut})` |

按压反馈规范模式（每个可交互元素独立 `@State`，避免互相联动）：

```typescript
.onTouch((event: TouchEvent) => {
  if (event.type === TouchType.Down) { this.ctaPressed = true }
  else if (event.type === TouchType.Up || event.type === TouchType.Cancel) { this.ctaPressed = false }
})
.scale({ x: this.ctaPressed ? MotionTokens.PRESS_PRIMARY : 1, y: this.ctaPressed ? MotionTokens.PRESS_PRIMARY : 1 })
.animation({ duration: MotionTokens.DURATION_PRESS, curve: MotionTokens.EASE_MOTION })
```

## 3. 共享 MotionTokens

在 `common/styles/DesignTokens.ets` 的 `MotionTokens` 集中管理：缓动 `EASE_MOTION/PANEL/FLY/FALL`（`ICurve`）、时长常量（按压 120、颜色 160/180、弹层 220、面板 280、入场 180、marker 300、core 460/延迟60、segPop 460、confetti fly 1100/fall 2600、pulse 1600、cf-pop 500/延迟50、cf-rise 450/500）、按压缩放系数（主按钮 .985、chip .97、图标 .96、快捷 .98、分段 .97、tab pill .96、返回 .94）。页面只引用，不散落魔法值。

## 4. 构建验证

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
. .\tools\deveco-env.ps1
hvigorw.bat assembleHap --mode module -p product=default
node tools/check-gates.mjs
```

要求 `BUILD SUCCESSFUL` 且 gates 通过。此时只证明「能编译」，不等于「观感 1:1」。

## 5. 原型参照帧（Chrome）

落定态：

```powershell
python tools/render-prototype-phone.py   # -> test_run/prototype-phone/<page>.png
```

中段/按压态（注入脚本暂停动画到 50% + 强制主按钮 `.985`）：

```powershell
python tools/capture-prototype-motion.py  # -> test_run/prototype-motion/<page>-{mid,pressed}.png
```

## 6. 设备帧（hdc）

先装最新 HAP 并启动：

```powershell
hdc install entry/build/default/outputs/default/entry-default-unsigned.hap
hdc shell aa start -a EntryAbility -b com.example.fittracker_opencode
```

拿控件坐标（无障碍树，可读文本）：

```powershell
hdc shell uitest dumpLayout -p /data/local/tmp/ui.json
hdc file recv /data/local/tmp/ui.json work/ui.json
python work/parse_ui.py work/ui.json
```

截图 + 点击（坐标是设备原生像素）：

```powershell
hdc shell uitest uiInput click <x> <y>
hdc shell snapshot_display -f /data/local/tmp/<name>.jpeg
hdc file recv /data/local/tmp/<name>.jpeg test_run/device-motion/<name>.jpeg
```

封装：`tools/capture-device-motion.ps1 -Name <name> -Action settled`（`-Action press/mid` 时加 `-TapX -TapY -DelayMs`）。

## 7. 对比与修复

```powershell
python tools/compare-motion-frames.py   # -> test_run/motion-diff/report.md + <page>-<state>.png 并排/热力图
```

报告给出每页每状态的 MAE（0~255，越小越接近）与 `diff` 热力图路径。修复循环：

1. 打开并排图 + 热力图，肉眼定位差异区域。
2. 只改 ArkUI 的时长/缓动/关键帧%/缩放系数；不动布局尺寸、颜色、文案。
3. 重新构建 → 重装 → 重截 → 重跑 diff，直到 MAE 不再显著下降、并排肉眼一致。

## 8. 给 agent 的任务模板

```text
任务：把 <原型 html> 的动效 1:1 落到 <ArkUI 页面文件>，只改 owner_files。
1) 读 docs/motion-restore-workflow.md（只读）。
2) rg 提取原型 @keyframes/transition/:active/cubic-bezier，列出规格表。
3) 按 §2 映射到 ArkUI；时长/缓动/缩放统一用 MotionTokens。
4) 构建：hvigorw assembleHap --mode module -p product=default，要求 BUILD SUCCESSFUL。
5) 用 §5/§6/§7 产出参照帧 + 设备帧 + MAE diff，写 outbox（changed_files + evidence + 缺口）。
约束：ArkTS strict（不用 any/unknown/as const/解构/for..in/嵌套函数）；只改 owner_files；不回退未提交布局改动。
```

并行分派按「文件归属」拆互不重叠子任务（≤4 并发），共享 `cluster/inbox` 文件信箱协议；超时未产出由协调者接管。

## 9. 已知限制

- 按压反馈（120ms）与屏间转场（200ms 级）在无 `screenrecord` 的模拟器上无法用静态截图逐帧捕获，只能靠真机实时目测或录屏。
- `prefers-reduced-motion` 无 ArkUI 直接等价，v1 跳过。
- hover 态在触屏无意义，不实现。
- 登录/完成等受会话或长流程约束的页面，先清会话或走完整流程才能截到；否则以「missing device」标注。

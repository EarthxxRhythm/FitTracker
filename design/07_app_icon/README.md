# FitTracker · App 图标（07_app_icon）

> 2026-10-03 定稿并落地。方向：**进度环 PURE**（用户从 6 个探索方向中选定 01，再从 4 个精修变体中选定 A）。
> 决策轨迹：`icon-explore-v1.html`（6 方向探索）→ `icon-ring-refine.html`（A/B/C/D 精修 + 底对比）→ 选定 A + 微光晕底。

## 设计定稿

**符号：进度环 · PURE**
- 270° 弧（缺口 90° 朝上），半径 `r=12`（48 视框口径）
- 线宽 `4.6`，圆头端点（stroke-linecap: round）
- 里程碑点 `r=2.8`，悬于缺口中央 12 点位
- 主色 `#50ECA7`（翡翠），对墨黑底对比 `12.73:1`（WCAG AAA）

**画布与占比**
- HarmonyOS 分层图标 `1024×1024`（background 满幅 + foreground 透明底）
- 符号内容占画布 `50%`（y 向实测 50.1%）
  - 校准依据：官方新模板 foreground 内容实测 44.8%、旧模板 67.4%——取中间值，兼顾合规与桌面存在感
- foreground 缩放参数（48 视框内）：`translate(24,24) scale(0.82474) translate(-24,-24)`
  （scale = 24 / 29.1，29.1 为符号内容 y 向跨度 9.2..38.3）

**底（background）**
- 微光晕：radial，中心 `(50%, 42%)`，`#0E1613 → #0B0F13`（78% 处到达外缘色）
- 实测：中心 `rgb(13,21,19)` vs 边缘 `rgb(11,15,19)`——极淡、零脏感

## 资产落位（5 个 PNG）

| 文件 | 落位 | 说明 |
|---|---|---|
| `background.png` | `AppScope/resources/base/media/` + `entry/src/main/resources/base/media/` | 1024×1024 微光晕底 |
| `foreground.png` | 同上两处 | 1024×1024 透明底符号 |
| `startIcon.png` | `entry/src/main/resources/base/media/` | 144×144 启动图标（bg+fg 合成） |

`layered_image.json` / `app.json5`（`$media:layered_image`）/ `module.json5`（`$media:layered_image`、`$media:startIcon`）引用不变，仅替换内容。

## 生成管线（可复现）

1. **母版 SVG 源**：`master_bg.html`（底）/ `master_fg.html`（符号），48 视框口径
2. **渲染**：Chrome headless `--screenshot --window-size=1024,1024 --force-device-scale-factor=1`
   （foreground 需加 `--default-background-color=00000000` 出透明底）
3. **合成**：PIL——`startIcon = background + foreground` 缩至 144 用 LANCZOS 合成
4. **验证**：PIL 像素断言（弧 8 方位 / 缺口 / 点位置 / 内容占比）→ 构建 → 安装 → 模拟器实拍

**改版方法**：改 `master_fg.html` 的 scale（占比）或路径参数 → 重跑上述管线 → 替换 resources 中的 PNG。

## 验证记录（2026-10-03）

| 环节 | 结果 |
|---|---|
| PIL 像素断言 | 弧 @3pm/6pm/9pm/25°/315° 全翡翠；缺口 @240° 透明；点位置正确；内容 y 占比 50.1% — **ALL PASS** |
| 构建 | `devecocli build --build-mode debug` → **BUILD SUCCESSFUL**（含 SignHap） |
| 安装 | `hdc install entry-default-signed.hap` → **install bundle successfully** |
| 实机显示 | Mate X7 模拟器（HarmonyOS 6.1.1 / API 24）桌面图标显示正确，见 `desktop-evidence.png` |

## 目录内容

- `master/` — 母版 PNG（`master_bg.png` / `master_fg.png` / `master_startIcon.png`），再生成与改版的源
- `master_bg.html` / `master_fg.html` — 生成源（底与符号的 SVG 定义，改版从此处调参）
- `icon-explore-v1.html` — 第一轮 6 方向探索页（环/哑铃/柱/脉冲/F/山）
- `icon-ring-refine.html` — 第二轮 A/B/C/D 精修对比页（含底处理对比）
- `master-preview.html` — 定稿预览页（成品 / 三档占比对比 / 桌面模拟）
- `desktop-evidence.png` — 模拟器桌面实拍（最终验证证据）

## 遗留（可选调整）

- 占比 50% 为推荐值：若实机观感需要更保守/更饱满，改 scale 重生成（45% → `0.74227`，55% → `0.90722`），单次调整约一分钟
- 底可从微光晕回退到纯平底 `#0B0F13`（改 `master_bg.html` 一处）
- 深色系统主题下图标表现良好（本身即暗色设计）；如未来需要浅色主题专用变体，可基于同一符号另出亮底版

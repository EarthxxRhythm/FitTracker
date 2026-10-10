# 菲特 · App 图标（07_app_icon）

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

## 应用市场提交素材（可复现）

市场规范：正方形；`216×216` 或 `1024×1024`；PNG ≤ 3 MB / WEBP ≤ 100 KB；须与软件包内应用图标一致。

| 文件 | 尺寸 | 大小 |
|---|---|---|
| `market/icon-1024.png` | 1024×1024 | 104,421 B |
| `market/icon-216.png` | 216×216 | 17,620 B |
| `market/icon-1024.webp` | 1024×1024 | 11,816 B |
| `market/icon-216.webp` | 216×216 | 2,400 B |

- **生成**：`python design/07_app_icon/make_market_icon.py` —— 读 `AppScope/resources/base/media/` 的 background + foreground 做 alpha 合成，再缩放导出；脚本内含正方形/尺寸/文件大小断言，任一不达标则非零退出。
- **口径**：满幅不透明方图（RGB 无 alpha），**不预切圆角**——圆角由平台统一处理；预切圆角会在平台二次裁切后留下透明角。
- **一致性（与包内图标）**：提交图与 `alpha_composite(bg, fg)` 逐像素相同（`ImageChops.difference(...).getbbox()` 为 `None`），源头就是包内那两份 PNG。
- **一致性（与设备渲染）**：符号占比实测对齐——设备实拍（`desktop-evidence.png`，图标方块 163×163）量得环 bbox 占比 48.5% / 49.7%，提交图 49.0% / 49.9%，差 ≤ 0.6 pp。

## UI 版符号（应用内品牌标识）

应用内三处品牌标识（欢迎 / 登录 / 注册页）与应用图标**同符号**，但不是同一份文件、也**不该直接缩放图标几何**：

| | 图标版（`master_fg.html`） | UI 版（`entry/src/main/resources/rawfile/fittracker-logo-ring.svg`） |
|---|---|---|
| 视框 | 48 | 24 |
| 弧半径 | 12 | 9.231 |
| 线宽 | 4.6 | 3.538 |
| 里程碑点 r | 2.8 | 2.154 |
| 符号占画布 | 50%（桌面图标安全区口径） | 92% |

- **换算依据**：直接缩图标几何的话，48 视框的线宽 4.6 在 18px 下只剩 1.7px（发糊）。UI 版按「外径占视框 92%」反推线宽与点半径，保持点/线比 1.217。
- **实测**（Chrome headless 渲染 + PIL 断言）：18px → 外径 16px、线宽 3px、点宽 4px（点/线 1.33，点可辨）；26px → 外径 24px、线宽 4px。两档的角度分箱均为 −30°..30° 无像素，即缺口朝上 ✔
- **引用点**：`PencilWelcomePage.ets:40`（18px 符号 / 34px 容器）、`PencilLoginPage.ets:183` 与 `PencilRegisterPage.ets:175`（26px 符号 / 48px 容器）。
- 旧符号 `fittracker-logo-pulse.svg`（F + 心跳）保留未删，已无引用。

## 验证记录（2026-10-03）

| 环节 | 结果 |
|---|---|
| PIL 像素断言 | 弧 @3pm/6pm/9pm/25°/315° 全翡翠；缺口 @240° 透明；点位置正确；内容 y 占比 50.1% — **ALL PASS** |
| 构建 | `devecocli build --build-mode debug` → **BUILD SUCCESSFUL**（含 SignHap） |
| 安装 | `hdc install entry-default-signed.hap` → **install bundle successfully** |
| 实机显示 | Mate X7 模拟器（HarmonyOS 6.1.1 / API 24）桌面图标显示正确，见 `desktop-evidence.png` |

## 目录内容

- `master/` — 母版 PNG（`master_bg.png` / `master_fg.png` / `master_startIcon.png`），再生成与改版的源
- `make_market_icon.py` — 应用市场提交素材生成脚本（合成 + 正方形/尺寸/大小断言）
- `market/` — 应用市场提交素材产出（1024 / 216 的 PNG + WEBP，共 4 个文件）
- `master_bg.html` / `master_fg.html` — 生成源（底与符号的 SVG 定义，改版从此处调参）
- `icon-explore-v1.html` — 第一轮 6 方向探索页（环/哑铃/柱/脉冲/F/山）
- `icon-ring-refine.html` — 第二轮 A/B/C/D 精修对比页（含底处理对比）
- `master-preview.html` — 定稿预览页（成品 / 三档占比对比 / 桌面模拟）
- `desktop-evidence.png` — 模拟器桌面实拍（最终验证证据）

## 遗留（可选调整）

- 占比 50% 为推荐值：若实机观感需要更保守/更饱满，改 scale 重生成（45% → `0.74227`，55% → `0.90722`），单次调整约一分钟
- 底可从微光晕回退到纯平底 `#0B0F13`（改 `master_bg.html` 一处）
- 深色系统主题下图标表现良好（本身即暗色设计）；如未来需要浅色主题专用变体，可基于同一符号另出亮底版

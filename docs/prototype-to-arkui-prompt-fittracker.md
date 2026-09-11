# FitTracker 迁移提示词项目附录

> 配合 `docs\prototype-to-arkui-prompt-template.md` 使用。
> 本文件只写 FitTracker 专属内容：规格源实际路径、屏清单、可执行命令、已踩过的坑。

## 1. 八项规格源的实际落点

对应模板「方括号填写清单」的八项：

| 模板占位 | FitTracker 实际路径 | 内容 |
|---|---|---|
| `[原型 HTML 冻结目录]` | `design\06_prototype_redraw\src\` | 13 个屏文件 + `fittracker-webapp.html` 预览壳 + `assets\`（GIF／SVG／脚本），**只读基线** |
| `[动效声明表文件]` | `design\06_prototype_redraw\MOTION.md` | 逐屏 `transition` / `:active` / `@keyframes` 声明表，由 `scripts\extract_specs.py` 生成 |
| `[设计令牌文档]` | `design\06_prototype_redraw\TOKENS.md` | 逐屏 `:root` 令牌 + 与代码令牌的对照 |
| `[代码中的令牌文件]` | `entry\src\main\ets\common\styles\DesignTokens.ets` | `ColorTokens` / `FontTokens` / `SpacingTokens` / `RadiusTokens` / `ShadowTokens` / `MotionTokens` / `TouchTokens` |
| `[产品愿景 / 视觉方向文档]` | `design\01_brief\product_vision.md`、`design\01_brief\visual_direction.md` | 产品定位与视觉方向 |
| `[色彩 / 字体 / 图表规格]` | `design\03_design_system\colors.md`、`typography.md`、`charts.md` | 六类色彩 token 与强调色硬规则；字体层级模型与数字强调；图表规范 |
| `[按钮 / 卡片 / 输入 / 页头 / 标签规格]` | `design\04_component_specs\buttons.md`、`cards.md`、`inputs.md`、`page_headers.md`、`tags.md` | 三级按钮；卡片分层；输入四态；页头高度纪律；标签 |
| `[逐页规格文档目录]` | `design\05_page_specs\` | `home.md`、`active_workout.md`、`review_home.md`、`workout_preview.md`、`workout_summary.md`、`exercise_detail.md` |
| `[视觉验收口径文档]` | `design\06_prototype_redraw\ACCEPTANCE-PLAN.md` | 裁剪区间、文本掩码、≤8% 达标线 |
| `[UX 验收清单]` | `docs\ui-acceptance-checklist.md` | Section A 视觉一致性 / B 流程清晰度 / C 交互打磨 / D 产品调性 |
| `[原型预览壳的 ROUTES 表]` | `design\06_prototype_redraw\src\fittracker-webapp.html` | 15 路由 → 屏文件 + frame 的映射，见下方 §2 |

**本项目暂无**：无（八项齐备）。

## 2. 屏清单：ROUTES 表与 ArkUI 落点

`fittracker-webapp.html` 的 `ROUTE_ORDER` 顺序如下（分片与验收以本表为准）：

| # | route | 屏文件（`src\` 下） | frame | ArkUI 落点 |
|---|---|---|---|---|
| 1 | `welcome` | `fittracker-welcome-home.html` | `screen-welcome` | `features\welcome\pages\PencilWelcomePage.ets` |
| 2 | `home` | `fittracker-welcome-home.html` | `screen-home` | `features\pencil\pages\PencilHomePage.ets` + `features\pencil\components\HomeContent.ets` |
| 3 | `login` | `fittracker-auth.html` | `screen-login` | `features\pencil\pages\PencilLoginPage.ets` |
| 4 | `register` | `fittracker-auth.html` | `screen-register` | `features\pencil\pages\PencilRegisterPage.ets` |
| 5 | `plan` | `fittracker-plan.html` | `screen-plan` | `features\pencil\pages\PencilPlanPage.ets` + `features\pencil\components\PlanContent.ets` |
| 6 | `workout` | `fittracker-training-preview.html` | `screen-training-preview` | `features\pencil\pages\PencilPreviewPage.ets` |
| 7 | `plans` | `fittracker-plan-detail.html` | `screen-plan-detail` | `features\pencil\pages\PencilPlansPage.ets` + `features\pencil\components\PlansContent.ets` |
| 8 | `planGroup` | `fittracker-plan-group-detail.html` | `screen-plan-group-detail` | `features\pencil\pages\PencilPlanGroupDetailPage.ets` + `features\pencil\components\PlanGroupDetailContent.ets` |
| 9 | `active` | `fittracker-training.html` | `screen-training` | `features\pencil\pages\PencilActivePage.ets` + `features\pencil\components\ActiveContent.ets` |
| 10 | `complete` | `fittracker-training-complete.html` | `screen-training-complete` | `features\workout\pages\WorkoutCompletePage.ets` |
| 11 | `review` | `fittracker-review.html` | `screen-review` | `features\pencil\pages\PencilReviewPage.ets` + `features\pencil\components\ReviewContent.ets` |
| 12 | `library` | `fittracker-exercise-library.html` | `screen-exercise-library` | `features\exercise\pages\ExerciseLibraryPage.ets` |
| 13 | `body` | `fittracker-body-data.html` | `screen-body-data` | `features\body\pages\BodyDataPage.ets` + `features\body\components\BodyDataContent.ets` |
| 14 | `profile` | `fittracker-personal.html` | `screen-personal` | `features\pencil\pages\PencilProfilePage.ets` + `features\pencil\components\ProfileContent.ets` |
| 15 | `settings` | `fittracker-settings.html` | `screen-settings` | `features\settings\pages\PencilSettingsPage.ets` + `features\settings\components\SettingsContent.ets` |

**共享层（分片前先冻结，不并入任何分片）**：

- `entry\src\main\ets\common\styles\DesignTokens.ets`（`MotionTokens` 被 21 个文件引用）
- `entry\src\main\ets\app\AppRoutes.ets`（≥11 个文件引用）
- `entry\src\main\ets\app\PencilAppShell.ets`（装配 4 个 Tab 内容体）
- `entry\src\main\ets\components\` 下的 `AppButton.ets` / `AppCard.ets` / `BottomTabBar.ets` / `PageHeader.ets` / `StageRail.ets`

**页面清单的权威来源**：`entry\src\main\resources\base\profile\main_pages.json`（20 页注册）与
`entry\src\main\ets\app\AppRoutes.ets`（路由常量）。新增页面必须同时满足「文件存在 + 注册进
`main_pages.json` + 有路由常量」。

## 3. 可执行命令

### 构建与门禁

```powershell
devecocli build                                  # 期望 BUILD SUCCESSFUL
node tools\check-main-pages.mjs                  # 页面注册校验
node tools\check-gates.mjs                       # 内容/页面/风格/死引用/ArkTS 编译门禁
```

### 结构验收

```powershell
# 参照帧（frame 序号从 0 开始）
python tools\visual-diff\render-prototype.py design\06_prototype_redraw\src\fittracker-auth.html test_run\ref.png --screen 0

# 单屏封装（装 HAP → 冷启动 → 截图 → 对比）
powershell -ExecutionPolicy Bypass -File tools\restore-accept.ps1 `
  -Html design\06_prototype_redraw\src\fittracker-training.html -FrameIndex 0 -Name active -Crop 100,740

# 裸对比（参照帧 vs 设备帧）
python tools\visual-diff\compare.py test_run\ref.png test_run\shot.jpeg --out test_run\report.md `
  --crop 100,740 --ignore-rect 73,182,368,206
```

### 设备导航（`restore-accept.ps1` 到不了的屏必须手动走这一步）

```powershell
hdc shell uitest dumpLayout -p /data/local/tmp/ui.json     # 取当前屏的 a11y 树
hdc file recv /data/local/tmp/ui.json test_run\ui.json     # 拉回本地
hdc shell uitest uiInput click <x> <y>                     # 坐标取自 dump 的 bounds（设备像素）
hdc shell snapshot_display -f /data/local/tmp/shot.jpeg    # 截图
hdc file recv /data/local/tmp/shot.jpeg test_run\shot.jpeg
```

### 动效验收

```powershell
python tools\capture-prototype-motion.py                                            # 原型落定态 + 按压/中间态
powershell -File tools\capture-device-motion.ps1 -Name active -Action press -TapX 660 -TapY 1611 -DelayMs 60
python tools\compare-motion-frames.py                                               # 每页每状态 MAE + 并排图 + 热力图
```

## 4. 本项目已踩过的坑（照抄，不要重踩）

### 4.1 画布基准与文档冲突——**信源码**

`README.md` 与 `docs\opendesign-1to1-rules.md` 硬规则 2 都写「除 welcome 外其余 14 屏 390×844 直绘」，
但实测不一致：

- `design\06_prototype_redraw\src\fittracker-auth.html:62` 定义 `--active-scale: 0.90698`，
  `:176-181` 的 `.auth-frame` 是 `width:430px; height:900px; transform:scale(...)` → **login/register 是缩放画布**。
- `fittracker-welcome-home.html` 的 `.w-frame` 同为 430×900 缩放。

**后果**：ArkUI 用了原型的 430 空间原始值却漏掉缩放容器，导致整体偏大约 10%。login/register 是
15 屏里偏差最大的两屏（10.02% / 12.28%）。

**修法**：包一层 `430×900` 容器 + `.scale({ x: 0.90698, y: 0.90698, centerX: 0, centerY: 0 })`，
外层 `.clip(true)`，容器内保持原型原始值。补容器后设备 a11y bounds ÷3.3846 得 FITTRACKER 落位
130.3–144.5vp，与原型计算 131.5–144.5vp 吻合。

**待核查**：`PencilWelcomePage.ets` 同属缩放屏，是否也有同样缺失，尚未逐行核实。

### 4.2 `restore-accept.ps1` 无法到达 auth 与流程屏

`tools\restore-accept.ps1` 的流程是 `force-stop → aa start --ps devSeed → Sleep 9 → snapshot_display`，
**全程没有点击注入**。实测 `bm clean` 后冷启动落在 Welcome 屏（屏上文本为 `FITTRACKER` /
`把训练，变成看得见的进步。` / `开始使用` / `本地记录 · 无需注册 · 随时开始`），而 login 需要点
`PencilWelcomePage.ets:303-305` 的按钮才可达。

**后果**：`test_run\emulator\ACCEPTANCE-2026-09-11.md` 里 login/register 的数字口径存疑
（截的可能一直是 Welcome 屏）。

**修法**：按 §3 的设备导航三步走，逐跳 `click` + 每跳后 `dumpLayout` 核对屏上文本。

### 4.3 数字逐位相同 ≠ 改动无效

实测两次跑的 `MAE=30.48 / 超阈 22.93%` 逐位相同。原因不是改动无效，而是**两次截的都是 Welcome 屏**——
目标屏根本没被截到。**先怀疑测错屏，再怀疑改动无效。**

### 4.4 子代理返回状态不可信

`delegate_batch` 返回 `cancelled`，但底层 worker 实际执行并改动了 4 个 owner_files。
判定依据：同一文件两次读取行号对不上，继而 `git status` 显示文件已变更。
**每批结束后必须用 `git status` 核对实际改动，再逐个读文件核验。**

### 4.5 `ui-acceptance-checklist.md` 的 Scope 已过时

该文档 Review Scope 段仍列旧路由名（`pages/LoginPage`、`pages/HomePage`、
`features/workout/pages/TrainingPlanDetailPage`），与当前 pencil 主线不符。
**页面清单以 `main_pages.json` 与 `AppRoutes.ets` 为准**，不要按该文档找页面。

### 4.6 `Scroll` 内部的 `layoutWeight` 不生效

`PencilAppShell.ets` 的 `layoutWeight(1)` 在视口层有效，但把内容迁进 `Scroll` 后即失效。
需要固定尺寸处改用 `constraintSize` 或显式高度。

### 4.7 ArkTS 严格模式禁令

不使用 `any`、`unknown`、`as const`、`@ts-ignore`、`for..in`、解构声明、函数表达式、嵌套函数、
`require`、`globalThis`、对象索引访问。触犯即编译失败。

### 4.8 滚动边界的判据只有原型

原型 `.frame` 外框一律 `overflow: hidden`（裁剪），真正的滚动容器是 `.pane-scroll` /
`.st-scroll` / `.wo-scroll` / `.bd-scroll` / `.sub-scroll` 等。**首页的日期问候、回顾页的周月切换
都在滚动区内**，不要想当然固定页头；`fittracker-training-preview.html` 则整屏无滚动容器，
不得添加 `Scroll`。

## 5. 验收口径（本项目）

- **裁剪区间**：`--crop 100,740`（剔除状态栏带与底部系统带）。
- **文本掩码**：由设备 a11y 树生成——`Text` 的像素 bounds ÷ 3.3846 转 vp → `y − 100` 转 crop 空间
  → 落在 `[0, 640)` 的才计入 `--ignore-rect`。
- **达标线**：**非文本内容区超阈像素占比 ≤ 8%**（`≤2%` 已被论证为跨渲染器不可达成的伪门槛）。
- **设备**：模拟器固定 390vp；320/360/430 响应式只能做静态审计 + 真机多机型抽测。
- **动效**：`compare-motion-frames.py` 给出的 MAE 越小越接近；收敛到“不再显著下降且并排肉眼一致”。

## 6. 与当前主线的边界

- **主线**：`features\pencil\`（登录、首页、计划、训练、复盘、个人页）+ `features\welcome\`、
  `features\onboarding\`、`features\exercise\`、`features\body\`、`features\settings\`、
  `features\monetization\`、`features\workout\`。
- **不要**重建历史壳、不要复活已归档页面、不要把已归档页面加回主路由。
- 归档素材在 `docs\archive\` 下，只用于追溯，不作为实现依据。
- 训练数据的兼容层（`WorkoutSessionPersistenceBridgeService`、`PersistenceFallbackService`）
  用于保护既有本地数据，**不要删除或绕过**。
- 本附录描述的是**视觉迁移**；业务逻辑、服务层、持久化不在迁移范围内。

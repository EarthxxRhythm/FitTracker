# 还原进度与证据（STATUS）

> 更新：2026-09-07。每步产物均随 commit 落库；生成物（截图/报告）在 `test_run/`，不入库。

## 完成

- **第 1 步 · 冻结规格源** ✅（commit bcd73c9）
  - `src/`：13 屏 HTML + webapp 壳 + `assets/` 快照（唯一视觉规格源）
  - `MANIFEST.md`：15 路由 → 文件/frame → ArkUI 落点
  - `MOTION.md`：逐屏动效声明（@keyframes/transition/animation/:active）
  - `docs/opendesign-1to1-rules.md` 修订为 390×844 直绘口径
- **第 2 步 · Token 审计与校准** ✅（commit d1f1cc6）
  - `TOKENS.md`：跨屏变量一致性 / 色值语义映射 / MotionTokens 覆盖审计
  - `DesignTokens.ets`：新增 `MotionTokens.DURATION_PROGRESS=350`（进度 .35s fill）
  - 编译门禁通过（assembleHap 产出新 HAP）
- **度量管道验证（端到端）** ✅
  - 参照帧：`python tools/render-prototype-phone.py` → `test_run/prototype-phone/welcome-home.png`
  - 设备帧：hdc 截图 `test_run/welcome-device.jpeg`（1320×2856）
  - 对比：`tools/visual-diff/compare.py`（density 3.3846, threshold 16）→ `test_run/welcome-compare.md`
  - 结果：welcome **基线 MAE=32.91 / 超阈 29.77%**；大差异带 = 状态栏(0-84)、视觉图形带(588-672)、CTA 带(756-844)
  - 结论：参考页 welcome 也未达像素 1:1（页面早于最新 HTML），全部 15 屏都需按新基线收敛

## 下一步（按计划第 3/4 步）

1. 黄金公共组件先行（tab pill/header/button/card/sheet/图表），每组件过组件级像素绿卡。
2. 批次 A：home（welcome-home · screen-home 帧）→ login/register → plan → profile → review 逐屏还原，
   每屏产出 changed_files + 静态帧/动效态帧 + compare 报告（目标：非文本内容区超阈 ≤8%）。
3. 批次 B/C：流程屏与新功能屏（body-data/settings/plans/planGroup/library…），新页双注册
   `main_pages.json` + `AppRoutes`。
4. 动效状态帧策略按已定默认（按压/弹层/celebrate 必截；持续脉冲只核 MOTION.md 映射表）。

## 基线数值速查（convergence 对照）

| 屏 | 参照帧 | MAE | 超阈% | 报告 |
|---|---|---|---|---|
| welcome | test_run/prototype-phone/welcome-home.png | 32.91 | 29.77 | test_run/welcome-compare.md |
| home（seed:today_flow） | test_run/prototype-phone/home-frame.png | 25.66 | 17.43 | test_run/home-compare.md |
| welcome · 内容区(y100-740) | test_run/prototype-phone/welcome-home.png | 31.01 | 26.15 | test_run/welcome-crop-compare.md |
| home · 内容区(y100-740) | test_run/prototype-phone/home-frame.png | 18.04 | 13.86 | test_run/home-crop-compare.md |

> compare.py 已支持 `--crop y0,y1` 内容区口径（tools/visual-diff README 有说明）；
> 口径已于 2026-09-07 由 `ACCEPTANCE-PLAN.md` 修正为「**非文本内容区超阈 ≤8%**」——原
> ≤2% 经论证为跨渲染器（浏览器 vs ArkUI）不可达成的伪门槛；度量手段为 `--crop 100,740`
> 加 `--ignore-rect` 文本掩码（掩码从设备 a11y 树自动提取）。
> 2026-09-11 已按该口径完成 15 屏实测：**4 屏达标 / 11 屏未达标**，结果见
> `test_run/emulator/ACCEPTANCE-2026-09-11.md`。

Home 基线分解：超阈集中在 band1(84-168 日期/问候文字带,字体度量差+起始位差)、band9(756-844
底部系统导航指示条/底部tab带)；band6/8 内容中段最低(4.8%/5.6%)。数字差(0/3次 vs 3/5次、0% vs
14%)源自种子 vs HTML 静态示例，属预期文本差非布局差。收敛循环目标：裁掉状态栏/底部系统带
并掩蔽文本后，**非文本内容区超阈 ≤8%**（口径见 `ACCEPTANCE-PLAN.md`）。

## 新需求：页面自适应设备屏幕（2026-09-07 加入）

- 双基准验收：① 390vp 非文本内容区超阈 ≤8%（口径见 `ACCEPTANCE-PLAN.md`）；② 自适应层（320–430vp 无溢出/无截断、安全区、
  字号 ≤1.3× 不破版；>600vp 平板/横屏阶段可选）。
- 结构规则改为流式/弹性优先（Column/Row/Scroll/layoutWeight/百分比），`.position` 仅限装饰层；
  规则已写入 docs/opendesign-1to1-rules.md §3 与「自适应与安全区」节。

## 黄金组件基线（进行中→基本完成）

- BottomTabBar 对齐 HTML：新增 ShadowTokens.TAB_PILL/TAB_PILL_ACTIVE（HTML 0 6px 14px/.30 与
  0 8px 20px/.34），SURFACE_NAV → rgba(8,12,15,.97)，ShadowTokens.NAV → 0,-8,28,.28；
  pill 阴影按激活态切换 + .16s implicit 色彩/阴影过渡（对应 HTML .tab/.pill transition）。
- AppButton/PageHeader 补按压（.985 / 返回 .94，120ms EASE_MOTION）；AppCard 无交互不须改。
- 输入/分段/chip/sheet/ring 均随各屏内联还原（共享组件使用面为零，不空建）。

## 并行任务已排队（cluster/inbox，供 app-engineer 认领）

- 批次 A：screen-home / login / register / plan / profile / review
- 批次 B：screen-workout-preview / active / complete
- 批次 C/新建：screen-library / body / settings / plans / plan-group
- 新页注册（main_pages.json + AppRoutes）由协调者统一做；验收 = 390vp 非文本内容区超阈 ≤8% + 320/360/430 冒烟 + 动效帧。

## ✅ 2026-09-07 全队列执行完成（13/13 outbox）
- 修复：Login/Register 输入聚焦态+密码可见（commit）；新建 Body/Settings/Plans/PlanGroupDetail
  四页（薄壳+内容组件，静态镜像示例数据）并注册到 main_pages.json(20 页)/AppRoutes（+4 常量）。
- 核验无改动：Home(有基线)、Plan、Profile、Active、Review、Preview、Complete、Library。
- 全量编译绿（assembleHap exit=0）与 check-gates 全过。
- 待办：1) 新页路由接线（profile 快捷入口/plans 点击跳计划组详情/body 与 settings 单位联动）；
  2) 设备像素/响应式/动效帧验收（15 屏逐屏 `--crop 100,740` + 文本掩码，≤8%；2026-09-11 已完成静态帧，结果见 `test_run/emulator/ACCEPTANCE-2026-09-11.md`）；3) 趋势折线、封面 icon、
  错误提示逐字段等已标 gaps；4) 数据可信回归（训练闭环 smoke）。

## 设备验证状态

- 已打通：渲染参照帧 → 装 HAP → 截图 → compare.py 数值报告（welcome 基线 MAE 32.91/超阈 29.77%，
  主因状态栏/图形/CTA 位差，待逐屏收敛）。
- 待办（需主会话串行设备循环）：每屏静态+响应式三档+动效帧收敛。

## 自适应（小屏不裁切）硬化（2026-09-07）
- 加 Scroll：PencilLoginPage / PencilRegisterPage（表单包 Scroll，高屏仍居中）、
  HomeContent / ProfileContent（主内容包 Scroll）——并行 app-engineer x2 + 手动 x2，devecocli 构建绿。
- 已具 Scroll：plan/review/active/body/settings/plans/plan-group/library/complete/detail/monetization/目标设置。
- 整屏固定面板特意不滚（留设备人工确认矮屏）：Splash/Welcome/TrainingPreview。
- 验收口径（ACCEPTANCE-PLAN.md 已修正）：像素 diff 仅粗定位；达标 = 无几何/色块错误 + 文本豁免（≤8% AA地板）。


## 2026-09-11 · 滚动边界对齐 + auth 缩放基准修复

**背景**：用户要求「非列表等溢出需滑动的组件保持固定」；核对原型后选定「忠于原型、双向对齐滚动边界」。

**关键发现（与既有文档冲突，以源码为准）**：

- `fittracker-auth.html:62` 定义 `--active-scale: 0.90698`，`.auth-frame`（:176-185）为 **430×900 画布 × 0.90698 ≈ 390×816**——login/register 与 welcome 同属「缩放画布」，**不是** 390×844 直绘。`README.md` 与 `docs/opendesign-1to1-rules.md` 硬规则 2 的「除 welcome 外 14 屏均 390 直绘」对 auth **不成立**。
- `restore-accept.ps1` 只做 `force-stop + start`，**不导航**，因此无法到达 login/register（冷启动落 Welcome，login 需点「开始使用」再进）。既有 `test_run/emulator/ACCEPTANCE-2026-09-11.md` 中 login/register 的数字口径**存疑**（可能截的是 Welcome 屏）。

**变更（4 文件）**：

- `PencilLoginPage.ets` / `PencilRegisterPage.ets`：brand/标题/form/switch 统一移入单层 `Scroll`（对齐 `.auth-scroll` 整页滚）；补 `430×900 + scale(0.90698, centerX/Y=0)` 缩放容器；去除原型不存在的 `justifyContent(Center)`；内容 padding 采用原型 `.auth-content` 的 `76/24/28`。
- `ActiveContent.ets`：`demoCard()` 移入 `Scroll`（对齐 `.wo-scroll` 含 demo-card）；`topProgress()` / `dock()` 保持在外。
- `ReviewContent.ets`：`segmentedControl()` 移入 `Scroll` 顶部（对齐 `.pane-scroll` 含 `.review-toolbar`）。
- `PlanContent.ets`：**核对结论 = 无需改动**——`plan.html:182-190` 的 `.plan-content{height:100%}` + `.current-plan/.today-plan` 用 `flex:2:8` 分配，内容永不溢出，`.pane-scroll` 的滚动不触发。

**设备实测**（390vp，`--crop 100,740`，文本掩码，口径见 `ACCEPTANCE-PLAN.md`）：

| 屏 | 基线（2026-09-11） | 本次 | 判定 |
|---|---|---|---|
| login | 13.46 / 10.02% | 11.85 / 9.32% | 改善 |
| register | 18.80 / 12.28% | 15.36 / 10.00% | 改善 |
| active | 4.80 / 6.58% | 5.10 / 6.53% | 持平（达标） |
| review | 11.56 / 11.49% | 11.99 / 11.75% | 持平 |

login 剩余差异集中在 band 6-7（CTA/分割线/社交按钮区，32.8%/29.0%），上半部 band 0-5 为 0.5%-8.4%。

**复现方式**：`restore-accept.ps1` 对 auth 屏无效；正确路径为 `bm clean` → `aa start` → `uitest uiInput click <「开始使用」坐标>` 到 login，再点「立即注册」到 register。掩码生成见 `test_run/genmask.py`（从 `uitest dumpLayout` 的文本 bounds ÷3.3846 换算）。

## 2026-09-12 · 首页（home）完整还原 + 度量管道垂直对齐修正

**根因**：`compare.py` 对原型帧与设备截图使用同一组裁剪坐标，而设备截图是整屏（含系统状态栏）、原型帧是 `.phone` 画布——页面元素整体错开，制造大面积**伪差**。首页有两个全宽、高对比的 CTA，错位后完全不重叠，因此比大块同色卡片的屏（active/plans/body/profile）明显更差。

**实测对齐量 = 35vp**（像素锚点：date 文字带 36 / greet 34 / 今日卡上边框 35）。注意 a11y root 的 `bounds` 从 132px 起（÷3.3846 = 39.0vp），**不能直接当对齐量用**——以像素锚点为准。

**改动**：

- 工具：`compare.py --align-y`（默认 0，历史数字可复现）、`restore-accept.ps1 -AlignY`（默认 35）、`genmask.py` 掩码同步偏移。
- 首页：删 `radialGradient` 光晕层（原型 `.appshell` 为纯色 `var(--ink-0)`，全文件仅 3 处渐变且均属 ring/divider）、背景渐变改纯色、两处 `--line-10` 描边 `#10FFFFFF`→`#1AFFFFFF`、补 title/rec 行高与 date/label/m-value/val 字距、移除原型没有的「查看预览」按压态。
- 配套：`BottomTabBar` 激活字重 600 与顶边 `rgba(255,255,255,.05)`；`PencilAppShell` Tab 转场改 160ms 单段 + `scale(.99)` 初态；新增 `MotionTokens.EASE_TAB`。

**复测（390vp · `--crop 100,740` · a11y 文本掩码 · 进度环豁免）**：

| 口径 | MAE | 超阈% | 判定 |
|---|---|---|---|
| 物理对齐 35 | 7.16 | **6.92%** | ✅ 达标（≤8%） |
| best-fit 30 | 4.76 | 5.18% | ✅ |
| `--align-y 0`（旧口径） | 20.47 | 18.34% | ❌ |

历史基线 `home 14.19%` 是在**无对齐**的错口径下测得的，不代表还原质量。

**已验证**：光晕删除在 band 0 生效（mean 4.11 → 1.11，降 73%）；band 5（CTA 带）从 18.24% 微升至 19.50%，为渲染器行高收缩残差。

**已知限度**：ArkUI 默认行高比 Chrome `line-height: normal` 小约 10%，导致页内**累积收缩**——首页顶部元素需偏移 35，今日卡内 CTA 只需 30。单一 `--align-y` 无法逐元素对齐，故验收**同时记录两组数字**：「物理对齐」（达标判据）与「best-fit」（定位参考）。

## 2026-09-12（续）· 行高收缩根治 —— 直接向 Chrome 取值

**方法**：不再猜 `line-height: normal` 是多少。用 headless Chrome 在原型页面上执行后 `--dump-dom`，从 `<title>` 取回 `getBoundingClientRect()` 实测值。工具：`tools/probe-css-metrics.py`——与 `tools/spec-bounds-diff.py` **互补**：后者读 CSS *声明值*（查坐标是否偏移），前者读渲染后的*计算值*（查尺寸为何不符），`line-height: normal` 与 flex gap 的计算结果只在后者可见。

**Chrome 实测 vs 设备 a11y**：

| 元素 | Chrome 高 | 设备（修前） | 差 |
|---|---|---|---|
| `.today-id .label` (12.7px) | 19.00 | 15.4 | +3.60 |
| `.today-id .muscle` (12.7px) | 19.00 | 15.4 | +3.60 |
| `.today-id .day` (10.9px) | 16.00 | 13.0 | +3.00 |
| `.today-id .title-row` | 24.63 | 26.2 | −1.57 |
| `.today-id` 合计 | **103.63** | 94.6 | **+9.03** |
| `.today` 卡片总高 | 393.63 | 389.1 | +4.53 |

即 Chrome 对 12.7px 的 `normal` 行高是 19px（≈1.5×），ArkUI 默认仅 ≈1.21×。

**改动**（`HomeContent.ets`）：给 `.today-id` 的 label / muscle 补 `lineHeight(19)`、day 补 `lineHeight(16)`（title/rec 此前已补）。

**验证（复现即证）**：

- 设备 a11y 复测：label 18.9 / muscle 18.9 / day 16.0 / title 24.5 —— 逐项命中 Chrome 值；`.today-id` 从 94.6 恢复到 **102.2**（Chrome 103.63，残余 1.4）。
- 绿色 CTA 按钮带像素位置：**(458,497) → (461,499)**，下移 3.6vp，与 `today-top` 从 100 → 102.2 的预期一致。
- 偏移扫描最优点：**30 → 33**，向物理值 35 收敛。

**最终数字**：

| 口径 | 修前 | 修后 | Δ |
|---|---|---|---|
| 物理对齐 35 + 掩码 + 环豁免 | 6.92% | **5.65%** | −1.27pt |
| best-fit 33 + 掩码 + 环豁免 | 5.18%（align 30） | **4.39%** | −0.79pt |
| `--align-y 0` + 掩码 | 18.34% | 18.88% | — |

**残余**：`.today-id` 仍差 1.4vp（Chrome 103.63 vs 设备 102.2），来自 flex `gap`/`margin` 的取整累积；物理对齐 35 与 best-fit 33 之间仍有 2vp 差，故两组口径**继续并列使用**。

**动效态帧**：设备无 `screenrecord`，160ms 过渡中间帧**无法捕获**。已捕获 Tab 切换**终态**帧（`test_run/restore-accept/tab-plan.jpeg`；点击「计划」tab 后 a11y 确认为计划页，与首页帧 MAE 19.14、内容区行带差异 14–40%），证明切换与渲染正确。过渡曲线只做代码级核对（`MotionTokens.EASE_TAB` = `bezier(0,0,.2,1)`、160ms、初态 `scale(.99)`）。

**响应式**：设备固定 390vp，`devecocli ui window` 只有 `list`（不能改窗口）、`wm size` 不可用 → 无法做 320/360/430 设备截图，**降级为静态审计**：首页链路（`HomeContent` / `BottomTabBar` / `PencilAppShell`）无 ≥320vp 硬编码宽度；全仓仅 `WorkoutCompletePage.ets:248` 有 `.width(430)`，那是该屏缩放画布（430×930.6×0.90698）的原型规格，非缺陷。

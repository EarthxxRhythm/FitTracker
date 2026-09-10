# Open Design → ArkUI 1:1 还原规则（修订版）

目标：把 Open Design 最新 HTML 原型（`fittracker-webapp.html` 预览壳，15 路由）
1:1 还原到 FitTracker ArkUI。**冻结基线与规格：`design/06_prototype_redraw/`**
（MANIFEST.md / MOTION.md / TOKENS.md / src/），外部目录仅作增量 diff 来源。

## 硬规则

1. 冻结基线 `design/06_prototype_redraw/src/*.html` 是唯一规格源，禁止“近似”或沿用错误旧值。
2. **画布口径**：除 `screen-welcome`（`fittracker-welcome-home.html` 内 `.w-frame`，
   430×900 画布 × `SCALE=0.90698` ≈ 390×816）外，其余 14 屏均为 390×844 直绘，
   与设备 vp **1:1**，不再乘任何 SCALE。像素对比：模拟器截图 ÷ 3.3846 后对齐 390×844。
3. 结构（自适应优先）：`@Entry @Component struct`；整屏画布以 390×844 vp 为设计基准，但**结构化容器一律用流式/弹性布局还原**：`Column/Row/Scroll` + `.layoutWeight()`/百分比宽 + `Flex`，对应 HTML `.appshell`/`.pane` 等 flex 语义；**`.position({x,y})` 绝对定位只用于装饰性覆盖层**（背景艺术、徽章、浮层内锚点），且锚点优先相对容器计算。禁止用固定坐标堆整页内容。

## 自适应与安全区（双基准验收）

- 设计基准 390×844 vp（= 冻结 HTML 画布 = 默认模拟器视口），像素对比验收仍在此 vp 上进行（**非文本内容区**超阈 ≤8%，口径定义见 `design/06_prototype_redraw/ACCEPTANCE-PLAN.md`）。
- **自适应层**（与像素基准同时满足）：
  1. 宽度 320–430 vp 竖屏：页面不横向溢出、不出现截断硬编码；页面左右 gutter 用 `SpacingTokens.PAGE_GUTTER`（16），窄屏可按 `>=360` 判断收窄为 16/12。
  2. 高度不足/超长：`Scroll` 包裹、避免固定高卡片撑破；键盘弹起与底部栏避开用 safe-area/avoidArea。
  3. 文本：不写死单行定高撑版面；默认 `maxLines + TextOverflow.Ellipsis`；系统字号放大 ≤1.3× 不破版（按钮用 minHeight 而非固定 height 时用 `.constraintSize({ minHeight })`）。
  4. 平板/横屏/折叠（>600 vp，阶段可选）：结构性栅格用 `GridRow` 断点或 `.layoutWeight` 重排，装饰不溢出即可，不追求 1:1。
- 验收链：每屏 = ①390vp **非文本内容区**超阈 ≤8%（口径见 `ACCEPTANCE-PLAN.md`；原 ≤2% 已论证为不可达成的伪门槛）+ ②响应式冒烟（320/360/430 三档截图无溢出/无错位，以 compare 行带突变或肉眼采样为准）+ ③动效态帧（按压/弹层/celebrate）。
4. 颜色从 HTML `:root` 原样取用（TOKENS.md 汇总）：`rgba(r,g,b,a)` → `#AARRGGBB`，
   `AA = round(a*255)`。例：`rgba(255,255,255,.56)` → `#8FF3FBF7`。
5. 字体：中文 `fontFamily('HarmonyOS Sans')`；HTML `--font-num`(Inter) → 数字体令牌；
   `--font-mono`(Geist Mono) → mono 令牌。
6. 保留现有导航（`getUIContext().getRouter()` + `AppRoutes`）、数据/服务 import、`@State`
   逻辑；只改视觉布局、内容、颜色、尺寸、图标与动效。
7. ArkTS strict：不用 `any`/`unknown`/`as const`/`@ts-ignore`/`for..in`/解构/函数表达式/
   `require`/`globalThis`/对象索引访问；import 在文件顶部；显式接口/类型。遵循 AGENTS.md。
8. 图标优先复用 `entry/src/main/resources/rawfile/` 现有 SVG；缺失时用 ArkUI
   `Path/Line/Circle/Polygon` 内联绘制，除非确有必要才新增 rawfile SVG。
9. 动效（含按压反馈、面板转场、关键帧序列）一律引用 `common/styles/DesignTokens.ets`
   `MotionTokens`，实现模式见 `docs/motion-restore-workflow.md` §2；时长/曲线/按压缩放
   系数核对 `MOTION.md`。禁止页面内散落魔法动效值。
10. 中文必须与 HTML 逐字一致；HTML 为 UTF-8，读文件用 UTF-8 避免 GBK 乱码。
11. 每屏还原后按 `docs/模拟器视觉回归说明.md` + `design/06_prototype_redraw/README.md`
    的像素/动效双轨验收（门槛：**非文本内容区**超阈像素占比 ≤8%，定义见 `ACCEPTANCE-PLAN.md`；
    可捕获动效态同标准；持续脉冲只核 MOTION.md 映射表）。

## 设计令牌（跨屏一致，逐屏差异见 TOKENS.md）

- 背景：`--ink-0:#0B0F13` `--ink-1:#0A0D12` `--bg:#07090B` `--surface:#10171B`
  `--surface-2:#121A1E`；欢迎页专用 `--ink-welcome-0:#10171B`
- 强调：`--accent:#50ECA7` `--accent-deep:#45C9A1` `--accent-soft:#8CEBCC`
  `--on-accent:#07100B`
- CTA 渐变：`--cta-a:#47D994` `--cta-b:#53E7A5`（若页面使用）
- 文本：`--txt-hi:#F7FBF8` `--txt-body:#EDF6F2` `--white-70/-54/-40/-32` alpha 白
- 描边/玻璃：`--hairline:rgba(255,255,255,.06~.07)` `--line-10/-14/-16` `--accent-40..07`
- 视觉卡：`--visual-a:#14241F` `--visual-b:#0D1616`；`--font-cn/num/mono`

## 页面映射（15 路由 → ArkUI）

| route | HTML src frame | ArkUI 落点 | 状态 |
|---|---|---|---|
| welcome | welcome-home · screen-welcome | PencilWelcomePage.ets | 参考已达标（勿动） |
| home | welcome-home · screen-home | PencilAppShell HomeContent / PencilHomePage | 待还原 |
| login/register | auth · screen-login / screen-register | PencilLoginPage / PencilRegisterPage | 待还原 |
| plan | plan · screen-plan | PlanContent / PencilPlanPage | 待还原 |
| workout | training-preview · screen-training-preview | PencilPreviewPage | 待还原 |
| plans | plan-detail · screen-plan-detail | 新建（计划组） | 待建 |
| planGroup | plan-group-detail · screen-plan-group-detail | 新建（计划组详细） | 待建 |
| active | training · screen-training | ActiveContent / PencilActivePage | 待还原 |
| complete | training-complete · screen-training-complete | WorkoutCompletePage | 待还原 |
| review | review · screen-review | ReviewContent / PencilReviewPage | 待还原 |
| library | exercise-library · screen-exercise-library | ExerciseLibraryPage | 待还原 |
| body | body-data · screen-body-data | 新建（身体数据） | 待建 |
| profile | personal · screen-personal | ProfileContent / PencilProfilePage | 待还原 |
| settings | settings · screen-settings | 新建（设置） | 待建 |

# Open Design → ArkUI 1:1 还原规则（修订版）

目标：把 Open Design 最新 HTML 原型（`fittracker-webapp.html` 预览壳，15 路由）
1:1 还原到 FitTracker ArkUI。**冻结基线与规格：`design/06_prototype_redraw/`**
（MANIFEST.md / MOTION.md / TOKENS.md / src/），外部目录仅作增量 diff 来源。

## 硬规则

1. 冻结基线 `design/06_prototype_redraw/src/*.html` 是唯一规格源，禁止“近似”或沿用错误旧值。
2. **画布口径**：除 `screen-welcome`（`fittracker-welcome-home.html` 内 `.w-frame`，
   430×900 画布 × `SCALE=0.90698` ≈ 390×816）外，其余 14 屏均为 390×844 直绘，
   与设备 vp **1:1**，不再乘任何 SCALE。像素对比：模拟器截图 ÷ 3.3846 后对齐 390×844。
3. 结构：`@Entry @Component struct`；整屏画布 390×844 用 `Column`/`Scroll`/`Stack`
   按对应 frame 的 DOM 结构还原；绝对定位元素用 `.position({x,y})`，**数值与 HTML 一致**。
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
    的像素/动效双轨验收（门槛：主区域超阈像素占比 ≤2%；可捕获动效态同标准；持续脉冲
    只核 MOTION.md 映射表）。

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

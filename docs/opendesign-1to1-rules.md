# Open Design → ArkUI 1:1 还原规则

目标：把 `C:\Users\19308\AppData\Roaming\Open Design\namespaces\release-stable-win\data\projects\56d6b0af-ac55-498d-9942-c02a4d35cc71\*.html` 的 App 页面 1:1 还原到 FitTracker ArkUI。

## 硬规则

1. HTML 文件是唯一规格源，禁止“近似”或沿用错误旧值。
2. 视口 390×844；设计空间 430×900；`SCALE = 390/430 = 0.9069767`；`FRAME_HEIGHT = 900 * SCALE ≈ 816.28`。
3. 结构照抄已达标参考页 `entry/src/main/ets/features/welcome/pages/PencilWelcomePage.ets`：`@Entry @Component struct`、`Stack({ alignContent: Alignment.TopStart })`、绝对定位 `.position({ x, y })`、全部尺寸 × `SCALE`。
4. 颜色从 HTML `:root` 原样取用；`rgba(r,g,b,a)` 转 ArkUI `#AARRGGBB`，`AA = round(a*255)` 十六进制。例：`rgba(80,236,167,.302)` → `#4D50ECA7`；`rgba(255,255,255,.65)` → `#A6FFFFFF`。
5. 字体：中文 `fontFamily('Noto Sans SC')`；`--font-num` → `'Inter'`；`--font-mono` → `'Geist Mono'`。
6. 保留现有导航（`getUIContext().getRouter()` + `AppRoutes`）、数据/服务 import、`@State` 逻辑；只改视觉布局、内容、颜色、尺寸、图标。
7. ArkTS strict：不用 `any`/`unknown`、不对象索引访问、显式类型、import 在文件顶部、不用 `for..in`/解构/函数表达式；遵循 AGENTS.md。
8. 图标优先复用 `entry/src/main/resources/rawfile/` 现有 SVG；缺失时用 ArkUI `Path/Line/Circle/Polygon` 内联绘制，除非确有必要才新增 rawfile SVG。
9. 不要执行 build/install；只编辑自己负责的 `.ets` 文件（必要时新增 rawfile 图标）。
10. 中文必须与 HTML 逐字一致。HTML 是 UTF-8；用 `Get-Content -Encoding UTF8` 或 `python -c "open(p,encoding='utf-8').read()"` 读取，避免 GBK 乱码。

## 设计令牌（各 HTML `:root` 一致）

- 背景：`--ink-0:#0B0F13` `--ink-1:#0A0D12` `--ink-welcome-0:#10171B`
- 强调：`--accent:#50ECA7` `--accent-deep:#45C9A1` `--accent-soft:#8CEBCC`
- CTA 渐变：`--cta-a:#47D994` `--cta-b:#53E7A5`
- 强调上文字：`--on-accent:#07100B` `--on-accent-2:#08110D`
- 文本：`--txt-hi:#F7FBF8` `--txt-body:#EDF6F2`
- 视觉卡：`--visual-a:#14241F` `--visual-b:#0D1616`

## 页面映射

| HTML | ArkUI 文件 |
|---|---|
| fittracker-auth.html（登录+注册两个 phone） | PencilLoginPage.ets + PencilRegisterPage.ets |
| fittracker-personal.html | PencilProfilePage.ets |
| fittracker-plan.html | PencilPlanPage.ets |
| fittracker-training-preview.html | PencilPreviewPage.ets |
| fittracker-training.html | PencilActivePage.ets |
| fittracker-training-complete.html | WorkoutCompletePage.ets |
| fittracker-review.html | PencilReviewPage.ets |
| fittracker-welcome-home.html | PencilWelcomePage.ets（已达标，勿改） |

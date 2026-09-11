# FitTracker 文档入口

## 当前实现依据

- 当前页面注册唯一来源：`entry/src/main/resources/base/profile/main_pages.json`
- 当前代码路由唯一来源：`entry/src/main/ets/app/AppRoutes.ets`
- 当前工程约束：根目录 `AGENTS.md`
- 当前 UI 主线：`features/pencil/`、`features/welcome/`、`features/onboarding/`、`features/exercise/`、`features/monetization/`、`features/workout/`

当前训练主线为：

`PencilSplashPage -> PencilWelcomePage -> PencilLoginPage/PencilRegisterPage -> GoalSetupPage -> PencilAppShell`

应用壳内的主要内容由 `PencilHomePage`、`PencilPlanPage`、`PencilPreviewPage`、`PencilActivePage`、`WorkoutSummaryPage`、`PencilReviewPage` 和 `PencilProfilePage` 承载。

## 历史归档

`docs/archive/legacy-routes-2026-08/` 保存旧启动页、旧首页原型、旧训练页、旧路由图和已完成的实现计划。归档文件只用于审计和历史追溯，不作为新的代码、路由或目录实现依据。

验收证据、构建记录和设备回归材料继续保留在原位置，除非明确要求，不移动或删除。

## 迁移提示词

把 Open Design HTML 原型迁移为 ArkUI 页面（完整 UI/UX 还原）时使用的提示词，拆为两份配合使用：

- `docs\prototype-to-arkui-prompt-template.md` —— 通用方法论模板，跨项目复用，方括号处按项目替换
- `docs\prototype-to-arkui-prompt-fittracker.md` —— FitTracker 专属附录：八项规格源落点、15 屏清单与 ArkUI 落点、可执行命令、已踩过的坑、验收口径

用法：先读附录第 1 节确认规格源，再把模板正文的方括号填成附录里的实际路径。

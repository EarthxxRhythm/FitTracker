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

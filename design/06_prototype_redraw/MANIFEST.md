# FitTracker 界面重建 · 规格清单（MANIFEST）

> 冻结基线目录：`design/06_prototype_redraw/src/`（唯一视觉规格源，勿手改；
> HTML 更新走 Open Design 目录 → 增量 diff 流程）。

## 1. 路由映射（来自 fittracker-webapp.html ROUTES）

| # | route | 屏文件 | frame | 中文 | 当前仓库落点 |
|---|-------|--------|-------|------|--------------|
| 1 | `welcome` | `fittracker-welcome-home.html` | `screen-welcome` | 启动-欢迎页 | PencilWelcomePage.ets（参考已达标） |
| 2 | `home` | `fittracker-welcome-home.html` | `screen-home` | 首页 Tab | PencilHomePage.ets / PencilAppShell HomeContent |
| 3 | `login` | `fittracker-auth.html` | `screen-login` | 登录 | PencilLoginPage.ets |
| 4 | `register` | `fittracker-auth.html` | `screen-register` | 注册 | PencilRegisterPage.ets |
| 5 | `plan` | `fittracker-plan.html` | `screen-plan` | 计划 Tab | PencilPlanPage.ets / PlanContent |
| 6 | `workout` | `fittracker-training-preview.html` | `screen-training-preview` | 训练 Tab-预览 | PencilPreviewPage.ets |
| 7 | `plans` | `fittracker-plan-detail.html` | `screen-plan-detail` | 计划组 | PencilPlansPage.ets / PlansContent |
| 8 | `planGroup` | `fittracker-plan-group-detail.html` | `screen-plan-group-detail` | 计划组详细 | PencilPlanGroupDetailPage.ets / PlanGroupDetailContent |
| 9 | `active` | `fittracker-training.html` | `screen-training` | 训练执行 | PencilActivePage.ets / ActiveContent |
| 10 | `complete` | `fittracker-training-complete.html` | `screen-training-complete` | 训练完成 | WorkoutCompletePage.ets |
| 11 | `review` | `fittracker-review.html` | `screen-review` | 训练回顾 Tab | PencilReviewPage.ets / ReviewContent |
| 12 | `library` | `fittracker-exercise-library.html` | `screen-exercise-library` | 动作库 | ExerciseLibraryPage.ets |
| 13 | `body` | `fittracker-body-data.html` | `screen-body-data` | 身体数据 | BodyDataPage.ets / BodyDataContent |
| 14 | `profile` | `fittracker-personal.html` | `screen-personal` | 我的 Tab | PencilProfilePage.ets / ProfileContent |
| 15 | `settings` | `fittracker-settings.html` | `screen-settings` | 设置 | PencilSettingsPage.ets / SettingsContent |

外壳入口：`fittracker-webapp.html`（15 路由预览壳，390×844 iframe）。

## 2. 快照文件清单

| 文件 | bytes | frames | 标题 |
|---|---|---|---|
| `fittracker-auth.html` | 32888 | screen-login, screen-register | FitTracker · 登录与注册原型 |
| `fittracker-body-data.html` | 31698 | screen-body-data | FitTracker 身体数据页原型 |
| `fittracker-brand-identity.html` | 30120 | - | FitTracker · 品牌标识系统 |
| `fittracker-exercise-library.html` | 42383 | screen-exercise-library | FitTracker · 动作库页原型 |
| `fittracker-personal.html` | 97719 | screen-personal | FitTracker 个人页原型 |
| `fittracker-plan-detail.html` | 20607 | screen-plan-detail | FitTracker · 计划组原型 |
| `fittracker-plan-group-detail.html` | 25481 | screen-plan-group-detail | FitTracker · 计划组详细页原型 |
| `fittracker-plan.html` | 38213 | screen-plan | FitTracker · 计划页原型 |
| `fittracker-review-openstats-1to1.html` | 18550 | - | openGym Stats 组件 · 1:1 还原 |
| `fittracker-review.html` | 70759 | screen-review | FitTracker · 训练回顾 |
| `fittracker-settings.html` | 21854 | screen-settings | FitTracker · 设置页原型 |
| `fittracker-training-complete.html` | 18800 | screen-training-complete | FitTracker · 训练完成页原型 |
| `fittracker-training-preferences.html` | 20232 | screen-training-preferences | FitTracker · 训练偏好页原型 |
| `fittracker-training-preview.html` | 19381 | screen-training-preview | FitTracker · 训练预览页原型 |
| `fittracker-training.html` | 34895 | screen-training | FitTracker · 训练页原型 |
| `fittracker-webapp.html` | 20288 | - | FitTracker · 连续网页版原型 |
| `fittracker-welcome-home.html` | 38711 | screen-welcome, screen-home | FitTracker · 界面重建原型 |

另含 `assets/`（ft-stage.js、exercise-gifs/、opengym-ref/）。

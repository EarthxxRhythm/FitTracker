# FitTracker 项目约束

> 最后核对：2026-08-01。本文只描述当前主线；历史设计、旧路由和已归档计划不作为实现依据。

## 项目概览

HarmonyOS Stage 模式的 ArkUI 健身训练应用，中文本地化、本地数据优先。应用记录训练组数/次数/重量，计算 Epley 1RM，并保存目标、计划、训练会话、复盘与备份数据。

技术栈：ArkTS/ArkUI、`@kit.ArkData` preferences、Stage Ability、ohosTest。

## 当前代码边界

```text
entry/src/main/ets/
├── app/                  # 启动、路由常量、应用壳
├── features/
│   ├── pencil/           # 当前视觉主线：登录、首页、计划、训练、复盘、个人页
│   ├── welcome/          # 欢迎页
│   ├── onboarding/       # 目标设置
│   ├── exercise/         # 动作库与动作详情
│   ├── monetization/     # 会员能力展示
│   └── workout/          # 训练完成、摘要及训练流兼容服务
├── shared/               # 跨功能内容、计划、复盘、备份、同步和内存仓库
├── common/               # 稳定的认证、会话、计划/训练持久化和设计令牌
└── components/           # 可复用 ArkUI 组件
```

`entry/src/main/resources/base/profile/main_pages.json` 是页面注册的唯一事实来源；`app/AppRoutes.ets` 是代码中的路由常量来源。新页面必须同时满足：文件存在、注册到 `main_pages.json`、由 `AppRoutes` 或明确的父页面引用。

当前注册主线：

- `features/pencil/PencilSplashPage`
- `features/welcome/pages/PencilWelcomePage`
- `features/pencil/PencilLoginPage`
- `features/pencil/PencilRegisterPage`
- `features/pencil/PencilProfilePage`
- `features/onboarding/pages/GoalSetupPage`
- `app/PencilAppShell`
- `features/pencil/PencilHomePage`
- `features/exercise/pages/ExerciseLibraryPage`
- `features/exercise/pages/ExerciseDetailPage`
- `features/monetization/pages/MonetizationHubPage`
- `features/pencil/PencilPlanPage`
- `features/pencil/PencilPreviewPage`
- `features/pencil/PencilActivePage`
- `features/workout/pages/WorkoutCompletePage`
- `features/workout/pages/WorkoutSummaryPage`
- `features/pencil/PencilReviewPage`

旧的 `pages/Index`、`pages/ProfilePage`、旧认证页、旧标签栏、旧常量和未注册的旧功能页已经移除。不要重新创建历史壳，也不要把已归档页面加入主路由。

## 服务归属

- `common/services/`：preferences 持久化、认证、会话 token、用户资料、稳定的计划/训练 API。
- `shared/services/`：内容目录、计划引擎、首页/复盘派生数据、同步、备份、内存仓库和持久化降级组合。
- `features/workout/services/`：仅放训练功能专属编排，以及新旧训练数据模型之间的兼容桥。

服务均使用模块级 singleton：`export default new ServiceName()`。调用方直接导入默认实例，禁止在页面或服务中再次 `new`。

现有兼容层（尤其 `WorkoutSessionPersistenceBridgeService` 和 `PersistenceFallbackService`）用于保护已有本地训练数据，除非明确完成数据迁移，不要删除或绕过。

## ArkUI / ArkTS 约定

- 页面使用 `@Entry @Component struct`；异步加载放在 `aboutToAppear()`，销毁时清理 timer/listener。
- 导航使用 `this.getUIContext().getRouter()`，路由名只引用 `AppRoutes` 常量。路由参数使用 `getParams()` 时必须显式声明类型并用 `try-catch` 处理缺失参数。
- 系统上下文通过 `getUIContext().getHostContext()` 获取并做空值保护；preferences API 的异步调用必须在成功写入后 `flush()`。
- 通用组件的颜色、字体、间距、圆角优先使用 `common/styles/DesignTokens.ets`；Pencil 主线允许使用 feature 内集中声明的视觉 token，不要在单个组件中散落魔法值。
- 所有新增用户可见文本使用中文；资源、权限和 API Level 变更要同步检查 `module.json5` 与资源目录。
- 保持 ArkTS strict mode：不使用 `any`、`unknown`、`as const`、`@ts-ignore`、`for..in`、解构声明、函数表达式、嵌套函数、`require`、`globalThis` 或对象索引访问；对象和数组使用显式接口/类型。
- import 必须位于文件顶部；优先使用官方 HarmonyOS API 和 ArkUI 组件。

## 清理规则

- 先查 `main_pages.json`、`AppRoutes.ets`、ArkTS import 和测试引用，再删除文件。
- 当前工作区已有的未提交改动属于用户资产；除非用户明确要求，不回退、覆盖、移动或删除这些文件。
- 仅因为文件名含有 `legacy` 不足以删除：先确认是否承载本地数据兼容、备份或测试契约。
- 生成的构建日志、模拟器输出和 `test_run/` 不属于源代码；清理它们前先确认不是用户要保留的验收证据。

## 常用检查

```powershell
node tools/check-main-pages.mjs
node tools/check-gates.mjs
hvigorw assembleHap --mode module -p product=default
```

设备回归使用 `tools/auth-regression.ps1` 或 `tools/dev-smoke.ps1`；没有设备时至少运行路由检查、静态引用检查和可用的 ArkTS/ohosTest 构建。

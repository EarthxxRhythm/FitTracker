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

页面统一放在 `features/<feature>/pages/`；Tab 内容等无 `@Entry` 的界面体放 `features/<feature>/components/`。当前注册主线：

- `features/pencil/pages/PencilSplashPage`
- `features/welcome/pages/PencilWelcomePage`
- `features/pencil/pages/PencilLoginPage`
- `features/pencil/pages/PencilRegisterPage`
- `features/pencil/pages/PencilProfilePage`
- `features/onboarding/pages/GoalSetupPage`
- `app/PencilAppShell`
- `features/pencil/pages/PencilHomePage`
- `features/exercise/pages/ExerciseLibraryPage`
- `features/exercise/pages/ExerciseDetailPage`
- `features/monetization/pages/MonetizationHubPage`
- `features/pencil/pages/PencilPlanPage`
- `features/pencil/pages/PencilPreviewPage`
- `features/pencil/pages/PencilActivePage`
- `features/workout/pages/WorkoutCompletePage`
- `features/pencil/pages/PencilReviewPage`

pencil 的 Tab 界面体组件：`features/pencil/components/` 下 `HomeContent` / `PlanContent` / `ProfileContent` / `ReviewContent` / `ActiveContent`，供 `PencilAppShell` 与对应薄壳注册页复用。

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

## 多代理消息通道（平台通道故障时的文件信箱协议）

平台的 inter-agent `message` 载荷投递当前不可靠（spawn/followup/send 会触发回合，但内容可能为空）。所有并行子代理必须走共享文件信箱，不依赖消息参数携带任务正文。

- 协调者：先用 `apply_patch` 把任务写入 `cluster/inbox/<task>.json`，再 `spawn_agent`，必须传 `fork_turns="none"`；`message` 只写一行简短提示，正文以信箱文件为准。
- 子代理：启动后若分析通道中没有 `NEW_TASK` 载荷，扫描 `cluster/inbox/*.json`，认领文件修改时间最早的任务并原子移动到 `cluster/claimed/`，再执行；完成后把结果写入 `cluster/outbox/<task>.json`，并在 final answer 中给出摘要。
- 协调者：轮询 `cluster/outbox/` 收敛结果；不要用 `wait_agent` 作为完成信号，以 outbox 文件为准。
- 协议细节与 JSON 字段约定见 `cluster/PROTOCOL.md`。

## 提效约定

Agent 默认按以下顺序优先使用已装好的提效工具，避免低效的 grep/read 循环：

- **codegraph 优先**：本项目已索引 `.codegraph/`。理解代码、查调用链、判断改动影响时先 `codegraph_explore`（一次返回逐行源码 + 调用路径 + 依赖方），不要先 grep/read 兜圈。
- **上下文主动压缩**：每个探索/实现阶段闭环后主动 `compress`，保持高信号窗口；超大文件只看骨架时用 `token-optimizer`。
- **并行拆块**：2+ 个无共享状态、无顺序依赖的任务并行执行，走本项目的 `cluster/` 文件信箱协议（见上一节）或用 `dispatching-parallel-agents`；复杂多文件特性先由 TaskManager 拆块。
- **上下文发现走子代理**：内部规范/模式用 `ContextScout`，外部库最新文档用 `ExternalScout` 或 `context7`，不自己逐文件翻。
- **HarmonyOS 构建/文档走 `deveco-cli`**：scaffold/build/run/debug/devices/docs 均通过它，不裸跑 hvigorw 或凭训练数据猜 SDK API。

## 并行优先原则（2026-09-07 起）

工作量大或重复度高时，先判断能否并行：

1. 拆分成**互不重叠**的子单元（不同文件/不同屏/不同服务）。
2. 用 pi `subagent` 工具并行派 `app-engineer`/`spec-scout`/`qa-device`（默认 ≤4，agentScope both，任务自包含写入 cluster/inbox，结果回 cluster/outbox）。
3. **单写者纪律**：构建(assembleHap)、装 HAP、设备截图、git 提交只由主会话/协调者执行；子代理只编辑 owner_files 并本地静态自洽。
4. 同文件、同设备、有数据依赖的任务不并行（会互相覆盖/串行化），显式说明原因。
5. 并行批次后统一编译+验收，达标才合并/提交。

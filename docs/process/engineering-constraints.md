# 菲特 项目约束

> **层级**：L1 权威
> **最后核对**：2026-10-28
> **上位文档**：无，本文为顶层
> **说明**：本文原名 `AGENTS.md`，内容为工程约束本体，与 AI 工具配置无关，故改用工程文档名；各目录就近约束同样由 `AGENTS.md` 改名为 `CONVENTIONS.md`
> **状态**：现行
> **路径基准**：文中 `apps\…`、`docs\…`、`server\…` 相对仓库根；标注 `cd apps/harmony` 之后的 `tools\…` 相对鸿蒙工程根
> **适用端**：双端

> 2026-10-12 monorepo 重组说明：鸿蒙工程位于 `apps/harmony/`，安卓位于 `apps/android/`，共享文档在仓库根 `docs/`。页面清单与 features 边界已按 `main_pages.json` 最新版校准；登录/注册已云端化（2026-10-28 起为自托管 Supabase，原华为 AGC 链路已整体移除），「训练目标」引导页已移除。本文只描述当前主线；历史设计、旧路由和已归档计划不作为实现依据。

## 项目概览

HarmonyOS Stage 模式的 ArkUI 健身训练应用，中文本地化、本地存储 + 账号云同步（自托管 Supabase：认证服务 + Postgres 整包快照）。应用记录训练组数/次数/重量，计算 Epley 1RM，并保存目标、计划、训练会话、回顾与备份数据。

技术栈：ArkTS/ArkUI、`@kit.ArkData` preferences、Stage Ability、ohosTest。

## 当前代码边界

```text
apps/harmony/entry/src/main/ets/
├── app/                  # 启动、路由常量、应用壳
├── features/
│   ├── pencil/           # 当前视觉主线：登录、首页、计划、训练（含预览覆盖层）、回顾、个人页
│   ├── welcome/          # 欢迎页
│   ├── exercise/         # 动作库与动作详情
│   ├── body/             # 身体数据
│   ├── settings/         # 设置
│   └── workout/          # 训练完成、摘要及训练流兼容服务
├── shared/               # 跨功能内容、计划、回顾、备份、云同步和内存仓库
├── common/               # 稳定服务：认证（Supabase/沙盒双实现）、会话、云环境探测、计划/训练持久化、设计令牌
└── components/           # 可复用 ArkUI 组件
```

`apps/harmony/entry/src/main/resources/base/profile/main_pages.json` 是页面注册的唯一事实来源；`app/AppRoutes.ets` 是代码中的路由常量来源。新页面必须同时满足：文件存在、注册到 `main_pages.json`、由 `AppRoutes` 或明确的父页面引用。

页面统一放在 `features/<feature>/pages/`；Tab 内容等无 `@Entry` 的界面体放 `features/<feature>/components/`。当前注册页面的完整清单以 `main_pages.json` 为准（本文不再复制，避免与事实源漂移）。

界面体组件：`features/pencil/components/` 下按 `*Content` 命名的组件，供 `PencilAppShell` 与对应薄壳注册页复用；`features/body/components/`、`features/settings/components/` 同理。训练预览为 `features/pencil/pages/PencilPreviewPage.ets` 中的 `PencilPreviewContent`（无 `@Entry`，由 `PencilAppShell.build()` 在 `Stack` 内以 `if (showPreview)` 条件渲染成覆盖层，不注册路由。**不是 `bindContentCover`**——该方案在设备上不可用）。

冷启动分流：未登录 → 登录页；已登录（无论有无目标）→ 主壳。原「训练目标」引导页已移除，无目标场景由首页空态承接。原「账号与同步」页已下线，退出登录并入设置页，同步改为登录后恒定自动。

旧的 `pages/Index`、`pages/ProfilePage`、旧认证页、旧标签栏、旧常量和未注册的旧功能页已经移除。不要重新创建历史壳，也不要把已归档页面加入主路由。

## 服务归属

- `common/services/`：preferences 持久化、认证（`AuthService` 门面：Supabase/沙盒双 Provider，按 `CloudEnvironment` 探测切换）、会话 token、用户资料、稳定的计划/训练 API。
- `shared/services/`：内容目录、计划引擎、首页/回顾派生数据、云同步（`CloudSyncService` 决策内核 + Supabase/沙盒快照存储）、备份、内存仓库和持久化降级组合。
- 认证与云同步的运行模式：`CloudEnvironment` 探测 rawfile 中的 `supabase.json`（存在 → Supabase 真实链路；缺失 → 沙盒降级、UI 明示演示模式）。Android 端等价配置由 `local.properties` 经 BuildConfig（`SUPABASE_URL` / `SUPABASE_PUBLISHABLE_KEY`）注入，缺省空串即云端禁用。ohosTest 经 `AuthSyncTestGate` 强制沙盒，测试不触真实网络。
- `features/workout/services/`：仅放训练功能专属编排，以及新旧训练数据模型之间的兼容桥。

服务均使用模块级 singleton：`export default new ServiceName()`。调用方直接导入默认实例，禁止在页面或服务中再次 `new`。

现有兼容层（尤其 `WorkoutSessionPersistenceBridgeService` 和 `PersistenceFallbackService`）用于保护已有本地训练数据，除非明确完成数据迁移，不要删除或绕过。

## ArkUI / ArkTS 约定

- 页面使用 `@Entry @Component struct`；异步加载放在 `aboutToAppear()`，销毁时清理 timer/listener。
- 导航使用 `this.getUIContext().getRouter()`，路由名只引用 `AppRoutes` 常量。路由参数使用 `getParams()` 时必须显式声明类型并用 `try-catch` 处理缺失参数。
- 系统上下文通过 `getUIContext().getHostContext()` 获取并做空值保护；preferences API 的异步调用必须在成功写入后 `flush()`。
- 通用组件的颜色、字体、间距、圆角优先使用 `common/styles/DesignTokens.ets`；按压/淡入等动效语汇走 `common/styles/MotionIntent.ets`，形态别名走 `DuTokens.ets`，不要在单个组件中散落魔法值（13+ 处手写按压已收敛为该两层）。
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
cd apps/harmony    # 以下命令均须在鸿蒙工程目录下执行（tools/ 随工程下移，仓库根不再有 tools/）
node tools/check-main-pages.mjs
node tools/check-gates.mjs
devecocli build --product default
```

设备回归使用 `apps/harmony/tools/auth-regression.ps1` 或 `apps/harmony/tools/dev-smoke.ps1`；没有设备时至少运行路由检查、静态引用检查和可用的 ArkTS/ohosTest 构建。

## 规范在哪

全部规范载体见 `docs\spec-registry.md`（层级 / 状态 / 适用端 / 自动检查方式）；**口径与术语**见 `docs\glossary.md`（事实口径表、标准词、口径分层规则、GL 机器闸门）。写文档或注释前先确认用词属于哪一层（现行 / 历史 / 平台限定）。

本目录树下的就近约束——进入该目录改代码前**先读那一份**，与本文冲突时以本文（L1）为准：

| 目录 | 约束文件 | 管什么 |
|---|---|---|
| `common\services\` | `CONVENTIONS.md` | 应用级服务清单、singleton / flush / Context 约定 |
| `shared\` | `CONVENTIONS.md` | 跨功能领域逻辑归属 + ANTI-PATTERNS |
| `components\` | `CONVENTIONS.md` | 通用组件约定 + AppButton 厚底规则 |
| `features\workout\pages\` | `CONVENTIONS.md` | 训练页仅保留 2 页，禁建第二套主线 |
| `features\workout\services\` | `CONVENTIONS.md` | 训练编排归属 + ANTI-PATTERNS |

双端同步要求见 `docs\process\dual-platform-parity.md`；测试环境见 `docs\process\test-environments.md`；登录验证见 `docs\process\auth-verification.md`；代码细则（rule id）见 `docs\process\engineering-standards.md`。

## 构建与检查约定

- **HarmonyOS 构建走 `devecocli`**：scaffold/build/run/debug/devices/docs 均通过它，不裸跑 `hvigorw`、不凭训练数据猜 SDK API。
- **构建命令**（两条均实测通过）：default HAP `devecocli build --product default`（`BUILD SUCCESSFUL in 11s`）；ohosTest `devecocli build --modules entry@ohosTest --product default`（`BUILD SUCCESSFUL in 1min`，产物 `entry/build/default/outputs/ohosTest/entry-ohosTest-unsigned.hap`）。模块格式 `--modules <module>@<target>`；`--no-parallel` 由 devecocli 内部管理，不再显式传。对照：裸跑 `hvigorw assembleHap` 的后台任务曾挂起 17min 无产出，终止后 hvigor daemon 残留 `ESRCH` 坏状态，需等其自行恢复才能再次构建。`apps\harmony\tools\*.ps1` 与 `apps\harmony\tools\check-gates.mjs` 内部的历史 `hvigorw` 调用保持原样（改动有回归风险），但**新增流程一律走 `devecocli`**。

## 并行优先原则（2026-09-07 起）

工作量大或重复度高时，先判断能否并行：

1. 拆分成**互不重叠**的子单元（不同文件/不同屏/不同服务）。
2. **单写者纪律**：构建(assembleHap)、装 HAP、设备截图、git 提交只由主会话执行；并行工作单元只编辑各自文件并本地静态自洽。
3. 同文件、同设备、有数据依赖的任务不并行（会互相覆盖/串行化），显式说明原因。
4. 并行批次后统一编译 + 验收，达标才合并/提交。

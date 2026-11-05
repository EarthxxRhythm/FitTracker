# HarmonyOS 端依赖图与越界审计台账

> **范围**：`apps/harmony/entry/src/main/ets`（139 个 `.ets`，41632 行）
> **基线**：`master@23abd74`；仓库工作树另有用户未提交改动 `apps/harmony/build-profile.json5`（未触碰）
> **性质**：只读审计。**本台账未修改任何源码**。
> **采集方式**：机械 `grep -rn` 穷举 + 复用仓库门禁 `apps/harmony/tools/check-code-rules.mjs` 的导出函数（`collectEtsFiles` / `collectInlineColors`），非人工抽样。
> **单位约定（回应「计数口径不一」挑战）**：所有越界条目统一报 **import 行数**，并附 **涉及文件数**。理由见 §5.4。

---

## 0. 结论摘要

| 维度 | 实测 | 预设数字 | 判定 |
|---|---|---|---|
| `shared/` → `features/` 越界 | **3 行 / 3 文件** | 3 | ✅ 吻合，但**全部是已注册门禁豁免**，属冻结基线而非待修缺陷 |
| `common/` → `shared/` 越界 | **4 行 / 1 文件** | 4 | ⚠️ 数字吻合但**口径不同**（处=import 行 ≠ 处=文件）；且**无门禁覆盖** |
| 内联色值 | **37 行命中**（门禁 DS-01 口径）／baseline **38 条** | 38 | ⚠️ `38` 是 **baseline 条目数**，实测命中 37 —— 差 1 条陈旧条目 |
| 内联色值（扩展口径） | **111 行 / 136 处 / 104 个不同值** | — | 预设 38 严重低估真实表面（见 §2） |
| 无门禁覆盖的新越界 | **`shared/` → `app/` 7 行 / 7 文件** | 未预设 | 🔴 **本次审计最大发现**，此前无人登记 |

**门禁现状（实测）**：
```
cd apps/harmony && node tools/check-code-rules.mjs
[code-rules] 7 条规则、19 个注册页、20 个路由常量、139 个 .ets 文件、4 条豁免、37 处色值在基线内 —— 全部通过
```
即：现存越界**全部已被门禁合法化**（豁免或基线），但门禁的规则集只覆盖 `→features` 一个方向（AR-01/02/03，`tools/check-code-rules.mjs:242-246`），`→app` 方向完全裸奔。

---

## 1. 越界依赖台账

### 1.1 `shared/` → `features/`（3 行 / 3 文件）— 禁动

| file:line | 目标 | 问题类型 | 影响面 | 优先级 |
|---|---|---|---|---|
| `shared/services/AccountDataLifecycle.ets:14` | `features/workout/services/WorkoutSessionPersistenceBridgeService` | 层次倒置（下层依赖上层） | 账号数据生命周期 | — 禁动 |
| `shared/services/DeviceSeedService.ets:17` | 同上 | 层次倒置 | 设备种子数据 | — 禁动 |
| `shared/services/UserDataBackupService.ets:10` | 同上 | 层次倒置 | 备份包完整性 | — 禁动 |

**禁动依据（file:line）**：
- `apps/harmony/tools/check-code-rules.mjs:39-59` —— `EXEMPTIONS` 中三条 `AR-02` 豁免逐条对应上述三个文件，`reason` 写明「备份须覆盖训练兼容层数据，桥接服务归属 features/workout」「设备种子数据须经兼容层写入，保证旧数据可见」。
- `docs/process/engineering-constraints.md`（L1，「服务归属」）：「现有兼容层（尤其 `WorkoutSessionPersistenceBridgeService` 和 `PersistenceFallbackService`）用于保护已有本地训练数据，除非明确完成数据迁移，不要删除或绕过。」
- 桥接服务实体：`features/workout/services/WorkoutSessionPersistenceBridgeService.ets:8`（类声明）~`:221`（`export default new WorkoutSessionPersistenceBridgeService()`），221 行，内部同时依赖 `shared/models`、`shared/services`、`common/services`（`:5-12`）。

> **回应挑战「WorkoutSessionPersistenceBridgeService 落点未确认」**：**已确认**，落点 `features/workout/services/WorkoutSessionPersistenceBridgeService.ets`，类体 `:8`，默认导出 `:221`。耦合 `PersistenceFallbackService` = `shared/services/PersistenceFallbackService.ets:16`（类）/`:102`（导出），与 bridge **不在同一层、不构成同一兼容层**——两者是并列的两套兼容机制，禁动清单必须双列（见 §4）。

**结论**：这 3 行不是「待修越界」，是**已批准的冻结基线**。任何「清理越界依赖」的重构若动到它们，会连带打断备份/种子/账号清理三条数据链路，且门禁会转红。

---

### 1.2 `common/` → `shared/`（4 行 / 1 文件）— 可安全重构（有前置条件）

| file:line | 目标 | 问题类型 | 影响面 | 优先级 |
|---|---|---|---|---|
| `common/services/TrainingPlanService.ets:10` | `shared/services/GoalRepository` | 层次倒置 | 计划/目标读取 | P2 |
| `common/services/TrainingPlanService.ets:11` | `shared/services/PlanEngine` | 层次倒置 | 计划生成 | P2 |
| `common/services/TrainingPlanService.ets:12` | `shared/services/ContentRepository` | 层次倒置 | 内容目录 | P2 |
| `common/services/TrainingPlanService.ets:13` | `shared/services/HomePlanService` | 层次倒置 | 首页计划派生 | P2 |

**现状**：`common/` 被 L1 定义为「稳定服务」，`shared/` 是「跨功能派生层」，`common → shared` 方向与 `shared/CONVENTIONS.md` 声明的分层意向相反，但**门禁 AR-01/02/03 不覆盖此方向**（只 forbid `features/`），所以长期无人发现。

**唯一实际调用点**：`common/services/TrainingPlanService.ets:753` —— `const generatedPlan = PlanEngine.generatePlan(goal)`，即 `common` 层里只有「预置计划服务」一处回指 `shared` 的计划引擎。

**可安全重构判据**：把计划生成编排从 `common/services/TrainingPlanService.ets` 上移到 `shared/services/`，即可消除 4 行全部越界。但 `TrainingPlanService` 有 813 行、含 4 套预置计划数据（`:98` 起 `PRESET_PLANS`）+ 4 个导出的纯函数（`:279 resolveTodayTrainingIndex`、`:298 planHasAnyWeekdayInfo`、`:324 resolveTodayTrainingIndexForPlan`、`:340 resolveDayDistance`），被 `features/pencil/components/` 下至少 3 个文件导入（`PlansContent.ets:6`、`PlanTabModel.ets:16`、`PlanGroupDetailContent.ets:147`）。
→ **重构可行但非零风险**：需同步迁移 4 个纯函数与 `PresetPlan`/`UserPlan`/`TrainingDay`/`ExerciseRef` 接口（`:15/:22/:28/:38`）。**P2，须独立排期，不得与色值清理同批**。

---

### 1.3 `shared/` → `app/`（7 行 / 7 文件）— 🔴 可安全重构，优先级最高

| file:line | 目标 | 问题类型 | 影响面 | 优先级 |
|---|---|---|---|---|
| `shared/services/GoalRepository.ets:7` | `app/AppState`（`FitTrackerStores`） | 反向依赖启动层 | 目标仓储 | **P1** |
| `shared/services/SyncService.ets:8` | `app/AppState` | 反向依赖启动层 | 同步状态 | **P1** |
| `shared/services/BodyMeasurementService.ets:11` | `app/AppState` | 反向依赖启动层 | 身体测量 | **P1** |
| `shared/services/BodyRecordService.ets:12` | `app/AppState` | 反向依赖启动层 | 身体记录 | **P1** |
| `shared/services/CloudSyncService.ets:15` | `app/AppState` | 反向依赖启动层 | 云同步决策内核 | **P1** |
| `shared/services/HomePlanService.ets:17` | `app/AppRoutes` | 反向依赖路由层 | 首页计划 | P2 |
| `shared/services/WorkoutPreviewService.ets:13` | `app/AppRoutes` | 反向依赖路由层 | 训练预览 | P2 |

**为什么这是最高优先级**：
1. **零门禁覆盖**——`tools/check-code-rules.mjs:242-246` 的 `LAYERS` 只有三条 `→features` 规则，`→app` 不在任何规则/基线/豁免内，属「合法但无人知」。
2. **破坏可测性**——`app/AppState.ets` 是 UI 层 store singleton，`shared` 层服务直接读它，导致这些服务无法脱离 Stage 运行时单测。对比：`shared/services/PersistenceFallbackService.ets`（零 store 依赖）有独立 `PersistenceFallbackService.test.ets`，而上述 5 个 store 依赖服务无。
3. **闭环风险**——`app/PencilAppShell.ets` 已 `import` 了 `features/pencil/components/HomeContent`（`app → features`），而 `shared → app` 存在，构成 `shared → app → features → shared` 环。

**可安全重构方案**：`AppState` 依赖可从「import 直取」改为「注入/回调」（`shared` 层声明 `interface StoreSink`，由 `app` 层在初始化时注入）。`AppRoutes` 两处是路由常量引用，把 `AppRoutes` 下沉到 `common/`（或 `shared/` 内的常量文件）成本更低、风险更小——**建议先做这两处，后做 5 处 store 注入**。

**`AppRoutes` 引用面口径（tq-a4 实测更正，覆盖草稿的「17 行 / 17 文件」）**：

全仓 `grep -rn "from '.*AppRoutes'"` 实测 **main 17 + test 7 = 24** 个消费点：

| 区段 | 命中 | 消费点 | 说明 |
|---|---|---|---|
| `entry/src/main/ets` | 18 行 / 18 文件 | **17** | 多出的 1 行是 `app/AppRoutes.ets` 自身的 re-export（`export { AppRoutes } from '../common/AppRoutes'`），不计入消费面 |
| `entry/src/test` | 1 行 / 1 文件 | **1** | `TargetLoopSkeleton.test.ets:7` |
| `entry/src/ohosTest/ets/test` | 6 行 / 6 文件 | **6** | `TargetLoopFlow.test.ets:2`、`AuthSessionFlow.test.ets:9`、`AuthRoutingFlow.test.ets:9`、`StartupRouting.test.ets:2`、`PersistenceFallbackService.test.ets:4`、`WorkoutPreviewService.test.ets:2` |
| **合计** | 25 行 | **24** | main 17 + test 7 |

**为什么必须写清这 7 处**：下沉采用「`app/AppRoutes.ets` 保留为兼容 re-export 壳」方案时，这 7 处测试 import **无需改动**（说明符仍指向 `app/AppRoutes`，由壳转发到 `common/AppRoutes`）。但它同时是**壳不可删除的硬约束**——任何「彻底删除 `app/AppRoutes.ets` 门面」的后续波次必须先改这 7 处，否则 `test` / `ohosTest` 编译立刻失败。只按「17」记账会把这条约束丢掉。

**`mod-routes-sink` 验收判据增补（tq-a4）**：除下列两条既有判据外——① `grep -rn "from '.*/app/AppRoutes'" apps/harmony/entry/src/main/ets/shared/` 命中数 2 → 0（基线 `HomePlanService.ets:17`、`WorkoutPreviewService.ets:13`）；② `cd apps/harmony && node tools/check-code-rules.mjs` 绿且「20 个路由常量」不变——须**额外**验证一条：

> **re-export 后 `ohosTest` 与 `test` 目录 import 路径不变且 build 通过**——即 `entry/src/test/TargetLoopSkeleton.test.ets` 与 `entry/src/ohosTest/ets/test/` 下 6 个文件的 `AppRoutes` import 说明符保持指向 `app/AppRoutes`（不改写为 `common/AppRoutes`），且编译通过。

判据形态：`grep -rn "from '.*AppRoutes'" apps/harmony/entry/src/test apps/harmony/entry/src/ohosTest` 仍为 7 行（路径不变）+ 一次真实 build 退出码 0。

---

### 1.4 `features/` → `features/`（5 行 / 5 文件）— 禁动

| file:line | 目标 | 问题类型 | 影响面 | 优先级 |
|---|---|---|---|---|
| `features/pencil/components/PlanGroupDetailContent.ets:15` | `features/workout/services/WorkoutSessionPersistenceBridgeService` | 跨 feature 耦合 | 计划组详情 | — 禁动 |
| `features/pencil/components/ReviewContent.ets:7` | 同上 | 跨 feature 耦合 | 回顾页 | — 禁动 |
| `features/pencil/components/states/HomeState.ets:22` | 同上 | 跨 feature 耦合 | 首页状态 | — 禁动 |
| `features/pencil/components/states/ProfileState.ets:23` | 同上 | 跨 feature 耦合 | 个人页状态 | — 禁动 |
| `features/workout/pages/WorkoutCompletePage.ets:8` | 同上（经 `../../../features/workout/services/` 绕行） | 跨 feature + 路径异味 | 训练完成页 | 路径**可安全重构**；依赖不可动 |

**拆分判定**：
- **依赖本身禁动**（同 §1.1，兼容层）。
- 但 `features/workout/pages/WorkoutCompletePage.ets:8` 的**说明符写法** `'../../../features/workout/services/...'` 是自层绕行（从 `features/workout/pages/` 上跳 3 级再折回同目录），应改为 `'../services/WorkoutSessionPersistenceBridgeService'`（自 `features/workout/pages/` 上跳 1 级即 `features/workout/services/`；曾误写为 `'../../services/...'`，该写法会解析到**不存在**的 `features/services/`，照抄即编译失败）。**纯路径改写，零语义变化，可安全重构**。〔Wave 1 复核：源码 `:8` 已按本行修正，台账同步校正〕

---

### 1.5 已证无越界的方向（正向确认，供下游排除）

| 方向 | 实测 | 依据 |
|---|---|---|
| `common/` → `features/` | **0** | 唯一命中 `common/styles/PrototypeTokens.ets:26` 是文档注释，非 import |
| `common/` → `components/` | **0** | 无命中 |
| `components/` → 非 `common/` | **0** | `components/` 全部 10 个文件的 import 只指向 `common/styles/*` 与 `common/utils/SegmentGeometry`（`components/SegmentedPill.ets:37`） |
| `features/` → `components/` | 7 行 / 合法 | 复用组件是设计意图 |
| `features/` → `common/` / `shared/` | 101 行 / 51 行 | 合法向下依赖 |
| `features/` → `app/` | 16 行 | 合法（取 store / 路由常量） |

---

## 2. 内联色值：38 与 37 的差额已定位

### 2.1 两套口径必须分开报，否则会污染重构排期

| 口径 | 定义 | 实测 |
|---|---|---|
| **门禁 DS-01 口径** | `/(?:backgroundColor\|fontColor\|borderColor\|fillColor\|strokeColor\|linearGradient)\(\s*'(#[0-9A-Fa-f]{6,8})'/`，即**属性方法实参位置的裸字面量**；`const X: string = '#...'` 命名常量**放行**（`tools/check-code-rules.mjs:275-291`） | **37 行命中** |
| **扩展口径** | 任意非注释行上的 `'#RRGGBB'`/`'#AARRGGBB'` 字面量，含命名常量、渐变数组、三元分支 | **111 行 / 136 处 / 104 个不同值** |

### 2.2 `38` 的真相 —— 它是 baseline 条目数，不是当前违规数

- `apps/harmony/tools/code-rules-baseline.json`：`entries.length === 38`（实测）。
- 当前 DS-01 命中：**37**。
- 差额 **1 条**，已定位到具体条目：

```
STALE BASELINE: features/pencil/components/ReviewContent.ets|#9E040608  baseline=2  current=1
```

即 `ReviewContent.ets` 里 `#9E040608` 曾出现 2 次，现存 1 次（`:2547`），baseline 未随之收敛。

> **回应挑战「38/3/4 预设数字来源」**：**来源查明，均为可复现的既有事实，但不是「待修数量」**：
> - `38` = `code-rules-baseline.json` 条目数（技术债台账的存量条目，只允许缩小）。
> - `3` = `EXEMPTIONS` 中三条 `AR-02` 豁免对应的文件数（`tools/check-code-rules.mjs:44-59`）。
> - `4` = `common/services/TrainingPlanService.ets` 的 4 条 import 行（单文件）。
> 三组数字都是**已登记的存量**，把它们当「待修目标」会让审计去「修已批准的东西」。本台账一律以实测为下限，并对账偏差。

### 2.3 37 行 DS-01 命中的归属（全量，file:line）

按层：`features/` 33 行 · `app/` 2 行 · 其余 2 行。

| file:line | 值 | 收敛难度 |
|---|---|---|
| `app/PencilAppShell.ets:595` | `#000000` | ⚠️ 语义不明（可能是占位透明层），需先确认意图 |
| `app/PencilAppShell.ets:627` | `#0B0F13` | 可安全重构（与 `EntryAbility.ets:25/26` 同值，应提 token） |
| `features/body/components/BodyDataContent.ets:1288` | `#06FFFFFF` | 可安全重构 |
| `features/pencil/components/ActiveContent.ets:1544` | `#06FFFFFF` | 与上行同值 → 应合并为一个 token |
| `features/pencil/components/ActiveContent.ets:1627` | `#FA0A0D12` | 与 `PencilAppShell.ets:23` `RESUME_BAR_SURFACE` 同值 → 应委托该常量 |
| `features/pencil/components/ActiveContent.ets:1733` | `#13161A` | 可安全重构 |
| `features/pencil/components/PlanContent.ets:211` | `#2450ECA7` | 可安全重构（ACCENT 的 alpha 变体，PrototypeTokens 已有 `ACCENT_A10`，需补 `ACCENT_A14`） |
| `features/pencil/components/PlanContent.ets:266` | `#13171A` | 可安全重构 |
| `features/pencil/components/PlanContent.ets:375` | `#000000` | ⚠️ 同上，需确认语义 |
| `features/pencil/components/PlanGroupDetailContent.ets:391` | `#F00D1117` | 可安全重构（与 `SettingsContent.ets:484` 同值） |
| `features/pencil/components/PlanGroupDetailContent.ets:470` | `#D10A0D12` | 可安全重构（与 `LegalDocPage.ets:153` 同值） |
| `features/pencil/components/PlanGroupDetailContent.ets:505` | `#2450ECA7` | 与 `PlanContent.ets:211` 同值 |
| `features/pencil/components/PlanGroupDetailContent.ets:575` | `#151D1B` | 可安全重构 |
| `features/pencil/components/PlanGroupDetailContent.ets:726` | `#151B20` | 与 `PlansContent.ets:303` 同值 |
| `features/pencil/components/PlanGroupDetailContent.ets:790` | `#EB0A0D12` | 可安全重构 |
| `features/pencil/components/PlansContent.ets:244` | `#1450ECA7` | 可安全重构 |
| `features/pencil/components/PlansContent.ets:303` | `#151B20` | 同上 |
| `features/pencil/components/ProfileContent.ets:304` | `#9EFFFFFF` | 与 `ReviewContent.ets:103` `REVIEW_LABEL2` 同值 → 跨 feature 同值，应提公共 token |
| `features/pencil/components/ProfileEditContent.ets:1150` | `#E61A201E` | 可安全重构 |
| `features/pencil/components/ReviewContent.ets:2204` | `#20272F` | 可安全重构 |
| `features/pencil/components/ReviewContent.ets:2547` | `#9E040608` | 可安全重构（并同步删 baseline 陈旧条目） |
| `features/pencil/pages/PencilLoginPage.ets:346` | `#A6FFFFFF` | 与 `PencilRegisterPage.ets:463` 同值 |
| `features/pencil/pages/PencilLoginPage.ets:363` | `#14D3B487` | 与 `PencilRegisterPage.ets:224` 同值 |
| `features/pencil/pages/PencilRegisterPage.ets:224` | `#14D3B487` | 同上 |
| `features/pencil/pages/PencilRegisterPage.ets:463` | `#A6FFFFFF` | 同上 |
| `features/pencil/pages/PencilRegisterPage.ets:557` | `#FFD7C5` | 可安全重构 |
| `features/pencil/pages/PencilSplashPage.ets:52` | `#0F50ECA7` | 可安全重构 |
| `features/pencil/pages/PencilSplashPage.ets:98` | `#F5F7FA` | 可安全重构 |
| `features/pencil/pages/PencilSplashPage.ets:107` | `#AAB4BF` | 可安全重构 |
| `features/pencil/pages/PencilSplashPage.ets:194` | `#6F7C87` | 可安全重构 |
| `features/pencil/pages/PencilSplashPage.ets:203` | `#090C11` | 可安全重构（同值见 `PencilSplashPage.ets:160` 渐变尾色） |
| `features/settings/components/SettingsContent.ets:484` | `#F00D1117` | 同上 |
| `features/settings/pages/LegalDocPage.ets:91` | `#C9FFFFFF` | 可安全重构 |
| `features/settings/pages/LegalDocPage.ets:153` | `#D10A0D12` | 同上 |
| `features/workout/pages/WorkoutCompletePage.ets:474` | `#B8FFFFFF` | 可安全重构 |

> 完整 37 行原始清单可用 `node .rivet/scratch/ds01.mjs` 复现（探针已按纪律清理，见 §6）。

### 2.4 扩展口径 111 行 / 136 处的归属（门禁看不到的那 74 行）

| file | 行数 | 主要形态 | 判定 |
|---|---|---|---|
| `features/pencil/components/ReviewContent.ets` | 17（`:86-108` 共 12 条命名常量 + `:2204/:2330/:2547/:2575`） | `const X: string = '#...'` + 图表调色板数组 | **部分禁动**：`:86-95` 是回顾图表的**数据色阶**（`BALANCE_FILLS` / `FATIGUE_FILLS` / `STRENGTH_FILLS` / `SILHOUETTE_FILL`），与 Android 端图表配色对等，迁移前须先跑 `check-parity` |
| `features/pencil/components/PlanGroupDetailContent.ets` | 11 | 属性实参 + 三元分支 | 可安全重构 |
| `features/pencil/pages/PencilSplashPage.ets` | 9 | 属性实参 + 渐变数组 | 可安全重构 |
| `features/pencil/pages/PencilRegisterPage.ets` | 8 | 属性实参 + 渐变 | 可安全重构 |
| `features/pencil/components/ActiveContent.ets` | 8 | 属性实参 + 命名常量 | 可安全重构 |
| `features/pencil/components/PlansContent.ets` | 6 | 属性实参 | 可安全重构 |
| `features/pencil/components/PlanContent.ets` | 6 | 属性实参 | 可安全重构 |
| `features/settings/components/SettingsContent.ets` | 5 | 三元分支 | 可安全重构 |
| `features/pencil/pages/PencilLoginPage.ets` | 5 | 三元分支 | 可安全重构 |
| `features/pencil/components/HomeContent.ets` | 5 | 属性实参 + 渐变 | 可安全重构 |
| `features/pencil/components/AvatarTint.ets` | 5（`:20/:23/:26/:29/:32`，每行 3 个值） | 头像色调三元组（fill/text/border） | **可安全重构**——这是最典型的 token 化候选，5 组 × 3 值 = 15 个字面量，全在一个 `return { fill, text, border }` 对象里 |
| `app/PencilAppShell.ets` | 5 | 命名常量 + 属性实参 | 见 §2.3 |
| `common/services/TrainingPlanService.ets` | 4（`:102 #43A047` / `:142 #FB8C00` / `:175 #1E88E5` / `:215 #E53935`） | **预置计划数据字段**（`mkPlan(id, name, color, ...)` 的第 3 参） | 🔴 **禁动**——这是**数据**不是主题：4 套预置计划的品牌色随计划一起入库/同步/备份，改值会改变已存用户数据的语义，且须与 Android 端 `PRESET_PLANS` 同步（跑 `check-parity` 前置） |
| `features/pencil/pages/PencilPreviewPage.ets` | 3 | 三元分支 | 可安全重构 |
| `features/pencil/components/ProfileContent.ets` | 3 | 属性实参 + 三元 | 可安全重构 |
| `features/settings/pages/LegalDocPage.ets` | 2 | 属性实参 | 可安全重构 |
| `features/pencil/components/WeightRecordDialog.ets` | 2（`:35 SCRIM_COLOR` / `:37 CARD_FILL`） | 命名常量 | 可安全重构 |
| `entryability/EntryAbility.ets` | 2（`:25/:26`，`statusBarColor` / `navigationBarColor`） | 系统栏色 | **禁动**——Ability 生命周期上下文早于 UI，取 `DesignTokens` 会引入启动期依赖；建议保留但加注释指向 token |
| `features/workout/pages/WorkoutCompletePage.ets` | 1 | 属性实参 | 可安全重构 |
| `features/welcome/pages/PencilWelcomePage.ets` | 1（`:160`） | `shadow` color | 可安全重构（同文件 `:22-25/:76/:207` 的 hex 是注释，已排除） |
| `features/pencil/components/ProfileEditContent.ets` | 1 | 属性实参 | 可安全重构 |
| `features/exercise/pages/ExerciseLibraryPage.ets` | 1（`:36 SHEET_BG`） | 静态命名常量 | 可安全重构 |
| `features/body/components/BodyDataContent.ets` | 1 | 属性实参 | 可安全重构 |

**重复值 Top（合并即收益）**：`#2F6655`×3 · `#13161A`×3 · `#0B0F13`×3 · `#FFFFFF`×2 · `#FA0A0D12`×2 · `#F0A48A`×2 · `#F00D1117`×2 · `#E5B878`×2 · `#D10A0D12`×2 · `#A6FFFFFF`×2 · `#8850ECA7`×2 · `#49C48F`×2 · `#45C18D`×2 · `#429B77`×2 · `#3B9572`×2 · `#3A705E`×2 · `#33000000`×2 · `#2EFFFFFF`×2 · `#26D3B487`×2 · `#2450ECA7`×2

---

## 3. 重复实现点

### 3.1 双 `WorkoutSession` 数据模型 — 禁动

| file:line | 定义 | 角色 |
|---|---|---|
| `shared/models/TrainingModels.ets:88` | `export interface WorkoutSession` | 新模型（云同步/备份/桥接的目标形状） |
| `common/services/WorkoutSessionService.ets:26` | `export interface WorkoutSession`（调用侧别名为 `LegacyWorkoutSession`） | 旧模型（preferences 持久化形状） |
| `common/services/WorkoutSessionService.ets:14` | `export interface SavedSet` | 旧集合模型 |
| `common/services/WorkoutSessionService.ets:20` | `export interface SavedExercise` | 旧动作模型 |

**禁动依据**：L1 明示 `WorkoutSessionPersistenceBridgeService` 用于保护已有本地训练数据。桥接服务 `features/workout/services/WorkoutSessionPersistenceBridgeService.ets:5-10` 的双重 import 就是这个映射的物理位置（同时引入 `shared/models` 的新类型与 `common/services/WorkoutSessionService` 的 `SavedExercise/SavedSet/WorkoutSession as LegacyWorkoutSession`）。
**这不是「重复」，是迁移未完成的必然形态**——任何「统一模型」的重构都必须先有数据迁移方案。

### 3.2 动作库数据双源 — 禁动（测试契约锁定）

| file:line | 内容 | 生产调用方 |
|---|---|---|
| `common/services/ExerciseService.ets:95`（类）/`:153`（导出） | 内联动作种子（`:42-62` 起 `e1..e20` 硬编码 `mkExercise`） | **0** |
| `generated/LocalExerciseContent.ets:2` | 从 JSONL 生成的动作/器械/肌群全量数据（2271 行） | `shared/services/JsonlSeedContentDataSource.ets:6`、`generated/LocalContentSyncPackage.ets:6` |
| `shared/services/ContentRepository.ets`（648 行） | 运行时动作库读取 | `features/exercise/pages/ExerciseLibraryPage.ets:13`、桥接服务 `:7` 等 |

**证据**：`grep -rn "ExerciseService" entry/src/main/ets` 的全部命中只有 `ExerciseService.ets` 自身 3 行 + `FavoriteExerciseService.ets`（另一服务，2 行）+ `ExerciseLibraryPage.ets` 里对 **`FavoriteExerciseService`** 的 5 行调用。**无任何文件 import `ExerciseService`**。
**但禁动**：`apps/harmony/entry/src/ohosTest/ets/test/ExerciseService.test.ets` 与 `apps/harmony/entry/src/test/ExerciseService.test.ets` 均存在。删除须同时改测试契约并走决策，不属「可安全重构」。

### 3.3 计划生成双入口 — 部分可安全重构

| file:line | 角色 |
|---|---|
| `shared/services/PlanEngine.ets:47`（`class PlanEngineImpl`）/`:308`（导出） | 目标驱动生成（`generatePlan(goal)`），308 行 |
| `common/services/TrainingPlanService.ets:753` | **转发** `PlanEngine.generatePlan(goal)` |
| `common/services/TrainingPlanService.ets:99-278` | `PRESET_PLANS` 4 套预置计划（二/三/四/五分化的静态数据） |
| `common/services/TrainingPlanService.ets:279/298/324/340` | 4 个计划解析纯函数 |

`generatePlan` 全仓 7 处命中，调用者横跨 `features/pencil/components/states/HomeState.ets:126`、`states/PlanState.ets:89`、`pages/PencilPreviewPage.ets:124`、`shared/services/GoalAdjustmentPreviewService.ets:144`、`shared/services/ReviewDashboardService.ets:296`；其中 `features/` 层**绕过 `TrainingPlanService` 直接 import `PlanEngine`**（4 处，`HomeState.ets:20`、`PlanState.ets:13`、`PencilPreviewPage.ets:18`、`PlanTabModel.ets` 注释）。

**判定**：`PlanEngine`（目标生成）与 `TrainingPlanService`（预置计划）**职责可切分，不是重复实现**——但 `features/` 绕过 `common` 直接取 `shared`，使「计划」这一域有两个公开入口，属**边界模糊**（见 §4.3）。统一入口是 P2 重构，非禁动。

### 3.4 肌肉配色双份 — 可安全重构

| file:line | 内容 |
|---|---|
| `common/services/TrainingPlanService.ets:102/142/175/215` | 4 套预置计划的 `color` 字段（数据） |
| `common/styles/DesignTokens.ets:603` | `class MuscleColorMap` + `:600` `static getColor(muscle)` 按肌群返回 `ColorTokens.MUSCLE_*` |

两者语义不同（计划品牌色 vs 肌群分类色），**非重复**。但 `common/styles/DesignTokens.ets:603-612` 已把肌群配色 token 化，而预置计划色仍裸写在服务里——建议加注释区分，**不改值**（跨端对等）。

### 3.5 已证无重复：`Review*` 家族

`ReviewService`（`shared/services/ReviewService.ets:8` / `:42`，算式内核：`calculateCompletionRate` / `calculateVolume`）被 `ReviewDashboardService.ets:95/149/211/212/343/348` 与 `ReviewInsightsService.ets:368/433` 复用。**组合关系，不是重复实现**。`StatsDashboardService.ets:88` 与 `ReviewDashboardService.ets:75` 名字相近但分别服务不同视图，无共享逻辑重叠。

---

## 4. 边界模糊文件

### 4.1 零生产调用方、被 `ohosTest` 锁定的四个服务 — 全部禁动

| file:line | 行数 | 生产调用方 | 测试契约 | 判定 |
|---|---|---|---|---|
| `common/services/ExerciseService.ets:95` | 153 | **0** | `entry/src/ohosTest/ets/test/ExerciseService.test.ets`、`entry/src/test/ExerciseService.test.ets` | 禁动（测试契约） |
| `features/workout/services/WorkoutSessionEditService.ets:49` | 358 | **0** | `ohosTest/ets/test/WorkoutSessionEditService.test.ets` | 禁动（测试契约） |
| `shared/services/StartupContentSyncService.ets:12` | 42 | **0** | `ohosTest/ets/test/StartupContentSyncFlow.test.ets` | 禁动（测试契约） |
| `shared/services/PersistenceFallbackService.ets:16` | 102 | **0** | `ohosTest/ets/test/PersistenceFallbackService.test.ets` | 🔴 禁动（L1 明示兼容层 **且** 测试契约） |

> **这是本次审计最容易踩的坑**：「零 import」看起来像死代码，四个里三个能通过 `grep` 判定为「无调用方」，但**删了会转红**。`docs/process/engineering-constraints.md`「清理规则」已写明：「先查 `main_pages.json`、`AppRoutes.ets`、ArkTS import **和测试引用**，再删除文件」。本台账把测试引用一并落到 file:line。

### 4.2 `mock/SeedPlanRules.ets` 被生产代码引用 — 可安全重构

`mock/SeedPlanRules.ets:35`（`export const SEED_PLAN_RULES: PlanRule[]`）被 `shared/services/PlanEngine.ets:6` import，并在 `:90-96` 作为生产逻辑的分支数据。
**问题**：目录名 `mock/` 暗示测试替身，实际是**生产规则表**。这会让「清理 mock」类重构误删生产依赖（`check-dead-refs.mjs` 拦不住这种语义误判）。
**可安全重构**：迁移到 `shared/services/PlanRuleCatalog.ets`（或 `shared/models/`），并同步 `PlanEngine.ets:6` 的说明符。**纯移动 + 改 import，零逻辑变更**。

### 4.3 `common/services/TrainingPlanService.ets`（813 行）— 层次脏，P2

单文件同时承载三类职责：静态数据（`:99-278` `PRESET_PLANS`）、纯函数（`:279/298/324/340`）、编排（`:370 class` / `:753` 委托 `shared.PlanEngine`）。它是 §1.2 那 4 行越界的**唯一来源**。
**可安全重构但需整体搬迁**，不是删几行能解决的。建议拆为 `shared/services/PresetPlanRepository.ets`（数据）+ `shared/services/PlanResolver.ets`（4 个纯函数）+ 保留 `common` 侧的薄门面。

### 4.4 `features/workout/pages/WorkoutCompletePage.ets:8` — 路径异味，可安全重构

说明符 `'../../../features/workout/services/WorkoutSessionPersistenceBridgeService'` 从 `features/workout/pages/` 上跳 3 级到 `ets/` 再折回。应为 `'../services/WorkoutSessionPersistenceBridgeService'`（`../` 即 `features/workout/services/`；曾误写为 `'../../services/...'`，会解析到不存在的 `features/services/`）。**纯路径改写**。〔Wave 1 复核：源码 `:8` 现状即此修正后形态〕

### 4.5 `generated/` 的双向引用

`generated/LocalExerciseContent.ets` 被 `shared/services/JsonlSeedContentDataSource.ets:6` 与 `generated/LocalContentSyncPackage.ets:6` 引用；`shared/services/ContentDatabaseService.ets:22` 与 `shared/services/SyncService.ets:24` 又引用 `generated/LocalContentSyncPackage`。`generated/` 是构建产物区，**禁动**（重新生成会覆盖手改，且它是内容同步的唯一真源）。

---

## 5. 暂缓项处置

| # | 挑战 | 处置 |
|---|---|---|
| 1 | 38/3/4 三组预设数字的来源 | **采纳**。已查明全部来源并逐项对账（§0、§2.2）：`38`=baseline 条目数，`3`=`EXEMPTIONS` 中 AR-02 豁免文件数，`4`=单文件 import 行数。台账以实测为下限，偏差已记录。**另发现 `38` 与实测 `37` 差 1 条陈旧 baseline**（`ReviewContent.ets\|#9E040608`）。 |
| 2 | `WorkoutSessionPersistenceBridgeService` 落点未确认 | **采纳**。已定位 `features/workout/services/WorkoutSessionPersistenceBridgeService.ets:8`（类）/`:221`（导出）；`PersistenceFallbackService` 另落 `shared/services/PersistenceFallbackService.ets:16/:102`。禁动清单双列（§1.1、§4.1）。 |
| 3 | 禁动项是否也需填「问题类型/影响面/优先级」 | **采纳**。本文全部条目统一填三字段；禁动项额外附 `file:line` 依据（§1.1 依据段、§3.1/§3.2/§4.1 各自标注）。优先级统一记 `— 禁动`，避免与 P1/P2 混排被误取。 |
| 4 | 计数单位口径不一（处=文件 vs 处=import 行） | **采纳**。§5.4 定义：**一律报 import 行数 + 文件数**。因此 `shared→features` 记「3 行 / 3 文件」，`common→shared` 记「4 行 / 1 文件」——两者不再可被并排比较为「同为 4 处」。 |
| 5 | 契约基线应为 `contracts/README.md` §0-§7 而非 §1-§6，§7「已知未收敛项」遗漏 | **放弃（不在本任务 scope）**。本任务 scope 为 `apps/harmony/entry/src/main/ets`，契约漂移审计属 `contracts/` 独立任务。本台账只记录鸿蒙侧与契约的接触点（§3.1 双模型）。 |
| 6 | `audit-server-functions` 声称标注 `deploy/migrations` 为禁动区却不打开它们产出 file:line | **放弃（不在本任务 scope）**。属 `server/` 任务。本任务 scope 不含 `server/`、`deploy/`、`migrations/`。 |
| 7 | 高危风险：预设数字诱发确认偏误 | **采纳并执行**：先机械穷举再对账（§0 表格顺序即采集顺序）；`shared→app` 7 行是**预设之外**的新发现，证明穷举未被 3/4/38 锚定。 |
| 8 | 高危风险：密钥明文摘录 | **不适用**。本 scope 不含 `server/` 与 `.env.template`；台账全文只引用 `file:line` + 字段名，不含任何凭据值。 |

---

## 6. 验证与复现

| 项 | 命令 | 结果 |
|---|---|---|
| 门禁基线 | `cd apps/harmony && node tools/check-code-rules.mjs` | exit 0，`37 处色值在基线内 —— 全部通过`，4 条豁免列出 |
| DS-01 复现 | `node .rivet/scratch/ds01.mjs`（本次探针） | `CURRENT HITS 37`；`baseline entries 38`；`STALE: ReviewContent.ets\|#9E040608 baseline=2 current=1`；`UNBASELINED: (none)` |
| 越界穷举 | `grep -rn "from '\.\./\.\./app/"` 等定向 grep（见各节） | 见 §1 |
| 编译 | — | **未执行**。本任务只读审计且未改源码；`build-profile.json5` 已有用户未提交改动，编译状态不可归因于本审计。 |

**未验证边界（须下游知悉）**：
1. 台账「可安全重构」是**基于静态依赖的判定**，未做重构后编译验证——鸿蒙编译需 DevEco Studio + 华为账号授权（L1「门禁任一红即停」），本环境不具备。
2. `.ets` 的 `import` 全量覆盖依赖「顶层 `^import`」正则；动态 `require` 在 ArkTS strict 下被禁（L1），故无遗漏风险，但**未做 AST 级交叉验证**。
3. 内联色值扩展口径用文本正则，可能把非颜色用途的 8 位十六进制串误捕——已人工逐行核对 111 行，未发现误捕；`#000000` 两处（`PencilAppShell.ets:595`、`PlanContent.ets:375`）语义存疑已标注 ⚠️。

---

## 7. 建议排期（按影响面 / 风险）

| 序 | 动作 | 条目数 | 优先级 | 风险 |
|---|---|---|---|---|
| 1 | `AppRoutes` 下沉到 `common/`，消除 `shared→app` 的 2 行（引用面口径：main 17 + test 7 = 24，壳 `app/AppRoutes.ets` 不可删，见 §1.3） | 2 行 | P1 | 低（纯常量搬迁） |
| 2 | 修 `WorkoutCompletePage.ets:8` 自层绕行路径 + `mock/SeedPlanRules.ets` 迁移 | 2 处 | P1 | 低（纯路径/纯移动） |
| 3 | 删 baseline 陈旧条目 `ReviewContent.ets\|#9E040608`（38→37→…只缩不增） | 1 条 | P2 | 极低 |
| 4 | 37 行 DS-01 收敛到 token（按 §2.3「可安全重构」标注，排除 ⚠️ 与禁动） | ~30 行 | P2 | 中（视觉回归需真机核对） |
| 5 | 扩展口径剩余 74 行收敛（`AvatarTint` 15 个值优先，收益最高） | ~74 处 | P3 | 中 |
| 6 | `shared→app` 的 5 处 store 依赖改注入 | 5 行 | P3 | 高（影响同步/备份链路） |
| 7 | `TrainingPlanService` 拆分，消除 `common→shared` 4 行 | 1 文件 | P3 | 高（813 行 + 3 个 feature 调用方） |
| — | **禁动，不排期** | §1.1(3) §1.4(4) §3.1(1) §3.2(1) §4.1(4) §4.5(1) | — | 动即转红或丢数据 |

**本台账未修改任何源码文件。** 探索期临时探针 `.rivet/scratch/*` 已按纪律清理（`a-*.txt` / `b-*.txt` / … / `ds01.mjs` 全部删除），`test_run/module-audit/harmony.md` 为唯一产物。

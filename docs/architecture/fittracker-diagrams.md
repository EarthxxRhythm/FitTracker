# 菲特（FitTracker）系统图集

> 流程图 · 用例图 · 类图 · 序列图
> 生成日期：2026-10-12 ｜ 依据版本：`apps\harmony` @ HEAD `0ff159e`
> 所有图均以仓库当前代码为准，节点旁附 `文件:行号` 锚点；Mermaid 源码可直接渲染（已用 mermaid 11 解析器实测）。

## 0. 范围与依据

| 项 | 说明 |
| --- | --- |
| 图集对象 | `apps\harmony`（HarmonyOS 主线：ArkTS / ArkUI，Stage 模型，单 `entry` 模块） |
| 未覆盖 | `apps\android`（独立的 Kotlin 实现，153 个 `.kt`）与 `apps\harmony` 是同一产品的双端实现，本图集不展开，见 §5 |
| 页面注册真源 | `apps\harmony\entry\src\main\resources\base\profile\main_pages.json`（实为 **19** 项，见 §5） |
| 代码路由真源 | `apps\harmony\entry\src\main\ets\app\AppRoutes.ets` |
| 分层约定 | `features/*`（页面与界面体）→ `shared/services`（跨功能服务）→ `common/services`（稳定基础服务）；服务均为模块级 singleton（`export default new Xxx()`） |

三层依赖方向（单一方向，无反向依赖）：

```mermaid
flowchart LR
  F["features<br/>页面 / 组件"] --> S["shared/services<br/>内容·计划·复盘·备份·云同步"]
  F --> C["common/services<br/>认证·会话·云探测·持久化·设计令牌"]
  S --> C
  C --> P["@kit.ArkData preferences<br/>@kit.CloudFoundationKit / AGC"]
```

---

## 1. 流程图

### 1.1 冷启动分流

依据：`entryability\EntryAbility.ets`、`features\pencil\pages\PencilSplashPage.ets:122`（testMode 判定与分流）、`app\AppState.ets:27`（`StartupDecision.getInitialRoute`）。

```mermaid
flowchart TD
  A["EntryAbility.onWindowStageCreate<br/>EntryAbility.ets"] --> B["loadContent(AppRoutes.STARTUP)<br/>= PencilSplashPage"]
  B --> C{"debug 包且 testMode=sandbox ?<br/>PencilSplashPage.ets:122"}
  C -->|是| C1["CloudEnvironment.setModeForTesting('sandbox')"]
  C -->|否| C2["按真实环境探测"]
  C1 --> D["SessionManager.isLoggedIn(context)<br/>PencilSplashPage.ets:133"]
  C2 --> D
  D -->|未登录| E["replaceUrl(PencilLoginPage)"]
  D -->|已登录| F["replaceUrl(PencilAppShell)"]
  E --> G["登录 / 注册<br/>PencilLoginPage · PencilRegisterPage"]
  G -->|成功| F
  F --> H["底部四 Tab<br/>首页 · 计划 · 复盘 · 个人"]
  H -.->|点击底部训练按钮| I["训练预览全模态<br/>PencilPreviewContent"]
```

> `StartupDecision.getInitialRoute(hasValidSession, hasGoal)` 当前只按登录态分流；`hasGoal` 保留签名但不参与决策（原「训练目标」引导页已移除，无目标场景由首页空态承接）。

### 1.2 训练主流程（预览 → 执行 → 完成）

依据：`app\PencilAppShell.ets:28,173`（`showPreview` 状态与 `PencilPreviewContent` 全模态）、`features\pencil\components\ActiveContent.ets:271`（`finish`）、`:333,364`（`saveCompletedSession` → `WorkoutRepository.saveSession`）、`features\workout\pages\WorkoutCompletePage.ets:79,145`（`triggerCloudSync` / `loadPersistedSessions`）。

```mermaid
flowchart TD
  Home["首页 Tab · HomeContent"] -->|点击训练按钮| Preview["PencilPreviewContent<br/>壳内 bindContentCover 全模态"]
  Preview -->|开始训练| Active["PencilActivePage → ActiveContent<br/>组次录入 · 组间计时"]
  Active -->|"最后一段完成：saveCompletedSession()"| Repo["WorkoutRepository.saveSession()<br/>内存仓库（TrainingModels.WorkoutSession）"]
  Active -->|"finish() → pushUrl"| Complete["WorkoutCompletePage"]
  Complete -->|"aboutToAppear · loadWorkoutStats()"| Bridge["WorkoutSessionPersistenceBridgeService<br/>.loadPersistedSessions()"]
  Bridge --> WSS["WorkoutSessionService<br/>preferences fit_tracker_sessions"]
  Complete -->|"triggerCloudSync()"| Sync["CloudSyncService<br/>.requestBackgroundSync()"]
  Complete -->|继续| Home
```

### 1.3 云同步决策（整包快照）

依据：`shared\services\CloudSyncService.ets:80`（`decideSyncAction`）、`:146`（`syncNow`）、`:325`（`resolveStore`）。

```mermaid
flowchart TD
  S["CloudSyncService.syncNow()"] --> A{"syncInProgress ?"}
  A -->|是| Skip["skipped：同步进行中"]
  A -->|否| B{"SessionManager.getSession()"}
  B -->|null| Un["skipped：未登录"]
  B -->|session| C["buildLocalPayload()<br/>UserDataBackupService.exportPackage + UserProfile"]
  C --> C2["hashPayload()（djb2 规范化摘要）"]
  C2 --> D{"resolveStore()"}
  D -->|null| Fail["failed：云服务未就绪"]
  D -->|store| E["store.pull(userId) → remoteHash / remoteUpdatedAt"]
  E --> F{"decideSyncAction(localHash, remoteHash, baseline, remoteUpdatedAt, lastSyncAt)"}
  F -->|"remoteHash 为空"| Push["push 上行"]
  F -->|"local==baseline 且 remote==baseline"| None["none 已是最新"]
  F -->|"local==baseline 且 remote!=baseline"| Pull["pull 下行应用"]
  F -->|"remote==baseline（仅本地变化）"| Push
  F -->|"双方都变 且 云端更新更晚"| Conflict["conflict_pull 云端优先"]
  F -->|"双方都变 且 云端不更新"| Push
  Push --> Meta["writeMeta(lastSyncedHash = localHash)"]
  Pull --> Meta2["writeMeta(lastSyncedHash = remoteHash)"]
  Conflict --> Meta2
  None --> Meta3["writeMeta(lastSyncedHash = localHash)"]
```

### 1.4 认证/同步后端解析（环境探测 + 降级）

依据：`common\services\CloudEnvironment.ets:58`（`getBackend`）、`:95`（`ensureCloudDatabaseReady`）、`common\services\AuthService.ets:127`（`resolveProvider`）。

```mermaid
flowchart TD
  Init["CloudEnvironment.initialize(context)（幂等）"] --> Forced{"sandboxForced ?<br/>测试注入"}
  Forced -->|是| SB["backend = sandbox"]
  Forced -->|否| Sup{"SupabaseConfig.isConfigured() ?"}
  Sup -->|是| SUP["backend = supabase"]
  Sup -->|否| Agc{"探测到 agconnect-services.json ?"}
  Agc -->|是| AGC["backend = agc"]
  Agc -->|否| SB
  SB --> R["getBackend() 单一真源"]
  SUP --> R
  AGC --> R
  R --> AuthP["AuthService.resolveProvider()"]
  R --> SyncS["CloudSyncService.resolveStore()"]
```

> 优先级：测试强制 sandbox > 显式 Supabase 配置 > 探测到的 AGC > 沙盒兜底。认证与同步两条链路都以 `getBackend()` 为判据。

---

## 2. 用例图

> 说明：Mermaid 无原生用例图，此处以 `flowchart` 的圆形节点表示参与者（Actor）、体育场形节点表示用例（Use Case）。参与关系的依据为 §3 的页面清单与 `AppRoutes.ets` 常量。

```mermaid
flowchart LR
  Visitor((访客))
  User((已登录用户))
  Cloud(["云后端<br/>AGC / Supabase / 沙盒"])

  Visitor --- UC1(["查看欢迎页"])
  Visitor --- UC2(["注册账号"])
  Visitor --- UC3(["手机验证码登录"])
  Visitor --- UC4(["邮箱密码登录"])
  Visitor --- UC5(["第三方登录"])

  User --- UC6(["查看今日训练"])
  User --- UC7(["浏览动作库 / 动作详情"])
  User --- UC8(["训练：预览 → 执行 → 完成"])
  User --- UC9(["训练复盘（历史 · 周趋势 · PR · 肌肉分布）"])
  User --- UC10(["训练计划管理（计划组 / 启用 / 今日计划）"])
  User --- UC11(["身体数据记录"])
  User --- UC12(["备份导出 / 导入"])
  User --- UC13(["账号与云同步"])
  User --- UC14(["设置（单位 · 语言 · 周开始日 · 开关）"])
  User --- UC15(["查看隐私政策 / 用户协议"])

  UC3 -.-> Cloud
  UC4 -.-> Cloud
  UC5 -.-> Cloud
  UC13 -.-> Cloud
  UC8 -.->|训练完成后台同步| Cloud
```

用例 → 页面/服务落点：

| 用例 | 承载页面 | 关键服务 |
| --- | --- | --- |
| 登录 / 注册 | `PencilLoginPage` · `PencilRegisterPage` | `AuthService` → `AuthProvider` |
| 查看今日训练 | `PencilHomePage`（`HomeContent`） | `HomePlanService` · `TrainingPlanService` |
| 训练执行 | `PencilActivePage`（`ActiveContent`） | `ActiveWorkoutService` · `WorkoutRepository` |
| 训练完成 | `WorkoutCompletePage` | `WorkoutSummaryService` · `WorkoutSessionService` |
| 训练复盘 | `PencilReviewPage`（`ReviewContent`） | `ReviewDashboardService` · `ReviewInsightsService` · `PersonalRecordService` |
| 动作库 | `ExerciseLibraryPage` · `ExerciseDetailPage` | `ExerciseService` · `ContentRepository` |
| 身体数据 | `BodyDataPage`（`BodyDataContent`） | — |
| 设置 | `PencilSettingsPage` | `SettingsService` |
| 账号与云同步 | `AccountSyncPage` | `CloudSyncService` · `UserProfileService` |
| 备份 | （设置页入口） | `UserDataBackupService` · `SystemBackupBridgeService` |

---

## 3. 类图

### 3.1 领域模型（`shared\models\TrainingModels.ets`）

```mermaid
classDiagram
  class UserGoal {
    +string goalId
    +string goalType
    +string level
    +number weeklyDays
    +string[] equipmentIds
  }
  class TrainingPlan {
    +string planId
    +string goalId
    +string name
    +number cycleWeeks
    +string status
  }
  class PlanDay {
    +string dayId
    +number dayOfWeek
    +string title
    +string[] focusMuscleIds
  }
  class PlannedExercise {
    +string plannedExerciseId
    +string exerciseId
    +number targetSets
    +string targetReps
  }
  class ExerciseContent {
    +string exerciseId
    +string nameZh
    +string nameEn
    +string[] primaryMuscleIds
    +string[] equipmentIds
    +number contentVersion
  }
  class MuscleGroup {
    +string muscleId
    +string nameZh
    +string region
  }
  class EquipmentItem {
    +string equipmentId
    +string nameZh
  }
  class WorkoutSession {
    +string sessionId
    +string planId
    +string dayId
    +number totalVolume
    +number fatigueScore
  }
  class WorkoutSet {
    +string setId
    +string exerciseId
    +number weight
    +number reps
    +number rpe
    +boolean isWarmup
  }
  class ContentSyncMetadata {
    +number localVersion
    +number lastKnownRemoteVersion
    +string status
  }

  UserGoal "1" --> "*" TrainingPlan : goalId
  TrainingPlan "1" *-- "*" PlanDay
  PlanDay "1" *-- "*" PlannedExercise
  PlannedExercise "*" --> "1" ExerciseContent : exerciseId
  ExerciseContent "*" --> "*" MuscleGroup : primary/secondary
  ExerciseContent "*" --> "*" EquipmentItem
  WorkoutSession "1" *-- "*" WorkoutSet
  WorkoutSet "*" --> "1" ExerciseContent : exerciseId
```

> `TrainingModels.ets` 另提供纯函数 `estimateOneRepMax(weight, reps)`（Epley 公式 `w·(1+reps/30)`，四舍五入两位小数），是 PR 计算的唯一公式来源。

### 3.2 服务分层（按职责簇）

```mermaid
classDiagram
  direction LR
  class AuthService {
    <<singleton>>
    +loginWithPhoneCode()
    +registerWithEmail()
    +logout()
    +getActiveProviderId()
  }
  class SessionManager {
    <<singleton>>
    +saveSession()
    +isLoggedIn()
    +clearSession()
  }
  class CloudEnvironment {
    <<singleton>>
    +initialize()
    +getBackend()
    +ensureCloudDatabaseReady()
  }
  class CloudSyncService {
    <<singleton>>
    +syncNow()
    +onSignIn()
    +requestBackgroundSync()
    +decideSyncAction()
  }
  class ContentRepository {
    <<singleton>>
    +getExerciseLibraryItems()
    +getExerciseDetailViewModel()
    +filterExerciseLibraryItems()
  }
  class ActiveWorkoutService {
    <<singleton>>
    +createState()
    +createCompletedSession()
  }
  class WorkoutSessionService {
    <<singleton>>
    +saveSession()
    +getWeeklyStats()
    +getAllExerciseRecords()
  }
  class TrainingPlanService {
    <<singleton>>
  }
  class PlanEngine {
    <<singleton>>
  }
  class UserDataBackupService {
    <<singleton>>
    +exportPackage()
    +importPackage()
  }
  class ReviewDashboardService {
    <<singleton>>
  }
  class SettingsService {
    <<singleton>>
  }
  class UserProfileService {
    <<singleton>>
  }

  AuthService --> CloudEnvironment
  AuthService --> SessionManager
  CloudSyncService --> CloudEnvironment
  CloudSyncService --> SessionManager
  CloudSyncService --> UserDataBackupService
  CloudSyncService --> UserProfileService
  ActiveWorkoutService ..> WorkoutSessionService
  UserDataBackupService --> TrainingPlanService
  ContentRepository ..> TrainingPlanService
```

### 3.3 认证后端：策略模式（`common\services\auth\`）

```mermaid
classDiagram
  class AuthProvider {
    <<abstract>>
    +getProviderId() string
    +attachContext(context)
    +requestPhoneCode(phone)
    +loginWithPhoneCode(phone, code)
    +registerWithEmail(email, password, code, nickname)
    +loginWithThirdParty(id)
    +signOut()
    +getCurrentSession() AuthSession
  }
  class SandboxAuthProvider {
    本地沙盒，AGC 未配置时降级
  }
  class AgcAuthProvider {
    AGC 认证服务
  }
  class SupabaseAuthProvider {
    自托管 Supabase
  }
  class AuthService {
    <<singleton 门面>>
    +setProviderForTesting()
  }

  AuthProvider <|-- SandboxAuthProvider
  AuthProvider <|-- AgcAuthProvider
  AuthProvider <|-- SupabaseAuthProvider
  AuthService --> AuthProvider : resolveProvider() 按 getBackend() 选择
  AuthService --> SessionManager : 登录成功写会话快照
```

> `AuthProvider.ets` 的注释仅列 Sandbox / AGC 两种实现，但 `AuthService.ets:13,127` 已接入 `SupabaseAuthProvider`——文档注释滞后于代码。

### 3.4 云存储：策略模式（`shared\services\`）

```mermaid
classDiagram
  class CloudSnapshotStore {
    <<abstract>>
    +pull(context, userId) CloudSnapshot
    +push(context, snapshot) boolean
  }
  class AgcCloudSnapshotStore {
    AGC 云数据库
  }
  class SandboxSnapshotStore {
    本地沙盒文件
  }
  class CloudSyncService {
    <<singleton>>
    -resolveStore() CloudSnapshotStore
  }

  CloudSnapshotStore <|-- AgcCloudSnapshotStore
  CloudSnapshotStore <|-- SandboxSnapshotStore
  CloudSyncService --> CloudSnapshotStore : resolveStore()（AGC 未就绪返回 null，不跨存储降级）
  CloudSnapshotStore ..> CloudSnapshot : 承载整包 payload + hash
```

### 3.5 训练数据的双模型与兼容桥

同名 `WorkoutSession` 存在两套定义，桥接服务负责双向转换（AGENTS.md 明确要求保留，勿删）：

```mermaid
classDiagram
  class SharedWorkoutSession["WorkoutSession（TrainingModels）"] {
    +string sessionId
    +WorkoutSet[] sets
  }
  class LegacyWorkoutSession["WorkoutSession（WorkoutSessionService）"] {
    +string id
    +SavedExercise[] exercises
    +string createdAt
  }
  class WorkoutRepository {
    <<内存仓库>>
    +saveSession()
    +getSessions()
  }
  class WorkoutSessionPersistenceBridgeService {
    <<singleton>>
    +persistActiveWorkoutCompletion()
    +loadPersistedSessions()
    +syncRepositoryFromPersistence()
    +replacePersistedSessions()
  }

  WorkoutSessionPersistenceBridgeService ..> SharedWorkoutSession : 共享模型侧
  WorkoutSessionPersistenceBridgeService ..> LegacyWorkoutSession : 偏好存储侧
  WorkoutSessionPersistenceBridgeService --> WorkoutRepository
  WorkoutSessionPersistenceBridgeService --> WorkoutSessionService
  WorkoutRepository ..> SharedWorkoutSession
  WorkoutSessionService ..> LegacyWorkoutSession
```

> `createLegacySession` / `createSharedSession` 在两侧模型间做字段映射，并借 `ContentRepository` 把 `exerciseId` 与中文名/别名互相解析（`WorkoutSessionPersistenceBridgeService.ets:70,88`）。

---

## 4. 序列图

### 4.1 登录（以手机验证码为例）

依据：`features\pencil\pages\PencilLoginPage.ets:172`、`common\services\AuthService.ets:46`、`shared\services\CloudSyncService.ets:221`。

```mermaid
sequenceDiagram
  actor U as 用户
  participant LP as PencilLoginPage
  participant AS as AuthService
  participant CE as CloudEnvironment
  participant P as AuthProvider<br/>(Sandbox/AGC/Supabase)
  participant SM as SessionManager
  participant CS as CloudSyncService

  U->>LP: 输入手机号 + 验证码
  LP->>AS: loginWithPhoneCode(context, phone, code)
  AS->>CE: initialize(context)（幂等探测）
  CE-->>AS: backend = agc / supabase / sandbox
  AS->>P: attachContext(context)
  AS->>P: loginWithPhoneCode(phone, code)
  P-->>AS: AuthResult{success, session}
  AS->>SM: saveSession(context, session)
  AS-->>LP: AuthResult
  LP->>CS: onSignIn(context)
  CS->>CS: syncNow(context)（失败不阻塞登录）
  LP->>LP: routeAfterLogin()
  LP-->>U: replaceUrl(PencilAppShell / 首页空态)
```

### 4.2 完成训练 → 落库 → 后台云同步

依据：`features\pencil\components\ActiveContent.ets:271,333,364`、`features\workout\pages\WorkoutCompletePage.ets:79,136,145`。

```mermaid
sequenceDiagram
  actor U as 用户
  participant AC as ActiveContent
  participant WR as WorkoutRepository
  participant CP as WorkoutCompletePage
  participant BR as PersistenceBridgeService
  participant WS as WorkoutSessionService
  participant CS as CloudSyncService

  U->>AC: 完成最后一组
  AC->>AC: saveCompletedSession()
  AC->>WR: saveSession(session)  （TrainingModels.WorkoutSession，内存）
  AC->>CP: pushUrl(AppRoutes.WORKOUT_COMPLETE)
  CP->>CP: aboutToAppear() → playEntranceAnimations()
  CP->>BR: loadPersistedSessions(context)
  BR->>WS: getSessions(context)
  WS-->>BR: LegacyWorkoutSession[]（preferences fit_tracker_sessions）
  BR-->>CP: WorkoutSession[]（共享模型）
  CP->>CP: WorkoutSummaryService.createSummary()
  CP->>CS: requestBackgroundSync(context)
  CS->>CS: syncNow(context)（autoEnabled 才执行）
  CP-->>U: 渲染完成徽章 / 连续打卡
```

> ⚠ 观察：`ActiveContent.saveCompletedSession()` 只写入内存 `WorkoutRepository`（`ActiveContent.ets:364`），而完成页从 preferences 读取（`WorkoutCompletePage.ets:145`）。把内存态回写持久化的是 `WorkoutSessionPersistenceBridgeService.persistActiveWorkoutCompletion()`，但它在**生产代码中未见调用方**（仅 `ohosTest\ets\test\TargetLoopFlow.test.ets:198,256,310` 调用）。该链路是否在运行时导致「完成页读不到刚结束的会话」需在设备上实测确认，本图集仅如实标注，不作结论。

### 4.3 云同步内部（`syncNow` 六态决策）

依据：`shared\services\CloudSyncService.ets:146-218`。

```mermaid
sequenceDiagram
  participant Caller as 调用方<br/>(登录页 / 完成页 / 账号页)
  participant CS as CloudSyncService
  participant SM as SessionManager
  participant UB as UserDataBackupService
  participant ST as CloudSnapshotStore

  Caller->>CS: syncNow(context)
  CS->>SM: getSession(context)
  alt 无会话
    SM-->>CS: null
    CS-->>Caller: skipped 未登录
  else 有会话
    SM-->>CS: session
    CS->>UB: exportPackage(context)
    UB-->>CS: backupJson
    CS->>CS: buildLocalPayload() + hashPayload()
    CS->>CS: readMeta() → baseline(lastSyncedHash)
    CS->>ST: pull(context, userId)
    ST-->>CS: CloudSnapshot | null
    CS->>CS: decideSyncAction(...)
    alt push
      CS->>ST: push(createCloudSnapshot(...))
      CS->>CS: writeMeta(lastSyncedHash=localHash, status=synced)
    else pull / conflict_pull
      CS->>UB: importPackage(context, remote.backupJson)
      CS->>CS: writeMeta(lastSyncedHash=remoteHash, status=synced)
    else none
      CS->>CS: writeMeta(lastSyncedHash=localHash, status=synced)
    end
    CS-->>Caller: SyncResult{success, action, message}
  end
```

---

## 5. 观察与已知偏差

以下为静态阅读中发现的、与文档描述不一致或值得复核之处，均附锚点，供后续核实：

1. **页面数 19 ≠ 文档的 18**：`main_pages.json` 实际注册 19 项（含 `features/settings/pages/LegalDocPage`），而 `README.md` 与 `AGENTS.md` 均记为 18 页。以 `main_pages.json` 为准。
2. **`AuthProvider` 注释滞后**：`auth\AuthProvider.ets` 注释只列 Sandbox / AGC，实际 `AuthService.ets:13` 已导入并接入 `SupabaseAuthProvider`（`resolveProvider` 在 `backend === 'supabase'` 时返回它，`AuthService.ets:127`）。
3. **训练落库链路存疑**（见 §4.2 ⚠）：内存态 → 持久化的桥 `persistActiveWorkoutCompletion` 在生产代码中无调用方（仅测试调用），而完成页从持久化读取。
4. **双 `WorkoutSession` 模型并存**：`shared\models\TrainingModels.ets` 与 `common\services\WorkoutSessionService.ets` 各定义一套，由 `WorkoutSessionPersistenceBridgeService` 桥接（AGENTS.md 要求保留）。阅读训练数据代码时须先确认处于哪一侧模型。
5. **`WORKOUT_PREVIEW` 路由常量已非路由页**：`AppRoutes.ets:19` 注释说明训练预览改为壳内全模态，该常量仅作「开始训练入口」标识，无生产代码据此 `pushUrl`。

### android 端（`apps\android`）

同一产品的 Kotlin 实现（`app\` + Gradle，153 个 `.kt`），由 `chore(repo): 同步原仓库最新改动进 apps/android` 类提交同步进本 monorepo。若需要 android 端的对应四类图（模块分层、Activity/Fragment 用例、Repository/ViewModel 类图、登录与同步序列），可在本文件基础上另追加一节——其架构与 HarmonyOS 端并非一一对应，需单独调研。

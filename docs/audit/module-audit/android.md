# 安卓模块边界 / 重复实现 / 依赖方向 审计台账

> 范围：`apps\android\app\src`（main + test 计数，违例只记 main）
> 生成方式：机械 grep / wc 穷举 + 定点阅读，**未修改任何源码**
> 判定基线：`apps\android\CONVENTIONS.md`（L2，§一模块结构 / §二单例 / §四 token / §五反模式）+ `docs\process\engineering-constraints.md`（L1）
> 状态：客观发现，不含"应改成什么"的设计结论

## §0 口径与方法（先声明，避免下游误读）

- **前缀**：`SRC` = `apps\android\app\src\main\java\com\fittracker\app`。条目写 `SRC\ui\screens\FtScreens.kt:115`。
- **计数单位（暂缓项决议 #4：采纳）**：`N 行` = import / 代码行实例数；`N 文件` = 去重文件数。**两者成对写**，禁止单写"N 处"。
- **规模基线（wc -l 实测）**：
  | 目录 | 行数 | | 目录 | 行数 |
  |---|---|---|---|---|
  | `data\auth` | 1496 | | `nav` | 585 |
  | `data\cloud` | 942 | | `notifications` | 349 |
  | `data\model` | 370 | | `ui\`（根，FtApp/FtChrome） | 432 |
  | `data\persist` | 139 | | `ui\components` | 2306 |
  | `data\service`（根） | 5640 | | `ui\screens\`（FtScreens） | 189 |
  | `data\service\backup` | 436 | | `ui\screens`（18 屏子树） | 23411 |
  | `data\service\stats` | 1629 | | `ui\theme` | 575 |
  | `data\sync` | 911 | | `wxapi` | 92 |
  | `app`（MainActivity） | 32 | | **main 合计** | **≈39534 行 / 125 文件** |

  `ui\screens` 子树占全量 59%，但只有 7 个 ViewModel（见 B-4）。
- **禁动项字段（暂缓项决议 #3：采纳）**：禁动项与违例项用同一套字段（问题类型 / 影响面 / 优先级），保证台账可排序。

## §1 依赖方向（机械穷举，正向与反向都列）

| ID | 方向 | 实测 | 判定 |
|---|---|---|---|
| D-1 | `data` → `ui` | **0 行**（`^import com.fittracker.app.ui` 在 `data/` 下 0 命中） | ✅ 干净，无反向依赖 |
| D-2 | `data` → `nav` / `notifications` | 0 行 | ✅ 干净 |
| D-3 | `ui\components` → `data` | **1 文件 / 7 行**：`SRC\ui\components\WeightGateDialog.kt`（7 条 data import） | ⚠️ 通用组件层依赖数据层（该文件是全 `ui\components` 唯一破口） |
| D-4 | `ui\screens` 下**可组合**（`*Screen.kt` / `FtScreens.kt` / `*Components.kt`）→ `data.(service\|persist\|sync\|auth\|cloud)` | **18 文件 / 139 行**（分布：ReviewScreen 15、WorkoutPreviewScreen 14、ProfileScreen 12、ProfileEditScreen 12、BodyScreen 12、SettingsScreen 11、CompleteScreen 11、ActiveScreen 11、HomeScreen 10、LoginScreen 7、SplashScreen 5、TrainingPreferencesScreen 5、FtScreens 5、PlansScreen 4、PlanGroupScreen 2、LibraryScreen 1、LegalDocScreen 1、ExerciseDetailScreen 1） | ❌ 主违例：UI 层直连数据层，绕开 ViewModel |
| D-5 | `ui` → `nav` | **8 行 / 6 文件**：`SRC\ui\components\FtBottomTabBar.kt:31`、`SRC\ui\components\FtCanvas.kt:17`、`:18`、`SRC\ui\FtApp.kt:43`、`:44`、`:45`、`SRC\ui\screens\FtScreens.kt:22`、`:23` | ⚠️ 其中 `FtCanvas.kt:17,18` 依赖的是**画布几何**而非路由 → 见 A-1 |
| D-6 | `ui` → `notifications` | **2 行**：`SRC\ui\screens\active\ActiveScreen.kt:114`（`checkAndNotifyAchievement`）、`SRC\ui\screens\settings\SettingsScreen.kt:69`（`ReminderScheduler`） | ⚠️ 副作用从 UI 直接触发 |
| D-7 | `nav` → `ui` | **4 行**：`SRC\nav\FtNavHost.kt:16`-`:19`（FtScreen / ExerciseDetailScreen / LegalDocScreen / PlanGroupScreen） | ✅ 装配层依赖 UI，方向正常 |
| D-8 | `notifications` → `data` | **11 行 / 3 文件**：`AchievementTrigger.kt:4`-`:7`、`ReminderScheduler.kt:7`-`:9`、`WorkoutReminderWorker.kt:6`-`:9` | ✅ 旁路层依赖数据层，方向正常 |

小计：**正向（data→ui）0 行；反向（ui→data）146 行 / 19 文件**（D-3 的 7 + D-4 的 139）。

## §2 模块边界违例（对照 CONVENTIONS 具体条款）

| ID | file:line | 问题类型 | 影响面 | 优先级 |
|---|---|---|---|---|
| B-1 | `SRC\ui\screens\FtScreens.kt:71`、`:115`、`:120`、`:123`、`:124` | CONVENTIONS §一「FtScreens.kt 只做聚合与转接，不要绕过目录写业务逻辑」——该文件做完整登录编排：`rememberCoroutineScope()`(:71) → `AuthService.signIn(...)`(:115) → `SyncOrchestrator.onSignIn(...)`(:120) → `delay(900)`(:123) → `onNavigate("home")`(:124) | 189 行聚合文件承载认证+同步+头像+延时跳转四件事；三处登录路径（密码 :115-124 / 手机验证码 :130-138 / 注册 :150-158）各自重复同一编排 | P1 |
| B-2 | `SRC\ui\screens\auth\LoginScreen.kt:438`、`:475`、`:487` | §五反模式「在 ui\screens\* 里直接读 BuildConfig」+ UI 层解析第三方 JSON | 两处 `com.fittracker.app.BuildConfig.WECHAT_APP_ID` / `QQ_APP_ID` 直读；`:487` 在 UI 里 `as? org.json.JSONObject` 解 QQ 回调 | P1 |
| B-3 | `SRC\ui\screens\review\FtBodyMap.kt:24`、`:71`、`:75`、`:79` | UI 层自己做 JSON 解析（`org.json.JSONObject` 树 + `parseView`） | 身体图几何数据的解析逻辑住在 `ui\screens\review\`，绕开 `data\persist\JsonCodec` | P2 |
| B-4 | 无 ViewModel 的 11 屏：`active` / `auth` / `complete` / `exercise` / `legal` / `library` / `preferences` / `settings` / `splash` / `welcome` / `workout`（18 屏目录仅 7 个 `*ViewModel.kt`：body / home / plan / plangroup / plans / profile / review） | 分层不成体系：VM 层覆盖率 7/18 | 与 D-4 同源——无 VM 的屏只能把 `data.service` 调用写进 Composable | P1 |
| B-5 | `SRC\ui\screens\review\FtReviewColors.kt`（26 处 `Color(0x…)`） | §四「视觉 token 归 `ui\theme`」——调色板落在 `screens\review\` | 第二个颜色事实源，跨屏引用后 token 收敛失效 | P2 |
| B-6 | `SRC\nav\FtRoutes.kt:11`（`FtCanvasKind`）、`:35`（`FtCanvasSpec`）、`:143`（`FtRoutes`） | 单文件混装两类职责：视觉画布几何 + 路由权威表 | 画布几何住在 `nav` 导致 `ui` 反向依赖（D-5）；改画布口径要动导航包 | P2 |
| B-7 | `SRC\ui\FtChrome.kt`（31 行，`class FtChromeState`）vs `SRC\ui\components\FtChrome.kt`（116 行，`FtPageHeader`:30 / `FtChip`:89） | 同名文件不同物（状态容器 vs 组件）；**非重复实现** | 阅读/检索时误判，import 只差 `.components` 一段；`ReviewScreen.kt:111` 引的是 `ui.FtChromeState` | P3 |
| B-8 | 路由字面量散写：`SRC\ui\screens\FtScreens.kt:94`、`:95`、`:102`、`:124`、`:138`、`:158`；`SRC\ui\screens\splash\SplashScreen.kt:83`；`SRC\ui\screens\complete\CompleteScreen.kt:222`；`SRC\ui\FtApp.kt:211`、`:260` | §五反模式「直接拼路由字符串」 | `FtRoutes` 的 `FtRoute.id`（`SRC\nav\FtRoutes.kt:117`）是字符串字段，**没有逐路由常量**可引用；事实源存在但不可被类型检查保护（另见 §4 F-3） | P2 |

## §3 重复实现（逐条给出全部落点，不做"取其一"的取舍）

| ID | 内容 | file:line 全量落点 | 影响面 | 优先级 |
|---|---|---|---|---|
| R-1 | `private fun padTwoDigits(value: Int)` —— **6 份逐字节相同** | `SRC\data\service\ReviewInsightsService.kt:424`、`SRC\data\service\stats\PersonalRecordService.kt:264`、`SRC\data\service\stats\ReviewDashboardService.kt:483`、`SRC\data\service\stats\StatsDashboardService.kt:314`、`SRC\data\service\WorkoutSessionService.kt:197`、`SRC\data\service\WorkoutSummaryService.kt:270` | 6 文件 | P2 |
| R-2 | `formatDate(timestamp): "yyyy-MM-dd"` —— **6 份**（5 份字面一致，`StatsDashboardService` 仅把 `Calendar.getInstance()` 换成 `calendarFrom()`；`WorkoutSessionService` 唯一 public 且用 `calendar.timeInMillis=`） | `SRC\data\service\ReviewInsightsService.kt:417`、`SRC\data\service\stats\PersonalRecordService.kt:257`、`SRC\data\service\stats\ReviewDashboardService.kt:476`、`SRC\data\service\stats\StatsDashboardService.kt:307`、`SRC\data\service\WorkoutSummaryService.kt:263`、`SRC\data\service\WorkoutSessionService.kt:182` | 日期格式口径有 6 个独立实现点；改格式必漏 | P1 |
| R-3 | 周起点计算 / 周标签 —— 私有重造，而 `SRC\data\service\WeekWindow.kt:20/27/35/54/68` 已是既有共享实现 | `createWeekStart`：`SRC\data\service\ReviewInsightsService.kt:347`、`SRC\data\service\stats\StatsDashboardService.kt:236`；`mondayStart`：`SRC\data\service\BodyRecordService.kt:231`；`createWeekLabel`/`getWeekOffsetLabel`：`ReviewInsightsService.kt:325`、`:335` | 周窗口语义（`WeekStart` 可配）有两个平行实现族 | P1 |
| R-4 | `QqAuthStore` vs `WxAuthStore` —— 结构同构（`saveCode`/`saveFailure`/`consume`/`clear` + `*AuthResult` data class + 手写 `org.json`） | `SRC\data\auth\QqAuthStore.kt`（101 行，`object`:17、`saveCode`:30、`saveFailure`:35、`consume`:40、`clear`:66、`QqAuthResult`:96）↔ `SRC\data\auth\WxAuthStore.kt`（105 行，`:16`、`:31`、`:36`、`:44`、`:70`、`WxAuthResult`:100）；手写 JSON：`QqAuthStore.kt:49`、`:73` / `WxAuthStore.kt:53`、`:77` | 第三方登录存储两份平行实现，**且都绕过 `SRC\data\persist\JsonCodec.kt`**（全仓 `JsonCodec.` 有 12+ 统一调用点，仅这 4 处例外） | P2 |
| R-5 | UI 私有 Composable 重名：**14 个名字 / 33 处声明 / 12 个 Screen 文件** | `TopBar`→`BodyScreen.kt:313`、`LibraryScreen.kt:350`、`PlanGroupScreen.kt:254`、`WorkoutPreviewScreen.kt:292`；`Card`→`BodyScreen.kt:1104`、`ReviewScreen.kt:1226`；`FootNote`→`LibraryScreen.kt:848`、`TrainingPreferencesScreen.kt:410`、`SettingsScreen.kt:599`；`ScreenToast`→`LibraryScreen.kt:1102`、`PlanGroupScreen.kt:708`、`SettingsScreen.kt:676`；`SheetButton`→`BodyScreen.kt:1074`、`ProfileEditScreen.kt:961`；`BackIcon`→`LibraryScreen.kt:1151`、`TrainingPreferencesScreen.kt:426`、`SettingsScreen.kt:614`；`BackChevronIcon`→`BodyScreen.kt:1149`、`LegalDocScreen.kt:213`；`ChevronLeftIcon`→`PlanGroupScreen.kt:761`、`PlansScreen.kt:448`；`ChevronIcon`→`ProfileScreen.kt:899`、`SettingsScreen.kt:628`；`CheckIcon`→`BodyScreen.kt:1187`、`PlanGroupScreen.kt:775`；`LibraryIcon`→`LibraryScreen.kt:1266`、`ProfileScreen.kt:857`；`MetricTile`→`BodyScreen.kt:629`、`ExerciseDetailScreen.kt:779`；`Dock`→`ActiveScreen.kt:1588`、`CompleteScreen.kt:441`；`ConfettiLayer`→`ActiveScreen.kt:2097`、`CompleteScreen.kt:568` | 12 屏各自造同义组件；`ui\components`（2306 行）已提供共享层却未覆盖 | P2 |
| R-6 | 共享组件已存在却被重造（候选，需语义核对） | `SRC\ui\components\FtCard.kt:43`（`FtCard`）↔ `SRC\ui\screens\body\BodyScreen.kt:1104` `Card` / `SRC\ui\screens\review\ReviewScreen.kt:1226` `Card`；`SRC\ui\components\FtChrome.kt:30`（`FtPageHeader`）↔ R-5 的 4 份 `TopBar` | 同上；`FtCard`/`FtPageHeader` 的复用面被本地私有版本截断 | P2 |
| R-7 | `FtScreens.kt` 内同一段登录成功编排 3 次 | `SRC\ui\screens\FtScreens.kt:115`-`:124`、`:130`-`:138`、`:150`-`:158`（各自 `SyncOrchestrator.onSignIn` + `AvatarImageService.resolveDir` + `delay(900)` + `onNavigate("home")`） | 与 B-1 同源；文件内重复 | P1 |

**同一语义双轨序列化小计**：`JsonCodec` 统一调用点 ≥12 行（`SandboxAuthProvider.kt:310/318/677/685`、`SessionManager.kt:67/81/94/202/209`、`SupabaseAuthProvider.kt:375/382`、`SupabaseCloudSnapshotStore.kt:70` …）vs 手写 `org.json` **4 文件 / 5 处**（R-4 的 4 处 + `FtBodyMap.kt:71`）。

## §4 文档 ↔ 源码漂移（CONVENTIONS §一 目录清单 vs 实际）

| ID | 文档写的 | 源码实际 | 性质 |
|---|---|---|---|
| F-1 | `ui\theme\` 列 6 文件（DuTokens / FtColor / FtShape / FtSpace / FtMotion / FtTheme） | **7 文件**，多出 `SRC\ui\theme\FtType.kt`（93 行） | 文档漏登记；token 层事实源不完整 |
| F-2 | `data\service\stats\` 列「ReviewService / ReviewDashboardService」 | **5 文件 / 1629 行**：另含 `SRC\data\service\stats\PersonalRecordService.kt`（265）、`StatsDashboardService.kt`（349）、`HomePlanService.kt`（393） | 文档漏登记 3 个文件；且 `SRC\data\service\ReviewInsightsService.kt`（同一"回顾派生"职责族）**放在 `service\` 根而非 `stats\`** → 归类不一致 |
| F-3 | 「路由事实源：`nav\FtRoutes.kt`」 | `FtRoutes` 对象确在 `SRC\nav\FtRoutes.kt:143`，但同文件 `:11`/`:35` 是画布几何；且路由 id 只有字符串字段（`FtRoute.id`，`:117`），**无逐路由常量**，调用方普遍写裸字面量（B-8） | 事实源存在但不可被编译器约束 |
| F-4 | §一 未提及 `ui\` 根下文件 | `SRC\ui\FtApp.kt`（壳）、`SRC\ui\FtChrome.kt`（`FtChromeState`）都在 `ui\` 根，且 `ui\` 与 `ui\components\FtChrome.kt` 同名 | 目录清单不完整 + B-7 命名冲突 |
| F-5 | §四「不要在 Composable 里散落魔法色值」 | **实测 250 处 `Color(0x…)` / 25 文件**：`SRC\ui\theme\FtColor.kt` 34 处（合规 token 文件）、`SRC\ui\screens\review\FtReviewColors.kt` 26 处（B-5 越位调色板）、**其余 190 处散在 22 个 UI 文件**（Top5：`ActiveScreen.kt:26`、`PlanGroupScreen.kt:19`、`LibraryScreen.kt:19`、`SplashScreen.kt:16`、`ExerciseDetailScreen.kt:12`） | 主违例，量级见 §6 |

## §5 禁动清单（改前必读；file:line 为锚点）

| ID | file:line | 禁动依据（问题类型） | 影响面（误动的后果） | 优先级 |
|---|---|---|---|---|
| X-1 | `SRC\data\model\TrainingModels.kt:197` `estimateOneRepMax` | 全项目 1RM **唯一实现点**（注释 `:192` 自述；`ReviewService.kt:41`、`ActiveWorkoutService.kt:597` 均复用它，无第二份） | 重写公式 = 双端 1RM/PR/训练量全线漂移（对齐鸿蒙 `TrainingModels.ets:418`） | P0-禁动 |
| X-2 | `SRC\data\model\BackupPackage.kt`（契约源，`contracts\README.md` §1 引用 `:23`） | 跨端备份包契约（字段级，Android ↔ 鸿蒙 `UserDataBackupService.ets:26`） | 改 = 旧包导入丢字段 / 双端不兼容 | P0-禁动 |
| X-3 | `SRC\data\sync\LocalSnapshotStore.kt`（`CloudPayloadEnvelope`） | `contracts\README.md` §2 云信封契约（`backupJson` 美化格式非紧凑） | 改 = 云端已有快照读不出 | P0-禁动 |
| X-4 | `SRC\data\cloud\SupabaseCloudSnapshotStore.kt` | `apps\android\CONVENTIONS.md` §三：与鸿蒙 `SupabaseCloudSnapshotStore.ets` 是同一契约的两份实现（同表同 PostgREST 形状同时间单位） | 单侧改 = 「同步成功但数据不同步」 | P0-禁动 |
| X-5 | `SRC\data\service\backup\UserDataBackupService.kt:39`、`:364` | 备份合并/镜像兼容逻辑；两处注释以鸿蒙 `WorkoutSessionPersistenceBridgeService`（`:115` 的 `replacePersistedSessions`）为对照 | 改 = 已落盘用户会话合并错乱 | P0-禁动 |
| X-6 | `SRC\data\service\WorkoutSessionService.kt:12`、`:180`-`:182` | `:12` 明文声明「Android 按迁移计划**不移植兼容层**」；`:182` `formatDate` 被外部引用（周窗口/日期归一） | 误以为缺兼容层而"补齐"= 造出无人消费的第二套；改 `formatDate` 波及 R-2 调用面 | P1-禁动 |
| X-7 | `SRC\data\persist\JsonCodec.kt` | 序列化单点（统一调用点 ≥12 行） | 绕过它新增 `org.json` = 复刻 R-4 的双轨问题 | P1-禁动 |
| X-8 | `contracts\README.md`（**§0–§7**，含 §7「已知未收敛项」） | 跨端契约基线 | 漏读 §7 会把"已知未收敛"当成新发现的漂移 | P0-参考 |

**暂缓项 #2 决议（采纳）**：`WorkoutSessionPersistenceBridgeService` **在 `apps\android\` 下没有对应文件**——全仓 grep 只命中两类：(a) 鸿蒙侧 `.preview` 编译缓存产物；(b) Android 侧的**注释引用**（`UserDataBackupService.kt:39`、`:364`、`WorkoutSessionService.kt:12`、`:180`）。鸿蒙本体在 `apps\harmony\entry\src\main\ets\shared\services\`（L1「服务归属」明文列其为现存兼容层）。故本台账的禁动项用 Android 侧对照物锚定（X-5 / X-6），**不虚构不存在的 file:line**。

## §6 预设数字对账（暂缓项 #1 决议：降级为待证伪假设 → 已证伪）

| 预设 | 来源推测 | Android 实测 | 结论 |
|---|---|---|---|
| 「38 处内联色值」 | 鸿蒙侧口径 | **250 行 / 25 文件**（含 2 个调色板文件 60 行） | ❌ 不可迁移。Android 侧真实违例量 **190 行 / 22 文件** |
| 「3 处 shared→features」 | 鸿蒙目录概念（`shared/`+`features/`），Android 无同名层 | 安卓对位指标：**`ui→data` 反向 146 行 / 19 文件**（D-3 7 + D-4 139）；`data→ui` **0 行** | ❌ 概念不对位；改用 D-3/D-4 |
| 「4 处 common→shared」 | 鸿蒙 `common/`→`shared/` import 行 | 安卓无 `common/`/`shared/` 层；最近对位是 `data\service` 内部重复（R-1 6 / R-2 6 / R-3 4） | ❌ 概念不对位 |

口径说明：上表 Android 数字均为 **grep 全量穷举的下限**（模式固定、无采样），因此"≥"关系成立的是**鸿蒙侧预设不可外推**这一点，而非 Android 数字可外推。

## §7 暂缓项决议汇总

| # | 议题 | 决议 |
|---|---|---|
| 1 | 38/3/4 预设数字 | **采纳为待证伪假设并证伪**（§6）。台账不把这些数当预期值；Android 数字全部重新穷举得出。偏差：内联色值 +152 行（38→190 违例行，若含调色板 250） |
| 2 | `WorkoutSessionPersistenceBridgeService` 落点 | **已定位**：Android 无此文件，仅注释引用；以 X-5 / X-6 锚定对照面（§5 脚注） |
| 3 | 禁动项是否填全字段 | **采纳**：全字段（依据/影响面/优先级），见 §5 |
| 4 | 计数单位混用 | **采纳**：`N 行`（实例）与 `N 文件`（去重）成对书写，§0 已声明 |
| 5 | 契约基线 §1-§6 vs §0-§7 | **采纳修正**：基线为 `contracts\README.md` **§0–§7**，§7「已知未收敛项」纳入必读（X-8） |
| 6 | audit-server-functions 的禁动区缺口 | **本任务范围外**（Scope 仅 `apps\android\app\src`），未处理；留给 server 侧审计 |

## §8 本轮未覆盖（诚实边界）

- `apps\android\app\src\test\`（73 个 `*.kt`）只做了清单计数，未做与 main 的边界对位审计。
- `ui\screens` 各屏**内部**（合计 23411 行）只抽读了 4 个文件（FtScreens / ReviewScreen 片段 / 局部脚手架），逻辑重复的存在性以名字复用（R-5/R-6）为证据，未逐屏做语义等价判定——R-6 明确标为"候选，需语义核对"。
- 未运行任何构建/测试（本次为只读审计，无源码改动）；台账不含通过/失败结论。

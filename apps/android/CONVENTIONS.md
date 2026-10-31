# 安卓端工程约束

> **层级**：L2 展开
> **最后核对**：2026-10-28
> **上位文档**：`docs\process\engineering-constraints.md`（L1，冲突以 L1 为准）+ `docs\glossary.md`（口径与术语）
> **状态**：现行
> **路径基准**：文中 `app\…`、`build.gradle.kts` 相对 `apps\android\`；`docs\…`、`server\…` 相对仓库根
> **适用端**：仅安卓

## 为什么需要这份文件

本仓库是双端同构，但 `apps\android\` 下此前只有 `app/libs/README.md`——改安卓代码的人拿不到任何书面约束，只能靠读鸿蒙侧的规则再自行类比。结果是「一端做了、另一端没做」和「安卓抄了鸿蒙的 ArkTS 规则」两类错误都会发生。

`docs\process\dual-platform-parity.md` 已经管了**两端之间**的对等关系（哪一屏对哪一屏、身份字段是否一致），本文件管**安卓端内部**的写法。两者是主从关系：对等清单以 parity 为准，端内写法以本文为准。

用词与事实口径（回顾 / 训练计划 / 计划组 / 快照 / 云后端等）一律以 `docs\glossary.md` 为准，本文不重复定义。

## 一、模块结构

```text
apps/android/app/src/main/java/com/fittracker/app/
├── data/
│   ├── auth/       # AuthService 门面 + Provider 双实现 + 会话与第三方登录存储
│   ├── cloud/      # Supabase 链路：Http / Config / Session / AuthProvider / 快照存储
│   ├── model/      # 领域模型（与鸿蒙 shared 的模型逐字段对齐）
│   ├── persist/    # JsonStore 读写抽象
│   ├── service/    # 与鸿蒙 common/services + shared/services 对应的服务
│   │   └── stats/  # 回顾与统计派生（ReviewService / ReviewDashboardService）
│   └── sync/       # 云同步编排：CloudSyncService / SyncOrchestrator / 本地沙盒存储
├── nav/            # FtRoutes：路由与 Tab 的事实源
├── notifications/  # 应用内提醒
├── ui/
│   ├── components/ # 跨屏复用组件
│   ├── screens/    # 每屏一个目录，+ FtScreens.kt 聚合
│   └── theme/      # 视觉 token：DuTokens / FtColor / FtShape / FtSpace / FtMotion / FtTheme
└── wxapi/          # 微信开放平台回调入口
```

**路由事实源**：`app\src\main\java\com\fittracker\app\nav\FtRoutes.kt`。新增屏必须同时满足：`ui/screens/<name>/` 目录存在、`FtRoutes` 有对应条目、在 `docs\process\dual-platform-parity.md` 的对等清单里登记（或登记为单端独有并给理由）——三件套缺一件，`check-parity.mjs` 就会红。

**屏目录与聚合文件**：每个屏一个目录（`home`、`plan`、`review` 等），`FtScreens.kt` 只做聚合与转接。不要绕过目录直接在 `FtScreens.kt` 里写业务逻辑。

## 二、服务与单例

- 服务一律 `object Xxx`（Kotlin 单例），调用方直接引用，**不要** `new` 出第二份。
- 需要持久化的服务以 `JsonStore` 注入，与 `data/service/` 各服务同模式；测试注入点必须显式命名（`setXxxForTesting`），并在注释里写清「为什么需要它」。
- 持有**实例内存态**的服务必须缓存实例（例：`AuthService` 按 store 缓存 provider，否则「发码」与「验证码登录」会落在两个实例上，沙盒登录恒失败）。这类约定的回归护栏要写成测试。
- 服务层返回业务模型，不返回 UI 文案。

## 三、云链路

- 配置来源：`local.properties` 的 `supabase.url` / `supabase.publishableKey` → `build.gradle.kts` 的 `buildConfigField` → `BuildConfig.SUPABASE_URL` / `BuildConfig.SUPABASE_PUBLISHABLE_KEY`。`local.properties` **不入库**；缺省空串即云端禁用，自动走沙盒。
- provider 解析规则与鸿蒙 `CloudEnvironment.getBackend()` 同构：已配置 → Supabase 真实链路；未配置 → `SandboxAuthProvider` 本地沙盒。**没有 AGC 分支**——AGC 云后端已移除（2026-10-28）。
- 快照存储 `data/cloud/SupabaseCloudSnapshotStore.kt` 与鸿蒙 `SupabaseCloudSnapshotStore.ets` 是**同一契约的两份实现**：同一张 `public.snapshots(user_id, payload, updated_at)`、同一 `user_id`、同一 PostgREST 请求形状、同一时间单位（epoch 毫秒 ↔ ISO8601 UTC）。改一侧必须同时改另一侧，并同步 `contracts/` 里的契约描述。
- 单测不依赖 `BuildConfig`：需要云配置的用例注入 store/配置，不要读真实 `local.properties`。

## 四、UI 与视觉 token

| 用途 | 安卓 token | 鸿蒙对应 |
|---|---|---|
| 颜色 | `ui/theme/FtColor.kt` + `DuTokens.kt` | `common/styles/DesignTokens.ets` `ColorTokens` |
| 间距 / 圆角 / 尺寸 | `FtSpace.kt` / `FtShape.kt` | `SpacingTokens` / `RadiusTokens` / `TouchTokens` |
| 动效 | `FtMotion.kt` | `common/styles/MotionIntent.ets` |

- 不要在 Composable 里散落魔法色值/尺寸；同类按钮不要各自加阴影或圆角。
- 两端各自维护 token，**改配色两端一起改**（parity「改动时的同步要求」第 5 条）。
- 用户可见文案中文，且与鸿蒙**逐字一致**：同一屏、同一状态、同一标点。典型易错点：Tab 名（「回顾」）与屏内徽章的措辞必须一致。

## 五、反模式

- ❌ 把鸿蒙的 ArkTS 规则照搬到 Kotlin（`@Entry`、`AppRoutes` 常量、preferences `flush()` 都不适用）；这里只借**约束意图**，不借语法。
- ❌ 在 `ui/screens/*` 里直接 new 服务、直接读 `BuildConfig`、直接拼路由字符串。
- ❌ 新增屏不登记 parity，或只做一端就提交且不加「仅 <端>」说明。
- ❌ 改快照契约只改一端。两端契约不一致时线上表现为「同步成功但数据不同步」，比报错更难查。
- ❌ 用 `applicationId` 与 `namespace` 互相替代：前者是上架身份（`com.earthrhythm.fittracker`，必须等于鸿蒙 `bundleName`），后者只决定 R 类与 BuildConfig 包名（`com.fittracker.app`）。

## 六、常用检查

```powershell
cd apps/harmony
node tools/check-parity.mjs          # 双端对等清单 + 身份一致（含安卓屏目录）
node tools/check-glossary.mjs        # 口径与术语（GL-01..GL-04）
node tools/check-specs.mjs           # 规范登记与头部

cd ../android
./gradlew :app:testDebugUnitTest     # JVM 单测
./gradlew :app:compileDebugKotlin    # 只改注释/常量后至少跑这条
```

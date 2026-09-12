# FitTracker Release / Build Runbook

## 1. 目的

这份 runbook 只覆盖 FitTracker 的构建与发布工程面，用来回答 4 个问题：

- 当前仓库能稳定产出什么交付物
- release / signing 现在真实卡在哪里
- 发布与构建工程师建议用什么命令复跑
- 后续把正式签名接进来时，应改哪些接入点

本文件不覆盖业务功能验收，不替代 `docs/mvp-closeout.md` 的 MVP 功能收官记录。

## 2. 当前真实状态

截至 2026-09-12（本轮 release 硬阻断攻关），仓库已消除「判据死锁」，但真实签名材料仍未生成。

已确认的现状：

- DevEco / hvigor / PackageHap 基础链路可用，`PackageHap -> spawn java ENOENT` 已通过 `tools/deveco-env.ps1`、`tools/java.cmd`、`tools/node-java-shim.cjs` 收住。
- 当前可稳定产出 unsigned HAP：
  - `entry/build/default/outputs/default/entry-default-unsigned.hap`
  - `entry/build/default/outputs/ohosTest/entry-ohosTest-unsigned.hap`
- 应用身份已替换为正式值：`bundleName = com.earthrhythm.fittracker`，`vendor = EarthRhythm`（原 `com.example.fittracker_opencode` / `example` 已废弃，数据影响见 §9）。
- 根配置 `build-profile.json5` 声明了 `release` build mode；`app.signingConfigs` 仍为空数组，`default` product 的 `signingConfig: "default"` 引用暂时悬空。
- `entry/build-profile.json5` 的 release 块已开启混淆（`ruleOptions.enable = true`，规则见 `entry/obfuscation-rules.txt`；实测缺口见 §4.5）。
- **签名材料尚未生成**：`devecocli auth status` 返回 `Not logged in`，`devecocli signature generate --product default` 直接失败（`Run devecocli auth login to sign in.`）。

结论：**判据与实际状态已对齐——`node tools/check-release-readiness.mjs` 现在的 FAIL 准确指向「签名材料未生成」这一真实缺口，而不是判据自身造成的死锁。在登录并生成材料前，仓库仍只具备 unsigned 构建能力。**

## 3. 当前建议命令

### 3.1 只读 readiness 检查

```powershell
node tools/check-release-readiness.mjs
```

用途：

- 快速确认 release build mode、签名材料、product 引用、环境脚本、unsigned 产物、应用身份是否处于可继续推进状态
- 当 signing 尚未接入时，脚本会以非零退出码明确提示“release not ready”

签名材料判据（2026-09-12 修正）：

- 旧判据要求「仓库内存在签名材料文件」，与「签名材料不得入库」互斥——两者同时成立时门禁永远 FAIL，形成死锁，无法与发布工程约束同时满足。
- 新判据只看 `build-profile.json5` 中 `signingConfigs[].material` 引用的路径（`storeFile` / `certpath` / `profile`）是否真实存在：`resolve` + `existsSync`，**仓库内外皆可**；`signingConfigs` 为空或任一引用路径缺失判 FAIL。
- 附加安全判据：材料落在仓库内**且被 git 追踪**判 FAIL（防止证书入库）；product 的 `signingConfig` 解析不到同名定义判 FAIL。
- 回归测试：`node --test tools/check-release-readiness.test.mjs`（覆盖空配置 / 路径缺失 / 仓库外材料 PASS / 仓库内被追踪 / 悬空引用 5 个用例）。

### 3.2 基础构建环境准备

```powershell
powershell -ExecutionPolicy Bypass -File tools/deveco-env.ps1
```

用途：

- 统一设置 `JAVA_HOME`
- 规范化 `Path` / `PATH`
- 将 DevEco JBR、hvigor、toolchain 与 repo 内 Java shim 补进当前会话

### 3.3 当前可复跑的 unsigned 构建

```powershell
devecocli build --modules entry@default --product default
devecocli build --modules entry@ohosTest --product default
```

说明：

- 这是当前仓库唯一已经被验证过的构建交付口径
- 若出现 Java / PackageHap 相关问题，先重跑 `tools/deveco-env.ps1`

## 4. 正式签名发布仍缺的前置条件

以下项目没有补齐前，不应宣称仓库已具备 release 签名交付能力。

### 4.1 应用身份前置项

- ✅ 正式 `bundleName`：`com.earthrhythm.fittracker`（已落地于 `AppScope/app.json5`）
- ✅ 正式 `vendor`：`EarthRhythm`（已落地；若厂商法定登记名不同，请以登记名为准再改一次）
- ⛔ 对应的 AppGallery Connect 应用条目（需在 AGC 控制台创建，仓库外操作）

原 `com.example.fittracker_opencode` / `example` 只适合作为开发样板值。替换 bundleName 会改变本地数据沙箱、导致旧数据不可见，完整机制与迁移路径见 **§9**。

### 4.2 签名材料前置项

- HarmonyOS 发布证书材料
- 与应用身份匹配的 profile / provisioning 材料
- 本机安全存放策略

生成方式（用户指定）：

```powershell
devecocli auth login                            # 交互登录华为开发者账号
devecocli signature generate --product default  # 生成材料并自动写入 build-profile.json5
```

- `signature generate` 默认把材料写到**项目根 `signature/`** 目录，并把 `signingConfigs` 自动写进 `build-profile.json5`。
- `signature/` 目录与 `*.p12 / *.cer / *.p7b` 等扩展名已加入 `.gitignore`，材料不得入库。
- **当前状态：blocked** —— `devecocli auth status` 返回 `Not logged in`，`signature generate` 以 `Failed to automatically generate signatures. Run devecocli auth login to sign in.` 失败。该步必须在可交互登录的环境执行；未登录时不得手写假证书或伪路径让门禁变绿。

### 4.3 构建配置前置项

- 在 `build-profile.json5` 中补齐真实 `signingConfigs`（由 `signature generate` 自动完成）
- 明确 `default` product 在 release 期实际引用的 signing config 名称（当前 `"default"` 与 `signature generate` 的默认命名一致）
- 签名材料来源已约定为 `devecocli signature generate` 的项目根 `signature/` 产物

### 4.4 验收前置项

- 一次真实 signed HAP 构建记录
- 一次 signed 包安装 / 启动验证
- 一份 release closeout 或发布交付记录

### 4.5 release 混淆（已开启配置，尚未实测）

- `entry/build-profile.json5` 的 `ruleOptions.enable` 已由 `false` 改为 `true`；规则文件 `entry/obfuscation-rules.txt` 启用了 `-enable-property-obfuscation` / `-enable-toplevel-obfuscation` / `-enable-filename-obfuscation` / `-enable-export-obfuscation`。
- ⚠ **本轮只在配置层开启，未在 release 包上实测**（未构建、未装机）。开启混淆后至少需实测以下三条，缺一不可：
  1. **启动与日志**：release 包冷启动不崩，`devecocli log --level E` 无致命错误；
  2. **持久化 round-trip**：`common/services/*` 中 11 处 `JSON.parse(json) as Xxx`（`AuthService` / `SessionManager` / `TrainingPlanService` / `WorkoutSessionService` / `WorkoutDraftService` / `FavoriteExerciseService` / `GoalRepository` 等）在「写入 → 冷启动 → 读取」后数据完好；
  3. **页面路由**：`main_pages.json` 注册的 `@Entry` 页面在 filename 混淆后仍能正常加载。
- 若上述任一项失败：把 `entry/build-profile.json5` 的 `ruleOptions.enable` 回退为 `false`，并在本文记录原因与实测证据。

## 5. 建议的后续接入点

本仓库后续接正式签名时，建议只改下列工程接入点：

- `build-profile.json5`
  - 补齐 `app.signingConfigs`
  - 保持 `products` 与 `buildModeSet` 的职责在根配置层
- `entry/build-profile.json5`
  - 继续只承载模块级 release 构建选项，如混淆、资源策略
- `tools/deveco-env.ps1`
  - 继续负责 DevEco / Java / hvigor 运行环境
  - 不建议把证书内容硬编码进脚本
- 新的本机私有配置载体
  - 可以是本机私有文件，也可以是环境变量映射
  - 必须默认不入库

建议原则：

- 证书、profile、密码、别名等敏感信息不提交仓库
- 仓库只保留接入点、校验脚本、命令说明和故障定位文档

## 6. 当前不建议做的事

- 不要在签名材料未齐时，先把 `build-profile.json5` 写成伪完整配置
- 不要把证书或密码以明文文件形式提交到仓库
- 不要把 MVP 的 unsigned closeout 文档直接改写成“已签名发布完成”

## 7. 外部依赖清单

正式签名发布至少依赖以下外部条件：

- 本机安装可用的 DevEco Studio / hvigor / HarmonyOS SDK
- 华为开发者账号
- AppGallery Connect 应用
- 发布证书与 profile 材料
- 用于签名的本机安全存储位置与访问权限

## 8. 与现有文档的关系

- `docs/mvp-closeout.md`：记录 MVP 内部验收包，不记录正式签名发布完成
- 本文档：记录发布与构建工程面的真实状态、命令、缺口与后续接入点

## 9. bundleName 变更的副作用与数据迁移

### 9.1 结论先行

HarmonyOS 按 bundleName 划分应用数据沙箱。**任何一次 bundleName 变更，都会让新包在系统看来是一个全新应用**：原沙箱内的全部本地数据在新包下不可见，用户感知为"数据被清空"。这是平台机制，不是缺陷。

本轮已实际发生该变更：

- 旧（样板）身份：`bundleName = com.example.fittracker_opencode`，`vendor = example`
- 新（正式）身份：`bundleName = com.earthrhythm.fittracker`，`vendor = EarthRhythm`

**后果**：若旧身份包从未对外分发，则本次变更无实际数据损失；若旧身份包曾安装到任何真实设备（含内测机），该设备上的本地数据在新包下不会自动带过来，需要按 9.4 迁移。后续如再次变更身份，同样遵循本节流程。

### 9.2 机制：沙箱路径随 bundleName 变化

HarmonyOS 为每个应用按其 bundleName 分配独立沙箱目录，应用私有数据（含 Preferences 文件）落在形如 `/data/app/el2/<userId>/base/<bundleName>/` 的路径下。Preferences 由 `preferences.getPreferences(context, <storeName>)` 创建，其物理文件位于该 bundleName 的沙箱内。

- bundleName 不变：`getPreferences` 命中同一目录，数据延续；
- bundleName 改变：新包沙箱路径不同，`getPreferences` 只会在新目录创建空库，旧数据既不会被读取，也不会被自动迁移。

### 9.3 受影响的数据（当前全部 Preferences store）

下表是当前实现中全部本地数据落点，bundleName 变更后**这 11 个 store 全部从"零"开始**：

| store 名 | 业务含义 | 定义 / 使用位置 |
| --- | --- | --- |
| `fit_tracker_auth` | 本地账号凭据 | `entry/src/main/ets/common/services/AuthService.ets` |
| `fit_tracker_session` | 登录会话 | `entry/src/main/ets/common/services/SessionManager.ets` |
| `fit_tracker_profile` | 用户资料 | `entry/src/main/ets/common/services/UserProfileService.ets` |
| `fit_tracker_goal` | 用户目标设置 | `entry/src/main/ets/shared/services/GoalRepository.ets` |
| `fit_tracker_plans` | 训练计划 | `entry/src/main/ets/common/services/TrainingPlanService.ets` |
| `fit_tracker_sessions` | 训练记录 | `entry/src/main/ets/common/services/WorkoutSessionService.ets` |
| `fit_tracker_active_workout` | 进行中的训练草稿 | `entry/src/main/ets/common/services/WorkoutDraftService.ets` |
| `fit_tracker_favorites` | 收藏的动作 | `entry/src/main/ets/common/services/FavoriteExerciseService.ets` |
| `fit_tracker_entitlement` | 会员权益状态 | `entry/src/main/ets/shared/services/MonetizationEntitlementService.ets` |
| `fit_tracker_content_sync` | 内容目录同步状态 | `entry/src/main/ets/shared/services/SyncService.ets` |
| `fit_tracker_launch_request` | 启动请求（调试种子） | `entry/src/main/ets/app/LaunchRequestStore.ets` |

（`app/AppState.ets` 的 `FitTrackerStores` 中还声明了 `CONTENT` / `PLANS` / `WORKOUTS` / `RECORDS` 常量，但当前代码中未见对它们的引用，不构成数据落点。）

### 9.4 迁移路径

仅在"已经分发过旧 bundleName 的包、且用户留有数据"时才需要迁移：

1. 在**旧包**内使用应用内备份功能，导出本地 JSON 备份包，保存到设备公共目录或外部存储；
2. 替换 `bundleName` 与 `vendor`，重新构建；
3. 卸载旧包、安装新包（两者 bundleName 不同，可并存，但建议干净安装）；
4. 在**新包**内导入第 1 步的备份包；
5. 校验：训练记录、计划、资料、收藏等是否完整回填。

备份包以内容为单位组织，不依赖沙箱路径，因此是跨 bundleName 迁移的可行载体——但前提是旧包在卸载前已经导出。

### 9.5 上线检查项

- [x] `AppScope/app.json5` 的 `bundleName` / `vendor` 已替换为正式身份（`com.earthrhythm.fittracker` / `EarthRhythm`）；
- [ ] 已确认不存在"仍需读取旧 bundleName 沙箱数据"的诉求，或已按 9.4 完成迁移；
- [ ] 替换后重新执行 `node tools/check-release-readiness.mjs`；
- [ ] 替换后重新走一遍完整回归（`ohosTest` + 关键设备冒烟）。


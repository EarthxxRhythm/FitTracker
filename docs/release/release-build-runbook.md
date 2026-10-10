# 菲特 Release / Build Runbook

## 1. 目的

这份 runbook 只覆盖 菲特 的构建与发布工程面，用来回答 4 个问题：

- 当前仓库能稳定产出什么交付物
- release / signing 现在真实卡在哪里
- 发布与构建工程师建议用什么命令复跑
- 后续把正式签名接进来时，应改哪些接入点

本文件不覆盖业务功能验收，不替代 `docs/closeout/mvp-closeout.md` 的 MVP 功能收官记录。

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

- `docs/closeout/mvp-closeout.md`：记录 MVP 内部验收包，不记录正式签名发布完成
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
| `fit_tracker_content_sync` | 内容目录同步状态 | `entry/src/main/ets/shared/services/SyncService.ets` |
| `fit_tracker_launch_request` | 启动请求（调试种子） | `entry/src/main/ets/app/LaunchRequestStore.ets` |

（`app/AppState.ets` 的 `菲特Stores` 中还声明了 `CONTENT` / `PLANS` / `WORKOUTS` / `RECORDS` 常量，但当前代码中未见对它们的引用，不构成数据落点。）

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



## 10. 实测记录：2026-09-13 首次产出已签名 release HAP

### 执行结果

| 步骤 | 命令 | 结果 |
|---|---|---|
| 登录 | `devecocli auth status` | `Current user: 131*******` |
| 生成材料 | `devecocli signature generate --product default` | 成功；材料写入 `~/.ohos/config/`，签名配置写入 `build-profile.json5` |
| 门禁 | `node tools/check-release-readiness.mjs` | **exit 0**（接入前为 exit 1） |
| release 构建 | `devecocli build --product default --build-mode release` | BUILD SUCCESSFUL，产出 `entry-default-signed.hap`（约 22.1 MB），**无 "Will skip sign" 警告** |
| 安装 | `hdc install entry/build/default/outputs/default/entry-default-signed.hap` | `install bundle successfully` |
| 冷启动 | `aa start -a EntryAbility -b com.earthrhythm.fittracker` | `start ability successfully`，welcome 页正常渲染 |

结论：**已签名 release HAP 产出并在设备安装启动成功**，混淆开启未破坏启动与渲染。

### 接入签名时暴露的两处门禁缺陷（已修复，commit c4973d3）

1. `devecocli signature generate` 会把 `build-profile.json5` 重写为 json5 风格（无引号键名 + 单引号字符串 + 尾逗号），旧 `stripJson5` 只处理注释与尾逗号 → `JSON.parse` 崩溃，门禁在真实签名配置下失效。
2. `hasReleaseMode` / `hasModuleReleaseBlock` 用双引号字面量正则匹配结构，在 json5 风格下误判「缺少 release build mode」。

修复后 `stripJson5` 支持单引号字符串与无引号键名，两个结构判据改为基于解析后的对象；回归测试 7 pass / 0 fail。

### 实测到的行为差异（不阻塞上架，待诊断）

`--ps devSeed today_flow` 在 **debug 包**下可让 splash 直达 home；在 **release 包**（混淆开启）下，日志确认 `Launch want params` **已收到** `"devSeed":"today_flow"`，但应用稳定停在 welcome 页，未驱动跳转。两次启动间隔 28 秒均为同一结果，变量只有构建模式。

影响面：`devSeed` 是调试参数，生产启动不携带，因此**不影响正式发布包的功能**；但会使 release 包下的设备截图验收（依赖 seed 直达 home）失效——如需在 release 包上做视觉验收，改用 `devecocli ui click` 导航。

> **更正（2026-10-09 实测，四组对照实验）**：上述「debug 生效 / release 失效」的二分**机制记录有误**。真正变量不是构建模式，而是 `testMode=sandbox`：
>
> | 包 | 启动参数 | 落地页 |
> | --- | --- | --- |
> | release | `devSeed` | 登录页 |
> | debug | `devSeed` | 登录页 |
> | debug | `testMode sandbox` + `devSeed` | **首页（注入成功）** |
> | release | `testMode sandbox` + `devSeed` | 登录页 |
>
> 即：`devSeed` 必须配 `testMode=sandbox` 才生效（AGC 真实接线后 seed 的沙盒登录态才有意义），而 `testMode` 被 `isDebuggablePackage()` 门禁限制在 debug 包（`entry/src/main/ets/features/pencil/pages/PencilSplashPage.ets:122`）⇒ **release 包无论如何都注入不了演示数据**。另注：`--ps` 需**重复书写**（`--ps k1 v1 --ps k2 v2`），写成 `--ps k1 v1 k2 v2` 会被 aa 参数解析器拒绝。
>
> 完整实验记录与云真机造数替代路径见 `docs/release/cloud-debug-automation.md` §5。

### 注意事项

- `build-profile.json5` 的签名配置含本机绝对路径（`C:\Users\<user>\.ohos\config\...`）与加密密码。**更正（2026-10-02 核实）**：该内容已随 HEAD 入库（`git show HEAD:build-profile.json5` 实证含完整 `signingConfigs`；工作树该文件与 HEAD 无差异）——与「签名材料不入库」取向存在冲突，处置决策见 §11（已选定方案甲）。团队与 CI 环境应各自执行 `devecocli signature generate`；门禁在干净环境下判 FAIL 属预期（确无签名材料）。
- 签名材料本体（`.p12` / `.cer` / `.p7b`）位于仓库外，且 `.gitignore` 已排除相关扩展名。


### 10.1 混淆后的功能冒烟（2026-09-13，回应审查发现）

审查指出 `entry/obfuscation-rules.txt` 启用了 4 项破坏性选项（`-enable-property-obfuscation` / `-enable-toplevel-obfuscation` / `-enable-filename-obfuscation` / `-enable-export-obfuscation`），而 release 包此前只验过冷启动，存在 built ≠ wired ≠ effective 的风险。据此补测——全部在**已签名 release 包**（`entry-default-signed.hap`，混淆开启）上执行：

| 测项 | 方法 | 结果 |
|---|---|---|
| 冷启动 | `aa start` 不带 seed | 落首页，正常渲染 |
| Tab 路由 | 点 计划(412,2640) / 我的(1155,2640) | 分别渲染「当前计划」「当前 0/0 天」、profile（林/谱尼） |
| 子页 pushUrl | profile → 设置(1191,399) / 身体数据(350,2446) / 动作库(970,2446) | 分别渲染「设置」「身体数据」「动作库」 |
| 冷启动后重渲染 | force-stop → start → 进 profile | 正常 |
| **持久化往返** | 改「周开始日」→ 截图 A → force-stop → 重启 → 回到同屏 → 截图 B → 逐像素比对 | 尺寸一致；差异 bbox 仅 `(143,68,184,120)`（状态栏区域）；平均通道差 **0.03** → 设置保持 |

**结论**：
- `-enable-filename-obfuscation` **未打断**字符串形式的路由名（tab 切换与 `pushUrl` 子页跳转均正常）。
- `-enable-property-obfuscation` **未破坏** preferences 的 JSON 字段名往返（设置改动能跨冷启动保持）。

**仍未覆盖**（在 release 包上属未验证）：训练流（preview → active → complete）、备份导入导出、以及 ohosTest 在 release 变体下的运行（ohosTest 产物是 debug 构建，不适用）。

> 配套门禁：`tools/check-release-readiness.mjs` 已新增 `release-obfuscation` 检查项——未找到 release 块、`enable` 非 true、或规则文件缺失均判 FAIL。此前该脚本对混淆开关**零覆盖**（`grep -c obfuscation` = 0），`enable` 回退为 false 也会 PASS。

## 11. `build-profile.json5` 签名配置的处置（决策待定，含两种方案）

### 11.1 现状（可复核）

- `build-profile.json5` **受版本控制追踪**：`git ls-files --error-unmatch build-profile.json5` 命中。
- **更正（2026-10-02 核实）**：`signingConfigs[0].material`（含本机绝对路径 `C:\Users\19308\.ohos\config\...cer / .p7b / .p12` 与口令密文字段 `storePassword` / `keyPassword`）**已入库**——`git show HEAD:build-profile.json5` 实测含完整签名配置，且工作树该文件与 HEAD 无差异（`git status --porcelain build-profile.json5` 为空）。此前「HEAD 版本为空数组 / 改动仅存在于工作区」的记录已失真；该文件最后一次变更在提交 `d263246`（2026-09-28）。
- `.gitignore` 已排除 `/signature/`、`*.p12` / `*.cer` / `*.p7b` / `/local.properties`，取向是「本机配置不入库」；但 **`build-profile.json5` 本身不在 `.gitignore` 内**（`grep -n build-profile .gitignore` 无命中），且已被追踪。

> 密文不等于零风险：口令字段为加密口令（非明文），但密文与密钥库文件同时泄露时仍扩大攻击面；本机绝对路径也会暴露开发者账号名与目录结构。

### 11.2 冲突点

`build-profile.json5` 同时扮演两个互斥角色：它是 hvigor 必需的**入口配置**（本应入库、可审查），又被 `devecocli signature generate` **原地写入本机敏感信息**（不应入库）。二者需要一条明确规则。

### 11.3 方案甲：仓库保持「无签名 / 可解析」形态，本机配置不入库

做法：

- 入库的 `build-profile.json5` 只保留 `signingConfigs: []` 及 products / buildModeSet / strictMode 等可入库结构；
- 本机每次 `signature generate` 后的改动不提交——提交前 `git restore build-profile.json5`，或本机执行 `git update-index --skip-worktree build-profile.json5` 让本机改动默认不进 diff。

代价：

- 依赖人工纪律或本地 git 配置；`git add .` / `git add -A` 会误带入本机路径与口令密文；
- 干净 clone 与 CI 环境跑 `check-release-readiness.mjs` 必然 FAIL（语义正确：确无材料），无法「零操作」产出 signed 包；
- `--skip-worktree` 会掩盖上游对 `build-profile.json5` 的真实改动，需团队就「谁能改根配置」达成约定。

### 11.4 方案乙：将 `build-profile.json5` 移出版本控制，仓库改存模板

做法：

- `git rm --cached build-profile.json5` + 在 `.gitignore` 增加 `build-profile.json5`；
- 仓库改存 `build-profile.example.json5`（`signingConfigs: []` 占位），开发者复制为 `build-profile.json5` 后再由 `signature generate` 或手填。

代价：

- 丢失对根配置（products / buildModeSet / strictMode）的版本追踪与代码审查——此后的根配置变更不再进 diff，回归风险上升；
- 需持续维护 example 模板与真实文件的同步，`signature generate` 的重写行为会让模板持续漂移；
- 每个开发环境与 CI 都必须从模板重建；`build-profile.json5` 缺失会使 hvigor 构建直接失败，模板机制必须保证「先复制再构建」；
- 新人上手与故障定位成本上升。

### 11.5 两方案共同的不变量

- 签名材料本体位于仓库外，其扩展名已被 `.gitignore` 覆盖；
- 无论选哪个方案，都**不得**把 `signingConfigs` 中的本机路径与本机口令提交进仓库；
- 干净环境门禁判 FAIL 属预期，不是缺陷。

### 11.6 决策（2026-10-02 回填）

**已选定：甲**（仓库保持「无签名 / 可解析」形态，本机配置不入库；1.1.0 上架推进计划采纳）。理由：不破坏根配置的版本追踪与可审查性（乙的已知代价）；当前入库内容为加密口令密文 + 本机路径，材料本体未入库，风险评级低—中，历史不改写。

执行动作（发布收尾期）：

1. 在提交发布材料切换前，先以「无签名 / 可解析」形态提交 `build-profile.json5`（恢复至不含本机敏感字段），本机用 `git update-index --skip-worktree build-profile.json5` 保持带签名配置的构建能力；
2. 提交纪律：禁止 `git add .` / `git add -A` 带入 `build-profile.json5` 的本机改动；
3. 干净 clone / CI 环境各自 `devecocli signature generate`（门禁 FAIL 属预期）。

## 12. 上架材料待办清单（release closeout）

下表汇总上架前必须就位的材料与当前缺口。**已就位的部分不代表可提交**——缺口列出的项目未清零前，不应宣称可上架。

| # | 材料 | 当前状态 | 缺口 / 阻塞 | 落点 |
| --- | --- | --- | --- | --- |
| 1 | 隐私政策 | 正文已具备；应用内展示已接线（LegalDocPage + rawfile 副本） | **已闭环**（2026-10-10 核实）：开发者主体 / 联系邮箱已填；品牌名已统一为「菲特（FitTracker）」 | `docs/legal/privacy-policy.md` 第十一节 |
| 2 | 用户协议 | 正文已具备；应用内展示已接线（同上） | **已闭环**（同 #1） | `docs/legal/user-agreement.md` 第十节 |
| 3 | 应用市场截图 | 规格与清单已定义 | 实拍待 release 签名包 + 目标设备（**可用云调试远程真机**，无需物理设备；手动操作手册见 `docs/release/cloud-debug-automation.md`） | `docs/release/store-listing-screenshot-checklist.md` |
| 4 | 应用身份（bundleName / vendor） | 已落地：`com.earthrhythm.fittracker` / `EarthRhythm` | AGC 应用条目需在控制台创建（仓库外；调试 profile 已含 app-identifier） | `AppScope/app.json5` |
| 5 | 已签名 release 包 | 本机已实测产出（见 §10）；1.1.0 版本号已写回（`1.1.0` / `1001000`） | 发布材料切换后重构建；团队 / CI 环境各自 `devecocli signature generate` | `build-profile.json5`（处置见 §11） |
| 6 | 混淆实测 | 冷启动 / Tab / 子页 / 持久化往返已冒烟（见 §10.1）；1.1.0 JSON 边界白名单已补齐（`14a68fb`，86 项） | 训练流、备份导入导出在 release 包上未覆盖；1.1.0 新增 JSON 链（云同步/会话/草稿）待最终 release 包复测 | `entry/build-profile.json5`、`entry/obfuscation-rules.txt` |

### 12.1 法律文本：主体信息与品牌名（已闭环，2026-10-10）

> **本节原记载已失效并更正**：2026-10-02 记录称「开发者主体、联系邮箱均为占位符」。2026-10-10 读 `docs/legal/` 原文核实——**两处占位早已填入**（`开发者主体：EarthRhythm`、`联系邮箱：1930808767@qq.com`），md 与 rawfile 副本一致，`docs/legal/README.md` 的「上线前必须补齐」小节亦已标 `[x]`。原记载属文档漂移，按事实更正。

品牌名统一（2026-10-10，决策：主名「菲特」，法律文本用「菲特（FitTracker）」）：

| 载体 | 文件 | 改动 |
| --- | --- | --- |
| 仓库源文档 | `docs/legal/privacy-policy.md`、`user-agreement.md`、`README.md` | 7 处 `FitTracker` → `菲特（FitTracker）` |
| 应用内副本 | `entry/src/main/resources/rawfile/legal/*.txt` | 6 处 `菲特` → `菲特（FitTracker）`（改前源文档与副本已不同步） |

- 写法约定：`FitTracker` 仅作为主名的括号注记出现；指代系统「应用管理」中显示的应用名时只用「菲特」。
- 副本同步按 `docs/legal/README.md` 的约束验证：改 md 后运行 `node tools/convert-legal-docs.mjs`，输出与手工结果 **md5 逐字节相等**（`03ceef69…` / `de343ed1…`），无漂移。

## 13.（已校准，2026-10-02）welcome / login / register 三屏可达性

> 原标题：「遗留决策：welcome / login / register 三屏从启动流不可达」。
> **校准**：本节原结论已被 1.1.0 推翻——当前 `PencilSplashPage.ets` aboutToAppear 实证：未登录 → 登录 / 注册页（`StartupDecision.getInitialRoute(hasValidSession, hasGoal)`），三屏回到正常启动流（见 `docs/CHANGELOG.md` 1.1.0「启动门槛」）。原「A. 补入口 / B. 彻底移除」两方向决策随之作废。
>
> 历史留档（1.0.0 时代事实，供溯源）：自 `4d6a144`（取消启动时登录门槛）起，无登录门槛版本下三屏仅在 `getHostContext()` 返回空的异常路径可达；该状态不适用于 1.1.0+。

## 14. 发布签名落地记录（2026-10-09）

### 14.1 发布证书与 Profile（已申请，AGC 控制台可复核）

| 项 | 值 |
| --- | --- |
| 发布证书 | `fittracker_release`（生效，失效日期 2029-10-09） |
| 发布 Profile | `fittracker_release_profile`（生效，`type=release`，bundleName `com.earthrhythm.fittracker`） |
| CSR | `~/.ohos/release-keys/fittracker-release.csr`（sha256 `180ce5fa4a8bf1ed…`，EC/secp256r1 + SHA256withECDSA） |
| 签名材料归档 | `~/.ohos/release-keys/`：`fittracker-release.p12` / `fittracker_release.cer`（3 证书链）/ `fittracker_release.p7b` |
| 机器密钥材料副本 | `~/.ohos/release-keys/material/`（自 `~/.ohos/config/material/` 复制） |
| 调试配置备份 | `~/.ohos/release-keys/build-profile.debug-backup.json5` |

### 14.2 hvigor 签名口令的格式要求（**踩坑点**）

`build-profile.json5` 的 `storePassword` / `keyPassword` **不是明文口令**，必须写 DevEco 的加密串：

- 明文会被 hvigor 直接拒：`00303116`（长度 < 32）、`00303117`（长度须为偶数）—— 两条均属 `Configuration Error`，来自 `hvigor-ohos-plugin/src/utils/decipher-util.js` 的 `decryptPwd`
- 密文格式：`hex( [4B 大端 e][N B IV][密文][16B GCM tag] )`，其中 `e = 密文长度 + 16`
- 密钥派生（`materialDir` = **`dirname(storeFile)`**，即 p12 所在目录）：

  ```text
  materialDir/material/
    ├── fd/{0,1,2}/<file>   各含 1 个 16 字节文件
    ├── ac/<file>           salt（16 字节）
    └── ce/<file>           work（48 字节，被 rootKey 加密的工作密钥）
  rootKey = pbkdf2( xor(fd0, fd1, fd2, component).toString(), salt, 10000, 16, 'sha256' )
  key     = AES-128-GCM(rootKey).decrypt(work)
  component = [49,243,9,115,214,175,91,184,211,190,177,88,101,131,192,119]
  ```

- 加密脚本（**不入库**，`.rivet/` 下）：`.rivet/scratch/encrypt-pwd.cjs`
  用法：`node .rivet/scratch/encrypt-pwd.cjs <materialDir> <明文口令>`（自带 round-trip 自检）

> **推论（重要）**：签名材料必须放在**存在 `material/` 子目录的目录**下，否则 hvigor 找不到密钥材料。本仓库的落地方式是材料与 `material/` 副本同放 `~/.ohos/release-keys/`。

### 14.3 构建与发布签名验证

```powershell
devecocli build --product default --build-mode release
```

产物：`build/outputs/default/菲特-default-signed.app`、`entry/build/default/outputs/default/entry-default-signed.hap`

发布签名判据（两条都要满足）：

```bash
grep -ao '"type":"[a-z]*"' build/outputs/default/菲特-default-signed.app | head -1
# 期望： "type":"release"
grep -ao "distribution-certificate" build/outputs/default/菲特-default-signed.app | head -1
# 期望命中 distribution-certificate（而非 development-certificate）
```

### 14.4 AGC 控制台登录态复用（**避免每次重新登录**）

AGC 操作走**持久浏览器 profile**，**禁止用一次性 `--user-data-dir` 启动**（Chrome 随 bash 退出被杀 → cookie 未落盘 → 每次都要重新登录）：

- 持久 profile：`%LOCALAPPDATA%\Tianshu\TianshuData\.rivet\browser-debug-profile`
- cookie 库：`<profile>\Default\Network\Cookies`（首次人工登录后写入）
- **实测更正（2026-10-09 晚，重要）**：持久 profile 能保证**同一浏览器会话内**登录态稳定（本轮多次跨操作、跨多轮对话均未要求重新登录）；但**浏览器关闭后重开，AGC 仍会回到未登录状态**——实测证据：重开后进程 `--user-data-dir` 确实指向 `browser-debug-profile`，cookie 库存在且 40 KB（mtime 晚于上次登录），页面却显示「登录」入口。
  - **推测**（未证实）：华为账号会话 cookie 为会话级，或不随进程关闭持久化。
  - **因此**：不要把「关掉浏览器再开仍已登录」当作既定事实；需要重新登录时按 `await_login` 走一次人工登录。
- 打开方式：

  ```text
  browser_debug open { url: "https://developer.huawei.com/consumer/cn/service/josp/agc/index.html", shared_profile: true }
  ```

- 控制台表单在 `#mainIframeView` iframe 内，需穿透 iframe 取元素：
  `document.querySelector('#mainIframeView').contentDocument`
- Element-UI 控件用**完整事件序列**（`pointerdown/mousedown/pointerup/mouseup/click`）点击；纯 `.click()` 对部分控件无效
- 输入框用 `execCommand('insertText')` 才能触发 Vue 的 v-model（直接赋 `value` 只改 DOM，字数计数不动）
- **文件上传（CSR 等）无法脚本注入**——该组件会丢弃合成事件（实测：原生 setter 赋值成功、change 事件已触发，但组件不接收；且浏览器为 pipe 模式无 CDP 端口，用不了 `DOM.setFileInputFiles`）→ 需人工点「选取」
- **下载**的文件不落 Downloads，而是落在 Playwright 临时目录 `%TEMP%\playwright-artifacts-*\<guid>`，需手动归档

# 双端对等规范

> **层级**：L2 展开
> **最后核对**：2026-10-27
> **上位文档**：`AGENTS.md`（冲突以 L1 为准）
> **状态**：现行（3 项待裁决，见「已知不对称」）
> **路径基准**：两端路径均相对仓库根
> **适用端**：双端

## 为什么需要这份文档

本仓库是双端同构：鸿蒙 19 个注册页、安卓 20 个 Screen 目录，跑同一套业务。但 `apps\android\` 下此前**一份 `.md` 都没有**——安卓端改代码的人拿不到任何书面约束。

结果是「一端做了、另一端没做」类缺陷反复出现。这类缺陷单看一端看不出来：代码本身没错，错的是另一端没有对应物。本文件把对等关系显式化，并由 `check-parity.mjs` 校验文件级存在性。

## 对等清单（鸿蒙 19 个注册页 ↔ 安卓 20 个 Screen 目录）

鸿蒙侧事实源：`apps\harmony\entry\src\main\resources\base\profile\main_pages.json`
安卓侧事实源：`apps\android\app\src\main\java\com\fittracker\app\ui\screens\` 下的目录

| # | 鸿蒙页 | 安卓 Screen | 对等 |
|---|---|---|---|
| 1 | `features\pencil\pages\PencilSplashPage` | `splash\SplashScreen` | ✅ |
| 2 | `features\welcome\pages\PencilWelcomePage` | `welcome\WelcomeScreen` | ✅ |
| 3 | `features\pencil\pages\PencilLoginPage` | `auth\LoginScreen` | ✅ |
| 4 | `features\pencil\pages\PencilRegisterPage` | `auth\RegisterScreen` | ✅ |
| 5 | `features\pencil\pages\PencilHomePage` | `home\HomeScreen` | ✅ |
| 6 | `features\pencil\pages\PencilPlanPage` | `plan\PlanScreen` | ✅ |
| 7 | `features\pencil\pages\PencilPlansPage` | `plans\PlansScreen` | ✅ |
| 8 | `features\pencil\pages\PencilPlanGroupDetailPage` | `plangroup\PlanGroupScreen` | ✅ |
| 9 | `features\pencil\pages\PencilActivePage` | `active\ActiveScreen` | ✅ |
| 10 | `features\workout\pages\WorkoutCompletePage` | `complete\CompleteScreen` | ✅ |
| 11 | `features\pencil\pages\PencilReviewPage` | `review\ReviewScreen` | ✅ |
| 12 | `features\exercise\pages\ExerciseLibraryPage` | `library\LibraryScreen` | ✅ |
| 13 | `features\exercise\pages\ExerciseDetailPage` | `exercise\ExerciseDetailScreen` | ✅ |
| 14 | `features\body\pages\BodyDataPage` | `body\BodyScreen` | ✅ |
| 15 | `features\pencil\pages\PencilProfilePage` | `profile\ProfileScreen` | ✅ |
| 16 | `features\pencil\pages\PencilProfileEditPage` | `profile\ProfileEditScreen` | ✅ |
| 17 | `features\settings\pages\PencilSettingsPage` | `settings\SettingsScreen` | ✅ |
| 18 | `features\settings\pages\LegalDocPage` | `legal\LegalDocScreen` | ✅ |
| 19 | `app\PencilAppShell`（应用壳，非内容页） | `FtApp.kt`（根，非 screen 目录） | ⚠️ 见已知不对称 1 |
| — | `features\pencil\pages\PencilPreviewPage`（**非注册页**） | `workout\WorkoutPreviewScreen`（独立路由） | ⚠️ 见已知不对称 2 |
| — | **（无对应）** | `preferences\TrainingPreferencesScreen` | ⚠️ 见待裁决 1 |

## 已知不对称（豁免表）

**每条必须带「理由」与「复核方式」两列**，`check-parity.mjs` 会校验这两列非空——空白的豁免等于没写。

| # | 项 | 不对称内容 | 理由 | 复核方式 |
|---|---|---|---|---|
| 1 | 应用壳 | 鸿蒙 `app\PencilAppShell.ets` vs 安卓 `FtApp.kt` | 各自框架的根壳写法不同（ArkUI `bindContentCover` vs Compose NavHost） | 两端启动链路人工核对：冷启动 → 主壳 → 四 Tab |
| 2 | 训练预览 | 鸿蒙 `bindContentCover` 全模态 vs 安卓独立路由 | 框架能力差异 | 交互一致性人工核对：从首页进入预览 → 返回后状态保持 |
| 3 | 训练偏好 | 安卓 `preferences\TrainingPreferencesScreen` 为独立屏，鸿蒙侧**无对应物** | 2026-10-27 实测：`grep '训练偏好\|TrainingPreference\|trainingPreference'` 于 `apps\harmony\entry\src\main\ets` **零命中**——不是内嵌在设置页，是尚未实现 | 鸿蒙侧重现该能力后从本表移除；在此之前安卓侧训练偏好改动**不需要**双端同步 |

## 裁决记录（Wave 3 已落定）

| # | 问题 | 为什么现在不能定 | 裁决方式 |
|---|---|---|---|
| 1 | ~~`TrainingPreferencesScreen` 在鸿蒙侧的对应物~~ | **已裁决 2026-10-27**：鸿蒙侧无对应实现（grep 零命中），已移入「已知不对称」表第 3 行 | — |
| 2 | ~~`plans\` / `plan\` 与鸿蒙两页的对应关系~~ | **已裁决 2026-10-27**：读两个文件的 KDoc 确认——`plan\PlanScreen`（原型 `fittracker-plan.html`，底部 tabbar 由壳层提供，是一级 Tab）↔ `PencilPlanPage`；`plans\PlansScreen`（原型 `fittracker-plan-detail.html`，`onBack` 返回，二级页）↔ `PencilPlansPage`；`plans` 的 `onOpen` → `planGroup?planId=` ↔ `PencilPlanGroupDetailPage` | — |
| 3 | 安卓侧是否已有 Kotlin 风格工具链（ktlint / detekt） | 只读了 `build.gradle.kts` 的依赖，未见相关插件 | grep `ktlint\|detekt` 于 `apps\android\`；若无则记为「安卓侧无代码风格门禁」缺口 |

## 身份与字段对齐（已确认事实）

来源：`apps\android\app\build.gradle.kts` 注释原文。

| 项 | 值 | 说明 |
|---|---|---|
| 上架身份 | `applicationId = "com.earthrhythm.fittracker"` | 「与鸿蒙侧 bundleName（`AppScope/app.json5`）统一 —— 备案 / 应用市场登记 / 签名标识都用它」 |
| 代码包名 | `namespace = "com.fittracker.app"` | 只决定 R 类与 BuildConfig 包名，**与上架身份无关**，勿混 |
| SDK | `minSdk = 24` / `targetSdk = 37` / `compileSdk = 37` | — |
| 微信 AppID 字段 | `wechat.appId`（local.properties）↔ 鸿蒙 `thirdparty.json` 的 `wechatAppId` | 「语义一致（同一开放平台应用的同一 AppID）」 |
| QQ AppID 字段 | `qq.appId`（local.properties）↔ 鸿蒙 `thirdparty.json` 的 `qqAppId` | QQ 回调 scheme 经 `manifestPlaceholders` 注入，不硬编码进 manifest |
| 云端配置 | `supabase.url` / `supabase.publishableKey`（local.properties）↔ 鸿蒙 `agconnect-services.json` | 两者均不入库（`.gitignore`） |

`check-parity.mjs` 校验 `applicationId` 与鸿蒙 `bundleName` 一致，不一致即红。

## 改动时的同步要求

1. **用户可见行为改动，双端都要落。** 只做一端的，提交信息必须写「仅 \<端\>」并说明原因（例：「仅鸿蒙：安卓侧待 Compose 版本升级后跟进」）。
2. **新增字段**：追四条链——写入 → 持久化 → 备份包 → 同步白名单 hash 视图，另一端同步。不在 hash 视图里则变更检测对该域失明。
3. **新增屏**：两端同时建，或在本文件的对等清单里登记为「单端独有」并给理由。
4. **合规文档**：字段进同步链路后，隐私政策两份副本（`docs\legal\privacy-policy.md` + `rawfile\legal\privacy-policy.txt`）都要改。
5. **视觉 token**：两端各自维护（鸿蒙 `DesignTokens.ets` / 安卓 `ui\theme\DuTokens.kt`），改配色要两端一起改。

## 本文的验证边界

- 对等清单由 `check-parity.mjs` 校验**文件级存在性**：页面文件存在、Screen 目录存在、身份字段一致
- **行为等价无法静态验证**——同一功能两端交互是否一致，必须设备侧人工核对
- 待裁决 3 项已于 2026-10-27 全部裁决（见上表），本文件的对照表为**已确认契约**，不再是待定快照

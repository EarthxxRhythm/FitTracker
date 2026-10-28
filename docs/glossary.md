# 菲特 术语与口径总表

> **层级**：L2 展开
> **最后核对**：2026-10-28
> **上位文档**：`AGENTS.md`（L1，冲突以 L1 为准）
> **状态**：现行
> **路径基准**：表中路径均相对仓库根；标注 `cd apps/harmony` 之后的路径相对鸿蒙工程根
> **适用端**：双端

## 为什么需要这份文档

同一件事在仓库里有多种说法时，读者无法判断哪个是真的——而且错的那种通常看起来更"官方"。

2026-10-28 实测到的分裂（每一条都是可复现的）：

- 云后端：`AGENTS.md` 已改定为自托管 Supabase，但 `contracts` 仍写「两端后端不同源（AGC / Supabase）」，`dual-platform-parity.md` 把鸿蒙凭据文件写成 `agconnect-services.json`
- 术语：两端 Tab 文案都是「回顾」，但代码注释与文档共 109 处写「复盘」；`engineering-standards.md` 甚至把「训练复盘」「训练回顾」并列成两个页面标题
- 同一屏内自相矛盾：Tab 叫「回顾」，徽章叫「首次复盘」
- AGC 一词同时指两件完全不同的事：**发布/云调试平台**（仍在使用）与**云后端**（已整体移除）——不区分就无法判断某句 AGC 是事实还是历史

所以本文是**口径的单一真源**：其余文档描述事实时引用本文，与本文冲突的以本文为准（本文与 `AGENTS.md` 冲突时以 `AGENTS.md` 为准）。

## 一、事实口径表

同一项只允许一种说法。**失效写法**列中的形态出现在现行范围（见 §3）即为口径错误。

| 项 | 唯一权威值 | 依据 | 失效写法 |
|---|---|---|---|
| 产品名 | 中文正文用**菲特**；英文标识用**FitTracker**（仓库名、类名、文档英文标题） | 本文 §4 | 同一句混用「菲特 / FitTracker」 |
| 端名 | **鸿蒙** / **安卓**（中文正文）；目录为 `apps\harmony` / `apps\android` | `AGENTS.md` 文件头 | 「HarmonyOS 端 / Android 端」作为端名 |
| 云后端 | **自托管 Supabase（PostgREST）+ 沙盒降级**，二态 | `CloudEnvironment.ets:17` `type CloudBackend = 'supabase' \| 'sandbox'` | 「AGC 云数据库」「AGC 认证服务」「sandbox / supabase / agc 三态」 |
| 鸿蒙云端凭据 | `apps\harmony\AppScope\resources\rawfile\supabase.json`（不入库） | `SupabaseConfig.ets:22` `SUPABASE_CONFIG_FILE` | 把 `agconnect-services.json` 当作现行凭据文件 |
| 安卓云端凭据 | `apps\android\local.properties` 的 `supabase.url` / `supabase.publishableKey` → `BuildConfig.SUPABASE_URL` / `BuildConfig.SUPABASE_PUBLISHABLE_KEY` | `apps/android/app/build.gradle.kts:18,62` | 说安卓侧走 AGC |
| 快照表 | `public.snapshots`（`user_id` uuid PK / `payload` jsonb / `updated_at` timestamptz），两端同表同 `user_id` | `supabase-sync-setup.md` §1 | 「两端后端不同源、云数据互不可见」 |
| 时间单位 | 全库时间戳统一 **epoch 毫秒**；出网 ISO8601 UTC | `SupabaseCloudSnapshotStore.ets` 头部 | 秒 / 本地时区字符串 |
| 上架身份 | `com.earthrhythm.fittracker`（两端一致，`check-parity` 校验） | `dual-platform-parity.md`「身份与字段对齐」 | 把代码包名当作上架身份 |
| 代码包名 | `com.fittracker.app`（只决定 R 类与 BuildConfig 包名） | `apps/android/app/build.gradle.kts` `namespace` | — |
| 页面事实源 | `apps\harmony\entry\src\main\resources\base\profile\main_pages.json` | `AGENTS.md` | 在文档里复制页面清单当作事实源 |
| 路由事实源 | `apps\harmony\entry\src\main\ets\app\AppRoutes.ets` | 同上 | 硬编码路由字面量 |
| 构建工具 | 鸿蒙一律 **devecocli**；不裸跑 `hvigorw` | `AGENTS.md`「提效约定」 | 把 `hvigorw assembleHap` 当推荐命令 |
| preferences store 前缀 | `fit_tracker_`，写入后必须 `flush()` | `common/services/AGENTS.md` | 裸 store 名 |
| 1RM 公式 | **Epley**（`重量 × (1 + 次数 / 30)`） | `AGENTS.md` 项目概览 | 混用 Brzycki 等其它公式 |
| AGC 的两种指代 | **AGC 平台**＝分发/云调试/签名/提审控制台（仍在使用）；**AGC 云后端**＝认证 + 云数据库（2026-10-28 已整体移除） | `CloudEnvironment.ets:12-13` 变更记录 | 只说「AGC」不区分是哪一种 |

## 二、术语表

**标准词**是唯一允许的写法；**禁用同义词**出现在现行范围即为 GL-01 红灯。

| 标准词 | 禁用同义词 | 含义 | 依据（真源） |
|---|---|---|---|
| **回顾** | 复盘 | Review 页：训练完成后按周/月回看训练量、PR、体重变化的一屏 | `BottomTabBar.ets:42` `createBottomTabItem('review', '回顾', false)`；`FtRoutes.kt:179` `tabLabel = "回顾"` |
| **首页** | 主页、Home | 主壳第一个 Tab | `PencilHomePage` / `home\HomeScreen` |
| **训练计划** | 方案、计划方案 | 一组按天编排的动作安排 | `TrainingPlanService` / `PlanEngine` |
| **计划组** | 计划分组、计划集 | 多个计划的容器 | `PencilPlanGroupDetailPage` / `plangroup\PlanGroupScreen` |
| **训练预览** | 预览页、开始前预览 | 开始训练前的覆盖层（鸿蒙为全模态，不是路由页） | `PencilPreviewContent` |
| **训练执行** | 训练中、进行中 | 逐组记录的一屏 | `PencilActivePage` / `active\ActiveScreen` |
| **训练组 / 次数 / 重量** | 组、rep、kg 混写 | 计数的三个基本量 | `AGENTS.md` 项目概览 |
| **动作库** | 内容库 | 动作条目集合（用户视角） | `ExerciseLibraryPage` / `library\LibraryScreen` |
| **动作目录** | — | 同一集合在**代码层**的读取 API 与仓储（与「动作库」区分：前者是界面，后者是数据通道） | `ExerciseService` / `ContentRepository` |
| **训练会话** | 训练记录、workout session（中文正文里） | 一次训练落库的记录单元 | `WorkoutSessionService` / `SessionRepository` |
| **快照** | 备份包（不同概念） | 云端整包数据单元（`CloudSnapshot`） | `CloudSnapshotStore.ets` |
| **备份包** | 快照（混用） | **本地**导出/导入的数据包 | `UserDataBackupService` |
| **沙盒** | — | 内部实现名：无云端配置时的本地降级后端 | `CloudBackend = 'sandbox'` |
| **演示模式** | — | **用户可见**文案：沙盒运行时的界面提示 | UI 文案 |
| **云同步** | 数据同步、同步 | 登录后恒定自动的整包快照同步（无开关、无独立设置页） | `CloudSyncService`；`AGENTS.md` |
| **身体数据** | 体重页、体征 | 体重/围度记录屏 | `BodyDataPage` / `body\BodyScreen` |
| **个人页** | 我的、Profile | 主壳第四个 Tab | `PencilProfilePage` / `profile\ProfileScreen` |

**改名的边界**：`Review*` 类名、`review` 路由名、`FtReviewModel` 等标识符**保持英文不动**——`Review` 与标准词「回顾」语义一致，改名只会制造无收益的 diff。

## 三、口径分层规则

判断某句话是否"违规"之前，先判断它属于哪一层。**这是本表能落地的前提**：历史材料里的 AGC 是事实记录，不是错误。

| 层 | 范围 | 允许什么 | 由谁检查 |
|---|---|---|---|
| **现行** | `AGENTS.md`、`docs/spec-registry.md` 中状态为「现行」的文档、`apps/*/src/{main,test,ohosTest}/**`、`README.md`、`CONTRIBUTING.md`、`contracts/**` | 只能用 §1 的权威值与 §2 的标准词 | `check-glossary`（GL-01/02/03） |
| **历史** | `docs/archive/**`、`docs/CHANGELOG.md`、`docs/closeout/**`、`docs/superpowers/specs/**`、`docs/release/software-copyright*`、`docs/release/gongan-beian-form.md`（对外申报/备案文本，按提交时措辞留档）、`docs/process/tasks.*`（流程队列快照与其说明） | 保留原文；可写 AGC 云后端、可写「复盘」 | 不检查 |
| **平台限定** | 任意文档中描述**发布流程**的句子 | `AGC 控制台`、`AGC 云调试`、`AGC 提审`、`AppGallery Connect`、`agconnect-services.json.disabled`（作为历史残留） | GL-02/GL-03 放行 |
| **豁免措辞** | 任意行 | 同一行含 `已移除` / `已被取代` / `历史` / `不再启用` / `作废` 即放行——用于"解释历史"的句子 | GL-01/02/03 放行 |

**跨层引用的写法**：历史文档被现行文档引用时，引用处必须带层标注，例如「`docs/cloud/cloud-setup.md`（已被取代，仅作排错参考）」。

**扫描面与登记的关系**：GL 脚本的「现行文档」取自注册表状态为「现行」的行 + `FIXED_DOCS`（`AGENTS.md` / `README.md` / `CONTRIBUTING.md`）。**未在注册表登记的 docs 不在扫描面内**——不是允许违规，而是尚未纳入管辖。要让某份文档受检，把它登记进 `docs/spec-registry.md` 并补齐 6 行头部即可，脚本无需改动。

## 四、语言与文案口径

| 对象 | 规则 |
|---|---|
| 规范文档正文 | **中文**。唯一的例外是代码块、表格中的路径与标识符 |
| 代码标识符 | **英文**（类名、方法名、字段名、路由 key） |
| 用户可见文案 | **中文**，且**两端逐字一致**（同一屏、同一状态、同一标点） |
| 英文技术名词首次出现 | 给中文括注，如「自托管 Supabase（PostgREST）」；此后可直接用英文 |
| 文档标题 H1 | `# 中文标题`；`AGENTS.md` 一类约定文件名保持英文 |

## 五、机器闸门

规则由 `apps/harmony/tools/check-glossary.mjs` 实现，接入 `check-gates.mjs`（在 `spec registry` 之后、`code rules` 之前）。规则 id 与本文同名章节互指：文档说「为什么」，脚本说「怎么查」。

| rule id | 约束 | 判据 | 豁免 |
|---|---|---|---|
| GL-01 | 术语唯一 | 现行范围内出现「复盘」 | 历史层；同行含豁免措辞 |
| GL-02 | 云后端事实 | 现行范围内「AGC」同行含 `云数据库` / `云后端` / `云服务` / `认证服务` | 平台限定的平台语境；同行含豁免措辞 |
| GL-03 | 凭据文件名 | 现行范围内 `agconnect-services.json` 同行不含失效措辞 | 同行含豁免措辞 |
| GL-04 | 登记 | 本文必须登记在 `docs/spec-registry.md` 且状态为「现行」 | 无 |

**规则定义处豁免**：本文与 `check-glossary.mjs` 自身必须指名禁用词（否则无法定义规则），故代码里的 `RULE_DEFINITION_FILES` 对这三份文件跳过 GL-01/02/03 的用词扫描。GL-04 不受影响——本文仍须登记为现行。

**新增一条规则的门槛**：必须能同时给出「现行范围的最小复现句」与「历史层的合法对照句」，否则这条规则会误杀历史材料。

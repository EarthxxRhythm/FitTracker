# contracts 域 · 契约漂移审计台账

> **基线**：`contracts\README.md` **§0–§7**（实测 148 行）。计划原文写「§0-§6」与实际章节不符——按暂缓项 #1 决议**采纳修正**为 §0–§7，§7「已知未收敛项」纳入必读。该项修正直接产生本台账最高价值发现 C-3（§7-2 的事实基础已失效）。
>
> **来源**：10 个源文件逐条交叉核对（README 1 + 鸿蒙 4 + 安卓 5），合计 3114 行。
> **性质**：只读审计，未修改任何源码；不含「应改成什么」的设计结论。
> **git 基线**：`docs/audit/` 整目录 untracked（暂缓项 #4 决议：**采纳该事实**）。下游复核 file:line 须以**工作区磁盘**为基线，不得假设本文件已入库。

## §0 口径与方法（先声明，避免下游误读）

- **前缀**
  - `C` = `contracts\README.md`
  - `H` = `apps\harmony\entry\src\main\ets\shared\services`
  - `A` = `apps\android\app\src\main\java\com\fittracker\app\data`
  - 条目写 `H\CloudSyncService.ets:108`、`A\sync\CloudSyncService.kt:28`、`C:142`。
- **规模基线（`wc -l` 实测）**：

  | 文件 | 行数 | | 文件 | 行数 |
  |---|---|---|---|---|
  | `C`（README） | 148 | | `A\model\BackupPackage.kt` | 58 |
  | `H\UserDataBackupService.ets` | 693 | | `A\service\backup\UserDataBackupService.kt` | 436 |
  | `H\SupabaseCloudSnapshotStore.ets` | 384 | | `A\sync\LocalSnapshotStore.kt` | 293 |
  | `H\CloudSyncService.ets` | 495 | | `A\cloud\SupabaseCloudSnapshotStore.kt` | 216 |
  | `H\CloudSnapshotStore.ets` | 143 | | `A\sync\CloudSyncService.kt` | 248 |
  | | | | **10 文件合计** | **3114** |

- **锚点纪律（暂缓项 #5 决议：采纳）**：每条 `file:line` 以「**符号名 + 行号**」双载。仅行号的引用不可抽验，出现即记漂移（§3）。§5 给可执行抽验命令，gate 判据 = 该行文本仍含声明的符号。
- **问题类型（暂缓项 #6 决议：采纳）**：**不凑满五型**。本域实际捕获 4 类：契约漂移（`C-*`）、行号漂移（`L-*`）、魔法值散落（`M-*`）、双端模块边界不对称（`B-*`）。「越界依赖 / 重复实现」在纯契约源文件里 **0 命中**——不制造条目。

## §1 契约条款 ↔ 双端实现逐条核对

| ID | 契约条款 | 声明锚点 | 鸿蒙实现 | 安卓实现 | 判定 |
|---|---|---|---|---|---|
| K-1 | §1 备份包 9 字段 + `bodyRecords` / `bodyMeasurements` 可选语义 | `C:21`–`C:38` | `H\UserDataBackupService.ets:29`（`interface UserDataBackupPackage`）、可选域 `:41`/`:43` | `A\model\BackupPackage.kt:23`（`data class`）、可选域 `= null` 默认值 | ✅ 字段名 / 顺序 / 可空语义逐条一致 |
| K-2 | §2 云信封字段集 | `C:44`–`C:56`（表 5 字段） | `H\CloudSyncService.ets:68`（**11 字段**） | `A\sync\LocalSnapshotStore.kt:44`（**11 字段**） | ❌ **C-1**：契约缺 6 字段 |
| K-3 | §3 云快照 5 字段 | `C:58`–`C:72` | `H\CloudSnapshotStore.ets:15` | `A\sync\CloudSyncService.kt:68` | ✅ 一致（`schemaVersion` 均默认取常量） |
| K-4 | §3 `deviceTag` 固定 `local-device` | `C:67` | `H\CloudSyncService.ets:419`（`resolveDeviceTag`）、`H\SupabaseCloudSnapshotStore.ets:46` | `A\sync\CloudSyncService.kt:151`（`DEVICE_TAG`）、`A\cloud\SupabaseCloudSnapshotStore.kt:84` | ✅ 值一致；⚠️ 同一字面量 4 处各自持有 → **M-1** |
| K-5 | §3 Supabase 表映射 `snapshots(user_id/payload/updated_at)` | `C:68`–`C:70` | 文件名与列名映射仅由 `H\SupabaseCloudSnapshotStore.ets:45`–`:46`、`:354`–`:355` 传参点确认；**REST 端点与列名未逐行核读** | `A\cloud\SupabaseCloudSnapshotStore.kt:27`–`:38`（含 GET/POST 端点注释）、`:60`、`:101`–`:103` | ⚠️ 安卓侧已核；鸿蒙侧**部分核对**（见 §6 未覆盖） |
| K-6 | §4 决策矩阵六分支 + `>` 严格大于 | `C:74`–`C:90` | `H\CloudSyncService.ets:108`（`decideSyncAction`） | `A\sync\CloudSyncService.kt:173` | ✅ 六分支逐条一致，末行 `remoteUpdatedAt > lastSyncAt ? conflict_pull : push` 两端同构 |
| K-7 | §4 hash 输出 `<摘要>_<长度十六进制>` | `C:92`–`C:94` | `H\CloudSyncService.ets:320`（`hashPayload`）、`:326`（`djb2Hex`） | `A\sync\LocalSnapshotStore.kt:142`（`hashPayload`）、`:148`（`djb2Hex`） | ✅ 格式与 djb2 32 位环绕逐位一致 |
| K-8 | §4 canonical 视图（字段序） | `C:92` 仅散文，**无字段清单** | `H\CloudSyncService.ets:366`（`normalizePayloadForHash`），内层 8 字段 / 外层 10 字段 | `A\sync\LocalSnapshotStore.kt:166`（同函数），内层 8 / 外层 10，同序 | ⚠️ **C-2**：两端实现一致，契约未声明 |
| K-9 | §4 跨端字节级一致性未强制（已知接受） | `C:96`–`C:97` | `H\LocalSnapshotStore` 语义对应的注释在 `LocalSnapshotStore.kt:157` 段（安卓侧声明） | 同左 | ✅ 与实现注释一致 |
| K-10 | §5 导入合并三策略 | `C:100`–`C:116` | `H\UserDataBackupService.ets:113`（`importPackage`）、`:199`（`mergeSessions`）、`:218`（`normalizePlanSelection`） | `A\service\backup\UserDataBackupService.kt:126`、`:214`、`:241` | ✅ 语义逐条一致（按 `sessionId` 就地替换 / 目标以包为准 / 计划整块替换 + 指针归一）；锚点失效 → **L-5** |
| K-11 | §6 三常量值均 `1` | `C:118`–`C:126` | `H\UserDataBackupService.ets:17`、`H\CloudSnapshotStore.ets:12`、`H\CloudSyncService.ets:45` | `A\model\BackupPackage.kt:13`、`A\sync\CloudSyncService.kt:28`、`:31` | ✅ 六处全为 `1`；§6 表格缺鸿蒙列 → **C-4**，安卓行号失效 → **L-1/L-2** |
| K-12 | §6 硬相等校验（有限数 + `!= 1` 拒绝） | `C:128`–`C:130` | `:275`（`!== BACKUP_SCHEMA_VERSION`）、`:334`（`isFiniteNumberValue` + `!==`） | `A\service\backup\UserDataBackupService.kt:314`（`!= BACKUP_SCHEMA_VERSION`）+ `:296`–`:313` 有限数守卫 | ✅ 一致，两端均「不做兼容尝试」 |
| K-13 | §7-1 两端后端同源 / 同一 `public.snapshots` | `C:139`–`C:140` | `H\SupabaseCloudSnapshotStore.ets`（存在，384 行） | `A\cloud\SupabaseCloudSnapshotStore.kt`（存在，216 行） | ✅ 与实现一致 |
| K-14 | §7-2「`updateSession` 无生产调用方，故实际不会触发」 | `C:142` | — | `A\service\WorkoutRepository.kt:72` 被 `apps\android\...\ui\screens\complete\CompleteScreen.kt:209` **实际调用** | ❌ **C-3**：断言证伪 |
| K-15 | §7-3 hash 跨端不一致接受 | `C:143` | `H\CloudSyncService.ets:366` 段注释 | `A\sync\LocalSnapshotStore.kt:157` 段注释 | ✅ 一致 |

## §2 契约漂移台账（`C-*`）

| ID | 类型 | 现象 | 证据（file:line） | 影响面 | 优先级 |
|---|---|---|---|---|---|
| **C-1** | 契约漂移 | **§2 信封字段表只声明 5 字段，实际双端各传 11 字段**。缺 `heightCm` / `gender` / `birthYear` / `experience` / `avatarImage` / `avatarImageHash`（后者是头像变更检测的唯一入 hash 载体） | 契约：`C:48`–`C:54`；鸿蒙：`H\CloudSyncService.ets:68`–`:97`；安卓：`A\sync\LocalSnapshotStore.kt:44`–`:77` | 契约真源不承载实际传输面——改任一字段时无法依 README 判断双端是否对齐；`avatarImageHash` 缺失尤其危险（漏改会让头像变更不进 hash → 头像永不同步且无报错） | **高** |
| **C-2** | 契约漂移 | **§4 只说「按固定字段序重排」，未声明 canonical 视图字段清单**。实际视图内层 8 字段（+`bodyRecords` / `bodyMeasurements`）、外层 10 字段（+`heightCm` / `gender` / `birthYear` / `experience` / `avatarImageHash`） | 契约：`C:92`；鸿蒙：`H\CloudSyncService.ets:366`–`:414`；安卓：`A\sync\LocalSnapshotStore.kt:166`–`:212` | 两端现一致，但**新增字段必须在两端同改且同序**才不产生「本端变、云端不变」的静默失明。README 无清单 → 无从校验顺序 | **高** |
| **C-3** | 契约漂移 / **未收敛项事实基础失效** | **§7-2 声称「Android 侧 `WorkoutRepository.updateSession` 无生产调用方（记录只增不改），故实际不会触发」——已证伪**：`CompleteScreen.kt:209` 在 RPE 保存路径上调用 `WorkoutRepository.updateSession` | 断言：`C:142`；被调方：`A\service\WorkoutRepository.kt:72`；调用方：`apps\android\app\src\main\java\com\fittracker\app\ui\screens\complete\CompleteScreen.kt:209` | §7 把「同一条记录两端都改 → 导入包胜出 → 本端修改被替换」定性为不会发生。实际路径存在：一端改 RPE、另一端同步 → 按 §5 就地替换，本端修改静默丢失且无提示 | **高** |
| **C-4** | 契约漂移 | **§6 表格只有「位置（Android）」一列**，而章节标题写「三个独立常量，两端各持一份」——鸿蒙侧三处位置全缺 | 契约：`C:120`–`C:126`；鸿蒙实际：`H\UserDataBackupService.ets:17`、`H\CloudSnapshotStore.ets:12`、`H\CloudSyncService.ets:45` | 升版本时改完安卓容易漏鸿蒙：漏则旧端拒绝新端数据（§6 推论本已言明后果，却未给出对端定位锚） | 中 |
| **C-5** | 契约漂移 | **`UserDataBackupImportResult` 双端结构不对称**：鸿蒙仍带 `statusText: string`，安卓已移除（Wave 8 i18n 移到 `values/strings_backup.xml`）。契约全文未声明该类型结构 | 鸿蒙：`H\UserDataBackupService.ets:46`–`:56`（`statusText` 在 `:55`）；安卓：`A\model\BackupPackage.kt:48`–`:57`（无该字段） | 该类型不跨端序列化，故不破坏互操作；但双端同名字段集不同，按契约无法判断「哪边是对的」 | 中 |
| **C-6** | 契约漂移（弱） | §2 的「源」引用只给文件名、不给行号（§1/§4/§5 均给行号）。同一文档锚点粒度不一致 | 契约：`C:56`（`apps/android/.../data/sync/LocalSnapshotStore.kt` 无 `:line`） | 抽验时无法用统一 gate 覆盖（§5） | 低 |

## §3 行号漂移台账（`L-*`：README 声明的 file:line 已与源码不符）

| ID | 契约声明 | 实际 | 偏差 | 抽验符号 |
|---|---|---|---|---|
| **L-1** | `C:125` `sync/CloudSyncService.kt:29` = `SNAPSHOT_SCHEMA_VERSION` | `A\sync\CloudSyncService.kt:28` | −1 | `const val SNAPSHOT_SCHEMA_VERSION` |
| **L-2** | `C:126` `sync/CloudSyncService.kt:32` = `ENVELOPE_SCHEMA_VERSION` | `A\sync\CloudSyncService.kt:31` | −1 | `const val ENVELOPE_SCHEMA_VERSION` |
| **L-3** | `C:38` 鸿蒙 `UserDataBackupService.ets:26` = 备份包 | `H\UserDataBackupService.ets:29`（`interface UserDataBackupPackage`）；`:26` 处是 `:22`–`:28` 的文档注释块 | +3 | `export interface UserDataBackupPackage` |
| **L-4** | `C:90` 鸿蒙 `CloudSyncService.ets:80`（`decideSyncAction`）、调用点 `:177` | 定义 `:108`；调用点 `:190` | +28 / +13 | `decideSyncAction(` / `this.decideSyncAction(` |
| **L-5** | `C:112` 鸿蒙 `UserDataBackupService.ets:164`（§5 合并规则） | `:164` 是 `createPackage(`；实际三落点 `:113`（`importPackage`）/ `:199`（`mergeSessions`）/ `:218`（`normalizePlanSelection`） | 指向错函数 | `async importPackage(` / `mergeSessions(existingSessions` / `normalizePlanSelection(plans` |
| L-6 | `C:124` `model/BackupPackage.kt:13` = `BACKUP_SCHEMA_VERSION` | `A\model\BackupPackage.kt:13` | ✅ 正确（唯一未漂移的 §6 锚） | `const val BACKUP_SCHEMA_VERSION` |
| L-7 | `C:26`–`C:33` §1 字段表 | ✅ 与 `A\model\BackupPackage.kt:23`–`:34` 对齐 | 0 | `data class UserDataBackupPackage` |

> 漂移集中形态：`C:118`–`C:126`（§6）与 `C:88`–`C:112`（§4/§5）两段。安卓侧偏向「+1」型（常量前移一行），鸿蒙侧偏向「换实现后未回填」（+13 ～ +28）。**纯行号漂移不改变契约语义**，但会让 §5 抽验命令失去 gate 价值——这是暂缓项 #5 的直接证据。

## §4 魔法值散落（`M-*`）与双端模块边界不对称（`B-*`）

| ID | 类型 | 现象 | 证据 |
|---|---|---|---|
| **M-1** | 魔法值散落 | `'local-device'` 字面量 **4 处**各自持有，均未从单一常量派生 | `H\CloudSyncService.ets:419`–`:421`（`resolveDeviceTag` 直接 return）、`H\SupabaseCloudSnapshotStore.ets:46`、`A\sync\CloudSyncService.kt:151`、`A\cloud\SupabaseCloudSnapshotStore.kt:84`（引用常量，非字面量）→ 实际**字面量 2 处 + 引用 2 处** |
| **M-2** | 魔法值散落 | `META_KEY = 'meta'` 两端各一份，未入契约 | `H\CloudSyncService.ets:44`、`A\sync\CloudSyncService.kt:148` |
| **M-3** | 魔法值散落 | 状态字面量 `'never'` 两端各一份（`'syncing'` / `'unauthenticated'` 仅鸿蒙侧 `getState` 生成，安卓侧 `SyncState` 仅为 DTO，未见生成方） | `H\CloudSyncService.ets:251`（`createMeta('', '', 0, 'never', '')`）、`A\sync\CloudSyncService.kt:237`（`lastStatus = "never"`） |
| **M-4** | 魔法值散落 | 沙盒目录名 `'cloud_sandbox'` 两端各一份，未入契约 | `H\CloudSnapshotStore.ets:13`、`A\sync\LocalSnapshotStore.kt:287` |
| **B-1** | 双端模块边界不对称 | 同一职责在两端落点数量不同：**鸿蒙 1 文件承载 6 类职责**（决策内核 / 信封构建 + 下行应用 / hash / 元数据落盘 / store 解析 / 头像落位），**安卓拆成 2 文件**（`CloudSyncService.kt` 纯逻辑；`LocalSnapshotStore.kt` 载荷 + hash + 沙盒 store） | 鸿蒙：`H\CloudSyncService.ets:108` / `:257` / `:320` / `:366` / `:419` / `:427` 全在同文件（495 行）；安卓：`A\sync\CloudSyncService.kt`（248 行）+ `A\sync\LocalSnapshotStore.kt`（293 行） |
| **B-2** | 重复实现（跨端） | `djb2Hex` 双端各实现一份；契约 §4 只说算法、不登记两端落点 | `H\CloudSyncService.ets:326`、`A\sync\LocalSnapshotStore.kt:148` |

> B-1 的后果不是代码缺陷，而是**审计成本**：按契约条款到鸿蒙侧找对应实现时，一个 495 行文件里混着 6 类职责，无子模块边界可锚。

## §5 file:line 抽验命令（暂缓项 #5 决议：gate 落地）

每条锚点的 gate 判据 = **目标行文本仍含声明的符号**。任一行不命中即基线漂移，台账需重测。

```bash
cd "$(git rev-parse --show-toplevel)"
ok=0; bad=0
chk() { # chk <file> <line> <expected-substring>
  local text; text=$(sed -n "${2}p" "$1")
  if [[ "$text" == *"$3"* ]]; then ok=$((ok+1)); else bad=$((bad+1)); echo "DRIFT $1:$2 期望含 [$3] 实为 [$text]"; fi
}
H=apps/harmony/entry/src/main/ets/shared/services
A=apps/android/app/src/main/java/com/fittracker/app/data
C=contracts/README.md
# 契约常量值 = 1（K-11）
chk $C 125 'SNAPSHOT_SCHEMA_VERSION'
chk $C 126 'ENVELOPE_SCHEMA_VERSION'
chk $C 124 'BACKUP_SCHEMA_VERSION'
# 行号漂移的「实际位置」（L-1..L-5）
chk $A/sync/CloudSyncService.kt 28 'SNAPSHOT_SCHEMA_VERSION'
chk $A/sync/CloudSyncService.kt 31 'ENVELOPE_SCHEMA_VERSION'
chk $A/model/BackupPackage.kt 13 'BACKUP_SCHEMA_VERSION'
chk $H/UserDataBackupService.ets 29 'interface UserDataBackupPackage'
chk $H/CloudSyncService.ets 108 'decideSyncAction('
chk $H/UserDataBackupService.ets 199 'mergeSessions(existingSessions'
# 结构性漂移（C-1 信封字段 / C-3 updateSession 调用方 / K-6 决策分支）
chk $H/CloudSyncService.ets 68 'interface CloudPayloadEnvelope'
chk $A/sync/LocalSnapshotStore.kt 44 'data class CloudPayloadEnvelope'
chk $A/sync/CloudSyncService.kt 173 'fun decideSyncAction('
chk apps/android/app/src/main/java/com/fittracker/app/ui/screens/complete/CompleteScreen.kt 209 'WorkoutRepository.updateSession'
# 魔法值（M-1/M-4）
chk $H/CloudSnapshotStore.ets 13 'SANDBOX_SNAPSHOT_DIR'
chk $A/sync/LocalSnapshotStore.kt 287 'SANDBOX_SNAPSHOT_DIR'
echo "pass=$ok drift=$bad"
```

**为什么 gate 只覆盖 15 条而非全部**：`K-1` / `K-3` / `K-10` 的语义一致靠人工对读（结构同名字段 + 策略语义），grep 无法判定「语义等价」。gate 只锚可机械判定的行，避免制造假绿。

## §6 暂缓项决议汇总

| # | 议题 | 决议 |
|---|---|---|
| 1 | 基线「§0-§6」与 README 实际 §0–§7 不符 | **采纳修正**：基线为 §0–§7。§7 纳入后直接产出 C-3（§7-2 证伪）——该项若按原基线会整条漏审 |
| 2 | `audit-server-functions` 的 `files` 漏 `server/deploy/`、`server/supabase/migrations/` 禁动区 | **本任务范围外**（Scope 为 10 个源文件 + README）。本台账未审计 server 侧；§3 中 `C:70` 引用的迁移文件仅作为契约引用被读，未核其内容 |
| 3 | `audit-tools-remotion` 三处技术栈异构 | **本任务范围外**，未处理 |
| 4 | 草稿「台账已落盘入库可复核」与 git 现状冲突 | **采纳该事实**：`docs/audit/` 整目录 untracked。本文件交付时**未 commit**；下游复核以工作区磁盘为准。抽验命令（§5）用 `git rev-parse --show-toplevel` 定位仓库根，不依赖任何提交 |
| 5 | 台账 file:line 缺可验证 gate | **采纳**：§0 锚点纪律（符号名 + 行号双载）+ §5 可执行抽验脚本（15 条 gate，输出 `pass=N drift=M`）。同时以 §3 量化当前漂移：`L-1..L-5` 共 5 条 `file:line` 已失效 |
| 6 | 五型问题分布可能失衡 | **采纳**：只写实际捕获的 4 类（`C-*` / `L-*` / `M-*` / `B-*`）。「越界依赖」在 10 个纯契约源文件里 0 命中，**不制造条目** |

## §7 本轮未覆盖（诚实边界）

- **鸿蒙 `SupabaseCloudSnapshotStore.ets`（384 行）未逐行读**：只核了 `:45`–`:46`（`DEVICE_TAG`）、`:38` / `:354`–`:355`（`SNAPSHOT_SCHEMA_VERSION` 传入点）与文件存在性。K-5 的鸿蒙侧 REST 端点 / 列名映射为**部分核对**，标 ⚠️ 而非 ✅。
- **安卓 `SupabaseCloudSnapshotStore.kt` 只核了映射注释与写入体**（`:27`–`:38`、`:60`、`:101`–`:103`），未核 401 / 重试 / 错误语义。
- **`BodyMeasurement` 的 8 字段与 `MEASUREMENT_UNSET = -1` 口径未核**：`C:35` 声明的「8 个字段未录入恒为 `-1`、单位 cm / % / kg」本轮未打开 `BodyModels` 对应定义（不在 10 文件 Scope 内）。**该条为未验证声明**，不得据本台账认为已核对。
- **`contentMeta.contentVersion` = 「取全部动作 `contentVersion` 最大值」**：实测两端实现一致（`A\service\backup\UserDataBackupService.kt:379`–`:380` `maxOfOrNull { it.contentVersion } ?: 0`；鸿蒙 `H\UserDataBackupService.ets:181` 调 `ContentRepository.getLocalContentVersion()`），但鸿蒙侧该函数体未读。
- **未运行任何构建 / 测试**：本次为只读审计，无源码改动；台账不含构建或测试的通过 / 失败结论。§5 抽验脚本**已执行**，实测输出 `pass=15 drift=0`（15 条锚点全部命中，含 C-3 的 `CompleteScreen.kt:209` 调用方）。该结果只证明**本台账自己引用的 file:line 与当前工作区一致**，不证明契约实现正确。
- `C:8` 提到的「2026-10-28 华为 AGC 链路整体移除」未做存证核验（历史事实，不影响当前契约面）。

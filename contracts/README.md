# FitTracker 跨端契约

> **本文件是 Android（`apps/android`）与鸿蒙（`apps/harmony`）之间的数据契约真源。**
> 两端各自实现，但字段名、语义、版本号必须逐条一致。**改契约前先改本文件**，
> 再同步两端实现——否则一端升级、另一端会直接拒绝数据（见 §6）。

## 0. 为什么需要这份契约

两端共用同一份产品数据（目标 / 计划 / 训练记录），但**后端实现不同源**：

| | 鸿蒙 | Android |
|---|---|---|
| 云端存储 | 华为 AGC | 自托管 Supabase |
| 存储实现 | `apps/harmony/entry/src/main/ets/shared/services/AgcCloudSnapshotStore.ets` | `apps/android/app/src/main/java/com/fittracker/app/data/cloud/SupabaseCloudSnapshotStore.kt` |
| 后端资产 | `apps/harmony/cloud/agc/` | `server/supabase/`、`server/deploy/` |

即 **契约层统一、供应商实现分家**。云端各自独立，但「备份包 JSON」必须双向可解析——
鸿蒙导出的备份应能被 Android 导入，反之亦然。

## 1. 备份包 `UserDataBackupPackage`

用户数据的整包表示。所有持久化字段都在这里。

| 字段 | 类型 | 说明 |
|---|---|---|
| `schemaVersion` | Int | = `BACKUP_SCHEMA_VERSION`，见 §6 |
| `exportedAt` | Long | 导出时刻（毫秒）。**不参与变更检测 hash** |
| `goal` | `UserGoal?` | 训练目标，可为 null（表示「未设置」） |
| `plans` | `List<UserPlan>` | 用户自建计划 |
| `currentPlanId` | String | 当前计划指针；不在 `plans` 中时归一化为首个 |
| `sessions` | `List<WorkoutSession>` | 训练记录 |
| `contentMeta` | `UserDataBackupContentMeta` | `{ contentVersion: Int }`，内容库版本（取全部动作 `contentVersion` 最大值） |

源：`apps/android/app/src/main/java/com/fittracker/app/data/model/BackupPackage.kt:23`
↔ 鸿蒙 `entry/src/main/ets/shared/services/UserDataBackupService.ets:26`

`WorkoutSession` 关键字段：`sessionId`（**合并键**）、`planId`、`dayId`、`startedAt`、`endedAt`、
`durationSeconds`、`totalSets`、`totalVolume`、`fatigueScore`、`notes`、`sets: List<WorkoutSet>`。
注意 `notes` 可能内嵌 `target_sets=` / `completed_sets=` 前缀，复盘解析依赖，**不可清理**。

## 2. 云信封 `CloudPayloadEnvelope`

上传到云端的载荷外层——备份包 + 用户资料一起传。

| 字段 | 类型 | 说明 |
|---|---|---|
| `schemaVersion` | Int | = `ENVELOPE_SCHEMA_VERSION` |
| `backupJson` | String | §1 备份包的 JSON 字符串（**美化格式**，非紧凑） |
| `nickname` | String | 用户昵称，空串表示不改 |
| `avatar` | String | 头像标识 |
| `weightUnit` | String | `"kg"` / `"lbs"` |

源：`apps/android/.../data/sync/LocalSnapshotStore.kt`（`CloudPayloadEnvelope`）

## 3. 云快照 `CloudSnapshot`

云端「每用户一条」的存储单元。

| 字段 | 类型 | 说明 |
|---|---|---|
| `userId` | String | 账号标识 |
| `payloadJson` | String | §2 信封的 JSON |
| `updatedAt` | Long | **服务端接收时间**（不是客户端时间） |
| `deviceTag` | String | 设备标识（当前实现固定 `local-device`） |
| `schemaVersion` | Int | = `SNAPSHOT_SCHEMA_VERSION` |

Supabase 侧映射：表 `public.snapshots(user_id uuid PK → auth.users, payload jsonb, updated_at timestamptz)`，
RLS 三策略 `auth.uid() = user_id`（select / insert / update；**刻意不建 delete 策略**）。
见 `server/supabase/migrations/20261004000000_snapshots.sql`。

## 4. 同步决策 `decideSyncAction`

三值 hash 决策：`localHash`（本地当前）/ `remoteHash`（云端）/ `baselineHash`（上次同步基线）。

| 条件 | 动作 |
|---|---|
| `remoteHash` 为空（云端无快照） | `PUSH`（首同步 / 认领） |
| `localHash == baselineHash` 且 `remoteHash == baselineHash` | `NONE` |
| `localHash == baselineHash` 且 `remoteHash != baselineHash` | `PULL` |
| `localHash != baselineHash` 且 `remoteHash == baselineHash` | `PUSH` |
| 双方都变 且 `remoteUpdatedAt > lastSyncAt` | `CONFLICT_PULL`（**云端优先**） |
| 双方都变 且 `remoteUpdatedAt <= lastSyncAt` | `PUSH` |

注意 `>` 是**严格**大于——时间戳相等时判 `PUSH`。

源：`apps/android/.../data/sync/CloudSyncService.kt`（`decideSyncAction`）
↔ 鸿蒙 `entry/src/main/ets/shared/services/CloudSyncService.ets:80`（调用点 `:177`）

### hash 口径

`hashPayload` = 先规范化（剔除 `exportedAt`，按固定字段序重排）再取 djb2 摘要，
输出 `<十六进制摘要>_<规范化长度十六进制>`。**非安全用途**——碰撞的代价仅是一次多余上行。

> ⚠ 跨端**字节级**一致性未强制：JS 数字格式（`625`）与 Kotlin（`625.0`）、对象字段序可能不同。
> 故同一语义数据在两端算出的 hash 未必相等——代价是多余一次上行，可接受。

## 5. 导入合并规则 `importPackage`

这是**多端数据不丢的关键**——各字段策略不同，不可一概而论：

| 字段 | 策略 |
|---|---|
| `sessions` | **按 `sessionId` 去重合并**：以本地为基底，同 id 用导入包版本**就地替换**，新 id **追加**，保序。**本地独有的记录不会被云端覆盖掉** |
| `goal` | **以导入包为准**；包内为 `null` 则清空本地目标 |
| `plans` | **整块替换**，以导入包为准（本地独有但不含在包内的计划会丢失） |
| `currentPlanId` | 归一化：不在 `plans` 中则回退 `plans[0].id`（空列表回退 `""`） |

源：`apps/android/.../data/service/backup/UserDataBackupService.kt`（`mergeSessions` / `normalizePlanSelection`）
↔ 鸿蒙 `entry/src/main/ets/shared/services/UserDataBackupService.ets:164`

**为什么 sessions 特殊**：训练记录是「只追加、几乎不回头改」的数据，按 id 合并几乎无损；
而目标是单值、计划含「当前指针」语义，合并会产生歧义（合并后哪份是当前计划说不清），
故这两者以包为准。**变更此规则前必须同时评估两端。**

## 6. 版本号纪律（最重要）

三个独立常量，两端各持一份：

| 常量 | 位置（Android） | 校验方式 |
|---|---|---|
| `BACKUP_SCHEMA_VERSION` | `model/BackupPackage.kt:13` | 备份包 `schemaVersion == 1` |
| `SNAPSHOT_SCHEMA_VERSION` | `sync/CloudSyncService.kt:29` | 快照 `schemaVersion == 1` |
| `ENVELOPE_SCHEMA_VERSION` | `sync/CloudSyncService.kt:32` | 信封 `schemaVersion == 1` |

**校验是硬相等，不是「尽量解析」**：解析时先检查 `schemaVersion` 是否为有限数，
再判 `!= 1` → 返回 `backup_schema_unsupported`，**直接拒绝，不做兼容尝试**。

**推论（多端共用后端的核心约束）**：

- 任何一端升级 `schemaVersion`，**另一端必须同时发版**；否则旧端拉到的数据它不认识，直接拒绝。
- 这三个版本号**独立于 App 的 versionName/versionCode**——不要混用。
- 新增字段若做向后兼容（旧端能忽略），可不升版本；语义变更或删字段必须升版本并两端同步。

## 7. 已知未收敛项

- **两端后端不同源**（AGC / Supabase）：云端数据互不可见，跨端迁移目前只能靠**手动备份包导出导入**。
  是否统一云端是独立决策，不在本契约范围内。
- **同一条训练记录两端都改**：按 §5 规则由导入包版本胜出，本端那次修改被替换。
  当前 Android 侧 `WorkoutRepository.updateSession` 无生产调用方（记录只增不改），故实际不会触发。
- **hash 跨端不一致**（见 §4）：接受多余一次上行，不追求字节级一致。

---

**维护约定**：改本文件所描述的任何结构、语义或版本号时，先改本文件 → 再改两端实现 → 两端各跑一次
备份导出/导入往返测试。仅改一端 = 制造两端不兼容。

package com.fittracker.app.data.sync

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * 云同步决策内核 + 契约类型——移植自鸿蒙
 * `entry/src/main/ets/shared/services/CloudSyncService.ets`（决策 / 类型）与
 * `CloudSnapshotStore.ets`（存储契约），Wave 5。
 *
 * 本文件只承载「纯逻辑 + 契约」，不碰平台存储：
 * - 类型：[SyncAction]（源 `:28`）、[SyncState]（源 `:33`）、[SyncResult]（源 `:40`）、
 *   [SyncMeta]（源 `:47`）。
 * - 快照契约：[CloudSnapshot]（源 `CloudSnapshotStore.ets:15`）+ [createCloudSnapshot]（源 `:23`）
 *   + [CloudSnapshotStore] 抽象（源 `:40`，方法 `pull` / `push`，源 `:42` / `:45`）。
 * - 决策纯函数：[CloudSyncService.decideSyncAction]（源 `:80`，三值 hash 决策，逐分支对齐）、
 *   [CloudSyncService.hasPendingChanges]（源 `:133`）、[CloudSyncService.isAccountChanged]（源
 *   `:159`）、[CloudSyncService.baselineFor]（源 `:159-160`）、[CloudSyncService.isValidMeta]（源 `:390`）。
 * 「本地整包构建 + 变更检测 hash」落在 [LocalSnapshotStore]（源 `buildLocalPayload` `:249` /
 * `hashPayload` `:288`）。源架构中的 `syncNow`（编排）/ `resolveStore`（Supabase ↔ 本地沙盒选择）/
 * 元数据落盘属后续 Wave——本文件仅暴露其可独立验证的决策面。
 *
 * 权威模型（源文件头注释）：本地存储 + 云同步；冲突按「服务端接收时间最近写入为准」
 * （云端 `updatedAt` 较新时下行）。
 */

/** 快照 schema 版本（源 `CloudSnapshotStore.ets:12` `SNAPSHOT_SCHEMA_VERSION = 1`）。 */
const val SNAPSHOT_SCHEMA_VERSION: Int = 1

/** 载荷信封 schema 版本（源 `CloudSyncService.ets:31` `ENVELOPE_SCHEMA_VERSION = 1`）。 */
const val ENVELOPE_SCHEMA_VERSION: Int = 1

/**
 * 同步动作（源 `:28`）：
 * `export type SyncAction = 'push' | 'pull' | 'none' | 'conflict_pull' | 'failed' | 'skipped'`。
 *
 * [id] 逐字承载源的字符串字面量，供落盘 / 展示对齐（`@SerialName` 保证 JSON 序列化为 `id` 而非枚举名）。
 */
@Serializable
enum class SyncAction(val id: String) {
    @SerialName("push")
    PUSH("push"),

    @SerialName("pull")
    PULL("pull"),

    @SerialName("none")
    NONE("none"),

    @SerialName("conflict_pull")
    CONFLICT_PULL("conflict_pull"),

    @SerialName("failed")
    FAILED("failed"),

    @SerialName("skipped")
    SKIPPED("skipped"),
}

/**
 * 云快照（源 `CloudSnapshotStore.ets:15`）——每个用户一条，载荷为整包 JSON 信封字符串。
 *
 * 与 Supabase 侧表 `public.snapshots(user_id, payload jsonb, updated_at)`（迁移
 * `supabase/migrations/20261004000000_snapshots.sql`）的映射：`userId`↔`user_id`、
 * `payloadJson`↔`payload`、`updatedAt`↔`updated_at`（`deviceTag` / `schemaVersion` 本地保留）。
 */
@Serializable
data class CloudSnapshot(
    val userId: String,
    val payloadJson: String,
    val updatedAt: Long,
    val deviceTag: String,
    val schemaVersion: Int = SNAPSHOT_SCHEMA_VERSION,
)

/** 源 `CloudSnapshotStore.ets:23` `createCloudSnapshot`——显式 schemaVersion 的构造工厂。 */
fun createCloudSnapshot(
    userId: String,
    payloadJson: String,
    updatedAt: Long,
    deviceTag: String,
    schemaVersion: Int,
): CloudSnapshot = CloudSnapshot(
    userId = userId,
    payloadJson = payloadJson,
    updatedAt = updatedAt,
    deviceTag = deviceTag,
    schemaVersion = schemaVersion,
)

/**
 * 云快照存储抽象（源 `CloudSnapshotStore.ets:40`）。
 *
 * 实现的「供应商」对应：
 * - 本地沙盒文件（[LocalSandboxSnapshotStore]）——云端配置缺失 / 测试环境；
 * - 自建服务器快照（源 `SupabaseCloudSnapshotStore.ets`）——发布路径
 *   Supabase 实现（同为 `CloudSnapshotStore`）。
 */
interface CloudSnapshotStore {
    /** 源 `:42` `abstract pull`——拉取指定用户最新快照；无快照返回 `null`。 */
    suspend fun pull(userId: String): CloudSnapshot?

    /** 源 `:45` `abstract push`——写入 / 覆盖用户快照；返回是否成功。 */
    suspend fun push(snapshot: CloudSnapshot): Boolean
}

/** 同步状态（源 `:33`）——面向 UI 的快照状态。 */
data class SyncState(
    val status: String,
    val lastSyncAt: Long,
    val lastError: String,
)

/** 同步结果（源 `:40`）。 */
data class SyncResult(
    val success: Boolean,
    val action: String,
    val message: String,
    val syncedAt: Long,
)

/**
 * 同步元数据（源 `:47`）——落盘于 [com.fittracker.app.data.persist.StoreNames.SYNC] 的键 [CloudSyncService.META_KEY]
 * （源 `:30` `META_KEY = 'meta'`）。`userId` 绑定账号，切换账号时自动视为全新同步。
 */
@Serializable
data class SyncMeta(
    val userId: String,
    val lastSyncedHash: String,
    val lastSyncAt: Long,
    val lastStatus: String,
    val lastError: String,
)

/** 同步基线（hash + 时间）——源 `syncNow` 中的 `baseline` / `baselineAt` 二元组（源 `:159-160`）。 */
data class SyncBaseline(
    val hash: String,
    val at: Long,
)

/**
 * 同步决策内核——纯逻辑切片，对应源 `CloudSyncService.ets` 的 `decideSyncAction` /
 * `hasPendingChanges` / 基线解析 / 元数据校验。全部无副作用，便于矩阵测试。
 */
object CloudSyncService {

    /** 源 `:30` `META_KEY`——`SyncMeta` 在 `fit_tracker_sync` 库中的键名。 */
    const val META_KEY: String = "meta"

    /** 源 `:339` `resolveDeviceTag()` 的固定返回值。 */
    const val DEVICE_TAG: String = "local-device"

    /**
     * 三值 hash 决策（源 `:80` `decideSyncAction`）——纯函数，逐分支对齐源。
     *
     * `remoteHash` 为空串表示云端无快照。决策矩阵：
     *
     * | 条件 | 动作 |
     * | --- | --- |
     * | `remoteHash` 为空（云端无快照） | [SyncAction.PUSH]（首同步 / 认领） |
     * | `localHash == baselineHash` 且 `remoteHash == baselineHash` | [SyncAction.NONE] |
     * | `localHash == baselineHash` 且 `remoteHash != baselineHash` | [SyncAction.PULL] |
     * | `localHash != baselineHash` 且 `remoteHash == baselineHash` | [SyncAction.PUSH] |
     * | 双方都变 且 `remoteUpdatedAt > lastSyncAt` | [SyncAction.CONFLICT_PULL]（云端优先） |
     * | 双方都变 且 `remoteUpdatedAt <= lastSyncAt` | [SyncAction.PUSH] |
     *
     * 参数口径对齐源调用点 `:177`（`decideSyncAction(localHash, remoteHash, baseline, remoteUpdatedAt, baselineAt)`）：
     * `baselineHash` / `lastSyncAt` 为基线，由 [baselineFor] 从 [SyncMeta] 推出（同账号取
     * `lastSyncedHash` / `lastSyncAt`，切账号取 `""` / `0`）。
     *
     * 备注：源的 `remoteUpdatedAt > lastSyncAt` 为**严格**大于——时间戳相等时判 `push`（不判冲突）。
     */
    fun decideSyncAction(
        localHash: String,
        remoteHash: String,
        baselineHash: String,
        remoteUpdatedAt: Long,
        lastSyncAt: Long,
    ): SyncAction {
        if (remoteHash.isEmpty()) { // 源 :87-89
            return SyncAction.PUSH
        }
        if (localHash == baselineHash) { // 源 :90-92
            return if (remoteHash == baselineHash) SyncAction.NONE else SyncAction.PULL
        }
        if (remoteHash == baselineHash) { // 源 :93-95
            return SyncAction.PUSH
        }
        return if (remoteUpdatedAt > lastSyncAt) SyncAction.CONFLICT_PULL else SyncAction.PUSH // 源 :96
    }

    /** 源 `:159` `meta.userId === session.userId` 的取反——账号是否切过。 */
    fun isAccountChanged(metaUserId: String, currentUserId: String): Boolean =
        metaUserId != currentUserId

    /**
     * 由元数据与当前账号推出同步基线（源 `:159-160`）：
     * 同账号沿用 `lastSyncedHash` / `lastSyncAt`；切账号则视为全新同步（`""` / `0`）。
     */
    fun baselineFor(meta: SyncMeta, currentUserId: String): SyncBaseline =
        if (isAccountChanged(meta.userId, currentUserId)) {
            SyncBaseline(hash = "", at = 0L) // 源 :160
        } else {
            SyncBaseline(hash = meta.lastSyncedHash, at = meta.lastSyncAt) // 源 :159
        }

    /**
     * 是否存在未同步到云端的本地变更（源 `:133` `hasPendingChanges`）——纯函数。
     *
     * - 未登录（`currentUserId` 为空，等价源 `:135-137` 会话为 `null`）→ `false`；
     * - 账号切过（源 `:139-141`）→ `true`；
     * - 否则比较本地 hash 与基线（源 `:143`）。
     *
     * `localHash` 由 [LocalSnapshotStore.hashPayload] 对 [LocalSnapshotStore.buildLocalPayload]
     * 的结果算得（源 `:142` 内联 `buildLocalPayload` + `hashPayload`）。
     */
    fun hasPendingChanges(
        metaUserId: String,
        currentUserId: String,
        localHash: String,
        lastSyncedHash: String,
    ): Boolean {
        if (currentUserId.isEmpty()) { // 源 :135-137
            return false
        }
        if (isAccountChanged(metaUserId, currentUserId)) { // 源 :139-141
            return true
        }
        return localHash != lastSyncedHash // 源 :143
    }

    /** 缺省元数据（源 `:344` `readMeta` 的 fallback：`createMeta('', '', 0, 'never', '')`）。 */
    fun defaultMeta(): SyncMeta = SyncMeta(
        userId = "",
        lastSyncedHash = "",
        lastSyncAt = 0L,
        lastStatus = "never",
        lastError = "",
    )

    /**
     * 源 `:390` `isValidMeta`——逐字段类型 / 有限性校验。
     *
     * Kotlin 侧 [SyncMeta] 字段为强类型，`@Serializable` 严格解码已排除类型不符 / 缺失；
     * 源对 `lastSyncAt` 的 `Number.isFinite` 守卫在 `Long` 下恒成立，故实现退化为非空判断。
     */
    fun isValidMeta(meta: SyncMeta?): Boolean = meta != null
}

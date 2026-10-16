package com.fittracker.app.data.sync

import com.fittracker.app.data.auth.AuthService
import com.fittracker.app.data.cloud.SupabaseAuthProvider
import com.fittracker.app.data.cloud.SupabaseCloudSnapshotStore
import com.fittracker.app.data.cloud.SupabaseConfig
import com.fittracker.app.data.persist.JsonCodec
import com.fittracker.app.data.persist.JsonStore
import com.fittracker.app.data.persist.StoreNames
import com.fittracker.app.data.service.UserProfileService
import com.fittracker.app.data.service.WeightUnit
import com.fittracker.app.data.service.backup.UserDataBackupService
import java.io.File
import kotlinx.serialization.decodeFromString
import kotlinx.serialization.encodeToString

/**
 * 云同步编排——移植自鸿蒙 `shared/services/CloudSyncService.ets` 的**有副效应流程**
 * （纯函数切片 [CloudSyncService] 与本地存储 [LocalSnapshotStore] / [LocalSandboxSnapshotStore]
 * 已先期落地）：`getState` / `hasPendingChanges` / `syncNow` / `onSignIn` /
 * `requestBackgroundSync` / `resetMeta` + 私有 `buildLocalPayload` / `applyRemotePayload` /
 * `resolveStore` / `readMeta` / `writeMeta`。
 *
 * 与源的映射差异（安卓化）：
 * - 源单例 + `context` 首参 → [store] 注入 + [sandboxDir] 参数（生产用
 *   [forFilesDir]`(context.filesDir)` 构造）。
 * - 源 `resolveStore`：AGC（未就绪 → `null` 显式失败，不跨存储降级）→ 本地沙盒；
 *   安卓侧同构：测试注入 > **Supabase（已配置）** > 本地沙盒；两者都无 → `null`。
 *   注意 Supabase 分支下"云服务未就绪"几乎不会触发（publishable key 恒可用），
 *   失败改由 pull/push 的 `null` / `false` 表达——与源 AGC 判定的语义差保留在报告中。
 * - 源 `SessionManager.getSession(context)` → [AuthService.currentSession]（两 provider 通用）。
 * - 源 `resolveDeviceTag()` 固定 `'local-device'` → [CloudSyncService.DEVICE_TAG]。
 */
object SyncOrchestrator {

    /** 测试注入存储（源 `setStoreForTesting`；`null` 恢复默认解析）。 */
    @Volatile
    private var testingStore: CloudSnapshotStore? = null

    /** 防重入（源 `syncInProgress`）。 */
    @Volatile
    private var syncInProgress: Boolean = false

    fun setStoreForTesting(store: CloudSnapshotStore?) {
        testingStore = store
    }

    /** 沙盒目录约定（源 `context.filesDir + '/cloud_sandbox'`）。 */
    fun forFilesDir(filesDir: File): File = File(filesDir, "cloud_sandbox")

    // --- 状态 / 开关 ---------------------------------------------------------

    /** 源 `:99` `getState`——`status` 优先级：syncing > unauthenticated > meta.lastStatus > never。 */
    suspend fun getState(store: JsonStore): SyncState {
        val meta: SyncMeta = readMeta(store)
        val session = AuthService.currentSession(store)
        val status: String = when {
            syncInProgress -> "syncing"
            session == null -> "unauthenticated"
            meta.lastStatus.isEmpty() -> "never"
            else -> meta.lastStatus
        }
        return SyncState(
            status = status,
            lastSyncAt = meta.lastSyncAt,
            lastError = meta.lastError,
        )
    }

    /**
     * 源 `:133` `hasPendingChanges`——纯函数 [CloudSyncService.hasPendingChanges] 的 IO 包装
     * （本地 hash 经 [LocalSnapshotStore.hashPayload]，与 `syncNow` 同口径）。
     */
    suspend fun hasPendingChanges(store: JsonStore): Boolean {
        val session = AuthService.currentSession(store) ?: return false // 源 :135-137
        val meta: SyncMeta = readMeta(store) // 源 :138
        val localHash: String = LocalSnapshotStore.hashPayload(LocalSnapshotStore.buildLocalPayload(store))
        return CloudSyncService.hasPendingChanges(
            metaUserId = meta.userId,
            currentUserId = session.userId,
            localHash = localHash,
            lastSyncedHash = meta.lastSyncedHash,
        )
    }

    // --- 主流程 --------------------------------------------------------------

    /**
     * 源 `:146` `syncNow`——决策（[CloudSyncService.decideSyncAction]）+ 执行 + 状态落盘。
     * 语义逐分支对齐源（各失败文案）。
     *
     * @param sandboxDir 本地沙盒目录（Supabase 未配置时的回落存储；`null` 且未配置 →
     *   走「云服务未就绪」显式失败路径，不静默）。
     */
    suspend fun syncNow(store: JsonStore, sandboxDir: File? = null): SyncResult {
        if (syncInProgress) { // 源 :147-149
            return SyncResult(success = false, action = "skipped", message = "同步进行中", syncedAt = System.currentTimeMillis())
        }
        syncInProgress = true
        try {
            val session = AuthService.currentSession(store) // 源 :153-156
                ?: return SyncResult(success = false, action = "skipped", message = "未登录", syncedAt = System.currentTimeMillis())

            val localPayload: String = LocalSnapshotStore.buildLocalPayload(store) // 源 :158
            val localHash: String = LocalSnapshotStore.hashPayload(localPayload) // 源 :159
            val meta: SyncMeta = readMeta(store) // 源 :160
            val baseline: SyncBaseline = CloudSyncService.baselineFor(meta, session.userId) // 源 :159-160

            val cloudStore: CloudSnapshotStore? = resolveStore(store, sandboxDir) // 源 :162
            if (cloudStore == null) { // 源 :163-174
                writeMeta(
                    store,
                    meta.copy(
                        userId = session.userId,
                        lastSyncedHash = baseline.hash,
                        lastSyncAt = baseline.at,
                        lastStatus = "failed",
                        lastError = "云服务未就绪，请稍后重试",
                    ),
                )
                return SyncResult(success = false, action = "failed", message = "云服务未就绪，请稍后重试", syncedAt = System.currentTimeMillis())
            }

            val remote: CloudSnapshot? = cloudStore.pull(session.userId) // 源 :175
            val remoteHash: String = if (remote == null) "" else LocalSnapshotStore.hashPayload(remote.payloadJson) // 源 :176
            val remoteUpdatedAt: Long = remote?.updatedAt ?: 0L // 源 :177
            val action: SyncAction = CloudSyncService.decideSyncAction( // 源 :178
                localHash = localHash,
                remoteHash = remoteHash,
                baselineHash = baseline.hash,
                remoteUpdatedAt = remoteUpdatedAt,
                lastSyncAt = baseline.at,
            )
            val now: Long = System.currentTimeMillis()

            when (action) { // 源 :181-218
                SyncAction.PUSH -> {
                    val pushed: Boolean = cloudStore.push( // 源 :182-184
                        createCloudSnapshot(session.userId, localPayload, now, CloudSyncService.DEVICE_TAG, SNAPSHOT_SCHEMA_VERSION),
                    )
                    if (!pushed) { // 源 :185-188
                        writeMeta(
                            store,
                            meta.copy(
                                userId = session.userId,
                                lastSyncedHash = baseline.hash,
                                lastSyncAt = baseline.at,
                                lastStatus = "failed",
                                lastError = "同步上传失败",
                            ),
                        )
                        return SyncResult(success = false, action = "push", message = "同步上传失败，请稍后重试", syncedAt = now)
                    }
                    writeMeta( // 源 :190
                        store,
                        meta.copy(
                            userId = session.userId,
                            lastSyncedHash = localHash,
                            lastSyncAt = now,
                            lastStatus = "synced",
                            lastError = "",
                        ),
                    )
                    return SyncResult(success = true, action = "push", message = "已同步到云端", syncedAt = now)
                }

                SyncAction.PULL, SyncAction.CONFLICT_PULL -> {
                    if (remote == null) { // 源 :195-198
                        writeMeta(
                            store,
                            meta.copy(
                                userId = session.userId,
                                lastSyncedHash = baseline.hash,
                                lastSyncAt = baseline.at,
                                lastStatus = "failed",
                                lastError = "云端快照缺失",
                            ),
                        )
                        return SyncResult(success = false, action = action.id, message = "云端快照缺失，请稍后重试", syncedAt = now)
                    }
                    val applied: Boolean = applyRemotePayload(store, remote.payloadJson) // 源 :199
                    if (!applied) { // 源 :200-203
                        writeMeta(
                            store,
                            meta.copy(
                                userId = session.userId,
                                lastSyncedHash = baseline.hash,
                                lastSyncAt = baseline.at,
                                lastStatus = "failed",
                                lastError = "云端数据恢复失败",
                            ),
                        )
                        return SyncResult(success = false, action = action.id, message = "云端数据恢复失败，请稍后重试", syncedAt = now)
                    }
                    // 基线记录为「云端快照 hash」而非导入后的本地并集（源 :205-208 注释）：
                    // 若本地保留有云端没有的实体（sessions 并集合并语义），下次同步判「仅本地变化 → push」，
                    // 把并集回写云端后收敛为 none；hasPendingChanges 据此正确报告未上行数据。
                    writeMeta(
                        store,
                        meta.copy(
                            userId = session.userId,
                            lastSyncedHash = remoteHash,
                            lastSyncAt = now,
                            lastStatus = "synced",
                            lastError = "",
                        ),
                    )
                    val message: String =
                        if (action == SyncAction.CONFLICT_PULL) "云端数据较新，已采用云端版本" else "已从云端恢复" // 源 :211-212
                    return SyncResult(success = true, action = action.id, message = message, syncedAt = now)
                }

                else -> { // none（以及防御性兜底）——源 :216-218
                    writeMeta(
                        store,
                        meta.copy(
                            userId = session.userId,
                            lastSyncedHash = localHash,
                            lastSyncAt = now,
                            lastStatus = "synced",
                            lastError = "",
                        ),
                    )
                    return SyncResult(success = true, action = "none", message = "已是最新", syncedAt = now)
                }
            }
        } catch (error: Exception) { // 源 :219-221
            return SyncResult(success = false, action = "failed", message = "同步失败，请稍后重试", syncedAt = System.currentTimeMillis())
        } finally {
            syncInProgress = false
        }
    }

    /** 源 `:224` `onSignIn`——登录成功钩子：云端有数据则恢复、为空则认领上传；失败不阻塞登录流程。 */
    suspend fun onSignIn(store: JsonStore, sandboxDir: File? = null) {
        try {
            syncNow(store, sandboxDir)
        } catch (error: Exception) {
            // 登录流程不因同步失败中断（源 :226-228）
        }
    }

    /** 源 `:233` `requestBackgroundSync`——启动后 / 训练完成后静默同步；同步恒定自动执行，失败不抛出。 */
    suspend fun requestBackgroundSync(store: JsonStore, sandboxDir: File? = null) {
        try {
            syncNow(store, sandboxDir)
        } catch (error: Exception) {
            // 静默路径：状态由 syncNow 内部记录（源 :238-240）
        }
    }

    /** 源 `:246` `resetMeta`——登出时调用，防账号切换串账。 */
    suspend fun resetMeta(store: JsonStore) {
        writeMeta(store, CloudSyncService.defaultMeta())
    }

    // --- 私有辅助 ------------------------------------------------------------

    /**
     * 源 `:262` `applyRemotePayload`——解析信封 → 导入备份包（[UserDataBackupService.importPackage]）
     * → 回写用户资料；任一步失败返回 `false`（源 catch 语义）。
     */
    private suspend fun applyRemotePayload(store: JsonStore, payloadJson: String): Boolean = try {
        val envelope: CloudPayloadEnvelope = JsonCodec.json.decodeFromString(payloadJson) // 源 :264
        if (envelope.backupJson.isEmpty()) { // 源 :265-267
            false
        } else {
            val importResult = UserDataBackupService.importPackage(store, envelope.backupJson) // 源 :268
            if (envelope.nickname.isNotEmpty()) { // 源 :269
                val local = UserProfileService.loadProfile(store)
                UserProfileService.saveProfile(
                    store,
                    local.copy(
                        nickname = envelope.nickname,
                        avatar = envelope.avatar,
                        weightUnit = if (envelope.weightUnit == "lbs") WeightUnit.LBS else WeightUnit.KG,
                        // 身体档案：旧信封无这些字段（null）时保留本地已填值，不用 0 覆盖。
                        heightCm = envelope.heightCm ?: local.heightCm,
                        gender = envelope.gender
                            ?.let { UserProfileService.normalizeGender(it) }
                            ?: local.gender,
                        birthYear = envelope.birthYear ?: local.birthYear,
                    ),
                )
            }
            importResult.success
        }
    } catch (error: Exception) { // 源 :278-280
        false
    }

    /**
     * 源 `:325` `resolveStore`——解析云存储：测试注入 > Supabase（已配置）> 本地沙盒。
     * 双无 → `null`（调用方走显式失败，不跨存储静默降级）。
     */
    private suspend fun resolveStore(store: JsonStore, sandboxDir: File?): CloudSnapshotStore? {
        testingStore?.let { return it } // 源 :326-328
        if (SupabaseConfig.isConfigured) {
            // access token 按需刷新（refresh token 在 CLOUD_SESSION；无会话时 null → 401 由 RLS 表达）
            val provider = SupabaseAuthProvider(store)
            return SupabaseCloudSnapshotStore(accessTokenProvider = { provider.validAccessToken() })
        }
        val dir: File = sandboxDir ?: return null
        return LocalSandboxSnapshotStore(dir)
    }

    /** 源 `:343` `readMeta`——缺失 / 空串 / 解析失败 / 校验不过一律回落 [CloudSyncService.defaultMeta]。 */
    private suspend fun readMeta(store: JsonStore): SyncMeta {
        val fallback: SyncMeta = CloudSyncService.defaultMeta() // 源 :344
        val raw: String? = store.readString(StoreNames.SYNC) // 源 :346
        if (raw.isNullOrEmpty() || raw.trim().isEmpty()) { // 源 :347-349
            return fallback
        }
        return try {
            val meta: SyncMeta = JsonCodec.json.decodeFromString(raw) // 源 :349
            if (!CloudSyncService.isValidMeta(meta)) fallback else meta // 源 :350-352
        } catch (error: Exception) { // 源 :353-355
            fallback
        }
    }

    /** 源 `:361` `writeMeta`——状态写入失败不阻塞同步流程（源 :365-367 注释）。 */
    private suspend fun writeMeta(store: JsonStore, meta: SyncMeta) {
        try {
            store.writeString(StoreNames.SYNC, JsonCodec.json.encodeToString(meta)) // 源 :363-365
        } catch (error: Exception) {
            // 忽略（源 :365-367）
        }
    }
}

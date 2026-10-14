package com.fittracker.app.data.sync

import androidx.datastore.preferences.core.PreferenceDataStoreFactory
import com.fittracker.app.data.auth.AuthService
import com.fittracker.app.data.auth.AuthSession
import com.fittracker.app.data.cloud.CloudSession
import com.fittracker.app.data.cloud.SupabaseAuthProvider
import com.fittracker.app.data.cloud.SupabaseSessionStore
import com.fittracker.app.data.persist.JsonCodec
import com.fittracker.app.data.persist.JsonStore
import com.fittracker.app.data.persist.StoreNames
import com.fittracker.app.data.service.backup.UserDataBackupService
import java.io.File
import java.util.concurrent.atomic.AtomicInteger
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.runBlocking
import kotlinx.serialization.decodeFromString
import kotlinx.serialization.encodeToString
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * [SyncOrchestrator] 契约测试——fake 云存储（[CloudSnapshotStore] 注入）驱动的全分支矩阵。
 *
 * 语义基线：鸿蒙 `CloudSyncService.ets:146` `syncNow` + `:133` `hasPendingChanges` + `:99` `getState`。
 * 会话构造：走云端会话存储（`StoreNames.CLOUD_SESSION`）——本测试经
 * `AuthService.setProviderFactoryForTesting` **显式注入 Supabase provider**，
 * `currentSession` 由持久化快照回落命中（见 `AuthService.currentSession`），
 * 不依赖 `BuildConfig.SUPABASE_URL`（CI / 无 local.properties 环境下行为一致）。
 * **真实网络不经手**：测试注入 fake 存储 + `AuthService.currentSession` 只读本地
 * （`provider.validAccessToken` 不被本测试路径触发——只读存储回落，不做刷新）。
 *
 * `@Config(sdk = [34])`：同 `SessionAndPlanTest`（Robolectric 支持范围内）。
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class SyncOrchestratorTest {

    @get:Rule
    val tempFolder: TemporaryFolder = TemporaryFolder()

    private val counter = AtomicInteger()

    private fun createStore(): JsonStore {
        val file = File(tempFolder.root, "sync_orchestrator_${counter.incrementAndGet()}.preferences_pb")
        val dataStore = PreferenceDataStoreFactory.create(
            scope = CoroutineScope(Dispatchers.IO + SupervisorJob()),
        ) { file }
        return JsonStore(dataStore)
    }

    /** Fake 云存储：记录调用、回放远端、可注入失败/抛错。 */
    private class FakeCloudStore(
        var remote: CloudSnapshot? = null,
        var pushResult: Boolean = true,
        var throwOnPull: Boolean = false,
    ) : CloudSnapshotStore {
        var pushed: CloudSnapshot? = null
        var pullCalls: Int = 0

        override suspend fun pull(userId: String): CloudSnapshot? {
            pullCalls++
            if (throwOnPull) throw RuntimeException("boom")
            return remote
        }

        override suspend fun push(snapshot: CloudSnapshot): Boolean {
            pushed = snapshot
            return pushResult
        }
    }

    @Before
    fun resetOrchestrator() {
        SyncOrchestrator.setStoreForTesting(null)
        // 本测试的会话构造走 CLOUD_SESSION（loginSession），需 Supabase 分支的
        // currentSession 回落读它——显式注入以免依赖本机 local.properties（CI 无此文件）。
        AuthService.setProviderFactoryForTesting { SupabaseAuthProvider(it) }
    }

    @After
    fun clearOrchestrator() {
        AuthService.setProviderFactoryForTesting(null)
        SyncOrchestrator.setStoreForTesting(null)
    }

    // --- 辅助 -----------------------------------------------------------------

    /** 伪造登录（云端会话落 `CLOUD_SESSION`——`AuthService.currentSession` 的持久化回落命中）。 */
    private suspend fun loginSession(store: JsonStore, userId: String = "u-1") {
        SupabaseSessionStore(store).save(
            CloudSession(
                accessToken = "access-token",
                refreshToken = "refresh-token",
                expiresAtEpochSeconds = System.currentTimeMillis() / 1000 + 3600,
                snapshot = AuthSession(
                    userId = userId,
                    displayName = "测试用户",
                    phone = "",
                    email = "tester@example.com",
                    providerId = "supabase",
                    signedInAt = System.currentTimeMillis(),
                ),
            ),
        )
    }

    /** 读回落盘的 [SyncMeta]（无则 null）。 */
    private suspend fun readMeta(store: JsonStore): SyncMeta? {
        val raw = store.readString(StoreNames.SYNC) ?: return null
        if (raw.isEmpty()) return null
        return JsonCodec.json.decodeFromString(raw)
    }

    /** 当前本地载荷 + hash（与编排同口径）。 */
    private suspend fun localPayloadHash(store: JsonStore): Pair<String, String> {
        val payload = LocalSnapshotStore.buildLocalPayload(store)
        return payload to LocalSnapshotStore.hashPayload(payload)
    }

    /** 远端信封 JSON（backupJson 由本地空库导出——保证结构合法）。 */
    private suspend fun envelopeJson(store: JsonStore, nickname: String = "远端昵称"): String {
        val backupJson = UserDataBackupService.exportPackage(store)
        return JsonCodec.json.encodeToString(
            CloudPayloadEnvelope(
                schemaVersion = 1,
                backupJson = backupJson,
                nickname = nickname,
                avatar = "",
                weightUnit = "kg",
            ),
        )
    }

    // --- syncNow --------------------------------------------------------------

    @Test
    fun `未登录_同步跳过`() = runBlocking {
        val store = createStore()
        val fake = FakeCloudStore()
        SyncOrchestrator.setStoreForTesting(fake)

        val result = SyncOrchestrator.syncNow(store)

        assertFalse(result.success)
        assertEquals("skipped", result.action)
        assertEquals("未登录", result.message)
        assertEquals(0, fake.pullCalls)
    }

    @Test
    fun `云端无快照_首同步推送上行`() = runBlocking {
        val store = createStore()
        loginSession(store)
        val fake = FakeCloudStore(remote = null)
        SyncOrchestrator.setStoreForTesting(fake)

        val result = SyncOrchestrator.syncNow(store)

        assertTrue(result.success)
        assertEquals("push", result.action)
        assertEquals("已同步到云端", result.message)
        assertNotNull(fake.pushed)
        val (_, hash) = localPayloadHash(store)
        // exportedAt 为导出时刻，两次 exportPackage 必不同（毫秒级）——断言走归一化 hash
        // （normalizePayloadForHash 剔除 exportedAt），而非逐字字符串比较。
        assertEquals(hash, LocalSnapshotStore.hashPayload(fake.pushed!!.payloadJson))
        assertEquals("u-1", fake.pushed!!.userId)
        // 元数据落盘：synced + 基线 = 本地 hash
        val meta = readMeta(store)!!
        assertEquals("u-1", meta.userId)
        assertEquals(hash, meta.lastSyncedHash)
        assertEquals("synced", meta.lastStatus)
    }

    @Test
    fun `双方均未变_已是最新_不再上行`() = runBlocking {
        val store = createStore()
        loginSession(store)
        val (payload, hash) = localPayloadHash(store)
        // 预置基线 = 当前 hash；远端同内容（hash 一致）
        store.writeString(
            StoreNames.SYNC,
            JsonCodec.json.encodeToString(
                SyncMeta(userId = "u-1", lastSyncedHash = hash, lastSyncAt = 1_000, autoEnabled = true, lastStatus = "synced", lastError = ""),
            ),
        )
        val fake = FakeCloudStore(remote = createCloudSnapshot("u-1", payload, updatedAt = 1_000, deviceTag = "d", schemaVersion = 1))
        SyncOrchestrator.setStoreForTesting(fake)

        val result = SyncOrchestrator.syncNow(store)

        assertTrue(result.success)
        assertEquals("none", result.action)
        assertEquals("已是最新", result.message)
        assertNull(fake.pushed)
    }

    @Test
    fun `仅远端变化_拉取恢复`() = runBlocking {
        val store = createStore()
        loginSession(store)
        val (_, hash) = localPayloadHash(store)
        store.writeString(
            StoreNames.SYNC,
            JsonCodec.json.encodeToString(
                SyncMeta(userId = "u-1", lastSyncedHash = hash, lastSyncAt = 1_000, autoEnabled = true, lastStatus = "synced", lastError = ""),
            ),
        )
        // 远端：不同内容（hash 不同）→ pull
        val fake = FakeCloudStore(
            remote = createCloudSnapshot("u-1", envelopeJson(store, nickname = "远端昵称"), updatedAt = 2_000, deviceTag = "d", schemaVersion = 1),
        )
        SyncOrchestrator.setStoreForTesting(fake)

        val result = SyncOrchestrator.syncNow(store)

        assertTrue(result.success)
        assertEquals("pull", result.action)
        assertEquals("已从云端恢复", result.message)
        val meta = readMeta(store)!!
        assertEquals("synced", meta.lastStatus)
    }

    @Test
    fun `双方都变_远端较新_冲突采用云端`() = runBlocking {
        val store = createStore()
        loginSession(store)
        store.writeString(
            StoreNames.SYNC,
            JsonCodec.json.encodeToString(
                // 基线 hash 与当前本地 hash 不同（本地已变）；lastSyncAt=1000
                SyncMeta(userId = "u-1", lastSyncedHash = "stale-hash", lastSyncAt = 1_000, autoEnabled = true, lastStatus = "synced", lastError = ""),
            ),
        )
        val fake = FakeCloudStore(
            remote = createCloudSnapshot("u-1", envelopeJson(store), updatedAt = 2_000, deviceTag = "d", schemaVersion = 1),
        )
        SyncOrchestrator.setStoreForTesting(fake)

        val result = SyncOrchestrator.syncNow(store)

        assertTrue(result.success)
        assertEquals("conflict_pull", result.action)
        assertEquals("云端数据较新，已采用云端版本", result.message)
    }

    @Test
    fun `双方都变_远端不新_推送上行`() = runBlocking {
        val store = createStore()
        loginSession(store)
        store.writeString(
            StoreNames.SYNC,
            JsonCodec.json.encodeToString(
                SyncMeta(userId = "u-1", lastSyncedHash = "stale-hash", lastSyncAt = 5_000, autoEnabled = true, lastStatus = "synced", lastError = ""),
            ),
        )
        // 远端 updatedAt=2000 <= lastSyncAt=5000 → push
        val fake = FakeCloudStore(
            remote = createCloudSnapshot("u-1", envelopeJson(store), updatedAt = 2_000, deviceTag = "d", schemaVersion = 1),
        )
        SyncOrchestrator.setStoreForTesting(fake)

        val result = SyncOrchestrator.syncNow(store)

        assertTrue(result.success)
        assertEquals("push", result.action)
        assertNotNull(fake.pushed)
    }

    @Test
    fun `上传失败_状态失败且保留旧基线`() = runBlocking {
        val store = createStore()
        loginSession(store)
        val fake = FakeCloudStore(remote = null, pushResult = false)
        SyncOrchestrator.setStoreForTesting(fake)

        val result = SyncOrchestrator.syncNow(store)

        assertFalse(result.success)
        assertEquals("push", result.action)
        assertEquals("同步上传失败，请稍后重试", result.message)
        val meta = readMeta(store)!!
        assertEquals("failed", meta.lastStatus)
        assertEquals("同步上传失败", meta.lastError)
    }

    @Test
    fun `同步异常_失败结果不抛出`() = runBlocking {
        val store = createStore()
        loginSession(store)
        SyncOrchestrator.setStoreForTesting(FakeCloudStore(throwOnPull = true))

        val result = SyncOrchestrator.syncNow(store)

        assertFalse(result.success)
        assertEquals("failed", result.action)
        assertEquals("同步失败，请稍后重试", result.message)
    }

    // --- hasPendingChanges / getState / setAutoEnabled / resetMeta ------------

    @Test
    fun `待上行判定_未登录false_切账号true_已同步false`() = runBlocking {
        val store = createStore()
        SyncOrchestrator.setStoreForTesting(FakeCloudStore())

        // 未登录 → false
        assertFalse(SyncOrchestrator.hasPendingChanges(store))

        // 登录 + 空 meta（meta.userId="" 与当前账号不同）→ true（切账号）
        loginSession(store)
        assertTrue(SyncOrchestrator.hasPendingChanges(store))

        // 基线对齐当前 hash → false
        val (_, hash) = localPayloadHash(store)
        store.writeString(
            StoreNames.SYNC,
            JsonCodec.json.encodeToString(
                SyncMeta(userId = "u-1", lastSyncedHash = hash, lastSyncAt = 1_000, autoEnabled = true, lastStatus = "synced", lastError = ""),
            ),
        )
        assertFalse(SyncOrchestrator.hasPendingChanges(store))
    }

    @Test
    fun `状态_未登录unauthenticated_登录后never`() = runBlocking {
        val store = createStore()
        SyncOrchestrator.setStoreForTesting(FakeCloudStore())

        assertEquals("unauthenticated", SyncOrchestrator.getState(store).status)

        loginSession(store)
        val state = SyncOrchestrator.getState(store)
        assertEquals("never", state.status)
        assertTrue(state.autoEnabled)
    }

    @Test
    fun `自动同步开关_落盘往返`() = runBlocking {
        val store = createStore()
        SyncOrchestrator.setAutoEnabled(store, false)
        assertFalse(readMeta(store)!!.autoEnabled)
        assertFalse(SyncOrchestrator.getState(store).autoEnabled)
    }

    @Test
    fun `登出重置_清账号与基线_保留开关`() = runBlocking {
        val store = createStore()
        store.writeString(
            StoreNames.SYNC,
            JsonCodec.json.encodeToString(
                SyncMeta(userId = "u-1", lastSyncedHash = "h", lastSyncAt = 9_999, autoEnabled = false, lastStatus = "synced", lastError = ""),
            ),
        )
        SyncOrchestrator.resetMeta(store)
        val meta = readMeta(store)!!
        assertEquals("", meta.userId)
        assertEquals("", meta.lastSyncedHash)
        assertEquals(0L, meta.lastSyncAt)
        assertEquals("never", meta.lastStatus)
        assertFalse(meta.autoEnabled) // 开关保留（源 :249）
    }

    @Test
    fun `后台静默同步_开关关闭时不触达云`() = runBlocking {
        val store = createStore()
        loginSession(store)
        SyncOrchestrator.setAutoEnabled(store, false)
        val fake = FakeCloudStore()
        SyncOrchestrator.setStoreForTesting(fake)

        SyncOrchestrator.requestBackgroundSync(store)

        assertEquals(0, fake.pullCalls)
    }

    @Test
    fun `登录钩子_云端异常不抛出`() = runBlocking {
        val store = createStore()
        loginSession(store)
        SyncOrchestrator.setStoreForTesting(FakeCloudStore(throwOnPull = true))

        // 不抛异常即通过（源 :221-229 登录流程不被同步失败中断）
        SyncOrchestrator.onSignIn(store)
    }
}

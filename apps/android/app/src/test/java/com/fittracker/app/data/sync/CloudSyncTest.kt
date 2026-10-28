package com.fittracker.app.data.sync

import androidx.datastore.preferences.core.PreferenceDataStoreFactory
import com.fittracker.app.data.persist.JsonCodec
import com.fittracker.app.data.persist.JsonStore
import com.fittracker.app.data.service.Experience
import com.fittracker.app.data.service.GoalRepository
import com.fittracker.app.data.service.TrainingPlanRepository
import com.fittracker.app.data.service.UserProfile
import com.fittracker.app.data.service.UserProfileService
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.runBlocking
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
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
import java.io.File
import java.util.concurrent.atomic.AtomicInteger

/**
 * [CloudSyncService] / [LocalSnapshotStore] / [LocalSandboxSnapshotStore] 契约测试——口径逐条对齐源
 * `shared/services/CloudSyncService.ets` 与 `CloudSnapshotStore.ets`（Wave 5）。
 *
 * 覆盖：
 * - [CloudSyncService.decideSyncAction] 决策矩阵全分支（三值 hash 组合 + 时间戳平局）；
 * - [CloudSyncService.hasPendingChanges] / [CloudSyncService.isAccountChanged] /
 *   [CloudSyncService.baselineFor] / [CloudSyncService.isValidMeta]；
 * - [LocalSnapshotStore.hashPayload] 稳定性与规范化（`exportedAt` 剔除）语义；
 * - [LocalSnapshotStore.buildLocalPayload] 整包信封往返；
 * - [LocalSandboxSnapshotStore] 快照往返、缺失 / 版本不符、userId 编码不碰撞。
 *
 * 测试手段照 `UserDataBackupServiceTest`：以 [PreferenceDataStoreFactory] 把每个用例的存储指向独立
 * 临时文件；沙盒目录指向 [TemporaryFolder]，互不污染。
 *
 * `@Config(sdk = [34])`：项目 targetSdk 37 超出 Robolectric 4.16 支持范围，必须钉到受支持 SDK
 * （原因同 `JsonStoreTest`）。
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class CloudSyncTest {

    @get:Rule
    val tempFolder: TemporaryFolder = TemporaryFolder()

    private val counter = AtomicInteger()

    private fun createStore(): JsonStore {
        val file = File(tempFolder.root, "sync_${counter.incrementAndGet()}.preferences_pb")
        val dataStore = PreferenceDataStoreFactory.create(
            scope = CoroutineScope(Dispatchers.IO + SupervisorJob()),
        ) { file }
        return JsonStore(dataStore)
    }

    /** 单例在 JVM 内跨用例存活——每例前清掉仓储内存缓存，避免串场。 */
    @Before
    fun resetSingletonState() {
        GoalRepository.clearLocal()
        TrainingPlanRepository.clearLocal()
    }

    // --- decideSyncAction：决策矩阵全分支 -----------------------------------

    private fun decide(
        localHash: String,
        remoteHash: String,
        baselineHash: String,
        remoteUpdatedAt: Long = 0L,
        lastSyncAt: Long = 0L,
    ): SyncAction = CloudSyncService.decideSyncAction(
        localHash, remoteHash, baselineHash, remoteUpdatedAt, lastSyncAt,
    )

    @Test
    fun `remote empty pushes`() { // 源 :87-89
        assertEquals(SyncAction.PUSH, decide("L", "", "B"))
    }

    @Test
    fun `remote empty takes priority over unchanged local`() { // 首分支优先于 :90
        assertEquals(SyncAction.PUSH, decide("B", "", "B"))
    }

    @Test
    fun `both equal baseline is none`() { // 源 :90-92
        assertEquals(SyncAction.NONE, decide("B", "B", "B"))
    }

    @Test
    fun `local unchanged remote changed pulls`() { // 源 :90-92
        assertEquals(SyncAction.PULL, decide("B", "R", "B"))
    }

    @Test
    fun `local changed remote unchanged pushes`() { // 源 :93-95
        assertEquals(SyncAction.PUSH, decide("L", "B", "B"))
    }

    @Test
    fun `both changed remote newer conflict pulls`() { // 源 :96
        assertEquals(SyncAction.CONFLICT_PULL, decide("L", "R", "B", remoteUpdatedAt = 200L, lastSyncAt = 100L))
    }

    @Test
    fun `both changed remote older pushes`() { // 源 :96
        assertEquals(SyncAction.PUSH, decide("L", "R", "B", remoteUpdatedAt = 100L, lastSyncAt = 200L))
    }

    @Test
    fun `both changed equal timestamps pushes`() { // 源 :96 严格大于——平局判 push
        assertEquals(SyncAction.PUSH, decide("L", "R", "B", remoteUpdatedAt = 100L, lastSyncAt = 100L))
    }

    @Test
    fun `both changed identically still follows conflict rule`() { // local==remote 且均 != 基线 → 仍走冲突分支
        assertEquals(SyncAction.CONFLICT_PULL, decide("H2", "H2", "B", remoteUpdatedAt = 500L, lastSyncAt = 100L))
        assertEquals(SyncAction.PUSH, decide("H2", "H2", "B", remoteUpdatedAt = 100L, lastSyncAt = 500L))
    }

    // --- hasPendingChanges / isAccountChanged / baselineFor -----------------

    @Test
    fun `isAccountChanged detects switch`() {
        assertFalse(CloudSyncService.isAccountChanged("user-a", "user-a"))
        assertTrue(CloudSyncService.isAccountChanged("user-a", "user-b"))
        assertTrue(CloudSyncService.isAccountChanged("", "user-b"))
    }

    @Test
    fun `baseline follows account`() {
        val meta = SyncMeta("user-a", "hash-x", 42L, "synced", "")
        val same = CloudSyncService.baselineFor(meta, "user-a")
        assertEquals("hash-x", same.hash)
        assertEquals(42L, same.at)
        val switched = CloudSyncService.baselineFor(meta, "user-b")
        assertEquals("", switched.hash)
        assertEquals(0L, switched.at)
    }

    @Test
    fun `no pending changes when logged out`() { // 源 :135-137
        assertFalse(CloudSyncService.hasPendingChanges("user-a", "", "local", "local"))
    }

    @Test
    fun `pending changes when account switched`() { // 源 :139-141
        assertTrue(CloudSyncService.hasPendingChanges("user-a", "user-b", "local", "local"))
    }

    @Test
    fun `pending changes compare local hash to baseline`() { // 源 :143
        assertFalse(CloudSyncService.hasPendingChanges("user-a", "user-a", "same", "same"))
        assertTrue(CloudSyncService.hasPendingChanges("user-a", "user-a", "local", "baseline"))
    }

    @Test
    fun `default meta mirrors source fallback`() { // 源 :344
        val meta = CloudSyncService.defaultMeta()
        assertEquals("", meta.userId)
        assertEquals("", meta.lastSyncedHash)
        assertEquals(0L, meta.lastSyncAt)
        assertEquals("never", meta.lastStatus)
        assertEquals("", meta.lastError)
        assertTrue(CloudSyncService.isValidMeta(meta))
        assertFalse(CloudSyncService.isValidMeta(null))
    }

    // --- hashPayload：稳定性 + 规范化 ---------------------------------------

    /** 构造与源同形的信封 JSON（`backupJson` 为嵌套 JSON 字符串）。 */
    private fun envelopeJson(
        exportedAt: Long,
        nickname: String = "小明",
        schemaVersion: Int = ENVELOPE_SCHEMA_VERSION,
        experience: String? = null,
        avatarImage: String? = null,
    ): String {
        val backup: String = JsonCodec.json.encodeToString(JsonObject.serializer(), buildJsonObject {
            put("schemaVersion", 1)
            put("exportedAt", exportedAt) // 唯一易变字段
            put("goal", JsonNull)
            put("plans", JsonArray(emptyList()))
            put("currentPlanId", "")
            put("sessions", JsonArray(emptyList()))
            put("contentMeta", buildJsonObject { put("contentVersion", 0) })
        })
        return JsonCodec.json.encodeToString(JsonObject.serializer(), buildJsonObject {
            put("schemaVersion", schemaVersion)
            put("backupJson", backup)
            put("nickname", nickname)
            put("avatar", "")
            put("weightUnit", "kg")
            // null → 不写该键，模拟旧信封（新端读到缺省字段为 null）。
            if (experience != null) {
                put("experience", experience)
            }
            if (avatarImage != null) {
                put("avatarImage", avatarImage)
                put("avatarImageHash", if (avatarImage.isEmpty()) "" else LocalSnapshotStore.djb2Hex(avatarImage))
            }
        })
    }

    @Test
    fun `hash is stable for identical payload`() {
        val payload = envelopeJson(1_000L)
        assertEquals(LocalSnapshotStore.hashPayload(payload), LocalSnapshotStore.hashPayload(payload))
    }

    @Test
    fun `hash ignores exportedAt`() { // 规范化剔除 exportedAt（源 :301-308）
        val a = envelopeJson(1_000L)
        val b = envelopeJson(9_999_999L)
        assertNotEquals(a, b) // 原文不同
        assertEquals(LocalSnapshotStore.hashPayload(a), LocalSnapshotStore.hashPayload(b)) // 规范化后 hash 相同
    }

    @Test
    fun `hash changes when content changes`() {
        assertNotEquals(
            LocalSnapshotStore.hashPayload(envelopeJson(1_000L, nickname = "小明")),
            LocalSnapshotStore.hashPayload(envelopeJson(1_000L, nickname = "小红")),
        )
    }

    @Test
    fun `hash changes when training experience changes`() { // 经验未入 hash 视图则同步对它失明
        assertNotEquals(
            LocalSnapshotStore.hashPayload(envelopeJson(1_000L, experience = "beginner")),
            LocalSnapshotStore.hashPayload(envelopeJson(1_000L, experience = "advanced")),
        )
    }

    @Test
    fun `hash changes when avatar image changes`() { // 头像摘要入视图；整段 base64 不入
        assertNotEquals(
            LocalSnapshotStore.hashPayload(envelopeJson(1_000L, avatarImage = "AAAA")),
            LocalSnapshotStore.hashPayload(envelopeJson(1_000L, avatarImage = "BBBB")),
        )
    }

    @Test
    fun `legacy envelope without avatar differs from explicit empty`() { // 未知 vs 明确无图
        assertNotEquals(
            LocalSnapshotStore.hashPayload(envelopeJson(1_000L)),
            LocalSnapshotStore.hashPayload(envelopeJson(1_000L, avatarImage = "")),
        )
    }

    @Test
    fun `hash has hex summary and hex length suffix`() { // 源 :294
        val hash = LocalSnapshotStore.hashPayload(envelopeJson(1_000L))
        val parts = hash.split("_")
        assertEquals(2, parts.size)
        assertTrue(parts[0].isNotEmpty() && parts[0].all { it in '0'..'f' })
        assertTrue(parts[1].isNotEmpty() && parts[1].all { it in '0'..'f' })
    }

    @Test
    fun `normalize returns input on invalid json`() { // 源 :322-324
        assertEquals("not json", LocalSnapshotStore.normalizePayloadForHash("not json"))
    }

    // --- 整包信封构建 / 读取 -------------------------------------------------

    @Test
    fun `buildLocalPayload round trips into envelope`() = runBlocking {
        val store = createStore()
        val payload = LocalSnapshotStore.buildLocalPayload(store)
        val envelope = LocalSnapshotStore.parseEnvelope(payload)
        assertNotNull(envelope)
        assertEquals(ENVELOPE_SCHEMA_VERSION, envelope!!.schemaVersion)
        assertEquals("kg", envelope.weightUnit) // 缺省资料单位
        // backupJson 自身可解析（为美化备份包 JSON）
        val backup = JsonCodec.json.parseToJsonElement(envelope.backupJson).jsonObjectOrNull()
        assertNotNull(backup)
    }

    @Test
    fun `buildLocalPayload hash stable across rebuilds`() = runBlocking { // exportedAt 不参与变更检测
        val store = createStore()
        val first = LocalSnapshotStore.buildLocalPayload(store)
        val second = LocalSnapshotStore.buildLocalPayload(store)
        assertEquals(LocalSnapshotStore.hashPayload(first), LocalSnapshotStore.hashPayload(second))
    }

    @Test
    fun `readCurrentEnvelope returns current package`() = runBlocking {
        val store = createStore()
        val envelope = LocalSnapshotStore.readCurrentEnvelope(store)
        assertNotNull(envelope)
        assertEquals(ENVELOPE_SCHEMA_VERSION, envelope!!.schemaVersion)
    }

    @Test
    fun `parseEnvelope rejects malformed payload`() {
        assertNull(LocalSnapshotStore.parseEnvelope("nope"))
        assertNull(LocalSnapshotStore.parseEnvelope("{\"schemaVersion\":1}")) // 缺 backupJson
    }

    @Test
    fun `envelope carries training experience from profile`() = runBlocking {
        val store = createStore()
        UserProfileService.saveProfile(store, UserProfile(experience = Experience.ADVANCED))
        val envelope = LocalSnapshotStore.readCurrentEnvelope(store)
        assertEquals("advanced", envelope?.experience)
    }

    @Test
    fun `legacy envelope without experience parses as null`() { // 旧端信封 → 下行保留本地值
        assertNull(LocalSnapshotStore.parseEnvelope(envelopeJson(1_000L))?.experience)
    }

    @Test
    fun `envelope carries avatar image base64 and hash from profile file`() = runBlocking {
        val store = createStore()
        val avatarFile = File(tempFolder.root, "avatar_test.jpg").apply {
            writeBytes(ByteArray(32) { index -> index.toByte() })
        }
        UserProfileService.saveProfile(store, UserProfile(avatarImagePath = avatarFile.absolutePath))

        val envelope = LocalSnapshotStore.readCurrentEnvelope(store)

        val expectedBase64 = java.util.Base64.getEncoder().encodeToString(avatarFile.readBytes())
        assertEquals(expectedBase64, envelope?.avatarImage)
        assertEquals(LocalSnapshotStore.djb2Hex(expectedBase64), envelope?.avatarImageHash)
    }

    @Test
    fun `legacy envelope without avatar parses avatar fields as null`() {
        val envelope = LocalSnapshotStore.parseEnvelope(envelopeJson(1_000L))
        assertNull(envelope?.avatarImage)
        assertNull(envelope?.avatarImageHash)
    }

    private fun kotlinx.serialization.json.JsonElement.jsonObjectOrNull(): JsonObject? =
        this as? JsonObject

    // --- LocalSandboxSnapshotStore ------------------------------------------

    private fun sandbox(): LocalSandboxSnapshotStore =
        LocalSandboxSnapshotStore(File(tempFolder.root, "sandbox"))

    @Test
    fun `sandbox push pull round trip`() = runBlocking { // 源 :49 / :66
        val store = sandbox()
        val snapshot = createCloudSnapshot("user-1", "{\"a\":1}", 123L, "local-device", SNAPSHOT_SCHEMA_VERSION)
        assertTrue(store.push(snapshot))
        assertEquals(snapshot, store.pull("user-1"))
    }

    @Test
    fun `sandbox pull missing returns null`() = runBlocking { // 源 :51
        assertNull(sandbox().pull("nobody"))
    }

    @Test
    fun `sandbox pull rejects wrong schema version`() = runBlocking { // 源 :127
        val store = sandbox()
        assertTrue(store.push(createCloudSnapshot("u", "{}", 1L, "d", 99)))
        assertNull(store.pull("u"))
    }

    @Test
    fun `sandbox user ids do not collide`() = runBlocking { // 源 :86 可逆编码
        val store = sandbox()
        val first = createCloudSnapshot("a b", "{\"v\":1}", 1L, "d", SNAPSHOT_SCHEMA_VERSION)
        val second = createCloudSnapshot("a+b", "{\"v\":2}", 2L, "d", SNAPSHOT_SCHEMA_VERSION)
        assertTrue(store.push(first))
        assertTrue(store.push(second))
        assertEquals(first, store.pull("a b"))
        assertEquals(second, store.pull("a+b"))
    }

    @Test
    fun `sandbox forFilesDir nests cloud_sandbox`() = runBlocking { // 源 :78-79
        val filesDir = File(tempFolder.root, "files")
        val store = LocalSandboxSnapshotStore.forFilesDir(filesDir)
        assertTrue(store.push(createCloudSnapshot("u", "{}", 1L, "d", SNAPSHOT_SCHEMA_VERSION)))
        assertTrue(
            File(filesDir, LocalSandboxSnapshotStore.SANDBOX_SNAPSHOT_DIR + "/u.json").exists(),
        )
    }
}

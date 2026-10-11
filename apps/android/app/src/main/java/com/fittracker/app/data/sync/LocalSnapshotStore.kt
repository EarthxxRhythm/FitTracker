package com.fittracker.app.data.sync

import com.fittracker.app.data.persist.JsonCodec
import com.fittracker.app.data.persist.JsonStore
import com.fittracker.app.data.service.UserProfileService
import com.fittracker.app.data.service.backup.UserDataBackupService
import kotlinx.serialization.Serializable
import kotlinx.serialization.decodeFromString
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.put
import java.io.File
import java.net.URLEncoder

/**
 * 本地快照——整包载荷构建 / 读取 + 变更检测 hash + 本地沙盒快照存储。移植自鸿蒙
 * `entry/src/main/ets/shared/services/CloudSyncService.ets`
 * （`buildLocalPayload` `:249`、`hashPayload` `:288`、`normalizePayloadForHash` `:297`）与
 * `CloudSnapshotStore.ets` 的本地沙盒实现（`LocalSandboxSnapshotStore` `:48`）。
 *
 * 两块职责：
 * 1. [LocalSnapshotStore]——把本地数据聚成整包 JSON 信封（复用 [UserDataBackupService.exportPackage]，
 *    其内部即 [UserDataBackupService.createPackage]），并对载荷做**规范化 + djb2 摘要**。同一次同步的
 *    「本地 hash / 云端 hash / 基线 hash」三值均经此算得（源 `syncNow` `:157` / `:175`）。
 * 2. [LocalSandboxSnapshotStore]——以本机文件模拟云端「每用户一条快照」（AGC 未配置 / 测试环境），
 *    即源 `CloudSnapshotStore.ets:48` 的移植，实现 [CloudSnapshotStore] 契约。
 *
 * 与源的**注入式差异**（Wave 3 既定纪律，沿用 [UserDataBackupService]）：源各方法首参
 * `context: Context` → 安卓侧改为注入 [JsonStore]（载荷侧）或沙盒目录 [File]（文件侧）；`async` → `suspend`。
 * 方法名与源逐一对齐。
 */

/**
 * 载荷信封（源 `CloudSyncService.ets:56` `interface CloudPayloadEnvelope`）——把整包备份 + 用户资料
 * 一起上传。字段名与源逐字对齐（互操作）。
 */
@Serializable
data class CloudPayloadEnvelope(
    val schemaVersion: Int = ENVELOPE_SCHEMA_VERSION,
    val backupJson: String,
    val nickname: String = "",
    val avatar: String = "",
    val weightUnit: String = "kg",
)

/**
 * 本地整包载荷构建 / 读取 + 变更检测 hash。
 *
 * 「本地整包」= [CloudPayloadEnvelope] 信封 JSON；其 `backupJson` 是
 * [UserDataBackupService.exportPackage] 的输出（即 `UserDataBackupService.createPackage` 构建、
 * 美化序列化后的备份包）。
 */
object LocalSnapshotStore {

    /**
     * 源 `:249` `buildLocalPayload`——聚合本地数据为整包 JSON 信封。
     *
     * 复用 [UserDataBackupService.exportPackage]（源 `:250` 同款；其内部以
     * [UserDataBackupService.createPackage] 构建包）读取备份包，再读用户资料（源 `:251`
     * `UserProfileService.loadProfile`）拼成信封，紧凑序列化（源 `:256` `JSON.stringify(envelope)`
     * → [JsonCodec.json] 无美化）。
     */
    suspend fun buildLocalPayload(store: JsonStore): String {
        val backupJson: String = UserDataBackupService.exportPackage(store) // 源 :250（createPackage 于其中）
        val profile: ProfileLike = loadProfile(store) // 源 :251
        val envelope: CloudPayloadEnvelope = CloudPayloadEnvelope( // 源 :252-255
            schemaVersion = ENVELOPE_SCHEMA_VERSION, // 源 :253
            backupJson = backupJson, // 源 :254
            nickname = profile.nickname,
            avatar = profile.avatar,
            weightUnit = profile.weightUnit,
        )
        return JsonCodec.json.encodeToString(CloudPayloadEnvelope.serializer(), envelope) // 源 :256
    }

    /** 解析信封；非 JSON / 缺必填字段 → `null`（源 `applyRemotePayload` 的容错口径 `:262-264`）。 */
    fun parseEnvelope(payload: String): CloudPayloadEnvelope? = try {
        JsonCodec.json.decodeFromString(CloudPayloadEnvelope.serializer(), payload)
    } catch (error: Exception) {
        null
    }

    /** 读取当前本地整包信封（构建后即刻解析回读）；解析失败返回 `null`。 */
    suspend fun readCurrentEnvelope(store: JsonStore): CloudPayloadEnvelope? =
        parseEnvelope(buildLocalPayload(store))

    /** 源 `:250-251`——读备份包 + 用户资料，投影为信封所需的三个资料字段。 */
    private suspend fun loadProfile(store: JsonStore): ProfileLike {
        val profile = UserProfileService.loadProfile(store) // 源 :251
        return ProfileLike(
            nickname = profile.nickname,
            avatar = profile.avatar,
            weightUnit = profile.weightUnit.id,
        )
    }

    /**
     * 变更检测 hash（源 `:288` `hashPayload`）——先规范化（剔除 `exportedAt` 等易变字段），
     * 再取 djb2 摘要；输出 `<十六进制摘要>_<规范化长度十六进制>`。
     *
     * 逐位对齐源：`hashValue = ((hashValue << 5) + hashValue + code) | 0`（Kotlin [Int] 环绕即
     * 32 位截断），最终以 `>>> 0` 无符号十六进制输出。`charCodeAt` → [Char.code]（均为 UTF-16 码元），
     * `length` → [String.length]（同为 UTF-16 码元数）。
     *
     * 非安全用途——碰撞 / 漂移的代价仅为额外一次上行同步（源 `:285-287`）。
     */
    fun hashPayload(payload: String): String {
        val canonical: String = normalizePayloadForHash(payload) // 源 :289
        var hashValue: Int = 5381 // 源 :290
        for (index in canonical.indices) { // 源 :291
            hashValue = (hashValue shl 5) + hashValue + canonical[index].code // 源 :292
        }
        return hashValue.toUInt().toString(16) + "_" + canonical.length.toString(16) // 源 :294
    }

    /**
     * 源 `:297` `normalizePayloadForHash`——重建确定性视图：剔除 `exportedAt`（`exportedAt` 每次
     * 导出都变，不参与变更检测），并按源字段序紧凑重排：内层 `schemaVersion` / `goal` / `plans` /
     * `currentPlanId` / `sessions` / `contentMeta`，外层 `schemaVersion` / `backupJson` / `nickname` /
     * `avatar` / `weightUnit`。解析失败 → 原样返回（源 `:322-324` catch）。
     *
     * 说明（跨端口径）：本方法保证**同一端口内**的确定性（同样的语义数据必得同样 hash）。跨鸿蒙 /
     * 安卓的**字节级**一致受 JSON 数字格式（JS `625` vs Kotlin `625.0`）与对象字段序影响，未强制对齐
     * ——漂移代价仅一次多余上行（见源 `:285-287`）。
     */
    fun normalizePayloadForHash(payload: String): String = try {
        val envelope: JsonObject = Json.parseToJsonElement(payload).jsonObject // 源 :298
        val backup: JsonObject = // 源 :299
            Json.parseToJsonElement(envelope.getValue("backupJson").jsonPrimitive.content).jsonObject
        val backupView: JsonObject = buildJsonObject { // 源 :301-308（JSON.stringify 的字段序）
            put("schemaVersion", backup["schemaVersion"] ?: JsonNull)
            put("goal", backup["goal"] ?: JsonNull)
            put("plans", backup["plans"] ?: JsonNull)
            put("currentPlanId", backup["currentPlanId"] ?: JsonNull)
            put("sessions", backup["sessions"] ?: JsonNull)
            put("contentMeta", backup["contentMeta"] ?: JsonNull)
        }
        val view: JsonObject = buildJsonObject { // 源 :309-317
            put("schemaVersion", envelope["schemaVersion"] ?: JsonNull)
            put(
                "backupJson",
                JsonPrimitive(JsonCodec.json.encodeToString(JsonObject.serializer(), backupView)),
            )
            put("nickname", envelope["nickname"] ?: JsonNull)
            put("avatar", envelope["avatar"] ?: JsonNull)
            put("weightUnit", envelope["weightUnit"] ?: JsonNull)
        }
        JsonCodec.json.encodeToString(JsonObject.serializer(), view) // 源 :318
    } catch (error: Exception) {
        payload // 源 :322-324
    }

    /** 内部投影：仅取信封所需的资料字段（[UserProfileService.UserProfile] 的子集）。 */
    private data class ProfileLike(
        val nickname: String,
        val avatar: String,
        val weightUnit: String,
    )
}

/**
 * 本地沙盒快照存储（源 `CloudSnapshotStore.ets:48` `LocalSandboxSnapshotStore`）——以
 * `<sandboxDir>/<encodeUserId>.json` 模拟云端「每用户一条快照」。
 *
 * 注入式差异：源构造无参、内部用 `context.filesDir + '/cloud_sandbox'`；安卓侧构造注入沙盒目录
 * [sandboxDir]，便于单测指向临时目录。[forFilesDir] 供生产侧以 `context.filesDir` 构造。
 */
class LocalSandboxSnapshotStore(
    private val sandboxDir: File,
) : CloudSnapshotStore {

    /** 源 `:49` `pull`——文件不存在 / 解析失败 / 校验不过均按「无快照」返回 `null`。 */
    override suspend fun pull(userId: String): CloudSnapshot? {
        val filePath: File = resolveFilePath(userId)
        if (!filePath.exists()) { // 源 :51
            return null
        }
        return try {
            val json: String = filePath.readText() // 源 :53
            val snapshot: CloudSnapshot =
                JsonCodec.json.decodeFromString(CloudSnapshot.serializer(), json) // 源 :54-55
            if (isValidSnapshot(snapshot)) snapshot else null // 源 :57
        } catch (error: Exception) {
            null // 源 :59-60
        }
    }

    /** 源 `:66` `push`——写盘成功返回 `true`；异常返回 `false`。 */
    override suspend fun push(snapshot: CloudSnapshot): Boolean = try {
        sandboxDir.mkdirs() // 源 :70（ensureDirectory）
        resolveFilePath(snapshot.userId) // 源 :71
            .writeText(JsonCodec.json.encodeToString(CloudSnapshot.serializer(), snapshot))
        true
    } catch (error: Exception) {
        false // 源 :74
    }

    /** 源 `:82-83` `resolveFilePath`。 */
    private fun resolveFilePath(userId: String): File =
        File(sandboxDir, encodeUserId(userId) + ".json")

    /**
     * 源 `:86` `encodeUserId`——可逆编码：不同 `userId` 绝不映射到同一文件名（避免有损替换的
     * 跨账号碰撞）。源用 `encodeURIComponent`，安卓用 [URLEncoder]（空格编为 `+` 而非 `%20`，
     * 但仍是单射，且沙盒文件名仅本机使用、不参与云同步）。
     */
    private fun encodeUserId(userId: String): String {
        val encoded: String = URLEncoder.encode(userId, Charsets.UTF_8.name()) // 源 :88
        return encoded.ifEmpty { "unknown" } // 源 :89
    }

    /**
     * 源 `:123` `isValidSnapshot`——schema 一致 + `userId` / `payloadJson` 非空。
     * 源对 `updatedAt` 的 `Number.isFinite` 守卫在 `Long` 下恒成立，故省略。
     */
    private fun isValidSnapshot(snapshot: CloudSnapshot): Boolean {
        if (snapshot.schemaVersion != SNAPSHOT_SCHEMA_VERSION) { // 源 :127
            return false
        }
        if (snapshot.userId.isEmpty()) { // 源 :130
            return false
        }
        if (snapshot.payloadJson.isEmpty()) { // 源 :133
            return false
        }
        return true
    }

    companion object {
        /** 源 `:13` `SANDBOX_SNAPSHOT_DIR`。 */
        const val SANDBOX_SNAPSHOT_DIR: String = "cloud_sandbox"

        /** 生产默认：`<filesDir>/cloud_sandbox`（源 `:78-79` `resolveDirPath`）。 */
        fun forFilesDir(filesDir: File): LocalSandboxSnapshotStore =
            LocalSandboxSnapshotStore(File(filesDir, SANDBOX_SNAPSHOT_DIR))
    }
}

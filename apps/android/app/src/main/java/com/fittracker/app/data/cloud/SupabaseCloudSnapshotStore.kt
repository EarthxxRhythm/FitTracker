package com.fittracker.app.data.cloud

import com.fittracker.app.data.persist.JsonCodec
import com.fittracker.app.data.sync.CloudSnapshot
import com.fittracker.app.data.sync.CloudSnapshotStore
import com.fittracker.app.data.sync.CloudSyncService
import com.fittracker.app.data.sync.SNAPSHOT_SCHEMA_VERSION
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.put
import java.util.Calendar
import java.util.TimeZone

/** UTC 时区——ISO8601 生成 / 解析的固定基准（Supabase `timestamptz` 恒带时区）。 */
private val UTC: TimeZone = TimeZone.getTimeZone("UTC")

/** `push` 的 PostgREST 偏好头：按主键 upsert + 不返回行体（2xx 即成功）。 */
private const val PREFER_UPSERT_MINIMAL: String = "resolution=merge-duplicates,return=minimal"

/**
 * Supabase（PostgREST）快照存储——[CloudSnapshotStore] 的云端实现，Wave 6。
 *
 * 映射表 `public.snapshots(user_id uuid PK / payload jsonb / updated_at timestamptz)`
 * （迁移 `supabase/migrations/20261004000000_snapshots.sql`）：
 * `userId`↔`user_id`、`payloadJson`↔`payload`、`updatedAt`↔`updated_at`。
 * `deviceTag` / `schemaVersion` 为本地字段，表中不持久化（`pull` 侧以本机缺省补齐）。
 *
 * ```
 * pull:  GET  {rest}/snapshots?user_id=eq.<user>&select=payload,updated_at&limit=1
 *          → 200 + []      → null                （云端无快照）
 *          → 200 + [row]   → CloudSnapshot(row)  （payload jsonb 内联 → 字符串）
 *          → 非 2xx        → null
 * push:  POST {rest}/snapshots   Prefer: resolution=merge-duplicates,return=minimal
 *          body [{"user_id":…,"payload":<json>,"updated_at":<ISO8601 UTC>}]
 *          → 2xx → true / 其余 → false
 * ```
 *
 * 两处口径（照基建既有纪律）：
 * - **jsonb 内联**：PostgREST 把 `jsonb` 列作为**内联 JSON 值**返回（非转义字符串），故 `pull` 侧
 *   用 `JsonElement.toString()` 序列化回字符串；`push` 侧把 `payloadJson` 解析成 `JsonElement`
 *   再放进 body，交由列按 jsonb 存储。
 * - **时间单位 = 毫秒**：全库时间戳（`SandboxAuthProvider.signedInAt`、`UserDataBackupService.exportedAt`
 *   …）统一用 `System.currentTimeMillis()`（源侧 `Date.now()`），故 [CloudSnapshot.updatedAt] 亦为
 *   epoch **毫秒**。ISO8601 生成 / 解析用 [java.util.Calendar]（`minSdk = 24` 且未启用 core library
 *   desugaring，不用 `java.time`——同 `StatsDashboardService` 口径）。
 */
class SupabaseCloudSnapshotStore(
    private val transport: CloudHttpTransport = UrlConnectionTransport,
    private val accessTokenProvider: suspend () -> String? = { null },
) : CloudSnapshotStore {

    /** 拉取指定用户最新快照；云端无快照 / 非 2xx / 解析失败均返回 `null`。 */
    override suspend fun pull(userId: String): CloudSnapshot? {
        val accessToken: String? = accessTokenProvider()
        val url: String =
            SupabaseEndpoints.rest("snapshots?user_id=eq.$userId&select=payload,updated_at&limit=1")
        val response: CloudHttpResponse = transport.request(
            method = "GET",
            url = url,
            headers = SupabaseEndpoints.headers(accessToken),
        )
        if (response.status !in 200..299) {
            return null // 鉴权失败 / 服务端错误 → 按「无快照」处理（决策内核据此走 PUSH）
        }
        val root: JsonElement = try {
            JsonCodec.json.parseToJsonElement(response.body)
        } catch (error: Exception) {
            return null // 非 JSON 响应体
        }
        val rows: JsonArray = root as? JsonArray ?: return null
        val row: JsonObject = rows.firstOrNull() as? JsonObject ?: return null // 空数组 → null
        val payload: JsonElement = row["payload"] ?: return null
        val updatedAtText: String =
            (row["updated_at"] as? JsonPrimitive)?.contentOrNull ?: return null
        val updatedAt: Long = epochMillisFromIso8601(updatedAtText) ?: return null
        return CloudSnapshot(
            userId = userId,
            payloadJson = payload.toString(), // jsonb 内联 → 序列化回字符串
            updatedAt = updatedAt,
            deviceTag = CloudSyncService.DEVICE_TAG, // 本地字段，表中不持久化
            schemaVersion = SNAPSHOT_SCHEMA_VERSION,
        )
    }

    /** 写入 / 覆盖用户快照（upsert）；2xx 视为成功。 */
    override suspend fun push(snapshot: CloudSnapshot): Boolean {
        val accessToken: String? = accessTokenProvider()
        val parsed: JsonElement = try {
            JsonCodec.json.parseToJsonElement(snapshot.payloadJson) // 内联为 JSON 值交由 jsonb 列存储
        } catch (error: Exception) {
            return false // 载荷非合法 JSON，拒绝上行
        }
        // 载荷契约为 CloudPayloadEnvelope 对象——仅接受 JSON 对象。kotlinx 会把单 token 裸串
        // （如 `not-json`）宽松解析为 JsonLiteral（非对象），此处一并拒绝，避免把非法 body 发出去。
        val payload: JsonObject = parsed as? JsonObject ?: return false
        val body: JsonObject = buildJsonObject {
            put("user_id", snapshot.userId)
            put("payload", payload)
            put("updated_at", iso8601UtcFromEpochMillis(snapshot.updatedAt))
        }
        val response: CloudHttpResponse = transport.request(
            method = "POST",
            url = SupabaseEndpoints.rest("snapshots"),
            headers = SupabaseEndpoints.headers(accessToken) +
                mapOf("Prefer" to PREFER_UPSERT_MINIMAL),
            body = JsonCodec.json.encodeToString(JsonObject.serializer(), body),
        )
        return response.status in 200..299
    }
}

/**
 * epoch **毫秒** → ISO8601 UTC 串（毫秒精度）：`2026-10-04T12:34:56.789Z`。
 *
 * 手写而非 `SimpleDateFormat`——避免可变小数位 / 时区模式（`XXX`）的解析歧义；输出恒定位数，
 * 便于逐字节断言。零第三方依赖，`Calendar` 在 `minSdk = 24` 直接可用。
 */
internal fun iso8601UtcFromEpochMillis(millis: Long): String {
    val calendar: Calendar = Calendar.getInstance(UTC).apply { timeInMillis = millis }
    return buildString {
        append(padNumber(calendar.get(Calendar.YEAR), 4))
        append('-')
        append(padNumber(calendar.get(Calendar.MONTH) + 1, 2))
        append('-')
        append(padNumber(calendar.get(Calendar.DAY_OF_MONTH), 2))
        append('T')
        append(padNumber(calendar.get(Calendar.HOUR_OF_DAY), 2))
        append(':')
        append(padNumber(calendar.get(Calendar.MINUTE), 2))
        append(':')
        append(padNumber(calendar.get(Calendar.SECOND), 2))
        append('.')
        append(padNumber(calendar.get(Calendar.MILLISECOND), 3))
        append('Z')
    }
}

/**
 * ISO8601 串 → epoch **毫秒**（与 [iso8601UtcFromEpochMillis] 互逆）。
 *
 * 接受 `YYYY-MM-DDTHH:MM:SS[.fraction][Z|±HH:MM|±HHMM]`（`T` 亦容忍 `t` / 空格分隔符，无时区后缀按 UTC）：
 * PostgREST 的 `timestamptz` 通常带微秒（6 位）与非 `Z` 偏移（如 `+00:00`）。小数秒截断 / 补齐到毫秒
 * （第 4 位起丢弃——本项目时间基准为毫秒）。格式不符 / 字段越界返回 `null`。
 */
internal fun epochMillisFromIso8601(text: String): Long? {
    if (text.length < 19) return null // 最短：YYYY-MM-DDTHH:MM:SS
    val year: Int = readFixedInt(text, 0, 4) ?: return null
    if (text[4] != '-') return null
    val month: Int = readFixedInt(text, 5, 2) ?: return null
    if (text[7] != '-') return null
    val day: Int = readFixedInt(text, 8, 2) ?: return null
    val dateTimeSeparator: Char = text[10]
    if (dateTimeSeparator != 'T' && dateTimeSeparator != 't' && dateTimeSeparator != ' ') return null
    val hour: Int = readFixedInt(text, 11, 2) ?: return null
    if (text[13] != ':') return null
    val minute: Int = readFixedInt(text, 14, 2) ?: return null
    if (text[16] != ':') return null
    val second: Int = readFixedInt(text, 17, 2) ?: return null

    var index: Int = 19
    var millisOfSecond: Int = 0
    if (index < text.length && text[index] == '.') {
        index++
        val fractionStart: Int = index
        while (index < text.length && text[index].isDigit()) index++
        if (index == fractionStart) return null // 小数点后无数字
        val fraction: String = text.substring(fractionStart, index)
        millisOfSecond = (fraction + "000").substring(0, 3).toInt() // 前 3 位即毫秒
    }

    val offsetMillis: Long = parseZoneOffsetMillis(text.substring(index)) ?: return null
    if (month !in 1..12 || day !in 1..31 || hour !in 0..23 || minute !in 0..59 || second !in 0..59) {
        return null
    }
    val calendar: Calendar = Calendar.getInstance(UTC).apply {
        clear()
        set(year, month - 1, day, hour, minute, second)
    }
    return calendar.timeInMillis - offsetMillis + millisOfSecond
}

/** 解析时区后缀为相对 UTC 的毫秒偏移；`Z`/空 → 0，`±HH:MM` / `±HHMM` / `±HH` → 有符号偏移。 */
private fun parseZoneOffsetMillis(zoneText: String): Long? {
    if (zoneText.isEmpty() || zoneText == "Z" || zoneText == "z") return 0L
    if (zoneText.length < 3) return null
    val sign: Char = zoneText[0]
    if (sign != '+' && sign != '-') return null
    val offsetHour: Int = readFixedInt(zoneText, 1, 2) ?: return null
    val rest: String = zoneText.substring(3)
    val offsetMinute: Int = when {
        rest.isEmpty() -> 0
        rest.startsWith(":") -> readFixedInt(rest, 1, 2) ?: return null
        else -> readFixedInt(rest, 0, 2) ?: return null
    }
    val magnitude: Long = (offsetHour * 60L + offsetMinute) * 60_000L
    return if (sign == '-') -magnitude else magnitude
}

/** 读取 [start] 起 [length] 位十进制数；越界 / 含非数字返回 `null`。 */
private fun readFixedInt(text: String, start: Int, length: Int): Int? {
    if (start < 0 || start + length > text.length) return null
    var value: Int = 0
    for (position in start until start + length) {
        val digit: Char = text[position]
        if (digit !in '0'..'9') return null
        value = value * 10 + (digit - '0')
    }
    return value
}

/** 左侧补零到固定宽度（`padStart`）。 */
private fun padNumber(value: Int, width: Int): String = value.toString().padStart(width, '0')

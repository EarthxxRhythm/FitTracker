package com.fittracker.app.data.cloud

import com.fittracker.app.data.sync.CloudSnapshot
import com.fittracker.app.data.sync.SNAPSHOT_SCHEMA_VERSION
import kotlinx.coroutines.runBlocking
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.Instant

/**
 * [SupabaseCloudSnapshotStore] 契约测试——PostgREST `snapshots` 读写口径（Wave 6）。
 *
 * 覆盖：
 * - `pull` 请求构造（GET / URL / Bearer 取自 `accessTokenProvider`）与响应分支（空数组→null、
 *   单行解析含 jsonb 内联、非 2xx→null、非数组→null、缺字段→null、微秒 / 非 UTC 偏移解析）；
 * - `push` 请求构造（POST / `Prefer` 头 / body 三字段）与分支（2xx→true、4xx→false、非法载荷静默失败）；
 * - `accessToken = null` 时回退到 publishable key。
 *
 * 手段：纯 JVM 普通 JUnit——`SupabaseCloudSnapshotStore` 只经 [CloudHttpTransport] 触网，注入
 * [RecordingTransport] 即可，无需 Robolectric / 真实存储。期望时间戳用 `java.time.Instant` 作**独立
 * 判据**（被测实现刻意不依赖 `java.time`，测试侧用它交叉验证毫秒口径）。
 */
class SupabaseCloudSnapshotStoreTest {

    /** 记录请求并可回放固定响应的假传输。 */
    private class RecordingTransport(private val response: CloudHttpResponse) : CloudHttpTransport {
        var method: String? = null
        var url: String? = null
        var headers: Map<String, String> = emptyMap()
        var body: String? = null
        var callCount: Int = 0

        override suspend fun request(
            method: String,
            url: String,
            headers: Map<String, String>,
            body: String?,
        ): CloudHttpResponse {
            this.method = method
            this.url = url
            this.headers = headers
            this.body = body
            callCount++
            return response
        }
    }

    private fun ok(body: String): CloudHttpResponse = CloudHttpResponse(200, body)

    /** 构造被测存储 + 假传输；token 缺省为 `"access-token"`。 */
    private fun storeWith(
        response: CloudHttpResponse,
        token: String? = "access-token",
    ): Pair<SupabaseCloudSnapshotStore, RecordingTransport> {
        val transport = RecordingTransport(response)
        return SupabaseCloudSnapshotStore(transport) { token } to transport
    }

    private fun sampleSnapshot(payloadJson: String = """{"schemaVersion":1}"""): CloudSnapshot =
        CloudSnapshot(
            userId = "user-1",
            payloadJson = payloadJson,
            updatedAt = Instant.parse("2026-10-04T12:34:56.789Z").toEpochMilli(),
            deviceTag = "local-device",
        )

    // ── pull：请求构造 ──────────────────────────────────────────────────────

    @Test
    fun `pull 构造 GET 请求且 Bearer 取自 provider`() = runBlocking {
        val (store, transport) = storeWith(ok("[]"))

        store.pull("user-1")

        assertEquals("GET", transport.method)
        assertTrue(
            "URL 应为 PostgREST 查询：${transport.url}",
            transport.url!!.endsWith(
                "/rest/v1/snapshots?user_id=eq.user-1&select=payload,updated_at&limit=1",
            ),
        )
        assertEquals("Bearer access-token", transport.headers["Authorization"])
        assertNull("GET 不应带请求体", transport.body)
    }

    // ── pull：响应分支 ──────────────────────────────────────────────────────

    @Test
    fun `pull 空数组返回 null`() = runBlocking {
        val (store, _) = storeWith(ok("[]"))

        assertNull(store.pull("user-1"))
    }

    @Test
    fun `pull 单行解析 jsonb 内联与毫秒 updated_at`() = runBlocking {
        val updatedAtText = "2026-10-04T12:34:56.789Z"
        val (store, _) = storeWith(
            ok("""[{"payload":{"schemaVersion":1,"backupJson":"{}"},"updated_at":"$updatedAtText"}]"""),
        )

        val snapshot = store.pull("user-1")

        assertNotNull(snapshot)
        assertEquals("user-1", snapshot!!.userId)
        // jsonb 在响应中内联为 JSON 值 → 序列化回字符串（紧凑、字段序保持）
        assertEquals("""{"schemaVersion":1,"backupJson":"{}"}""", snapshot.payloadJson)
        assertEquals(Instant.parse(updatedAtText).toEpochMilli(), snapshot.updatedAt) // 毫秒口径
        assertEquals(SNAPSHOT_SCHEMA_VERSION, snapshot.schemaVersion)
    }

    @Test
    fun `pull 解析微秒精度与非 UTC 偏移`() = runBlocking {
        // 20:34:56.789123+08:00 ≡ 12:34:56.789123Z（小数截断到毫秒）
        val (store, _) = storeWith(
            ok("""[{"payload":{"v":1},"updated_at":"2026-10-04T20:34:56.789123+08:00"}]"""),
        )

        val snapshot = store.pull("u")

        assertEquals(Instant.parse("2026-10-04T12:34:56.789Z").toEpochMilli(), snapshot!!.updatedAt)
    }

    @Test
    fun `pull 解析整秒 Z 后缀`() = runBlocking {
        val (store, _) = storeWith(ok("""[{"payload":{},"updated_at":"2026-10-04T12:34:56Z"}]"""))

        assertEquals(
            Instant.parse("2026-10-04T12:34:56Z").toEpochMilli(),
            store.pull("u")!!.updatedAt,
        )
    }

    @Test
    fun `pull 非 2xx 返回 null`() = runBlocking {
        val (store, _) = storeWith(CloudHttpResponse(500, "boom"))

        assertNull(store.pull("u"))
    }

    @Test
    fun `pull 响应非数组返回 null`() = runBlocking {
        val (store, _) = storeWith(ok("""{"unexpected":true}"""))

        assertNull(store.pull("u"))
    }

    @Test
    fun `pull 缺 payload 或 updated_at 返回 null`() = runBlocking {
        assertNull(storeWith(ok("""[{"payload":{"v":1}}]""")).first.pull("u"))
        assertNull(storeWith(ok("""[{"updated_at":"2026-10-04T12:34:56Z"}]""")).first.pull("u"))
    }

    // ── push：请求构造 ──────────────────────────────────────────────────────

    @Test
    fun `push 构造 POST 请求含 Prefer 头与三字段 body`() = runBlocking {
        val (store, transport) = storeWith(CloudHttpResponse(201, ""))

        val result = store.push(sampleSnapshot())

        assertTrue(result)
        assertEquals("POST", transport.method)
        assertTrue(transport.url!!.endsWith("/rest/v1/snapshots"))
        assertEquals("resolution=merge-duplicates,return=minimal", transport.headers["Prefer"])
        assertEquals("Bearer access-token", transport.headers["Authorization"])
        val bodyJson: JsonObject = Json.parseToJsonElement(transport.body!!).jsonObject
        assertEquals("user-1", bodyJson["user_id"]!!.jsonPrimitive.content)
        assertEquals("2026-10-04T12:34:56.789Z", bodyJson["updated_at"]!!.jsonPrimitive.content)
        assertEquals("""{"schemaVersion":1}""", bodyJson["payload"].toString()) // 载荷内联为 JSON 值
    }

    @Test
    fun `push 2xx 返回 true 非 2xx 返回 false`() = runBlocking {
        assertTrue(storeWith(CloudHttpResponse(201, "")).first.push(sampleSnapshot()))
        assertTrue(storeWith(CloudHttpResponse(200, "")).first.push(sampleSnapshot()))
        assertFalse(storeWith(CloudHttpResponse(409, "conflict")).first.push(sampleSnapshot()))
        assertFalse(storeWith(CloudHttpResponse(401, "unauthorized")).first.push(sampleSnapshot()))
    }

    @Test
    fun `push 非法 payloadJson 静默失败且不发请求`() = runBlocking {
        val (store, transport) = storeWith(CloudHttpResponse(201, ""))

        // `not-json` 被 kotlinx 宽松解析为裸字面量（非对象）；`{invalid` 直接抛解析异常——两者都应被拒
        assertFalse(store.push(sampleSnapshot(payloadJson = "not-json")))
        assertFalse(store.push(sampleSnapshot(payloadJson = "{invalid")))
        assertEquals(0, transport.callCount)
    }

    @Test
    fun `push 时间戳按毫秒口径生成 ISO8601`() = runBlocking {
        val (store, transport) = storeWith(CloudHttpResponse(201, ""))

        store.push(sampleSnapshot())

        val iso = Json.parseToJsonElement(transport.body!!).jsonObject["updated_at"]!!.jsonPrimitive.content
        assertEquals("2026-10-04T12:34:56.789Z", iso)
        assertEquals(Instant.parse(iso).toEpochMilli(), sampleSnapshot().updatedAt) // 互逆
    }

    // ── token 回退 ──────────────────────────────────────────────────────────

    @Test
    fun `accessToken 为 null 时 Authorization 回退到 publishable key`() = runBlocking {
        val (store, transport) = storeWith(ok("[]"), token = null)

        store.pull("u")

        assertEquals(SupabaseConfig.publishableKey, transport.headers["apikey"])
        assertEquals("Bearer ${SupabaseConfig.publishableKey}", transport.headers["Authorization"])
    }

    // ── ISO8601 辅助函数（直接单测口径） ────────────────────────────────────

    @Test
    fun `ISO8601 生成与解析互逆`() {
        val millis = Instant.parse("2026-10-04T12:34:56.789Z").toEpochMilli()
        assertEquals("2026-10-04T12:34:56.789Z", iso8601UtcFromEpochMillis(millis))
        assertEquals(millis, epochMillisFromIso8601("2026-10-04T12:34:56.789Z"))
    }

    @Test
    fun `ISO8601 解析拒绝畸形输入`() {
        assertNull(epochMillisFromIso8601("not-a-date"))
        assertNull(epochMillisFromIso8601("2026-13-40T99:99:99Z")) // 字段越界
        assertNull(epochMillisFromIso8601("2026-10-04T12:34:56.")) // 小数点为尾
    }
}

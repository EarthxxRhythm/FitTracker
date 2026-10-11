package com.fittracker.app.data.cloud

import androidx.datastore.preferences.core.PreferenceDataStoreFactory
import com.fittracker.app.data.auth.AuthSession
import com.fittracker.app.data.persist.JsonCodec
import com.fittracker.app.data.persist.JsonStore
import com.fittracker.app.data.persist.StoreNames
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.runBlocking
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import java.io.File
import java.util.concurrent.atomic.AtomicInteger

/**
 * [SupabaseAuthProvider] / [SupabaseSessionStore] 契约测试——全部响应手写 JSON 字符串，
 * 经 [FakeTransport] 回放，零网络。
 *
 * 覆盖：
 * - 登录成功映射 + 请求构造断言（URL / method / body / headers）；
 * - 密码错误（`invalid_credentials`）→ 中文文案；未识别错误 → 状态码文案；
 * - 注册待确认分支（无 `access_token`）/ 注册直通分支（含 `access_token`）/ 已注册文案；
 * - Refresh 路径（临近过期→刷新→token 更新；未临近过期不刷新）；
 * - refresh token 失效 → 清会话、`validAccessToken()` 返回 `null`；无会话返回 `null`；
 * - 登出清会话并携带 Bearer token；登出请求失败仍清本地；
 * - [SupabaseSessionStore] 落键往返与清除。
 *
 * 手段照 `AuthProviderTest` / `CloudSyncTest`：[PreferenceDataStoreFactory] 把每例存储指向独立临时
 * 文件；`@Config(sdk = [34])` 钉到 Robolectric 4.16 受支持 SDK（targetSdk 37 超出其范围）。
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class SupabaseAuthProviderTest {

    @get:Rule
    val tempFolder: TemporaryFolder = TemporaryFolder()

    private val counter = AtomicInteger()

    private fun createStore(): JsonStore {
        val file = File(tempFolder.root, "cloud_${counter.incrementAndGet()}.preferences_pb")
        val dataStore = PreferenceDataStoreFactory.create(
            scope = CoroutineScope(Dispatchers.IO + SupervisorJob()),
        ) { file }
        return JsonStore(dataStore)
    }

    private fun snapshot(): AuthSession = AuthSession(
        userId = "uuid-1",
        displayName = "小明",
        phone = "",
        email = "fan@example.com",
        providerId = SupabaseAuthProvider.PROVIDER_ID,
        signedInAt = 1_759_000_000_000,
    )

    private fun nowSeconds(): Long = System.currentTimeMillis() / 1000

    private fun requestBodyJson(request: RecordedRequest): JsonObject =
        JsonCodec.json.parseToJsonElement(request.body!!).jsonObject

    // ── 手机验证码（真短信 OTP） ─────────────────────────────────────────

    @Test
    fun `请求验证码_请求构造为E164并走otp端点`() = runBlocking {
        val transport = FakeTransport { CloudHttpResponse(200, "{}") }
        val provider = SupabaseAuthProvider(createStore(), transport)

        val result = provider.requestPhoneCode("13900000001")

        assertTrue(result.success)
        assertEquals("验证码已发送", result.message)
        assertEquals("", result.devCodeHint) // 生产路径不回显演示码
        val request = transport.last()
        assertEquals("POST", request.method)
        assertEquals(SupabaseEndpoints.auth("otp"), request.url)
        val body = requestBodyJson(request)
        assertEquals("+8613900000001", body["phone"]!!.jsonPrimitive.content)
    }

    @Test
    fun `验证码登录_verify端点与会话E164反解`() = runBlocking {
        val phoneTokenJson = """
            {"access_token":"at-otp","refresh_token":"rt-otp","expires_in":3600,
             "user":{"id":"uuid-otp","phone":"+8613900000001","user_metadata":{"nickname":"手机用户"}}}
        """.trimIndent()
        val transport = FakeTransport { CloudHttpResponse(200, phoneTokenJson) }
        val provider = SupabaseAuthProvider(createStore(), transport)

        val result = provider.signInWithPhoneCode("13900000001", "123456")

        assertTrue("应成功：${result.exceptionOrNull()?.message}", result.isSuccess)
        val session = result.getOrThrow()
        assertEquals("13900000001", session.phone) // E.164 反解为国内 11 位
        assertEquals("", session.email)
        assertEquals("手机用户", session.displayName)
        val request = transport.last()
        assertEquals(SupabaseEndpoints.auth("verify"), request.url)
        val body = requestBodyJson(request)
        assertEquals("+8613900000001", body["phone"]!!.jsonPrimitive.content)
        assertEquals("123456", body["token"]!!.jsonPrimitive.content)
        assertEquals("sms", body["type"]!!.jsonPrimitive.content)
    }

    @Test
    fun `验证码错误_映射为中文文案`() = runBlocking {
        val transport = FakeTransport {
            CloudHttpResponse(400, "{\"error_code\":\"otp_expired\",\"msg\":\"Token has expired or is invalid\"}")
        }
        val provider = SupabaseAuthProvider(createStore(), transport)

        val result = provider.signInWithPhoneCode("13900000001", "000000")

        assertTrue(result.isFailure)
        assertEquals("验证码错误或已过期", result.exceptionOrNull()?.message)
    }

    // ── 方案 B：账号规范化（手机号 ⇄ 内部邮箱） ──────────────────────────

    @Test
    fun `手机号注册_请求体映射为内部邮箱`() = runBlocking {
        val transport = FakeTransport { CloudHttpResponse(200, PASSWORD_OK_JSON) }
        val provider = SupabaseAuthProvider(createStore(), transport)

        val result = provider.signUp("13900000001", "abcd1234", "小明")

        assertTrue("注册应成功：${result.exceptionOrNull()?.message}", result.isSuccess)
        val body = requestBodyJson(transport.last())
        assertEquals("13900000001@$INTERNAL_EMAIL_DOMAIN", body["email"]!!.jsonPrimitive.content)
    }

    @Test
    fun `手机号登录_请求体映射为内部邮箱`() = runBlocking {
        val transport = FakeTransport { CloudHttpResponse(200, PASSWORD_OK_JSON) }
        val provider = SupabaseAuthProvider(createStore(), transport)

        provider.signIn("13900000001", "abcd1234")

        val body = requestBodyJson(transport.last())
        assertEquals("13900000001@$INTERNAL_EMAIL_DOMAIN", body["email"]!!.jsonPrimitive.content)
    }

    @Test
    fun `邮箱登录_原样透传不映射`() = runBlocking {
        val transport = FakeTransport { CloudHttpResponse(200, PASSWORD_OK_JSON) }
        val provider = SupabaseAuthProvider(createStore(), transport)

        provider.signIn("fan@example.com", "abcd1234")

        val body = requestBodyJson(transport.last())
        assertEquals("fan@example.com", body["email"]!!.jsonPrimitive.content)
    }

    @Test
    fun `内部邮箱会话_反解为手机号且不显示伪邮箱`() = runBlocking {
        val phoneTokenJson = """
            {"access_token":"at-phone","refresh_token":"rt-phone","expires_in":3600,
             "user":{"id":"uuid-phone","email":"13900000001@$INTERNAL_EMAIL_DOMAIN",
                     "user_metadata":{"nickname":"小明"}}}
        """.trimIndent()
        val transport = FakeTransport { CloudHttpResponse(200, phoneTokenJson) }
        val provider = SupabaseAuthProvider(createStore(), transport)

        val result = provider.signIn("13900000001", "abcd1234")

        assertTrue("登录应成功：${result.exceptionOrNull()?.message}", result.isSuccess)
        val session = result.getOrThrow()
        assertEquals("13900000001", session.phone)
        assertEquals("", session.email)
    }

    @Test
    fun `规范化工具函数_边界`() {
        assertEquals("13900000001@$INTERNAL_EMAIL_DOMAIN", normalizeAccount("13900000001"))
        assertEquals("fan@example.com", normalizeAccount("fan@example.com"))
        assertEquals("13900000001", phoneFromInternalEmail("13900000001@$INTERNAL_EMAIL_DOMAIN"))
        assertNull(phoneFromInternalEmail("fan@example.com"))
        assertEquals("+8613900000001", normalizePhoneE164("13900000001"))
        assertEquals("+8613900000001", normalizePhoneE164("+8613900000001")) // 已带 + 原样
        assertEquals("13900000001", phoneFromE164("+8613900000001"))
        assertEquals("+14155550100", phoneFromE164("+14155550100")) // 非 +86 原样
    }

    // ── 登录 ──────────────────────────────────────────────────────────────

    @Test
    fun `登录成功映射会话并构造请求`() = runBlocking {
        val transport = FakeTransport { CloudHttpResponse(200, PASSWORD_OK_JSON) }
        val provider = SupabaseAuthProvider(createStore(), transport)

        val result = provider.signIn("fan@example.com", "abcd1234")

        assertTrue("登录应成功：${result.exceptionOrNull()?.message}", result.isSuccess)
        val session = result.getOrThrow()
        assertEquals("uuid-1", session.userId)
        assertEquals("fan@example.com", session.email)
        assertEquals("小明", session.displayName)
        assertEquals("", session.phone)
        assertEquals("supabase", session.providerId)
        assertTrue(provider.isLoggedIn())
        assertEquals(session, provider.currentUser())

        val request = transport.last()
        assertEquals("POST", request.method)
        assertEquals(SupabaseEndpoints.auth("token?grant_type=password"), request.url)
        assertTrue(request.url.endsWith("/auth/v1/token?grant_type=password"))
        val body = requestBodyJson(request)
        assertEquals("fan@example.com", body["email"]!!.jsonPrimitive.content)
        assertEquals("abcd1234", body["password"]!!.jsonPrimitive.content)
        assertEquals(SupabaseConfig.publishableKey, request.headers["apikey"])
        assertEquals("Bearer ${SupabaseConfig.publishableKey}", request.headers["Authorization"])
        assertEquals("application/json", request.headers["Content-Type"])
    }

    @Test
    fun `密码错误映射为中文文案`() = runBlocking {
        val transport = FakeTransport { CloudHttpResponse(400, ERROR_INVALID_CREDENTIALS_JSON) }
        val provider = SupabaseAuthProvider(createStore(), transport)

        val result = provider.signIn("fan@example.com", "wrong")

        assertTrue(result.isFailure)
        assertEquals("邮箱或密码错误", result.exceptionOrNull()?.message)
        assertFalse("失败登录不应建立会话", provider.isLoggedIn())
        assertNull(provider.currentUser())
    }

    @Test
    fun `未识别错误回落到状态码文案`() = runBlocking {
        val transport = FakeTransport { CloudHttpResponse(500, "{\"msg\":\"Internal error\"}") }
        val provider = SupabaseAuthProvider(createStore(), transport)

        val result = provider.signIn("fan@example.com", "x")

        assertEquals("请求失败（状态码 500）", result.exceptionOrNull()?.message)
    }

    // ── 注册 ──────────────────────────────────────────────────────────────

    @Test
    fun `注册待确认分支返回中文提示`() = runBlocking {
        val transport = FakeTransport { CloudHttpResponse(200, SIGNUP_PENDING_JSON) }
        val provider = SupabaseAuthProvider(createStore(), transport)

        val result = provider.signUp("fan@example.com", "abcd1234", "小明")

        assertTrue(result.isFailure)
        assertEquals("确认邮件已发送——完成邮箱确认后再登录", result.exceptionOrNull()?.message)
        assertFalse("待确认态不应建立会话", provider.isLoggedIn())

        val request = transport.last()
        assertEquals(SupabaseEndpoints.auth("signup"), request.url)
        assertTrue(request.url.endsWith("/auth/v1/signup"))
        val body = requestBodyJson(request)
        assertEquals("fan@example.com", body["email"]!!.jsonPrimitive.content)
        assertEquals("abcd1234", body["password"]!!.jsonPrimitive.content)
        assertEquals("小明", body["data"]!!.jsonObject["nickname"]!!.jsonPrimitive.content)
    }

    @Test
    fun `注册直通分支落会话返回成功`() = runBlocking {
        val store = createStore()
        val transport = FakeTransport { CloudHttpResponse(200, SIGNUP_OK_JSON) }
        val provider = SupabaseAuthProvider(store, transport)

        val result = provider.signUp("fan@example.com", "abcd1234", "小明")

        assertTrue("直通注册应成功：${result.exceptionOrNull()?.message}", result.isSuccess)
        assertEquals("uuid-1", result.getOrThrow().userId)
        assertTrue(provider.isLoggedIn())
        // 已落库：独立 store 封装实例可读回
        assertEquals("at-signup", SupabaseSessionStore(store).load()?.accessToken)
    }

    @Test
    fun `注册已存在邮箱映射中文文案`() = runBlocking {
        val transport = FakeTransport { CloudHttpResponse(422, ERROR_USER_EXISTS_JSON) }
        val provider = SupabaseAuthProvider(createStore(), transport)

        val result = provider.signUp("fan@example.com", "abcd1234", "小明")

        assertEquals("该邮箱已注册", result.exceptionOrNull()?.message)
    }

    // ── Refresh ───────────────────────────────────────────────────────────

    @Test
    fun `临近过期触发刷新并更新 token`() = runBlocking {
        val store = createStore()
        SupabaseSessionStore(store).save(
            CloudSession(
                accessToken = "at-old",
                refreshToken = "rt-1",
                expiresAtEpochSeconds = nowSeconds() - 10,
                snapshot = snapshot(),
            ),
        )
        val transport = FakeTransport { CloudHttpResponse(200, REFRESH_OK_JSON) }
        val provider = SupabaseAuthProvider(store, transport)

        val token = provider.validAccessToken()

        assertEquals("at-new", token)
        val request = transport.last()
        assertEquals(SupabaseEndpoints.auth("token?grant_type=refresh_token"), request.url)
        assertTrue(request.url.endsWith("/auth/v1/token?grant_type=refresh_token"))
        assertEquals("rt-1", requestBodyJson(request)["refresh_token"]!!.jsonPrimitive.content)
        // 更新已落库
        assertEquals("at-new", SupabaseSessionStore(store).load()?.accessToken)
        // 距过期已 > 60s：再次调用不再发起请求
        provider.validAccessToken()
        assertEquals(1, transport.requests.size)
    }

    @Test
    fun `未临近过期直接返回现有 token`() = runBlocking {
        val store = createStore()
        SupabaseSessionStore(store).save(
            CloudSession("at-live", "rt-1", nowSeconds() + 3600, snapshot()),
        )
        val transport = FakeTransport { CloudHttpResponse(200, REFRESH_OK_JSON) }
        val provider = SupabaseAuthProvider(store, transport)

        assertEquals("at-live", provider.validAccessToken())
        assertTrue("未临近过期不应发起刷新", transport.requests.isEmpty())
    }

    @Test
    fun `refresh token 失效清会话返回 null`() = runBlocking {
        val store = createStore()
        SupabaseSessionStore(store).save(
            CloudSession("at-old", "bad", nowSeconds() - 10, snapshot()),
        )
        val transport = FakeTransport {
            CloudHttpResponse(401, "{\"error_code\":\"refresh_token_not_found\"}")
        }
        val provider = SupabaseAuthProvider(store, transport)

        val token = provider.validAccessToken()

        assertNull(token)
        assertNull("刷新失败应清本地会话", SupabaseSessionStore(store).load())
        assertFalse(provider.isLoggedIn())
    }

    @Test
    fun `刷新遇到服务端故障时保留会话不清`() = runBlocking {
        val store = createStore()
        SupabaseSessionStore(store).save(
            CloudSession("at-old", "rt-1", nowSeconds() - 10, snapshot()),
        )
        val transport = FakeTransport { CloudHttpResponse(503, "{\"message\":\"unavailable\"}") }
        val provider = SupabaseAuthProvider(store, transport)

        val token = provider.validAccessToken()

        assertNull(token)
        assertNotNull(
            "服务端暂时不可用不应清会话（2026-10-09 修「不会保持登陆」）",
            SupabaseSessionStore(store).load(),
        )
    }

    @Test
    fun `刷新遇到网络不可达时保留会话不清`() = runBlocking {
        val store = createStore()
        SupabaseSessionStore(store).save(
            CloudSession("at-old", "rt-1", nowSeconds() - 10, snapshot()),
        )
        val transport = FakeTransport { throw java.io.IOException("network unreachable") }
        val provider = SupabaseAuthProvider(store, transport)

        val token = provider.validAccessToken()

        assertNull(token)
        assertNotNull(
            "网络不可达不应清会话（2026-10-09 修「不会保持登陆」）",
            SupabaseSessionStore(store).load(),
        )
    }

    @Test
    fun `本地会话存在时 hasPersistedSession 为真且不触网`() = runBlocking {
        val store = createStore()
        SupabaseSessionStore(store).save(
            CloudSession("at-x", "rt-x", nowSeconds() + 60, snapshot()),
        )
        val transport = FakeTransport { error("hasPersistedSession 不应发起网络请求") }
        val provider = SupabaseAuthProvider(store, transport)

        assertTrue(provider.hasPersistedSession())
        assertTrue("不应触网", transport.requests.isEmpty())
    }

    @Test
    fun `无会话 validAccessToken 返回 null`() = runBlocking {
        val transport = FakeTransport { CloudHttpResponse(200, PASSWORD_OK_JSON) }
        val provider = SupabaseAuthProvider(createStore(), transport)

        assertNull(provider.validAccessToken())
        assertTrue("无会话不应发起请求", transport.requests.isEmpty())
    }

    // ── 登出 ──────────────────────────────────────────────────────────────

    @Test
    fun `登出清会话并携带 Bearer token`() = runBlocking {
        val store = createStore()
        val transport = FakeTransport { request ->
            if (request.url.contains("grant_type=password")) {
                CloudHttpResponse(200, PASSWORD_OK_JSON)
            } else {
                CloudHttpResponse(204, "")
            }
        }
        val provider = SupabaseAuthProvider(store, transport)
        provider.signIn("fan@example.com", "abcd1234")

        provider.signOut()

        assertFalse(provider.isLoggedIn())
        assertNull(provider.currentUser())
        assertNull(SupabaseSessionStore(store).load())
        val logout = transport.last()
        assertEquals(SupabaseEndpoints.auth("logout"), logout.url)
        assertEquals("Bearer at-1", logout.headers["Authorization"])
    }

    @Test
    fun `登出请求失败仍清本地会话`() = runBlocking {
        val store = createStore()
        val transport = FakeTransport { request ->
            if (request.url.contains("grant_type=password")) {
                CloudHttpResponse(200, PASSWORD_OK_JSON)
            } else {
                throw RuntimeException("network down")
            }
        }
        val provider = SupabaseAuthProvider(store, transport)
        provider.signIn("fan@example.com", "abcd1234")

        provider.signOut()

        assertFalse(provider.isLoggedIn())
        assertNull(SupabaseSessionStore(store).load())
    }

    // ── 会话存储 ──────────────────────────────────────────────────────────

    @Test
    fun `会话存储往返与清除`() = runBlocking {
        val store = createStore()
        val sessionStore = SupabaseSessionStore(store)
        val session = CloudSession("at", "rt", 123L, snapshot())

        assertNull(sessionStore.load())
        sessionStore.save(session)
        assertEquals(session, sessionStore.load())
        // 落键为 CLOUD_SESSION
        assertNotNull(store.readString(StoreNames.CLOUD_SESSION))
        sessionStore.clear()
        assertNull(sessionStore.load())
    }

    // ── 基建 ──────────────────────────────────────────────────────────────

    private data class RecordedRequest(
        val method: String,
        val url: String,
        val headers: Map<String, String>,
        val body: String?,
    )

    private class FakeTransport(
        private val responder: (RecordedRequest) -> CloudHttpResponse,
    ) : CloudHttpTransport {

        val requests: MutableList<RecordedRequest> = mutableListOf()

        override suspend fun request(
            method: String,
            url: String,
            headers: Map<String, String>,
            body: String?,
        ): CloudHttpResponse {
            val request = RecordedRequest(method, url, headers, body)
            requests += request
            return responder(request)
        }

        fun last(): RecordedRequest = requests.last()
    }

    companion object {
        private const val PASSWORD_OK_JSON =
            "{\"access_token\":\"at-1\",\"token_type\":\"bearer\",\"expires_in\":3600," +
                "\"refresh_token\":\"rt-1\",\"user\":{\"id\":\"uuid-1\",\"email\":\"fan@example.com\"," +
                "\"user_metadata\":{\"nickname\":\"小明\"}}}"

        private const val REFRESH_OK_JSON =
            "{\"access_token\":\"at-new\",\"token_type\":\"bearer\",\"expires_in\":3600," +
                "\"refresh_token\":\"rt-2\",\"user\":{\"id\":\"uuid-1\",\"email\":\"fan@example.com\"," +
                "\"user_metadata\":{\"nickname\":\"小明\"}}}"

        private const val SIGNUP_OK_JSON =
            "{\"access_token\":\"at-signup\",\"expires_in\":3600,\"refresh_token\":\"rt-signup\"," +
                "\"user\":{\"id\":\"uuid-1\",\"email\":\"fan@example.com\"," +
                "\"user_metadata\":{\"nickname\":\"小明\"}}}"

        private const val SIGNUP_PENDING_JSON =
            "{\"id\":\"uuid-2\",\"email\":\"fan@example.com\"," +
                "\"user_metadata\":{\"nickname\":\"小明\"}," +
                "\"confirmation_sent_at\":\"2026-10-04T00:00:00Z\"}"

        private const val ERROR_INVALID_CREDENTIALS_JSON =
            "{\"code\":400,\"error_code\":\"invalid_credentials\",\"msg\":\"Invalid login credentials\"}"

        private const val ERROR_USER_EXISTS_JSON =
            "{\"code\":422,\"error_code\":\"user_already_exists\",\"msg\":\"User already registered\"}"
    }
}

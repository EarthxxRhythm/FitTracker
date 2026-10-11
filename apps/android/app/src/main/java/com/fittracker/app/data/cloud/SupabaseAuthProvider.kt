package com.fittracker.app.data.cloud

import com.fittracker.app.data.auth.AuthException
import com.fittracker.app.data.auth.AuthProvider
import com.fittracker.app.data.auth.AuthSession
import com.fittracker.app.data.auth.VerifyCodeResult
import com.fittracker.app.data.persist.JsonCodec
import com.fittracker.app.data.persist.JsonStore
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.decodeFromString
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put

/**
 * Supabase（GoTrue）认证提供方——邮箱 + 密码链路。
 *
 * 覆盖 `AuthProvider` 抽象，把 GoTrue 的 REST 端点（`/auth/v1/...`）映射为项目认证域语义：
 * 注册 / 登录 / 登出 / 会话查询，并额外提供 [refreshIfNeeded] / [validAccessToken] 供
 * 快照 store 在读写 PostgREST 前取用最新 access token。
 *
 * 端点映射（URL 由 [SupabaseEndpoints.auth] 拼接，见本文件「端点表」注释）：
 *
 * | 方法 | 端点 | body | 成功响应关键字段 |
 * |---|---|---|---|
 * | [signUp] | `POST {auth}/signup` | `{"email","password","data":{"nickname"}}` | 含 `access_token` 即直通，否则待确认 |
 * | [signIn] | `POST {auth}/token?grant_type=password` | `{"email","password"}` | `access_token` / `refresh_token` / `expires_in` / `user` |
 * | [refreshIfNeeded] | `POST {auth}/token?grant_type=refresh_token` | `{"refresh_token"}` | 同上 |
 * | [signOut] | `POST {auth}/logout` | 无（Bearer = access token） | — |
 *
 * 持久化：会话整块 JSON 经 [SupabaseSessionStore] 存于 [com.fittracker.app.data.persist.StoreNames.CLOUD_SESSION]；
 * 内存镜像 [cached] 承载 [isLoggedIn] / [currentUser]（接口为同步方法，只能读内存）。
 *
 * 与项目其它 Provider 的差异：
 * - 传输层经 [CloudHttpTransport] **构造注入**（默认 [UrlConnectionTransport]）——单测注入 fake，零网络。
 * - [isAvailable] 反映云端配置是否就绪（[SupabaseConfig.isConfigured]），而非沙盒的恒 `true`。
 */
class SupabaseAuthProvider(
    store: JsonStore,
    private val transport: CloudHttpTransport = UrlConnectionTransport,
) : AuthProvider {

    /** 会话持久化封装（键 [com.fittracker.app.data.persist.StoreNames.CLOUD_SESSION]）。 */
    private val sessionStore: SupabaseSessionStore = SupabaseSessionStore(store)

    /** 内存镜像会话（对齐源 Provider 的 `currentSession`）。 */
    private var cached: CloudSession? = null

    /** 是否已尝试从存储加载（懒加载一次，避免重复 IO）。 */
    private var loaded: Boolean = false

    /** 提供方标识（快照 `providerId` 落此值）。 */
    override val providerId: String = PROVIDER_ID

    /** 云端配置就绪才可用（未配置时调用方应回落到沙盒）。 */
    override fun isAvailable(): Boolean = SupabaseConfig.isConfigured

    // --- 注册 --------------------------------------------------------------

    /**
     * 邮箱注册。本项目当前 `mailer_autoconfirm=false`（邮箱确认开启），`/signup` 对确认态
     * 返回用户对象而**无 `access_token`**——此分支不建立会话，返回失败 + 中文提示。
     * 若响应含 `access_token`（确认关闭 / 直通）→ 落会话并返回成功。
     */
    override suspend fun signUp(email: String, password: String, nickname: String): Result<AuthSession> {
        val body: String = buildJsonObject {
            put("email", normalizeAccount(email)) // 手机号 → 内部邮箱（方案 B）
            put("password", password)
            put("data", buildJsonObject { put("nickname", nickname) })
        }.toString()
        val response: CloudHttpResponse = transport.request(
            method = METHOD_POST,
            url = SupabaseEndpoints.auth(PATH_SIGNUP),
            headers = SupabaseEndpoints.headers(),
            body = body,
        )
        if (response.status !in HTTP_SUCCESS_RANGE) {
            return failure(mapError(response))
        }
        val root: JsonObject? = parseObject(response.body)
        if (root == null || !root.containsKey(FIELD_ACCESS_TOKEN)) {
            // 待确认态：响应无 access_token——不建会话
            return failure(AuthException(CONFIRMATION_REQUIRED_MESSAGE))
        }
        val token: GoTrueTokenResponse = parseTokenResponse(response.body)
            ?: return failure(AuthException(requestFailedMessage(response.status)))
        val session: CloudSession = token.toCloudSession()
        applySession(session)
        return Result.success(session.snapshot)
    }

    // --- 登录 --------------------------------------------------------------

    /** 邮箱 + 密码登录；成功落会话（含 refresh token 与过期时刻）并返回用户快照。 */
    override suspend fun signIn(account: String, password: String): Result<AuthSession> {
        val body: String = buildJsonObject {
            put("email", normalizeAccount(account)) // 手机号 → 内部邮箱；邮箱原样透传（方案 B）
            put("password", password)
        }.toString()
        val response: CloudHttpResponse = transport.request(
            method = METHOD_POST,
            url = SupabaseEndpoints.auth(PATH_TOKEN_PASSWORD),
            headers = SupabaseEndpoints.headers(),
            body = body,
        )
        if (response.status !in HTTP_SUCCESS_RANGE) {
            return failure(mapError(response))
        }
        val token: GoTrueTokenResponse = parseTokenResponse(response.body)
            ?: return failure(AuthException(requestFailedMessage(response.status)))
        val session: CloudSession = token.toCloudSession()
        applySession(session)
        return Result.success(session.snapshot)
    }

    // --- 手机验证码（真短信：GoTrue OTP + 项目配置的 SMS provider） ----------

    /**
     * 请求手机验证码：`POST /auth/v1/otp`（`{"phone": E.164}`）——GoTrue 经项目配置的
     * SMS provider 发送**真短信**。未配置 SMS provider 的项目会返回 4xx（如 `sms_send_failed`），
     * 文案经 [mapError] 透出（中文兜底为 `请求失败（状态码 N）`）。
     */
    override suspend fun requestPhoneCode(phone: String): VerifyCodeResult {
        val body: String = buildJsonObject {
            put("phone", normalizePhoneE164(phone))
        }.toString()
        val response: CloudHttpResponse = transport.request(
            method = METHOD_POST,
            url = SupabaseEndpoints.auth(PATH_OTP),
            headers = SupabaseEndpoints.headers(),
            body = body,
        )
        if (response.status !in HTTP_SUCCESS_RANGE) {
            return VerifyCodeResult(success = false, message = mapError(response).message.orEmpty(), devCodeHint = "")
        }
        return VerifyCodeResult(success = true, message = "验证码已发送", devCodeHint = "")
    }

    /**
     * 手机验证码登录/注册：`POST /auth/v1/verify`（`{"phone", "token", "type": "sms"}`）→
     * token 响应 → 会话落盘。手机号未注册时 GoTrue 自动建号（等价源沙盒「快速注册」语义）。
     */
    override suspend fun signInWithPhoneCode(phone: String, code: String): Result<AuthSession> {
        val body: String = buildJsonObject {
            put("phone", normalizePhoneE164(phone))
            put("token", code.trim())
            put("type", "sms")
        }.toString()
        val response: CloudHttpResponse = transport.request(
            method = METHOD_POST,
            url = SupabaseEndpoints.auth(PATH_VERIFY),
            headers = SupabaseEndpoints.headers(),
            body = body,
        )
        if (response.status !in HTTP_SUCCESS_RANGE) {
            return failure(mapError(response))
        }
        val token: GoTrueTokenResponse = parseTokenResponse(response.body)
            ?: return failure(AuthException(requestFailedMessage(response.status)))
        val session: CloudSession = token.toCloudSession()
        applySession(session)
        return Result.success(session.snapshot)
    }

    // --- 登出 --------------------------------------------------------------

    /**
     * 登出：以当前 access token 为 Bearer 调 `/logout`（**失败忽略**——本地清理不因网络受制），
     * 随后清空内存镜像与持久化会话。
     */
    override suspend fun signOut() {
        val accessToken: String? = ensureLoaded()?.accessToken
        if (accessToken != null) {
            try {
                transport.request(
                    method = METHOD_POST,
                    url = SupabaseEndpoints.auth(PATH_LOGOUT),
                    headers = SupabaseEndpoints.headers(accessToken),
                    body = null,
                )
            } catch (error: Exception) {
                // 登出请求失败忽略——本地清理照常进行
            }
        }
        cached = null
        loaded = true
        sessionStore.clear()
    }

    /** 是否已登录 = 内存镜像会话非空。 */
    override fun isLoggedIn(): Boolean = cached != null

    /** 当前会话快照（内存镜像；未加载时 `null`——需先经认证 / [refreshIfNeeded] 触发加载）。 */
    override fun currentUser(): AuthSession? = cached?.snapshot

    /** 清空内存态（下次访问重新从存储加载）。 */
    override fun clearAllData() {
        cached = null
        loaded = false
    }

    /** 清空内存态 + 删除持久化会话。 */
    override suspend fun clearPersisted() {
        cached = null
        loaded = false
        sessionStore.clear()
    }

    // --- 供快照 store 调用：有效 access token ------------------------------

    /**
     * 临近过期（剩余 < [REFRESH_WINDOW_SECONDS] 秒）时用 refresh token 换取新 token 并更新会话；
     * 未临近过期 / 无会话则空操作。刷新失败（如 refresh token 失效）→ 清除会话（token 已不可用）。
     */
    suspend fun refreshIfNeeded() {
        val session: CloudSession = ensureLoaded() ?: return
        val nowSeconds: Long = currentSeconds()
        if (session.expiresAtEpochSeconds - nowSeconds >= REFRESH_WINDOW_SECONDS) {
            return
        }
        val body: String = buildJsonObject {
            put("refresh_token", session.refreshToken)
        }.toString()
        val response: CloudHttpResponse = try {
            transport.request(
                method = METHOD_POST,
                url = SupabaseEndpoints.auth(PATH_TOKEN_REFRESH),
                headers = SupabaseEndpoints.headers(),
                body = body,
            )
        } catch (error: Exception) {
            // 网络不可达（离线 / DNS / 超时）：**保留会话**，等下次有机会再刷新——
            // 不能因网络波动清会话（2026-10-09 反馈「不会保持登陆」）
            return
        }
        val token: GoTrueTokenResponse? =
            if (response.status in HTTP_SUCCESS_RANGE) parseTokenResponse(response.body) else null
        if (token == null) {
            // 刷新失败要区分两类（2026-10-09 反馈「不会保持登陆」）：
            // - 凭证被服务端明确拒绝（4xx：refresh token 失效）→ 清会话（token 确实不可用）
            // - 服务端暂时不可用（5xx 等）→ **保留会话**，下次再刷
            if (response.status in 400..499) {
                cached = null
                loaded = true
                sessionStore.clear()
            }
            return
        }
        applySession(
            session.copy(
                accessToken = token.accessToken.ifEmpty { session.accessToken },
                refreshToken = token.refreshToken.ifEmpty { session.refreshToken },
                expiresAtEpochSeconds = nowSeconds + token.expiresIn,
            ),
        )
    }

    /**
     * [refreshIfNeeded] 后返回**当前有效** access token；无会话 / 无法获得有效 token 时为 `null`。
     *
     * 注意与「会话是否保留」的区别（2026-10-09 修「不会保持登陆」）：刷新因网络/服务端故障
     * 失败时会话**保留**（见 [refreshIfNeeded]），但过期 token 不算「有效」→ 此处返回 `null`；
     * 登录保持判定请用 [hasPersistedSession]。
     */
    suspend fun validAccessToken(): String? {
        refreshIfNeeded()
        val session: CloudSession = cached ?: return null
        return if (session.expiresAtEpochSeconds - currentSeconds() >= REFRESH_WINDOW_SECONDS) {
            session.accessToken
        } else {
            null
        }
    }

    /**
     * 本地是否存在持久化会话（**不触网**、不判 token 新鲜度）。
     *
     * 启动分流用：登录保持以「本地有会话」为准；token 续期交给实际网络请求路径（[validAccessToken]）。
     * 2026-10-09 修复「不会保持登陆」：原启动判定走 [validAccessToken]，
     * 网络波动/离线时刷新失败即被判未登录（并清会话）。
     */
    suspend fun hasPersistedSession(): Boolean = ensureLoaded() != null

    // --- 内部 --------------------------------------------------------------

    /** 首次访问时从存储加载会话到内存镜像。 */
    private suspend fun ensureLoaded(): CloudSession? {
        if (!loaded) {
            cached = sessionStore.load()
            loaded = true
        }
        return cached
    }

    /** 更新内存镜像并落库。 */
    private suspend fun applySession(session: CloudSession) {
        cached = session
        loaded = true
        sessionStore.save(session)
    }

    private fun parseObject(body: String): JsonObject? = try {
        JsonCodec.json.parseToJsonElement(body) as? JsonObject
    } catch (error: Exception) {
        null
    }

    /** 解析 GoTrue token 响应；缺 `access_token` 一律 `null`。 */
    private fun parseTokenResponse(body: String): GoTrueTokenResponse? = try {
        val parsed: GoTrueTokenResponse = JsonCodec.json.decodeFromString(body)
        if (parsed.accessToken.isEmpty()) null else parsed
    } catch (error: Exception) {
        null
    }

    /** GoTrue token 响应 → [CloudSession]（映射见 `AuthProvider` 域语义）。 */
    private fun GoTrueTokenResponse.toCloudSession(): CloudSession {
        val user: GoTrueUser? = this.user
        // 内部邮箱反解（方案 B）：`{phone}@phone.fittracker.app` → phone 字段承载手机号，
        // 避免 UI（账号与同步屏 accountText）显示伪邮箱。
        // 真短信（OTP）路径：user.phone 为 E.164（`+86…`）→ 反解为国内 11 位。
        val rawEmail: String = user?.email.orEmpty()
        val rawPhone: String = user?.phone.orEmpty()
        val phone: String = if (rawPhone.isNotEmpty()) {
            phoneFromE164(rawPhone)
        } else {
            phoneFromInternalEmail(rawEmail).orEmpty()
        }
        val snapshot: AuthSession = AuthSession(
            userId = user?.id.orEmpty(),
            displayName = resolveDisplayName(user),
            phone = phone,
            email = if (phone.isEmpty()) rawEmail else "",
            providerId = PROVIDER_ID,
            signedInAt = System.currentTimeMillis(),
        )
        return CloudSession(
            accessToken = accessToken,
            refreshToken = refreshToken,
            expiresAtEpochSeconds = currentSeconds() + expiresIn,
            snapshot = snapshot,
        )
    }

    /**
     * 显示名解析：`user.user_metadata.nickname` 优先；为空时回落邮箱 `@` 前缀
     * （对齐 `SandboxAuthProvider.resolveDisplayName` 的兜底思路，避免空显示名）。
     */
    private fun resolveDisplayName(user: GoTrueUser?): String {
        val nickname: String = user?.userMetadata?.nickname.orEmpty()
        if (nickname.isNotEmpty()) {
            return nickname
        }
        val email: String = user?.email.orEmpty()
        val atIndex: Int = email.indexOf('@')
        if (atIndex > 0) {
            return email.substring(0, atIndex)
        }
        return ""
    }

    /** 4xx 错误 → [AuthException]（中文文案，见 `ERROR_CODE_*` 映射）。 */
    private fun mapError(response: CloudHttpResponse): AuthException {
        val message: String = when (extractErrorCode(response.body)) {
            ERROR_CODE_INVALID_CREDENTIALS -> INVALID_CREDENTIALS_MESSAGE
            ERROR_CODE_USER_ALREADY_EXISTS -> USER_ALREADY_EXISTS_MESSAGE
            ERROR_CODE_EMAIL_PROVIDER_DISABLED -> EMAIL_PROVIDER_DISABLED_MESSAGE
            ERROR_CODE_WEAK_PASSWORD -> WEAK_PASSWORD_MESSAGE
            ERROR_CODE_OTP_EXPIRED -> OTP_EXPIRED_MESSAGE
            else -> requestFailedMessage(response.status)
        }
        return AuthException(message)
    }

    /** 从错误体按 `error_code` → `code` → `msg` 顺序取首个非空标量值。 */
    private fun extractErrorCode(body: String): String? {
        val root: JsonObject = parseObject(body) ?: return null
        for (key in ERROR_CODE_KEYS) {
            val element: JsonPrimitive = root[key] as? JsonPrimitive ?: continue
            val content: String = element.content
            if (content.isNotEmpty() && content != "null") {
                return content
            }
        }
        return null
    }

    private fun requestFailedMessage(status: Int): String = "请求失败（状态码 $status）"

    private fun currentSeconds(): Long = System.currentTimeMillis() / 1000

    private fun failure(error: AuthException): Result<AuthSession> = Result.failure(error)

    companion object {
        /** 提供方标识——写入快照 `providerId`。 */
        const val PROVIDER_ID: String = "supabase"

        /** 刷新窗口（秒）：剩余有效期小于此值即触发 Refresh。 */
        const val REFRESH_WINDOW_SECONDS: Long = 60

        /** 注册待确认态文案（`mailer_autoconfirm=false`，响应无 access_token）。 */
        const val CONFIRMATION_REQUIRED_MESSAGE: String = "确认邮件已发送——完成邮箱确认后再登录"

        private const val INVALID_CREDENTIALS_MESSAGE: String = "邮箱或密码错误"
        private const val USER_ALREADY_EXISTS_MESSAGE: String = "该邮箱已注册"
        private const val EMAIL_PROVIDER_DISABLED_MESSAGE: String =
            "邮箱注册服务未开启（请在 Supabase 控制台启用 Email 提供方）"
        private const val WEAK_PASSWORD_MESSAGE: String = "密码强度不足（至少 6 位）"
        private const val OTP_EXPIRED_MESSAGE: String = "验证码错误或已过期"

        private const val ERROR_CODE_INVALID_CREDENTIALS: String = "invalid_credentials"
        private const val ERROR_CODE_USER_ALREADY_EXISTS: String = "user_already_exists"
        private const val ERROR_CODE_EMAIL_PROVIDER_DISABLED: String = "email_provider_disabled"
        private const val ERROR_CODE_WEAK_PASSWORD: String = "weak_password"
        private const val ERROR_CODE_OTP_EXPIRED: String = "otp_expired"

        private val ERROR_CODE_KEYS: List<String> = listOf("error_code", "code", "msg")

        private const val METHOD_POST: String = "POST"
        private const val PATH_SIGNUP: String = "signup"
        private const val PATH_TOKEN_PASSWORD: String = "token?grant_type=password"
        private const val PATH_TOKEN_REFRESH: String = "token?grant_type=refresh_token"
        private const val PATH_OTP: String = "otp"
        private const val PATH_VERIFY: String = "verify"
        private const val PATH_LOGOUT: String = "logout"
        private const val FIELD_ACCESS_TOKEN: String = "access_token"

        private val HTTP_SUCCESS_RANGE: IntRange = 200..299
    }
}

/** GoTrue `/token`（password / refresh_token）响应——仅取本侧所需字段，其余由 `ignoreUnknownKeys` 忽略。 */
@Serializable
private data class GoTrueTokenResponse(
    @SerialName("access_token") val accessToken: String = "",
    @SerialName("refresh_token") val refreshToken: String = "",
    @SerialName("expires_in") val expiresIn: Long = 0,
    val user: GoTrueUser? = null,
)

/** GoTrue 用户对象（token 响应内 `user`，或 `/signup` 待确认态的顶层对象）。 */
@Serializable
private data class GoTrueUser(
    val id: String = "",
    val email: String = "",
    val phone: String = "",
    @SerialName("user_metadata") val userMetadata: GoTrueUserMetadata? = null,
)

/** GoTrue `user.user_metadata`——昵称用于显示名。 */
@Serializable
private data class GoTrueUserMetadata(
    val nickname: String = "",
)

/**
 * 内部邮箱域（方案 B）：手机号账号映射为 `{phone}@phone.fittracker.app` 提交给 GoTrue。
 *
 * 动机：本项目注册/登录 UI 以**中国大陆手机号**为账号标识（对齐原型），而 Supabase 托管
 * 认证为邮箱制；GoTrue 的邮箱校验只做格式匹配（不查 MX/域名真实性），故该域可通过。
 * 反解见 [phoneFromInternalEmail]。调研依据见「登录验证调研」结论（方案 B）。
 */
internal const val INTERNAL_EMAIL_DOMAIN: String = "phone.fittracker.app"

/** 账号规范化：手机号 → 内部邮箱；已含 `@` 的邮箱原样透传（登录屏支持「手机号或邮箱」）。 */
internal fun normalizeAccount(account: String): String =
    if (account.contains('@')) account else "$account@$INTERNAL_EMAIL_DOMAIN"

/** 内部邮箱 → 手机号；非内部域返回 `null`（真实邮箱账号保持不变）。 */
internal fun phoneFromInternalEmail(email: String): String? =
    if (email.endsWith("@$INTERNAL_EMAIL_DOMAIN")) email.removeSuffix("@$INTERNAL_EMAIL_DOMAIN") else null

/** 中国大陆 11 位手机号 → E.164（`+86` 前缀）；已带 `+` 的原样透传（真短信 OTP 路径）。 */
internal fun normalizePhoneE164(phone: String): String {
    val trimmed: String = phone.trim()
    return if (trimmed.startsWith("+")) trimmed else "+86$trimmed"
}

/** E.164 → 国内 11 位手机号（去 `+86` 前缀）；非 +86 号码原样返回。 */
internal fun phoneFromE164(e164: String): String = e164.removePrefix("+86")

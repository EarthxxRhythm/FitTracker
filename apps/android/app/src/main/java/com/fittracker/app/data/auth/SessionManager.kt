package com.fittracker.app.data.auth

import android.util.Base64
import com.fittracker.app.data.persist.JsonCodec
import com.fittracker.app.data.persist.JsonStore
import com.fittracker.app.data.persist.StoreNames
import kotlinx.serialization.Serializable
import kotlinx.serialization.decodeFromString
import kotlinx.serialization.encodeToString
import kotlin.random.Random

/**
 * 会话管理（Token 持久化）——逐方法移植自鸿蒙 `entry/src/main/ets/common/services/SessionManager.ets`。
 *
 * 职责（源 `SessionManager.ets:1` 文件头）：JWT Token 的生成、本地存储、有效性校验与清除，
 * 以及会话快照的持久化——供启动分流（`isLoggedIn`）与 UI 展示。
 *
 * 持久化模型（与源的映射）：
 * - 鸿蒙侧：`preferences.getPreferences(context, 'fit_tracker_session')` 打开
 *   `fit_tracker_session` 库（源 L11 `STORE_NAME`），库内**两个子键**——`'auth_token'`
 *   （源 L12 `TOKEN_KEY`）与 `'session_snapshot'`（源 L13 `SNAPSHOT_KEY`）。
 * - 安卓侧（Wave 2 折叠模型）：所有鸿蒙 preferences 库折叠进**同一个** DataStore，库名退化
 *   为**键名**；库内多子键折叠为**单键整块 JSON**（同 `UserProfileService` 的折叠手法）。
 *   因此 token 与快照合并为 [SessionBundle]，整块存于键 [StoreNames.SESSION]。
 *
 * 过期语义（源 L14 `TOKEN_EXPIRY_DAYS = 7`）：Token 载荷 `exp` = 签发时刻 + 7 天
 * （源 L56 `now + TOKEN_EXPIRY_DAYS * 24 * 60 * 60`，单位秒）。本侧 [isLoggedIn] 叠加该
 * 过期判定——**这是对源的增强**：源 `isLoggedIn`（L177）为乐观判定（仅查快照存在 + `userId`
 * 非空），未调用 `validateToken` 校验 `exp`；安卓侧为使「过期会话失效」语义可用，[isLoggedIn]
 * 同时要求 token 未过期。
 *
 * 与源的差异：源为单例 `export default new SessionManager()` 且首参 `context: Context`；
 * 安卓侧改为 [JsonStore] **构造注入**、可实例化——便于单测每例新建、避免跨用例状态串场。
 * `now`（秒）参数为安卓侧可测性加入（源内联 `Date.now()`），默认取当前时刻。
 */
class SessionManager(private val store: JsonStore) {

    /**
     * 最近一次持久化错误码（源 `SessionManager.ets` 的 `lastPersistenceError`；
     * 取值 `save_token_failed` / `load_token_failed` / `clear_token_failed` /
     * `save_session_failed` / `load_session_failed` / `clear_session_failed` / `check_login_failed`）。
     *
     * 私有——对外经 [getLastPersistenceError] 读取（对齐源方法名；同 `UserProfileService` 手法，
     * 且避免 Kotlin 属性 getter 与同名方法产生 JVM 签名冲突）。
     */
    private var lastPersistenceError: String = ""

    /** 源 `SessionManager.ets:94` `getLastPersistenceError`。 */
    fun getLastPersistenceError(): String = lastPersistenceError

    // --- 源 L50-L92：Token 生成 / 校验（纯逻辑，无 IO） ----------------------

    /**
     * 源 `SessionManager.ets:50` `generateToken`：构造形如 `header.body.signature` 的三段串
     * （载荷 `{userId, iat, exp}`，`exp = now + 7 天`）。签名段为演示用假值 `'mock_signature_'`。
     *
     * @param nowSeconds 签发时刻（秒）——源内联 `Math.floor(Date.now()/1000)`；本侧可注入以便测试过期。
     */
    fun generateToken(phone: String, nowSeconds: Long = currentSeconds()): String {
        val entropy: String = System.currentTimeMillis().toString() + "_" + Random.nextInt(Int.MAX_VALUE).toString(36)
        val payload: TokenPayload = TokenPayload(
            userId = phone,
            iat = nowSeconds,
            exp = nowSeconds + TOKEN_EXPIRY_DAYS * 24L * 60 * 60,
        )
        val header: String = base64Encode("""{"alg":"HS256","typ":"JWT"}""")
        val body: String = base64Encode(JsonCodec.json.encodeToString(payload))
        val signature: String = base64Encode("mock_signature_$entropy")
        return "$header.$body.$signature"
    }

    /**
     * 源 `SessionManager.ets:65` `validateToken`：解出载荷第二段并判 `exp > now`；
     * 段数不足、Base64/JSON 解析失败一律 `false`（对齐源 catch 返回 `false`）。
     */
    fun validateToken(token: String, nowSeconds: Long = currentSeconds()): Boolean = try {
        val parts: List<String> = token.split(".")
        if (parts.size < 2) {
            false
        } else {
            val payload: TokenPayload = JsonCodec.json.decodeFromString(base64Decode(parts[1]))
            payload.exp > nowSeconds
        }
    } catch (error: Exception) {
        false
    }

    /** 源 `SessionManager.ets:80` `getUserIdFromToken`——解析失败回落空串。 */
    fun getUserIdFromToken(token: String): String = try {
        val parts: List<String> = token.split(".")
        if (parts.size < 2) {
            ""
        } else {
            JsonCodec.json.decodeFromString<TokenPayload>(base64Decode(parts[1])).userId
        }
    } catch (error: Exception) {
        ""
    }

    // --- 源 L98-L129：Token 存取 --------------------------------------------

    /** 源 `SessionManager.ets:98` `saveToken`——失败置 `save_token_failed`。 */
    suspend fun saveToken(token: String) {
        lastPersistenceError = ""
        try {
            writeBundle(readBundle().copy(token = token))
        } catch (error: Exception) {
            lastPersistenceError = "save_token_failed"
        }
    }

    /** 源 `SessionManager.ets:109` `getToken`——空串回落 `null`；失败置 `load_token_failed`。 */
    suspend fun getToken(): String? {
        lastPersistenceError = ""
        return try {
            readBundle().token.ifEmpty { null }
        } catch (error: Exception) {
            lastPersistenceError = "load_token_failed"
            null
        }
    }

    /** 源 `SessionManager.ets:121` `clearToken`——失败置 `clear_token_failed`。 */
    suspend fun clearToken() {
        lastPersistenceError = ""
        try {
            writeBundle(readBundle().copy(token = ""))
        } catch (error: Exception) {
            lastPersistenceError = "clear_token_failed"
        }
    }

    // --- 源 L132-L175：会话快照存取 -----------------------------------------

    /** 源 `SessionManager.ets:132` `saveSession`——整块快照 JSON 落库；失败置 `save_session_failed`。 */
    suspend fun saveSession(snapshot: AuthSession) {
        lastPersistenceError = ""
        try {
            writeBundle(readBundle().copy(snapshot = snapshot))
        } catch (error: Exception) {
            lastPersistenceError = "save_session_failed"
        }
    }

    /**
     * 源 `SessionManager.ets:143` `getSession`：空串 → `null`；解析成功但快照非法 → `null`
     * （源 L151-L156 `isValidSnapshot`）；失败置 `load_session_failed`。
     */
    suspend fun getSession(): AuthSession? {
        lastPersistenceError = ""
        return try {
            val snapshot: AuthSession? = readBundle().snapshot
            if (snapshot == null || !isValidSnapshot(snapshot)) null else snapshot
        } catch (error: Exception) {
            lastPersistenceError = "load_session_failed"
            null
        }
    }

    /** 源 `SessionManager.ets:162` `clearSession`——失败置 `clear_session_failed`。 */
    suspend fun clearSession() {
        lastPersistenceError = ""
        try {
            writeBundle(readBundle().copy(snapshot = null))
        } catch (error: Exception) {
            lastPersistenceError = "clear_session_failed"
        }
    }

    /**
     * 登录态判定。
     *
     * 源 `SessionManager.ets:177` `isLoggedIn` 为**乐观判定**——快照存在且 `userId` 非空即 `true`。
     * 安卓侧在此之上叠加 **token 过期校验**（源 `TOKEN_EXPIRY_DAYS = 7`，见类注释「过期语义」）：
     * 快照存在 **且** token 未过期才判为已登录，使「过期会话失效」语义可用。
     * 异常置 `check_login_failed` 并返回 `false`。
     */
    suspend fun isLoggedIn(nowSeconds: Long = currentSeconds()): Boolean = try {
        val bundle: SessionBundle = readBundle()
        val snapshot: AuthSession? = bundle.snapshot
        if (snapshot == null || snapshot.userId.isEmpty()) {
            false
        } else {
            validateToken(bundle.token, nowSeconds)
        }
    } catch (error: Exception) {
        lastPersistenceError = "check_login_failed"
        false
    }

    /** 源 `SessionManager.ets:190` `isValidSnapshot`——`userId` 非空（其余字段由 Kotlin 类型保证）。 */
    private fun isValidSnapshot(snapshot: AuthSession): Boolean = snapshot.userId.isNotEmpty()

    // --- 内部：整块 JSON 读写 -----------------------------------------------

    private suspend fun readBundle(): SessionBundle {
        val raw: String? = store.readString(STORE_KEY)
        if (raw.isNullOrEmpty()) {
            return SessionBundle()
        }
        return try {
            JsonCodec.json.decodeFromString(raw)
        } catch (error: Exception) {
            SessionBundle()
        }
    }

    private suspend fun writeBundle(bundle: SessionBundle) {
        store.writeString(STORE_KEY, JsonCodec.json.encodeToString(bundle))
    }

    // --- 内部：Base64（对齐源 `util.Base64Helper` 默认 BASIC 编码） -----------

    private fun base64Encode(value: String): String =
        Base64.encodeToString(value.toByteArray(Charsets.UTF_8), Base64.NO_WRAP)

    private fun base64Decode(value: String): String =
        String(Base64.decode(value, Base64.NO_WRAP), Charsets.UTF_8)

    private fun currentSeconds(): Long = System.currentTimeMillis() / 1000

    companion object {
        /** 实际 [JsonStore] 键——鸿蒙库名 `fit_tracker_session`（源 `SessionManager.ets:11` `STORE_NAME`）。 */
        const val STORE_KEY: String = StoreNames.SESSION

        /** 鸿蒙源键名（源 `SessionManager.ets:12` `TOKEN_KEY`）。安卓侧折叠为单块 JSON，仅作对照。 */
        const val TOKEN_KEY: String = "auth_token"

        /** 鸿蒙源键名（源 `SessionManager.ets:13` `SNAPSHOT_KEY`）。安卓侧折叠为单块 JSON，仅作对照。 */
        const val SNAPSHOT_KEY: String = "session_snapshot"

        /** 源 `SessionManager.ets:14`——Token 有效期 7 天。 */
        const val TOKEN_EXPIRY_DAYS: Long = 7
    }
}

/**
 * 会话快照别名——源 `SessionManager.ets:31` `export type SessionSnapshot = AuthSession`
 * （单一真源在 `auth/AuthTypes`）。
 */
typealias SessionSnapshot = AuthSession

/** Token 载荷——源 `SessionManager.ets:21` `interface TokenPayload`。`iat` / `exp` 单位秒。 */
@Serializable
data class TokenPayload(
    val userId: String,
    val iat: Long,
    val exp: Long,
)

/**
 * 会话落盘整体——安卓折叠模型把源库内 `auth_token` + `session_snapshot` 两键合并为一块 JSON
 * （见类注释「持久化模型」）。`snapshot` 为快照本体，`token` 为 JWT 串。
 */
@Serializable
data class SessionBundle(
    val token: String = "",
    val snapshot: AuthSession? = null,
)

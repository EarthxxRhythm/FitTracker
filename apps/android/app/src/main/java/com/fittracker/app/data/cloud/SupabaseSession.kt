package com.fittracker.app.data.cloud

import com.fittracker.app.data.auth.AuthSession
import com.fittracker.app.data.persist.JsonCodec
import com.fittracker.app.data.persist.JsonStore
import com.fittracker.app.data.persist.StoreNames
import kotlinx.serialization.Serializable
import kotlinx.serialization.decodeFromString
import kotlinx.serialization.encodeToString

/**
 * 云端（Supabase）会话快照——access / refresh token + 过期时刻 + 用户快照。
 *
 * 设计取舍：
 * - **与沙盒会话分键存放**——沙盒侧 `token` / `snapshot` 落在 [StoreNames.SESSION]
 *   （见 `SessionManager.SessionBundle`）；云端 token 语义不同（含 refresh token 与过期时刻，
 *   且由 GoTrue 签发、Refresh 轮换），故独立成块存于 [StoreNames.CLOUD_SESSION]，互不干扰。
 * - 整块 JSON 落库（对齐项目「一个 preferences 键装一整块 JSON」的折叠模型，同
 *   `SessionManager` / `SandboxAuthProvider` 手法）。
 *
 * 过期语义：`expiresAtEpochSeconds` = 签发时刻（秒）+ 响应 `expires_in`；
 * 临近过期由 `SupabaseAuthProvider.refreshIfNeeded()` 依据它判定（窗口见该类常量）。
 */
@Serializable
data class CloudSession(
    /** GoTrue 签发的 access token（Bearer 凭据，供快照 store 调用 PostgREST）。 */
    val accessToken: String,
    /** GoTrue 签发的 refresh token（用于临近过期时换取新 token；每次刷新会轮换）。 */
    val refreshToken: String,
    /** access token 过期时刻（Unix 秒）。 */
    val expiresAtEpochSeconds: Long,
    /** 用户快照（跨平台互操作契约，见 `AuthSession`）——映射自 GoTrue `user`。 */
    val snapshot: AuthSession,
)

/**
 * 云端会话持久化——整块 [CloudSession] JSON 存于键 [STORE_KEY]。
 *
 * 读写**吞异常**（对齐项目其它存储封装的防御口径：本地存储不可用时返回 `null` / 静默失败，
 * 不阻塞认证主流程）。
 */
class SupabaseSessionStore(private val store: JsonStore) {

    /** 读取会话；缺键 / 空串 / 解析失败一律回落 `null`。 */
    suspend fun load(): CloudSession? = try {
        store.readString(STORE_KEY)
            ?.takeIf { it.isNotEmpty() }
            ?.let { JsonCodec.json.decodeFromString<CloudSession>(it) }
    } catch (error: Exception) {
        null
    }

    /** 整块 JSON 落库（覆盖写）；失败静默。 */
    suspend fun save(session: CloudSession) {
        try {
            store.writeString(STORE_KEY, JsonCodec.json.encodeToString(session))
        } catch (error: Exception) {
            // 本地存储不可用：不阻塞认证流程（内存缓存仍持有本会话）
        }
    }

    /** 清除会话键；失败静默。 */
    suspend fun clear() {
        try {
            store.remove(STORE_KEY)
        } catch (error: Exception) {
            // 清理失败不抛——调用方已清空内存态
        }
    }

    companion object {
        /** 实际 [JsonStore] 键——[StoreNames.CLOUD_SESSION]。 */
        const val STORE_KEY: String = StoreNames.CLOUD_SESSION
    }
}

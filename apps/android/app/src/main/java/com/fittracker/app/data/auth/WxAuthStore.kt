package com.fittracker.app.data.auth

import android.content.Context
import org.json.JSONObject

/**
 * 安卓侧第三方授权结果的跨生命周期暂存。
 *
 * 与鸿蒙端 PendingAuthStore 同构（见 apps/harmony/.../PendingAuthStore.ets）：
 * 微信授权会切到微信 App，宿主 Activity 可能被销毁；WXEntryActivity 回调先于
 * 登录页重建，结果必须落盘。消费一次即清 + TTL 过期保护。
 *
 * 存储实现用 SharedPreferences（安卓侧轻量键值），与项目其余「非敏感状态」一致；
 * 授权码本身是一次性短期凭据，不属长期敏感数据。
 */
object WxAuthStore {

    private const val STORE_NAME: String = "fit_tracker_pending_wx_auth"
    private const val KEY_RECORD: String = "pending_record"

    /** 授权结果有效期（毫秒）：超时视为过期，避免陈旧 code 误用。 */
    private const val PENDING_TTL_MS: Long = 5 * 60 * 1000

    private const val FIELD_KIND: String = "kind"
    private const val FIELD_CODE: String = "authCode"
    private const val FIELD_STATE: String = "state"
    private const val FIELD_MESSAGE: String = "message"
    private const val FIELD_CREATED_AT: String = "createdAt"

    /** 保存授权成功的一次性凭据。 */
    fun saveCode(context: Context, authCode: String, state: String) {
        write(context, buildRecord(KIND_CODE, authCode, state, ""))
    }

    /** 保存授权失败（用户取消 / 未安装 / 其他错误）。 */
    fun saveFailure(context: Context, kind: String, message: String) {
        write(context, buildRecord(kind, "", "", message))
    }

    /**
     * 消费：读取后立即清除；无记录 / 已过期 / 解析失败一律返回 null。
     * 一次性语义：无论过期与否，读到即清。
     */
    fun consume(context: Context): WxAuthResult? {
        val prefs = context.applicationContext
            .getSharedPreferences(STORE_NAME, Context.MODE_PRIVATE)
        val raw: String? = prefs.getString(KEY_RECORD, null)
        if (raw.isNullOrEmpty()) {
            return null
        }
        prefs.edit().remove(KEY_RECORD).apply()
        return try {
            val json = JSONObject(raw)
            val createdAt: Long = json.optLong(FIELD_CREATED_AT, 0L)
            if (System.currentTimeMillis() - createdAt > PENDING_TTL_MS) {
                return null
            }
            WxAuthResult(
                kind = json.optString(FIELD_KIND, ""),
                authCode = json.optString(FIELD_CODE, ""),
                state = json.optString(FIELD_STATE, ""),
                message = json.optString(FIELD_MESSAGE, ""),
            )
        } catch (error: Exception) {
            null
        }
    }

    /** 清理（登出 / 主动取消授权时）。 */
    fun clear(context: Context) {
        context.applicationContext
            .getSharedPreferences(STORE_NAME, Context.MODE_PRIVATE)
            .edit().remove(KEY_RECORD).apply()
    }

    private fun buildRecord(kind: String, authCode: String, state: String, message: String): String {
        val json = JSONObject()
        json.put(FIELD_KIND, kind)
        json.put(FIELD_CODE, authCode)
        json.put(FIELD_STATE, state)
        json.put(FIELD_MESSAGE, message)
        json.put(FIELD_CREATED_AT, System.currentTimeMillis())
        return json.toString()
    }

    private fun write(context: Context, record: String) {
        context.applicationContext
            .getSharedPreferences(STORE_NAME, Context.MODE_PRIVATE)
            .edit().putString(KEY_RECORD, record).apply()
    }

    /** kind 取值：与鸿蒙端 ThirdPartyAuthFailureKind 对齐。 */
    const val KIND_CODE: String = "code"
    const val KIND_CANCELLED: String = "cancelled"
    const val KIND_UNAVAILABLE: String = "unavailable"
    const val KIND_ERROR: String = "error"
}

/** 待消费的微信授权结果。 */
data class WxAuthResult(
    val kind: String,
    val authCode: String,
    val state: String,
    val message: String,
)

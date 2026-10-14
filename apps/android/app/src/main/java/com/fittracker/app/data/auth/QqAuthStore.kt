package com.fittracker.app.data.auth

import android.content.Context
import org.json.JSONObject

/**
 * 安卓侧 QQ 授权结果的跨生命周期暂存。
 *
 * 与 WxAuthStore 同构（QQ 授权同样会切到 QQ App / 浏览器，宿主可能被销毁）。
 *
 * 生命周期差异（与微信相比）：
 *  QQ SDK 用 `Tencent.createInstance(appId, context)` 的 IUiListener 回调在**同一进程内**
 *  返回（不经过独立 Activity 回跳），因此多数场景下结果可直接在回调里处理。
 *  但 QQ 官方也支持 hide 授权页后的 Activity 重建，且为与微信通道保持一致的消费方式
 *  （登录页统一读 store），仍落盘一次。
 */
object QqAuthStore {

    private const val STORE_NAME: String = "fit_tracker_pending_qq_auth"
    private const val KEY_RECORD: String = "pending_record"
    private const val PENDING_TTL_MS: Long = 5 * 60 * 1000

    private const val FIELD_KIND: String = "kind"
    private const val FIELD_CODE: String = "authCode"
    private const val FIELD_OPEN_ID: String = "openId"
    private const val FIELD_MESSAGE: String = "message"
    private const val FIELD_CREATED_AT: String = "createdAt"

    /** 保存授权成功的一次性凭据（QQ 的 authCode 即 access_token，openid 随附）。 */
    fun saveCode(context: Context, accessToken: String, openId: String) {
        write(context, buildRecord(KIND_CODE, accessToken, openId, ""))
    }

    /** 保存授权失败（用户取消 / 未安装 / 其他错误）。 */
    fun saveFailure(context: Context, kind: String, message: String) {
        write(context, buildRecord(kind, "", "", message))
    }

    /** 消费：读取后立即清除；无记录 / 已过期 / 解析失败返回 null。 */
    fun consume(context: Context): QqAuthResult? {
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
            QqAuthResult(
                kind = json.optString(FIELD_KIND, ""),
                authCode = json.optString(FIELD_CODE, ""),
                openId = json.optString(FIELD_OPEN_ID, ""),
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

    private fun buildRecord(kind: String, authCode: String, openId: String, message: String): String {
        val json = JSONObject()
        json.put(FIELD_KIND, kind)
        json.put(FIELD_CODE, authCode)
        json.put(FIELD_OPEN_ID, openId)
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

/** 待消费的 QQ 授权结果。 */
data class QqAuthResult(
    val kind: String,
    val authCode: String,
    val openId: String,
    val message: String,
)

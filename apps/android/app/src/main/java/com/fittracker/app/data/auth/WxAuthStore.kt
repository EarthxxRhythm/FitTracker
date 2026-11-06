package com.fittracker.app.data.auth

import android.content.Context
import kotlinx.serialization.Serializable

/**
 * 安卓侧第三方授权结果的跨生命周期暂存。
 *
 * 与鸿蒙端 PendingAuthStore 同构（见 apps/harmony/.../PendingAuthStore.ets）：
 * 微信授权会切到微信 App，宿主 Activity 可能被销毁；WXEntryActivity 回调先于
 * 登录页重建，结果必须落盘。消费一次即清 + TTL 过期保护。
 *
 * 存储机制已抽到 [ThirdPartyAuthStore]，这里只保留微信通道的记录字段与对外 API。
 * 底层用 SharedPreferences（安卓侧轻量键值），与项目其余「非敏感状态」一致；
 * 授权码本身是一次性短期凭据，不属长期敏感数据。
 */
object WxAuthStore {

    private const val STORE_NAME: String = "fit_tracker_pending_wx_auth"

    private val storage: ThirdPartyAuthStore<WxAuthRecord> = ThirdPartyAuthStore(
        storeName = STORE_NAME,
        serializer = WxAuthRecord.serializer(),
        createdAtOf = { record -> record.createdAt },
    )

    /** 保存授权成功的一次性凭据。 */
    fun saveCode(context: Context, authCode: String, state: String) {
        storage.write(context) { createdAt ->
            WxAuthRecord(
                kind = KIND_CODE,
                authCode = authCode,
                state = state,
                message = "",
                createdAt = createdAt,
            )
        }
    }

    /** 保存授权失败（用户取消 / 未安装 / 其他错误）。 */
    fun saveFailure(context: Context, kind: String, message: String) {
        storage.write(context) { createdAt ->
            WxAuthRecord(
                kind = kind,
                authCode = "",
                state = "",
                message = message,
                createdAt = createdAt,
            )
        }
    }

    /**
     * 消费：读取后立即清除；无记录 / 已过期 / 解析失败一律返回 null。
     * 一次性语义：无论过期与否，读到即清。
     */
    fun consume(context: Context): WxAuthResult? = storage.consume(context) { record ->
        WxAuthResult(
            kind = record.kind,
            authCode = record.authCode,
            state = record.state,
            message = record.message,
        )
    }

    /** 清理（登出 / 主动取消授权时）。 */
    fun clear(context: Context) {
        storage.clear(context)
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

/**
 * 落盘记录（与 WxAuthResult 同字段 + 写入时间）。
 *
 * 字段名与声明顺序沿用旧版手写 org.json 的输出，保证升级前后的存量记录可读。
 */
@Serializable
internal data class WxAuthRecord(
    val kind: String = "",
    val authCode: String = "",
    val state: String = "",
    val message: String = "",
    val createdAt: Long = 0L,
)

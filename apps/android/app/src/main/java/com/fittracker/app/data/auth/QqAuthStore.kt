package com.fittracker.app.data.auth

import android.content.Context
import kotlinx.serialization.Serializable

/**
 * 安卓侧 QQ 授权结果的跨生命周期暂存。
 *
 * 与 WxAuthStore 同构（QQ 授权同样会切到 QQ App / 浏览器，宿主可能被销毁），
 * 存储机制已抽到 [ThirdPartyAuthStore]，这里只保留 QQ 通道的记录字段与对外 API。
 *
 * 生命周期差异（与微信相比）：
 *  QQ SDK 用 `Tencent.createInstance(appId, context)` 的 IUiListener 回调在**同一进程内**
 *  返回（不经过独立 Activity 回跳），因此多数场景下结果可直接在回调里处理。
 *  但 QQ 官方也支持 hide 授权页后的 Activity 重建，且为与微信通道保持一致的消费方式
 *  （登录页统一读 store），仍落盘一次。
 */
object QqAuthStore {

    private const val STORE_NAME: String = "fit_tracker_pending_qq_auth"

    private val storage: ThirdPartyAuthStore<QqAuthRecord> = ThirdPartyAuthStore(
        storeName = STORE_NAME,
        serializer = QqAuthRecord.serializer(),
        createdAtOf = { record -> record.createdAt },
    )

    /** 保存授权成功的一次性凭据（QQ 的 authCode 即 access_token，openid 随附）。 */
    fun saveCode(context: Context, accessToken: String, openId: String) {
        storage.write(context) { createdAt ->
            QqAuthRecord(
                kind = KIND_CODE,
                authCode = accessToken,
                openId = openId,
                message = "",
                createdAt = createdAt,
            )
        }
    }

    /** 保存授权失败（用户取消 / 未安装 / 其他错误）。 */
    fun saveFailure(context: Context, kind: String, message: String) {
        storage.write(context) { createdAt ->
            QqAuthRecord(
                kind = kind,
                authCode = "",
                openId = "",
                message = message,
                createdAt = createdAt,
            )
        }
    }

    /** 消费：读取后立即清除；无记录 / 已过期 / 解析失败返回 null。 */
    fun consume(context: Context): QqAuthResult? = storage.consume(context) { record ->
        QqAuthResult(
            kind = record.kind,
            authCode = record.authCode,
            openId = record.openId,
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

/** 待消费的 QQ 授权结果。 */
data class QqAuthResult(
    val kind: String,
    val authCode: String,
    val openId: String,
    val message: String,
)

/**
 * 落盘记录（与 QqAuthResult 同字段 + 写入时间）。
 *
 * 字段名与声明顺序沿用旧版手写 org.json 的输出，保证升级前后的存量记录可读。
 */
@Serializable
internal data class QqAuthRecord(
    val kind: String = "",
    val authCode: String = "",
    val openId: String = "",
    val message: String = "",
    val createdAt: Long = 0L,
)

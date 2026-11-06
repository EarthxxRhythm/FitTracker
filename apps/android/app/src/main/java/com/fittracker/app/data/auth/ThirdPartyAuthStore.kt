package com.fittracker.app.data.auth

import android.content.Context
import com.fittracker.app.data.persist.JsonCodec
import kotlinx.serialization.KSerializer

/**
 * 第三方授权结果的跨生命周期暂存公共实现（QQ / 微信共用）。
 *
 * 两条通道的存储语义完全一致：写入一条记录 → 消费一次即清 → 超过 TTL 视为过期。
 * 差异只有两点：SharedPreferences 文件名，以及记录字段（QQ 带 openId，微信带 state）。
 * 因此这里只封装机制，记录本体由各通道在自己的 Store 文件里定义
 * （见 QqAuthStore 的 QqAuthRecord、WxAuthStore 的 WxAuthRecord）。
 *
 * 序列化统一走 [JsonCodec]（kotlinx.serialization），不再手写 org.json。
 *
 * @param storeName SharedPreferences 文件名。
 * @param serializer 记录序列化器。
 * @param createdAtOf 从记录中取出写入时间，用于 TTL 判定。
 */
internal class ThirdPartyAuthStore<R : Any>(
    private val storeName: String,
    private val serializer: KSerializer<R>,
    private val createdAtOf: (R) -> Long,
) {

    /** 消费：读取后立即清除；无记录 / 已过期 / 解析失败一律返回 null。 */
    fun <T : Any> consume(context: Context, toResult: (R) -> T): T? {
        val prefs = prefs(context)
        val raw: String? = prefs.getString(KEY_RECORD, null)
        if (raw.isNullOrEmpty()) {
            return null
        }
        prefs.edit().remove(KEY_RECORD).apply()
        return try {
            val record: R = JsonCodec.json.decodeFromString(serializer, raw)
            if (System.currentTimeMillis() - createdAtOf(record) > PENDING_TTL_MS) {
                return null
            }
            toResult(record)
        } catch (error: Exception) {
            null
        }
    }

    /** 清理（登出 / 主动取消授权时）。 */
    fun clear(context: Context) {
        prefs(context).edit().remove(KEY_RECORD).apply()
    }

    /** 写入一条待消费记录（覆盖旧值）。写入时间由这里统一注入，保证 TTL 口径单一。 */
    fun write(context: Context, build: (createdAt: Long) -> R) {
        val record: R = build(System.currentTimeMillis())
        val raw: String = JsonCodec.json.encodeToString(serializer, record)
        prefs(context).edit().putString(KEY_RECORD, raw).apply()
    }

    private fun prefs(context: Context) =
        context.applicationContext.getSharedPreferences(storeName, Context.MODE_PRIVATE)

    private companion object {
        const val KEY_RECORD: String = "pending_record"

        /** 记录有效期（毫秒）：超时视为过期，避免陈旧凭据误用。 */
        const val PENDING_TTL_MS: Long = 5 * 60 * 1000
    }
}

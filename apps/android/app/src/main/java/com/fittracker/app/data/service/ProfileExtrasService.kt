package com.fittracker.app.data.service

import com.fittracker.app.data.persist.JsonCodec
import com.fittracker.app.data.persist.JsonStore
import com.fittracker.app.data.persist.StoreNames
import kotlinx.serialization.Serializable
import kotlinx.serialization.decodeFromString
import kotlinx.serialization.encodeToString

/**
 * 名片类附加字段——对应鸿蒙 `common/services/ProfileExtrasService.ets` 的 `interface ProfileExtras`。
 *
 * 只装**不进云快照信封**的本地个人信息：地区、拍一拍、个性签名、常用健身房。
 * 昵称/头像/性别/身高/出生年/经验/体重单位仍由 [UserProfileService] 管，边界固定，
 * 不要把这些字段塞进 [UserProfile]（那会改动双端信封结构）。
 */
@Serializable
data class ProfileExtras(
    /** 地区；空串表示未填写。 */
    val region: String = "",
    /** 拍一拍文案；空串表示未填写。 */
    val tickle: String = "",
    /** 个性签名；空串表示未填写。 */
    val whatsUp: String = "",
    /** 常用健身房（地址类文本）；空串表示未填写。 */
    val gymAddress: String = "",
)

/**
 * 个人资料附加字段持久化服务——逐方法移植自鸿蒙 `common/services/ProfileExtrasService.ets`。
 *
 * 持久化模型：鸿蒙在 `fit_tracker_profile_extras` 库里逐键存取；安卓侧折叠为**一块 JSON**
 * 存于键 [StoreNames.PROFILE_EXTRAS]（同 `UserProfileService` 手法），语义不变。
 */
object ProfileExtrasService {

    /** 实际 JsonStore 键——与鸿蒙 `STORE_NAME` 同值。 */
    const val STORE_KEY: String = StoreNames.PROFILE_EXTRAS

    /** 鸿蒙源库名（源 `ProfileExtrasService.ets` 的 `STORE_NAME`）。 */
    const val STORE_NAME: String = "fit_tracker_profile_extras"

    /** 最近一次持久化错误码（源 `lastPersistenceError`）。 */
    private var lastPersistenceError: String = ""

    /** 源 `getLastPersistenceError`。 */
    fun getLastPersistenceError(): String = lastPersistenceError

    /** 源 `getEmptyExtras`。 */
    fun getEmptyExtras(): ProfileExtras = ProfileExtras()

    /**
     * 源 `loadExtras`：读库失败置 `load_extras_failed` 并回落空值；
     * 缺键/解析失败一律空值（不抛，避免整页载入中断）。
     */
    suspend fun loadExtras(store: JsonStore): ProfileExtras {
        lastPersistenceError = ""
        val raw: String? = try {
            store.readString(STORE_KEY)
        } catch (error: Exception) {
            lastPersistenceError = "load_extras_failed"
            return getEmptyExtras()
        }
        if (raw.isNullOrEmpty()) {
            return getEmptyExtras()
        }
        return try {
            JsonCodec.json.decodeFromString<ProfileExtras>(raw)
        } catch (error: Exception) {
            getEmptyExtras()
        }
    }

    /** 源 `saveExtras`：整块写入；失败置 `save_extras_failed`。 */
    suspend fun saveExtras(store: JsonStore, extras: ProfileExtras) {
        lastPersistenceError = ""
        try {
            store.writeString(STORE_KEY, JsonCodec.json.encodeToString(extras))
        } catch (error: Exception) {
            lastPersistenceError = "save_extras_failed"
        }
    }

    /** 源 `clearExtras`：清掉附加字段（账号数据生命周期调用）。 */
    suspend fun clearExtras(store: JsonStore) {
        lastPersistenceError = ""
        try {
            store.remove(STORE_KEY)
        } catch (error: Exception) {
            lastPersistenceError = "clear_extras_failed"
        }
    }
}

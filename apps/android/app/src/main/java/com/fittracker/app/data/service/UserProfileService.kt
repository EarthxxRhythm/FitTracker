package com.fittracker.app.data.service

import com.fittracker.app.data.persist.JsonCodec
import com.fittracker.app.data.persist.JsonStore
import com.fittracker.app.data.persist.StoreNames
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.decodeFromString
import kotlinx.serialization.encodeToString

/** 缺省体重单位（源 `UserProfileService.ets:22` `DEFAULT_PROFILE.weightUnit`）。 */
private const val DEFAULT_WEIGHT_UNIT_ID: String = "kg"

/**
 * 体重单位——对应源 `UserProfileService.ets:14` 的 `export type WeightUnit = 'kg' | 'lbs'`。
 *
 * `id` 即鸿蒙落盘的字符串；[SerialName] 保证 JSON 序列化为 `"kg"` / `"lbs"` 而非枚举名。
 */
@Serializable
enum class WeightUnit(val id: String) {
    @SerialName("kg")
    KG("kg"),

    @SerialName("lbs")
    LBS("lbs"),
}

/** 用户资料——对应源 `UserProfileService.ets:16` 的 `interface UserProfile`。 */
@Serializable
data class UserProfile(
    val nickname: String = "",
    val avatar: String = "",
    val weightUnit: WeightUnit = WeightUnit.KG,
)

/**
 * 用户个人资料持久化服务——逐方法移植自鸿蒙 `common/services/UserProfileService.ets`。
 *
 * Failure #5：管理昵称、头像占位、体重单位偏好的本地存储（源 L5）。
 *
 * 持久化模型（与源的映射）：
 * - 鸿蒙侧在 `fit_tracker_profile` 库里用 **3 个原始键** `nickname` / `avatar` / `weight_unit`
 *   分别存取（源 L39-L41、L57、L81、L92）。
 * - 安卓侧（Wave 2 折叠模型）：折叠进单一 DataStore 后，整份 [UserProfile] 以**一块 JSON**
 *   存于键 [StoreNames.PROFILE]（`fit_tracker_profile`）。因此源的「写单字段」方法
 *   （`saveNickname` / `saveAvatar` / `saveWeightUnit`）在安卓侧实现为**读-改-写**，语义
 *   不变（只改目标字段、其余保留）。
 *
 * `weightUnit` 的容错：源以字符串存取并对未知值归一为 `'kg'`（`normalizeWeightUnit` L120）。
 * 本侧落盘 JSON 的 `weightUnit` 仍按字符串承载（见内部 `UserProfileWire`），读回时经
 * [normalizeWeightUnit] 归一——保证「存 `"stone"` 也读回 `KG` 且不丢昵称/头像」。
 *
 * 与源的差异：首参 `context: Context` → 注入 [JsonStore]；`async` → `suspend`。方法名对齐。
 */
object UserProfileService {

    /** 实际 JsonStore 键——鸿蒙语义库名 `fit_tracker_profile`。 */
    const val STORE_KEY: String = StoreNames.PROFILE

    /** 鸿蒙源库名（源 `UserProfileService.ets:9` 的 `STORE_NAME`）。 */
    const val STORE_NAME: String = "fit_tracker_profile"

    /** 鸿蒙源键名（源 `UserProfileService.ets:10`）。安卓侧折叠为整块 JSON，键名仅作对照。 */
    const val KEY_NICKNAME: String = "nickname"

    /** 鸿蒙源键名（源 `UserProfileService.ets:11`）。 */
    const val KEY_AVATAR: String = "avatar"

    /** 鸿蒙源键名（源 `UserProfileService.ets:12`）。 */
    const val KEY_WEIGHT_UNIT: String = "weight_unit"

    /** 最近一次持久化错误码（源 `UserProfileService.ets:29` 的 `lastPersistenceError`）。 */
    private var lastPersistenceError: String = ""

    /** 源 `UserProfileService.ets:31` `getLastPersistenceError`。 */
    fun getLastPersistenceError(): String = lastPersistenceError

    // --- 源 L35-L97：读 / 写 -------------------------------------------------

    /**
     * 源 `UserProfileService.ets:35` `loadProfile`：读库失败回落默认并置 `load_profile_failed`；
     * 缺键/空串回落 [getDefaultProfile]；`weightUnit` 经 [normalizeWeightUnit] 归一。
     */
    suspend fun loadProfile(store: JsonStore): UserProfile {
        lastPersistenceError = ""
        val raw: String? = try {
            store.readString(STORE_KEY)
        } catch (error: Exception) {
            lastPersistenceError = "load_profile_failed"
            return getDefaultProfile()
        }
        if (raw.isNullOrEmpty()) {
            return getDefaultProfile()
        }
        return decodeProfile(raw)
    }

    /** 源 `UserProfileService.ets:53` `saveNickname`——只改昵称，其余字段保留（读-改-写）。 */
    suspend fun saveNickname(store: JsonStore, nickname: String) {
        lastPersistenceError = ""
        try {
            writeProfile(store, readProfileQuiet(store).copy(nickname = nickname))
        } catch (error: Exception) {
            lastPersistenceError = "save_nickname_failed"
        }
    }

    /** 源 `UserProfileService.ets:64` `saveProfile`——整份写入，单位先归一。 */
    suspend fun saveProfile(store: JsonStore, profile: UserProfile) {
        lastPersistenceError = ""
        try {
            writeProfile(store, profile.copy(weightUnit = normalizeWeightUnit(profile.weightUnit.id)))
        } catch (error: Exception) {
            lastPersistenceError = "save_profile_failed"
        }
    }

    /** 源 `UserProfileService.ets:77` `saveAvatar`——只改头像（读-改-写）。 */
    suspend fun saveAvatar(store: JsonStore, avatar: String) {
        lastPersistenceError = ""
        try {
            writeProfile(store, readProfileQuiet(store).copy(avatar = avatar))
        } catch (error: Exception) {
            lastPersistenceError = "save_avatar_failed"
        }
    }

    /** 源 `UserProfileService.ets:88` `saveWeightUnit`——只改单位（读-改-写）。 */
    suspend fun saveWeightUnit(store: JsonStore, unit: WeightUnit) {
        lastPersistenceError = ""
        try {
            writeProfile(store, readProfileQuiet(store).copy(weightUnit = unit))
        } catch (error: Exception) {
            lastPersistenceError = "save_weight_unit_failed"
        }
    }

    /** 源 `UserProfileService.ets:99` `getDefaultProfile`——`{ nickname:'', avatar:'', weightUnit:'kg' }`。 */
    fun getDefaultProfile(): UserProfile = UserProfile(
        nickname = "",
        avatar = "",
        weightUnit = WeightUnit.KG,
    )

    /** 源 `UserProfileService.ets:107` `clearProfile`——清掉资料（删库键）。 */
    suspend fun clearProfile(store: JsonStore) {
        lastPersistenceError = ""
        try {
            store.remove(STORE_KEY)
        } catch (error: Exception) {
            lastPersistenceError = "clear_profile_failed"
        }
    }

    /**
     * 源 `UserProfileService.ets:120` `normalizeWeightUnit`：仅 `'lbs'` 判为 `LBS`，其余一律 `KG`。
     */
    fun normalizeWeightUnit(value: String): WeightUnit =
        if (value == WeightUnit.LBS.id) WeightUnit.LBS else WeightUnit.KG

    // --- 内部：整块 JSON 读写 ------------------------------------------------

    /** 静默读回当前资料（缺键/解析失败回落默认），**不触碰** [lastPersistenceError]——供读-改-写用。 */
    private suspend fun readProfileQuiet(store: JsonStore): UserProfile {
        val raw: String? = store.readString(STORE_KEY)
        if (raw.isNullOrEmpty()) {
            return getDefaultProfile()
        }
        return decodeProfile(raw)
    }

    private fun decodeProfile(raw: String): UserProfile = try {
        val wire: UserProfileWire = JsonCodec.json.decodeFromString(raw)
        UserProfile(
            nickname = wire.nickname,
            avatar = wire.avatar,
            weightUnit = normalizeWeightUnit(wire.weightUnit),
        )
    } catch (error: Exception) {
        getDefaultProfile()
    }

    private suspend fun writeProfile(store: JsonStore, profile: UserProfile) {
        store.writeString(STORE_KEY, JsonCodec.json.encodeToString(profile))
    }
}

/**
 * 落盘线格式：`weightUnit` 以**原始字符串**承载，使未知值能经 [UserProfileService.normalizeWeightUnit]
 * 归一（源按字符串存取，故不会被严格枚举解析拒绝、连带丢掉昵称/头像）。
 * 只在读写边界使用，不外泄。
 */
@Serializable
private data class UserProfileWire(
    val nickname: String = "",
    val avatar: String = "",
    val weightUnit: String = DEFAULT_WEIGHT_UNIT_ID,
)

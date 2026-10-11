package com.fittracker.app.data.persist

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.flow.first

/**
 * 存储键名——语义命名对齐鸿蒙工程 `app/AppState.ets`（FitTrackerStores）与各服务 `STORE_NAME`。
 *
 * 说明：preferences 文件本身不可跨平台互通，键名对齐的价值在于**语义对照与排障**；
 * 真正跨平台互通的载体是备份包 JSON（见 `data/model/BackupPackage.kt`）。
 * 鸿蒙侧精确键名的逐服务核对在 Wave 3/5 各自实现时进行（用不到的键不预先造）。
 */
object StoreNames {
    /** 目标设置（`fit_tracker_goal`）。 */
    const val GOAL = "fit_tracker_goal"

    /** 我的计划列表（存 `List<UserPlan>` JSON；鸿蒙 `fit_tracker_plans` / `my_plans`）。 */
    const val PLANS = "fit_tracker_plans"

    /** 当前计划指针（鸿蒙 `fit_tracker_plans` / `current_plan_id`）。 */
    const val CURRENT_PLAN_ID = "fit_tracker_current_plan_id"

    /** 训练会话列表（存 `List<WorkoutSession>` JSON）。 */
    const val SESSIONS = "fit_tracker_sessions"

    /** 进行中训练（草稿）。 */
    const val ACTIVE_WORKOUT = "fit_tracker_active_workout"

    /** 用户资料。 */
    const val PROFILE = "fit_tracker_profile"

    /** 云同步基线（hash / 时间戳）。 */
    const val SYNC = "fit_tracker_sync"

    /** 沙盒认证（本地账号体系）。 */
    const val SANDBOX_AUTH = "fit_tracker_sandbox_auth"

    /** 内容库版本元数据。 */
    const val CONTENT = "fit_tracker_content"

    /** 登录会话（token 快照——沙盒 Provider）。 */
    const val SESSION = "fit_tracker_session"

    /** 云端会话（Supabase：access/refresh token + 快照——与沙盒会话分键存放）。 */
    const val CLOUD_SESSION = "fit_tracker_cloud_session"

    /** plan 屏浏览状态（存 `{ plan, card }` JSON；对齐原型 localStorage `fittracker-plan-state`）。 */
    const val PLAN_STATE = "fit_tracker_plan_state"

    /** 设置偏好（语言 / 周开始日 / 提醒与同步开关，整块 JSON）。 */
    const val SETTINGS = "fit_tracker_settings"

    /** 体重记录（存 `List<WeightRecord>` JSON；原型完整实现 Wave 3 · W3-1）。 */
    const val BODY_RECORDS = "fit_tracker_body_records"

    /**
     * 训练偏好（目标 / 经验 / 每周天数 / 单次时长 / 器械 / 限制肌群，整块 JSON）。
     *
     * Android 侧新增（设计原型 `fittracker-training-preferences.html`），鸿蒙工程无对等模型——
     * 故**不进备份包**（计划决策 D-6，见 `TrainingPreferencesService`）。
     */
    const val TRAINING_PREFERENCES = "fit_tracker_training_preferences"

    val ALL: List<String> = listOf(
        GOAL, PLANS, CURRENT_PLAN_ID, SESSIONS, ACTIVE_WORKOUT,
        PROFILE, SYNC, SANDBOX_AUTH, CONTENT, SESSION, CLOUD_SESSION,
        PLAN_STATE, SETTINGS, BODY_RECORDS, TRAINING_PREFERENCES,
    )
}

/** 应用级 DataStore 单例（文件 `fit_tracker.preferences_pb`）。 */
val Context.appDataStore: DataStore<Preferences> by preferencesDataStore(name = "fit_tracker")

/**
 * 整块 JSON 存取——对齐鸿蒙「一个 preferences 键装一整块 JSON 字符串」的模型。
 *
 * 构造接受 [DataStore] 而非 `Context`，便于测试注入临时文件（见 `JsonStoreTest`）。
 */
class JsonStore(private val dataStore: DataStore<Preferences>) {

    suspend fun readString(key: String): String? =
        dataStore.data.first()[stringPreferencesKey(key)]

    suspend fun writeString(key: String, value: String) {
        dataStore.edit { it[stringPreferencesKey(key)] = value }
    }

    suspend fun remove(key: String) {
        dataStore.edit { it.remove(stringPreferencesKey(key)) }
    }

    suspend fun <T> read(key: String, decode: (String) -> T): T? =
        readString(key)?.let(decode)

    suspend fun <T> write(key: String, value: T, encode: (T) -> String) {
        writeString(key, encode(value))
    }
}

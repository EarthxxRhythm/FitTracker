package com.fittracker.app.data.service

import com.fittracker.app.data.model.UserGoal
import com.fittracker.app.data.persist.JsonCodec
import com.fittracker.app.data.persist.JsonStore
import com.fittracker.app.data.persist.StoreNames
import kotlinx.serialization.decodeFromString
import kotlinx.serialization.encodeToString

/**
 * 本地用户目标仓储——逐方法移植自鸿蒙 `shared/services/GoalRepository.ets`。
 *
 * Feature #6：启动路由读取已保存目标（源 `GoalRepository.ets:3`）。
 *
 * 持久化模型（与源的映射）：
 * - 鸿蒙侧：`preferences.getPreferences(context, FitTrackerStores.GOAL)` 打开 `fit_tracker_goal`
 *   库，库内 `current_goal` 键装一整块 `UserGoal` JSON（源 L44）。
 * - 安卓侧（Wave 2 折叠模型）：所有鸿蒙 preferences 库折叠进**同一个** DataStore，
 *   库名退化为**键名**。本仓储因此把整块目标 JSON 存到键 [StoreNames.GOAL]（`fit_tracker_goal`），
 *   与 `JsonStoreTest` 的既定写法一致（该测试已把 `UserGoal` 写在此键下）。
 *
 * 与源的差异：鸿蒙方法首参 `context: Context` → 安卓侧改为注入 [JsonStore]（不硬绑 Context，
 * 便于单测注入临时文件）；`async` → `suspend`。方法名与源逐一对齐，其余语义（内存缓存、
 * `lastPersistenceError` 旗标、清空后回落）逐行复刻。
 *
 * 互操作约束：`UserGoal` 字段名与鸿蒙 JSON 输出逐字一致（见 `data/model/TrainingModels.kt`），
 * 备份包跨平台互通依赖于此。
 */
object GoalRepository {

    /** 鸿蒙源键名（`GoalRepository.ets:10` 的 `KEY_CURRENT_GOAL`）。安卓侧折叠为库名键 [STORE_KEY]。 */
    const val KEY_CURRENT_GOAL: String = "current_goal"

    /** 实际 JsonStore 键——鸿蒙库名 `fit_tracker_goal`（源 `AppState.ets` FitTrackerStores.GOAL）。 */
    const val STORE_KEY: String = StoreNames.GOAL

    /** 内存缓存（源 `GoalRepository.ets:11` 的 `currentGoal`）。 */
    private var currentGoal: UserGoal? = null

    /** 最近一次持久化错误码（源 `GoalRepository.ets:12` 的 `lastPersistenceError`）。 */
    private var lastPersistenceError: String = ""

    // --- 源 L16-L36：内存缓存（无 IO） ---------------------------------------

    /** 源 `GoalRepository.ets:16` `saveLocalGoal`——仅写缓存（深拷贝）。 */
    fun saveLocalGoal(goal: UserGoal) {
        currentGoal = copyGoal(goal)
    }

    /** 源 `GoalRepository.ets:20` `getLocalGoal`——无缓存返回 `null`（源 `undefined`）。 */
    fun getLocalGoal(): UserGoal? = currentGoal?.let { copyGoal(it) }

    /** 源 `GoalRepository.ets:27` `hasLocalGoal`。 */
    fun hasLocalGoal(): Boolean = currentGoal != null

    /** 源 `GoalRepository.ets:31` `clearLocal`。 */
    fun clearLocal() {
        currentGoal = null
    }

    /** 源 `GoalRepository.ets:35` `getLastPersistenceError`。 */
    fun getLastPersistenceError(): String = lastPersistenceError

    // --- 源 L39-L94：持久化（context → 注入 store） --------------------------

    /**
     * 源 `GoalRepository.ets:39` `saveGoal`：先写缓存，再把整块 JSON 落库；
     * 失败只置错误码 `save_goal_failed`，不抛出（对齐源 try/catch 吞异常）。
     */
    suspend fun saveGoal(store: JsonStore, goal: UserGoal) {
        saveLocalGoal(goal)
        lastPersistenceError = ""
        try {
            store.writeString(STORE_KEY, JsonCodec.json.encodeToString(copyGoal(goal)))
        } catch (error: Exception) {
            lastPersistenceError = "save_goal_failed"
        }
    }

    /**
     * 源 `GoalRepository.ets:51` `loadGoal`：**缓存优先**——缓存命中直接返回（不碰 store）；
     * 否则读库；空串 → `null`；JSON 解析失败 → `null`（源 catch 返回 `undefined`）。
     * 读库异常置错误码 `load_goal_failed` 并返回 `null`。
     */
    suspend fun loadGoal(store: JsonStore): UserGoal? {
        currentGoal?.let { return copyGoal(it) }

        lastPersistenceError = ""
        val value: String? = try {
            store.readString(STORE_KEY)
        } catch (error: Exception) {
            lastPersistenceError = "load_goal_failed"
            return null
        }
        if (value.isNullOrEmpty()) {
            return null
        }

        return try {
            val parsed: UserGoal = JsonCodec.json.decodeFromString(value)
            val goal: UserGoal = copyGoal(parsed)
            currentGoal = copyGoal(goal)
            goal
        } catch (error: Exception) {
            null
        }
    }

    /** 源 `GoalRepository.ets:79` `hasSavedGoal`——经 [loadGoal] 判定（会顺带填缓存）。 */
    suspend fun hasSavedGoal(store: JsonStore): Boolean = loadGoal(store) != null

    /**
     * 源 `GoalRepository.ets:84` `clearSavedGoal`：清缓存 + 删库键；
     * 失败置错误码 `clear_goal_failed`（对齐源）。
     */
    suspend fun clearSavedGoal(store: JsonStore) {
        clearLocal()
        lastPersistenceError = ""
        try {
            store.remove(STORE_KEY)
        } catch (error: Exception) {
            lastPersistenceError = "clear_goal_failed"
        }
    }

    // --- 源 L96-L116：深拷贝辅助 --------------------------------------------

    /** 源 `GoalRepository.ets:96` `copyGoal`——重建目标并深拷贝两个字符串数组。 */
    private fun copyGoal(source: UserGoal): UserGoal = source.copy(
        equipmentIds = copyStringArray(source.equipmentIds),
        restrictedMuscleIds = copyStringArray(source.restrictedMuscleIds),
    )

    /** 源 `GoalRepository.ets:110` `copyStringArray`——逐元素复制（Kotlin `List` 不可变，快照即可）。 */
    private fun copyStringArray(source: List<String>): List<String> = source.toList()
}

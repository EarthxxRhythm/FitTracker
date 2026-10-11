package com.fittracker.app.data.service

import com.fittracker.app.data.persist.JsonCodec
import com.fittracker.app.data.persist.JsonStore
import com.fittracker.app.data.persist.StoreNames
import kotlinx.serialization.Serializable
import kotlinx.serialization.decodeFromString
import kotlinx.serialization.encodeToString

/**
 * 进行中训练草稿〔draft〕持久化服务——逐字段移植自鸿蒙
 * `common/services/WorkoutDraftService.ets`（Function #40：进行中训练的持久化与重入恢复）。
 *
 * ## 与 [ActiveWorkoutService] 的职责边界
 * 鸿蒙把「进行中的一次训练」拆成了**两套模型、两个服务**：
 * - 本服务（`WorkoutDraftService`）持有**可持久化的快照** [WorkoutDraftSnapshot]——
 *   形状面向存储/恢复（扁平文本字段 + 每个动作内嵌 `sets`），不含 `isWarmup`，
 *   是崩溃/杀进程后重建 UI 的**唯一真源**；
 * - [ActiveWorkoutService] 持有**内存态计算引擎**（`ActiveWorkoutState`）——
 *   形状面向交互（`isWarmup`、`intensityNote`、实时 `completedSets` 重算），**不落盘**。
 * 两者对「动作/组」的表示高度重叠，但生命周期正交（一个落盘、一个在内存），
 * 故本安卓移植按源**保持双模型**，不做合并——合并会破坏「草稿可在无 UI 依赖下读写」的恢复契约。
 *
 * ## 持久化迁移（与源的**关键差异**）
 * 鸿蒙源为 `preferences`（`@kit.ArkData`）的 `STORE_NAME` + `KEY_WORKOUT_DRAFT` 两段式；
 * 安卓折叠为单个 [JsonStore] 键 [STORE_KEY]（= [StoreNames.ACTIVE_WORKOUT]，
 * 与源 `STORE_NAME` 同名）。[STORE_NAME] / [KEY_WORKOUT_DRAFT] 作为**对照常量**保留。
 * 方法签名由 `(context)` 升级为 `(store: JsonStore)` 注入——每次读写即落盘/读盘。
 *
 * 字段名与鸿蒙 JSON 输出**逐字一致**（camelCase），是备份互通与数据迁移的基石。
 *
 * ## 校验口径
 * 源的 `isValidWorkoutDraftSnapshot`（源 `:124`）做的是**运行期类型校验**（`isStringValue`
 * / `isFiniteNumberValue` / `isBooleanValue`）；Kotlin 侧这些由类型系统 + kotlinx 序列化
 * 保证，本移植**仅保留仍然有意义**的部分（`Double` 字段的有限性），见 [isValidWorkoutDraftSnapshot]。
 */

/** 单组草稿（源 `WorkoutDraftService.ets:8` `WorkoutSetDraft`）。注意：源草稿集**无** `isWarmup`。 */
@Serializable
data class WorkoutSetDraft(
    val setIndex: Int,
    val weightText: String,
    val repsText: String,
    val estimatedOneRepMax: Double,
    val oneRepMaxText: String,
    val isComplete: Boolean,
)

/** 单个动作草稿（源 `:17` `WorkoutExerciseDraft`）。 */
@Serializable
data class WorkoutExerciseDraft(
    val exerciseId: String,
    val name: String,
    val targetMuscle: String,
    val targetSets: Int,
    val targetReps: String,
    val completedSets: Int,
    val sets: List<WorkoutSetDraft>,
)

/** 进行中训练草稿快照（源 `:27` `WorkoutDraftSnapshot`）。 */
@Serializable
data class WorkoutDraftSnapshot(
    val planId: String,
    val planName: String,
    val dayLabel: String,
    val startedAt: Long,
    val totalTargetSets: Int,
    val completedSets: Int,
    val currentExerciseName: String,
    val currentExerciseProgress: String,
    val exercises: List<WorkoutExerciseDraft>,
    val updatedAt: Long,
)

/** 源 `:43` `copyWorkoutSetDraft`——逐字段重建单组草稿。 */
fun copyWorkoutSetDraft(source: WorkoutSetDraft): WorkoutSetDraft =
    WorkoutSetDraft(
        setIndex = source.setIndex,
        weightText = source.weightText,
        repsText = source.repsText,
        estimatedOneRepMax = source.estimatedOneRepMax,
        oneRepMaxText = source.oneRepMaxText,
        isComplete = source.isComplete,
    )

/** 源 `:55` `copyWorkoutExerciseDraft`——重建动作草稿并深拷贝其 `sets`。 */
fun copyWorkoutExerciseDraft(source: WorkoutExerciseDraft): WorkoutExerciseDraft =
    WorkoutExerciseDraft(
        exerciseId = source.exerciseId,
        name = source.name,
        targetMuscle = source.targetMuscle,
        targetSets = source.targetSets,
        targetReps = source.targetReps,
        completedSets = source.completedSets,
        sets = source.sets.map { copyWorkoutSetDraft(it) },
    )

/** 源 `:72` `copyWorkoutDraftSnapshot`——重建快照并深拷贝 `exercises`（含内层 `sets`）。 */
fun copyWorkoutDraftSnapshot(source: WorkoutDraftSnapshot): WorkoutDraftSnapshot =
    WorkoutDraftSnapshot(
        planId = source.planId,
        planName = source.planName,
        dayLabel = source.dayLabel,
        startedAt = source.startedAt,
        totalTargetSets = source.totalTargetSets,
        completedSets = source.completedSets,
        currentExerciseName = source.currentExerciseName,
        currentExerciseProgress = source.currentExerciseProgress,
        exercises = source.exercises.map { copyWorkoutExerciseDraft(it) },
        updatedAt = source.updatedAt,
    )

/**
 * 源 `:92` `hasWorkoutDraftProgress`——草稿是否有**值得恢复**的进度。
 *
 * 判定：`completedSets > 0`，或任一组的 `isComplete` / `weightText` / `repsText` 非空。
 */
fun hasWorkoutDraftProgress(source: WorkoutDraftSnapshot): Boolean {
    if (source.completedSets > 0) {
        return true
    }
    for (exercise in source.exercises) { // :96-104
        for (setDraft in exercise.sets) {
            if (setDraft.isComplete || setDraft.weightText.isNotEmpty() || setDraft.repsText.isNotEmpty()) {
                return true
            }
        }
    }
    return false
}

/** 源 `:108` `createEmptyWorkoutDraftSnapshot`——空快照（`currentExerciseProgress` 初值 `0/0`）。 */
fun createEmptyWorkoutDraftSnapshot(now: Long): WorkoutDraftSnapshot =
    WorkoutDraftSnapshot(
        planId = "",
        planName = "",
        dayLabel = "",
        startedAt = now,
        totalTargetSets = 0,
        completedSets = 0,
        currentExerciseName = "",
        currentExerciseProgress = "0/0",
        exercises = emptyList(),
        updatedAt = now,
    )

/**
 * 源 `:124` `isValidWorkoutDraftSnapshot`——结构合法性校验。
 *
 * Kotlin 侧字符串 / 布尔 / 列表结构由类型系统 + 序列化层保证（源 `:124` 的 `isStringValue`、
 * `:180` 的 `isBooleanValue`、`Array.isArray` 在 Kotlin 恒真），故此处只保留源中**仍然有意义**
 * 的数值有限性判定——`Double` 字段可为 `NaN`/`Infinity`；`Int`/`Long` 的有限性恒真，
 * 保留检查只为与源逐条对应。
 */
fun isValidWorkoutDraftSnapshot(source: WorkoutDraftSnapshot): Boolean {
    // 源 :125-126 number 校验（Long 恒有限，保留形状）
    if (!source.startedAt.toDouble().isFinite()) {
        return false
    }
    if (!source.totalTargetSets.toDouble().isFinite()) {
        return false
    }
    if (!source.completedSets.toDouble().isFinite()) {
        return false
    }
    if (!source.updatedAt.toDouble().isFinite()) {
        return false
    }
    // 源 :132 exercises 数组 → 逐项递归
    for (exercise in source.exercises) {
        if (!isValidWorkoutExerciseDraft(exercise)) {
            return false
        }
    }
    return true
}

/** 源 `:144` `isValidWorkoutExerciseDraft`——动作草稿递归校验。 */
private fun isValidWorkoutExerciseDraft(source: WorkoutExerciseDraft): Boolean {
    if (!source.targetSets.toDouble().isFinite()) { // 源 :149（Int 恒有限）
        return false
    }
    if (!source.completedSets.toDouble().isFinite()) { // 源 :150
        return false
    }
    for (setDraft in source.sets) { // 源 :154-158
        if (!isValidWorkoutSetDraft(setDraft)) {
            return false
        }
    }
    return true
}

/**
 * 源 `:160` `isValidWorkoutSetDraft`——单组草稿递归校验。
 * 唯一有意义项：`estimatedOneRepMax` 的有限性（`Double`）；其余类型的校验由类型系统承担。
 */
private fun isValidWorkoutSetDraft(source: WorkoutSetDraft): Boolean {
    if (!source.setIndex.toDouble().isFinite()) { // 源 :161（Int 恒有限）
        return false
    }
    if (!source.estimatedOneRepMax.isFinite()) { // 源 :163
        return false
    }
    return true
}

/**
 * 草稿持久化单例——方法名对齐源 `class WorkoutDraftService`（源 `:184`，default 导出单例）。
 */
object WorkoutDraftService {

    /** 鸿蒙源库名（源 `:40`）——安卓折叠为单键，仅作对照。 */
    const val STORE_NAME: String = "fit_tracker_active_workout"

    /** 鸿蒙源键名（源 `:41`）——同上，仅作对照。 */
    const val KEY_WORKOUT_DRAFT: String = "workout_draft"

    /** 实际 [JsonStore] 键——[StoreNames.ACTIVE_WORKOUT]（值同源 `STORE_NAME`）。 */
    const val STORE_KEY: String = StoreNames.ACTIVE_WORKOUT

    /**
     * 源 `:185` `saveDraft`——深拷贝后整块 JSON 写入。
     *
     * 源注释（`:190`）：持久化失败时**保持内存中的进行中训练可用**，故吞掉异常、不上抛。
     */
    suspend fun saveDraft(store: JsonStore, snapshot: WorkoutDraftSnapshot) {
        try {
            store.writeString(STORE_KEY, JsonCodec.json.encodeToString(copyWorkoutDraftSnapshot(snapshot)))
        } catch (error: Exception) {
            // 源 :189-192：留存内存中的进行中训练，持久化失败不影响可用性。
        }
    }

    /**
     * 源 `:195` `getDraft`——读回草稿；缺失 / 空串 / 解析失败一律返回 `null`。
     */
    suspend fun getDraft(store: JsonStore): WorkoutDraftSnapshot? {
        return try {
            val json: String = store.readString(STORE_KEY) ?: "" // 源 :196 `get(key, '')`
            parseDraft(json)
        } catch (error: Exception) {
            null
        }
    }

    /**
     * 源 `:205` `clearDraft`——**写入空串**（而非删键，源 `:207` `put(key, '')`）。
     *
     * 源注释（`:208-210`）：清空失败时保持原草稿不动，故吞掉异常。
     */
    suspend fun clearDraft(store: JsonStore) {
        try {
            store.writeString(STORE_KEY, "")
        } catch (error: Exception) {
            // 源 :208-210：清空失败不误伤已存草稿。
        }
    }

    /** 源 `:215` `parseDraft`——空串返回 `null`；反序列化 + 校验通过才返回深拷贝。 */
    private fun parseDraft(json: String): WorkoutDraftSnapshot? {
        if (json.isEmpty()) { // 源 :216
            return null
        }
        return try {
            val parsed: WorkoutDraftSnapshot = JsonCodec.json.decodeFromString(json)
            if (!isValidWorkoutDraftSnapshot(parsed)) {
                return null
            }
            copyWorkoutDraftSnapshot(parsed)
        } catch (error: Exception) {
            null
        }
    }
}

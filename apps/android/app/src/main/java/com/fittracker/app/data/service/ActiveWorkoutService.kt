package com.fittracker.app.data.service

import com.fittracker.app.data.model.WorkoutSession
import com.fittracker.app.data.model.WorkoutSet
import com.fittracker.app.data.model.estimateOneRepMax
import kotlinx.serialization.Serializable

/**
 * 活跃训练〔active workout〕状态引擎——逐方法移植自鸿蒙
 * `shared/services/ActiveWorkoutService.ets`（Feature #10：进行中训练的实时执行态）。
 *
 * ## 职责边界（与 [WorkoutDraftService] 的关系）
 * 本服务是**内存态计算引擎**——把「预览」编译成可交互的 [ActiveWorkoutState]、
 * 承接组录入（[updateSetEntry] / [updateSetWeight] / [updateSetReps] / [updateSetWarmup]
 * / [addSetEntry] / [updateExerciseCompletedSets]）、并在收尾时编译为持久化会话
 * [WorkoutSession]（[createCompletedSession]）。源 `ActiveWorkoutService.ets` **无持久化**
 * （不 import preferences），本移植**保持这一边界**：落盘由 [WorkoutDraftService] 负责，
 * 二者的动作/组模型刻意分叉（本侧有 `isWarmup`，草稿侧没有）。
 *
 * ## 关键口径
 * - `completedSets` **不是**输入值——每次拷贝动作时都按 `sets` 重新计算
 *   （[countCompleteWorkingSetEntries]：`isComplete && !isWarmup`），故录入组后计数自动跟随；
 * - 1RM：`Math.round(estimateOneRepMax(weight, reps))`（源 `:465`），与全项目唯一实现点
 *   [estimateOneRepMax]（两位小数）复用——**取整到整数**后落 `estimatedOneRepMax` 与
 *   `oneRepMaxText`（`参考 1RM {n} kg`，故用整数字符串而非 `Double.toString()`，对齐 JS 输出）；
 * - 热身组：`oneRepMaxText` 走专用文案，且**不计入** `completedSets` / 训练量。
 *
 * ## 输入契约（与源的差异）
 * 源 `createState` 消费 `WorkoutPreviewService`（Feature #9）的 `WorkoutPreviewSummary`——
 * 该服务**尚未移植**到本 Wave。为保持方法名与调用形态对齐源，本文件内定义**消费子集**
 * 输入契约 [WorkoutPreviewSummary] / [WorkoutPreviewExercise]（仅含 `ActiveWorkoutService`
 * 实际读取的字段）。待 `WorkoutPreviewService` 移植时应以之替换（字段为超集，可直接兼容）。
 */

/** 活跃训练单组录入项（源 `:29` `ActiveWorkoutSetEntry`）。 */
@Serializable
data class ActiveWorkoutSetEntry(
    val setIndex: Int,
    val weightText: String,
    val repsText: String,
    val estimatedOneRepMax: Double,
    val oneRepMaxText: String,
    val isWarmup: Boolean,
    val isComplete: Boolean,
)

/** 活跃训练单个动作（源 `:18` `ActiveWorkoutExercise`）。 */
@Serializable
data class ActiveWorkoutExercise(
    val plannedExerciseId: String,
    val exerciseId: String,
    val name: String,
    val targetSets: Int,
    val targetReps: String,
    val intensityNote: String,
    val completedSets: Int,
    val sets: List<ActiveWorkoutSetEntry>,
)

/** 活跃训练整体状态（源 `:39` `ActiveWorkoutState`）。 */
@Serializable
data class ActiveWorkoutState(
    val hasWorkout: Boolean,
    val planId: String,
    val dayId: String,
    val title: String,
    val totalTargetSets: Int,
    val completedSets: Int,
    val currentExerciseName: String,
    val currentExerciseSetProgress: String,
    val exercises: List<ActiveWorkoutExercise>,
)

/** 预览动作输入契约——`WorkoutPreviewService` 的消费子集（源 `WorkoutPreviewExercise`）。 */
@Serializable
data class WorkoutPreviewExercise(
    val plannedExerciseId: String,
    val exerciseId: String,
    val name: String,
    val targetSets: Int,
    val targetReps: String,
    val intensityNote: String,
)

/** 预览摘要输入契约——`WorkoutPreviewService` 的消费子集（源 `WorkoutPreviewSummary`）。 */
@Serializable
data class WorkoutPreviewSummary(
    val hasWorkout: Boolean,
    val planId: String,
    val dayId: String,
    val title: String,
    val exercises: List<WorkoutPreviewExercise>,
)

/**
 * 活跃训练服务单例——方法名对齐源 `class ActiveWorkoutService`（源 `:51`，default 导出单例）。
 */
object ActiveWorkoutService {

    // --- 构建 / 转移 ---------------------------------------------------------

    /** 源 `:52` `createState`——由预览摘要编译初始状态；`completedSets`/当前动作由 `exercises` 推导。 */
    fun createState(preview: WorkoutPreviewSummary): ActiveWorkoutState {
        val exercises: MutableList<ActiveWorkoutExercise> = mutableListOf()
        var totalTargetSets: Int = 0

        for (previewExercise in preview.exercises) { // :53-60
            totalTargetSets += previewExercise.targetSets
            exercises.add(createActiveExercise(previewExercise))
        }

        return ActiveWorkoutState( // :62-74
            hasWorkout = preview.hasWorkout && exercises.isNotEmpty(),
            planId = preview.planId,
            dayId = preview.dayId,
            title = preview.title,
            totalTargetSets = totalTargetSets,
            completedSets = countCompletedSets(exercises),
            currentExerciseName = findCurrentExerciseName(exercises),
            currentExerciseSetProgress = createCurrentExerciseSetProgress(exercises),
            exercises = exercises,
        )
    }

    /**
     * 源 `:76` `createStateWithProgress`——以新的 `exercises` 重算聚合字段（深拷贝输入）。
     * 保留 `hasWorkout`/`planId`/`dayId`/`title`/`totalTargetSets` 不变（源 `:81-93`）。
     */
    fun createStateWithProgress(
        state: ActiveWorkoutState,
        exercises: List<ActiveWorkoutExercise>,
    ): ActiveWorkoutState {
        val nextExercises: List<ActiveWorkoutExercise> = copyActiveExercises(exercises) // :80
        return ActiveWorkoutState( // :81-93
            hasWorkout = state.hasWorkout,
            planId = state.planId,
            dayId = state.dayId,
            title = state.title,
            totalTargetSets = state.totalTargetSets,
            completedSets = countCompletedSets(nextExercises),
            currentExerciseName = findCurrentExerciseName(nextExercises),
            currentExerciseSetProgress = createCurrentExerciseSetProgress(nextExercises),
            exercises = nextExercises,
        )
    }

    /**
     * 源 `:95` `createCompletedSession`——把活跃态编译为持久化 [WorkoutSession]。
     *
     * 口径（逐条对齐源 `:102-117`）：
     * - `totalSets` 用**实算** [countCompletedSets]（忽略入参，源即如此——入参 `completedSets`
     *   为遗留形参，保留以对齐签名）；
     * - 会话仅收录 `isComplete` 的组（[createWorkoutSets]），热身组计入 `sets` 但不计入 `totalVolume`；
     * - `notes` = `completed_sets={n};target_sets={m}`（回顾解析依赖此前缀）。
     *
     * 会话构造复用 [WorkoutRepository.createSession]（对应源 `TrainingModels.createWorkoutSession`）。
     */
    fun createCompletedSession(
        sessionId: String,
        state: ActiveWorkoutState,
        startedAt: Long,
        endedAt: Long,
        completedSets: Int, // 源遗留形参，未使用——保留以对齐签名
    ): WorkoutSession {
        val sets: List<WorkoutSet> = createWorkoutSets(state.exercises) // :102
        val actualCompletedSets: Int = countCompletedSets(state.exercises) // :103
        return WorkoutRepository.createSession( // :104-117
            sessionId = sessionId,
            planId = state.planId,
            dayId = state.dayId,
            startedAt = startedAt,
            endedAt = endedAt,
            durationSeconds = calculateDurationSeconds(startedAt, endedAt),
            totalSets = actualCompletedSets,
            totalVolume = calculateTotalVolume(sets),
            fatigueScore = 0.0,
            notes = createSessionNotes(actualCompletedSets, state.totalTargetSets),
            sets = sets,
        )
    }

    // --- 计数 ---------------------------------------------------------------

    /** 源 `:120` `countCompletedSets`——所有动作**有效工作组**（`isComplete && !isWarmup`）之和。 */
    fun countCompletedSets(exercises: List<ActiveWorkoutExercise>): Int {
        var completedSets: Int = 0
        for (exercise in exercises) { // :121-126
            completedSets += countCompleteWorkingSetEntries(exercise.sets)
        }
        return completedSets
    }

    /** 源 `:128` `countRecordedSets`——所有**已记录组**（`isComplete`，含热身组）之和。 */
    fun countRecordedSets(exercises: List<ActiveWorkoutExercise>): Int {
        var recordedSets: Int = 0
        for (exercise in exercises) { // :129-134
            recordedSets += countCompleteRecordedSetEntries(exercise.sets)
        }
        return recordedSets
    }

    // --- 组编辑（返回新列表，不改入参） ---------------------------------------

    /**
     * 源 `:136` `updateExerciseCompletedSets`——把指定动作的 `completedSets` 钳制到 `0..targetSets`。
     * 注意其余动作的 `completedSets` 会被[重算][copyActiveExerciseWithCompletedSets]，非原样保留。
     */
    fun updateExerciseCompletedSets(
        exercises: List<ActiveWorkoutExercise>,
        plannedExerciseId: String,
        completedSets: Int,
    ): List<ActiveWorkoutExercise> {
        val values: MutableList<ActiveWorkoutExercise> = mutableListOf()
        for (exercise in exercises) { // :137-149
            var nextCompletedSets: Int = exercise.completedSets
            if (exercise.plannedExerciseId == plannedExerciseId) {
                nextCompletedSets = clampCompletedSets(completedSets, exercise.targetSets)
            }
            values.add(copyActiveExerciseWithCompletedSets(exercise, nextCompletedSets))
        }
        return values
    }

    /**
     * 源 `:153` `updateSetEntry`——向指定动作的指定 `setIndex` 写入重量/次数文本，
     * 命中动作的 `completedSets` 随之重算。
     */
    fun updateSetEntry(
        exercises: List<ActiveWorkoutExercise>,
        plannedExerciseId: String,
        setIndex: Int,
        weightText: String,
        repsText: String,
    ): List<ActiveWorkoutExercise> {
        val values: MutableList<ActiveWorkoutExercise> = mutableListOf()
        for (exercise in exercises) { // :154-168
            if (exercise.plannedExerciseId == plannedExerciseId) {
                values.add(copyActiveExerciseWithSetEntry(exercise, setIndex, weightText, repsText))
            } else {
                values.add(copyActiveExercise(exercise))
            }
        }
        return values
    }

    /** 源 `:172` `updateSetWeight`——只改重量；次数沿用当前值。 */
    fun updateSetWeight(
        exercises: List<ActiveWorkoutExercise>,
        plannedExerciseId: String,
        setIndex: Int,
        weightText: String,
    ): List<ActiveWorkoutExercise> {
        val repsText: String = findSetRepsText(exercises, plannedExerciseId, setIndex) // :176
        return updateSetEntry(exercises, plannedExerciseId, setIndex, weightText, repsText)
    }

    /** 源 `:182` `updateSetReps`——只改次数；重量沿用当前值。 */
    fun updateSetReps(
        exercises: List<ActiveWorkoutExercise>,
        plannedExerciseId: String,
        setIndex: Int,
        repsText: String,
    ): List<ActiveWorkoutExercise> {
        val weightText: String = findSetWeightText(exercises, plannedExerciseId, setIndex) // :186
        return updateSetEntry(exercises, plannedExerciseId, setIndex, weightText, repsText)
    }

    /** 源 `:192` `updateSetWarmup`——切换指定组的 `isWarmup`；命中动作计数随之重算。 */
    fun updateSetWarmup(
        exercises: List<ActiveWorkoutExercise>,
        plannedExerciseId: String,
        setIndex: Int,
        isWarmup: Boolean,
    ): List<ActiveWorkoutExercise> {
        val values: MutableList<ActiveWorkoutExercise> = mutableListOf()
        for (exercise in exercises) { // :193-208
            if (exercise.plannedExerciseId == plannedExerciseId) {
                values.add(copyActiveExerciseWithWarmupState(exercise, setIndex, isWarmup))
            } else {
                values.add(copyActiveExercise(exercise))
            }
        }
        return values
    }

    /** 源 `:210` `addSetEntry`——为指定动作追加一个空组（`setIndex` 取最大 + 1）。 */
    fun addSetEntry(exercises: List<ActiveWorkoutExercise>, plannedExerciseId: String): List<ActiveWorkoutExercise> {
        val values: MutableList<ActiveWorkoutExercise> = mutableListOf()
        for (exercise in exercises) { // :211-221
            if (exercise.plannedExerciseId == plannedExerciseId) {
                values.add(copyActiveExerciseWithAdditionalSet(exercise))
            } else {
                values.add(copyActiveExercise(exercise))
            }
        }
        return values
    }

    /** 源 `:223` `markAllComplete`——源实现仅深拷贝（未置位，占位语义），本处逐行复刻。 */
    fun markAllComplete(exercises: List<ActiveWorkoutExercise>): List<ActiveWorkoutExercise> =
        copyActiveExercises(exercises) // :224

    // --- 内部：动作拷贝 ------------------------------------------------------

    /** 源 `:227` `copyActiveExercises`——逐动作深拷贝。 */
    private fun copyActiveExercises(source: List<ActiveWorkoutExercise>): List<ActiveWorkoutExercise> =
        source.map { copyActiveExercise(it) }

    /** 源 `:266` `createActiveExercise`——由预览动作编译初始动作（`completedSets=0`，按 `targetSets` 建空组）。 */
    private fun createActiveExercise(previewExercise: WorkoutPreviewExercise): ActiveWorkoutExercise =
        ActiveWorkoutExercise(
            plannedExerciseId = previewExercise.plannedExerciseId,
            exerciseId = previewExercise.exerciseId,
            name = previewExercise.name,
            targetSets = previewExercise.targetSets,
            targetReps = previewExercise.targetReps,
            intensityNote = previewExercise.intensityNote,
            completedSets = 0,
            sets = createSetEntries(previewExercise.targetSets),
        )

    /** 源 `:280` `copyActiveExercise`——深拷贝并把 `completedSets` 重算为有效工作组数。 */
    private fun copyActiveExercise(exercise: ActiveWorkoutExercise): ActiveWorkoutExercise =
        ActiveWorkoutExercise(
            plannedExerciseId = exercise.plannedExerciseId,
            exerciseId = exercise.exerciseId,
            name = exercise.name,
            targetSets = exercise.targetSets,
            targetReps = exercise.targetReps,
            intensityNote = exercise.intensityNote,
            completedSets = countCompleteWorkingSetEntries(exercise.sets),
            sets = copySetEntries(exercise.sets),
        )

    /** 源 `:294` `copyActiveExerciseWithCompletedSets`——深拷贝并落**指定** `completedSets`。 */
    private fun copyActiveExerciseWithCompletedSets(
        exercise: ActiveWorkoutExercise,
        completedSets: Int,
    ): ActiveWorkoutExercise = ActiveWorkoutExercise(
        plannedExerciseId = exercise.plannedExerciseId,
        exerciseId = exercise.exerciseId,
        name = exercise.name,
        targetSets = exercise.targetSets,
        targetReps = exercise.targetReps,
        intensityNote = exercise.intensityNote,
        completedSets = completedSets,
        sets = copySetEntries(exercise.sets),
    )

    /** 源 `:311` `copyActiveExerciseWithSetEntry`——替换命中组文本，重算 `completedSets`。 */
    private fun copyActiveExerciseWithSetEntry(
        exercise: ActiveWorkoutExercise,
        setIndex: Int,
        weightText: String,
        repsText: String,
    ): ActiveWorkoutExercise {
        val sets: MutableList<ActiveWorkoutSetEntry> = mutableListOf()
        for (entry in exercise.sets) { // :316-324
            if (entry.setIndex == setIndex) {
                sets.add(createSetEntry(setIndex, weightText, repsText, entry.isWarmup))
            } else {
                sets.add(copySetEntry(entry))
            }
        }
        return ActiveWorkoutExercise(
            plannedExerciseId = exercise.plannedExerciseId,
            exerciseId = exercise.exerciseId,
            name = exercise.name,
            targetSets = exercise.targetSets,
            targetReps = exercise.targetReps,
            intensityNote = exercise.intensityNote,
            completedSets = countCompleteWorkingSetEntries(sets),
            sets = sets,
        )
    }

    /** 源 `:340` `copyActiveExerciseWithWarmupState`——替换命中组的热身态，重算 `completedSets`。 */
    private fun copyActiveExerciseWithWarmupState(
        exercise: ActiveWorkoutExercise,
        setIndex: Int,
        isWarmup: Boolean,
    ): ActiveWorkoutExercise {
        val sets: MutableList<ActiveWorkoutSetEntry> = mutableListOf()
        for (entry in exercise.sets) { // :345-353
            if (entry.setIndex == setIndex) {
                sets.add(createSetEntry(entry.setIndex, entry.weightText, entry.repsText, isWarmup))
            } else {
                sets.add(copySetEntry(entry))
            }
        }
        return ActiveWorkoutExercise(
            plannedExerciseId = exercise.plannedExerciseId,
            exerciseId = exercise.exerciseId,
            name = exercise.name,
            targetSets = exercise.targetSets,
            targetReps = exercise.targetReps,
            intensityNote = exercise.intensityNote,
            completedSets = countCompleteWorkingSetEntries(sets),
            sets = sets,
        )
    }

    /** 源 `:368` `copyActiveExerciseWithAdditionalSet`——追加一个空组（`getNextSetIndex` 定位）。 */
    private fun copyActiveExerciseWithAdditionalSet(exercise: ActiveWorkoutExercise): ActiveWorkoutExercise {
        val sets: MutableList<ActiveWorkoutSetEntry> = copySetEntries(exercise.sets).toMutableList() // :369
        sets.add(createSetEntry(getNextSetIndex(sets), "", "", false)) // :370
        return ActiveWorkoutExercise(
            plannedExerciseId = exercise.plannedExerciseId,
            exerciseId = exercise.exerciseId,
            name = exercise.name,
            targetSets = exercise.targetSets,
            targetReps = exercise.targetReps,
            intensityNote = exercise.intensityNote,
            completedSets = countCompleteWorkingSetEntries(sets),
            sets = sets,
        )
    }

    // --- 内部：当前动作推导 --------------------------------------------------

    /** 源 `:236` `findCurrentExerciseName`——当前动作名（无则空串，源 `undefined`）。 */
    private fun findCurrentExerciseName(exercises: List<ActiveWorkoutExercise>): String =
        findCurrentExercise(exercises)?.name ?: "" // :237-242

    /** 源 `:244` `createCurrentExerciseSetProgress`——`{completed}/{target} 正式组`（无则 `0/0 正式组`）。 */
    private fun createCurrentExerciseSetProgress(exercises: List<ActiveWorkoutExercise>): String {
        val exercise: ActiveWorkoutExercise? = findCurrentExercise(exercises) // :245
        if (exercise == null) { // :246-248
            return "0/0 正式组"
        }
        return "${exercise.completedSets}/${exercise.targetSets} 正式组" // :249
    }

    /** 源 `:252` `findCurrentExercise`——首个未完成动作；全部完成则取末个；空列表返回 `null`。 */
    private fun findCurrentExercise(exercises: List<ActiveWorkoutExercise>): ActiveWorkoutExercise? {
        for (exercise in exercises) { // :253-258
            if (exercise.completedSets < exercise.targetSets) {
                return exercise
            }
        }
        if (exercises.isEmpty()) { // :260-262
            return null
        }
        return exercises.last() // :263
    }

    // --- 内部：组查询 --------------------------------------------------------

    /** 源 `:384` `findSetWeightText`——指定组的重量文本（未命中空串）。 */
    private fun findSetWeightText(
        exercises: List<ActiveWorkoutExercise>,
        plannedExerciseId: String,
        setIndex: Int,
    ): String = findSetEntry(exercises, plannedExerciseId, setIndex)?.weightText ?: "" // :388-391

    /** 源 `:396` `findSetRepsText`——指定组的次数文本（未命中空串）。 */
    private fun findSetRepsText(
        exercises: List<ActiveWorkoutExercise>,
        plannedExerciseId: String,
        setIndex: Int,
    ): String = findSetEntry(exercises, plannedExerciseId, setIndex)?.repsText ?: "" // :400-403

    /** 源 `:408` `findSetEntry`——按 `(plannedExerciseId, setIndex)` 查找组（未命中 `null`）。 */
    private fun findSetEntry(
        exercises: List<ActiveWorkoutExercise>,
        plannedExerciseId: String,
        setIndex: Int,
    ): ActiveWorkoutSetEntry? {
        for (exercise in exercises) { // :413-424
            if (exercise.plannedExerciseId != plannedExerciseId) {
                continue
            }
            for (entry in exercise.sets) {
                if (entry.setIndex == setIndex) {
                    return entry
                }
            }
        }
        return null
    }

    // --- 内部：组构造/拷贝 ---------------------------------------------------

    /** 源 `:428` `createSetEntries`——按 `targetSets` 建 `[0, targetSets)` 空组。 */
    private fun createSetEntries(targetSets: Int): List<ActiveWorkoutSetEntry> =
        (0 until targetSets).map { createSetEntry(it, "", "", false) } // :429-434

    /** 源 `:436` `copySetEntries`——逐组深拷贝。 */
    private fun copySetEntries(source: List<ActiveWorkoutSetEntry>): List<ActiveWorkoutSetEntry> =
        source.map { copySetEntry(it) }

    /** 源 `:444` `copySetEntry`——逐字段重建单组。 */
    private fun copySetEntry(entry: ActiveWorkoutSetEntry): ActiveWorkoutSetEntry =
        ActiveWorkoutSetEntry(
            setIndex = entry.setIndex,
            weightText = entry.weightText,
            repsText = entry.repsText,
            estimatedOneRepMax = entry.estimatedOneRepMax,
            oneRepMaxText = entry.oneRepMaxText,
            isWarmup = entry.isWarmup,
            isComplete = entry.isComplete,
        )

    /**
     * 源 `:457` `createSetEntry`——由文本构造组：`weight>0 且 reps>0` 视为已记录（`isComplete`），
     * 并算 1RM（`Math.round`，源 `:465`）。
     *
     * 文本解析口径：源 `Number(text)`（`''`→0、非法→NaN，两者都落 `>0` 为假）；
     * Kotlin 用 [String.toDoubleOrNull]（非法/空 → `null`，同判为无效），结果等价。
     * 次数取整差异：源把 `reps` 原样传入 `estimateOneRepMax`（可为小数），本移植按 [Int]
     * 截断（[estimateOneRepMax] 的签名即 `Int`）——用户录入的「次数」实践恒为整数，差异不影响输出。
     */
    private fun createSetEntry(
        setIndex: Int,
        weightText: String,
        repsText: String,
        isWarmup: Boolean,
    ): ActiveWorkoutSetEntry {
        val weight: Double? = weightText.toDoubleOrNull()
        val reps: Double? = repsText.toDoubleOrNull()
        var estimatedOneRepMax: Double = 0.0
        var oneRepMaxText: String = if (isWarmup) "热身组不参与 PR 与训练量" else "录入重量和次数后显示 1RM" // :459-460
        var isComplete: Boolean = false

        if (weight != null && reps != null && weight > 0 && reps > 0) { // :462
            val rounded: Long = Math.round(estimateOneRepMax(weight, reps.toInt())) // :465
            estimatedOneRepMax = rounded.toDouble()
            oneRepMaxText = if (isWarmup) {
                "热身组已记录，不参与 PR 与训练量"
            } else {
                "参考 1RM $rounded kg" // :469（整数文本，对齐 JS number→string）
            }
            isComplete = true // :472
        }

        return ActiveWorkoutSetEntry( // :475-484
            setIndex = setIndex,
            weightText = weightText,
            repsText = repsText,
            estimatedOneRepMax = estimatedOneRepMax,
            oneRepMaxText = oneRepMaxText,
            isWarmup = isWarmup,
            isComplete = isComplete,
        )
    }

    // --- 内部：计数/工具 -----------------------------------------------------

    /** 源 `:486` `countCompleteWorkingSetEntries`——`isComplete && !isWarmup` 计数。 */
    private fun countCompleteWorkingSetEntries(sets: List<ActiveWorkoutSetEntry>): Int {
        var count: Int = 0
        for (entry in sets) { // :487-493
            if (entry.isComplete && !entry.isWarmup) {
                count++
            }
        }
        return count
    }

    /** 源 `:496` `countCompleteRecordedSetEntries`——`isComplete` 计数（含热身组）。 */
    private fun countCompleteRecordedSetEntries(sets: List<ActiveWorkoutSetEntry>): Int {
        var count: Int = 0
        for (entry in sets) { // :497-503
            if (entry.isComplete) {
                count++
            }
        }
        return count
    }

    /** 源 `:506` `getNextSetIndex`——下一个可用 `setIndex`（默认 `size`，否则最大 + 1）。 */
    private fun getNextSetIndex(sets: List<ActiveWorkoutSetEntry>): Int {
        var nextSetIndex: Int = sets.size // :507
        for (entry in sets) { // :508-512
            if (entry.setIndex >= nextSetIndex) {
                nextSetIndex = entry.setIndex + 1
            }
        }
        return nextSetIndex
    }

    /** 源 `:516` `createWorkoutSets`——收集所有 `isComplete` 的组为持久化 [WorkoutSet]。 */
    private fun createWorkoutSets(exercises: List<ActiveWorkoutExercise>): List<WorkoutSet> {
        val values: MutableList<WorkoutSet> = mutableListOf()
        for (exercise in exercises) { // :517-526
            for (setEntry in exercise.sets) {
                if (setEntry.isComplete) {
                    values.add(createWorkoutSetFromEntry(exercise, setEntry))
                }
            }
        }
        return values
    }

    /** 源 `:530` `createWorkoutSetFromEntry`——单组组记录：`reps` 取 `floor`（源 `:539`）。 */
    private fun createWorkoutSetFromEntry(
        exercise: ActiveWorkoutExercise,
        setEntry: ActiveWorkoutSetEntry,
    ): WorkoutSet = WorkoutSet( // :534 源 `createWorkoutSet(...)`
        setId = "${exercise.plannedExerciseId}_set_${setEntry.setIndex + 1}",
        exerciseId = exercise.exerciseId,
        weight = parsePositiveNumber(setEntry.weightText),
        reps = parsePositiveNumber(setEntry.repsText).toInt(), // :539 源 `Math.floor`（正数截断即 floor）
        rpe = 0.0,
        isWarmup = setEntry.isWarmup,
    )

    /** 源 `:544` `calculateTotalVolume`——非热身组的 `weight × reps` 之和，两位小数（源 `:551`）。 */
    private fun calculateTotalVolume(sets: List<WorkoutSet>): Double {
        var totalVolume: Double = 0.0
        for (set in sets) { // :545-550
            if (!set.isWarmup) {
                totalVolume += set.weight * set.reps
            }
        }
        return Math.round(totalVolume * 100) / 100.0 // :551
    }

    /** 源 `:555` `parsePositiveNumber`——解析正数，非法或 `<=0` 一律 0。 */
    private fun parsePositiveNumber(value: String): Double {
        val parsed: Double = value.toDoubleOrNull() ?: return 0.0 // :556-560
        if (parsed <= 0) {
            return 0.0
        }
        return parsed
    }

    /** 源 `:563` `clampCompletedSets`——钳制到 `0..targetSets`。 */
    private fun clampCompletedSets(completedSets: Int, targetSets: Int): Int {
        if (completedSets < 0) { // :564-566
            return 0
        }
        if (completedSets > targetSets) { // :567-569
            return targetSets
        }
        return completedSets
    }

    /** 源 `:573` `calculateDurationSeconds`——`endedAt <= startedAt` 时为 0，否则向下取整秒。 */
    private fun calculateDurationSeconds(startedAt: Long, endedAt: Long): Int {
        if (endedAt <= startedAt) { // :574-576
            return 0
        }
        return ((endedAt - startedAt) / 1000).toInt() // :577 源 `Math.floor(.../1000)`
    }

    /** 源 `:580` `createSessionNotes`——`completed_sets={n};target_sets={m}`。 */
    private fun createSessionNotes(completedSets: Int, totalTargetSets: Int): String =
        "completed_sets=$completedSets;target_sets=$totalTargetSets" // :581
}

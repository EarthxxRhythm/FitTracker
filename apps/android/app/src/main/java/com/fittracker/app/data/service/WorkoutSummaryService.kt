package com.fittracker.app.data.service

import com.fittracker.app.data.model.WorkoutSession
import com.fittracker.app.data.model.WorkoutSet
import com.fittracker.app.data.model.estimateOneRepMax
import com.fittracker.app.data.service.stats.ReviewService
import java.util.Calendar
import kotlin.math.floor
import kotlin.math.roundToInt

private const val COMPLETED_SETS_PREFIX = "completed_sets="
private const val TARGET_SETS_PREFIX = "target_sets="

/**
 * 训练摘要里的单动作最佳记录
 * （源 `WorkoutSummaryService.ets:28` `WorkoutSummaryExerciseRecord`）。
 *
 * `bestOneRepMax` 源为 `Math.round(estimateOneRepMax(...))` 的整数值（`set:161`），故用 `Int`。
 */
data class WorkoutSummaryExerciseRecord(
    val exerciseId: String,
    val exerciseName: String,
    val bestOneRepMax: Int,
    val bestWeight: Double,
    val bestReps: Int,
    val dateText: String,
)

/** 训练后回顾摘要（源 `WorkoutSummaryService.ets:13` `WorkoutSummary`）。 */
data class WorkoutSummary(
    val hasSession: Boolean,
    val sessionId: String,
    val planId: String,
    val dayId: String,
    val durationSeconds: Int,
    val durationText: String,
    val completedSets: Int,
    val targetSets: Int,
    val completionRate: Int,
    val totalVolume: Double,
    val fatigueScore: Double,
    val exerciseRecords: List<WorkoutSummaryExerciseRecord>,
)

/**
 * 训练摘要服务——逐函数移植自鸿蒙 `shared/services/WorkoutSummaryService.ets`。
 *
 * Feature #11（训练摘要回顾）。无状态单例：完成率/训练量统一走 `ReviewService`
 * （源 `:49` / `:56` 复用 `ReviewService.calculateCompletionRate` / `calculateVolume`），
 * 单动作最佳 1RM 复用 `TrainingModels.kt` 的唯一实现点 `estimateOneRepMax`。
 *
 * `completed_sets=` / `target_sets=` 的 notes 解析口径与 `ReviewDashboardService`
 * 略有差异（本服务 `getNumberAfterPrefix` 无 fallback 参数、恒以 0 兜底；`getTargetSets`
 * 再按 `> 0` 判断回落），逐字对齐源 `:240` / `:113`，不做「统一化」。
 */
object WorkoutSummaryService {

    /** 源 `createSummary`（`WorkoutSummaryService.ets:38`）。单会话，历史 = 自身。 */
    fun createSummary(session: WorkoutSession): WorkoutSummary =
        createSummaryWithHistory(session, listOf(session))

    /** 源 `createSummaryWithHistory`（`WorkoutSummaryService.ets:43`）。 */
    fun createSummaryWithHistory(
        session: WorkoutSession,
        sessions: List<WorkoutSession>,
    ): WorkoutSummary {
        val completedSets = getCompletedSets(session)
        val targetSets = getTargetSets(session.notes, completedSets)
        return WorkoutSummary(
            hasSession = true,
            sessionId = session.sessionId,
            planId = session.planId,
            dayId = session.dayId,
            durationSeconds = session.durationSeconds,
            durationText = formatDuration(session.durationSeconds),
            completedSets = completedSets,
            targetSets = targetSets,
            completionRate = ReviewService.calculateCompletionRate(completedSets, targetSets),
            totalVolume = getTotalVolume(session),
            fatigueScore = session.fatigueScore,
            exerciseRecords = createExerciseRecords(session, sessions),
        )
    }

    /** 源 `createEmptySummary`（`WorkoutSummaryService.ets:63`）。 */
    fun createEmptySummary(): WorkoutSummary = WorkoutSummary(
        hasSession = false,
        sessionId = "",
        planId = "",
        dayId = "",
        durationSeconds = 0,
        durationText = "0 分钟",
        completedSets = 0,
        targetSets = 0,
        completionRate = 0,
        totalVolume = 0.0,
        fatigueScore = 0.0,
        exerciseRecords = emptyList(),
    )

    /**
     * 源 `formatDuration`（`WorkoutSummaryService.ets:81`）。
     *
     * `<= 0 → 「0 分钟」`；不足 1 分钟 → 「1 分钟内」；否则「H 小时 M 分钟 / H 小时 / M 分钟」。
     * 供 `ReviewInsightsService` 复用（源 `ReviewInsightsService.ets` 多处调用）。
     */
    fun formatDuration(durationSeconds: Int): String {
        if (durationSeconds <= 0) {
            return "0 分钟"
        }
        val minutes = durationSeconds / 60
        if (minutes <= 0) {
            return "1 分钟内"
        }
        val hours = minutes / 60
        val restMinutes = minutes % 60
        if (hours > 0 && restMinutes > 0) {
            return "$hours 小时 $restMinutes 分钟"
        }
        if (hours > 0) {
            return "$hours 小时"
        }
        return "$minutes 分钟"
    }

    /** 源 `getCompletedSets`（`WorkoutSummaryService.ets:102`）。sets 有值按组统计，否则解析 notes。 */
    private fun getCompletedSets(session: WorkoutSession): Int {
        if (session.sets.isNotEmpty()) {
            return countCompletedSets(session.sets)
        }
        val parsed = getNumberAfterPrefix(session.notes, COMPLETED_SETS_PREFIX)
        if (parsed > 0) {
            return parsed
        }
        return 0
    }

    /** 源 `getTargetSets`（`WorkoutSummaryService.ets:113`）。解析成功且 `> 0` 才采用，否则回落。 */
    private fun getTargetSets(notes: String, fallbackTargetSets: Int): Int {
        val parsed = getNumberAfterPrefix(notes, TARGET_SETS_PREFIX)
        if (parsed > 0) {
            return parsed
        }
        return fallbackTargetSets
    }

    /** 源 `getTotalVolume`（`WorkoutSummaryService.ets:121`）。优先 sets 现算，回落到 `session.totalVolume`。 */
    private fun getTotalVolume(session: WorkoutSession): Double {
        if (session.sets.isNotEmpty()) {
            return ReviewService.calculateVolume(session.sets)
        }
        if (session.totalVolume > 0) {
            return session.totalVolume
        }
        return ReviewService.calculateVolume(session.sets)
    }

    /** 源 `countCompletedSets`（`WorkoutSummaryService.ets:131`）。非热身、重量/次数均 > 0 的组计数。 */
    private fun countCompletedSets(sets: List<WorkoutSet>): Int {
        var count = 0
        for (set in sets) {
            if (set.weight > 0 && set.reps > 0 && !set.isWarmup) {
                count++
            }
        }
        return count
    }

    /**
     * 源 `createExerciseRecords`（`WorkoutSummaryService.ets:141`）。
     *
     * 只对当前会话出现过的动作建记录；每条记录在完整历史（含当前会话）上取最佳。
     * 源在原位修改 `record`，此处 data class 不可变，改为 `copy` 回链（语义等价）。
     */
    private fun createExerciseRecords(
        currentSession: WorkoutSession,
        sessions: List<WorkoutSession>,
    ): List<WorkoutSummaryExerciseRecord> {
        val currentExerciseIds = getUniqueExerciseIds(currentSession.sets)
        val records = ArrayList<WorkoutSummaryExerciseRecord>(currentExerciseIds.size)
        for (exerciseId in currentExerciseIds) {
            var record = createEmptyExerciseRecord(exerciseId)
            for (session in sessions) {
                record = updateExerciseRecord(record, session)
            }
            records.add(record)
        }
        return records
    }

    /** 源 `updateExerciseRecord`（`WorkoutSummaryService.ets:155`）。同动作、非热身、重量/次数均 > 0 才参与。 */
    private fun updateExerciseRecord(
        record: WorkoutSummaryExerciseRecord,
        session: WorkoutSession,
    ): WorkoutSummaryExerciseRecord {
        var current = record
        for (set in session.sets) {
            if (set.exerciseId != current.exerciseId || set.isWarmup || set.weight <= 0 || set.reps <= 0) {
                continue
            }
            val oneRepMax = estimateOneRepMax(set.weight, set.reps).roundToInt()
            if (isBetterExerciseRecord(current, oneRepMax, session.startedAt)) {
                current = current.copy(
                    bestOneRepMax = oneRepMax,
                    bestWeight = set.weight,
                    bestReps = set.reps,
                    dateText = formatDate(session.startedAt),
                )
            }
        }
        return current
    }

    /**
     * 源 `isBetterExerciseRecord`（`WorkoutSummaryService.ets:171`）。
     * 1RM 更大者胜；相等时取日期更晚者（`dateText` 为 `YYYY-MM-DD`，字典序即时间序）。
     */
    private fun isBetterExerciseRecord(
        record: WorkoutSummaryExerciseRecord,
        oneRepMax: Int,
        startedAt: Long,
    ): Boolean {
        if (oneRepMax > record.bestOneRepMax) {
            return true
        }
        if (oneRepMax < record.bestOneRepMax) {
            return false
        }
        if (record.dateText.isEmpty()) {
            return true
        }
        val dateText = formatDate(startedAt)
        return dateText >= record.dateText
    }

    /** 源 `createEmptyExerciseRecord`（`WorkoutSummaryService.ets:185`）。 */
    private fun createEmptyExerciseRecord(exerciseId: String): WorkoutSummaryExerciseRecord =
        WorkoutSummaryExerciseRecord(
            exerciseId = exerciseId,
            exerciseName = getExerciseName(exerciseId),
            bestOneRepMax = 0,
            bestWeight = 0.0,
            bestReps = 0,
            dateText = "",
        )

    /** 源 `getUniqueExerciseIds`（`WorkoutSummaryService.ets:197`）。保序去重。 */
    private fun getUniqueExerciseIds(sets: List<WorkoutSet>): List<String> {
        val exerciseIds = ArrayList<String>()
        for (set in sets) {
            if (!exerciseIds.contains(set.exerciseId)) {
                exerciseIds.add(set.exerciseId)
            }
        }
        return exerciseIds
    }

    /** 源 `getExerciseName`（`WorkoutSummaryService.ets:217`）。内容库未装载时回落到 id 本身。 */
    private fun getExerciseName(exerciseId: String): String =
        ContentRepository.getExercise(exerciseId)?.nameZh ?: exerciseId

    /** 源 `formatDate`（`WorkoutSummaryService.ets:225`）：`YYYY-MM-DD`（本地时区）。 */
    private fun formatDate(timestamp: Long): String {
        val date = Calendar.getInstance().apply { timeInMillis = timestamp }
        return "${date.get(Calendar.YEAR)}-${padTwoDigits(date.get(Calendar.MONTH) + 1)}-" +
            padTwoDigits(date.get(Calendar.DAY_OF_MONTH))
    }

    /** 源 `padTwoDigits`（`WorkoutSummaryService.ets:233`）。 */
    private fun padTwoDigits(value: Int): String = if (value < 10) "0$value" else value.toString()

    /**
     * 源 `getNumberAfterPrefix`（`WorkoutSummaryService.ets:240`）。
     *
     * 定位 `prefix` 到下一个 `;`（无则串尾）的子串，`Math.floor` 取整；无前缀或不可解析恒返回 0。
     * 复刻 JS `Number(...)` 语义：空白串按 0（`Number('') === 0`）。
     */
    private fun getNumberAfterPrefix(source: String, prefix: String): Int {
        val startIndex = source.indexOf(prefix)
        if (startIndex < 0) {
            return 0
        }
        val valueStartIndex = startIndex + prefix.length
        var valueEndIndex = source.indexOf(';', valueStartIndex)
        if (valueEndIndex < 0) {
            valueEndIndex = source.length
        }
        val rawValue = source.substring(valueStartIndex, valueEndIndex).trim()
        if (rawValue.isEmpty()) {
            return 0
        }
        val parsed = rawValue.toDoubleOrNull() ?: return 0
        return floor(parsed).toInt()
    }
}

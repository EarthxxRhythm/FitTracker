package com.fittracker.app.data.service.stats

import com.fittracker.app.data.model.TrainingPlan
import com.fittracker.app.data.model.UserGoal
import com.fittracker.app.data.model.WorkoutSession
import com.fittracker.app.data.model.WorkoutSet
import com.fittracker.app.data.service.ContentRepository
import com.fittracker.app.data.service.generatePlan
import java.util.Calendar

/** 单条最近训练记录（源 `ReviewDashboardService.ets:31` `ReviewRecentSessionRecord`）。 */
data class ReviewRecentSessionRecord(
    val sessionId: String,
    val dayId: String,
    val dayLabel: String,
    val dateText: String,
    val durationText: String,
    val completedSets: Int,
    val targetSets: Int,
    val completionRate: Int,
    val completionText: String,
    val totalVolume: Double,
    val volumeText: String,
)

/** 历史趋势摘要（源 `ReviewDashboardService.ets:45` `ReviewTrendSummary`）。 */
data class ReviewTrendSummary(
    val hasTrend: Boolean,
    val recentSessionCount: Int,
    val previousSessionCount: Int,
    val recentTotalVolume: Double,
    val previousTotalVolume: Double,
    val recentCompletionRate: Int,
    val previousCompletionRate: Int,
    val volumeTrendText: String,
    val completionTrendText: String,
    val summaryText: String,
)

/** 复盘面板汇总（源 `ReviewDashboardService.ets:15` `ReviewDashboardSummary`）。 */
data class ReviewDashboardSummary(
    val hasSessions: Boolean,
    val sessionCount: Int,
    val totalCompletedSets: Int,
    val totalTargetSets: Int,
    val averageCompletionRate: Int,
    val totalDurationSeconds: Int,
    val totalDurationText: String,
    val latestSessionId: String,
    val latestDayId: String,
    val latestDayLabel: String,
    val adjustmentHint: String,
    val adjustmentText: String,
    val recentRecords: List<ReviewRecentSessionRecord>,
    val trendSummary: ReviewTrendSummary,
)

/** 目标调整动作（源 `ReviewDashboardService.ets:59` `ReviewGoalAdjustmentAction`）。 */
data class ReviewGoalAdjustmentAction(
    val actionType: String,
    val title: String,
    val description: String,
    val canApply: Boolean,
    val currentWeeklyDays: Int,
    val targetWeeklyDays: Int,
    val currentSessionMinutes: Int,
    val targetSessionMinutes: Int,
    val buttonText: String,
)

/** 计划重生成结果（源 `ReviewDashboardService.ets:72` `ReviewPlanRegenerationResult`）。 */
data class ReviewPlanRegenerationResult(
    val adjustedGoal: UserGoal,
    val regeneratedPlan: TrainingPlan,
    val statusText: String,
)

/**
 * 复盘面板聚合——逐函数移植自鸿蒙 `shared/services/ReviewDashboardService.ets`。
 *
 * Feature #12（复盘面板 + 下次调整提示）、Feature #14（最近记录 + 历史趋势）。
 *
 * 完成率阈值：`< 70 → reduce_load`；`>= 95 → increase_load`；否则 `keep_plan`
 * （源 `getAdjustmentHint` `:407`）。趋势窗口 2、最近记录上限 5。
 */
object ReviewDashboardService {

    private const val RECENT_RECORD_LIMIT = 5
    private const val TREND_WINDOW_SIZE = 2

    /**
     * `PlanEngine.generatePlan` 插槽——默认接真实引擎
     * （`generatePlan(goal, ContentRepository.exercises())`；源为 `PlanEngine.generatePlan(goal)`，
     * 动作清单由注入的 ContentRepository 提供）。测试可注入假发生器验证
     * `createPlanRegenerationResult`。
     */
    var planGenerator: (UserGoal) -> TrainingPlan = { goal ->
        generatePlan(goal, ContentRepository.exercises())
    }

    /** 源 `createSummary`（`ReviewDashboardService.ets:79`）。 */
    fun createSummary(sessions: List<WorkoutSession>): ReviewDashboardSummary {
        if (sessions.isEmpty()) {
            return createEmptySummary()
        }

        var totalCompletedSets = 0
        var totalTargetSets = 0
        var totalDurationSeconds = 0
        for (session in sessions) {
            totalCompletedSets += getCompletedSets(session)
            totalTargetSets += getTargetSets(session)
            totalDurationSeconds += session.durationSeconds
        }

        val latestSession = sessions.last()
        val averageCompletionRate = ReviewService.calculateCompletionRate(totalCompletedSets, totalTargetSets)
        val hint = getAdjustmentHint(averageCompletionRate)
        return ReviewDashboardSummary(
            hasSessions = true,
            sessionCount = sessions.size,
            totalCompletedSets = totalCompletedSets,
            totalTargetSets = totalTargetSets,
            averageCompletionRate = averageCompletionRate,
            totalDurationSeconds = totalDurationSeconds,
            totalDurationText = formatDurationText(totalDurationSeconds),
            latestSessionId = latestSession.sessionId,
            latestDayId = latestSession.dayId,
            latestDayLabel = formatCompactDayId(latestSession.dayId),
            adjustmentHint = hint,
            adjustmentText = getAdjustmentText(hint),
            recentRecords = createRecentRecords(sessions),
            trendSummary = createTrendSummary(sessions),
        )
    }

    /** 源 `createEmptySummary`（`ReviewDashboardService.ets:116`）。 */
    fun createEmptySummary(): ReviewDashboardSummary = ReviewDashboardSummary(
        hasSessions = false,
        sessionCount = 0,
        totalCompletedSets = 0,
        totalTargetSets = 0,
        averageCompletionRate = 0,
        totalDurationSeconds = 0,
        totalDurationText = "0 分钟",
        latestSessionId = "",
        latestDayId = "",
        latestDayLabel = "",
        adjustmentHint = "start_training",
        adjustmentText = "先完成一次训练，再根据完成率调整下次计划。",
        recentRecords = emptyList(),
        trendSummary = createEmptyTrendSummary(),
    )

    /** 源 `createRecentRecords`（`:136`）。从最新往回取，最多 `RECENT_RECORD_LIMIT` 条。 */
    private fun createRecentRecords(sessions: List<WorkoutSession>): List<ReviewRecentSessionRecord> {
        val records = ArrayList<ReviewRecentSessionRecord>()
        var count = 0
        var index = sessions.size - 1
        while (index >= 0 && count < RECENT_RECORD_LIMIT) {
            records.add(createRecentRecord(sessions[index]))
            count++
            index--
        }
        return records
    }

    /** 源 `createRecentRecord`（`:146`）。 */
    private fun createRecentRecord(session: WorkoutSession): ReviewRecentSessionRecord {
        val completedSets = getCompletedSets(session)
        val targetSets = getTargetSets(session)
        val completionRate = ReviewService.calculateCompletionRate(completedSets, targetSets)
        val totalVolume = getTotalVolume(session)
        return ReviewRecentSessionRecord(
            sessionId = session.sessionId,
            dayId = session.dayId,
            dayLabel = formatCompactDayId(session.dayId),
            dateText = formatDate(session.startedAt),
            durationText = formatDurationText(session.durationSeconds),
            completedSets = completedSets,
            targetSets = targetSets,
            completionRate = completionRate,
            completionText = "$completedSets/$targetSets 组 · $completionRate%",
            totalVolume = totalVolume,
            volumeText = "${numText(totalVolume)} kg",
        )
    }

    /** 源 `createTrendSummary`（`:181`）。窗口 2：最近 2 次 vs 更早。 */
    private fun createTrendSummary(sessions: List<WorkoutSession>): ReviewTrendSummary {
        if (sessions.size < 2) {
            return createEmptyTrendSummary()
        }

        var recentStartIndex = sessions.size - TREND_WINDOW_SIZE
        if (recentStartIndex < 1) {
            recentStartIndex = 1
        }

        var recentCompletedSets = 0
        var recentTargetSets = 0
        var recentTotalVolume = 0.0
        for (index in recentStartIndex until sessions.size) {
            val session = sessions[index]
            recentCompletedSets += getCompletedSets(session)
            recentTargetSets += getTargetSets(session)
            recentTotalVolume += getTotalVolume(session)
        }

        var previousCompletedSets = 0
        var previousTargetSets = 0
        var previousTotalVolume = 0.0
        for (index in 0 until recentStartIndex) {
            val session = sessions[index]
            previousCompletedSets += getCompletedSets(session)
            previousTargetSets += getTargetSets(session)
            previousTotalVolume += getTotalVolume(session)
        }

        val recentCompletionRate = ReviewService.calculateCompletionRate(recentCompletedSets, recentTargetSets)
        val previousCompletionRate = ReviewService.calculateCompletionRate(previousCompletedSets, previousTargetSets)
        val recentSessionCount = sessions.size - recentStartIndex
        val previousSessionCount = recentStartIndex
        val volumeDelta = recentTotalVolume - previousTotalVolume
        val completionDelta = recentCompletionRate - previousCompletionRate
        return ReviewTrendSummary(
            hasTrend = true,
            recentSessionCount = recentSessionCount,
            previousSessionCount = previousSessionCount,
            recentTotalVolume = recentTotalVolume,
            previousTotalVolume = previousTotalVolume,
            recentCompletionRate = recentCompletionRate,
            previousCompletionRate = previousCompletionRate,
            volumeTrendText = createVolumeTrendText(volumeDelta),
            completionTrendText = createCompletionTrendText(completionDelta),
            summaryText = createTrendSummaryText(recentSessionCount, volumeDelta, completionDelta),
        )
    }

    /** 源 `createEmptyTrendSummary`（`:232`）。 */
    fun createEmptyTrendSummary(): ReviewTrendSummary = ReviewTrendSummary(
        hasTrend = false,
        recentSessionCount = 0,
        previousSessionCount = 0,
        recentTotalVolume = 0.0,
        previousTotalVolume = 0.0,
        recentCompletionRate = 0,
        previousCompletionRate = 0,
        volumeTrendText = "完成更多训练后生成趋势",
        completionTrendText = "完成更多训练后生成趋势",
        summaryText = "至少保存两次训练后，可以查看历史趋势。",
    )

    /** 源 `createGoalAdjustmentAction`（`:248`）。 */
    fun createGoalAdjustmentAction(summary: ReviewDashboardSummary, goal: UserGoal): ReviewGoalAdjustmentAction {
        val actionType = summary.adjustmentHint
        val targetWeeklyDays = adjustWeeklyDays(goal.weeklyDays, actionType)
        val targetSessionMinutes = adjustSessionMinutes(goal.sessionMinutes, actionType)
        val canApply = summary.hasSessions &&
            (targetWeeklyDays != goal.weeklyDays || targetSessionMinutes != goal.sessionMinutes)
        return ReviewGoalAdjustmentAction(
            actionType = actionType,
            title = getAdjustmentActionTitle(actionType),
            description = getAdjustmentActionDescription(
                actionType, goal.weeklyDays, targetWeeklyDays, goal.sessionMinutes, targetSessionMinutes,
            ),
            canApply = canApply,
            currentWeeklyDays = goal.weeklyDays,
            targetWeeklyDays = targetWeeklyDays,
            currentSessionMinutes = goal.sessionMinutes,
            targetSessionMinutes = targetSessionMinutes,
            buttonText = getAdjustmentButtonText(canApply),
        )
    }

    /** 源 `createEmptyGoalAdjustmentAction`（`:269`）。 */
    fun createEmptyGoalAdjustmentAction(): ReviewGoalAdjustmentAction = ReviewGoalAdjustmentAction(
        actionType = "start_training",
        title = "完成训练后再调整",
        description = "先保存一次训练结果，系统会根据完成率给出目标调整动作。",
        canApply = false,
        currentWeeklyDays = 0,
        targetWeeklyDays = 0,
        currentSessionMinutes = 0,
        targetSessionMinutes = 0,
        buttonText = "暂无可应用调整",
    )

    /** 源 `createPlanRegenerationResult`（`:284`）。依赖注入的 `planGenerator`（见该插槽说明）。 */
    fun createPlanRegenerationResult(
        goal: UserGoal,
        action: ReviewGoalAdjustmentAction,
        now: Long,
    ): ReviewPlanRegenerationResult {
        val adjustedGoal = UserGoal(
            goalId = goal.goalId,
            goalType = goal.goalType,
            level = goal.level,
            weeklyDays = action.targetWeeklyDays,
            sessionMinutes = action.targetSessionMinutes,
            equipmentIds = copyStringArray(goal.equipmentIds),
            restrictedMuscleIds = copyStringArray(goal.restrictedMuscleIds),
            createdAt = goal.createdAt,
            updatedAt = now,
        )
        val regeneratedPlan = planGenerator(adjustedGoal)
        return ReviewPlanRegenerationResult(
            adjustedGoal = adjustedGoal,
            regeneratedPlan = regeneratedPlan,
            statusText = "已保存调整并重新生成 ${regeneratedPlan.days.size} 天计划",
        )
    }

    /** 源 `createVolumeTrendText`（`:305`）。 */
    private fun createVolumeTrendText(delta: Double): String {
        if (delta > 0) return "训练量上升 ${numText(delta)} kg"
        if (delta < 0) return "训练量下降 ${numText(-delta)} kg"
        return "训练量持平"
    }

    /** 源 `createCompletionTrendText`（`:315`）。 */
    private fun createCompletionTrendText(delta: Int): String {
        if (delta > 0) return "完成率上升 $delta%"
        if (delta < 0) return "完成率下降 ${-delta}%"
        return "完成率持平"
    }

    /** 源 `createTrendSummaryText`（`:325`）。 */
    private fun createTrendSummaryText(recentSessionCount: Int, volumeDelta: Double, completionDelta: Int): String {
        if (volumeDelta > 0 && completionDelta > 0) {
            return "最近 $recentSessionCount 次训练量和完成率均高于此前记录。"
        }
        if (volumeDelta > 0 && completionDelta <= 0) {
            return "最近 $recentSessionCount 次训练量提高，注意保持完成率稳定。"
        }
        if (volumeDelta <= 0 && completionDelta > 0) {
            return "最近 $recentSessionCount 次完成率提高，训练量可以稳步推进。"
        }
        if (volumeDelta < 0 && completionDelta < 0) {
            return "最近 $recentSessionCount 次训练表现回落，建议下次适当降低压力。"
        }
        return "最近 $recentSessionCount 次训练与此前基本持平。"
    }

    /** 源 `getTotalVolume`（`:341`）。优先按 sets 现算，回落到 `session.totalVolume`。 */
    private fun getTotalVolume(session: WorkoutSession): Double {
        if (session.sets.isNotEmpty()) {
            return ReviewService.calculateVolume(session.sets)
        }
        if (session.totalVolume > 0) {
            return session.totalVolume
        }
        return ReviewService.calculateVolume(session.sets)
    }

    /** 源 `getCompletedSets`（`:366`）。sets 有值按组统计，否则解析 notes `completed_sets=`。 */
    private fun getCompletedSets(session: WorkoutSession): Int {
        if (session.sets.isNotEmpty()) {
            return countCompletedSets(session.sets)
        }
        return getNumberAfterPrefix(session.notes, "completed_sets=", 0)
    }

    /** 源 `getTargetSets`（`:373`）。解析 notes `target_sets=`，未命中回落到完成组数。 */
    private fun getTargetSets(session: WorkoutSession): Int =
        getNumberAfterPrefix(session.notes, "target_sets=", getCompletedSets(session))

    /** 源 `countCompletedSets`（`:377`）。非热身、重量/次数均 > 0 的组计数。 */
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
     * 源 `getNumberAfterPrefix`（`:387`）。在 `source` 中定位 `prefix`，
     * 取其到下一个 `;`（无则到串尾）之间的子串解析为整数（`Math.floor`）。
     *
     * 复刻 JS `Number(...)` 语义：空白串按 0（`Number('') === 0`），无法解析则回落 `fallbackValue`。
     */
    private fun getNumberAfterPrefix(source: String, prefix: String, fallbackValue: Int): Int {
        val startIndex = source.indexOf(prefix)
        if (startIndex < 0) {
            return fallbackValue
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
        val parsed = rawValue.toDoubleOrNull() ?: return fallbackValue
        return kotlin.math.floor(parsed).toInt()
    }

    /** 源 `getAdjustmentHint`（`:407`）。`< 70 → reduce_load`；`>= 95 → increase_load`。 */
    private fun getAdjustmentHint(averageCompletionRate: Int): String {
        if (averageCompletionRate < 70) return "reduce_load"
        if (averageCompletionRate >= 95) return "increase_load"
        return "keep_plan"
    }

    /** 源 `getAdjustmentText`（`:417`）。 */
    private fun getAdjustmentText(hint: String): String {
        if (hint == "reduce_load") return "完成率偏低，下次建议减少训练天数或缩短单次时长。"
        if (hint == "increase_load") return "完成率很高，下次可以增加训练天数或延长单次时长。"
        return "完成率稳定，下次保持当前计划即可。"
    }

    /** 源 `adjustWeeklyDays`（`:426`）。变化量 ±1，夹在 1..7。 */
    private fun adjustWeeklyDays(currentWeeklyDays: Int, actionType: String): Int = when (actionType) {
        "reduce_load" -> clampNumber(currentWeeklyDays - 1, 1, 7)
        "increase_load" -> clampNumber(currentWeeklyDays + 1, 1, 7)
        else -> clampNumber(currentWeeklyDays, 1, 7)
    }

    /** 源 `adjustSessionMinutes`（`:436`）。变化量 ±15，夹在 30..90。 */
    private fun adjustSessionMinutes(currentSessionMinutes: Int, actionType: String): Int = when (actionType) {
        "reduce_load" -> clampNumber(currentSessionMinutes - 15, 30, 90)
        "increase_load" -> clampNumber(currentSessionMinutes + 15, 30, 90)
        else -> clampNumber(currentSessionMinutes, 30, 90)
    }

    /** 源 `clampNumber`（`:446`）。 */
    private fun clampNumber(value: Int, minValue: Int, maxValue: Int): Int {
        if (value < minValue) return minValue
        if (value > maxValue) return maxValue
        return value
    }

    /** 源 `getAdjustmentActionTitle`（`:456`）。 */
    private fun getAdjustmentActionTitle(actionType: String): String {
        if (actionType == "reduce_load") return "降低下次训练压力"
        if (actionType == "increase_load") return "提高下次训练目标"
        return "保持当前目标"
    }

    /** 源 `getAdjustmentActionDescription`（`:466`）。 */
    private fun getAdjustmentActionDescription(
        actionType: String,
        currentWeeklyDays: Int,
        targetWeeklyDays: Int,
        currentSessionMinutes: Int,
        targetSessionMinutes: Int,
    ): String {
        if (actionType == "keep_plan") {
            return "当前完成率稳定，本次不需要改动目标。"
        }
        return "每周训练由 $currentWeeklyDays 天调整为 $targetWeeklyDays 天，" +
            "单次时长由 $currentSessionMinutes 分钟调整为 $targetSessionMinutes 分钟。"
    }

    /** 源 `getAdjustmentButtonText`（`:481`）。 */
    private fun getAdjustmentButtonText(canApply: Boolean): String =
        if (canApply) "应用调整并重新生成计划" else "无需重新生成"

    /** 源 `copyStringArray`（`:488`）。 */
    private fun copyStringArray(source: List<String>): List<String> {
        val values = ArrayList<String>(source.size)
        for (value in source) {
            values.add(value)
        }
        return values
    }

    /** 源 `formatDate`（`:351`）：`YYYY-MM-DD`（本地时区）。 */
    private fun formatDate(timestamp: Long): String {
        val date = Calendar.getInstance().apply { timeInMillis = timestamp }
        return "${date.get(Calendar.YEAR)}-${padTwoDigits(date.get(Calendar.MONTH) + 1)}-" +
            padTwoDigits(date.get(Calendar.DAY_OF_MONTH))
    }

    /** 源 `padTwoDigits`（`:359`）。 */
    private fun padTwoDigits(value: Int): String = if (value < 10) "0$value" else value.toString()

    /**
     * 内联自 `TrainingDayLabelService.ets:9 formatCompact`（该服务未在本次范围）。
     * `current_plan_day_N` / `day_N` → `第 N 天`；命名 key（推/拉/腿…）→ 固定中文；否则回落 `dayId`。
     */
    private fun formatCompactDayId(dayId: String, fallbackLabel: String = ""): String {
        val normalizedDayId = dayId.trim().lowercase()
        Regex("^current_plan_day_(\\d+)$").find(normalizedDayId)?.let {
            return "第 ${it.groupValues[1]} 天"
        }
        Regex("^day_(\\d+)$").find(normalizedDayId)?.let {
            return "第 ${it.groupValues[1]} 天"
        }
        val namedLabel = namedDayLabel(normalizedDayId)
        if (namedLabel.isNotEmpty()) {
            return namedLabel
        }
        if (fallbackLabel.isNotEmpty()) {
            return fallbackLabel
        }
        return dayId
    }

    /** 源 `TrainingDayLabelService.getNamedDayLabel`。 */
    private fun namedDayLabel(normalizedDayId: String): String {
        var key = normalizedDayId
        if (normalizedDayId.startsWith("day_")) {
            key = normalizedDayId.substring(4)
        } else if (normalizedDayId.endsWith("_day")) {
            key = normalizedDayId.substring(0, normalizedDayId.length - 4)
        }
        return when (key) {
            "push" -> "推日"
            "pull" -> "拉日"
            "leg", "legs", "lower" -> "下肢日"
            "upper" -> "上肢日"
            "core" -> "核心日"
            "full_body", "fullbody" -> "全身日"
            "recovery" -> "恢复日"
            "rest" -> "休息日"
            "chest" -> "胸部日"
            "back" -> "背部日"
            "shoulder", "shoulders" -> "肩部日"
            "arm", "arms" -> "手臂日"
            "glute", "glutes" -> "臀部日"
            "monday" -> "周一"
            "tuesday" -> "周二"
            "wednesday" -> "周三"
            "thursday" -> "周四"
            "friday" -> "周五"
            "saturday" -> "周六"
            "sunday" -> "周日"
            else -> ""
        }
    }

    /** 内联自 `WorkoutSummaryService.ets:81 formatDuration`（该服务未在本次范围）。 */
    private fun formatDurationText(durationSeconds: Int): String {
        if (durationSeconds <= 0) return "0 分钟"
        val minutes = durationSeconds / 60
        if (minutes <= 0) return "1 分钟内"
        val hours = minutes / 60
        val restMinutes = minutes % 60
        if (hours > 0 && restMinutes > 0) return "$hours 小时 $restMinutes 分钟"
        if (hours > 0) return "$hours 小时"
        return "$minutes 分钟"
    }

    /** JS `Number.prototype.toString` 口径：整数去掉尾随 `.0`。 */
    private fun numText(value: Double): String =
        if (value.isFinite() && value == kotlin.math.floor(value) && kotlin.math.abs(value) < 1e15) {
            value.toLong().toString()
        } else {
            value.toString()
        }
}

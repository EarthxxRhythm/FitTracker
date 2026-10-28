package com.fittracker.app.data.service

import com.fittracker.app.data.model.WorkoutSession
import com.fittracker.app.data.model.WorkoutSet
import com.fittracker.app.data.service.stats.ReviewRecentSessionRecord
import com.fittracker.app.data.service.stats.ReviewService
import java.util.Calendar
import kotlin.math.abs
import kotlin.math.floor

/** 最近训练筛选选项（源 `ReviewInsightsService.ets:12` `ReviewRecentSessionFilterOption`）。 */
data class ReviewRecentSessionFilterOption(
    val filterId: String,
    val label: String,
    val description: String,
    val matchedSessionCount: Int,
    val locked: Boolean,
)

/** 周趋势条目（源 `ReviewInsightsService.ets:20` `ReviewWeeklyTrendItem`）。 */
data class ReviewWeeklyTrendItem(
    val weekId: String,
    val weekLabel: String,
    val dateRangeText: String,
    val sessionCount: Int,
    val totalDurationSeconds: Int,
    val totalDurationText: String,
    val totalVolume: Double,
    val completionRate: Int,
    val completionText: String,
    val averageSessionText: String,
    val dominantDayId: String,
    val dominantDayLabel: String,
    val summaryText: String,
)

/**
 * 回顾洞察服务——逐函数移植自鸿蒙 `shared/services/ReviewInsightsService.ets`。
 *
 * Function #14（最近训练筛选 + 周趋势详情）。无状态单例，复用 `ReviewService`（完成率/训练量）
 * 与 `WorkoutSummaryService.formatDuration`（时长文案），最近记录模型 `ReviewRecentSessionRecord`
 * 复用 `stats` 包（源 `ReviewInsightsService.ets:7` 亦从 `ReviewDashboardService` 导入该类型）。
 *
 * 与 `ReviewDashboardService` 的重叠：本服务也产出「最近记录」，但口径不同——
 * 本服务上限 6 条、筛选窗口 7/30 天、`completionText` 为 `X/Y 组`（源 `:177`），
 * 而 `ReviewDashboardService`（源 `:146`）上限 5 条、`completionText` 为 `X/Y 组 · R%`。
 * 二者各自独立，勿互相替换。
 *
 * `currentReferenceTime` 为一次调用内共享的「当前时刻」缓存（源 `:39`）：`createWeeklyTrendItems`
 * 依赖它生成「本周 / N 周前」标签，调用前须先经任一入口方法写入 `now`。
 */
object ReviewInsightsService {

    private const val RECENT_RECORD_LIMIT = 6
    private const val WEEKLY_TREND_LIMIT = 6
    private const val COMPLETED_SETS_PREFIX = "completed_sets="
    private const val TARGET_SETS_PREFIX = "target_sets="

    private var currentReferenceTime: Long = 0

    /** 源 `createRecentFilters`（`ReviewInsightsService.ets:41`）。 */
    fun createRecentFilters(
        sessions: List<WorkoutSession>,
        now: Long,
        unlimitedHistoryUnlocked: Boolean,
    ): List<ReviewRecentSessionFilterOption> {
        currentReferenceTime = now
        return listOf(
            createFilterOption("recent_7_days", "最近 7 天", "聚焦最近一周训练", sessions, now, false),
            createFilterOption("recent_30_days", "最近 30 天", "看近一个月节奏", sessions, now, false),
            createFilterOption(
                "all_sessions",
                "全部记录",
                if (unlimitedHistoryUnlocked) "查看所有已保存训练" else "升级 Pro 后查看全部历史记录",
                sessions,
                now,
                !unlimitedHistoryUnlocked,
            ),
        )
    }

    /**
     * 源 `filterRecentRecords`（`ReviewInsightsService.ets:61`）。
     * 从最新往回取，最多 `RECENT_RECORD_LIMIT` 条匹配记录（结果按时间倒序，最新在前）。
     */
    fun filterRecentRecords(
        sessions: List<WorkoutSession>,
        filterId: String,
        now: Long,
        unlimitedHistoryUnlocked: Boolean,
    ): List<ReviewRecentSessionRecord> {
        currentReferenceTime = now
        val resolvedFilterId = resolveFilterId(filterId, unlimitedHistoryUnlocked)
        val filteredSessions = ArrayList<WorkoutSession>()
        var index = sessions.size - 1
        while (index >= 0) {
            if (matchesFilter(sessions[index], resolvedFilterId, now)) {
                filteredSessions.add(sessions[index])
            }
            if (filteredSessions.size >= RECENT_RECORD_LIMIT) {
                break
            }
            index--
        }
        return filteredSessions.map { createRecentRecord(it) }
    }

    /** 源 `resolveFilterId`（`ReviewInsightsService.ets:87`）。`all_sessions` 未解锁时降级为 30 天。 */
    fun resolveFilterId(filterId: String, unlimitedHistoryUnlocked: Boolean): String {
        if (filterId == "all_sessions" && !unlimitedHistoryUnlocked) {
            return "recent_30_days"
        }
        return filterId
    }

    /** 源 `createWeeklyTrendItems`（`ReviewInsightsService.ets:94`）。近 6 周（本周在前）汇总。 */
    fun createWeeklyTrendItems(
        sessions: List<WorkoutSession>,
        now: Long,
        weekStart: WeekStart,
    ): List<ReviewWeeklyTrendItem> {
        currentReferenceTime = now
        val items = ArrayList<ReviewWeeklyTrendItem>(WEEKLY_TREND_LIMIT)
        val currentWeekStart = createWeekStart(now, weekStart)
        for (offset in 0 until WEEKLY_TREND_LIMIT) {
            val weekStartCalendar = calendarAt(
                currentWeekStart.get(Calendar.YEAR),
                currentWeekStart.get(Calendar.MONTH),
                currentWeekStart.get(Calendar.DAY_OF_MONTH) - offset * 7,
            )
            items.add(createWeeklyTrendItem(sessions, weekStartCalendar, weekStart))
        }

        for (index in items.indices) {
            val current = items[index]
            val previous = if (index + 1 < items.size) items[index + 1] else null
            items[index] = current.copy(summaryText = createWeeklySummaryText(current, previous, index))
        }
        return items
    }

    /** 源 `createEmptyWeeklyTrendItem`（`ReviewInsightsService.ets:115`）。 */
    fun createEmptyWeeklyTrendItem(): ReviewWeeklyTrendItem = ReviewWeeklyTrendItem(
        weekId = "",
        weekLabel = "本周趋势",
        dateRangeText = "",
        sessionCount = 0,
        totalDurationSeconds = 0,
        totalDurationText = "0 分钟",
        totalVolume = 0.0,
        completionRate = 0,
        completionText = "0/0 组",
        averageSessionText = "0 分钟/次",
        dominantDayId = "",
        dominantDayLabel = "",
        summaryText = "完成训练后，这里会开始累积周趋势。",
    )

    /** 源 `createFilterOption`（`ReviewInsightsService.ets:134`）。 */
    private fun createFilterOption(
        filterId: String,
        label: String,
        description: String,
        sessions: List<WorkoutSession>,
        now: Long,
        locked: Boolean,
    ): ReviewRecentSessionFilterOption {
        var matchedSessionCount = 0
        for (session in sessions) {
            if (matchesFilter(session, filterId, now)) {
                matchedSessionCount++
            }
        }
        return ReviewRecentSessionFilterOption(
            filterId = filterId,
            label = label,
            description = description,
            matchedSessionCount = matchedSessionCount,
            locked = locked,
        )
    }

    /** 源 `matchesFilter`（`ReviewInsightsService.ets:158`）。7/30 天窗口按 `now` 回推。 */
    private fun matchesFilter(session: WorkoutSession, filterId: String, now: Long): Boolean {
        if (filterId == "recent_7_days") {
            return session.startedAt >= now - 7L * 24 * 60 * 60 * 1000
        }
        if (filterId == "recent_30_days") {
            return session.startedAt >= now - 30L * 24 * 60 * 60 * 1000
        }
        return true
    }

    /** 源 `createRecentRecord`（`ReviewInsightsService.ets:168`）。 */
    private fun createRecentRecord(session: WorkoutSession): ReviewRecentSessionRecord {
        val completedSets = getCompletedSets(session)
        val targetSets = getTargetSets(session)
        val completionRate = ReviewService.calculateCompletionRate(completedSets, targetSets)
        val totalVolume = getTotalVolume(session)
        return ReviewRecentSessionRecord(
            sessionId = session.sessionId,
            dayId = session.dayId,
            dayLabel = formatCompactDayLabel(session.dayId),
            dateText = formatDate(session.startedAt),
            durationText = WorkoutSummaryService.formatDuration(session.durationSeconds),
            completedSets = completedSets,
            targetSets = targetSets,
            completionRate = completionRate,
            completionText = "$completedSets/$targetSets 组",
            totalVolume = totalVolume,
            volumeText = "${numText(totalVolume)} kg",
        )
    }

    /**
     * 源 `createWeeklyTrendItem`（`ReviewInsightsService.ets:203`）。
     * 窗口 = `[weekStart 00:00, 次周周一 00:00)`；`dominantDayId` 取训练量最大的一天（`>=` 使后者胜出）。
     */
    private fun createWeeklyTrendItem(
        sessions: List<WorkoutSession>,
        weekStart: Calendar,
        weekStartSetting: WeekStart,
    ): ReviewWeeklyTrendItem {
        val weekStartTime = weekStart.timeInMillis
        val weekEnd = calendarAt(
            weekStart.get(Calendar.YEAR),
            weekStart.get(Calendar.MONTH),
            weekStart.get(Calendar.DAY_OF_MONTH) + 6,
        )
        val weekEndExclusive = calendarAt(
            weekEnd.get(Calendar.YEAR),
            weekEnd.get(Calendar.MONTH),
            weekEnd.get(Calendar.DAY_OF_MONTH) + 1,
        ).timeInMillis

        var sessionCount = 0
        var totalDurationSeconds = 0
        var totalVolume = 0.0
        var completedSets = 0
        var targetSets = 0
        var dominantDayId = ""
        var dominantVolume = 0.0

        for (session in sessions) {
            if (session.startedAt < weekStartTime || session.startedAt >= weekEndExclusive) {
                continue
            }
            sessionCount++
            totalDurationSeconds += session.durationSeconds
            totalVolume += getTotalVolume(session)
            completedSets += getCompletedSets(session)
            targetSets += getTargetSets(session)
            val sessionVolume = getTotalVolume(session)
            if (sessionVolume >= dominantVolume) {
                dominantVolume = sessionVolume
                dominantDayId = session.dayId
            }
        }

        val completionRate = ReviewService.calculateCompletionRate(completedSets, targetSets)
        val averageSessionSeconds = if (sessionCount > 0) floor(totalDurationSeconds.toDouble() / sessionCount).toInt() else 0
        return ReviewWeeklyTrendItem(
            weekId = formatDate(weekStartTime),
            weekLabel = createWeekLabel(weekStartTime, weekStartSetting),
            dateRangeText = "${formatDate(weekStartTime)} - ${formatDate(weekEnd.timeInMillis)}",
            sessionCount = sessionCount,
            totalDurationSeconds = totalDurationSeconds,
            totalDurationText = WorkoutSummaryService.formatDuration(totalDurationSeconds),
            totalVolume = totalVolume,
            completionRate = completionRate,
            completionText = "$completedSets/$targetSets 组",
            averageSessionText = WorkoutSummaryService.formatDuration(averageSessionSeconds) + "/次",
            dominantDayId = dominantDayId,
            dominantDayLabel = formatCompactDayLabel(dominantDayId),
            summaryText = "",
        )
    }

    /** 源 `createWeeklySummaryText`（`ReviewInsightsService.ets:256`）。 */
    private fun createWeeklySummaryText(
        current: ReviewWeeklyTrendItem,
        previous: ReviewWeeklyTrendItem?,
        index: Int,
    ): String {
        if (current.sessionCount == 0) {
            return "这一周还没有训练记录。"
        }
        if (previous == null || previous.sessionCount == 0) {
            return "本周完成 ${current.sessionCount} 次训练，平均完成率 ${current.completionRate}%。"
        }

        val volumeDelta = current.totalVolume - previous.totalVolume
        val completionDelta = current.completionRate - previous.completionRate
        if (index == 0) {
            return "相比上周，训练量${createSignedText(volumeDelta, "kg")}，完成率" +
                "${createSignedText(completionDelta, "%")}。"
        }
        return "相比更早一周，训练量${createSignedText(volumeDelta, "kg")}，完成率" +
            "${createSignedText(completionDelta, "%")}。"
    }

    /** 源 `createSignedText`（`ReviewInsightsService.ets:279`）。训练量增量（JS `number.toString` 口径）。 */
    private fun createSignedText(delta: Double, unit: String): String {
        if (delta > 0) {
            return "增加 ${numText(delta)} $unit"
        }
        if (delta < 0) {
            return "减少 ${numText(-delta)} $unit"
        }
        return "持平"
    }

    /** 源 `createSignedText`（`ReviewInsightsService.ets:279`）。完成率增量（整数）。 */
    private fun createSignedText(delta: Int, unit: String): String {
        if (delta > 0) {
            return "增加 $delta $unit"
        }
        if (delta < 0) {
            return "减少 ${-delta} $unit"
        }
        return "持平"
    }

    /** 源 `createWeekLabel`（`ReviewInsightsService.ets:289`）。本周 → `本周`，其余 `N 周前`。 */
    private fun createWeekLabel(timestamp: Long, weekStart: WeekStart): String {
        val nowWeekStart = formatDate(createWeekStart(currentReferenceTime, weekStart).timeInMillis)
        val weekId = formatDate(timestamp)
        if (weekId == nowWeekStart) {
            return "本周"
        }
        return "${getWeekOffsetLabel(timestamp, weekStart)} 周前"
    }

    /** 源 `getWeekOffsetLabel`（`ReviewInsightsService.ets:298`）。 */
    private fun getWeekOffsetLabel(timestamp: Long, weekStart: WeekStart): String {
        val nowWeekStart = createWeekStart(currentReferenceTime, weekStart)
        val weekStartCalendar = createWeekStart(timestamp, weekStart)
        val deltaMilliseconds = nowWeekStart.timeInMillis - weekStartCalendar.timeInMillis
        val deltaWeeks = floor(deltaMilliseconds.toDouble() / (7L * 24 * 60 * 60 * 1000)).toInt()
        return deltaWeeks.toString()
    }

    /**
     * 源 `createWeekStart`（`ReviewInsightsService.ets:306`）。当周周首 00:00 —— 周首由 [weekStart]
     * 决定（周一/周日；JS `getDay`：周日=0）。
     */
    private fun createWeekStart(timestamp: Long, weekStart: WeekStart): Calendar {
        val value = calendarFrom(timestamp)
        val jsDayOfWeek = value.get(Calendar.DAY_OF_WEEK) - 1 // 周日=0..周六=6
        val offset = WeekWindow.offsetFromWeekStart(jsDayOfWeek, weekStart)
        return calendarAt(
            value.get(Calendar.YEAR),
            value.get(Calendar.MONTH),
            value.get(Calendar.DAY_OF_MONTH) - offset,
        )
    }

    /** 源 `getTotalVolume`（`ReviewInsightsService.ets:316`）。优先 sets 现算，回落到 `session.totalVolume`。 */
    private fun getTotalVolume(session: WorkoutSession): Double {
        if (session.sets.isNotEmpty()) {
            return ReviewService.calculateVolume(session.sets)
        }
        if (session.totalVolume > 0) {
            return session.totalVolume
        }
        return ReviewService.calculateVolume(session.sets)
    }

    /** 源 `getCompletedSets`（`ReviewInsightsService.ets:326`）。sets 有值按组统计，否则解析 notes（无 `> 0` 判定）。 */
    private fun getCompletedSets(session: WorkoutSession): Int {
        if (session.sets.isNotEmpty()) {
            return countCompletedSets(session.sets)
        }
        return getNumberAfterPrefix(session.notes, COMPLETED_SETS_PREFIX, 0)
    }

    /** 源 `getTargetSets`（`ReviewInsightsService.ets:333`）。解析缺失/不可解析时回落完成组数（不判定 `> 0`）。 */
    private fun getTargetSets(session: WorkoutSession): Int =
        getNumberAfterPrefix(session.notes, TARGET_SETS_PREFIX, getCompletedSets(session))

    /** 源 `countCompletedSets`（`ReviewInsightsService.ets:337`）。非热身、重量/次数均 > 0 的组计数。 */
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
     * 源 `getNumberAfterPrefix`（`ReviewInsightsService.ets:347`）。
     *
     * 带 `fallbackValue`：无前缀或不可解析回落 `fallbackValue`，空白串按 0
     * （复刻 JS `Number('') === 0`，此时不触发回落——与 `WorkoutSummaryService` 同口径）。
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
        return floor(parsed).toInt()
    }

    /** 源 `formatDate`（`ReviewInsightsService.ets:364`）：`YYYY-MM-DD`（本地时区）。 */
    private fun formatDate(timestamp: Long): String {
        val date = Calendar.getInstance().apply { timeInMillis = timestamp }
        return "${date.get(Calendar.YEAR)}-${padTwoDigits(date.get(Calendar.MONTH) + 1)}-" +
            padTwoDigits(date.get(Calendar.DAY_OF_MONTH))
    }

    /** 源 `padTwoDigits`（`ReviewInsightsService.ets:370`）。 */
    private fun padTwoDigits(value: Int): String = if (value < 10) "0$value" else value.toString()

    /**
     * 内联自 `TrainingDayLabelService.ets:9 formatCompact`（该服务在 Kotlin 侧暂无独立单例；
     * `ReviewDashboardService` 亦曾以私有 `formatCompactDayId` 内联同一逻辑）。
     *
     * `current_plan_day_N` / `day_N` → `第 N 天`；命名 key（推/拉/腿…）→ 固定中文；否则回落 `fallbackLabel`、再回落 `dayId`。
     */
    private fun formatCompactDayLabel(dayId: String, fallbackLabel: String = ""): String {
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

    /** 本地时区午夜 Calendar（对齐 JS `new Date(y, m, d)`）。 */
    private fun calendarAt(year: Int, month0: Int, dayOfMonth: Int): Calendar {
        val cal = Calendar.getInstance()
        cal.clear()
        cal.set(year, month0, dayOfMonth)
        return cal
    }

    /** 从 epoch 毫秒构造本地 Calendar（对齐 JS `new Date(timestamp)`）。 */
    private fun calendarFrom(timestamp: Long): Calendar = Calendar.getInstance().apply { timeInMillis = timestamp }

    /**
     * JS `Number.prototype.toString` 口径：整数去掉尾随 `.0`
     * （Kotlin `1000.0.toString()` = `"1000.0"`，JS = `"1000"`）。
     */
    private fun numText(value: Double): String =
        if (value.isFinite() && value == floor(value) && abs(value) < 1e15) {
            value.toLong().toString()
        } else {
            value.toString()
        }
}

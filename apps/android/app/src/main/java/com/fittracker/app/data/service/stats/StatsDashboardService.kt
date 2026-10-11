package com.fittracker.app.data.service.stats

import com.fittracker.app.data.model.WorkoutSession
import com.fittracker.app.data.model.WorkoutSet
import com.fittracker.app.data.service.WeekStart
import com.fittracker.app.data.service.WeekWindow
import java.util.Calendar
import kotlin.math.abs
import kotlin.math.floor

/** 周训练统计（源 `StatsDashboardService.ets:9` `WeeklyTrainingStats`）。 */
data class WeeklyTrainingStats(
    val weekStartText: String,
    val weekEndText: String,
    val dateRangeText: String,
    val sessionCount: Int,
    val totalDurationSeconds: Int,
    val totalDurationText: String,
    val totalSets: Int,
    val totalVolume: Double,
)

/** 热力日历单日格（源 `StatsDashboardService.ets:20` `CalendarHeatmapDay`）。 */
data class CalendarHeatmapDay(
    val dateText: String,
    val dayOfMonth: Int,
    val isCurrentMonth: Boolean,
    val sessionCount: Int,
    val totalVolume: Double,
    val level: Int,
    val accessibilityText: String,
)

/** 热力日历一行（7 天）（源 `StatsDashboardService.ets:30` `CalendarHeatmapRow`）。 */
data class CalendarHeatmapRow(
    val rowId: String,
    val days: List<CalendarHeatmapDay>,
)

/** 统计面板汇总（源 `StatsDashboardService.ets:35` `StatsDashboardSummary`）。 */
data class StatsDashboardSummary(
    val weeklyStats: WeeklyTrainingStats,
    val monthTitle: String,
    val heatmapDays: List<CalendarHeatmapDay>,
    val heatmapRows: List<CalendarHeatmapRow>,
)

/**
 * 统计面板聚合——逐函数移植自鸿蒙 `shared/services/StatsDashboardService.ets`。
 *
 * 纯函数、无状态单例：周统计（本周一 00:00 起）+ 42 格热力日历（6 行 × 7 列）。
 *
 * 日期口径与源 `new Date(...)` 本地时区语义对齐，Kotlin 侧用 `java.util.Calendar`
 * （`minSdk = 24`，不用 `java.time`，避免 desugaring 依赖）。
 */
object StatsDashboardService {

    /** 源 `createSummary`（`StatsDashboardService.ets:43`）。 */
    fun createSummary(sessions: List<WorkoutSession>, now: Long, weekStart: WeekStart): StatsDashboardSummary {
        val heatmapDays = createHeatmapDays(sessions, now, weekStart)
        return StatsDashboardSummary(
            weeklyStats = createWeeklyStats(sessions, now, weekStart),
            monthTitle = formatMonthTitle(now),
            heatmapDays = heatmapDays,
            heatmapRows = createHeatmapRows(heatmapDays),
        )
    }

    /** 源 `createEmptySummary`（`StatsDashboardService.ets:54`）。 */
    fun createEmptySummary(now: Long, weekStart: WeekStart): StatsDashboardSummary =
        createSummary(emptyList(), now, weekStart)

    /** 源 `findHeatmapDay`（`StatsDashboardService.ets:58`）。 */
    fun findHeatmapDay(days: List<CalendarHeatmapDay>, dateText: String): CalendarHeatmapDay? {
        for (day in days) {
            if (day.dateText == dateText) {
                return day
            }
        }
        return null
    }

    /** 源 `createWeeklyStats`（`StatsDashboardService.ets:68`）。窗口 = [周首 00:00, 下个周首 00:00)。 */
    private fun createWeeklyStats(
        sessions: List<WorkoutSession>,
        now: Long,
        weekStart: WeekStart,
    ): WeeklyTrainingStats {
        val startCalendar = createWeekStart(now, weekStart)
        val weekEnd = calendarAt(
            startCalendar.get(Calendar.YEAR),
            startCalendar.get(Calendar.MONTH),
            startCalendar.get(Calendar.DAY_OF_MONTH) + 6,
        )
        val weekStartTime = startCalendar.timeInMillis
        val weekEndExclusive = calendarAt(
            weekEnd.get(Calendar.YEAR),
            weekEnd.get(Calendar.MONTH),
            weekEnd.get(Calendar.DAY_OF_MONTH) + 1,
        ).timeInMillis
        var sessionCount = 0
        var totalDurationSeconds = 0
        var totalSets = 0
        var totalVolume = 0.0

        for (session in sessions) {
            if (session.startedAt >= weekStartTime && session.startedAt < weekEndExclusive) {
                sessionCount++
                totalDurationSeconds += session.durationSeconds
                totalSets += getSessionCompletedSets(session)
                totalVolume += getSessionVolume(session)
            }
        }

        val weekStartText = formatDate(startCalendar.timeInMillis)
        val weekEndText = formatDate(weekEnd.timeInMillis)
        return WeeklyTrainingStats(
            weekStartText = weekStartText,
            weekEndText = weekEndText,
            dateRangeText = "$weekStartText - $weekEndText",
            sessionCount = sessionCount,
            totalDurationSeconds = totalDurationSeconds,
            totalDurationText = formatDurationText(totalDurationSeconds),
            totalSets = totalSets,
            totalVolume = totalVolume,
        )
    }

    /** 源 `createHeatmapDays`（`:107`）。当月 1 号所在周（周首由 [weekStart] 决定）的周首起，共 42 天。 */
    private fun createHeatmapDays(
        sessions: List<WorkoutSession>,
        now: Long,
        weekStart: WeekStart,
    ): List<CalendarHeatmapDay> {
        val current = calendarFrom(now)
        val monthStart = calendarAt(current.get(Calendar.YEAR), current.get(Calendar.MONTH), 1)
        val gridStart = createWeekStart(monthStart.timeInMillis, weekStart)
        val days = ArrayList<CalendarHeatmapDay>(42)

        for (offset in 0 until 42) {
            val date = calendarAt(
                gridStart.get(Calendar.YEAR),
                gridStart.get(Calendar.MONTH),
                gridStart.get(Calendar.DAY_OF_MONTH) + offset,
            )
            days.add(createHeatmapDay(sessions, date, current.get(Calendar.MONTH)))
        }
        return days
    }

    /** 源 `createHeatmapDay`（`:120`）。 */
    private fun createHeatmapDay(
        sessions: List<WorkoutSession>,
        date: Calendar,
        currentMonth: Int,
    ): CalendarHeatmapDay {
        val dateText = formatDate(date.timeInMillis)
        val dayStart = calendarAt(
            date.get(Calendar.YEAR),
            date.get(Calendar.MONTH),
            date.get(Calendar.DAY_OF_MONTH),
        ).timeInMillis
        val dayEndExclusive = calendarAt(
            date.get(Calendar.YEAR),
            date.get(Calendar.MONTH),
            date.get(Calendar.DAY_OF_MONTH) + 1,
        ).timeInMillis
        var sessionCount = 0
        var totalVolume = 0.0

        for (session in sessions) {
            if (session.startedAt >= dayStart && session.startedAt < dayEndExclusive) {
                sessionCount++
                totalVolume += getSessionVolume(session)
            }
        }

        return CalendarHeatmapDay(
            dateText = dateText,
            dayOfMonth = date.get(Calendar.DAY_OF_MONTH),
            isCurrentMonth = date.get(Calendar.MONTH) == currentMonth,
            sessionCount = sessionCount,
            totalVolume = totalVolume,
            level = createHeatmapLevel(totalVolume),
            accessibilityText = createAccessibilityText(dateText, sessionCount, totalVolume),
        )
    }

    /** 源 `createHeatmapRows`（`:147`）。6 行 × 7 列，行 id `week_<rowIndex>`。 */
    private fun createHeatmapRows(days: List<CalendarHeatmapDay>): List<CalendarHeatmapRow> {
        val rows = ArrayList<CalendarHeatmapRow>(6)
        for (rowIndex in 0 until 6) {
            val rowDays = ArrayList<CalendarHeatmapDay>(7)
            for (dayIndex in 0 until 7) {
                rowDays.add(days[rowIndex * 7 + dayIndex])
            }
            rows.add(CalendarHeatmapRow(rowId = "week_$rowIndex", days = rowDays))
        }
        return rows
    }

    /**
     * 源 `createWeekStart`（`:164`）。当周周首 00:00 —— 周首由 [weekStart] 决定
     * （周一/周日；JS `getDay`：周日=0）。
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

    /** 源 `createHeatmapLevel`（`:174`）。0→0；≤500→1；≤1000→2；≤1500→3；否则 4。 */
    private fun createHeatmapLevel(totalVolume: Double): Int {
        if (totalVolume <= 0) return 0
        if (totalVolume <= 500) return 1
        if (totalVolume <= 1000) return 2
        if (totalVolume <= 1500) return 3
        return 4
    }

    /** 源 `getSessionVolume`（`:190`）。优先按 sets 现算，回落到 `session.totalVolume`。 */
    private fun getSessionVolume(session: WorkoutSession): Double {
        if (session.sets.isNotEmpty()) {
            return calculateVolume(session.sets)
        }
        if (session.totalVolume > 0) {
            return session.totalVolume
        }
        return 0.0
    }

    /** 源 `getSessionCompletedSets`（`:200`）。非热身、重量/次数均 > 0 的组计数。 */
    private fun getSessionCompletedSets(session: WorkoutSession): Int {
        if (session.sets.isNotEmpty()) {
            var count = 0
            for (set in session.sets) {
                if (!set.isWarmup && set.weight > 0 && set.reps > 0) {
                    count++
                }
            }
            return count
        }
        return 0
    }

    /** 源 `calculateVolume`（`:214`）。训练量 = 非热身组 `weight * reps` 求和。 */
    private fun calculateVolume(sets: List<WorkoutSet>): Double {
        var volume = 0.0
        for (set in sets) {
            if (!set.isWarmup) {
                volume += set.weight * set.reps
            }
        }
        return volume
    }

    /** 源 `createAccessibilityText`（`:225`）。 */
    private fun createAccessibilityText(dateText: String, sessionCount: Int, totalVolume: Double): String {
        if (sessionCount <= 0) {
            return "$dateText 无训练"
        }
        return "$dateText $sessionCount 次训练 ${numText(totalVolume)} kg"
    }

    /** 源 `formatMonthTitle`（`:232`）：`YYYY 年 M 月`。 */
    private fun formatMonthTitle(timestamp: Long): String {
        val date = calendarFrom(timestamp)
        return "${date.get(Calendar.YEAR)} 年 ${date.get(Calendar.MONTH) + 1} 月"
    }

    /** 源 `formatDate`（`:237`）：`YYYY-MM-DD`（本地时区）。 */
    private fun formatDate(timestamp: Long): String {
        val date = calendarFrom(timestamp)
        return "${date.get(Calendar.YEAR)}-${padTwoDigits(date.get(Calendar.MONTH) + 1)}-" +
            padTwoDigits(date.get(Calendar.DAY_OF_MONTH))
    }

    /** 源 `padTwoDigits`（`:243`）。 */
    private fun padTwoDigits(value: Int): String = if (value < 10) "0$value" else value.toString()

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

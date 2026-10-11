package com.fittracker.app.data.service

import java.util.Calendar

/**
 * 周窗口计算——周首日由设置（[WeekStart]：周一/周日）决定。
 *
 * 全项目统一的周窗口口径，替换散落的 `if (dow == SUNDAY) 6 else dow - 1` 式硬编码
 * （消费点：WorkoutSessionService / HomeScreen / ProfileScreen / CompleteScreen /
 * FtReviewModel / BodyRecordService / StatsDashboardService / ReviewInsightsService）。
 *
 * 口径：
 * - 星期取值 jsDayOfWeek（0=周日…6=周六），与 [WorkoutSessionService] 既有约定一致；
 * - 窗口 = [周首 00:00, 下个周首 00:00)，本地时区；
 * - 日期字符串口径（[weekDateRange]）为闭区间首尾（`YYYY-MM-DD`），供既有「字符串含端点比较」复用。
 */
object WeekWindow {

    /** jsDayOfWeek 距当周周首的天数偏移（周首当天 = 0）。 */
    fun offsetFromWeekStart(jsDayOfWeek: Int, weekStart: WeekStart): Int =
        if (weekStart == WeekStart.MONDAY) (jsDayOfWeek + 6) % 7 else jsDayOfWeek

    /**
     * 7 天标签（从周首起）。[languageTag] 以 "zh" 开头（或空）取中文单字序（一~日）；
     * 其它取英文缩写（Mon~Sun）。保持"已渲染字符串"数据类型——UI 层读当前语言（[currentLanguageTag]）后传入。
     */
    fun dayLabels(weekStart: WeekStart, languageTag: String = "zh"): List<String> {
        val english = languageTag.isNotBlank() && !languageTag.startsWith("zh")
        val mondayFirst = if (english) LABELS_EN_MONDAY_FIRST else LABELS_ZH_MONDAY_FIRST
        val sundayFirst = if (english) LABELS_EN_SUNDAY_FIRST else LABELS_ZH_SUNDAY_FIRST
        return if (weekStart == WeekStart.MONDAY) mondayFirst else sundayFirst
    }

    /** 含 [timestamp] 的周窗口 [startMillis, endExclusiveMillis)（周首 00:00 → 下个周首 00:00）。 */
    fun weekRange(timestamp: Long, weekStart: WeekStart): Pair<Long, Long> {
        val offset = offsetFromWeekStart(jsDayOfWeek(timestamp), weekStart)
        val calendar: Calendar = Calendar.getInstance().apply {
            timeInMillis = timestamp
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
            add(Calendar.DAY_OF_MONTH, -offset)
        }
        val start: Long = calendar.timeInMillis
        calendar.add(Calendar.DAY_OF_MONTH, 7)
        return start to calendar.timeInMillis
    }

    /**
     * 周窗口的日期字符串（闭区间首尾 `YYYY-MM-DD`）——与 [WorkoutSessionService.weeklyStats]
     * 的既有「字符串含端点比较」口径一致（周首日 ~ 周首日 + 6）。
     */
    fun weekDateRange(timestamp: Long, weekStart: WeekStart): Pair<String, String> {
        val (start, _) = weekRange(timestamp, weekStart)
        val endInclusive: Calendar = Calendar.getInstance().apply {
            timeInMillis = start
            add(Calendar.DAY_OF_MONTH, 6)
        }
        return WorkoutSessionService.formatDate(start) to
            WorkoutSessionService.formatDate(endInclusive.timeInMillis)
    }

    /**
     * 周范围文本——[languageTag] 以 "zh" 开头（或空）：原型格式「M 月 d – d 日」（跨月「M 月 d – M 月 d 日」）；
     * 其它：「Oct 5 – 11」（跨月「Sep 28 – Oct 4」）。en dash 保持。
     */
    fun weekRangeText(timestamp: Long, weekStart: WeekStart, languageTag: String = "zh"): String {
        val (start, _) = weekRange(timestamp, weekStart)
        val startCal: Calendar = Calendar.getInstance().apply { timeInMillis = start }
        val endCal: Calendar = Calendar.getInstance().apply {
            timeInMillis = start
            add(Calendar.DAY_OF_MONTH, 6)
        }
        val startMonth = startCal.get(Calendar.MONTH) + 1
        val startDay = startCal.get(Calendar.DAY_OF_MONTH)
        val endMonth = endCal.get(Calendar.MONTH) + 1
        val endDay = endCal.get(Calendar.DAY_OF_MONTH)
        val english = languageTag.isNotBlank() && !languageTag.startsWith("zh")
        return if (english) {
            if (startMonth == endMonth) {
                "${MONTH_EN[startMonth - 1]} $startDay – $endDay"
            } else {
                "${MONTH_EN[startMonth - 1]} $startDay – ${MONTH_EN[endMonth - 1]} $endDay"
            }
        } else {
            if (startMonth == endMonth) {
                "$startMonth 月 $startDay – $endDay 日"
            } else {
                "$startMonth 月 $startDay – $endMonth 月 $endDay 日"
            }
        }
    }

    /** 当前星期（JS `Date.getDay()` 口径：0=周日…6=周六）。 */
    private fun jsDayOfWeek(millis: Long): Int {
        val calendar: Calendar = Calendar.getInstance()
        calendar.timeInMillis = millis
        return calendar.get(Calendar.DAY_OF_WEEK) - 1 // Calendar 周日=1 → 0=周日
    }

    private val LABELS_ZH_MONDAY_FIRST: List<String> = listOf("一", "二", "三", "四", "五", "六", "日")
    private val LABELS_ZH_SUNDAY_FIRST: List<String> = listOf("日", "一", "二", "三", "四", "五", "六")
    private val LABELS_EN_MONDAY_FIRST: List<String> =
        listOf("Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun")
    private val LABELS_EN_SUNDAY_FIRST: List<String> =
        listOf("Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat")
    private val MONTH_EN: List<String> =
        listOf("Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec")
}

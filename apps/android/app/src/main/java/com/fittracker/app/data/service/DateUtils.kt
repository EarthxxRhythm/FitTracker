package com.fittracker.app.data.service

import java.util.Calendar

/**
 * 日期格式化公共工具。
 *
 * 逐字节等价于现有 6 份内联实现（样板 `ReviewInsightsService.kt:417-421`）：
 * `ReviewInsightsService` / `WorkoutSessionService` / `WorkoutSummaryService` /
 * `stats/PersonalRecordService` / `stats/ReviewDashboardService` / `stats/StatsDashboardService`。
 *
 * 口径保持原样，零行为变更：`Calendar.getInstance()` 取默认时区（本地），
 * 输出 `YYYY-MM-DD`（月/日两位补零，年份不补零）。
 *
 * 可见性说明：本对象位于 `data.service` 包，而 `stats/` 三个 Service 位于
 * `data.service.stats` 子包——Kotlin 子包不继承父包可见性，故 `stats/` 下
 * 引用本对象必须显式 `import com.fittracker.app.data.service.DateUtils`，
 * 不能靠同前缀的包路径省略。同包的 `WeekWindow` 无需 import。
 */
object DateUtils {

    /** 时间戳 → `YYYY-MM-DD`（本地时区）。 */
    fun formatDate(millis: Long): String {
        val calendar = Calendar.getInstance().apply { timeInMillis = millis }
        return "${calendar.get(Calendar.YEAR)}-${padTwoDigits(calendar.get(Calendar.MONTH) + 1)}-" +
            padTwoDigits(calendar.get(Calendar.DAY_OF_MONTH))
    }

    /** 两位补零：`< 10` 前补 `0`。 */
    fun padTwoDigits(value: Int): String = if (value < 10) "0$value" else value.toString()
}

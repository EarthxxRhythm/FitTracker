package com.fittracker.app.data.service

import java.util.Calendar
import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * [WeekWindow] 契约测试——「周开始日」（周一/周日）两态全组合。
 *
 * 纯 JVM 测试（java.util.Calendar + 纯 Kotlin 枚举），不需要 Robolectric。
 * 时间构造统一走默认时区（与实现口径一致）。
 */
class WeekWindowTest {

    private fun at(year: Int, month0: Int, day: Int, hour: Int = 12, minute: Int = 0, second: Int = 0): Long =
        Calendar.getInstance().apply {
            set(year, month0, day, hour, minute, second)
            set(Calendar.MILLISECOND, 0)
        }.timeInMillis

    private fun dayOfWeekOf(millis: Long): Int =
        Calendar.getInstance().apply { timeInMillis = millis }.get(Calendar.DAY_OF_WEEK)

    private fun millisOfDay(millis: Long): Int =
        Calendar.getInstance().apply { timeInMillis = millis }.let {
            it.get(Calendar.HOUR_OF_DAY) * 3600_000 +
                it.get(Calendar.MINUTE) * 60_000 +
                it.get(Calendar.SECOND) * 1000 +
                it.get(Calendar.MILLISECOND)
        }

    // --- offsetFromWeekStart -------------------------------------------------

    @Test
    fun `偏移矩阵 周一态与周日态全组合`() {
        val mondayExpected = mapOf(0 to 6, 1 to 0, 2 to 1, 3 to 2, 4 to 3, 5 to 4, 6 to 5)
        val sundayExpected = mapOf(0 to 0, 1 to 1, 2 to 2, 3 to 3, 4 to 4, 5 to 5, 6 to 6)
        for (js in 0..6) {
            assertEquals("MONDAY js=$js", mondayExpected.getValue(js), WeekWindow.offsetFromWeekStart(js, WeekStart.MONDAY))
            assertEquals("SUNDAY js=$js", sundayExpected.getValue(js), WeekWindow.offsetFromWeekStart(js, WeekStart.SUNDAY))
        }
    }

    // --- dayLabels -----------------------------------------------------------

    @Test
    fun `标签序 周一起始为 一至日 周日起始为 日至六`() {
        assertEquals(listOf("一", "二", "三", "四", "五", "六", "日"), WeekWindow.dayLabels(WeekStart.MONDAY))
        assertEquals(listOf("日", "一", "二", "三", "四", "五", "六"), WeekWindow.dayLabels(WeekStart.SUNDAY))
    }

    @Test
    fun `标签序 英文 周一起始 Mon 起 周日起始 Sun 起`() {
        assertEquals(
            listOf("Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"),
            WeekWindow.dayLabels(WeekStart.MONDAY, "en"),
        )
        assertEquals(
            listOf("Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"),
            WeekWindow.dayLabels(WeekStart.SUNDAY, "en-US"),
        )
    }

    // --- weekRange -----------------------------------------------------------

    @Test
    fun `weekRange 周三锚点 窗口为周首零点起 7 天`() {
        val wednesday = at(2026, 9, 7) // 2026-10-07 周三
        val (monStart, monEnd) = WeekWindow.weekRange(wednesday, WeekStart.MONDAY)
        assertEquals(0, millisOfDay(monStart))
        assertEquals(Calendar.MONDAY, dayOfWeekOf(monStart))
        assertEquals("2026-10-05", WorkoutSessionService.formatDate(monStart))
        assertEquals("2026-10-12", WorkoutSessionService.formatDate(monEnd)) // exclusive：下周一

        val (sunStart, sunEnd) = WeekWindow.weekRange(wednesday, WeekStart.SUNDAY)
        assertEquals(Calendar.SUNDAY, dayOfWeekOf(sunStart))
        assertEquals("2026-10-04", WorkoutSessionService.formatDate(sunStart))
        assertEquals("2026-10-11", WorkoutSessionService.formatDate(sunEnd))
    }

    @Test
    fun `weekRange 周日深夜 周一态仍属当周`() {
        val sundayLate = at(2026, 9, 11, 23, 59, 59) // 2026-10-11 周日
        val (start, _) = WeekWindow.weekRange(sundayLate, WeekStart.MONDAY)
        assertEquals("2026-10-05", WorkoutSessionService.formatDate(start)) // 仍是 10-05 起的一周
    }

    @Test
    fun `weekRange 跨年 2026-01-01 属 2025-12-29 起的一周`() {
        val newYear = at(2026, 0, 1) // 2026-01-01 周四
        val (start, _) = WeekWindow.weekRange(newYear, WeekStart.MONDAY)
        assertEquals("2025-12-29", WorkoutSessionService.formatDate(start))
        assertEquals(Calendar.MONDAY, dayOfWeekOf(start))
    }

    // --- weekDateRange -------------------------------------------------------

    @Test
    fun `weekDateRange 闭区间首尾 两态`() {
        val wednesday = at(2026, 9, 7)
        assertEquals("2026-10-05" to "2026-10-11", WeekWindow.weekDateRange(wednesday, WeekStart.MONDAY))
        assertEquals("2026-10-04" to "2026-10-10", WeekWindow.weekDateRange(wednesday, WeekStart.SUNDAY))
    }

    // --- weekRangeText（原型格式「M 月 d – d 日」，en dash） -------------------

    @Test
    fun `weekRangeText 同月 两态`() {
        val wednesday = at(2026, 9, 7) // 2026-10-07 周三
        assertEquals("10 月 5 – 11 日", WeekWindow.weekRangeText(wednesday, WeekStart.MONDAY))
        assertEquals("10 月 4 – 10 日", WeekWindow.weekRangeText(wednesday, WeekStart.SUNDAY))
    }

    @Test
    fun `weekRangeText 跨月 2026-10-01 周一态含 9 月尾`() {
        val oct1 = at(2026, 9, 1) // 2026-10-01 周四
        // 周一态：09-28 ~ 10-04，跨月格式「M 月 d – M 月 d 日」
        assertEquals("9 月 28 – 10 月 4 日", WeekWindow.weekRangeText(oct1, WeekStart.MONDAY))
    }

    @Test
    fun `weekRangeText 英文格式 同月与跨月`() {
        val wednesday = at(2026, 9, 7) // 2026-10-07 周三
        assertEquals("Oct 5 – 11", WeekWindow.weekRangeText(wednesday, WeekStart.MONDAY, "en"))
        assertEquals("Oct 4 – 10", WeekWindow.weekRangeText(wednesday, WeekStart.SUNDAY, "en"))
        val oct1 = at(2026, 9, 1) // 2026-10-01 周四
        assertEquals("Sep 28 – Oct 4", WeekWindow.weekRangeText(oct1, WeekStart.MONDAY, "en"))
    }
}

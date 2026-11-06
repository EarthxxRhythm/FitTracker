package com.fittracker.app.data.service

import java.util.Calendar
import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * [DateUtils] 逐字节等价测试——「新旧 `formatDate` / `padTwoDigits` 输出一致」的可执行证据。
 *
 * 背景：`DateUtils` 的提取是**行为保持重构**，验收要求新旧实现输出逐字节一致。
 * 原计划的 check-parity 门不含日期判据（路径亦错），不能充当该证明，故以本测试兑现：
 *
 * 1. 金值（golden）——月 1-9 / 日 1-9 补零、年末边界、闰日等确定字符串；
 * 2. 交叉比对——[DateUtils.formatDate] 与 [legacyFormatDate]（旧实现的**独立逐字副本**）
 *    在同一时间戳矩阵上逐值相等；另断言委托壳 [WorkoutSessionService.formatDate] 与参考实现一致。
 *    注意不可用 [WorkoutSessionService.formatDate] 当参考——它已改为委托 [DateUtils]，
 *    自我比对恒真、无防回归价值。
 *
 * 时间构造一律取**本地正午**（`hour = 12`）：正午在任意时区都落在当日，金值字符串与时区无关。
 */
class DateUtilsTest {

    private fun at(
        year: Int,
        month0: Int,
        day: Int,
        hour: Int = 12,
        minute: Int = 0,
        second: Int = 0,
    ): Long = Calendar.getInstance().apply {
        clear()
        set(year, month0, day, hour, minute, second)
    }.timeInMillis

    // --- formatDate 金值 -----------------------------------------------------

    @Test
    fun `formatDate 月 1 至 9 补零`() {
        val expected = mapOf(
            0 to "2026-01-15",
            1 to "2026-02-15",
            2 to "2026-03-15",
            3 to "2026-04-15",
            4 to "2026-05-15",
            5 to "2026-06-15",
            6 to "2026-07-15",
            7 to "2026-08-15",
            8 to "2026-09-15",
        )
        for ((month0, golden) in expected) {
            assertEquals("month0=$month0", golden, DateUtils.formatDate(at(2026, month0, 15)))
        }
    }

    @Test
    fun `formatDate 日 1 至 9 补零`() {
        val expected = mapOf(
            1 to "2026-10-01",
            2 to "2026-10-02",
            3 to "2026-10-03",
            4 to "2026-10-04",
            5 to "2026-10-05",
            6 to "2026-10-06",
            7 to "2026-10-07",
            8 to "2026-10-08",
            9 to "2026-10-09",
        )
        for ((day, golden) in expected) {
            assertEquals("day=$day", golden, DateUtils.formatDate(at(2026, 9, day)))
        }
    }

    @Test
    fun `formatDate 月日同为个位数 双补零`() {
        assertEquals("2026-01-05", DateUtils.formatDate(at(2026, 0, 5)))
        assertEquals("2026-09-09", DateUtils.formatDate(at(2026, 8, 9)))
    }

    @Test
    fun `formatDate 月日两位数直出 不补零`() {
        assertEquals("2026-10-10", DateUtils.formatDate(at(2026, 9, 10)))
        assertEquals("2026-12-31", DateUtils.formatDate(at(2026, 11, 31)))
        assertEquals("2026-11-30", DateUtils.formatDate(at(2026, 10, 30)))
    }

    @Test
    fun `formatDate 年末边界 12-31 与次年 01-01`() {
        assertEquals("2026-12-31", DateUtils.formatDate(at(2026, 11, 31, 23, 59, 59)))
        assertEquals("2027-01-01", DateUtils.formatDate(at(2027, 0, 1, 0, 0, 0)))
        assertEquals("2026-12-09", DateUtils.formatDate(at(2026, 11, 9)))
    }

    @Test
    fun `formatDate 闰日 2024-02-29 与平年 02-28`() {
        assertEquals("2024-02-29", DateUtils.formatDate(at(2024, 1, 29)))
        assertEquals("2024-03-01", DateUtils.formatDate(at(2024, 2, 1)))
        assertEquals("2026-02-28", DateUtils.formatDate(at(2026, 1, 28)))
    }

    // --- padTwoDigits --------------------------------------------------------

    @Test
    fun `padTwoDigits 0 至 9 补零为 00 至 09`() {
        val expected = listOf("00", "01", "02", "03", "04", "05", "06", "07", "08", "09")
        for (value in 0..9) {
            assertEquals("value=$value", expected[value], DateUtils.padTwoDigits(value))
        }
    }

    @Test
    fun `padTwoDigits 大于等于 10 直出`() {
        assertEquals("10", DateUtils.padTwoDigits(10))
        assertEquals("12", DateUtils.padTwoDigits(12))
        assertEquals("31", DateUtils.padTwoDigits(31))
        assertEquals("99", DateUtils.padTwoDigits(99))
    }

    // --- 新旧实现交叉比对（逐字节） ------------------------------------------

    @Test
    fun `formatDate 与既有 WorkoutSessionService 副本逐字节一致`() {
        val samples = listOf(
            at(2026, 0, 5),
            at(2026, 8, 9),
            at(2026, 9, 1),
            at(2026, 9, 7),
            at(2026, 11, 31, 23, 59, 59),
            at(2027, 0, 1, 0, 0, 0),
            at(2024, 1, 29),
            at(2024, 2, 1),
            at(2026, 10, 30),
            at(2026, 11, 9),
        )
        for (millis in samples) {
            assertEquals(
                "millis=$millis / 参考实现",
                legacyFormatDate(millis),
                DateUtils.formatDate(millis),
            )
            assertEquals(
                "millis=$millis / 委托壳",
                legacyFormatDate(millis),
                WorkoutSessionService.formatDate(millis),
            )
        }
    }

    /**
     * 旧实现的逐字副本（`Calendar.getInstance()` + `timeInMillis` + 两位补零）。
     *
     * 作为**独立参考**：不调用 [WorkoutSessionService.formatDate]（已委托 [DateUtils]，
     * 自比恒真）。将来若 [DateUtils] 被改坏而金值未覆盖到，本条会红。
     */
    private fun legacyFormatDate(millis: Long): String {
        val calendar = Calendar.getInstance().apply { timeInMillis = millis }
        val pad = { value: Int -> if (value < 10) "0$value" else value.toString() }
        return "${calendar.get(Calendar.YEAR)}-${pad(calendar.get(Calendar.MONTH) + 1)}-" +
            pad(calendar.get(Calendar.DAY_OF_MONTH))
    }
}

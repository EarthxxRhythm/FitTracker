package com.fittracker.app.notifications

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.Calendar

/**
 * 训练提醒判定的 JVM 契约测试（计划 A6 · Wave 4）。
 *
 * 两层：
 * 1. [workoutReminderDecision] 的组合穷举（3 个入参 × 全取值域 = 12 组）——语义硬约束：
 *    开关关不发、今天已训练不发、休息日不发、无计划不受训练日约束、其余发。
 * 2. [ReminderScheduler.initialDelayMillis] 的落点断言——「首延至下一个 19:30」是计划
 *    明写的调度语义（19:30 前 → 当日，已过 / 恰好 → 次日），否则提醒时刻静默漂移而无人察觉。
 *
 * 无 Robolectric：两个被测函数均为纯 JVM 计算（不触碰 Android 框架）。
 */
class ReminderDecisionTest {

    // ── 1. 判定函数：组合穷举 ────────────────────────────────────────────────

    @Test
    fun `开关关闭时任何条件都不发`() {
        assertFalse(workoutReminderDecision(enabled = false, hasSessionToday = false, isTrainingDay = true))
        assertFalse(workoutReminderDecision(enabled = false, hasSessionToday = false, isTrainingDay = false))
        assertFalse(workoutReminderDecision(enabled = false, hasSessionToday = false, isTrainingDay = null))
        assertFalse(workoutReminderDecision(enabled = false, hasSessionToday = true, isTrainingDay = true))
        assertFalse(workoutReminderDecision(enabled = false, hasSessionToday = true, isTrainingDay = false))
        assertFalse(workoutReminderDecision(enabled = false, hasSessionToday = true, isTrainingDay = null))
    }

    @Test
    fun `今天已训练则不再打扰_即便开关开且是训练日`() {
        assertFalse(workoutReminderDecision(enabled = true, hasSessionToday = true, isTrainingDay = true))
        assertFalse(workoutReminderDecision(enabled = true, hasSessionToday = true, isTrainingDay = false))
        assertFalse(workoutReminderDecision(enabled = true, hasSessionToday = true, isTrainingDay = null))
    }

    @Test
    fun `开关开且今天未训练且是训练日则发`() {
        assertTrue(workoutReminderDecision(enabled = true, hasSessionToday = false, isTrainingDay = true))
    }

    @Test
    fun `休息日不发`() {
        assertFalse(workoutReminderDecision(enabled = true, hasSessionToday = false, isTrainingDay = false))
    }

    @Test
    fun `无当前计划时不受训练日约束_照发`() {
        assertTrue(workoutReminderDecision(enabled = true, hasSessionToday = false, isTrainingDay = null))
    }

    @Test
    fun `全部 12 种组合与期望公式一致`() {
        for (enabled in listOf(false, true)) {
            for (hasSessionToday in listOf(false, true)) {
                for (isTrainingDay in listOf(null, false, true)) {
                    val expected = enabled && !hasSessionToday && (isTrainingDay == null || isTrainingDay)
                    assertEquals(
                        "enabled=$enabled hasSessionToday=$hasSessionToday isTrainingDay=$isTrainingDay",
                        expected,
                        workoutReminderDecision(enabled, hasSessionToday, isTrainingDay),
                    )
                }
            }
        }
    }

    // ── 2. 调度首延：下一个 19:30 ────────────────────────────────────────────

    @Test
    fun `19 30 之前_首延落在当日 19 30`() {
        val now = localMillis(2026, Calendar.MARCH, 10, 12, 0)
        val delay = ReminderScheduler.initialDelayMillis(now)

        assertTrue("首延应为正：$delay", delay > 0L)
        assertTrue("首延不超过一天：$delay", delay <= 24L * 60 * 60 * 1000)
        assertWallClock(now + delay, year = 2026, month = Calendar.MARCH, day = 10, hour = 19, minute = 30)
    }

    @Test
    fun `19 30 已过_首延落在次日 19 30`() {
        val now = localMillis(2026, Calendar.MARCH, 10, 20, 0)
        val delay = ReminderScheduler.initialDelayMillis(now)

        assertTrue("首延应为正：$delay", delay > 0L)
        assertWallClock(now + delay, year = 2026, month = Calendar.MARCH, day = 11, hour = 19, minute = 30)
    }

    @Test
    fun `恰好 19 30 视为已到_顺延次日`() {
        val now = localMillis(2026, Calendar.MARCH, 10, 19, 30)
        val delay = ReminderScheduler.initialDelayMillis(now)

        assertWallClock(now + delay, year = 2026, month = Calendar.MARCH, day = 11, hour = 19, minute = 30)
    }

    @Test
    fun `19 29 起首延为 1 分钟`() {
        val now = localMillis(2026, Calendar.MARCH, 10, 19, 29)

        assertEquals(60_000L, ReminderScheduler.initialDelayMillis(now))
    }

    @Test
    fun `提醒时刻常量为 19 30`() {
        assertEquals(19, ReminderScheduler.REMINDER_HOUR)
        assertEquals(30, ReminderScheduler.REMINDER_MINUTE)
        assertEquals(24L, ReminderScheduler.REPEAT_INTERVAL_HOURS)
    }

    // ── 内部：日期构造 / 断言 ────────────────────────────────────────────────

    /** 本地时区下 `yyyy-MM-dd HH:mm:00.000` 的毫秒时刻。 */
    private fun localMillis(year: Int, month: Int, day: Int, hour: Int, minute: Int): Long =
        Calendar.getInstance().apply {
            clear()
            set(year, month, day, hour, minute, 0)
        }.timeInMillis

    /** 断言某毫秒时刻的**墙钟**字段（按默认时区）——跨夏令时也能表达"次日 19:30"的语义。 */
    private fun assertWallClock(
        millis: Long,
        year: Int,
        month: Int,
        day: Int,
        hour: Int,
        minute: Int,
    ) {
        val at: Calendar = Calendar.getInstance().apply { timeInMillis = millis }
        val actual = "${at.get(Calendar.YEAR)}-${at.get(Calendar.MONTH)}-${at.get(Calendar.DAY_OF_MONTH)} " +
            "${at.get(Calendar.HOUR_OF_DAY)}:${at.get(Calendar.MINUTE)}"
        assertEquals("$year-$month-$day $hour:$minute", actual)
    }
}

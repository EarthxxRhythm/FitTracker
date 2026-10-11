package com.fittracker.app.notifications

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/**
 * 成就触发纯函数契约测试（计划 A6 第 5 条）——连续训练天数与里程碑命中。
 *
 * 纯 JVM（无 Robolectric）：只覆盖 [achievementMilestone] 与 [currentStreak] 两个判定函数；
 * 通知投递与开关接线属真机/集成面。
 */
class AchievementTriggerTest {

    // --- achievementMilestone：仅命中 3/7/14/30 ---------------------------------

    @Test
    fun `里程碑仅命中 3 7 14 30`() {
        assertEquals(3, achievementMilestone(3))
        assertEquals(7, achievementMilestone(7))
        assertEquals(14, achievementMilestone(14))
        assertEquals(30, achievementMilestone(30))
        assertNull(achievementMilestone(0))
        assertNull(achievementMilestone(1))
        assertNull(achievementMilestone(6))
        assertNull(achievementMilestone(8))
        assertNull(achievementMilestone(31))
    }

    // --- currentStreak：截至今天的连续训练天数 -----------------------------------

    @Test
    fun `今天有训练 从今天往回连数`() {
        val dates = listOf("2026-10-05", "2026-10-06", "2026-10-07")
        assertEquals(3, currentStreak(dates, today = "2026-10-07"))
    }

    @Test
    fun `今天未训练 从昨天起算`() {
        val dates = listOf("2026-10-05", "2026-10-06") // 昨天 10-06 有训练
        assertEquals(2, currentStreak(dates, today = "2026-10-07"))
    }

    @Test
    fun `断档 昨天与今天都无训练 返回 0`() {
        val dates = listOf("2026-10-04", "2026-10-05") // 最后训练 10-05；今天 10-07 前一天无
        assertEquals(0, currentStreak(dates, today = "2026-10-07"))
    }

    @Test
    fun `中间缺一天 只算到断点`() {
        val dates = listOf("2026-10-03", "2026-10-05", "2026-10-06", "2026-10-07")
        // 10-05..10-07 连续 3 天；10-03 被 10-04 缺档隔断，不计入
        assertEquals(3, currentStreak(dates, today = "2026-10-07"))
    }

    @Test
    fun `跨月与跨年边界均连续`() {
        assertEquals(3, currentStreak(listOf("2026-09-30", "2026-10-01", "2026-10-02"), today = "2026-10-02"))
        assertEquals(2, currentStreak(listOf("2025-12-31", "2026-01-01"), today = "2026-01-01"))
    }

    @Test
    fun `空集合返回 0`() {
        assertEquals(0, currentStreak(emptyList(), today = "2026-10-07"))
    }
}

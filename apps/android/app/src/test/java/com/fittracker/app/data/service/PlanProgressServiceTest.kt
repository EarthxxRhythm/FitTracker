package com.fittracker.app.data.service

import com.fittracker.app.data.model.WorkoutSession
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * [PlanProgressService] 纯函数聚合口径。
 *
 * 覆盖：空输入 / 单计划多会话 / 多计划混合 / 无匹配 planId / 缺 dayId。
 * 这些正是「会话里有 planId 但没人按计划聚合」补上后的核心契约。
 */
class PlanProgressServiceTest {

    private fun session(
        sessionId: String,
        planId: String,
        dayId: String,
        endedAt: Long,
        durationSeconds: Int = 1800,
    ): WorkoutSession = WorkoutSession(
        sessionId = sessionId,
        planId = planId,
        dayId = dayId,
        startedAt = endedAt - durationSeconds * 1000L,
        endedAt = endedAt,
        durationSeconds = durationSeconds,
        totalSets = 0,
        totalVolume = 0.0,
        fatigueScore = 0.0,
        notes = "",
        sets = emptyList(),
    )

    @Test
    fun `空会话返回零态`() {
        val summary = PlanProgressService.createSummary(emptyList(), "plan_a")
        assertEquals("plan_a", summary.planId)
        assertEquals(0, summary.totalSessions)
        assertEquals(0L, summary.lastTrainedAt)
        assertTrue(summary.trainedDayIds.isEmpty())
        assertTrue(summary.dayProgress.isEmpty())
    }

    @Test
    fun `planId 为空时不把未归属会话算进来`() {
        val sessions = listOf(session("s1", "plan_a", "current_plan_day_1", 1000L))
        val summary = PlanProgressService.createSummary(sessions, "")
        assertEquals(0, summary.totalSessions)
        assertFalse(PlanProgressService.isDayTrained(summary, "current_plan_day_1"))
    }

    @Test
    fun `单计划多会话按训练日聚合`() {
        val sessions = listOf(
            session("s1", "plan_a", "current_plan_day_1", 1_000L, 1800),
            session("s2", "plan_a", "current_plan_day_1", 3_000L, 2400),
            session("s3", "plan_a", "current_plan_day_2", 2_000L, 1200),
        )
        val summary = PlanProgressService.createSummary(sessions, "plan_a")

        assertEquals(3, summary.totalSessions)
        assertEquals(5400, summary.totalDurationSeconds)
        assertEquals(3_000L, summary.lastTrainedAt)
        assertEquals(listOf("current_plan_day_1", "current_plan_day_2"), summary.trainedDayIds)

        val day1 = summary.dayProgress.first { it.dayId == "current_plan_day_1" }
        assertEquals(2, day1.sessionCount)
        assertEquals(4200, day1.totalDurationSeconds)
        assertEquals(3_000L, day1.lastTrainedAt)
    }

    @Test
    fun `多计划混合只统计目标计划`() {
        val sessions = listOf(
            session("s1", "plan_a", "current_plan_day_1", 1_000L),
            session("s2", "plan_b", "current_plan_day_1", 2_000L),
            session("s3", "plan_a", "current_plan_day_2", 3_000L),
        )
        val summary = PlanProgressService.createSummary(sessions, "plan_a")
        assertEquals(2, summary.totalSessions)
        assertEquals(3_000L, summary.lastTrainedAt)
        assertTrue(PlanProgressService.isDayTrained(summary, "current_plan_day_2"))
    }

    @Test
    fun `无匹配 planId 返回零态`() {
        val sessions = listOf(session("s1", "plan_b", "current_plan_day_1", 1_000L))
        val summary = PlanProgressService.createSummary(sessions, "plan_a")
        assertEquals(0, summary.totalSessions)
        assertTrue(summary.dayProgress.isEmpty())
    }

    @Test
    fun `缺 dayId 的会话计入总次数但不进训练日聚合`() {
        val sessions = listOf(
            session("s1", "plan_a", "", 1_000L),
            session("s2", "plan_a", "current_plan_day_1", 2_000L),
        )
        val summary = PlanProgressService.createSummary(sessions, "plan_a")
        assertEquals(2, summary.totalSessions)
        assertEquals(listOf("current_plan_day_1"), summary.trainedDayIds)
    }

    @Test
    fun `isDayTrained 对空 dayId 恒为 false`() {
        val summary = PlanProgressService.createEmpty("plan_a")
        assertFalse(PlanProgressService.isDayTrained(summary, ""))
    }

    @Test
    fun `启用计划后 UserPlan id 与预置 id 不等时仍能聚合`() {
        // 真实链路：enablePlan 生成 UserPlan.id = "user_plan_<时间戳>"，会话落的是它；
        // 计划组详情拿到的是预置 id。只比预置 id 会全部落空。
        val sessions = listOf(
            session("s1", "user_plan_1700000000000", "current_plan_day_1", 1_000L),
            session("s2", "user_plan_1700000000000", "current_plan_day_2", 2_000L),
        )
        val summary = PlanProgressService.createSummaryForIds(
            sessions,
            "preset_ppl",
            listOf("preset_ppl", "user_plan_1700000000000"),
        )
        assertEquals(2, summary.totalSessions)
        assertTrue(PlanProgressService.isDayTrained(summary, "current_plan_day_2"))
    }

    @Test
    fun `只传预置 id 时 user_plan 会话不计入`() {
        val sessions = listOf(session("s1", "user_plan_1700000000000", "current_plan_day_1", 1_000L))
        val summary = PlanProgressService.createSummary(sessions, "preset_ppl")
        assertEquals(0, summary.totalSessions)
    }

    @Test
    fun `sessionCountForDay 返回该日完成次数`() {
        val sessions = listOf(
            session("s1", "plan_a", "current_plan_day_1", 1_000L),
            session("s2", "plan_a", "current_plan_day_1", 2_000L),
            session("s3", "plan_a", "current_plan_day_2", 3_000L),
        )
        val summary = PlanProgressService.createSummary(sessions, "plan_a")
        assertEquals(2, PlanProgressService.sessionCountForDay(summary, "current_plan_day_1"))
        assertEquals(1, PlanProgressService.sessionCountForDay(summary, "current_plan_day_2"))
        assertEquals(0, PlanProgressService.sessionCountForDay(summary, "current_plan_day_3"))
        assertEquals(0, PlanProgressService.sessionCountForDay(summary, ""))
    }
}

package com.fittracker.app.data.service

import com.fittracker.app.data.model.WorkoutSession
import com.fittracker.app.data.model.WorkoutSet
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.Calendar

/**
 * Wave 3b 训练摘要 / 回顾洞察服务契约测试。
 *
 * 被测：`WorkoutSummaryService`（源 `shared/services/WorkoutSummaryService.ets`）与
 * `ReviewInsightsService`（源 `shared/services/ReviewInsightsService.ets`，行号见各断言注释）。
 *
 * 二者均为纯函数（`ContentRepository` 仅在内存索引上查询，未装载时回落 id），
 * 无需 Robolectric，用普通 JUnit。日期相关断言一律以本地 `Calendar` 构造时间戳，
 * 避免时区差异。
 */
class WorkoutSummaryTest {

    // ────────────────────────── 构造工具 ──────────────────────────

    /** 本地时区时间戳（对齐 JS `new Date(y, m, d, h, min)`）。 */
    private fun lt(year: Int, month1: Int, day: Int, hour: Int = 0, minute: Int = 0): Long {
        val cal = Calendar.getInstance()
        cal.clear()
        cal.set(year, month1 - 1, day, hour, minute, 0)
        return cal.timeInMillis
    }

    private fun set(
        exerciseId: String,
        weight: Double,
        reps: Int,
        isWarmup: Boolean = false,
    ): WorkoutSet = WorkoutSet(
        setId = "set", exerciseId = exerciseId, weight = weight, reps = reps, rpe = 0.0, isWarmup = isWarmup,
    )

    private fun session(
        sessionId: String = "s",
        startedAt: Long = 0L,
        durationSeconds: Int = 0,
        notes: String = "",
        sets: List<WorkoutSet> = emptyList(),
        dayId: String = "day_1",
        totalVolume: Double = 0.0,
        fatigueScore: Double = 0.0,
    ): WorkoutSession = WorkoutSession(
        sessionId = sessionId, planId = "plan", dayId = dayId,
        startedAt = startedAt, endedAt = startedAt, durationSeconds = durationSeconds,
        totalSets = sets.size, totalVolume = totalVolume, fatigueScore = fatigueScore, notes = notes, sets = sets,
    )

    // ══════════════════ 1. WorkoutSummaryService ══════════════════

    @Test
    fun `摘要基于 sets 统计完成组并回落到 notes 的 target`() {
        // 源 WorkoutSummaryService.ets:43 createSummaryWithHistory
        val s = session(
            sessionId = "s1",
            durationSeconds = 3900,
            fatigueScore = 7.5,
            notes = "target_sets=5; completed_sets=1",
            sets = listOf(
                set("bench", 100.0, 5), // 计入：500
                set("bench", 60.0, 10, isWarmup = true), // 热身排除
                set("bench", 80.0, 8), // 计入：640
            ),
        )
        val summary = WorkoutSummaryService.createSummary(s)
        assertTrue(summary.hasSession)
        assertEquals("s1", summary.sessionId)
        assertEquals("plan", summary.planId)
        assertEquals("day_1", summary.dayId)
        assertEquals(3900, summary.durationSeconds)
        assertEquals("1 小时 5 分钟", summary.durationText)
        assertEquals(2, summary.completedSets) // sets 有值 → 按组统计（热身排除）
        assertEquals(5, summary.targetSets) // notes target_sets=5
        assertEquals(40, summary.completionRate) // round(2*100/5)
        assertEquals(1140.0, summary.totalVolume, 1e-9) // 100*5 + 80*8
        assertEquals(7.5, summary.fatigueScore, 1e-9)
    }

    @Test
    fun `无 sets 时完成组与 target 均从 notes 解析`() {
        // 源 getCompletedSets :102 / getTargetSets :113 / getNumberAfterPrefix :240
        val summary = WorkoutSummaryService.createSummary(
            session(sessionId = "s1", notes = "target_sets=10; completed_sets=7"),
        )
        assertEquals(7, summary.completedSets)
        assertEquals(10, summary.targetSets)
        assertEquals(70, summary.completionRate)
        assertEquals(0.0, summary.totalVolume, 1e-9)
    }

    @Test
    fun `target 前缀缺失时回落完成组数`() {
        // 源 getTargetSets :113（parsed <= 0 回落 fallbackTargetSets）
        val summary = WorkoutSummaryService.createSummary(
            session(sessionId = "s1", notes = "completed_sets=4"),
        )
        assertEquals(4, summary.completedSets)
        assertEquals(4, summary.targetSets)
        assertEquals(100, summary.completionRate)
    }

    @Test
    fun `无 sets 时训练量回落到 session_totalVolume`() {
        // 源 getTotalVolume :121
        val summary = WorkoutSummaryService.createSummary(
            session(sessionId = "s1", totalVolume = 1500.0),
        )
        assertEquals(1500.0, summary.totalVolume, 1e-9)
    }

    @Test
    fun `时长文案各档位`() {
        // 源 formatDuration :81
        assertEquals("0 分钟", WorkoutSummaryService.formatDuration(0))
        assertEquals("0 分钟", WorkoutSummaryService.formatDuration(-5))
        assertEquals("1 分钟内", WorkoutSummaryService.formatDuration(30))
        assertEquals("5 分钟", WorkoutSummaryService.formatDuration(300))
        assertEquals("1 小时", WorkoutSummaryService.formatDuration(3600))
        assertEquals("1 小时 5 分钟", WorkoutSummaryService.formatDuration(3900))
        assertEquals("2 小时", WorkoutSummaryService.formatDuration(7200))
    }

    @Test
    fun `空摘要字段归零`() {
        // 源 createEmptySummary :63
        val e = WorkoutSummaryService.createEmptySummary()
        assertFalse(e.hasSession)
        assertEquals("", e.sessionId)
        assertEquals(0, e.durationSeconds)
        assertEquals("0 分钟", e.durationText)
        assertEquals(0, e.completedSets)
        assertEquals(0, e.targetSets)
        assertEquals(0, e.completionRate)
        assertEquals(0.0, e.totalVolume, 1e-9)
        assertEquals(0.0, e.fatigueScore, 1e-9)
        assertTrue(e.exerciseRecords.isEmpty())
    }

    @Test
    fun `动作记录跨历史取最佳 1RM 并按当前会话动作顺序排列`() {
        // 源 createExerciseRecords :141 / updateExerciseRecord :155 / isBetterExerciseRecord :171
        val t1 = lt(2024, 1, 1, 10)
        val t2 = lt(2024, 1, 2, 10)
        val older = session(sessionId = "old", startedAt = t1, sets = listOf(set("ex_bench", 100.0, 5))) // 1RM 117
        val current = session(
            sessionId = "cur", startedAt = t2,
            sets = listOf(set("ex_bench", 90.0, 5), set("ex_squat", 120.0, 3)), // 105 / 132
        )
        val summary = WorkoutSummaryService.createSummaryWithHistory(current, listOf(older, current))

        assertEquals(2, summary.exerciseRecords.size)
        val bench = summary.exerciseRecords[0]
        assertEquals("ex_bench", bench.exerciseId)
        assertEquals("ex_bench", bench.exerciseName) // 内容库未装载 → 回落 id
        assertEquals(117, bench.bestOneRepMax) // round(116.67)
        assertEquals(100.0, bench.bestWeight, 1e-9)
        assertEquals(5, bench.bestReps)
        assertEquals("2024-01-01", bench.dateText)
        val squat = summary.exerciseRecords[1]
        assertEquals("ex_squat", squat.exerciseId)
        assertEquals(132, squat.bestOneRepMax) // round(120 * (1 + 3/30))
        assertEquals(120.0, squat.bestWeight, 1e-9)
        assertEquals(3, squat.bestReps)
        assertEquals("2024-01-02", squat.dateText)
    }

    @Test
    fun `同 1RM 取日期更晚的一次`() {
        // 源 isBetterExerciseRecord :171（相等时 dateText 更晚者胜）
        val t1 = lt(2024, 1, 1, 10)
        val t2 = lt(2024, 1, 3, 10)
        val older = session(sessionId = "old", startedAt = t1, sets = listOf(set("ex_x", 100.0, 5))) // 117
        val newer = session(sessionId = "new", startedAt = t2, sets = listOf(set("ex_x", 100.0, 5))) // 117
        val summary = WorkoutSummaryService.createSummaryWithHistory(newer, listOf(older, newer))
        val rec = summary.exerciseRecords.single()
        assertEquals(117, rec.bestOneRepMax)
        assertEquals("2024-01-03", rec.dateText)
    }

    // ══════════════════ 2. ReviewInsightsService ══════════════════

    @Test
    fun `最近筛选选项计数与解锁状态`() {
        // 源 createRecentFilters :41 / createFilterOption :134 / matchesFilter :158
        val now = lt(2024, 1, 17, 12)
        val sessions = listOf(
            session(sessionId = "w7", startedAt = lt(2024, 1, 15, 10)), // 7 天内
            session(sessionId = "w30", startedAt = lt(2024, 1, 5, 10)), // 30 天内
            session(sessionId = "old", startedAt = lt(2023, 12, 1, 10)), // 超 30 天
        )
        val locked = ReviewInsightsService.createRecentFilters(sessions, now, unlimitedHistoryUnlocked = false)
        assertEquals(listOf("最近 7 天", "最近 30 天", "全部记录"), locked.map { it.label })
        assertEquals(1, locked[0].matchedSessionCount)
        assertEquals(2, locked[1].matchedSessionCount)
        assertEquals(3, locked[2].matchedSessionCount)
        assertFalse(locked[0].locked)
        assertTrue(locked[2].locked)
        assertEquals("升级 Pro 后查看全部历史记录", locked[2].description)

        val unlocked = ReviewInsightsService.createRecentFilters(sessions, now, unlimitedHistoryUnlocked = true)
        assertFalse(unlocked[2].locked)
        assertEquals("查看所有已保存训练", unlocked[2].description)
    }

    @Test
    fun `all_sessions 未解锁时解析为最近 30 天`() {
        // 源 resolveFilterId :87
        assertEquals("recent_30_days", ReviewInsightsService.resolveFilterId("all_sessions", false))
        assertEquals("all_sessions", ReviewInsightsService.resolveFilterId("all_sessions", true))
        assertEquals("recent_7_days", ReviewInsightsService.resolveFilterId("recent_7_days", false))
    }

    @Test
    fun `最近记录上限 6 且最新在前`() {
        // 源 filterRecentRecords :61（recentRecordLimit = 6，:37）+ createRecentRecord :168
        val now = lt(2024, 1, 17, 12)
        // 升序（最早在前），s8 最新
        val sessions = (1..8).map { i ->
            session(
                sessionId = "s$i",
                startedAt = now - (9 - i) * 3600_000L,
                durationSeconds = 1800,
                notes = "target_sets=3; completed_sets=3",
                dayId = "day_2",
            )
        }
        val records = ReviewInsightsService.filterRecentRecords(
            sessions, "recent_7_days", now, unlimitedHistoryUnlocked = false,
        )
        assertEquals(6, records.size)
        val first = records.first()
        assertEquals("s8", first.sessionId)
        assertEquals("s3", records.last().sessionId)
        assertEquals("第 2 天", first.dayLabel)
        assertEquals("30 分钟", first.durationText)
        assertEquals(3, first.completedSets)
        assertEquals(3, first.targetSets)
        assertEquals(100, first.completionRate)
        assertEquals("3/3 组", first.completionText) // 源 :177（无 ` · R%` 后缀）
        assertEquals("0 kg", first.volumeText)
    }

    @Test
    fun `all_sessions 未解锁时过滤剔除超 30 天记录`() {
        val now = lt(2024, 1, 17, 12)
        val sessions = listOf(
            session(sessionId = "recent", startedAt = lt(2024, 1, 10, 10)), // 7 天前（在 30 天内）
            session(sessionId = "old", startedAt = lt(2023, 12, 1, 10)), // 超 30 天
        )
        val records = ReviewInsightsService.filterRecentRecords(
            sessions, "all_sessions", now, unlimitedHistoryUnlocked = false,
        )
        assertEquals(1, records.size)
        assertEquals("recent", records.single().sessionId)
    }

    @Test
    fun `周趋势近 6 周聚合与文案`() {
        // 源 createWeeklyTrendItems :94 / createWeeklyTrendItem :203 / createWeeklySummaryText :256 / createWeekStart :306
        val now = lt(2024, 1, 17, 12) // 周三 → 本周一 2024-01-15
        val sessions = listOf(
            session(
                sessionId = "thisweek", startedAt = lt(2024, 1, 16, 10), durationSeconds = 1800,
                notes = "target_sets=4; completed_sets=4", dayId = "day_5",
            ),
            session(
                sessionId = "lastweek", startedAt = lt(2024, 1, 10, 10), durationSeconds = 1800,
                notes = "target_sets=4; completed_sets=2", dayId = "day_6",
            ),
            session(sessionId = "old", startedAt = lt(2023, 12, 1, 10)),
        )
        val items = ReviewInsightsService.createWeeklyTrendItems(sessions, now, WeekStart.MONDAY)
        assertEquals(6, items.size)

        val thisWeek = items[0]
        assertEquals("本周", thisWeek.weekLabel)
        assertEquals(1, thisWeek.sessionCount)
        assertEquals(1800, thisWeek.totalDurationSeconds)
        assertEquals("30 分钟", thisWeek.totalDurationText)
        assertEquals(100, thisWeek.completionRate)
        assertEquals("4/4 组", thisWeek.completionText)
        assertEquals("30 分钟/次", thisWeek.averageSessionText)
        assertEquals("day_5", thisWeek.dominantDayId)
        assertEquals("第 5 天", thisWeek.dominantDayLabel)
        assertEquals("相比上周，训练量持平，完成率增加 50 %。", thisWeek.summaryText)

        assertEquals("1 周前", items[1].weekLabel)
        assertEquals("本周完成 1 次训练，平均完成率 50%。", items[1].summaryText)

        assertEquals(0, items[2].sessionCount)
        assertEquals("2 周前", items[2].weekLabel)
        assertEquals("这一周还没有训练记录。", items[2].summaryText)
    }

    @Test
    fun `空周趋势条目字段`() {
        // 源 createEmptyWeeklyTrendItem :115
        val e = ReviewInsightsService.createEmptyWeeklyTrendItem()
        assertEquals("本周趋势", e.weekLabel)
        assertEquals(0, e.sessionCount)
        assertEquals("0 分钟", e.totalDurationText)
        assertEquals("0/0 组", e.completionText)
        assertEquals("0 分钟/次", e.averageSessionText)
        assertEquals("完成训练后，这里会开始累积周趋势。", e.summaryText)
    }

    @Test
    fun `周趋势完成率下降走减少分支`() {
        // 源 createSignedText :279（delta < 0 → 「减少 X %」）
        val now = lt(2024, 1, 17, 12)
        val sessions = listOf(
            session(sessionId = "thisweek", startedAt = lt(2024, 1, 16, 10), notes = "target_sets=4; completed_sets=1"),
            session(sessionId = "lastweek", startedAt = lt(2024, 1, 10, 10), notes = "target_sets=4; completed_sets=4"),
        )
        val thisWeek = ReviewInsightsService.createWeeklyTrendItems(sessions, now, WeekStart.MONDAY)[0]
        assertEquals(25, thisWeek.completionRate) // round(1*100/4)
        assertEquals("相比上周，训练量持平，完成率减少 75 %。", thisWeek.summaryText)
    }

    @Test
    fun `周趋势周首切周日时本周窗口前移一天`() {
        // 2024-01-17 为周三：周一首当周 = 2024-01-15 起；周日首当周 = 2024-01-14 起
        val now = lt(2024, 1, 17, 12)
        val sessions = listOf(
            session(sessionId = "sunday", startedAt = lt(2024, 1, 14, 10), durationSeconds = 1800),
        )
        val sundayFirst = ReviewInsightsService.createWeeklyTrendItems(sessions, now, WeekStart.SUNDAY)
        assertEquals("本周", sundayFirst[0].weekLabel)
        assertEquals(1, sundayFirst[0].sessionCount)
        assertEquals(0, sundayFirst[1].sessionCount)
        // 同一份数据在周一首模式下落到上一周
        val mondayFirst = ReviewInsightsService.createWeeklyTrendItems(sessions, now, WeekStart.MONDAY)
        assertEquals(0, mondayFirst[0].sessionCount)
        assertEquals(1, mondayFirst[1].sessionCount)
    }
}

package com.fittracker.app.data.service

import com.fittracker.app.data.model.WorkoutSession
import com.fittracker.app.data.model.WorkoutSet
import java.util.Calendar
import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * [WorkoutSessionService.weeklyStats] 的「周开始日」两态契约测试（A5 全量周窗口接线）。
 *
 * 纯 JVM 测试（`java.util.Calendar` + 纯数据模型，不落存储，无需 Robolectric）；
 * 时间构造走默认时区，与实现口径一致。
 *
 * 固定锚点 2026-06-10（周三）下的两态窗口：
 * - 周一态：06-08（周一）00:00 ~ 06-14（周日）23:59:59
 * - 周日态：06-07（周日）00:00 ~ 06-13（周六）23:59:59
 *
 * 会话构造口径同 `SessionAndPlanTest.modelSession`（扁平 `sets` 的 [WorkoutSession]），
 * 每组非热身 `60kg × 10` → 单会话 `sets = 1`、`volume = 600.0`。
 */
class WorkoutSessionServiceWeekTest {

    private fun at(
        year: Int,
        month0: Int,
        day: Int,
        hour: Int,
        minute: Int = 0,
        second: Int = 0,
    ): Long = Calendar.getInstance().apply {
        set(year, month0, day, hour, minute, second)
        set(Calendar.MILLISECOND, 0)
    }.timeInMillis

    private fun session(id: String, startedAt: Long, durationSeconds: Int): WorkoutSession = WorkoutSession(
        sessionId = id,
        planId = "plan-1",
        dayId = "上肢A",
        startedAt = startedAt,
        endedAt = startedAt + durationSeconds * 1000L,
        durationSeconds = durationSeconds,
        totalSets = 1,
        totalVolume = 0.0,
        fatigueScore = 0.0,
        notes = "",
        sets = listOf(WorkoutSet("set-$id", "bench-press", 60.0, 10, 0.0, false)),
    )

    @Test
    fun `周统计 周一态与周日态 窗口端点各归其周且计数不同`() {
        val now = at(2026, 5, 10, 12) // 2026-06-10 周三
        val sessions = listOf(
            session("s-sat-before", at(2026, 5, 6, 23, 59, 59), 60), // 06-06 周六 · 两态皆出
            session("s-sun-open", at(2026, 5, 7, 0, 0, 0), 120), // 06-07 周日 · 仅周日态入（周首零点）
            session("s-mon-open", at(2026, 5, 8, 0, 0, 0), 180), // 06-08 周一 · 两态皆入
            session("s-tue", at(2026, 5, 9, 12, 0, 0), 240), // 06-09 周二 · 两态皆入
            session("s-sat-close", at(2026, 5, 13, 23, 59, 59), 300), // 06-13 周六 · 两态皆入
            session("s-sun-open2", at(2026, 5, 14, 0, 0, 0), 360), // 06-14 周日 · 仅周一态入（周尾零点）
            session("s-sun-late", at(2026, 5, 14, 23, 59, 59), 480), // 06-14 周日 · 仅周一态入（闭区间端点）
            session("s-mon-next", at(2026, 5, 15, 0, 0, 0), 540), // 06-15 周一 · 两态皆出（下个周首）
        )

        val monday = WorkoutSessionService.weeklyStats(sessions, now, WeekStart.MONDAY)
        assertEquals(5, monday.count)
        assertEquals(180 + 240 + 300 + 360 + 480, monday.duration)
        assertEquals(5, monday.sets)
        assertEquals(600.0 * 5, monday.volume, 0.0)

        val sunday = WorkoutSessionService.weeklyStats(sessions, now, WeekStart.SUNDAY)
        assertEquals(4, sunday.count)
        assertEquals(120 + 180 + 240 + 300, sunday.duration)
        assertEquals(4, sunday.sets)
        assertEquals(600.0 * 4, sunday.volume, 0.0)
    }

    @Test
    fun `周统计 周日锚点 周一态收上一周 周日态开新周`() {
        val now = at(2026, 5, 14, 20) // 2026-06-14 周日 20:00
        val sessions = listOf(
            session("s-sat", at(2026, 5, 13, 20, 0, 0), 60), // 06-13 周六 · 仅周一态入
            session("s-sun", at(2026, 5, 14, 20, 0, 0), 120), // 06-14 周日（锚点日）· 两态皆入
            session("s-mon", at(2026, 5, 15, 9, 0, 0), 180), // 06-15 周一 · 仅周日态入
            session("s-sat2", at(2026, 5, 20, 9, 0, 0), 240), // 06-20 周六 · 仅周日态入（新周尾）
            session("s-sun2", at(2026, 5, 21, 9, 0, 0), 300), // 06-21 周日 · 两态皆出（新周首）
        )

        val monday = WorkoutSessionService.weeklyStats(sessions, now, WeekStart.MONDAY)
        assertEquals(2, monday.count)
        assertEquals(60 + 120, monday.duration)

        val sunday = WorkoutSessionService.weeklyStats(sessions, now, WeekStart.SUNDAY)
        assertEquals(3, sunday.count)
        assertEquals(120 + 180 + 240, sunday.duration)
    }
}

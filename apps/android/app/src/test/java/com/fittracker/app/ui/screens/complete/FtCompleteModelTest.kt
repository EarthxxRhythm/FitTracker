package com.fittracker.app.ui.screens.complete

import com.fittracker.app.R
import com.fittracker.app.data.service.WeekStart
import com.fittracker.app.data.service.WeekWindow
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 训练完成屏纯逻辑层的契约测试。
 *
 * 期望值逐条取自原型 `design/06_prototype_redraw/src/fittracker-training-complete.html`：
 * 连续记录 7 天（L418-425，周一至周六 `.on`、周日 `.off`）、
 * confetti 生成（L459-472）、文案（L412/L413/L419/L420/L436）。
 */
class FtCompleteModelTest {

    @Test
    fun `连续记录为周一至周六打卡_周日未打卡`() {
        val days = FtCompleteModel.STREAK_DAYS
        assertEquals(7, days.size)
        assertEquals(listOf("一", "二", "三", "四", "五", "六", "日"), days.map { it.label })
        assertTrue(days.take(6).all { it.active })
        assertFalse(days[6].active)
    }

    @Test
    fun `静态文案逐字取自原型`() {
        assertEquals(R.string.complete_title, FtCompleteModel.TITLE_RES)
        assertEquals(R.string.complete_subtitle, FtCompleteModel.SUBTITLE_RES)
        assertEquals(R.string.complete_streak_title, FtCompleteModel.STREAK_TITLE_RES)
        assertEquals(R.string.complete_streak_count, FtCompleteModel.STREAK_COUNT_RES)
        assertEquals(R.string.complete_continue, FtCompleteModel.CONTINUE_LABEL_RES)
    }

    /** `streak-days` 的 `role="img"` aria-label（L417），逐字取自源码。 */
    @Test
    fun `连续记录的无障碍文案逐字取自原型`() {
        assertEquals(R.string.complete_a11y_streak, FtCompleteModel.STREAK_A11Y_RES)
    }

    /**
     * 静态样例的槽位标签须与周窗口工具的周一态一致——实际打卡状态由
     * `CompleteScreen.weekActivity(trainingDates, weekStart)` 按周首重排（周首切周日时首列变「日」）。
     */
    @Test
    fun `连续记录静态样例与周窗口工具周一态一致`() {
        assertEquals(
            WeekWindow.dayLabels(WeekStart.MONDAY),
            FtCompleteModel.STREAK_DAYS.map { it.label },
        )
        assertEquals(7, WeekWindow.dayLabels(WeekStart.SUNDAY).size)
    }

    @Test
    fun `彩带数量为 38`() {
        assertEquals(38, FtCompleteModel.confetti { 0.5f }.size)
        assertEquals(38, FtCompleteModel.CONFETTI_COUNT)
    }

    @Test
    fun `全为随机中值时的彩带参数`() {
        val p = FtCompleteModel.confetti(count = 5) { 0.5f }[0]
        // left=0.5*100=50%；w=6+0.5*6=9；h=10+0.5*8=14；
        // dur=2.2+0.5*1.6=3.0；delay=0.5*0.45=0.225；rot=round(0.5*720-360)=0
        assertEquals(50f, p.leftPercent, 1e-3f)
        assertEquals(9f, p.width, 1e-3f)
        assertEquals(14f, p.height, 1e-3f)
        assertEquals(3.0f, p.durationSeconds, 1e-3f)
        assertEquals(0.225f, p.delaySeconds, 1e-3f)
        assertEquals(0, p.rotationDeg)
        assertEquals(0, p.colorIndex)
    }

    @Test
    fun `彩带配色按五色循环`() {
        val parts = FtCompleteModel.confetti(count = 11) { 0.5f }
        assertEquals(listOf(0, 1, 2, 3, 4, 0, 1, 2, 3, 4, 0), parts.map { it.colorIndex })
    }

    /** `Math.round(random * 720 - 360)`：rnd=0 → -360；rnd=1 → 360（半值向上取整）。 */
    @Test
    fun `旋转角覆盖正负三百六十度`() {
        assertEquals(-360, FtCompleteModel.confetti(count = 1) { 0f }[0].rotationDeg)
        assertEquals(360, FtCompleteModel.confetti(count = 1) { 1f }[0].rotationDeg)
    }

    // ── 整体 RPE 采集（逐字对齐鸿蒙 WorkoutCompletePage.ets 的 rpeCard） ──

    @Test
    fun `RPE 档位为 1 到 10 共十档`() {
        assertEquals(listOf(1, 2, 3, 4, 5, 6, 7, 8, 9, 10), FtCompleteModel.RPE_OPTIONS)
        assertEquals(10, FtCompleteModel.RPE_OPTIONS.size)
    }

    @Test
    fun `RPE 档位不含零_未评价不可选`() {
        // 0 表示未评价；不可选是「用户交互永不写 0 覆盖已存值」的结构保证
        assertFalse(FtCompleteModel.RPE_OPTIONS.contains(0))
        assertTrue(FtCompleteModel.RPE_OPTIONS.all { it > 0 })
    }

    @Test
    fun `RPE 状态文案_未评价走未评价资源`() {
        assertEquals(
            R.string.complete_rpe_unrated,
            FtCompleteModel.rpeStatusRes(rpe = 0, saved = false),
        )
        assertEquals(
            R.string.complete_rpe_unrated,
            FtCompleteModel.rpeStatusRes(rpe = 0, saved = true),
        )
    }

    @Test
    fun `RPE 状态文案_已评价走档位资源`() {
        assertEquals(
            R.string.complete_rpe_value,
            FtCompleteModel.rpeStatusRes(rpe = 7, saved = false),
        )
        assertEquals(
            R.string.complete_rpe_value,
            FtCompleteModel.rpeStatusRes(rpe = 7, saved = true),
        )
    }

    @Test
    fun `RPE 写回守卫_同值不写`() {
        // 对齐鸿蒙 selectSessionRpe 的 `if (this.sessionRpe === value) return`
        assertFalse(FtCompleteModel.shouldPersistRpe(picked = 5, current = 5, sessionId = "s1"))
    }

    @Test
    fun `RPE 写回守卫_会话 id 为空不写`() {
        // 对齐鸿蒙 `if (ctx === undefined || this.latestSessionId.length === 0) return`
        assertFalse(FtCompleteModel.shouldPersistRpe(picked = 5, current = 0, sessionId = ""))
    }

    @Test
    fun `RPE 写回守卫_异值且 id 非空则写`() {
        assertTrue(FtCompleteModel.shouldPersistRpe(picked = 5, current = 0, sessionId = "s1"))
        assertTrue(FtCompleteModel.shouldPersistRpe(picked = 8, current = 5, sessionId = "s1"))
    }

    // ── 界面态更新守卫（与写回守卫分离：界面反馈先行） ──

    @Test
    fun `RPE 选择态_异值应更新`() {
        assertTrue(FtCompleteModel.shouldUpdateRpeSelection(picked = 7, current = 0))
        assertTrue(FtCompleteModel.shouldUpdateRpeSelection(picked = 7, current = 3))
    }

    @Test
    fun `RPE 选择态_同值不更新`() {
        assertFalse(FtCompleteModel.shouldUpdateRpeSelection(picked = 7, current = 7))
    }

    /**
     * 回归护栏：**界面态更新不得依赖会话 id**。
     *
     * 曾经的缺陷——把写回守卫前置到状态更新之前，导致会话 id 为空（新装应用首轮训练）
     * 时用户点选毫无视觉反馈。鸿蒙 `selectSessionRpe` 的语义是「先更新界面、再尝试写回」。
     */
    @Test
    fun `RPE 选择态更新与会话 id 无关_界面反馈不依赖可写回性`() {
        // 会话 id 为空：不应写回，但**仍应更新界面态**
        assertFalse(FtCompleteModel.shouldPersistRpe(picked = 7, current = 0, sessionId = ""))
        assertTrue(FtCompleteModel.shouldUpdateRpeSelection(picked = 7, current = 0))
    }
}

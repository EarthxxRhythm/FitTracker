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
}

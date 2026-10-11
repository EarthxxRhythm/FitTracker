package com.fittracker.app.ui.screens.active

import com.fittracker.app.R
import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * 训练执行屏纯逻辑层的契约测试。
 *
 * 期望值逐条取自原型 `design/06_prototype_redraw/src/fittracker-training.html` 内联脚本：
 * `formatClock`（L700-712）、`updateProgress` 的分格规则与标签（L741-776）、
 * `completeSet`/步骤按钮的 clamp（L864-880）、`spawnConfetti`（L779-796）。
 * **运行时权威是这段 JS**。
 */
class FtActiveModelTest {

    // ── formatClock（原型 L700-712） ───────────────────────────

    @Test
    fun `计时不足一小时走 mm_ss`() {
        assertEquals("00:00", FtActiveModel.formatClock(0))
        assertEquals("00:09", FtActiveModel.formatClock(9))
        assertEquals("00:59", FtActiveModel.formatClock(59))
        assertEquals("01:00", FtActiveModel.formatClock(60))
        assertEquals("59:59", FtActiveModel.formatClock(3599))
    }

    @Test
    fun `满一小时后切换为 h_mm_ss 且不带前导零`() {
        assertEquals("1:00:00", FtActiveModel.formatClock(3600))
        assertEquals("1:01:01", FtActiveModel.formatClock(3661))
        assertEquals("10:00:00", FtActiveModel.formatClock(36000))
    }

    @Test
    fun `负数被夹到零`() {
        assertEquals("00:00", FtActiveModel.formatClock(-5))
    }

    // ── 进度标签（原型 L769-773） ──────────────────────────────

    @Test
    fun `未完成时标签指向下一组`() {
        assertEquals(FtLabelRes(R.string.active_progress_step, listOf(3, 6)), FtActiveModel.progressLabel(2))
        assertEquals(FtLabelRes(R.string.active_progress_step, listOf(1, 6)), FtActiveModel.progressLabel(0))
        assertEquals(FtLabelRes(R.string.active_progress_step, listOf(6, 6)), FtActiveModel.progressLabel(5))
    }

    @Test
    fun `完成全部组后标签改写为训练完成`() {
        assertEquals(FtLabelRes(R.string.active_progress_done, listOf(6)), FtActiveModel.progressLabel(6))
    }

    // ── 进度分格角色（原型 L748-762） ──────────────────────────

    @Test
    fun `分格角色按已完成数划分`() {
        assertEquals(FtSegRole.Done, FtActiveModel.segRole(0, completed = 2))
        assertEquals(FtSegRole.Done, FtActiveModel.segRole(1, completed = 2))
        assertEquals(FtSegRole.Current, FtActiveModel.segRole(2, completed = 2))
        assertEquals(FtSegRole.Plain, FtActiveModel.segRole(3, completed = 2))
        assertEquals(FtSegRole.Plain, FtActiveModel.segRole(5, completed = 2))
    }

    @Test
    fun `首屏无记录时第一格为当前格`() {
        assertEquals(FtSegRole.Current, FtActiveModel.segRole(0, completed = 0))
        assertEquals(FtSegRole.Plain, FtActiveModel.segRole(1, completed = 0))
    }

    @Test
    fun `全部完成后不再有当前格`() {
        (0 until 6).forEach { i ->
            assertEquals(FtSegRole.Done, FtActiveModel.segRole(i, completed = 6))
        }
    }

    // ── 提交按钮（原型 L732-733） ──────────────────────────────

    @Test
    fun `未满组显示提交_满组显示已完成`() {
        assertEquals(FtLabelRes(R.string.active_submit), FtActiveModel.submitLabel(2))
        assertEquals(FtLabelRes(R.string.active_submit), FtActiveModel.submitLabel(5))
        assertEquals(FtLabelRes(R.string.active_submit_done), FtActiveModel.submitLabel(6))
    }

    // ── 步进 clamp（原型 L864-880：n = clamp(n ± inc, min, max)） ──

    @Test
    fun `重量步进按 1 递增递减`() {
        assertEquals(33, FtActiveModel.stepValue(32, delta = 1, min = 20, max = 200))
        assertEquals(31, FtActiveModel.stepValue(32, delta = -1, min = 20, max = 200))
    }

    @Test
    fun `重量步进在上下界被夹住`() {
        assertEquals(200, FtActiveModel.stepValue(200, delta = 1, min = 20, max = 200))
        assertEquals(20, FtActiveModel.stepValue(20, delta = -1, min = 20, max = 200))
    }

    @Test
    fun `次数步进在 1 到 15 之间`() {
        assertEquals(10, FtActiveModel.stepValue(9, delta = 1, min = 1, max = 15))
        assertEquals(8, FtActiveModel.stepValue(9, delta = -1, min = 1, max = 15))
        assertEquals(15, FtActiveModel.stepValue(15, delta = 1, min = 1, max = 15))
        assertEquals(1, FtActiveModel.stepValue(1, delta = -1, min = 1, max = 15))
    }

    // ── 初始状态（原型 L693-698） ──────────────────────────────

    @Test
    fun `首屏预置两条记录且目标为六组`() {
        assertEquals(6, FtActiveModel.TARGET)
        assertEquals(listOf(FtSetRecord(30, 10), FtSetRecord(32, 9)), FtActiveModel.INITIAL_RECORDS)
    }

    // ── 彩带几何（原型 spawnConfetti，L779-796） ───────────────

    @Test
    fun `全为随机中值时的粒子几何`() {
        val parts = FtActiveModel.confetti(count = 36) { 0.5f }
        assertEquals(36, parts.size)

        // i=0：angle=0，dist=90+0.5*150=165 → tx=165, ty=0, rot=0.5*540-270=0
        val p0 = parts[0]
        assertEquals(165f, p0.offsetX, 1e-3f)
        assertEquals(0f, p0.offsetY, 1e-2f)
        assertEquals(0f, p0.rotationDeg, 1e-3f)
        assertEquals(0.04f, p0.delaySeconds, 1e-4f)
        assertEquals(1.075f, p0.durationSeconds, 1e-4f)
        assertEquals(0, p0.colorIndex)

        // i=9：angle=2π*9/36=π/2 → tx≈0, ty≈165
        val p9 = parts[9]
        assertEquals(0f, p9.offsetX, 1e-2f)
        assertEquals(165f, p9.offsetY, 1e-3f)
    }

    @Test
    fun `粒子配色按四色循环`() {
        val parts = FtActiveModel.confetti(count = 8) { 0.5f }
        assertEquals(listOf(0, 1, 2, 3, 0, 1, 2, 3), parts.map { it.colorIndex })
    }

    @Test
    fun `角度围绕整圆均匀撒开`() {
        val parts = FtActiveModel.confetti(count = 4) { 0.5f }
        // 0° / 90° / 180° / 270°，dist 恒 165
        assertEquals(165f, parts[0].offsetX, 1e-3f)
        assertEquals(165f, parts[1].offsetY, 1e-3f)
        assertEquals(-165f, parts[2].offsetX, 1e-3f)
        assertEquals(-165f, parts[3].offsetY, 1e-3f)
    }
}

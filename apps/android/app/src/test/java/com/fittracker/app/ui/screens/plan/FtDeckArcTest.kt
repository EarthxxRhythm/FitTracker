package com.fittracker.app.ui.screens.plan

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 弧形卡片堆几何层的契约测试。
 *
 * 期望值逐条来自原型 `design/06_prototype_redraw/src/fittracker-plan.html` 的
 * `stepPx()`（L779）与 `applyArc()`（L781-793）——**运行时权威是这段 JS**：
 * `paint()` 为每张卡写 inline style，覆盖同名 CSS 类 `.pos-front/prev/next`，
 * 故实现必须对齐 JS 而非 CSS（两者的 `-86%` 与 `0.86 × 卡宽` 恰好等值，可互证）。
 */
class FtDeckArcTest {

    /** `.deck` 宽度：390 视口 − `.plan-content` 左右各 16 内边距 */
    private val deckW = 358f

    /** `stepPx() = (deckEl.offsetWidth - 48) * 0.86` = 310 × 0.86 */
    private val step = 266.6f

    private val eps = 1e-3f

    @Test
    fun `步进距离为卡宽乘 0_86`() {
        assertEquals(step, FtDeckArc.stepPx(deckW), 1e-2f)
    }

    /** `u = 0` 是当前卡：`pos-front` 的 transform/opacity 全部为中性值。 */
    @Test
    fun `当前卡居中且完全不透明`() {
        val s = FtDeckArc.slot(u = 0f, deckWidth = deckW)

        assertEquals(0f, s.offsetX, eps)
        assertEquals(0f, s.offsetY, eps)
        assertEquals(0f, s.rotationDeg, eps)
        assertEquals(1f, s.scale, eps)
        assertEquals(1f, s.alpha, eps)
        assertEquals(100, s.zIndex)
        assertTrue(s.interactive)
    }

    /** `u = ±1` 是左右相邻卡：`pos-prev` / `pos-next`——上抬 16px、旋转 ±6°、缩到 .82、alpha .74。 */
    @Test
    fun `左邻卡向左上偏移并倾斜`() {
        val s = FtDeckArc.slot(u = -1f, deckWidth = deckW)

        assertEquals(-step, s.offsetX, 1e-2f)
        assertEquals(16f, s.offsetY, eps)
        assertEquals(-6f, s.rotationDeg, eps)
        assertEquals(0.82f, s.scale, eps)
        assertEquals(0.74f, s.alpha, eps)
        assertEquals(70, s.zIndex)
        assertTrue(s.interactive)
    }

    @Test
    fun `右邻卡向右上偏移并反向倾斜`() {
        val s = FtDeckArc.slot(u = 1f, deckWidth = deckW)

        assertEquals(step, s.offsetX, 1e-2f)
        assertEquals(16f, s.offsetY, eps)
        assertEquals(6f, s.rotationDeg, eps)
        assertEquals(0.82f, s.scale, eps)
        assertEquals(0.74f, s.alpha, eps)
    }

    /** 线性段 `o = 1 - 0.26 * au`（`au <= 1`）。 */
    @Test
    fun `半程偏移的透明度按斜率 0_26 递减`() {
        val s = FtDeckArc.slot(u = 0.5f, deckWidth = deckW)

        assertEquals(1f - 0.26f * 0.5f, s.alpha, eps)
    }

    /** 收尾段 `o = 0.74 * (1 - (au - 1) / 0.2)`（`1 < au < 1.2`）。 */
    @Test
    fun `一点二倍以内按余量线性淡出`() {
        val s = FtDeckArc.slot(u = 1.1f, deckWidth = deckW)

        assertEquals(0.74f * (1f - 0.1f / 0.2f), s.alpha, eps)
    }

    /** `au >= 1.2` 完全透明且不可点（`pointerEvents: none`），但几何值仍由公式给出。 */
    @Test
    fun `一点二倍以外不可见也不可交互`() {
        val s = FtDeckArc.slot(u = 1.2f, deckWidth = deckW)

        assertEquals(0f, s.alpha, eps)
        assertFalse(s.interactive)
        assertEquals(1f - 0.18f * 1.2f, s.scale, eps)
    }

    /** 缩放斜率只在 `au` 到达 1.2 前生效：`s = 1 - 0.18 * min(au, 1.2)`。 */
    @Test
    fun `远端卡片的缩放被一点二封顶`() {
        val near = FtDeckArc.slot(u = 1.2f, deckWidth = deckW)
        val far = FtDeckArc.slot(u = 2f, deckWidth = deckW)

        assertEquals(near.scale, far.scale, eps)
        assertEquals(12f, far.rotationDeg, eps)
        assertEquals(16f * 2f, far.offsetY, eps)
        assertEquals(2f * step, far.offsetX, 1e-2f)
        assertFalse(far.interactive)
    }

    /** `zIndex = Math.max(1, Math.round(100 - au * 30))`。 */
    @Test
    fun `层级随距离下降且下限为一`() {
        assertEquals(100, FtDeckArc.slot(u = 0f, deckWidth = deckW).zIndex)
        assertEquals(70, FtDeckArc.slot(u = 1f, deckWidth = deckW).zIndex)
        assertEquals(55, FtDeckArc.slot(u = 1.5f, deckWidth = deckW).zIndex)
        assertEquals(1, FtDeckArc.slot(u = 9f, deckWidth = deckW).zIndex)
    }

    // ── 拖拽 ────────────────────────────────────────────────

    /** `dragOffset = clamp(baseOffset - dx / stepPx(), -1, 1)`。 */
    @Test
    fun `拖拽比例被夹在正负一之间`() {
        assertEquals(1f, FtDeckArc.clampDrag(3f), eps)
        assertEquals(-1f, FtDeckArc.clampDrag(-3f), eps)
        assertEquals(0.42f, FtDeckArc.clampDrag(0.42f), eps)
    }

    /** `endDrag`：位移过阈值且落点在有效区间 → 切到相邻卡。 */
    @Test
    fun `拖过阈值切到下一张`() {
        assertEquals(
            FtDeckSettle.Advance(1),
            FtDeckArc.settle(dragOffset = 0.3f, moved = true, activeIndex = 0, cardCount = 5),
        )
        assertEquals(
            FtDeckSettle.Advance(-1),
            FtDeckArc.settle(dragOffset = -0.3f, moved = true, activeIndex = 2, cardCount = 5),
        )
    }

    /** 未过阈值 → 回弹（原型 `animateOffset(0, 260)`）。 */
    @Test
    fun `未过阈值回弹`() {
        assertEquals(
            FtDeckSettle.SnapBack,
            FtDeckArc.settle(dragOffset = 0.2f, moved = true, activeIndex = 0, cardCount = 5),
        )
        assertEquals(
            FtDeckSettle.SnapBack,
            FtDeckArc.settle(dragOffset = -0.19f, moved = true, activeIndex = 3, cardCount = 5),
        )
    }

    /** `moved` 为假（位移不足 6px）时即便越阈值也不切卡。 */
    @Test
    fun `未判定为拖拽则回弹`() {
        assertEquals(
            FtDeckSettle.SnapBack,
            FtDeckArc.settle(dragOffset = 0.9f, moved = false, activeIndex = 0, cardCount = 5),
        )
    }

    /** 越界（第一张再向左、最后一张再向右）→ 回弹，不越数组。 */
    @Test
    fun `两端越界回弹`() {
        assertEquals(
            FtDeckSettle.SnapBack,
            FtDeckArc.settle(dragOffset = -0.6f, moved = true, activeIndex = 0, cardCount = 5),
        )
        assertEquals(
            FtDeckSettle.SnapBack,
            FtDeckArc.settle(dragOffset = 0.6f, moved = true, activeIndex = 4, cardCount = 5),
        )
    }
}

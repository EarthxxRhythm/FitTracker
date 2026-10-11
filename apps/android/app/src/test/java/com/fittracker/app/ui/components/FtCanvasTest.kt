package com.fittracker.app.ui.components

import com.fittracker.app.nav.FtCanvasSpec
import com.fittracker.app.nav.FtRoutes
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 画布缩放换算测试。
 *
 * 核心不变量：
 * 1. 在参考视口 390×844 下，`fitScale` 必须复现原型写死的 0.90698；
 * 2. 缩放后的设计空间都不得溢出可用区域；
 * 3. 两个设计高度（900 与 844/0.90698）都要成立——硬编码其一必错。
 */
class FtCanvasTest {

    private val refW = FtCanvasSpec.REF_W
    private val refH = FtCanvasSpec.REF_H

    @Test
    fun `参考视口下 welcome 系缩放比复现原型写死的 0_90698`() {
        val s = FtCanvasSpec.fitScale(refW, refH, 430f, 900f)
        assertEquals(FtCanvasSpec.PROTOTYPE_SCALE.toDouble(), s.toDouble(), 1e-4)
    }

    @Test
    fun `参考视口下 complete 缩放比同样为 0_90698`() {
        val s = FtCanvasSpec.fitScale(refW, refH, 430f, FtCanvasSpec.DESIGN_H_COMPLETE)
        assertEquals(FtCanvasSpec.PROTOTYPE_SCALE.toDouble(), s.toDouble(), 1e-4)
    }

    @Test
    fun `welcome 系缩放后 430 设计宽等于 390 视口宽 高约 816`() {
        val s = FtCanvasSpec.fitScale(refW, refH, 430f, 900f)
        val (w, h) = FtCanvasSpec.scaledSize(s, 430f, 900f)
        assertEquals(390.0, w.toDouble(), 0.05)
        assertEquals(816.3, h.toDouble(), 0.2)
    }

    @Test
    fun `complete 缩放后恰好填满 390x844`() {
        val s = FtCanvasSpec.fitScale(refW, refH, 430f, FtCanvasSpec.DESIGN_H_COMPLETE)
        val (w, h) = FtCanvasSpec.scaledSize(s, 430f, FtCanvasSpec.DESIGN_H_COMPLETE)
        assertEquals(390.0, w.toDouble(), 0.2)
        assertEquals(844.0, h.toDouble(), 0.2)
    }

    @Test
    fun `路由表的缩放屏在参考视口下都不溢出`() {
        for (route in FtRoutes.all) {
            if (route.canvas != com.fittracker.app.nav.FtCanvasKind.Scaled) continue
            val s = FtCanvasSpec.fitScale(refW, refH, route.designW, route.designH)
            val (w, h) = FtCanvasSpec.scaledSize(s, route.designW, route.designH)
            assertTrue("${route.id} 宽溢出: $w", w <= refW + 0.5f)
            assertTrue("${route.id} 高溢出: $h", h <= refH + 0.5f)
        }
    }

    @Test
    fun `窄屏下缩放后不溢出可用区域`() {
        val cases = listOf(320f to 640f, 360f to 800f, 411f to 891f, 430f to 932f)
        for ((w, h) in cases) {
            for (designH in listOf(900f, FtCanvasSpec.DESIGN_H_COMPLETE)) {
                val s = FtCanvasSpec.fitScale(w, h, 430f, designH)
                val (sw, sh) = FtCanvasSpec.scaledSize(s, 430f, designH)
                assertTrue("宽溢出 @${w}x${h}/dH=$designH: $sw", sw <= w + 1e-3f)
                assertTrue("高溢出 @${w}x${h}/dH=$designH: $sh", sh <= h + 1e-3f)
            }
        }
    }

    // ── 自适应层 ────────────────────────────────────────────────

    /** 关键回归：加上限后，参考视口下缩放必须仍等于原型值（上限不得改动参考态）。 */
    @Test
    fun `缩放上限于参考视口下不改变原型缩放比`() {
        assertEquals(
            FtCanvasSpec.fitScale(refW, refH, 430f, 900f),
            FtCanvasSpec.adaptiveScale(refW, refH, 430f, 900f),
            1e-6f,
        )
        assertEquals(
            FtCanvasSpec.PROTOTYPE_SCALE.toDouble(),
            FtCanvasSpec.adaptiveScale(refW, refH, 430f, 900f).toDouble(),
            1e-4,
        )
    }

    @Test
    fun `超宽视口下缩放封顶为 1 不再放大`() {
        for (w in listOf(460f, 600f, 800f, 1200f)) {
            val s = FtCanvasSpec.adaptiveScale(w, 1600f, 430f, 900f)
            assertEquals("宽 $w 未封顶", 1f, s, 1e-6f)
        }
    }

    @Test
    fun `参考视口下水平偏移为 0`() {
        val s = FtCanvasSpec.adaptiveScale(refW, refH, 430f, 900f)
        assertEquals(0f, FtCanvasSpec.horizontalInset(refW, s, 430f), 1e-3f)
    }

    @Test
    fun `封顶时多余宽度转为水平居中的左偏移`() {
        val s = FtCanvasSpec.adaptiveScale(800f, 1600f, 430f, 900f)
        assertEquals(1f, s, 1e-6f)
        // (800 - 430) / 2 = 185
        assertEquals(185f, FtCanvasSpec.horizontalInset(800f, s, 430f), 1e-3f)
    }

    @Test
    fun `水平偏移永不为负`() {
        // 内容宽于可用宽（不应发生，但偏移必须是 0 而非负值，否则内容会被推出屏幕）
        assertEquals(0f, FtCanvasSpec.horizontalInset(300f, 1f, 430f), 1e-6f)
    }

    /**
     * 自适应契约：320/360/390/412/430 五档 × 两种设计高度，
     * 缩放后既不能溢出，也不能小到不可读（>0.5）。
     */
    @Test
    fun `五档常见宽度下缩放既不溢出也不过度缩小`() {
        val widths = listOf(320f to 569f, 360f to 800f, 390f to 844f, 412f to 916f, 430f to 932f)
        for ((w, h) in widths) {
            for (designH in listOf(900f, FtCanvasSpec.DESIGN_H_COMPLETE)) {
                val s = FtCanvasSpec.adaptiveScale(w, h, 430f, designH)
                val (sw, sh) = FtCanvasSpec.scaledSize(s, 430f, designH)
                assertTrue("溢出 @${w}x${h}: ${sw}x${sh}", sw <= w + 0.5f && sh <= h + 0.5f)
                assertTrue("过度缩小 @${w}x${h}: scale=$s", s > 0.5f)
            }
        }
    }
}

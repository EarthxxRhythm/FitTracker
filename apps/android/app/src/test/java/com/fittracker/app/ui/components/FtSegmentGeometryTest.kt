package com.fittracker.app.ui.components

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * 分段控件几何契约测试。
 *
 * 覆盖三类不可回归点：
 * 1. 等分：逐项宽高与偏移，且末项右边缘必须落在轨道右边缘（恒等式对任意 n / gap 成立）；
 * 2. 自适应：偏移是前序项宽与间距的累加，不是「平均宽 × index」；
 * 3. 边界：未测量完成 / 索引越界 / 算得负宽一律 [FtSegmentRect.EMPTY]，
 *    调用方据此隐藏指示器，避免进入页面时滑块从 0 飞入。
 *
 * 与鸿蒙 `common/utils/SegmentGeometry.ets` 同公式——本文件失败即双端都错。
 */
class FtSegmentGeometryTest {

    private val eps = 1e-4f

    // ── 等分 ─────────────────────────────────────────────────────────

    @Test
    fun `等分 两项无间距 第二项偏移等于半宽`() {
        val rect = FtSegmentGeometry.resolveEven(n = 2, trackWidth = 100f, gap = 0f, index = 1)
        assertEquals(50f, rect.offsetX, eps)
        assertEquals(50f, rect.width, eps)
    }

    @Test
    fun `等分 三项带间距 宽度与偏移按公式落位`() {
        // (200 - 4*2) / 3 = 64；index=2 → (64 + 4) * 2 = 136
        val rect = FtSegmentGeometry.resolveEven(n = 3, trackWidth = 200f, gap = 4f, index = 2)
        assertEquals(136f, rect.offsetX, eps)
        assertEquals(64f, rect.width, eps)
    }

    @Test
    fun `等分 末项右边缘始终落在轨道右边缘`() {
        val track = 320f
        for (n in 1..10) {
            for (gap in listOf(0f, 2f, 4f, 12f)) {
                val last = FtSegmentGeometry.resolveEven(n, track, gap, n - 1)
                if (last.width > 0f) {
                    assertEquals("n=$n gap=$gap", track, last.offsetX + last.width, eps)
                }
            }
        }
    }

    @Test
    fun `等分 零项零宽与索引越界 返回空矩形`() {
        assertEquals(FtSegmentRect.EMPTY, FtSegmentGeometry.resolveEven(0, 100f, 0f, 0))
        assertEquals(FtSegmentRect.EMPTY, FtSegmentGeometry.resolveEven(3, 0f, 0f, 0))
        assertEquals(FtSegmentRect.EMPTY, FtSegmentGeometry.resolveEven(3, 100f, 0f, -1))
        assertEquals(FtSegmentRect.EMPTY, FtSegmentGeometry.resolveEven(3, 100f, 0f, 3))
    }

    @Test
    fun `等分 间距吃满轨道时返回空矩形而非负宽`() {
        // (100 - 100*2) / 3 < 0
        assertEquals(FtSegmentRect.EMPTY, FtSegmentGeometry.resolveEven(3, 100f, 100f, 0))
    }

    // ── 自适应 ───────────────────────────────────────────────────────

    @Test
    fun `自适应 三项不等宽 偏移为前序项宽累加`() {
        // 体重 48 / 围度与体成分 96 / 身体档案 72，间距 8
        val rect = FtSegmentGeometry.resolveMeasured(listOf(48f, 96f, 72f), gap = 8f, index = 1)
        assertEquals(56f, rect.offsetX, eps)
        assertEquals(96f, rect.width, eps)
    }

    @Test
    fun `自适应 末项偏移等于前两项加两段间距`() {
        val rect = FtSegmentGeometry.resolveMeasured(listOf(48f, 96f, 72f), gap = 8f, index = 2)
        assertEquals(48f + 8f + 96f + 8f, rect.offsetX, eps)
        assertEquals(72f, rect.width, eps)
    }

    @Test
    fun `自适应 索引越界返回空矩形`() {
        val widths = listOf(48f, 96f)
        assertEquals(FtSegmentRect.EMPTY, FtSegmentGeometry.resolveMeasured(widths, 8f, -1))
        assertEquals(FtSegmentRect.EMPTY, FtSegmentGeometry.resolveMeasured(widths, 8f, 2))
        assertEquals(FtSegmentRect.EMPTY, FtSegmentGeometry.resolveMeasured(emptyList(), 8f, 0))
    }

    @Test
    fun `自适应 前序项尚未测量完成时返回空矩形`() {
        // 第 2 项指向 index=2，但 index=1 还是 0 —— 几何不可信，隐藏而不是画在半路
        assertEquals(FtSegmentRect.EMPTY, FtSegmentGeometry.resolveMeasured(listOf(48f, 0f, 72f), 8f, 2))
        // 选中项自身未测量
        assertEquals(FtSegmentRect.EMPTY, FtSegmentGeometry.resolveMeasured(listOf(48f, 0f), 8f, 1))
    }
}

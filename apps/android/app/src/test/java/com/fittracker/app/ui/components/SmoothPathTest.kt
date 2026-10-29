package com.fittracker.app.ui.components

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * SmoothPath 纯函数测试：平滑段构造、按进度截断、尖端定位。
 *
 * 与鸿蒙 `common/utils/SmoothPath.ets` 同一套算法，两端断言应一致。
 */
class SmoothPathTest {

    private fun line(n: Int): List<NormPoint> =
        (0 until n).map { i -> NormPoint(i.toFloat() / (n - 1), 0.5f) }

    @Test
    fun toSmoothSegmentsReturnsOneLessThanPoints() {
        val segments = toSmoothSegments(line(5))
        assertEquals(4, segments.size)
    }

    @Test
    fun toSmoothSegmentsStartsAtFirstPointAndEndsAtLast() {
        val points = line(4)
        val segments = toSmoothSegments(points)
        assertEquals(points.first().x, segments.first().from.x, 1e-5f)
        assertEquals(points.last().x, segments.last().to.x, 1e-5f)
    }

    @Test
    fun toSmoothSegmentsReturnsEmptyWhenFewerThanTwoPoints() {
        assertTrue(toSmoothSegments(emptyList()).isEmpty())
        assertTrue(toSmoothSegments(listOf(NormPoint(0.5f, 0.5f))).isEmpty())
    }

    @Test
    fun truncateAtZeroReturnsEmpty() {
        val segments = toSmoothSegments(line(5))
        assertTrue(truncateSegments(segments, 0f).isEmpty())
        assertTrue(truncateSegments(segments, -0.3f).isEmpty())
    }

    @Test
    fun truncateAtOneReturnsAllSegments() {
        val segments = toSmoothSegments(line(5))
        assertEquals(segments.size, truncateSegments(segments, 1f).size)
        assertEquals(segments.size, truncateSegments(segments, 3f).size)
    }

    @Test
    fun truncateHalfReturnsCompletedPlusPartial() {
        val segments = toSmoothSegments(line(5))   // 4 段
        val half = truncateSegments(segments, 0.5f) // span = 2.0 → 2 段，无部分
        assertEquals(2, half.size)
    }

    @Test
    fun truncatePartialEndsBetweenControlAndEnd() {
        val segments = toSmoothSegments(line(5))
        val partial = truncateSegments(segments, 0.125f) // span = 0.5 → 0 完整 + 1 部分
        assertEquals(1, partial.size)
        val tip = partial.last().to
        val first = segments.first()
        // 部分曲线的终点 x 应落在该段起点与终点之间
        assertTrue(tip.x > first.from.x)
        assertTrue(tip.x < first.to.x)
    }

    @Test
    fun tipOfReturnsLastEndOrNull() {
        assertNull(tipOf(emptyList()))
        val segments = toSmoothSegments(line(3))
        assertEquals(segments.last().to, tipOf(segments))
    }
}

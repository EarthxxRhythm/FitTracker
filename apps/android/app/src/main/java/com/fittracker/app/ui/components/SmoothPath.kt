package com.fittracker.app.ui.components

/**
 * SmoothPath —— 把折线点列转成平滑的二次贝塞尔段序列，并支持按进度截断。
 *
 * 与鸿蒙 `common/utils/SmoothPath.ets` 同一套算法（中点法 + de Casteljau 截断），
 * 两端必须保持逐值一致，否则同一批数据画出的曲线形状会分叉。
 *
 * 坐标系：所有点均为**归一化坐标**（0..1），与 Canvas 实际像素尺寸解耦。
 */

/** 归一化坐标点（0..1）。 */
data class NormPoint(val x: Float, val y: Float)

/** 一段二次贝塞尔：起点 / 控制点 / 终点，全部归一化。 */
data class QuadSegment(val from: NormPoint, val control: NormPoint, val to: NormPoint)

private fun midpoint(a: NormPoint, b: NormPoint): NormPoint =
    NormPoint((a.x + b.x) / 2f, (a.y + b.y) / 2f)

/**
 * 折线点列 → 平滑的二次贝塞尔段序列（中点法）。
 *
 * 段 i 的终点取 `mid(P[i], P[i+1])`、控制点取 `P[i]`；首段起点用 `P[0]`、
 * 末段终点直接收在 `P[n-1]`。点数 < 2 时返回空列表（无可画曲线）。
 */
fun toSmoothSegments(points: List<NormPoint>): List<QuadSegment> {
    val out = ArrayList<QuadSegment>(maxOf(points.size - 1, 0))
    if (points.size < 2) return out
    var from = points[0]
    for (i in 0 until points.size - 1) {
        val control = points[i]
        val to = if (i == points.size - 2) points[points.size - 1] else midpoint(points[i], points[i + 1])
        out.add(QuadSegment(from, control, to))
        from = to
    }
    return out
}

/**
 * 按进度 [p]（0..1）截断段序列：已完成段 + 最后一段在 t 处的部分曲线。
 *
 * 部分曲线用 de Casteljau 在 t 处分段并取第一段：
 *   C'  = P0 + t(C - P0)
 *   P1' = (1-t)²P0 + 2(1-t)tC + t²P1
 */
fun truncateSegments(segments: List<QuadSegment>, p: Float): List<QuadSegment> {
    if (segments.isEmpty() || p <= 0f) return emptyList()
    if (p >= 1f) return segments
    val span = segments.size * p
    val full = span.toInt()
    val frac = span - full
    val out = ArrayList<QuadSegment>(full + 1)
    for (i in 0 until minOf(full, segments.size)) {
        out.add(segments[i])
    }
    if (full < segments.size && frac > 0f) {
        val seg = segments[full]
        val inv = 1f - frac
        val control = NormPoint(
            seg.from.x + (seg.control.x - seg.from.x) * frac,
            seg.from.y + (seg.control.y - seg.from.y) * frac,
        )
        val end = NormPoint(
            inv * inv * seg.from.x + 2f * inv * frac * seg.control.x + frac * frac * seg.to.x,
            inv * inv * seg.from.y + 2f * inv * frac * seg.control.y + frac * frac * seg.to.y,
        )
        out.add(QuadSegment(seg.from, control, end))
    }
    return out
}

/** 曲线尖端（截断后的终点）；空序列返回 null。 */
fun tipOf(segments: List<QuadSegment>): NormPoint? = segments.lastOrNull()?.to

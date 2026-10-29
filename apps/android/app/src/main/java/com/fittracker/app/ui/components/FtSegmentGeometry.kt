package com.fittracker.app.ui.components

/**
 * 分段控件「选中块」几何计算的纯函数层（鸿蒙 `common/utils/SegmentGeometry.ets` 的逐行同构实现）。
 *
 * 指示器矩形只取决于「项数 / 各项宽度 / 间距 / 选中索引」，与 Compose 渲染无关：
 * - 双端共用同一套公式，改一侧必须改另一侧；
 * - 能在 JVM 上单测（见 `FtSegmentGeometryTest`）。
 *
 * 边界：任何不可确定的情况（未测量完成、索引越界、算得负宽）一律返回 [FtSegmentRect.EMPTY]，
 * 调用方据此隐藏指示器。不要返回近似值——否则进入页面时滑块会从 0 飞到选中项。
 */
internal data class FtSegmentRect(val offsetX: Float, val width: Float) {
    companion object {
        /** 零矩形：几何不可知。 */
        val EMPTY = FtSegmentRect(0f, 0f)
    }
}

internal object FtSegmentGeometry {

    /**
     * 等分场景：n 项等宽铺满 [trackWidth]，相邻项间隔 [gap]。
     *
     * 恒等式：`offsetX(n-1) + width == trackWidth`（n 项宽 + (n-1) 个间隔 = 轨道宽）。
     */
    fun resolveEven(n: Int, trackWidth: Float, gap: Float, index: Int): FtSegmentRect {
        if (n <= 0 || index < 0 || index >= n || trackWidth <= 0f) return FtSegmentRect.EMPTY
        val width = (trackWidth - gap * (n - 1)) / n
        if (width <= 0f) return FtSegmentRect.EMPTY
        return FtSegmentRect((width + gap) * index, width)
    }

    /**
     * 自适应场景：各项宽度由内容决定，[itemWidths] 为逐项实测宽度。
     *
     * 偏移是前序项宽与间距的累加——不能用「平均宽 × index」近似。
     */
    fun resolveMeasured(itemWidths: List<Float>, gap: Float, index: Int): FtSegmentRect {
        if (index < 0 || index >= itemWidths.size) return FtSegmentRect.EMPTY
        val width = itemWidths[index]
        if (width <= 0f) return FtSegmentRect.EMPTY
        var offsetX = 0f
        for (i in 0 until index) {
            val itemWidth = itemWidths[i]
            // 尚有项未测量完成：整体几何不可信，隐藏而不是画在半路。
            if (itemWidth <= 0f) return FtSegmentRect.EMPTY
            offsetX += itemWidth + gap
        }
        return FtSegmentRect(offsetX, width)
    }
}

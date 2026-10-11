package com.fittracker.app.ui.screens.plan

import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt

/**
 * 弧形卡片堆的几何层——无 Compose 依赖，可单测。
 *
 * 规格源：原型 `design/06_prototype_redraw/src/fittracker-plan.html` 的
 * `stepPx()`（L779）、`applyArc()`（L781-793）与 `endDrag()`（L875-886）。
 *
 * [u] 是卡片相对当前卡的**偏移数**：`0` 为当前卡，`±1` 为左右相邻卡，`±2` 及以上为远端。
 * 拖拽过程中 `u = 索引 − 当前索引 − dragOffset`，故同一套公式同时驱动静止态与拖拽态
 * （原型的 `paint()` 就是这么用的）。
 */
data class FtDeckSlot(
    /** 水平位移（px，正为右）。 */
    val offsetX: Float,
    /** 垂直抬升（px，恒向上）。 */
    val offsetY: Float,
    /** 旋转角（度，正为顺时针）。 */
    val rotationDeg: Float,
    /** 缩放。 */
    val scale: Float,
    /** 不透明度。 */
    val alpha: Float,
    /** 绘制层级。 */
    val zIndex: Int,
    /** 是否可交互（原型 `pointerEvents: au < 1.2`）。 */
    val interactive: Boolean,
)

/** 拖拽释放后的落点判定（原型 `endDrag`）。 */
sealed interface FtDeckSettle {
    /** 回弹原位（原型 `animateOffset(0, 260)`）。 */
    data object SnapBack : FtDeckSettle

    /** 切到相邻卡（原型 `animateOffset(dir, 320)`）；`dir` 为 ±1。 */
    data class Advance(val dir: Int) : FtDeckSettle
}

object FtDeckArc {

    /** `.deck-card { left: 24px; right: 24px }`——`stepPx` 里的 48 即左右各 24。 */
    const val CARD_INSET = 24f

    /** `stepPx()` 系数：卡宽 × 0.86。与 CSS `.pos-prev { translateX(-86%) }` 等值互证。 */
    const val STEP_RATIO = 0.86f

    /** `y = 16 * au`。 */
    const val LIFT_Y = 16f

    /** `r = 6 * u`。 */
    const val ROT_DEG = 6f

    /** `s = 1 - 0.18 * min(au, 1.2)` 的斜率。 */
    const val SCALE_SLOPE = 0.18f

    /** 缩放斜率的封顶值，同时是「可交互」的边界。 */
    const val SCALE_CAP = 1.2f

    /** `o = 1 - 0.26 * au`（`au <= 1`）的斜率。 */
    const val FADE_SLOPE = 0.26f

    /** 相邻卡的定格透明度。 */
    const val PEEK_ALPHA = 0.74f

    /** 切卡阈值：`|dragOffset| > 0.2`。 */
    const val COMMIT_THRESHOLD = 0.2f

    /** `stepPx() = (deckEl.offsetWidth - 48) * 0.86`。 */
    fun stepPx(deckWidth: Float): Float = (deckWidth - CARD_INSET * 2f) * STEP_RATIO

    /**
     * 透明度分段（原型 `applyArc` 的 `o` 三支）：
     * `au <= 1` 线性降到 0.74；`1 < au < 1.2` 归零；更远恒 0。
     */
    private fun alphaFor(au: Float): Float = when {
        au <= 1f -> 1f - FADE_SLOPE * au
        au < SCALE_CAP -> PEEK_ALPHA * (1f - (au - 1f) / (SCALE_CAP - 1f))
        else -> 0f
    }

    /** 由偏移数 [u] 求该卡的完整摆放参数。 */
    fun slot(u: Float, deckWidth: Float): FtDeckSlot {
        val au = abs(u)
        return FtDeckSlot(
            offsetX = u * stepPx(deckWidth),
            offsetY = LIFT_Y * au,
            rotationDeg = ROT_DEG * u,
            scale = 1f - SCALE_SLOPE * min(au, SCALE_CAP),
            alpha = alphaFor(au),
            zIndex = max(1, (100f - au * 30f).roundToInt()),
            interactive = au < SCALE_CAP,
        )
    }

    /** `dragOffset = clamp(baseOffset - dx / stepPx(), -1, 1)`。 */
    fun clampDrag(raw: Float): Float = raw.coerceIn(-1f, 1f)

    /**
     * 拖拽释放后的落点：位移被判为拖拽（`moved`）且越过 [COMMIT_THRESHOLD]、
     * 目标下标仍在 `0 until cardCount` 内时切卡，否则一律回弹。
     */
    fun settle(
        dragOffset: Float,
        moved: Boolean,
        activeIndex: Int,
        cardCount: Int,
    ): FtDeckSettle {
        val dir = when {
            !moved -> 0
            dragOffset > COMMIT_THRESHOLD -> 1
            dragOffset < -COMMIT_THRESHOLD -> -1
            else -> 0
        }
        val target = activeIndex + dir
        val valid = dir != 0 && target >= 0 && target < cardCount
        return if (valid) FtDeckSettle.Advance(dir) else FtDeckSettle.SnapBack
    }
}

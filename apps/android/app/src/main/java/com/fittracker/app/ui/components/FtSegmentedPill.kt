package com.fittracker.app.ui.components

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.fittracker.app.ui.theme.FtColor
import com.fittracker.app.ui.theme.FtMotion
import kotlin.math.roundToInt

/**
 * `.seg` 容器外观变体（[FtSegmentedPill] 的 `container` 参数）。
 *
 * 从 `ReviewScreen.kt` 上移：原本是本屏私有，登录页 / 身体数据页各自另写了一套
 * 分段控件（`LoginModeSwitch` / `PeriodSeg`），三处形态一致却互不复用。
 */
internal enum class SegContainer {
    /** 原型底板：`.seg` 填充（调用方传 `trackFill`）+ 1px 描边（`line10`）。 */
    Full,

    /** 只留 1px 外描边，去掉填充——胶囊浮于页面但仍有轮廓（回顾页周/月）。 */
    StrokeOnly,

    /** 描边与填充全去掉（身体数据页签、RPE 十格这类裸行）。 */
    None,
}

/**
 * 分段控件：互斥选择 + 选中块滑动。
 *
 * ── 为什么存在 ────────────────────────────────────────────────
 * 改造前，选中态是「每个按钮自己的 background 随选中项互换」。颜色渐变无法表达位移——
 * 起点和终点是两个不同元素，任何时刻都不存在「一个实体从 A 移动到 B」，视觉上是溶解不是滑动。
 *
 * 本组件把选中底色从「N 个按钮各自的属性」提升为「1 个独立图层 + 几何量」：
 *
 *     Box
 *       ├─ 层 1  常底网格（itemBackground，仅 RPE 十格这类刻度选择器）
 *       ├─ 层 2  滑块（accent，offset / width 由 FtSegmentGeometry 算出，动画到新索引）
 *       └─ 层 3  按钮行（透明底，onSelect 回调）
 *
 * 层序不可颠倒：滑块必须在常底之上（遮住格底与格边），在文字之下（不遮字）。
 *
 * ── 几何从哪来 ────────────────────────────────────────────────
 * 全部来自 [FtSegmentGeometry] 的纯函数，与鸿蒙 `common/utils/SegmentGeometry.ets` 逐行同构。
 * 未测量完成 / 索引越界 / 负宽时纯函数返回 [FtSegmentRect.EMPTY]，滑块整体不参与组合
 * （`if (target.width > 0f)`）——首次创建时 `animateFloatAsState` 直接初始化为目标值，
 * 因此不会出现「从 0 展开」的假动画。之后的选中变化才走 `DURATION_SEG_SLIDE` 平移。
 *
 * ── 边界 ─────────────────────────────────────────────────────
 * 不持有业务状态：`selectedIndex` 由调用方提供，组件通过 `onSelect` 请求变更。
 * 内部两个测量态（`trackWidthPx` / `measuredWidths`）只服务几何计算。
 */
@Composable
internal fun FtSegmentedPill(
    labels: List<String>,
    selectedIndex: Int,
    onSelect: (Int) -> Unit,
    modifier: Modifier = Modifier,
    fillWidth: Boolean = false,
    buttonHeight: Dp = 44.dp,
    buttonPadH: Dp = 20.dp,
    inactiveColor: Color = FtColor.white62,
    contentDescription: String? = null,
    container: SegContainer = SegContainer.Full,
    itemGap: Dp = 0.dp,
    /** 项圆角。默认 999（与 `FtShape.pill` 同值），身体数据页签 / RPE 用 9 / 10。 */
    itemRadius: Dp = 999.dp,
    /** 容器圆角。默认 999（胶囊）；登录页模式切换是 14。 */
    trackRadius: Dp = 999.dp,
    buttonFontSize: TextUnit = 13.sp,
    /** 选中项字重；未选中固定 Medium(500)（与原型 600/500 口径一致）。 */
    buttonFontWeight: FontWeight = FontWeight.SemiBold,
    /** 容器填充色——`SegContainer.Full` 时生效，各屏取值不同故由调用方传入。 */
    trackFill: Color = Color.Transparent,
    /** 每项常态底色（仅刻度选择器；胶囊分段保持透明）。 */
    itemBackground: Color = Color.Transparent,
    itemBorderColor: Color = Color.Transparent,
    /**
     * 逐项无障碍描述（下标 → 文案）。RPE 十格靠它区分「第 n 档 · 已选/未选」；
     * 传 null 表示不设逐项描述（此时只有 `contentDescription` 的整体描述）。
     */
    itemContentDescription: ((Int) -> String)? = null,
) {
    val density = LocalDensity.current
    val gapPx = with(density) { itemGap.toPx() }
    var trackWidthPx by remember { mutableFloatStateOf(0f) }
    val measuredWidths = remember { mutableStateMapOf<Int, Float>() }

    val target: FtSegmentRect = if (fillWidth) {
        FtSegmentGeometry.resolveEven(labels.size, trackWidthPx, gapPx, selectedIndex)
    } else {
        FtSegmentGeometry.resolveMeasured(labels.indices.map { measuredWidths[it] ?: 0f }, gapPx, selectedIndex)
    }

    val shape = RoundedCornerShape(itemRadius)
    val trackShape = RoundedCornerShape(trackRadius)

    val trackModifier = modifier
        .then(if (fillWidth) Modifier.fillMaxWidth() else Modifier)
        .then(
            if (contentDescription != null) {
                Modifier.semantics { this.contentDescription = contentDescription }
            } else {
                Modifier
            },
        )
        .then(
            when (container) {
                SegContainer.Full -> Modifier
                    .clip(trackShape)
                    .background(trackFill)
                    .border(1.dp, FtColor.line10, trackShape)

                SegContainer.StrokeOnly -> Modifier
                    .clip(trackShape)
                    .border(1.dp, FtColor.line10, trackShape)

                SegContainer.None -> Modifier
            },
        )
        .padding(3.dp)

    Row(modifier = trackModifier) {
        Box {
            // 层 1：每项常底（刻度选择器专用；胶囊分段不渲染）
            if (itemBackground != Color.Transparent || itemBorderColor != Color.Transparent) {
                Row(horizontalArrangement = Arrangement.spacedBy(itemGap)) {
                    labels.indices.forEach { _ ->
                        Box(
                            modifier = Modifier
                                .then(if (fillWidth) Modifier.weight(1f) else Modifier)
                                .height(buttonHeight)
                                .clip(shape)
                                .background(itemBackground)
                                .border(
                                    width = if (itemBorderColor == Color.Transparent) 0.dp else 1.dp,
                                    color = itemBorderColor,
                                    shape = shape,
                                ),
                        )
                    }
                }
            }

            // 层 2：滑块。仅在几何可知时创建——首次创建不播动画。
            if (target.width > 0f) {
                val slideSpec = tween<Float>(
                    durationMillis = FtMotion.DURATION_SEG_SLIDE,
                    easing = FtMotion.EASE_PANEL,
                )
                val animX by animateFloatAsState(targetValue = target.offsetX, animationSpec = slideSpec, label = "seg-x")
                val animW by animateFloatAsState(targetValue = target.width, animationSpec = slideSpec, label = "seg-w")
                Box(
                    modifier = Modifier
                        .offset { IntOffset(animX.roundToInt(), 0) }
                        .width(with(density) { animW.toDp() })
                        .height(buttonHeight)
                        .clip(shape)
                        .background(FtColor.accent),
                )
            }

            // 层 3：按钮行
            Row(
                modifier = Modifier
                    .then(if (fillWidth) Modifier.fillMaxWidth() else Modifier)
                    .then(
                        if (fillWidth) {
                            Modifier.onSizeChanged { trackWidthPx = it.width.toFloat() }
                        } else {
                            Modifier
                        },
                    ),
                horizontalArrangement = Arrangement.spacedBy(itemGap),
            ) {
                labels.forEachIndexed { index, label ->
                    val active = index == selectedIndex
                    Box(
                        modifier = Modifier
                            .then(if (fillWidth) Modifier.weight(1f) else Modifier)
                            .height(buttonHeight)
                            .clip(shape)
                            // 测量必须放在 padding **之前**：Modifier 链从左到右包裹，
                            // padding 之后的 onGloballyPositioned 看到的是内容区（纯文字宽），
                            // 滑块会窄出一条，选中项的深色字落到轨道上看不见
                            // （真机实测滑块 37px，整项应为 159px）。
                            .then(
                                if (fillWidth) {
                                    Modifier
                                } else {
                                    Modifier.onGloballyPositioned { coords ->
                                        measuredWidths[index] = coords.size.width.toFloat()
                                    }
                                },
                            )
                            .clickableNoRipple { onSelect(index) }
                            // 等分场景宽度由 weight 决定，加水平内边距会挤字——只对自适应生效。
                            .padding(horizontal = if (fillWidth) 0.dp else buttonPadH)
                            .then(
                                if (itemContentDescription != null) {
                                    val desc = itemContentDescription.invoke(index)
                                    // 必须写 `this.`：组件参数同名 `contentDescription`（val）
                                    // 会遮蔽 SemanticsPropertyReceiver 的同名属性，裸写即 VAL_REASSIGNMENT。
                                    Modifier.semantics { this.contentDescription = desc }
                                } else {
                                    Modifier
                                },
                            ),
                        contentAlignment = Alignment.Center,
                    ) {
                        Text(
                            text = label,
                            fontSize = buttonFontSize,
                            fontWeight = if (active) buttonFontWeight else FontWeight.Medium,
                            color = if (active) FtColor.onAccent else inactiveColor,
                            textAlign = TextAlign.Center,
                            maxLines = 1,
                        )
                    }
                }
            }
        }
    }
}

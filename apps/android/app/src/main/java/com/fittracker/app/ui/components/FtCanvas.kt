package com.fittracker.app.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.offset
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.ui.graphics.TransformOrigin
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.layout.layout
import androidx.compose.ui.unit.Constraints
import androidx.compose.ui.unit.dp
import com.fittracker.app.nav.FtCanvasKind
import com.fittracker.app.nav.FtCanvasSpec
import com.fittracker.app.ui.theme.FtColor
import kotlin.math.roundToInt

/**
 * 屏画布容器。
 *
 * - [FtCanvasKind.Direct]：填满可用空间，与设备 vp 1:1。
 * - [FtCanvasKind.Scaled]：内容在 `designW × designH` 的**设计空间**内绘制，
 *   整体按 [FtCanvasSpec.fitScale] 从左上角缩放，外层裁剪。
 *
 * **缩放屏不得在屏内手写 scale**——鸿蒙工程正是漏了这层容器，导致 login/register
 * 成为 15 屏中偏差最大的两屏（10.02% / 12.28%）。
 *
 * 设计空间逐屏不同：welcome/login/register 为 430×900，complete 为 430×930.56
 * （由路由表 [com.fittracker.app.nav.FtRoute.designW] / `designH` 携带）。
 */
@Composable
fun FtCanvas(
    kind: FtCanvasKind,
    modifier: Modifier = Modifier,
    designW: Float = FtCanvasSpec.DESIGN_W,
    designH: Float = FtCanvasSpec.DESIGN_H_BASE,
    content: @Composable BoxScope.() -> Unit,
) {
    when (kind) {
        FtCanvasKind.Direct -> Box(
            modifier = modifier
                .fillMaxSize()
                .background(FtColor.bg),
            content = content,
        )

        FtCanvasKind.Scaled -> BoxWithConstraints(
            modifier = modifier
                .fillMaxSize()
                .clipToBounds()
                .background(FtColor.bg),
        ) {
            val scale = FtCanvasSpec.adaptiveScale(maxWidth.value, maxHeight.value, designW, designH)
            val leftInset = FtCanvasSpec.horizontalInset(maxWidth.value, scale, designW)
            Box(
                modifier = Modifier
                    .offset(x = leftInset.dp)
                    .designSpace(designW, designH, scale)
                    .graphicsLayer {
                        scaleX = scale
                        scaleY = scale
                        transformOrigin = TransformOrigin(0f, 0f)
                    },
                content = content,
            )
        }
    }
}

/**
 * 按**设计空间**测量内容，却向父级报告**缩放后**的尺寸。
 *
 * 这不是可选的写法，两种「显然」的写法都会坏：
 * - `Modifier.size(designW, designH)`：设计空间（430×900 / 430×930.56）恒大于可用视口
 *   （390×844），`size` 会把目标尺寸**夹进父级约束**——设计空间实际变成 390×844，
 *   版面随之整体错位（实测 `box measured px=1170x2532`，即 390×844 dp；
 *   `complete` 屏因此整屏小 9.3%、居中元素左偏约 19dp）。
 * - `Modifier.requiredSize(...)`：设计空间尺寸保住了，但节点**超出父级约束**，
 *   父级摆放时又把它挪了位（实测整体右移约 21dp）。
 *
 * 这里的写法两头都不越界：内容按 `designW × designH` 测量、节点按 `designW*scale`
 * 入账。内容溢出到报告尺寸之外交给 `graphicsLayer` 的缩放收回，父级的
 * `clipToBounds` 只负责兜底。
 */
private fun Modifier.designSpace(designW: Float, designH: Float, scale: Float): Modifier =
    this.layout { measurable, constraints ->
        val placeable = measurable.measure(
            Constraints.fixed(designW.dp.roundToPx(), designH.dp.roundToPx()),
        )
        val w = (designW.dp.roundToPx() * scale).roundToInt()
        val h = (designH.dp.roundToPx() * scale).roundToInt()
        layout(w, h) { placeable.place(0, 0) }
    }

package com.fittracker.app.ui.components

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.fittracker.app.ui.theme.FtColor
import com.fittracker.app.ui.theme.FtShape
import com.fittracker.app.ui.theme.FtSpace

/**
 * 卡片层级（见 `design/04_component_specs/cards.md`）。
 *
 * 一屏内**最多一个** [Focus]，若干 [Standard]，避免「等权重的仪表盘块」。
 */
enum class FtCardLevel {
    /** 常规信息块 */
    Standard,

    /** 次级/浮起卡 */
    Floating,

    /** 主导焦点卡（一屏至多一个） */
    Focus,
}

/**
 * FitTracker 卡片容器。
 *
 * 取色一律来自原型 CSS 令牌（`FtColor`），而非 `design/03_design_system/colors.md` 里那套
 * 与原型有微差的旧值——TOKENS.md §5 已说明两者存在 L* 级别的色差，且要求「还原屏时不做全局覆盖」。
 */
@Composable
fun FtCard(
    modifier: Modifier = Modifier,
    level: FtCardLevel = FtCardLevel.Standard,
    padding: Dp = FtSpace.xl,
    containerColor: Color? = null,
    borderColor: Color? = null,
    shape: Shape? = null,
    content: @Composable ColumnScope.() -> Unit,
) {
    val levelBg: Color = when (level) {
        FtCardLevel.Standard -> FtColor.surface
        FtCardLevel.Floating -> FtColor.surface2
        FtCardLevel.Focus -> FtColor.visualA
    }
    val levelBorder: Color = when (level) {
        FtCardLevel.Standard -> FtColor.hairline
        FtCardLevel.Floating -> FtColor.line10
        FtCardLevel.Focus -> FtColor.accent12
    }
    val levelShape: RoundedCornerShape = when (level) {
        FtCardLevel.Standard -> FtShape.md
        FtCardLevel.Floating -> FtShape.lg
        FtCardLevel.Focus -> FtShape.xl
    }

    val bg: Color = containerColor ?: levelBg
    val border: Color = borderColor ?: levelBorder
    val resolvedShape: Shape = shape ?: levelShape

    Column(
        modifier = modifier
            .clip(resolvedShape)
            .background(bg)
            .border(BorderStroke(1.dp, border), resolvedShape)
            .padding(padding),
        content = content,
    )
}

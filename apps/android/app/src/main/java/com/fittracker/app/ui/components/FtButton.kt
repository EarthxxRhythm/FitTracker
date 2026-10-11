package com.fittracker.app.ui.components

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.fittracker.app.ui.theme.FtColor
import com.fittracker.app.ui.theme.FtMotion
import com.fittracker.app.ui.theme.FtShape
import com.fittracker.app.ui.theme.FtSpace

/**
 * 按钮三级语义（见 `design/04_component_specs/buttons.md`）。
 */
enum class FtButtonVariant {
    /** 主操作：实心强调色，深色文字 */
    Primary,

    /** 次操作：次级面 + 描边 */
    Secondary,

    /** 低优先：透明底，次要文字 */
    Ghost,
}

/**
 * FitTracker 按钮。
 *
 * 按压反馈为 `transform: scale(.985)`（原型 `.btn-primary:active`），
 * **不使用 Material ripple**（theme 已全局关闭）——与原型保持一致。
 */
@Composable
fun FtButton(
    text: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    variant: FtButtonVariant = FtButtonVariant.Primary,
    enabled: Boolean = true,
    fontSize: Float = 15f,
    fontWeight: Int = 600,
    height: androidx.compose.ui.unit.Dp = 52.dp,
    shape: RoundedCornerShape = FtShape.md,
    leading: (@Composable () -> Unit)? = null,
) {
    val interaction = remember { MutableInteractionSource() }
    val pressed by interaction.collectIsPressedAsState()
    val scale = if (pressed && enabled) FtMotion.PRESS_SCALE_CTA else 1f

    val bg: Color = when (variant) {
        FtButtonVariant.Primary -> FtColor.accent
        FtButtonVariant.Secondary -> FtColor.surface2
        FtButtonVariant.Ghost -> Color.Transparent
    }
    val fg: Color = when (variant) {
        FtButtonVariant.Primary -> FtColor.onAccent
        FtButtonVariant.Secondary -> FtColor.txtHi
        FtButtonVariant.Ghost -> FtColor.white70
    }

    Box(
        modifier = modifier
            .graphicsLayer { scaleX = scale; scaleY = scale }
            .defaultMinSize(minHeight = height)
            .clip(shape)
            .background(bg)
            .then(
                if (variant == FtButtonVariant.Secondary) {
                    Modifier.border(BorderStroke(1.dp, FtColor.hairline), shape)
                } else {
                    Modifier
                },
            )
            .clickable(
                interactionSource = interaction,
                indication = null,
                enabled = enabled,
                onClick = onClick,
            ),
        contentAlignment = Alignment.Center,
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(FtSpace.s),
            modifier = Modifier.padding(horizontal = FtSpace.xxl),
        ) {
            if (leading != null) {
                leading()
            }
            Text(
                text = text,
                color = if (enabled) fg else FtColor.white32,
                fontSize = fontSize.sp,
                fontWeight = FontWeight(fontWeight),
            )
        }
    }
}

package com.fittracker.app.ui.components

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
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
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.fittracker.app.ui.theme.DuTokens
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
 * ── Duolingo 皮肤元素（C1 档）──────────────────────────────────
 * 主操作采用**硬边厚底 + 按下位移**反馈，与 Harmony 侧 `AppButton.ets` 同构：
 *   常态：底部 4dp 实心深绿厚边（`DuTokens.PRESS_DEPTH`），无模糊光晕；
 *   按下：厚边收平至 0，整体下沉 2dp（`DuTokens.PRESS_SHIFT`），松开回弹。
 *
 * **为什么不用 `border`**：Compose 的 `Modifier.border` 只能四边同宽。
 * 故用 `drawBehind` 在底部绘制色条 + `padding(bottom = depth)` 让内容避让，
 * 等价于 CSS `border-bottom: 4px solid`。
 *
 * **为什么主操作不再叠加 scale**：Duolingo 靠"被按进面板"传达物理感，
 * 缩放与位移同帧叠加会让观感发虚；`Secondary` / `Ghost` 无厚底，保留
 * 原型 `transform: scale(.985)` 的按压语汇。
 *
 * **配色保持原型基线**：厚底取 `FtColor.accentDeep`（`#45C9A1`），与按钮面
 * `FtColor.accent`（`#50ECA7`）配对。只借 Duolingo 的形态，不动配色。
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
    height: Dp = 52.dp,
    shape: RoundedCornerShape = FtShape.md,
    leading: (@Composable () -> Unit)? = null,
) {
    val interaction = remember { MutableInteractionSource() }
    val pressed by interaction.collectIsPressedAsState()

    // 只有可用的主操作才有厚底；禁用/加载态不该产生"可按"的错觉
    val usesPressDepth = variant == FtButtonVariant.Primary && enabled
    // 按压缩放必须走 animateFloatAsState——裸值直送 graphicsLayer 是硬切，
    // 视觉上等于没有按压反馈（这是本项目 Android 端 14 处按压的共性问题）。
    val scale by animateFloatAsState(
        targetValue = if (!usesPressDepth && pressed && enabled) FtMotion.PRESS_SCALE_CTA else 1f,
        animationSpec = tween(FtMotion.DURATION_PRESS, easing = FtMotion.EASE_MOTION),
        label = "ft-button-press-scale",
    )
    val depth: Dp = if (usesPressDepth && !pressed) DuTokens.PRESS_DEPTH else 0.dp
    val shift: Dp = if (usesPressDepth && pressed) DuTokens.PRESS_SHIFT else 0.dp

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
            .graphicsLayer {
                scaleX = scale
                scaleY = scale
                translationY = shift.toPx()
            }
            .defaultMinSize(minHeight = height)
            .clip(shape)
            .background(bg)
            // 底部厚边：与按钮面同色系的深色，零模糊。clip 之后绘制，
            // 圆角处会被裁剪，不会露出直角。
            .drawBehind {
                if (depth.value > 0f) {
                    val thickness = depth.toPx()
                    drawRect(
                        color = FtColor.accentDeep,
                        topLeft = Offset(0f, size.height - thickness),
                        size = Size(size.width, thickness),
                    )
                }
            }
            // 内容避让厚边：按钮总高不变，文字在"按钮面"内居中
            .padding(bottom = depth)
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

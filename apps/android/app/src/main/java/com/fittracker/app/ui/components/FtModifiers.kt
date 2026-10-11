package com.fittracker.app.ui.components

import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier

/**
 * 无涟漪点击。
 *
 * 原型的按压反馈一律是 `transform: scale(...)`（系数见
 * [com.fittracker.app.ui.theme.FtMotion]），不含 Material ripple。
 * `FtTheme` 已全局关闭涟漪；此扩展供屏内自绘的可点击元素使用，
 * 需要按压缩放的元素请自行叠加 `graphicsLayer`。
 */
@Composable
fun Modifier.clickableNoRipple(
    enabled: Boolean = true,
    onClick: () -> Unit,
): Modifier {
    val interaction = remember { MutableInteractionSource() }
    return this.clickable(
        interactionSource = interaction,
        indication = null,
        enabled = enabled,
        onClick = onClick,
    )
}

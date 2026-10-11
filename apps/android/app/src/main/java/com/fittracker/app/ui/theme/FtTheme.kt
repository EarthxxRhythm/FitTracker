package com.fittracker.app.ui.theme

import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.LocalRippleConfiguration
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Typography
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider

/**
 * FitTracker 主题。
 *
 * 色板来自 [FtColor]（原型 `:root` 规范值），字体来自 [FtType]。
 *
 * **涟漪已全局关闭**：原型没有 Material ripple，按压反馈一律是 `transform: scale(...)`
 * （系数见 [FtMotion]）。保留 ripple 会让按压态与原型不一致。
 */
private val FtColorScheme = darkColorScheme(
    primary = FtColor.accent,
    onPrimary = FtColor.onAccent,
    primaryContainer = FtColor.accentDeep,
    onPrimaryContainer = FtColor.onAccent,
    secondary = FtColor.accentSoft,
    onSecondary = FtColor.onAccent,
    background = FtColor.bg,
    onBackground = FtColor.txtBody,
    surface = FtColor.surface,
    onSurface = FtColor.txtHi,
    surfaceVariant = FtColor.surface2,
    onSurfaceVariant = FtColor.txtBody,
    outline = FtColor.line10,
    outlineVariant = FtColor.hairline,
    error = FtColor.warn,
)

private val FtTypography = Typography(
    displayLarge = FtType.display,
    headlineSmall = FtType.headline,
    titleLarge = FtType.titleLg,
    titleMedium = FtType.title,
    bodyLarge = FtType.bodyLg,
    bodyMedium = FtType.body,
    bodySmall = FtType.caption,
    labelLarge = FtType.captionStrong,
    labelMedium = FtType.label,
    labelSmall = FtType.micro,
)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun FtTheme(content: @Composable () -> Unit) {
    CompositionLocalProvider(LocalRippleConfiguration provides null) {
        MaterialTheme(
            colorScheme = FtColorScheme,
            typography = FtTypography,
            content = content,
        )
    }
}

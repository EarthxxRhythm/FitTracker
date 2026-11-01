package com.fittracker.app.ui.theme

import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.LocalRippleConfiguration
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Typography
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.remember
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.Density

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

/**
 * 视觉审查 P1：限制系统字号放大——本应用的字号上限（系统放大到该系数为止）。
 *
 * 原型（`web/`）按 1.0 系统字号排版：底栏 72、dock、进度环 46、弹层宽 342 都是固定几何。
 * 系统字号拉到 2.0 时文字必然撑破这些盒子。这里只在主题根生效一次：
 * [FtTheme] 把 `Density.fontScale` 夹到本上限，页面不必逐个 Text 处理。
 */
val LocalMaxFontScale = staticCompositionLocalOf { 1.3f }

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun FtTheme(content: @Composable () -> Unit) {
    val maxFontScale = LocalMaxFontScale.current
    val base = LocalDensity.current
    // 视觉审查 P1：限制系统字号放大——只夹 fontScale，density 原样透传（dp 尺寸仍 1:1）。
    val clampedDensity = remember(base.density, base.fontScale, maxFontScale) {
        Density(density = base.density, fontScale = base.fontScale.coerceAtMost(maxFontScale))
    }
    CompositionLocalProvider(
        LocalRippleConfiguration provides null,
        LocalDensity provides clampedDensity,
    ) {
        MaterialTheme(
            colorScheme = FtColorScheme,
            typography = FtTypography,
            content = content,
        )
    }
}

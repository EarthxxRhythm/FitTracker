package com.fittracker.app.ui.components

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.fittracker.app.nav.FtRoutes
import com.fittracker.app.ui.theme.FtColor
import com.fittracker.app.ui.theme.FtMotion
import com.fittracker.app.ui.theme.FtShape
import com.fittracker.app.ui.theme.FtType

/**
 * 底栏背景。用户要求：与内容区完全同色、去掉分界感 → 取页面底色 `#0F0F0F`
 * （原为原型 `.tabbar` 的 `rgba(8,12,15,.97)`，比内容区更暗、产生色阶）。
 */
private val TabbarBg = Color(0xF70F0F0F)

/**
 * 底部主导航（原型 `.tabbar`，`fittracker-welcome-home.html:606-667` + `:927-942`）。
 *
 * 五枚 Tab，顺序即 [FtRoutes.tabs]（home / plan / workout / review / profile）。
 * 中央一枚（workout）为胶囊形态：72×44、圆角 18，激活底色 `--accent-deep`，按压缩放 .96；
 * 其余四枚为纯文字（13px / 500，激活转 600 且转 `--nav-active`）。
 *
 * 已知偏差：原型 `box-shadow: 0 -8px 28px rgba(0,0,0,.28)` 的**向上投影**未复刻——
 * Compose 阴影向下投且此处位于屏幕底部，改为仅保留顶部 1px 描边。待视觉验收时复核。
 */
@Composable
fun FtBottomTabBar(
    currentRouteId: String,
    onSelect: (String) -> Unit,
    modifier: Modifier = Modifier,
) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            // 原型 `.tabbar` 向上投影 `box-shadow: 0 -8px 28px rgba(0,0,0,.28)` 的近似：
            // 底栏上缘 ~28dp 由透明渐入实底（透出页背景），消除内容区→底栏的硬色阶跳变（真机剖面 (19,23,26)→(8,12,15)）。
            .background(
                Brush.verticalGradient(
                    0f to Color.Transparent,
                    0.38f to TabbarBg,
                    1f to TabbarBg,
                ),
            )
            // 用户要求去掉分界感：不再绘制上缘 1px 描边（原型 `.tabbar` 的 border-top）
            // 自适应：Tab 栏是屏幕最底部的 chrome，必须避让系统导航栏
            // （三键导航约 48vp、手势条约 24vp）。背景随之下延至屏幕底。
            .navigationBarsPadding()
            .padding(horizontal = 16.dp, vertical = 8.dp),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        FtRoutes.tabs.forEach { route ->
            val active = route.id == currentRouteId
            if (route.isTabCenter) {
                FtCenterTab(active = active, onClick = { onSelect(route.id) })
            } else {
                FtTextTab(
                    label = route.tabLabel ?: route.label,
                    active = active,
                    onClick = { onSelect(route.id) },
                )
            }
        }
    }
}

@Composable
private fun RowScope.FtTextTab(
    label: String,
    active: Boolean,
    onClick: () -> Unit,
) {
    val interaction = remember { MutableInteractionSource() }
    Box(
        modifier = Modifier
            .height(56.dp)
            .weight(1f)
            .clip(FtShape.xxl)
            .clickable(interactionSource = interaction, indication = null, onClick = onClick),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = label,
            color = if (active) FtColor.navActive else FtColor.navInactive,
            fontSize = 13.sp,
            fontWeight = if (active) FontWeight.SemiBold else FontWeight.Medium,
            letterSpacing = 0.26.sp, // 原型 letter-spacing .02em × 13px
        )
    }
}

@Composable
private fun RowScope.FtCenterTab(
    active: Boolean,
    onClick: () -> Unit,
) {
    val interaction = remember { MutableInteractionSource() }
    val pressed by interaction.collectIsPressedAsState()
    // 裸值直送 graphicsLayer 是硬切（视觉上等于没有按压反馈），走 animateFloatAsState
    val scale by animateFloatAsState(
        targetValue = if (pressed) FtMotion.PRESS_SCALE_TAB_CENTER else 1f,
        animationSpec = tween(FtMotion.DURATION_PRESS, easing = FtMotion.EASE_MOTION),
        label = "tab-center-press-scale",
    )
    Box(
        modifier = Modifier
            .height(56.dp)
            .weight(1f)
            .clickable(interactionSource = interaction, indication = null, onClick = onClick),
        contentAlignment = Alignment.Center,
    ) {
        Box(
            modifier = Modifier
                .size(width = 72.dp, height = 44.dp)
                .graphicsLayer { scaleX = scale; scaleY = scale }
                .clip(FtShape.centerPill)
                // 原型 `.tab-center .pill`（L650-658）：默认底 `var(--accent)`；
                // `.tab-center.active .pill`（L662-665）：激活底 `var(--accent-deep)`——两态皆翡翠，无非激活灰。
                .background(if (active) FtColor.accentDeep else FtColor.accent),
            contentAlignment = Alignment.Center,
        ) {
            FtDumbbellIcon(
                modifier = Modifier.size(24.dp),
                // 原型 `.tab-center .pill { color: var(--on-accent) }`（L657）——恒深色前景
                color = FtColor.onAccent,
            )
        }
    }
}

/** 供后续屏复用的渐变工具占位（原型多处使用 `--cta-a → --cta-b`）。 */
internal fun ftCtaBrush(): Brush = Brush.linearGradient(listOf(FtColor.ctaA, FtColor.ctaB))

/** 类型令牌转发，减少组件内 import 噪声。 */
internal val ftTabLabelType = FtType.label

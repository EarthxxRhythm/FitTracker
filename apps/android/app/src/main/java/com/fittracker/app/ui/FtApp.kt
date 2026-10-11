package com.fittracker.app.ui

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.LinearOutSlowInEasing
import androidx.compose.animation.core.tween
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Scaffold
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.unit.dp
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import com.fittracker.app.nav.FtNavHost
import com.fittracker.app.nav.FtRoutes
import com.fittracker.app.nav.navigateToTab
import com.fittracker.app.ui.components.FtBottomTabBar
import com.fittracker.app.ui.theme.FtColor
import com.fittracker.app.ui.theme.FtTheme

// ── Tab 切换内容动效令牌（W2-5） ──────────────────────────────────────────
// 取值逐条来自原型 `select()`：`fittracker-welcome-home.html:964-995`
// （`fittracker-plan.html:917-946` 的 `selectTab()` 同构）。本文件是唯一消费点，
// 故就近定义；若出现第二个消费点应上移进 FtMotion（本轮 files 范围未覆盖 theme 层）。

/** 原型 `select()`：内容区回弹 `.16s`。 */
private const val TAB_SHIFT_DURATION_MS = 160

/** 原型 `select()`：起点 `translateX(8 * dir)px` —— 侧偏 8px，方向随 Tab 次序定正负。 */
private const val TAB_SHIFT_DISTANCE_DP = 8

/** 原型 `select()`：起点 `scale(.99)` —— 微缩。 */
private const val TAB_SHIFT_MIN_SCALE = 0.99f

/** 原型 `select()`：起点 `opacity .88` —— 压暗。 */
private const val TAB_SHIFT_MIN_ALPHA = 0.88f

/**
 * 应用外壳。
 *
 * 底部 Tab 栏**仅在 Tab 一级路由上出现**——与原型一致：`fittracker-welcome-home.html`
 * 里 `.appshell`（含 `.tabbar`）只包住 home/plan/workout/review/profile 五个 pane，
 * 而 login / active / settings 等屏是独立整屏，不带 Tab 栏。
 */
@Composable
fun FtApp() {
    FtTheme {
        val navController = rememberNavController()
        val backStackEntry by navController.currentBackStackEntryAsState()
        val currentId = backStackEntry?.destination?.route ?: FtRoutes.START
        // 底栏按**帧**判定，而非按路由的 Tab 属性：
        // `workout` 在 ROUTES 里确实是 Tab 一级入口（tabbar 中央胶囊就是它），
        // 但它加载的 `fittracker-training-preview.html` 是整屏帧
        // （`.pv-frame { position:absolute; inset:0 }`，文件内**没有** `.tabbar`），
        // 故该屏不渲染底栏——否则内容区矮一个底栏高，与原型参照帧对不齐。
        val onTab = FtRoutes.tabs.any { it.id == currentId } && currentId != "workout"

        // ── Tab 切换内容动效（W2-5，对齐原型 `select()`） ──────────────────
        // 原型语义：Tab 壳层**瞬时**换屏（`select()` 直接 classList.toggle，无过渡），
        // 动效只发生在**内容区** `#viewport` —— 先瞬时落到「侧偏 8px / 微缩 .99 /
        // 压暗 .88」的起点，再由 160ms 曲线回弹归位（`transition .16s
        // cubic-bezier(0, 0, .2, 1)`，opacity 用 `ease`）。
        //
        // 触发面：仅 Tab 一级路由之间的切换（含中央 workout）；splash 分流出的首屏、
        // 以及屏内跳转（如 home→settings）都不触发——原型里这些不经 `select()`。
        val tabIds = remember { FtRoutes.tabs.map { it.id } }
        var previousTabId by remember { mutableStateOf<String?>(null) }
        var shiftDirection by remember { mutableIntStateOf(1) }
        // 1f = 归位（无视觉效果）；每次 Tab 切换先 snapTo(0f) 落到起点再动画回 1f。
        val contentSettle = remember { Animatable(1f) }

        LaunchedEffect(currentId) {
            val from = previousTabId
            previousTabId = currentId
            val fromIndex = from?.let { tabIds.indexOf(it) } ?: -1
            val toIndex = tabIds.indexOf(currentId)
            // 非 Tab↔Tab（首次组合、splash 分流、屏内跳转）→ 保持静默。
            if (fromIndex < 0 || toIndex < 0 || fromIndex == toIndex) return@LaunchedEffect
            // 与原型 `ORDER.indexOf(key) >= ORDER.indexOf(current) ? 1 : -1` 同式。
            shiftDirection = if (toIndex > fromIndex) 1 else -1
            // 原型先 `transition='none'` + 强制 reflow 跳到起点，再恢复过渡回弹；
            // 对应 Compose 的「snapTo 起点 → animateTo 终点」。
            contentSettle.snapTo(0f)
            contentSettle.animateTo(
                targetValue = 1f,
                // `cubic-bezier(0, 0, .2, 1)` 即 Compose 内置 LinearOutSlowInEasing。
                animationSpec = tween(
                    durationMillis = TAB_SHIFT_DURATION_MS,
                    easing = LinearOutSlowInEasing,
                ),
            )
        }

        Scaffold(
            containerColor = FtColor.bg,
            // 关键：原型画布是**不含系统栏**的 390×844 整屏。
            // Scaffold 默认会按 systemBars 内缩内容区，导致 FtCanvas 的可用高变小、
            // fitScale 被算小（实测有效缩放 0.855 vs 原型 0.90698，且整体下移一个状态栏）。
            // 故显式清零 insets，让内容真正 edge-to-edge。
            contentWindowInsets = WindowInsets(0),
            bottomBar = {
                if (onTab) {
                    FtBottomTabBar(
                        currentRouteId = currentId,
                        onSelect = { navController.navigateToTab(it) },
                    )
                }
            },
        ) { inner ->
            FtNavHost(
                navController = navController,
                modifier = Modifier
                    .padding(inner)
                    // 动效施加在**内容区**（不含底栏），与原型作用于 `#viewport` 同级：
                    // 底栏不参与位移/缩放，Tab 间也不会出现整屏推入式位移。
                    .graphicsLayer {
                        val away = 1f - contentSettle.value // 1f = 未归位（起点），0f = 已归位
                        translationX = shiftDirection * TAB_SHIFT_DISTANCE_DP.dp.toPx() * away
                        val scale = 1f - (1f - TAB_SHIFT_MIN_SCALE) * away
                        scaleX = scale
                        scaleY = scale
                        alpha = 1f - (1f - TAB_SHIFT_MIN_ALPHA) * away
                    },
            )
        }
    }
}

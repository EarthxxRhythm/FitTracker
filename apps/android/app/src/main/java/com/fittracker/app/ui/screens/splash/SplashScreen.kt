package com.fittracker.app.ui.screens.splash

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.fittracker.app.R
import com.fittracker.app.data.auth.AuthService
import com.fittracker.app.data.persist.JsonStore
import com.fittracker.app.data.persist.appDataStore
import com.fittracker.app.data.service.AvatarImageService
import com.fittracker.app.data.sync.SyncOrchestrator
import com.fittracker.app.ui.components.FtBrandMark
import com.fittracker.app.ui.theme.FtType

/**
 * 启动页（规格源：鸿蒙 `features/pencil/pages/PencilSplashPage.ets`——无原型 HTML 帧，逐值移植）。
 *
 * 390×844 直绘，画布由 `FtCanvas` 施加；本文件 px 值 1:1 映射为 dp。
 * 启动分流（对齐鸿蒙 `PencilSplashPage.aboutToAppear` + `StartupDecision.getInitialRoute`）：
 * 未登录 → login（强制登录门槛）；已登录 → home（主壳）。跳转采用 replace 语义
 * （splash 出栈）——由 `FtNavHost` 对「从 splash 出发」的跳转统一清栈实现。
 *
 * 版式结构（源 `.ets build()`）：
 * - 底色 `#090C11` + 纵向渐变 `#0B0F13 → #0D1117(50%) → #090C11`（angle 180）；
 * - 全屏径向光晕（中心 195,202.56 / 半径 280：#1850ECA7 → 透明）；
 * - 204×204 圆光晕 @(113,184)（径向 #0D50ECA7 → 透明）；
 * - 品牌三同心圆 @(155,226)：120（#0F50ECA7 底 + 2px #50ECA7 边）→ 72（#1A50ECA7 + 1px #8850ECA7）→ 24 实心；
 * - 文案块 @(40,382) 宽 350；页脚彩蛋 @(40,786) 宽 350。
 */
@Composable
fun SplashScreen(
    onNavigate: (String) -> Unit,
    modifier: Modifier = Modifier,
) {
    val density = LocalDensity.current
    val context = LocalContext.current
    val store = remember { JsonStore(context.appDataStore) }

    // 启动分流（`StartupDecision.getInitialRoute`）：未登录 → login；已登录 → home。
    // 鸿蒙侧为 replaceUrl（替换当前页）；安卓侧由 FtNavHost 对 splash 出发的跳转清栈等效。
    LaunchedEffect(Unit) {
        val loggedIn: Boolean = AuthService.isLoggedIn(store)
        if (loggedIn) {
            // 冷启动已登录：后台静默同步（源 `requestBackgroundSync`——自动同步开启时生效，
            // 失败不抛出；隐私政策第五节「冷启动已登录」上行时机的实现点）
            SyncOrchestrator.requestBackgroundSync(
                store,
                SyncOrchestrator.forFilesDir(context.filesDir),
                AvatarImageService.resolveDir(context),
            )
        }
        onNavigate(if (loggedIn) "home" else "login")
    }

    Box(modifier.fillMaxSize().background(Color(0xFF090C11))) {
        // 纵向渐变底（angle 180：顶 → 底）
        Box(
            Modifier.fillMaxSize().background(
                Brush.verticalGradient(
                    colorStops = arrayOf(
                        0f to Color(0xFF0B0F13),
                        0.5f to Color(0xFF0D1117),
                        1f to Color(0xFF090C11),
                    ),
                ),
            ),
        )

        // 全屏径向光晕：中心 [195, 202.56]、半径 280（`radialGradient` 中心径向）
        val haloCenter = with(density) { Offset(195.dp.toPx(), 202.56.dp.toPx()) }
        val haloRadius = with(density) { 280.dp.toPx() }
        Box(
            Modifier.fillMaxSize().background(
                Brush.radialGradient(
                    colorStops = arrayOf(0f to Color(0x1850ECA7), 1f to Color(0x0050ECA7)),
                    center = haloCenter,
                    radius = haloRadius,
                ),
            ),
        )

        // 204×204 圆光晕 @(113,184)：中心 [102,102]、半径 102
        val orbCenter = with(density) { Offset(102.dp.toPx(), 102.dp.toPx()) }
        val orbRadius = with(density) { 102.dp.toPx() }
        Box(
            Modifier
                .offset(x = 113.dp, y = 184.dp)
                .size(204.dp)
                .background(
                    Brush.radialGradient(
                        colorStops = arrayOf(0f to Color(0x0D50ECA7), 1f to Color(0x0050ECA7)),
                        center = orbCenter,
                        radius = orbRadius,
                    ),
                    CircleShape,
                ),
        )

        BrandMark(
            modifier = Modifier.offset(x = 155.dp, y = 226.dp),
        )

        WelcomeBlock(
            modifier = Modifier
                .offset(x = 40.dp, y = 382.dp)
                .width(350.dp),
        )

        // 页脚彩蛋（Geist Mono 10px；本工程未内嵌 Geist Mono，回落 Monospace）
        Text(
            text = stringResource(R.string.splash_footer),
            style = FtType.natural(10f, family = FtType.mono),
            color = Color(0xFF6F7C87),
            textAlign = TextAlign.Center,
            modifier = Modifier
                .offset(x = 40.dp, y = 786.dp)
                .width(350.dp),
        )
    }
}

/** 品牌三同心圆：120 外圆 → 72 中圆 → 24 实心（`buildBrandMark`）。 */
@Composable
private fun BrandMark(modifier: Modifier = Modifier) {
    Box(
        modifier = modifier
            .size(120.dp)
            .background(Color(0x0F50ECA7), CircleShape)
            .border(width = 2.dp, color = Color(0xFF50ECA7), shape = CircleShape),
        contentAlignment = Alignment.Center,
    ) {
        Box(
            modifier = Modifier
                .size(72.dp)
                .background(Color(0x1A50ECA7), CircleShape)
                .border(width = 1.dp, color = Color(0x8850ECA7), shape = CircleShape),
            contentAlignment = Alignment.Center,
        ) {
            // 品牌标志（2026-10-09 用户设计稿）：C 形环 + 缺口中央圆点（替代原 24dp 实心圆）；
            // 保留原彩色光晕（原型 `shadow(radius:18, color:#8850ECA7)` 的 spot/ambient 近似）。
            FtBrandMark(
                modifier = Modifier
                    .size(44.dp)
                    .shadow(
                        elevation = 12.dp,
                        shape = CircleShape,
                        ambientColor = Color(0x8850ECA7),
                        spotColor = Color(0x8850ECA7),
                    ),
            )
        }
    }
}

/** 文案块：标语（Geist Mono 10 / 1.4 字距）→ 品名（Inter 34 Bold）→ 副标语（Inter 15 / 行高 1.45）。 */
@Composable
private fun WelcomeBlock(modifier: Modifier = Modifier) {
    Column(
        modifier = modifier,
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Text(
            text = stringResource(R.string.splash_tagline),
            style = FtType.natural(10f, 500, family = FtType.mono).copy(letterSpacing = 1.4.sp),
            color = Color(0xFF50ECA7),
            textAlign = TextAlign.Center,
            modifier = Modifier.fillMaxWidth(),
        )
        Text(
            text = stringResource(R.string.splash_brand),
            style = FtType.ft(34f, 700),
            color = Color(0xFFF5F7FA),
            textAlign = TextAlign.Center,
            modifier = Modifier.fillMaxWidth(),
        )
        Text(
            text = stringResource(R.string.splash_sub),
            style = FtType.ft(15f, 400, lineHeight = 21.75f), // 1.45 × 15
            color = Color(0xFFAAB4BF),
            textAlign = TextAlign.Center,
            modifier = Modifier.fillMaxWidth(),
        )
    }
}

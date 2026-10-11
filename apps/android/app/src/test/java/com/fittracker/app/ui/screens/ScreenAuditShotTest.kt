package com.fittracker.app.ui.screens

import android.graphics.Bitmap
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.size
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.asAndroidBitmap
import androidx.compose.ui.test.captureToImage
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onRoot
import androidx.compose.ui.unit.dp
import com.fittracker.app.nav.FtRoutes
import java.io.File
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

/**
 * 全屏体检拼图（临时探针）：把 `FtRoutes.navigable` 的每个路由按真机内容区尺寸渲染成一格，
 * 拼成一张总览图落盘，用于排查「底部留白 / 内容溢出」这类整体布局问题。
 *
 * 每格 = 422×832dp（真机内容区），**不含底栏**——比真机可用高度更高，故留白只会更明显、
 * 不会漏判。Scaled 画布的路由（welcome/login/register/complete）会按设计比例居中，四周留边属预期。
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34], qualifiers = "w390dp-h844dp-mdpi")
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class ScreenAuditShotTest {

    @get:Rule
    val rule = createComposeRule()

    private val columns = 4

    @Test
    fun `全部路由渲染成一张总览图`() {
        val routes = FtRoutes.navigable
        rule.setContent {
            Column {
                routes.chunked(columns).forEach { chunk ->
                    Row {
                        chunk.forEach { route ->
                            Box(modifier = Modifier.size(422.dp, 832.dp)) {
                                FtScreen(route = route, onNavigate = {}, onBack = {})
                            }
                        }
                    }
                }
            }
        }
        rule.waitForIdle()

        val sheet = rule.onRoot().captureToImage().asAndroidBitmap()
        val out = File(System.getProperty("java.io.tmpdir"), "ftshots")
        out.mkdirs()
        val file = File(out, "routes.png")
        file.outputStream().use { sheet.compress(Bitmap.CompressFormat.PNG, 90, it) }
        assertTrue("拼图未落盘：${file.absolutePath}", file.length() > 0)
    }
}

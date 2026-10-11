package com.fittracker.app.ui.screens.splash

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import com.fittracker.app.R
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * 启动域文案资源的**逐字真源**断言（Wave 8 i18n）。
 *
 * 该屏文案本就为英文（规格源：鸿蒙 `features/pencil/pages/PencilSplashPage.ets`，无原型 HTML 帧），
 * zh 默认区域逐字保留既有硬编码，故 zh / en 两侧断言同值。
 *
 * `splash_footer` 的 `·` 两侧各两个空格在资源里以 `\u0020` 转义书写（防止资源编译器折叠空白）——
 * 本测试按**真实空格**逐字节断言，是把「转义是否被正确解析」钉死在这里的唯一手段。
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34], qualifiers = "zh-rCN")
class FtSplashStringsTest {

    private val context: Context get() = ApplicationProvider.getApplicationContext()

    @Test
    fun `启动域文案逐字（zh 默认区域）`() {
        assertEquals(
            "YOUR DAILY TRAINING COMPANION",
            context.getString(R.string.splash_tagline),
        )
        assertEquals("FitTracker", context.getString(R.string.splash_brand))
        assertEquals(
            "Move better. Feel stronger.\nOne focused session at a time.",
            context.getString(R.string.splash_sub),
        )
        // 逐字节：`·` 两侧为两个半角空格（非折叠后的单个空格）
        assertEquals(
            "TRAIN WITH INTENTION  ·  RECOVER WITH PURPOSE",
            context.getString(R.string.splash_footer),
        )
    }

    /** English 资源生效（方法级区域限定符覆盖类级 `zh-rCN`）——本域 zh/en 同值。 */
    @Test
    @Config(sdk = [34], qualifiers = "en-rUS")
    fun `英文资源在 en 区域生效`() {
        assertEquals("YOUR DAILY TRAINING COMPANION", context.getString(R.string.splash_tagline))
        assertEquals("FitTracker", context.getString(R.string.splash_brand))
        assertEquals(
            "Move better. Feel stronger.\nOne focused session at a time.",
            context.getString(R.string.splash_sub),
        )
        assertEquals(
            "TRAIN WITH INTENTION  ·  RECOVER WITH PURPOSE",
            context.getString(R.string.splash_footer),
        )
    }
}

package com.fittracker.app.ui.screens.active

import android.content.Context
import android.content.ContextWrapper
import android.os.Vibrator
import android.os.VibratorManager
import androidx.test.core.app.ApplicationProvider
import org.junit.Assert.assertEquals
import org.junit.Assume.assumeTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config

/**
 * 「声音与震动」触觉反馈（计划 A4）的 JVM 契约测试。
 *
 * 分三层：
 * 1. [Haptics.VIBRATION_MS] 为 30ms——时长是对外承诺（真机手感锚点），改动必须可见；
 * 2. **守卫路径**（确定性）：系统服务缺失时静默返回、不抛异常——模拟器 / 无振动器设备上
 *    触觉反馈缺失不得影响训练记录推进（`completeSet` 里 `Haptics.confirm` 在记录推进之后）；
 * 3. **震动参数**：`shadowOf(vibrator)` 断言 30ms。本机 Gradle 缓存里只落到 SDK 34 的
 *    android-all（`~/.m2/repository/org/robolectric/android-all-instrumented/`，Robolectric 4.16
 *    无 `ShadowVibratorManager`），因此该用例先解析 `VIBRATOR_MANAGER_SERVICE`，服务不可用时
 *    `assumeTrue` **跳过**（不假绿、不假红）——真机手动验证仍是本项的最终判据
 *    （完成一组感到震动；关开关无震动）。
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class HapticsTest {

    private val context: Context get() = ApplicationProvider.getApplicationContext()

    @Test
    fun `确认震动时长为 30ms`() {
        assertEquals(30L, Haptics.VIBRATION_MS)
    }

    @Test
    fun `系统服务缺失时静默返回_不抛异常`() {
        val noService = object : ContextWrapper(context) {
            override fun getSystemService(name: String): Any? = null
        }
        // 两个分支（VibratorManager / Vibrator）都取不到服务——守卫必须吞掉，不向上抛
        Haptics.confirm(noService)
    }

    @Test
    fun `完成一组触发一次 30ms 震动`() {
        val vibrator: Vibrator? = runCatching {
            val manager = context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager
            manager?.defaultVibrator
        }.getOrNull()
        assumeTrue(
            "Robolectric 未提供可用的 VibratorManager（4.16 无该服务的 shadow）——本条转发真机验证",
            vibrator != null,
        )

        val shadow = shadowOf(vibrator!!)
        shadow.setHasVibrator(true)
        Haptics.confirm(context)

        assertEquals(30L, shadow.milliseconds)
    }
}

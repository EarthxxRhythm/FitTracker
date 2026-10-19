package com.fittracker.app.ui.screens.complete

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import com.fittracker.app.R
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * 训练完成域（complete 屏 + [FtCompleteModel]）文案资源的**逐字真源**断言（Wave 7 i18n）。
 *
 * 文案断言从 [FtCompleteModelTest]（纯逻辑、无 `Context`）拆出：模型只持资源 ID，
 * 逐字真值在 `values/strings_complete.xml`（zh）——此处以 `context.getString` 解析校验。
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34], qualifiers = "zh-rCN")
class FtCompleteStringsTest {

    private val context: Context = ApplicationProvider.getApplicationContext()

    @Test
    fun `complete 域文案中文逐字对齐原型`() {
        val expectations = listOf(
            R.string.complete_title to "训练完成",
            R.string.complete_subtitle to "今天的训练已保存，做得很好。",
            R.string.complete_streak_title to "训练连续记录",
            R.string.complete_streak_count to "连续 %1\$d 天",
            R.string.complete_a11y_streak to "本周连续训练记录：周一至周六已打卡，周日未打卡",
            R.string.complete_continue to "继续",
            R.string.complete_a11y_continue to "继续查看训练总结",
            R.string.complete_rpe_title to "本次训练强度",
            R.string.complete_rpe_hint to "1 轻松 · 10 极限",
            R.string.complete_rpe_unrated to "未评价",
            R.string.complete_rpe_value to "RPE %1\$d%2\$s",
            R.string.complete_rpe_saved to "\u0020· 已保存",
            R.string.complete_a11y_rpe_option to "训练强度 %1\$d 档，%2\$s",
            R.string.complete_a11y_rpe_selected to "已选中",
            R.string.complete_a11y_rpe_unselected to "未选中",
        )

        expectations.forEach { (id, expected) ->
            assertEquals("资源 id=$id 与原型中文不一致", expected, context.getString(id))
        }
    }

    @Test
    fun `连续天数插值逐字`() {
        assertEquals("连续 6 天", context.getString(R.string.complete_streak_count, 6))
    }

    /** English 资源生效（`values-en/strings_complete.xml`）——方法级区域限定符覆盖类级 `zh-rCN`。 */
    @Test
    @Config(sdk = [34], qualifiers = "en-rUS")
    fun `英文资源在 en 区域生效`() {
        assertEquals("Workout complete", context.getString(R.string.complete_title))
        assertEquals("6-day streak", context.getString(R.string.complete_streak_count, 6))
        assertEquals("Continue", context.getString(R.string.complete_continue))
    }
}

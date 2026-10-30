package com.fittracker.app.ui.screens.active

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import com.fittracker.app.R
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * 训练执行域（active 屏 + [FtActiveModel]）文案资源的**逐字真源**断言（Wave 7 i18n）。
 *
 * 文案断言从 [FtActiveModelTest]（纯逻辑、无 `Context`）拆出：带参文案由模型产出
 * 「资源 ID + 参数」，逐字真值在 `values/strings_active.xml`（zh）——此处以 `context.getString`
 * 解析校验（含插值）。
 *
 * `@Config(sdk = [34])`：项目 targetSdk 超 Robolectric 支持范围，须钉受支持 SDK。
 * `qualifiers = "zh-rCN"`：取 `values/` 中文真源；不钉则默认走 en 资源。
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34], qualifiers = "zh-rCN")
class FtActiveStringsTest {

    private val context: Context = ApplicationProvider.getApplicationContext()

    @Test
    fun `active 域文案中文逐字对齐原型`() {
        val expectations = listOf(
            R.string.active_progress_step to "第 %1\$d 组 / 共 %2\$d 组",
            R.string.active_progress_done to "训练完成 · 全部 %1\$d 组",
            R.string.active_elapsed_label to "总时长",
            R.string.active_a11y_progress to "训练组数进度",
            R.string.active_submit to "完成",
            R.string.active_submit_done to "已完成",
            R.string.active_demo_label to "动作",
            R.string.active_fallback_exercise to "杠铃卧推",
            R.string.active_demo_stage to "第 %1\$d 组 · 正式组",
            R.string.active_a11y_demo_gif to "%1\$s 动作演示",
            R.string.active_a11y_demo_visual to "%1\$s 动作演示图",
            R.string.active_empty_sets to "还没有完成组",
            R.string.active_set_index to "第 %1\$d 组",
            R.string.active_modal_eyebrow to "RECORD SET",
            R.string.active_modal_title to "记录本组",
            R.string.active_modal_subtitle to "%1\$s · 第 %2\$d 组",
            R.string.active_a11y_close_modal to "关闭弹窗",
            R.string.active_field_weight to "重量",
            R.string.active_field_reps to "次数",
            R.string.active_field_weight_unit to "KG",
            R.string.active_field_reps_unit to "8–10",
            R.string.active_a11y_decrease to "减少%1\$s",
            R.string.active_a11y_increase to "增加%1\$s",
            R.string.active_action_complete_set to "完成本组",
            R.string.active_celebrate_title to "本组完成",
            R.string.active_celebrate_subtitle to "做得很好",
            // 产品要求（2026-10-29）：主按钮文案由「提交」改为「完成」，并新增长按提前结束的提示文案。
            // 以下几条不再逐字对齐原型——需求变更优先于原型基线。
            R.string.active_hold_hint to "长按「完成」提前结束本动作",
            R.string.active_hold_cancel to "松开取消 · 继续按住结束本动作",
            R.string.active_exercise_full to "本动作已完成",
            R.string.active_exercise_ended to "本动作已结束",
            // 组胶囊：视觉三态（已完成 / 进行中 / 未开始）也得在无障碍描述里有三态，
            // 所以从单段「第 N 组」改成带状态词的组合文案。
            R.string.active_set_pill_a11y_state to "第 %1\$d 组，%2\$s",
            R.string.active_set_state_done to "已完成",
            R.string.active_set_state_current to "进行中",
            R.string.active_set_state_todo to "未开始",
            R.string.active_switch_exercise to "切换动作",
        )

        expectations.forEach { (id, expected) ->
            assertEquals("资源 id=$id 与原型中文不一致", expected, context.getString(id))
        }
    }

    /** 带参文案插值逐字（含 en dash `–`、间隔号 `·`、全角标点）。 */
    @Test
    fun `带参文案插值逐字`() {
        assertEquals("第 3 组 / 共 6 组", context.getString(R.string.active_progress_step, 3, 6))
        assertEquals("训练完成 · 全部 6 组", context.getString(R.string.active_progress_done, 6))
        assertEquals("杠铃卧推 · 第 2 组", context.getString(R.string.active_modal_subtitle, "杠铃卧推", 2))
        assertEquals("减少重量", context.getString(R.string.active_a11y_decrease, "重量"))
        assertEquals("第 5 组", context.getString(R.string.active_set_index, 5))
        assertEquals("第 3 组，已完成", context.getString(R.string.active_set_pill_a11y_state, 3, "已完成"))
    }

    /** English 资源生效（`values-en/strings_active.xml`）——方法级区域限定符覆盖类级 `zh-rCN`。 */
    @Test
    @Config(sdk = [34], qualifiers = "en-rUS")
    fun `英文资源在 en 区域生效`() {
        assertEquals("Set 3 of 6", context.getString(R.string.active_progress_step, 3, 6))
        assertEquals("Workout complete · all 6 sets", context.getString(R.string.active_progress_done, 6))
        assertEquals("Record set", context.getString(R.string.active_modal_title))
        assertEquals("Decrease Weight", context.getString(R.string.active_a11y_decrease, "Weight"))
        // 英文区域下组合文案的插值形状：`Set %1$d, %2$s` → `Set 3, completed`
        assertEquals("Set 3, completed", context.getString(R.string.active_set_pill_a11y_state, 3, "completed"))
    }
}

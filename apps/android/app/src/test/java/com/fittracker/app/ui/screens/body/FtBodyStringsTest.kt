package com.fittracker.app.ui.screens.body

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import com.fittracker.app.R
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * 身体数据域（body 屏 + [FtBodyModel]）文案资源的**逐字真源**断言（Wave 8 i18n）。
 *
 * 模型层产出 [FtBodyLabel]（资源 ID + 参数），逐字真值在 `values/strings_body.xml`（zh）——
 * 此处以 `context.getString` 解析校验（含插值）。
 *
 * `@Config(sdk = [34])`：项目 targetSdk 超 Robolectric 支持范围，须钉受支持 SDK。
 * `qualifiers = "zh-rCN"`：取 `values/` 中文真源；en 用方法级 `qualifiers = "en-rUS"` 覆盖。
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34], qualifiers = "zh-rCN")
class FtBodyStringsTest {

    private val context: Context = ApplicationProvider.getApplicationContext()

    @Test
    fun `body 域文案中文逐字对齐原型`() {
        val expectations = listOf(
            R.string.body_a11y_back to "返回个人页",
            R.string.body_title to "身体数据",
            R.string.body_weight_label to "当前体重",
            R.string.body_updated to "更新于 %1\$s",
            R.string.body_delta_last_week to "较上周 %1\$s",
            R.string.body_delta_saved to "今日已记录 · 刚刚",
            R.string.body_goal_label to "增肌目标 %1\$s %2\$s",
            R.string.body_goal_gap to "还差 %1\$s %2\$s",
            R.string.body_goal_reached to "已达目标",
            R.string.body_composition_title to "身体成分",
            R.string.body_composition_meta to "目标 · 增肌",
            R.string.body_fat_label to "体脂率 · 健康区间 10–20%",
            R.string.body_fat_scale_low to "偏低",
            R.string.body_fat_scale_normal to "健康",
            R.string.body_fat_scale_high to "偏高",
            R.string.body_metric_bmi to "BMI",
            R.string.body_metric_bmi_note to "正常范围",
            R.string.body_metric_muscle to "骨骼肌",
            R.string.body_metric_muscle_note to "标准",
            R.string.body_metric_bmr to "基础代谢",
            R.string.body_metric_bmr_note to "估算值",
            R.string.body_metric_water to "身体水分",
            R.string.body_metric_water_note to "正常范围",
            R.string.body_trend_title to "体重趋势",
            R.string.body_a11y_trend_range to "趋势时间范围",
            R.string.body_trend_empty to "暂无记录 · 记录体重后生成趋势",
            R.string.body_period_week to "周",
            R.string.body_period_month to "月",
            R.string.body_period_year to "年",
            R.string.body_trend_caption_week to "近 7 天 · %1\$s",
            R.string.body_trend_caption_month to "近 30 天 · %1\$s",
            R.string.body_trend_caption_year to "近 12 个月 · %1\$s",
            R.string.body_trend_caption_range to "%1\$s · %2\$s",
            R.string.body_measure_title to "围度记录",
            R.string.body_measure_meta to "较上月",
            R.string.body_measure_chest to "胸围",
            R.string.body_measure_waist to "腰围",
            R.string.body_measure_hip to "臀围",
            R.string.body_measure_arm to "臂围",
            R.string.body_measure_thigh to "大腿围",
            R.string.body_cta to "记录今日体重",
            R.string.body_foot_note_kg to "身体数据仅保存在本机；单位可在「设置」中切换为磅（lbs）。",
            R.string.body_foot_note_lbs to "身体数据仅保存在本机；单位可在「设置」中切换为千克（kg）。",
            R.string.body_sheet_title to "记录今日体重",
            R.string.body_sheet_sub to "每次记录都会被纳入体重趋势",
            R.string.body_sheet_cancel to "取消",
            R.string.body_sheet_save to "保存",
            R.string.body_sheet_input_a11y to "今日体重",
            R.string.body_invalid_hint to "请输入 0–500 之间的有效体重",
        )

        expectations.forEach { (id, expected) ->
            assertEquals("资源 id=$id 与原型中文不一致", expected, context.getString(id))
        }
    }

    /** 带参文案插值逐字（含 U+2212 减号、U+00B7 中点、全角标点）。 */
    @Test
    fun `body 带参文案插值逐字`() {
        assertEquals("更新于 07:40", context.getString(R.string.body_updated, "07:40"))
        assertEquals("较上周 −0.3 kg", context.getString(R.string.body_delta_last_week, "−0.3 kg"))
        assertEquals("增肌目标 74.0 kg", context.getString(R.string.body_goal_label, "74.0", "kg"))
        assertEquals("还差 1.5 kg", context.getString(R.string.body_goal_gap, "1.5", "kg"))
        assertEquals("近 7 天 · −0.3 kg", context.getString(R.string.body_trend_caption_week, "−0.3 kg"))
        assertEquals("近 30 天 · +0.7 kg", context.getString(R.string.body_trend_caption_month, "+0.7 kg"))
        assertEquals("近 7 天 · −0.3 kg", context.getString(R.string.body_trend_caption_range, "近 7 天", "−0.3 kg"))
    }

    /** English 资源生效（`values-en/strings_body.xml`）——方法级区域限定符覆盖类级 `zh-rCN`。 */
    @Test
    @Config(sdk = [34], qualifiers = "en-rUS")
    fun `body 英文资源在 en 区域生效`() {
        assertEquals("Body Data", context.getString(R.string.body_title))
        assertEquals("Current weight", context.getString(R.string.body_weight_label))
        assertEquals("Updated 07:40", context.getString(R.string.body_updated, "07:40"))
        assertEquals("Muscle-gain goal 74.0 kg", context.getString(R.string.body_goal_label, "74.0", "kg"))
        assertEquals("Goal reached", context.getString(R.string.body_goal_reached))
        assertEquals("Last 7 days · −0.3 kg", context.getString(R.string.body_trend_caption_week, "−0.3 kg"))
        assertEquals("Log today's weight", context.getString(R.string.body_cta))
    }
}

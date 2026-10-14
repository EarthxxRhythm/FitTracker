package com.fittracker.app.ui.screens.review

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import com.fittracker.app.R
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * 回顾域（review 屏 + [FtReviewModel]）文案资源的**逐字真源**断言（Wave 7 i18n）。
 *
 * 文案断言从 [FtReviewModelTest]（纯逻辑、无 `Context`）拆出：模型只持资源 ID，
 * 逐字真值在 `values/strings_review.xml`（zh，原型 `fittracker-review.html` L1120-1563 与
 * 既有硬编码）——此处以 `context.getString` 解析校验。改动中文即红。
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34], qualifiers = "zh-rCN")
class FtReviewStringsTest {

    private val context: Context get() = ApplicationProvider.getApplicationContext()

    @Test
    fun `回顾域文案中文逐字对齐原型`() {
        val expectations = listOf(
            R.string.review_scale_week to "周",
            R.string.review_scale_month to "月",
            R.string.review_head_week to "本周 · %1\$s",
            R.string.review_head_month to "本月 · %1\$d月",
            R.string.review_head_week_sample to "本周 · 6月 7–13日",
            R.string.review_head_month_sample to "本月 · 6月",
            R.string.review_stat_workouts to "训练",
            R.string.review_stat_duration to "时长",
            R.string.review_stat_weight_change to "体重变化",
            R.string.review_unit_times to "次",
            R.string.review_unit_minutes to "分钟",
            R.string.review_unit_kg to "kg",
            R.string.review_week_headline to "状态不错，继续保持。",
            R.string.review_week_desc to "你比上周多完成了 1 次训练，平均训练时长也提升了 12 分钟。",
            R.string.review_week_sub to "过去 7 天",
            R.string.review_month_headline to "本月节奏更稳定。",
            R.string.review_month_desc to "本月已完成 17 次训练，平均每周 4 次，累计训练 720 分钟。",
            R.string.review_month_sub to "每天 · 越深量越大",
            R.string.review_activity_title to "训练节奏",
            R.string.review_month_label to "%1\$d 年 %2\$d 月",
            R.string.review_month_label_sample to "2026 年 6 月",
            R.string.review_month_meta to "训练 %1\$d 天 · %2\$d 分钟",
            R.string.review_month_meta_sample to "训练 17 天 · 720 分钟",
            R.string.review_month_tip to "一格代表一天 · 颜色越深，当天训练量越大",
            R.string.review_month_legend_none to "未练",
            R.string.review_month_legend_light to "轻",
            R.string.review_month_legend_medium to "中",
            R.string.review_month_legend_high to "高",
            R.string.review_month_legend_max to "大",
            R.string.review_muscle_title to "肌肉地图",
            R.string.review_muscle_a11y_mode to "肌肉地图模式",
            R.string.review_muscle_legend_low to "低",
            R.string.review_muscle_legend_high to "高",
            R.string.review_muscle_mode_balance to "平衡",
            R.string.review_muscle_mode_fatigue to "疲劳",
            R.string.review_muscle_mode_strength to "力量",
            R.string.review_muscle_meta_balance to "近 30 天 · 训练量",
            R.string.review_muscle_meta_fatigue to "当前恢复状态",
            R.string.review_muscle_meta_strength to "力量与最佳成绩",
            R.string.review_muscle_note_balance to "胸部训练量最高，核心最少。",
            R.string.review_muscle_note_fatigue to "腿部与臀部疲劳度较高，建议优先恢复。",
            R.string.review_muscle_note_strength to "胸部与腿部力量最强，核心相对薄弱。",
            R.string.review_muscle_trapezius to "斜方肌",
            R.string.review_muscle_deltoids to "肩",
            R.string.review_muscle_chest to "胸",
            R.string.review_muscle_upper_back to "上背",
            R.string.review_muscle_serratus to "前锯肌",
            R.string.review_muscle_biceps to "二头",
            R.string.review_muscle_triceps to "三头",
            R.string.review_muscle_forearm to "前臂",
            R.string.review_muscle_abs to "腹",
            R.string.review_muscle_obliques to "腹斜肌",
            R.string.review_muscle_lower_back to "下背",
            R.string.review_muscle_gluteal to "臀",
            R.string.review_muscle_quadriceps to "股四头",
            R.string.review_muscle_hamstring to "腘绳肌",
            R.string.review_muscle_adductors to "内收肌",
            R.string.review_muscle_hip_flexors to "髋屈肌",
            R.string.review_muscle_calves to "小腿",
            R.string.review_muscle_tibialis to "胫骨",
            R.string.review_muscle_detail_sets to "%1\$d 组",
            R.string.review_muscle_recovery_0 to "已恢复",
            R.string.review_muscle_recovery_1 to "恢复中",
            R.string.review_muscle_recovery_2 to "略疲劳",
            R.string.review_muscle_recovery_3 to "疲劳",
            R.string.review_muscle_strength_0 to "弱",
            R.string.review_muscle_strength_1 to "一般",
            R.string.review_muscle_strength_2 to "中",
            R.string.review_muscle_strength_3 to "强",
            R.string.review_muscle_detail_none to "—",
            R.string.review_weight_title to "体重与目标",
            R.string.review_weight_foot_current to "当前",
            R.string.review_weight_delta_sample to "较上月 -0.8 kg",
            R.string.review_weight_delta_month to "较上月 %1\$s",
            R.string.review_weight_goal_label to "目标 %1\$s kg",
            R.string.review_weight_goal_a11y_open to "设置体重目标",
            R.string.review_goal_modal_title to "设置体重目标",
            R.string.review_goal_modal_desc to "输入你的目标体重，更新曲线上的目标线。",
            R.string.review_goal_modal_a11y_input to "目标体重",
            R.string.review_goal_modal_unit to "kg",
            R.string.review_goal_modal_cancel to "取消",
            R.string.review_goal_modal_save to "保存",
            R.string.review_1rm_title to "估算 1RM",
            R.string.review_1rm_meta to "来自最佳有效组",
            R.string.review_1rm_sample_bench_press to "杠铃卧推",
            R.string.review_1rm_sample_squat to "杠铃深蹲",
            R.string.review_1rm_sample_deadlift to "杠铃硬拉",
            R.string.review_1rm_sample_row to "杠铃划船",
            R.string.review_1rm_sample_bench_press_src to "6月10日 · 第3组",
            R.string.review_1rm_sample_squat_src to "6月8日 · 第2组",
            R.string.review_1rm_sample_deadlift_src to "6月5日 · 第1组",
            R.string.review_1rm_sample_row_src to "6月3日 · 第2组",
            R.string.review_effort_title to "努力程度",
            R.string.review_effort_meta to "Effort · RIR / RPE",
            R.string.review_effort_a11y_scale to "努力程度刻度",
            R.string.review_effort_note to "RIR 记的是你还剩几次；RPE 用 0–10 表示主观用力，RPE ≈ 10 − RIR。",
            R.string.review_effort_unit to "%1\$s · 近 8 次平均",
        )

        expectations.forEach { (id, expected) ->
            assertEquals("资源 id=$id 与原型中文不一致", expected, context.getString(id))
        }
        assertEquals("资源条数（zh）", 97, expectations.size)
    }

    /** 带参模板的插值结果（原型样例值）。 */
    @Test
    fun `回顾域带参模板插值逐字`() {
        assertEquals("本周 · 6月 7–13日", context.getString(R.string.review_head_week, "6月 7–13日"))
        assertEquals("本月 · 6月", context.getString(R.string.review_head_month, 6))
        assertEquals("2026 年 6 月", context.getString(R.string.review_month_label, 2026, 6))
        assertEquals("训练 2 天 · 35 分钟", context.getString(R.string.review_month_meta, 2, 35))
        assertEquals("较上月 -0.8 kg", context.getString(R.string.review_weight_delta_month, "-0.8 kg"))
        assertEquals("目标 68 kg", context.getString(R.string.review_weight_goal_label, "68"))
        assertEquals("48 组", context.getString(R.string.review_muscle_detail_sets, 48))
        assertEquals("RIR · 近 8 次平均", context.getString(R.string.review_effort_unit, "RIR"))
        assertEquals("RPE · 近 8 次平均", context.getString(R.string.review_effort_unit, "RPE"))
    }

    /** English 资源生效（`values-en/strings_review.xml`）——方法级区域限定符覆盖类级 `zh-rCN`。 */
    @Test
    @Config(sdk = [34], qualifiers = "en-rUS")
    fun `英文资源在 en 区域生效`() {
        assertEquals("Week", context.getString(R.string.review_scale_week))
        assertEquals("Current", context.getString(R.string.review_weight_foot_current))
        assertEquals("Save", context.getString(R.string.review_goal_modal_save))
        assertEquals("This week · Jun 7–13", context.getString(R.string.review_head_week_sample))
        assertEquals("RIR · 8-session average", context.getString(R.string.review_effort_unit, "RIR"))
        assertEquals("6/2026", context.getString(R.string.review_month_label, 2026, 6))
        assertEquals("Chest", context.getString(R.string.review_muscle_chest))
    }
}

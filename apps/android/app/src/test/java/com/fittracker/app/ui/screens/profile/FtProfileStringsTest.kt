package com.fittracker.app.ui.screens.profile

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import com.fittracker.app.R
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * 个人域（profile 屏 + [FtProfileModel]）文案资源的**逐字真源**断言（Wave 8 i18n）。
 *
 * 文案真值在 `values/strings_profile.xml`（zh，逐字取自原型
 * `design/06_prototype_redraw/src/fittracker-personal.html` L1366-1452 与既有硬编码）——
 * 此处以 `context.getString` 解析校验，改动中文即红。
 *
 * 本域文案**无位置参数**（数值如「186」「4」「1,240」由数据层注入，不落资源），
 * 故断言里无需 `%1\$s` / `%1\$d` 转义。
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34], qualifiers = "zh-rCN")
class FtProfileStringsTest {

    private val context: Context get() = ApplicationProvider.getApplicationContext()

    @Test
    fun `个人域文案中文逐字对齐原型`() {
        val expectations = listOf(
            // 头部（L1369-1378）
            R.string.profile_sample_avatar_initial to "林",
            R.string.profile_sample_name to "林默",
            R.string.profile_sample_sub to "增肌第 42 天 · 保持节奏",
            R.string.profile_a11y_settings to "设置",
            // 本周概览（L1380-1403）
            R.string.profile_week_title to "本周概览",
            R.string.profile_week_meta_sample to "7 月 21 – 27 日",
            R.string.profile_week_unit to "分钟",
            R.string.profile_week_label to "本周训练时长",
            R.string.profile_week_metric_workouts to "训练",
            R.string.profile_week_metric_burned to "消耗",
            R.string.profile_unit_times to "次",
            R.string.profile_unit_kcal to "千卡",
            // 训练连续记录（L1405-1419）
            R.string.profile_streak_title to "训练连续记录",
            R.string.profile_streak_count to "连续 6 天",
            R.string.profile_streak_day_mon to "一",
            R.string.profile_streak_day_tue to "二",
            R.string.profile_streak_day_wed to "三",
            R.string.profile_streak_day_thu to "四",
            R.string.profile_streak_day_fri to "五",
            R.string.profile_streak_day_sat to "六",
            R.string.profile_streak_day_sun to "日",
            // 最近成就（L1421-1439）
            R.string.profile_achievements_title to "最近成就",
            R.string.profile_achievement_streak_title to "稳定输出",
            R.string.profile_achievement_streak_note to "连续训练 7 天",
            R.string.profile_achievement_streak_value to "本周完成度 86%",
            R.string.profile_achievement_pr_title to "重量突破",
            // 重量为 `%1$s` 占位符——实际文案按「设置 · 体重单位」换算后注入（原「深蹲达到 80 kg」）。
            R.string.profile_achievement_pr_note to "深蹲达到 %1\$s",
            R.string.profile_achievement_pr_value to "刷新个人最佳",
            // 快捷入口（L1441-1452）
            R.string.profile_shortcut_body to "身体数据",
            R.string.profile_shortcut_training_preferences to "训练偏好",
            R.string.profile_shortcut_library to "动作库",
        )

        expectations.forEach { (id, expected) ->
            assertEquals("资源 id=$id 与原型中文不一致", expected, context.getString(id))
        }
        assertEquals("资源条数（zh）", 31, expectations.size)
    }

    /** 模型层持有的资源 ID 与真值一致（防止模型 ↔ 资源错位）。 */
    @Test
    fun `模型层资源引用指向本域真值`() {
        assertEquals("林", context.getString(FtProfileModel.SAMPLE_AVATAR_INITIAL_RES))
        assertEquals("林默", context.getString(FtProfileModel.SAMPLE_NAME_RES))
        assertEquals("设置", context.getString(FtProfileModel.SETTINGS_A11Y_RES))
        assertEquals("本周概览", context.getString(FtProfileModel.WEEK_TITLE_RES))
        assertEquals("分钟", context.getString(FtProfileModel.WEEK_UNIT_RES))
        assertEquals("训练连续记录", context.getString(FtProfileModel.STREAK_TITLE_RES))
        assertEquals("最近成就", context.getString(FtProfileModel.ACHIEVEMENTS_TITLE_RES))
        assertEquals("本周训练时长", context.getString(FtProfileModel.WEEK_LABEL_RES))
        assertEquals(
            listOf("训练", "消耗"),
            FtProfileModel.WEEK_METRICS.map { context.getString(it.labelRes) },
        )
        assertEquals(
            listOf("次", "千卡"),
            FtProfileModel.WEEK_METRICS.map { context.getString(it.unitRes) },
        )
        assertEquals(
            listOf("一", "二", "三", "四", "五", "六", "日"),
            FtProfileModel.STREAK_DAYS.map { context.getString(it.labelRes) },
        )
        assertEquals(
            listOf("稳定输出", "重量突破"),
            FtProfileModel.ACHIEVEMENTS.map { context.getString(it.titleRes) },
        )
        assertEquals(
            listOf("身体数据", "训练偏好", "动作库"),
            FtProfileModel.SHORTCUTS.map { context.getString(it.labelRes) },
        )
        assertEquals(
            listOf("body", "trainingPreferences", "library"),
            FtProfileModel.SHORTCUTS.map { it.route },
        )
        assertEquals("settings", FtProfileModel.SETTINGS_ROUTE)
    }

    /** English 资源生效（`values-en/strings_profile.xml`）——方法级区域限定符覆盖类级 `zh-rCN`。 */
    @Test
    @Config(sdk = [34], qualifiers = "en-rUS")
    fun `英文资源在 en 区域生效`() {
        assertEquals("Weekly overview", context.getString(R.string.profile_week_title))
        assertEquals("Jul 21 – 27", context.getString(R.string.profile_week_meta_sample))
        assertEquals("6-day streak", context.getString(R.string.profile_streak_count))
        assertEquals("Exercise library", context.getString(R.string.profile_shortcut_library))
        assertEquals("Settings", context.getString(R.string.profile_a11y_settings))
        assertEquals("kcal", context.getString(R.string.profile_unit_kcal))
        assertEquals("M", context.getString(R.string.profile_streak_day_mon))
        assertEquals("Lin Mo", context.getString(R.string.profile_sample_name))
    }
}

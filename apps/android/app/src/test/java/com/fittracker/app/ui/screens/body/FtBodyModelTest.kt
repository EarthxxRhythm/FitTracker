package com.fittracker.app.ui.screens.body

import com.fittracker.app.R
import com.fittracker.app.data.service.WeightUnit
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * FtBodyModel 单位换算链 + 文案资源载体的契约测试。
 *
 * Wave 8 i18n 改造后，本域文案改为字符串资源 ID（`values/strings_body.xml` 为逐字真源），
 * 模型层产出 [FtBodyLabel]（资源 ID + 参数）而不解出字符串——故此处断言
 * **资源 ID 与位置参数**（无需 `Context`），中文/英文逐字真值由资源测试
 * （Robolectric `@Config(qualifiers = "zh-rCN" / "en-rUS")`）覆盖。
 *
 * 断言口径：
 * - 特殊字符锁定：`−` 为 U+2212（不是 ASCII `-`）、`·` 为 U+00B7 中点。
 * - [WeightUnit.LBS] 断言换算值（×[FtBodyModel.LBS_PER_KG] 后 `%.1f`）与单位标签 `lbs`。
 * - 边界：`toKilograms(toDisplay(x))` 往返、`goalGap` 达标分支、`formatWeight` 舍入。
 *
 * 纯逻辑层无 Android 依赖（仅 `R` 常量 / [WeightUnit] / `java.util.Locale` / `kotlin.math`），
 * 故用纯 JVM 单测（无需 Robolectric）。
 */
class FtBodyModelTest {

    // ── 单位标签 ────────────────────────────────────────────────────

    @Test
    fun `单位标签为设置项 id`() {
        assertEquals("kg", FtBodyModel.unitLabel(WeightUnit.KG))
        assertEquals("lbs", FtBodyModel.unitLabel(WeightUnit.LBS))
        assertEquals(WeightUnit.KG.id, FtBodyModel.unitLabel(WeightUnit.KG))
        assertEquals(WeightUnit.LBS.id, FtBodyModel.unitLabel(WeightUnit.LBS))
    }

    // ── KG：资源 ID 与参数 ──────────────────────────────────────────

    @Test
    fun `KG_主数值格式与目标标签`() {
        assertEquals("72.5", FtBodyModel.formatDisplay(FtBodyModel.INITIAL_WEIGHT, WeightUnit.KG))
        val goal = FtBodyModel.goalLabel(WeightUnit.KG)
        assertEquals(R.string.body_goal_label, goal.res)
        assertEquals(listOf("74.0", "kg"), goal.args)
    }

    @Test
    fun `delta文案锁定资源与U+2212减号`() {
        val delta = FtBodyModel.deltaInitial(WeightUnit.KG)
        assertEquals(R.string.body_delta_last_week, delta.res)
        assertEquals(listOf("−0.3 kg"), delta.args)
        val arg = delta.args[0] as String
        assertTrue("应含 U+2212 减号：$arg", '\u2212' in arg)
        assertFalse("不应含 ASCII 连字符", '-' in arg)
    }

    @Test
    fun `趋势标题资源随尺度切换`() {
        assertEquals(R.string.body_trend_caption_week, FtBodyModel.trendCaption(TrendPeriod.WEEK, WeightUnit.KG).res)
        assertEquals(R.string.body_trend_caption_month, FtBodyModel.trendCaption(TrendPeriod.MONTH, WeightUnit.KG).res)
        assertEquals(R.string.body_trend_caption_year, FtBodyModel.trendCaption(TrendPeriod.YEAR, WeightUnit.KG).res)
        assertEquals(listOf("−0.3 kg"), FtBodyModel.trendCaption(TrendPeriod.WEEK, WeightUnit.KG).args)
        assertEquals(listOf("+0.7 kg"), FtBodyModel.trendCaption(TrendPeriod.MONTH, WeightUnit.KG).args)
        assertEquals(listOf("+4.5 kg"), FtBodyModel.trendCaption(TrendPeriod.YEAR, WeightUnit.KG).args)
    }

    @Test
    fun `带符号差值锁定U+00B7中点用于caption`() {
        // trendCaption(TrendPeriod.WEEK, LBS) 的差值参数为 `−0.7 lbs`（0.3 kg → 0.7 lbs）。
        val lbs = FtBodyModel.trendCaption(TrendPeriod.WEEK, WeightUnit.LBS)
        assertEquals(listOf("−0.7 lbs"), lbs.args)
        // 单位标签与符号随单位换算。
        assertEquals("+9.9 lbs", FtBodyModel.signedWeight(4.5, WeightUnit.LBS))
    }

    @Test
    fun `目标缺口资源与达标分支`() {
        val gap = FtBodyModel.goalGap(FtBodyModel.INITIAL_WEIGHT, WeightUnit.KG)
        assertEquals(R.string.body_goal_gap, gap.res)
        assertEquals(listOf("1.5", "kg"), gap.args)

        assertEquals(R.string.body_goal_reached, FtBodyModel.goalGap(74.0, WeightUnit.KG).res)
        assertEquals(R.string.body_goal_reached, FtBodyModel.goalGap(73.96, WeightUnit.KG).res)
        assertEquals(R.string.body_goal_reached, FtBodyModel.goalGap(80.0, WeightUnit.KG).res)
        assertEquals(R.string.body_goal_reached, FtBodyModel.goalGap(80.0, WeightUnit.LBS).res)
        assertEquals(listOf("0.1", "kg"), FtBodyModel.goalGap(73.9, WeightUnit.KG).args)
    }

    @Test
    fun `脚注资源随单位改写`() {
        assertEquals(R.string.body_foot_note_kg, FtBodyModel.footNote(WeightUnit.KG))
        assertEquals(R.string.body_foot_note_lbs, FtBodyModel.footNote(WeightUnit.LBS))
    }

    @Test
    fun `身体成分仅换算质量格`() {
        assertEquals(FtBodyModel.METRICS, FtBodyModel.metrics(WeightUnit.KG))

        val metrics = FtBodyModel.metrics(WeightUnit.LBS)
        assertEquals(4, metrics.size)

        // 骨骼肌 34.2 kg → 75.4 lbs，单位标签改写为 lbs。
        val muscle = metrics.first { it.labelRes == R.string.body_metric_muscle }
        assertEquals("75.4", muscle.value)
        assertEquals("lbs", muscle.unit)

        // 非质量格（BMI / 基础代谢 kcal / 身体水分 %）保持原值。
        assertEquals(FtBodyModel.METRICS[0], metrics[0]) // BMI（无单位）
        assertEquals("1710", metrics[2].value)
        assertEquals("kcal", metrics[2].unit)
        assertEquals("58.2", metrics[3].value)
        assertEquals("%", metrics[3].unit)
    }

    // ── LBS：换算值 ─────────────────────────────────────────────────

    @Test
    fun `LBS_换算系数与往返`() {
        assertEquals(2.2046226218, FtBodyModel.LBS_PER_KG, 0.0)
        assertEquals(159.8351410805, FtBodyModel.toDisplay(72.5, WeightUnit.LBS), 1e-6)
    }

    @Test
    fun `LBS_主数值与目标标签`() {
        assertEquals("159.8", FtBodyModel.formatDisplay(FtBodyModel.INITIAL_WEIGHT, WeightUnit.LBS))
        assertEquals(listOf("163.1", "lbs"), FtBodyModel.goalLabel(WeightUnit.LBS).args)
    }

    // ── 边界 ────────────────────────────────────────────────────────

    @Test
    fun `换算往返回到千克基准`() {
        listOf(0.3, 1.5, 72.5, 74.0, 34.2).forEach { kg ->
            val round = FtBodyModel.toKilograms(FtBodyModel.toDisplay(kg, WeightUnit.LBS), WeightUnit.LBS)
            assertEquals("往返 $kg", kg, round, 1e-9)
        }
        assertEquals(72.5, FtBodyModel.toKilograms(72.5, WeightUnit.KG), 0.0)
    }

    @Test
    fun `formatWeight按一位小数舍入`() {
        assertEquals("74.0", FtBodyModel.formatWeight(74.0))
        assertEquals("72.5", FtBodyModel.formatWeight(72.46))
        assertEquals("72.4", FtBodyModel.formatWeight(72.41))
        assertEquals("159.8", FtBodyModel.formatWeight(159.8351410805))
    }

    @Test
    fun `goalPercent为四舍五入且封顶100`() {
        assertEquals(98, FtBodyModel.goalPercent(FtBodyModel.INITIAL_WEIGHT))
        assertEquals(FtBodyModel.INITIAL_GOAL_PERCENT, FtBodyModel.goalPercent(FtBodyModel.INITIAL_WEIGHT))
        assertEquals(100, FtBodyModel.goalPercent(74.0))
        assertEquals(100, FtBodyModel.goalPercent(80.0))
        assertEquals(50, FtBodyModel.goalPercent(37.0))
    }

    @Test
    fun `体重校验范围`() {
        assertTrue(FtBodyModel.isWeightValid(0.1))
        assertTrue(FtBodyModel.isWeightValid(500.0))
        assertFalse(FtBodyModel.isWeightValid(0.0))
        assertFalse(FtBodyModel.isWeightValid(501.0))
        assertFalse(FtBodyModel.isWeightValid(null))
        assertEquals(72.5, FtBodyModel.parseWeight(" 72.5 ")!!, 0.0)
        assertEquals(null, FtBodyModel.parseWeight("abc"))
    }

    @Test
    fun `折线点按min_max归一化`() {
        val series = TrendSeries(
            values = listOf(1f, 2f, 3f, 4f, 5f, 6f, 7f),
            labels = listOf("", "", "", "", "", "", ""),
        )
        val points = FtBodyModel.chartPoints(series)
        assertEquals(7, points.size)
        // 最低点贴底、最高点贴顶。
        assertEquals(FtBodyModel.CHART_BOTTOM, points.first().second, 1e-4f)
        assertEquals(FtBodyModel.CHART_TOP, points.last().second, 1e-4f)
        assertEquals(FtBodyModel.CHART_X, points.map { it.first })
    }
}

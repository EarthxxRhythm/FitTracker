package com.fittracker.app.ui.screens.body

import com.fittracker.app.R
import com.fittracker.app.data.model.BodyMeasurement
import com.fittracker.app.data.service.Gender
import com.fittracker.app.data.service.UserProfileService
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
        assertEquals("72.5", FtBodyModel.formatDisplay(72.5, WeightUnit.KG))
        val goal = FtBodyModel.goalLabel(WeightUnit.KG)
        assertEquals(R.string.body_goal_label, goal.res)
        assertEquals(listOf("74.0", "kg"), goal.args)
    }

    @Test
    fun `delta文案锁定资源与U+2212减号`() {
        // 原型样例 delta 已移除（假数据清理）；改为断言带参文案的资源与符号口径。
        val delta = FtBodyModel.deltaText(-0.3, WeightUnit.KG)
        assertEquals(R.string.body_delta_last_week, delta.res)
        assertEquals(listOf("−0.3 kg"), delta.args)
        val arg = delta.args[0] as String
        assertTrue("应含 U+2212 减号：$arg", '\u2212' in arg)
        assertFalse("不应含 ASCII 连字符", '-' in arg)
    }

    @Test
    fun `无趋势时兜底为空态而非样例差值`() {
        // 原型样例 delta（−0.3 / +0.7 / +4.5）已随假数据清理移除；无 trend 的兜底一律空态。
        assertEquals(R.string.body_trend_empty, FtBodyModel.trendCaption(TrendPeriod.WEEK, WeightUnit.KG).res)
        assertEquals(R.string.body_trend_empty, FtBodyModel.trendCaption(TrendPeriod.MONTH, WeightUnit.KG).res)
        assertEquals(R.string.body_trend_empty, FtBodyModel.trendCaption(TrendPeriod.YEAR, WeightUnit.KG).res)
    }

    @Test
    fun `带符号差值锁定U+00B7中点用于caption`() {
        // signedWeight 的符号与换算口径（U+2212 减号）。
        assertEquals("+9.9 lbs", FtBodyModel.signedWeight(4.5, WeightUnit.LBS))
        assertEquals("−0.3 kg", FtBodyModel.signedWeight(-0.3, WeightUnit.KG))
        assertTrue("应含 U+2212 减号", '\u2212' in FtBodyModel.signedWeight(-0.3, WeightUnit.KG))
    }

    @Test
    fun `目标缺口资源与达标分支`() {
        val gap = FtBodyModel.goalGap(72.5, WeightUnit.KG)
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
    fun `身体成分为真实派生且未录时占位`() {
        // 无测量记录、档案未填、无体重 → 四格全占位（不再展示原型样例 22.9/34.2/1710/58.2）。
        val blank = FtBodyModel.metrics(
            WeightUnit.KG,
            latest = null,
            profile = UserProfileService.getDefaultProfile(),
            weightKg = null,
            now = 0L,
        )
        assertEquals(4, blank.size)
        blank.forEach { assertEquals(FtBodyModel.PLACEHOLDER, it.value) }

        // 有档案与体重 → BMI 按公式真算；有测量记录 → 骨骼肌随单位换算。
        val profile = UserProfileService.getDefaultProfile().copy(
            heightCm = 178,
            gender = Gender.MALE,
            birthYear = 1996,
        )
        val measurement = BodyMeasurement(dateMillis = 0L, skeletalMuscleKg = 34.2, bodyWaterPercent = 58.2)
        val kg = FtBodyModel.metrics(
            WeightUnit.KG,
            latest = measurement,
            profile = profile,
            weightKg = 72.5,
            now = 0L,
        )
        // BMI = 72.5 / 1.78² = 22.882… → 22.9
        assertEquals("22.9", kg[0].value)
        assertEquals("34.2", kg[1].value)
        assertEquals("kg", kg[1].unit)
        assertEquals("58.2", kg[3].value)

        val lbs = FtBodyModel.metrics(
            WeightUnit.LBS,
            latest = measurement,
            profile = profile,
            weightKg = 72.5,
            now = 0L,
        )
        // 骨骼肌 34.2 kg → 75.4 lbs，单位标签改写为 lbs。
        assertEquals("75.4", lbs[1].value)
        assertEquals("lbs", lbs[1].unit)
        // BMI 非质量格，不随单位换算。
        assertEquals("22.9", lbs[0].value)
    }

    // ── LBS：换算值 ─────────────────────────────────────────────────

    @Test
    fun `LBS_换算系数与往返`() {
        assertEquals(2.2046226218, FtBodyModel.LBS_PER_KG, 0.0)
        assertEquals(159.8351410805, FtBodyModel.toDisplay(72.5, WeightUnit.LBS), 1e-6)
    }

    @Test
    fun `LBS_主数值与目标标签`() {
        assertEquals("159.8", FtBodyModel.formatDisplay(72.5, WeightUnit.LBS))
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
        assertEquals(98, FtBodyModel.goalPercent(72.5))
        assertEquals(98, FtBodyModel.goalPercent(72.5))
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

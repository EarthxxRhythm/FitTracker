package com.fittracker.app.data.service

import com.fittracker.app.data.model.MEASUREMENT_UNSET
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/**
 * [BodyMetrics] 派生纯函数契约测试（Wave 1）。
 *
 * 锁定 golden 值（BMI / Mifflin-St Jeor 基础代谢）与边界（未填 / 无效输入回落 null）。
 * 纯逻辑无 Android 依赖，故用纯 JVM 单测（无需 Robolectric）。
 */
class BodyMetricsTest {

    @Test
    fun `BMI 按公式计算并保留一位小数`() {
        // 72.5kg / 1.78m² = 22.882... → 22.9
        assertEquals(22.9, BodyMetrics.computeBmi(72.5, 178.0)!!, 0.001)
        // 60kg / 1.70m² = 20.761... → 20.8
        assertEquals(20.8, BodyMetrics.computeBmi(60.0, 170.0)!!, 0.001)
    }

    @Test
    fun `BMI 无效输入回落 null`() {
        assertNull(BodyMetrics.computeBmi(0.0, 178.0))
        assertNull(BodyMetrics.computeBmi(72.5, 0.0))
        assertNull(BodyMetrics.computeBmi(-1.0, 178.0))
        assertNull(BodyMetrics.computeBmi(Double.NaN, 178.0))
    }

    @Test
    fun `BMI 分级按中国成人标准`() {
        assertEquals(BodyMetrics.BmiCategory.LOW, BodyMetrics.bmiCategory(18.4))
        assertEquals(BodyMetrics.BmiCategory.NORMAL, BodyMetrics.bmiCategory(18.5))
        assertEquals(BodyMetrics.BmiCategory.NORMAL, BodyMetrics.bmiCategory(23.9))
        assertEquals(BodyMetrics.BmiCategory.HIGH, BodyMetrics.bmiCategory(24.0))
        assertEquals(BodyMetrics.BmiCategory.HIGH, BodyMetrics.bmiCategory(27.9))
        assertEquals(BodyMetrics.BmiCategory.OBESE, BodyMetrics.bmiCategory(28.0))
    }

    @Test
    fun `基础代谢按 Mifflin-St Jeor 计算`() {
        // 男：10·72.5 + 6.25·178 − 5·30 + 5 = 725 + 1112.5 − 150 + 5 = 1692.5 → 1693
        assertEquals(1693, BodyMetrics.basalMetabolicRate(72.5, 178.0, 30, Gender.MALE)!!)
        // 女：同参数 −161 → 1692.5 − 166 = 1526.5 → 1527（实际：725+1112.5−150−161=1526.5）
        assertEquals(1527, BodyMetrics.basalMetabolicRate(72.5, 178.0, 30, Gender.FEMALE)!!)
    }

    @Test
    fun `基础代谢性别未填或参数无效回落 null`() {
        assertNull(BodyMetrics.basalMetabolicRate(72.5, 178.0, 30, Gender.UNSPECIFIED))
        assertNull(BodyMetrics.basalMetabolicRate(0.0, 178.0, 30, Gender.MALE))
        assertNull(BodyMetrics.basalMetabolicRate(72.5, 178.0, 0, Gender.MALE))
    }

    @Test
    fun `周岁由出生年与当前年求差`() {
        val calendar = java.util.Calendar.getInstance()
        calendar.clear()
        calendar.set(2026, 5, 15)
        val now = calendar.timeInMillis
        assertEquals(31, BodyMetrics.ageFromBirthYear(1995, now))
        assertEquals(0, BodyMetrics.ageFromBirthYear(0, now))
        assertEquals(0, BodyMetrics.ageFromBirthYear(2030, now))
    }

    @Test
    fun `体脂健康区间按性别给出`() {
        assertEquals(10.0, BodyMetrics.bodyFatHealthyRange(Gender.MALE)!!.low, 0.001)
        assertEquals(20.0, BodyMetrics.bodyFatHealthyRange(Gender.MALE)!!.high, 0.001)
        assertEquals(18.0, BodyMetrics.bodyFatHealthyRange(Gender.FEMALE)!!.low, 0.001)
        assertNull(BodyMetrics.bodyFatHealthyRange(Gender.UNSPECIFIED))
    }

    @Test
    fun `体脂健康判定含边界`() {
        assertEquals(true, BodyMetrics.isBodyFatHealthy(10.0, Gender.MALE))
        assertEquals(true, BodyMetrics.isBodyFatHealthy(20.0, Gender.MALE))
        assertEquals(false, BodyMetrics.isBodyFatHealthy(20.1, Gender.MALE))
        assertNull(BodyMetrics.isBodyFatHealthy(16.0, Gender.UNSPECIFIED))
        assertNull(BodyMetrics.isBodyFatHealthy(-1.0, Gender.MALE))
    }

    @Test
    fun `围度差值在任一侧未录时返回 null`() {
        val unset = MEASUREMENT_UNSET.toDouble()
        assertEquals(-2.0, BodyMetrics.measurementDelta(78.0, 80.0, unset)!!, 0.001)
        assertEquals(0.5, BodyMetrics.measurementDelta(78.5, 78.0, unset)!!, 0.001)
        assertNull(BodyMetrics.measurementDelta(unset, 80.0, unset))
        assertNull(BodyMetrics.measurementDelta(78.0, unset, unset))
    }
}

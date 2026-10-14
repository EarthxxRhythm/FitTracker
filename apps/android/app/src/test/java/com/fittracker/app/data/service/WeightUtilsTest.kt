package com.fittracker.app.data.service

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * [WeightUtils] 换算与格式化——业务数据以 kg 存储、单位只影响显示与会话输入，
 * 换算方向搞反不会报错、只会静默显示错值，故在此锁定口径。
 */
class WeightUtilsTest {

    private val tolerance = 0.001

    @Test
    fun `kg 单位下换算为恒等`() {
        assertEquals(72.5, WeightUtils.kgToDisplay(72.5, WeightUnit.KG), tolerance)
        assertEquals(80.0, WeightUtils.displayIntToKg(80, WeightUnit.KG), tolerance)
        assertEquals("kg", WeightUtils.unitLabel(WeightUnit.KG))
    }

    @Test
    fun `lbs 单位下按 2_2046226218 换算`() {
        assertEquals(159.83, WeightUtils.kgToDisplay(72.5, WeightUnit.LBS), 0.01)
        assertEquals("lbs", WeightUtils.unitLabel(WeightUnit.LBS))
    }

    @Test
    fun `显示单位输入换算回 kg 与正向换算互逆`() {
        // 100 lbs → kg → 回 lbs，应回到原值（同一常量、双向一致）。
        val kg = WeightUtils.displayIntToKg(100, WeightUnit.LBS)
        assertEquals(45.359, kg, tolerance)
        assertEquals(100.0, WeightUtils.kgToDisplay(kg, WeightUnit.LBS), tolerance)
    }

    @Test
    fun `格式化固定 1 位小数且不随区域变化`() {
        assertEquals("72.5", WeightUtils.formatWeight(72.5, WeightUnit.KG))
        assertEquals("159.8", WeightUtils.formatWeight(72.5, WeightUnit.LBS))
    }
}

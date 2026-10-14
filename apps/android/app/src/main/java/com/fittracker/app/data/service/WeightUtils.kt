package com.fittracker.app.data.service

import java.util.Locale

/**
 * 体重单位换算与格式化工具（镜像鸿蒙 `common/utils/WeightUtils.ets`）。
 *
 * 约定：业务数据一律以 **kg** 为基准存储；lbs 只出现在显示层（显示时换算、输入时换算回 kg）。
 * 体重单位来源：[UserProfileService] 的 `weightUnit`（设置页「体重单位」）。
 */
object WeightUtils {

    /** 1 千克 = 2.2046226218 磅（1 lb = 0.45359237 kg 的倒数）。 */
    const val LBS_PER_KG: Double = 2.2046226218

    /** 单位标签（如 `kg` / `lbs`）。 */
    fun unitLabel(unit: WeightUnit): String = unit.id

    /** kg 基准值 → 当前单位数值。 */
    fun kgToDisplay(kg: Double, unit: WeightUnit): Double =
        if (unit == WeightUnit.LBS) kg * LBS_PER_KG else kg

    /** kg 基准值 → 当前单位下 1 位小数的展示文本。 */
    fun formatWeight(kg: Double, unit: WeightUnit): String =
        String.format(Locale.US, "%.1f", kgToDisplay(kg, unit))

    /** 当前单位整数输入值 → kg 基准值。 */
    fun displayIntToKg(value: Int, unit: WeightUnit): Double =
        if (unit == WeightUnit.LBS) value.toDouble() / LBS_PER_KG else value.toDouble()
}

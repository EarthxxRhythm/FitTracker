package com.fittracker.app.data.service

import kotlin.math.roundToInt

/**
 * 身体指标派生纯函数（BMI / 基础代谢 / 体脂健康区间 / 围度差值）——镜像鸿蒙
 * `common/utils/BodyMetrics.ets`。
 *
 * 全部为无副作用的纯函数，便于 JVM 单测（不触持久化、不依赖 Context）。
 * 口径：
 *  - BMI = 体重(kg) / 身高(m)²，分级用中国成人标准（<18.5 偏低 / 18.5–24 正常 / 24–28 偏高 / ≥28 肥胖）。
 *  - 基础代谢用 Mifflin-St Jeor 公式（不依赖体脂率，故体脂率可保持可选录入）。
 *  - 体脂健康区间按性别给出参考范围（男 10–20%、女 18–28%）——**参考区间**，
 *    用于给体脂秤读数定位，非医学诊断。
 */
object BodyMetrics {

    /** BMI 分级（语义枚举；中文标签由 [bmiCategoryLabel] 提供）。 */
    enum class BmiCategory { LOW, NORMAL, HIGH, OBESE }

    /** 体脂率健康区间（百分比）。 */
    data class BodyFatRange(val low: Double, val high: Double)

    /** BMI 分级阈值（中国成人标准）。 */
    private const val BMI_LOW_MAX = 18.5
    private const val BMI_NORMAL_MAX = 24.0
    private const val BMI_HIGH_MAX = 28.0

    /** BMI：体重(kg) 与身高(cm) 任一无效（非有限 / ≤0）时返回 null。 */
    fun computeBmi(weightKg: Double, heightCm: Double): Double? {
        if (!weightKg.isFinite() || !heightCm.isFinite()) return null
        if (weightKg <= 0.0 || heightCm <= 0.0) return null
        val heightM = heightCm / 100.0
        val bmi = weightKg / (heightM * heightM)
        return Math.round(bmi * 10.0) / 10.0
    }

    /** BMI 分级。 */
    fun bmiCategory(bmi: Double): BmiCategory = when {
        bmi < BMI_LOW_MAX -> BmiCategory.LOW
        bmi < BMI_NORMAL_MAX -> BmiCategory.NORMAL
        bmi < BMI_HIGH_MAX -> BmiCategory.HIGH
        else -> BmiCategory.OBESE
    }

    /** BMI 分级的中文标签（用户可见文本）。 */
    fun bmiCategoryLabel(category: BmiCategory): String = when (category) {
        BmiCategory.LOW -> "偏低"
        BmiCategory.NORMAL -> "正常范围"
        BmiCategory.HIGH -> "偏高"
        BmiCategory.OBESE -> "肥胖"
    }

    /**
     * 基础代谢（kcal/日，Mifflin-St Jeor）：
     *  男 BMR = 10·体重 + 6.25·身高 − 5·年龄 + 5
     *  女 BMR = 10·体重 + 6.25·身高 − 5·年龄 − 161
     * 性别未填（[Gender.UNSPECIFIED]）或任一参数无效时返回 null。
     */
    fun basalMetabolicRate(
        weightKg: Double,
        heightCm: Double,
        age: Int,
        gender: Gender,
    ): Int? {
        if (gender != Gender.MALE && gender != Gender.FEMALE) return null
        if (!weightKg.isFinite() || !heightCm.isFinite()) return null
        if (weightKg <= 0.0 || heightCm <= 0.0 || age <= 0) return null
        val base = 10.0 * weightKg + 6.25 * heightCm - 5.0 * age
        val bmr = if (gender == Gender.MALE) base + 5.0 else base - 161.0
        return bmr.roundToInt()
    }

    /** 由出生年与当前时间求周岁；出生年未填（0）或晚于当前年时返回 0。 */
    fun ageFromBirthYear(birthYear: Int, now: Long): Int {
        if (birthYear <= 0) return 0
        val currentYear = java.util.Calendar.getInstance().apply { timeInMillis = now }.get(java.util.Calendar.YEAR)
        val age = currentYear - birthYear
        return if (age > 0) age else 0
    }

    /** 体脂率健康参考区间；性别未填时返回 null。 */
    fun bodyFatHealthyRange(gender: Gender): BodyFatRange? = when (gender) {
        Gender.MALE -> BodyFatRange(low = 10.0, high = 20.0)
        Gender.FEMALE -> BodyFatRange(low = 18.0, high = 28.0)
        else -> null
    }

    /** 体脂率是否落在健康区间；区间未知或读数未录（-1）时返回 null。 */
    fun isBodyFatHealthy(bodyFatPercent: Double, gender: Gender): Boolean? {
        val range = bodyFatHealthyRange(gender) ?: return null
        if (!bodyFatPercent.isFinite() || bodyFatPercent < 0.0) return null
        return bodyFatPercent >= range.low && bodyFatPercent <= range.high
    }

    /**
     * 单项「较上次」差值（保留一位小数）；任一侧未录（[MEASUREMENT_UNSET]）时返回 null。
     * 与 [BodyMeasurementService.delta] 同口径。
     */
    fun measurementDelta(latest: Double, previous: Double, unset: Double): Double? {
        if (latest == unset || previous == unset) return null
        return Math.round((latest - previous) * 10.0) / 10.0
    }

    /** 未录入标记（与 `BodyMeasurement` 各字段默认值同源）。 */
    private val MEASUREMENT_UNSET: Double =
        com.fittracker.app.data.model.MEASUREMENT_UNSET.toDouble()
}

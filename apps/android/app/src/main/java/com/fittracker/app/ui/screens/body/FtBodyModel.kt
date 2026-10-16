package com.fittracker.app.ui.screens.body

import androidx.annotation.StringRes
import com.fittracker.app.R
import com.fittracker.app.data.model.BodyMeasurement
import com.fittracker.app.data.model.MEASUREMENT_UNSET
import com.fittracker.app.data.service.BodyMeasurementService
import com.fittracker.app.data.service.BodyMetrics
import com.fittracker.app.data.service.BodyTrend
import com.fittracker.app.data.service.Gender
import com.fittracker.app.data.service.UserProfile
import com.fittracker.app.data.service.WeightUnit
import java.util.Locale
import kotlin.math.abs
import kotlin.math.roundToInt

/**
 * 一条带参文案的「资源 ID + 位置参数」载体。
 *
 * 模型层无 `Context`（保持可单测），故不解出字符串，只持资源 ID 与参数；
 * 由 UI 层 `stringResource(res, *args.toTypedArray())` 解析（Wave 6/7 i18n 约定）。
 */
data class FtBodyLabel(@StringRes val res: Int, val args: List<Any> = emptyList())

/** 身体成分网格的一格（原型 `.metric-tile`，L350-368）。 */
data class BodyMetric(
    /** `.mt-label`（L171）文案资源。 */
    @StringRes val labelRes: Int,
    val value: String,
    /** `.mt-value .unit`；为 null 时只有数值（如 BMI）。 */
    val unit: String?,
    /** `.mt-note`（L174）**静态**文案资源；空态占位时可为 null（不渲染注解）。 */
    @StringRes val noteRes: Int? = null,
    /** `.mt-note` 的**动态**文案（如 BMI 分级）；非空时优先于 [noteRes]。 */
    val noteText: String? = null,
    /** `.mt-note.mut`：true 走 `--white-40`，false 走 `--accent`。 */
    val muted: Boolean = false,
)

/** 围度记录的一行（原型 `.measure-row`，L398-417）。 */
data class BodyMeasure(
    /** `.ms-label`（L190）文案资源。 */
    @StringRes val labelRes: Int,
    val value: String,
    val delta: String,
    /** `.ms-delta.down`：true 走 `--white-54`，false 走 `--accent`。 */
    val down: Boolean,
)

/**
 * 体重趋势的时间尺度（原型 `data-period`，L380-383）。
 *
 * [labelRes] 为分段按钮文案资源（`周` / `月` / `年`）。
 */
enum class TrendPeriod(val token: String, @StringRes val labelRes: Int) {
    WEEK("week", R.string.body_period_week),
    MONTH("month", R.string.body_period_month),
    YEAR("year", R.string.body_period_year),
}

/**
 * 一套尺度的趋势数据。
 *
 * [labels] 为**真实路径**轴标签（由数据层 `BodyRecordService` / `WeekWindow` 产出，
 * 见 [series]）——非本域文案，故保持已解析字符串；本域不持有样例标签字面量。
 */
data class TrendSeries(
    val values: List<Float>,
    val labels: List<String>,
)

/**
 * 身体数据屏的纯逻辑层——无 Compose 依赖，可单测。
 *
 * 规格源：原型 `design/06_prototype_redraw/src/fittracker-body-data.html`
 * （文案 L300-443 · 趋势序列 L527-531 · 绘图常量 L521-525 · 记录面板脚本 L511-560）。
 *
 * **文案外置**（Wave 8 i18n）：所有用户可见文案改为字符串资源 ID（`values/strings_body.xml`
 * 的中文值为逐字真源），本对象只持有 `@StringRes Int` / [FtBodyLabel] / 纯逻辑函数，
 * 由 UI 层 `stringResource` 解析——本文件不出现文案字面量。
 * 图表轴标签由数据层产出（`BodyRecordService` / `WeekWindow`），故 [TrendSeries.labels] 保持字符串。
 */
object FtBodyModel {

    // ── 顶栏与卡片文案资源（L301-422） ────────────────────────────

    /** `.bd-back` 的 `aria-label`（L301）。 */
    @StringRes
    val BACK_A11Y_RES = R.string.body_a11y_back

    /** `.bd-title`（L304）。 */
    @StringRes
    val TITLE_RES = R.string.body_title

    /** `.weight-label`（L314）。 */
    @StringRes
    val WEIGHT_LABEL_RES = R.string.body_weight_label

    /** `.weight-date`（L315）的「更新于 …」前缀模板：`%1$s` 时间。 */
    @StringRes
    val UPDATED_RES = R.string.body_updated

    /** 保存后注入的 delta 文案（L552，原 [DELTA_SAVED]）。 */
    @StringRes
    val DELTA_SAVED_RES = R.string.body_delta_saved

    /** `.card-title`（L334）。 */
    @StringRes
    val COMPOSITION_TITLE_RES = R.string.body_composition_title

    /** `.card-meta`（L335）。 */
    @StringRes
    val COMPOSITION_META_RES = R.string.body_composition_meta

    /** `.fat-label`（L339）。 */
    @StringRes
    val FAT_LABEL_RES = R.string.body_fat_label

    /** `.fat-scale` 三档（L346-348）。 */
    val FAT_SCALE_RES: List<Int> = listOf(
        R.string.body_fat_scale_low,
        R.string.body_fat_scale_normal,
        R.string.body_fat_scale_high,
    )

    /** `.fat-zone` 的内联 `left: 25%; width: 50%`（L343）——**版式几何**，非数据。 */
    const val FAT_ZONE_LEFT = 0.25f
    const val FAT_ZONE_WIDTH = 0.50f

    /**
     * `.fat-marker` 的内联 `left: 56%`（L344）——**已由真实体脂率派生**，不再是常量。
     *
     * 映射口径：健康区间 `[low, high]` 线性铺满 `.fat-zone`（轨道 25%–75%），
     * 即 `left = FAT_ZONE_LEFT + (bf − low) / (high − low) × FAT_ZONE_WIDTH`。
     * 校验：`bf = 16.2`（男，区间 10–20）→ 0.25 + 0.62 × 0.5 = **0.56**，与原型内联值逐位一致。
     *
     * @return 标记点在轨道上的横向比例（0–1）；体脂率未录 / 性别未填（无健康区间）时返回 null（不绘制）。
     */
    fun fatMarkerLeft(bodyFatPercent: Double?, gender: Gender): Float? {
        if (bodyFatPercent == null || !bodyFatPercent.isFinite() || bodyFatPercent < 0.0) return null
        val range = BodyMetrics.bodyFatHealthyRange(gender) ?: return null
        val span = range.high - range.low
        if (span <= 0.0) return null
        val fraction = FAT_ZONE_LEFT + ((bodyFatPercent - range.low) / span).toFloat() * FAT_ZONE_WIDTH
        return fraction.coerceIn(0f, 1f)
    }

    /** 未录入占位（原型无此符号，仓内既有约定：值渲染 `--`）。 */
    const val PLACEHOLDER = "--"

    /** 数值格文案：未录入（null）→ [PLACEHOLDER]，否则 `%.1f`。 */
    fun valueText(value: Double?): String =
        if (value == null || !value.isFinite()) PLACEHOLDER else formatWeight(value)

    /** 由出生年推得的周岁：`ageFromBirthYear` 的便捷口（`0` 表未填）。 */
    fun ageOf(birthYear: Int, now: Long): Int = BodyMetrics.ageFromBirthYear(birthYear, now)

    /** `.card-title`（L377）。 */
    @StringRes
    val TREND_TITLE_RES = R.string.body_trend_title

    /** `.seg` 的 `aria-label`（L380）。 */
    @StringRes
    val A11Y_TREND_RANGE_RES = R.string.body_a11y_trend_range

    /** 无记录空态 caption（原为原型样例序列回落的 caption）。 */
    @StringRes
    val TREND_EMPTY_RES = R.string.body_trend_empty

    /** `.card-title`（L394）。 */
    @StringRes
    val MEASURE_TITLE_RES = R.string.body_measure_title

    /** `.card-meta`（L395）。 */
    @StringRes
    val MEASURE_META_RES = R.string.body_measure_meta

    /** `.bd-cta`（L421）。 */
    @StringRes
    val CTA_LABEL_RES = R.string.body_cta

    /** `.sheet-title`（L432）。 */
    @StringRes
    val SHEET_TITLE_RES = R.string.body_sheet_title

    /** `.sheet-sub`（L433）。 */
    @StringRes
    val SHEET_SUB_RES = R.string.body_sheet_sub

    /** `.sheet-cancel`（L440）。 */
    @StringRes
    val SHEET_CANCEL_RES = R.string.body_sheet_cancel

    /** `.sheet-save`（L441）。 */
    @StringRes
    val SHEET_SAVE_RES = R.string.body_sheet_save

    /** `<input ... aria-label="今日体重">`（L435）。 */
    @StringRes
    val SHEET_INPUT_A11Y_RES = R.string.body_sheet_input_a11y

    /** 校验失败提示（L548）。 */
    @StringRes
    val INVALID_HINT_RES = R.string.body_invalid_hint

    // ── 体重趋势几何（原型脚本 L521-525、L474-497） ──────────────

    /** `#trend-svg` 的 `viewBox="0 0 326 140"`（L387）。 */
    const val CHART_W = 326f
    const val CHART_H = 140f

    /** 脚本 `X = [20, 68, 115, 163, 210, 258, 305]`（L521）。 */
    val CHART_X = listOf(20f, 68f, 115f, 163f, 210f, 258f, 305f)

    /** `TOP = 18, BOTTOM = 100, BASE = 112, LABEL_Y = 126`（L522）。 */
    const val CHART_TOP = 18f
    const val CHART_BOTTOM = 100f
    const val CHART_BASE = 112f
    const val CHART_LABEL_Y = 126f

    /** 两条网格线 y（L486-487：y=20 走 `rgba(255,255,255,.06)`，y=100 走 `rgba(255,255,255,.10)`）。 */
    const val GRID_FAINT_Y = 20f
    const val GRID_STRONG_Y = 100f

    /**
     * 折线各点的 `(x, y)`（原型 `drawChart`，L474-478）：
     * `lo = min(vals)`、`hi = max(vals)`、`span = (hi - lo) || 1`、
     * `y = BOTTOM - ((v - lo) / span) * (BOTTOM - TOP)`，`x = X[i]`。
     */
    fun chartPoints(series: TrendSeries): List<Pair<Float, Float>> {
        val lo = series.values.min()
        val hi = series.values.max()
        val span = (hi - lo).takeIf { it != 0f } ?: 1f
        return series.values.mapIndexed { i, v ->
            CHART_X[i] to (CHART_BOTTOM - ((v - lo) / span) * (CHART_BOTTOM - CHART_TOP))
        }
    }

    // ── 体重 / 目标（原型脚本 L518-542） ─────────────────────────

    /** `var GOAL = 74.0`（L518）。 */
    const val GOAL_KG = 74.0

    /**
     * `setGoalUI` 的目标进度百分比：`min(100, round(current / GOAL * 100))`（L527）。
     */
    fun goalPercent(current: Double): Int =
        ((current / GOAL_KG) * 100.0).roundToInt().coerceAtMost(100)
    /**
     * `setGoalUI` 的目标标签（L526）：`增肌目标 <目标值> <单位>`。
     * `%1$s` 目标值 · `%2$s` 单位标签（按 [unit] 换算）。
     */
    fun goalLabel(unit: WeightUnit): FtBodyLabel =
        FtBodyLabel(
            R.string.body_goal_label,
            listOf(formatWeight(toDisplay(GOAL_KG, unit)), unitLabel(unit)),
        )

    /**
     * `setGoalUI` 的剩余量文案（L526）：
     * `gap = max(0, GOAL - current)`；`gap <= 0.05` 时「已达目标」，否则「还差 <差值> <单位>」。
     * 差值按 [unit]（设置项「体重单位」）换算后呈现。
     */
    fun goalGap(current: Double, unit: WeightUnit): FtBodyLabel {
        val gap = (GOAL_KG - current).coerceAtLeast(0.0)
        return if (gap <= 0.05) {
            FtBodyLabel(R.string.body_goal_reached)
        } else {
            FtBodyLabel(
                R.string.body_goal_gap,
                listOf(formatWeight(toDisplay(gap, unit)), unitLabel(unit)),
            )
        }
    }

    // ── 记录面板（原型脚本 L511-560） ────────────────────────────

    /** `min="1" max="500"`（L435）；脚本判据为 `v <= 0 || v > 500`（L547）。 */
    const val WEIGHT_MAX = 500.0

    /** `parseFloat(input.value)`（L545）：非法输入得到 null。 */
    fun parseWeight(text: String): Double? = text.trim().toDoubleOrNull()

    /** `!isFinite(v) || v <= 0 || v > 500`（L547）。 */
    fun isWeightValid(value: Double?): Boolean =
        value != null && value.isFinite() && value > 0.0 && value <= WEIGHT_MAX

    /** `v.toFixed(1)`（L551）。 */
    fun formatWeight(value: Double): String = String.format(Locale.US, "%.1f", value)

    // ── 体重单位（设置项「体重单位」的消费口） ───────────────────────
    //
    // 屏内所有质量基准值都以**千克**存（原型样例、[GOAL_KG]、趋势序列的 delta），
    // 展示时按当前单位换算。设置项名即「体重单位」，故围度（cm）不参与换算；
    // 质量类数值（含身体成分里的 `骨骼肌`）随单位换算。

    /** 1 千克 = 2.2046226218 磅（1 lb = 0.45359237 kg 的倒数）。 */
    const val LBS_PER_KG: Double = 2.2046226218

    /** 质量单位标签（`kg` / `lbs`）——数值/单位非文案，取自设置项 id。 */
    private const val MASS_UNIT_KG = "kg"

    /** 无单位数值格的单位后缀（`kcal` / `%` / `cm`）——数值/单位非文案。 */
    private const val UNIT_KCAL_LABEL = "kcal"
    private const val UNIT_PERCENT_LABEL = "%"
    private const val UNIT_CM_LABEL = "cm"

    /** 单位标签——`.weight-value span`（L317）/ `.sheet-unit`（L436）文案。 */
    fun unitLabel(unit: WeightUnit): String = unit.id

    /** 千克 → 展示单位（[WeightUnit.KG] 取原值，[WeightUnit.LBS] 换算）。 */
    fun toDisplay(kg: Double, unit: WeightUnit): Double =
        if (unit == WeightUnit.LBS) kg * LBS_PER_KG else kg

    /** 展示单位 → 千克（记录面板保存时回写基准值）。 */
    fun toKilograms(value: Double, unit: WeightUnit): Double =
        if (unit == WeightUnit.LBS) value / LBS_PER_KG else value

    /** 主数值格式：按展示单位换算后 `%.1f`（`#hero-weight` / `.weight-value`）。 */
    fun formatDisplay(kg: Double, unit: WeightUnit): String = formatWeight(toDisplay(kg, unit))

    /**
     * `#hero-delta` 的通用式：`较上周 ` + [signedWeight]。样例值 `−0.3 kg` 已去——
     * 无记录时调用方不渲染 delta（见 `BodyScreen`），故本函数只承载真实差值。
     */
    fun deltaText(deltaKg: Double, unit: WeightUnit): FtBodyLabel =
        FtBodyLabel(R.string.body_delta_last_week, listOf(signedWeight(deltaKg, unit)))


    /**
     * 带符号质量差值文案：正号 `+`、负号用 U+2212（原型 `−`，L320），
     * 数值按 [unit] 换算后 `%.1f`，尾部接单位标签。例：`−0.3 kg` / `+0.7 lbs`。
     */
    fun signedWeight(deltaKg: Double, unit: WeightUnit): String {
        val sign = if (deltaKg < 0.0) "\u2212" else "+"
        return sign + formatWeight(toDisplay(abs(deltaKg), unit)) + " " + unitLabel(unit)
    }

    /**
     * `.trend-cap` 文案的空态式（`SERIES[key].caption` 的样例值已去）——无记录时由
     * `BodyScreen` 直接渲染 [TREND_EMPTY_RES]，本函数只在**有记录但 trend 为 null**
     * 的兜底路径使用，故返回空态资源而非假差值。
     */
    fun trendCaption(period: TrendPeriod, unit: WeightUnit): FtBodyLabel =
        FtBodyLabel(TREND_EMPTY_RES)


    // ── 真实记录的趋势适配（Wave 3 · W3-1） ────────────────────────
    //
    // 服务层 [BodyRecordService] 产出的 [BodyTrend] 是 data 层千克基准类型；此处适配为
    // 展示层 [TrendSeries]（点集保持千克——折线按 min/max 归一化，与单位无关）并按单位成文 caption。

    /** 由 [BodyTrend] 构造展示序列；[TrendSeries.labels] 直接取数据层轴标签。 */
    fun series(trend: BodyTrend, unit: WeightUnit): TrendSeries = TrendSeries(
        values = trend.values,
        labels = trend.labels,
    )

    /** [BodyTrend] 的 caption：`<区间> · <带符号差值> <单位>`。 */
    fun trendCaption(trend: BodyTrend, unit: WeightUnit): FtBodyLabel =
        FtBodyLabel(
            R.string.body_trend_caption_range,
            listOf(trend.rangeText, signedWeight(trend.deltaKg, unit)),
        )

    /**
     * `.metric-grid` 四格（L350-368）——**由服务注入的真值**（不再有样例常量）。
     *
     * 口径：
     * - BMI：`BodyMetrics.computeBmi(weightKg, heightCm)` + `bmiCategoryLabel` 作 note；体重/身高缺一律 `--`。
     * - 基础代谢：`BodyMetrics.basalMetabolicRate(weight, height, age, gender)`；性别未填/年龄未知一律 `--`。
     * - 骨骼肌 / 身体水分：取 [latest]（体脂秤读数，仅用户录入，不做公式推算）；未录一律 `--`。
     *
     * 未录格一律 `value = "--"`、`noteRes = null`、`muted = true`（既有空态约定）。
     *
     * @param unit 体重单位（`骨骼肌` 为质量，随单位换算）
     * @param latest 最新一条体成分记录；null = 无任何记录
     * @param profile 身体档案（身高/性别/出生年）
     * @param weightKg 当前体重（千克）；null = 无体重记录
     * @param now 当前时间（用于由出生年推周岁，保证纯函数可单测）
     */
    fun metrics(
        unit: WeightUnit,
        latest: BodyMeasurement?,
        profile: UserProfile,
        weightKg: Double?,
        now: Long,
    ): List<BodyMetric> {
        // BMI
        val bmi = if (weightKg != null) {
            BodyMetrics.computeBmi(weightKg, profile.heightCm.toDouble())
        } else {
            null
        }
        val bmiTile = if (bmi != null) {
            BodyMetric(
                labelRes = R.string.body_metric_bmi,
                value = formatWeight(bmi),
                unit = null,
                noteRes = null,
                noteText = BodyMetrics.bmiCategoryLabel(BodyMetrics.bmiCategory(bmi)),
                muted = false,
            )
        } else {
            blankMetric(R.string.body_metric_bmi)
        }

        // 骨骼肌（质量：kg 基准，随单位换算）
        val muscle = latest?.skeletalMuscleKg?.let { unsetOrValue(it) }
        val muscleTile = if (muscle != null) {
            BodyMetric(
                labelRes = R.string.body_metric_muscle,
                value = formatDisplay(muscle, unit),
                unit = unitLabel(unit),
                noteRes = R.string.body_metric_muscle_note,
                muted = true,
            )
        } else {
            blankMetric(R.string.body_metric_muscle)
        }

        // 基础代谢（kcal）
        val bmr = if (weightKg != null) {
            BodyMetrics.basalMetabolicRate(
                weightKg = weightKg,
                heightCm = profile.heightCm.toDouble(),
                age = BodyMetrics.ageFromBirthYear(profile.birthYear, now),
                gender = profile.gender,
            )
        } else {
            null
        }
        val bmrTile = if (bmr != null) {
            BodyMetric(
                labelRes = R.string.body_metric_bmr,
                value = bmr.toString(),
                unit = UNIT_KCAL_LABEL,
                noteRes = R.string.body_metric_bmr_note,
                muted = true,
            )
        } else {
            blankMetric(R.string.body_metric_bmr)
        }

        // 身体水分（%）
        val water = latest?.bodyWaterPercent?.let { unsetOrValue(it) }
        val waterTile = if (water != null) {
            BodyMetric(
                labelRes = R.string.body_metric_water,
                value = formatWeight(water),
                unit = UNIT_PERCENT_LABEL,
                noteRes = R.string.body_metric_water_note,
                muted = false,
            )
        } else {
            blankMetric(R.string.body_metric_water)
        }

        return listOf(bmiTile, muscleTile, bmrTile, waterTile)
    }

    /** 围度卡五行（L398-417）——**由真实 latest/previous 填充**，未录一律 `--`。 */
    fun measures(latest: BodyMeasurement?, previous: BodyMeasurement?): List<BodyMeasure> = listOf(
        measureRow(R.string.body_measure_chest, latest?.chestCm, previous?.chestCm),
        measureRow(R.string.body_measure_waist, latest?.waistCm, previous?.waistCm),
        measureRow(R.string.body_measure_hip, latest?.hipCm, previous?.hipCm),
        measureRow(R.string.body_measure_arm, latest?.armCm, previous?.armCm),
        measureRow(R.string.body_measure_thigh, latest?.thighCm, previous?.thighCm),
    )

    /** 单行围度：值未录 → `--`；差值任一侧未录 → `--`（不猜涨跌）。 */
    private fun measureRow(labelRes: Int, latest: Double?, previous: Double?): BodyMeasure {
        val value = latest?.let { unsetOrValue(it) }
        val delta = if (latest != null && previous != null) {
            BodyMetrics.measurementDelta(latest, previous, MEASUREMENT_UNSET.toDouble())
        } else {
            null
        }
        return BodyMeasure(
            labelRes = labelRes,
            value = if (value == null) PLACEHOLDER else formatWeight(value) + " " + UNIT_CM_LABEL,
            delta = if (delta == null) PLACEHOLDER else signedCm(delta),
            down = delta != null && delta < 0.0,
        )
    }

    /** 围度带符号差值：正号 `+`、负号 U+2212（与 [signedWeight] 同符号口径，无单位后缀）。 */
    fun signedCm(deltaCm: Double): String {
        val sign = if (deltaCm < 0.0) "\u2212" else "+"
        return sign + formatWeight(abs(deltaCm))
    }

    /** 空态格（未录）：值 `--`、无注解、置灰。 */
    private fun blankMetric(@StringRes labelRes: Int): BodyMetric =
        BodyMetric(labelRes = labelRes, value = PLACEHOLDER, unit = null, noteRes = null, muted = true)

    /** 围度字段的未录判定（`-1` → null）。 */
    private fun unsetOrValue(raw: Double): Double? =
        if (raw == MEASUREMENT_UNSET.toDouble() || !raw.isFinite()) null else raw


    /**
     * `.foot-note`（L422）——承诺随当前单位改写（kg 时说「可切换为磅」，
     * lbs 时说「可切换为千克」）。
     */
    @StringRes
    fun footNote(unit: WeightUnit): Int =
        if (unit == WeightUnit.LBS) R.string.body_foot_note_lbs else R.string.body_foot_note_kg
}

package com.fittracker.app.ui.screens.review

import androidx.annotation.StringRes
import com.fittracker.app.R
import com.fittracker.app.data.model.WorkoutSession
import com.fittracker.app.data.service.WeightUnit
import com.fittracker.app.data.service.WeightUtils
import com.fittracker.app.data.service.WeekStart
import com.fittracker.app.data.service.WeekWindow
import com.fittracker.app.data.service.currentLanguageTag
import java.util.Calendar
import java.util.Locale
import kotlin.math.ceil

/**
 * 概览/统计卡的单个数值（原型 `data.stats[i]`）。
 *
 * [labelRes] / [unitRes] 为字符串资源 ID（`values/strings_review.xml`）；[value] 是运行期数值文本
 * （空库时取原型样例）。文案不落模型层，由 UI 层 `stringResource` / `getString` 解析。
 */
/**
 * 一张统计卡的文案（原型 `.stat-card`）。
 *
 * [unitRes] 为资源 id 形式的单位（`次`/`分钟`/`kg`）；[unitText] 供**按设置动态换算**的单位
 * （如体重卡的 `kg`/`lbs`）——非空时优先于 [unitRes]。
 */
data class ReviewStat(
    @StringRes val labelRes: Int,
    val value: String,
    @StringRes val unitRes: Int,
    val unitText: String? = null,
)

/** 一套时间尺度的全部文案（原型 `WEEK` / `MONTH`）；[badge] 是语言无关的样例数据（`↑ +18%`）。 */
data class ReviewScaleData(
    @StringRes val weekRes: Int,
    val badge: String,
    @StringRes val headlineRes: Int,
    @StringRes val descRes: Int,
    @StringRes val subRes: Int,
    val stats: List<ReviewStat>,
)

/** 周柱状图的一根柱（原型 `.bar-col`，高度写在 inline style 里）。 */
data class WeekBar(val label: String, val height: Float, val on: Boolean)

/** 月历的一格；[day] 为 0 表示占位空格（原型 `.mcal-space`）。 */
data class MonthCell(val day: Int, val level: Int, val today: Boolean = false)

/**
 * 某一天的训练摘要（供月历热力格点击弹层）。
 *
 * [hasSession] 为 false 表示当天无训练记录（其余字段均为 0）。
 */
data class DaySummary(
    val day: Int,
    val durationMinutes: Int,
    val exerciseCount: Int,
    val setCount: Int,
    val volumeKg: Double,
    val hasSession: Boolean,
)

/**
 * 估算 1RM 的一行。
 *
 * 真实路径的 [name] / [src] 来自数据层（`PersonalRecordService` 的动作名与最佳日期文本）、
 * [unit] 为语言无关单位，均**非 UI 文案**，故保留为已解析字符串。
 */
data class OneRmRow(val name: String, val src: String, val value: String, val unit: String)

/** 空库时的 1RM 降级样例行（原型静态四行）——文案走资源，由 UI 层解析成 [OneRmRow]。 */
data class OneRmSample(@StringRes val nameRes: Int, @StringRes val srcRes: Int, val value: String)

/** 努力程度的两种记法（原型 `data-effort`）。 */
enum class EffortMetric(val token: String) {
    RIR("rir"),
    RPE("rpe"),
    ;

    /** 原型 `effortCurrent.toUpperCase()`——原文是 `RIR` / `RPE`。 */
    val display: String get() = token.uppercase(Locale.US)
}

/**
 * 努力程度视图的渲染结果（原型 `renderEffort()`）。
 *
 * [average] 是运行期数值文本；单位文案带记法名（`RIR` / `RPE`），由 UI 层用
 * `review_effort_unit` 模板 + [metric] 插值（见 [FtReviewModel.EFFORT_UNIT_RES]）。
 */
data class EffortView(
    val average: String,
    val metric: EffortMetric,
    val barPercents: List<Int>,
    val barLabels: List<String>,
)

/**
 * 点选肌肉后的详情行取值（原型 `selectMuscle`）。
 *
 * [textRes] 是文案资源 ID；[arg] 为可选插值参数（仅「N 组」用，见 `review_muscle_detail_sets`）。
 */
data class MuscleDetail(@StringRes val textRes: Int, val arg: Int? = null)

/** 月历标题参数（模板 `review_month_label`：`%1$d 年 %2$d 月`）。 */
data class MonthLabel(val year: Int, val month: Int)

/** 月历 meta 参数（模板 `review_month_meta`：`训练 %1$d 天 · %2$d 分钟`）。 */
data class MonthMeta(val days: Int, val minutes: Int)

/** 肌肉地图的三种模式（原型 `data-mode`）。 */
enum class MuscleMode(val token: String) { BALANCE("balance"), FATIGUE("fatigue"), STRENGTH("strength") }

/**
 * 训练回顾屏的纯逻辑层——无 Compose 依赖，可单测。
 *
 * 规格源：原型 `design/06_prototype_redraw/src/fittracker-review.html`
 * （WEEK/MONTH L1541-1563 · 月历 L1203-1260 · 体重曲线 L1311-1330 · 1RM L1352-1375 ·
 * 肌肉地图常量 L1612-1627 · selectMuscle L1680-1704 · saveGoal L1744-1759 ·
 * renderEffort L1779-1805）。
 *
 * **文案外置**（Wave 7 i18n）：用户可见文案改为字符串资源 ID（`values/strings_review.xml`
 * 的中文值为逐字真源），本对象只持有 `@StringRes Int` 与纯逻辑函数，由 UI 层
 * `stringResource` / `context.getString` 解析——本文件不出现文案字面量（样例数据同样资源化）。
 */
object FtReviewModel {

    // ── 时间尺度（L1541-1563） ────────────────────────────────────

    val WEEK = ReviewScaleData(
        weekRes = R.string.review_head_week_sample,
        badge = "↑ +18%",
        headlineRes = R.string.review_week_headline,
        descRes = R.string.review_week_desc,
        subRes = R.string.review_week_sub,
        stats = listOf(
            ReviewStat(R.string.review_stat_workouts, "4", R.string.review_unit_times),
            ReviewStat(R.string.review_stat_duration, "186", R.string.review_unit_minutes),
            ReviewStat(R.string.review_stat_weight_change, "-0.8", R.string.review_unit_kg),
        ),
    )

    val MONTH = ReviewScaleData(
        weekRes = R.string.review_head_month_sample,
        badge = "↑ +12%",
        headlineRes = R.string.review_month_headline,
        descRes = R.string.review_month_desc,
        subRes = R.string.review_month_sub,
        stats = listOf(
            ReviewStat(R.string.review_stat_workouts, "17", R.string.review_unit_times),
            ReviewStat(R.string.review_stat_duration, "720", R.string.review_unit_minutes),
            ReviewStat(R.string.review_stat_weight_change, "-1.6", R.string.review_unit_kg),
        ),
    )

    /**
     * 周柱状：高度是原型写死的 inline style（L1195-1201），不是算出来的。
     *
     * 日标签取自 [WeekWindow.dayLabels]（与真实路径 `weeklyBars` 同源）——日标签的 i18n 归
     * `WeekWindow` 域（Wave 7/8 统一迁资源），本域不另立一份（同 Wave 1 移除 `MONTH_HEAD` 的理由）。
     */
    val WEEK_BARS: List<WeekBar> = run {
        val labels = WeekWindow.dayLabels(WeekStart.MONDAY, currentLanguageTag())
        val heights = listOf(52.6f, 83.4f, 67.1f, 38.1f, 105.2f, 74.4f, 41.7f)
        val lit = listOf(false, true, true, false, true, true, false)
        List(7) { index -> WeekBar(labels[index], heights[index], lit[index]) }
    }

    // ── 月历（L1203-1260） ────────────────────────────────────────

    // 月历表头序由「周开始日」决定（WeekWindow.dayLabels(weekStart)，由 ReviewScreen 持有并传入）——
    // 原 MONTH_HEAD 常量已移除（Wave 4 遗留小项）；「一…日 / 日…六」两态断言由 WeekWindowTest 继承。
    /** 月历标题样例（真实路径：`monthLabel` 参数 + `review_month_label` 模板）。 */
    @StringRes
    val MONTH_LABEL_RES = R.string.review_month_label_sample

    /** 月历 meta 样例（真实路径：`monthMeta` 参数 + `review_month_meta` 模板）。 */
    @StringRes
    val MONTH_META_RES = R.string.review_month_meta_sample

    @StringRes
    val MONTH_TIP_RES = R.string.review_month_tip

    /** 图例五档文案（原型 `.month-legend`，L1256-1260）。 */
    val MONTH_LEGEND_RES: List<Int> = listOf(
        R.string.review_month_legend_none,
        R.string.review_month_legend_light,
        R.string.review_month_legend_medium,
        R.string.review_month_legend_high,
        R.string.review_month_legend_max,
    )

    /** 月历 6 月：30 天 + 5 个尾部占位（原型 `.mcal-grid` 的 35 个 span）。 */
    val MONTH_CELLS: List<MonthCell> = run {
        // 原型 class 序列（L1210-1249）：每 7 格一行，0 表示无 lN
        val levels = listOf(
            0, 2, 1, 0, 3, 4, 0,
            0, 2, 3, 0, 2, 4, 0,
            0, 3, 1, 0, 2, 4, 0,
            0, 1, 2, 0, 3, 3, 0,
            0, 2, 0, 0, 0, 0, 0,
        )
        List(35) { i ->
            val day = if (i < 30) i + 1 else 0
            MonthCell(day = day, level = if (day == 0) 0 else levels[i], today = day == 13)
        }
    }

    // ── 体重与目标（L1311-1340 / saveGoal L1744-1759） ────────────

    const val WEIGHT_VIEW_W = 342f
    const val WEIGHT_VIEW_H = 132f

    /** 体重折线八个点（原型 `polyline` 的坐标，viewBox 342×132）。 */
    val WEIGHT_POINTS = listOf(
        12f to 42f, 57f to 49f, 102f to 47f, 147f to 58f,
        192f to 64f, 237f to 60f, 282f to 68f, 330f to 74f,
    )

    /** 面积图的基线（原型 `polygon` 收到 y=120 再闭合）。 */
    const val WEIGHT_AREA_BASE_Y = 120f

    /** 网格线 y（原型四条 `<line>`，L1312-1315）。 */
    val WEIGHT_GRID_YS = listOf(16f, 44f, 72f, 100f)

    @StringRes
    val WEIGHT_FOOT_LEFT_RES = R.string.review_weight_foot_current

    /** 空库降级样例（原型静态主数值）；真实路径数值见 [weightCurrentText]。 */
    const val WEIGHT_CURRENT = "69.2 kg"

    /** 空库降级样例（原型静态脚注）；真实路径文案见 `review_weight_delta_month`。 */
    @StringRes
    val WEIGHT_DELTA_RES = R.string.review_weight_delta_sample

    /** 目标线的初始 y：markup 写死 90，**与公式值 91 不同**——按 markup 走。 */
    const val INITIAL_GOAL_LINE_Y = 90f

    /** 弹窗初值取自按钮文案里的数字（原型 `openGoalModal`）。 */
    fun initialGoal(): Double = GOAL_INITIAL

    const val GOAL_MIN = 30.0
    const val GOAL_MAX = 200.0
    private const val GOAL_INITIAL = 68.0

    fun clampGoal(value: Double): Double = value.coerceIn(GOAL_MIN, GOAL_MAX)

    /** `y = clamp(16, 116, 16 + (71 − goal) / 4 × 100)`（原型 `saveGoal`）。 */
    fun goalLineY(goal: Double): Float =
        (16.0 + ((71.0 - goal) / 4.0) * 100.0).coerceIn(16.0, 116.0).toFloat()

    /**
     * 目标按钮的数值文案：整数不带小数，非整数保留一位（原型 `val % 1 === 0 ? … : toFixed(1)`）。
     * 整条按钮文案是模板 `review_weight_goal_label`（`目标 %1$s kg`），由 UI 层插值。
     */
    fun goalValueText(goal: Double): String {
        if (goal % 1.0 == 0.0) return goal.toLong().toString()
        return String.format(Locale.US, "%.1f", goal)
    }

    // ── 估算 1RM（L1352-1375） ────────────────────────────────────

    /** 空库时的四行样例（原型静态行；真实路径由 `PersonalRecordService` 填充，见 [OneRmRow]）。 */
    val ONE_RM_SAMPLES = listOf(
        OneRmSample(R.string.review_1rm_sample_bench_press, R.string.review_1rm_sample_bench_press_src, "62.5"),
        OneRmSample(R.string.review_1rm_sample_squat, R.string.review_1rm_sample_squat_src, "95"),
        OneRmSample(R.string.review_1rm_sample_deadlift, R.string.review_1rm_sample_deadlift_src, "105"),
        OneRmSample(R.string.review_1rm_sample_row, R.string.review_1rm_sample_row_src, "58"),
    )

    // ── 努力程度（L1779-1805） ────────────────────────────────────

    /** 最近 8 次的 RIR 原始值（原型 `RIR_DATA`）。 */
    val RIR_DATA = listOf(2, 3, 1, 2, 4, 1, 3, 2)

    /** 每根柱的下限高度百分比（原型 `Math.max(8, h)`）。 */
    const val EFFORT_MIN_BAR_PERCENT = 8

    /** 努力程度柱区一列的总高（原型 `.effort-bars { height: 96px }`）——柱子、间距、序号共用这 96。 */
    const val EFFORT_BAR_COLUMN_HEIGHT = 96

    /** 柱与序号之间的间距（原型 `.effort-bar { gap: 6px }`）。 */
    const val EFFORT_BAR_GAP = 6

    /**
     * 序号行占位（原型 `.lbl { line-height: 1 }` @9px 的实测行高）。
     * 取 12 与鸿蒙端 `EFFORT_BAR_LABEL_HEIGHT` 同口径，保证两端柱高逐像素一致。
     */
    const val EFFORT_BAR_LABEL_HEIGHT = 12

    /**
     * 柱子实际可用的轨道高 = 列高 − 间距 − 序号 = 78。
     *
     * 柱高必须按**轨道**换算，不能按列高的百分比——否则满量程柱(96) 加上间距(6) 与序号(12)
     * 会把 96 的列撑成 114，flex 收缩反过来挤压柱子与序号，第 5 根（唯一满量程）首当其冲。
     */
    const val EFFORT_BAR_TRACK_HEIGHT = EFFORT_BAR_COLUMN_HEIGHT - EFFORT_BAR_GAP - EFFORT_BAR_LABEL_HEIGHT

    /** 未录入占位（仓内既有约定：值渲染 `--`）。 */
    const val EMPTY_VALUE = "--"

    /** 单根柱的高度：把轨道百分比 [percent] 落到固定值，使柱与间距、序号互不挤压。 */
    fun effortBarHeight(percent: Int): Float = percent * EFFORT_BAR_TRACK_HEIGHT / 100f

    /** 单位文案模板：`%1$s` 记法名（`RIR` / `RPE`）——UI 层 `stringResource(id, metric.display)` 插值。 */
    @StringRes
    val EFFORT_UNIT_RES = R.string.review_effort_unit

    /**
     * 把原始量表值映射为柱高百分比：先夹到量表范围 [min, max]，再按量程归一，最后夹下限。
     *
     * 「夹到量表范围」这一步不可省——RIR 口径的量表上界是 4，而真实 RPE 反推的 RIR 最高可达 9
     * （rpe=1 → RIR=9）；不夹会让百分比冲到 225%（柱高 175.5 远超 78 的轨道，柱子溢出列高）。
     * 样例路径 [RIR_DATA] 全在 1–4 内故不触发，但两处共用同一口径，统一在此收口。
     */
    private fun barPercentsOf(values: List<Int>, min: Int, max: Int): List<Int> =
        values.map { raw ->
            val clamped = raw.coerceIn(min, max)
            maxOf(EFFORT_MIN_BAR_PERCENT, ((clamped - min) * 100.0 / (max - min)).toInt())
        }

    fun effort(metric: EffortMetric): EffortView {
        val vals = if (metric == EffortMetric.RIR) RIR_DATA else RIR_DATA.map { 10 - it }
        val min = if (metric == EffortMetric.RIR) 0 else 6
        val max = if (metric == EffortMetric.RIR) 4 else 10
        val avg = vals.sum().toDouble() / vals.size
        val percents = barPercentsOf(vals, min, max)
        return EffortView(
            average = String.format(Locale.US, "%.1f", avg),
            metric = metric,
            barPercents = percents,
            barLabels = vals.indices.map { (it + 1).toString() },
        )
    }

    /**
     * 由**真实**整体 RPE 序列构造努力程度视图（Wave 2）。
     *
     * [rpeValues] 为近 N 次已评价训练的整体 RPE（1–10）。空列表 → 返回 null（调用方渲染空态，
     * 不再回落 [RIR_DATA] 的样例行）。RIR 口径 = `10 − RPE`（与原型 `effort()` 一致）。
     */
    fun effortFrom(metric: EffortMetric, rpeValues: List<Int>): EffortView? {
        if (rpeValues.isEmpty()) return null
        val vals = if (metric == EffortMetric.RIR) rpeValues.map { 10 - it } else rpeValues
        val min = if (metric == EffortMetric.RIR) 0 else 6
        val max = if (metric == EffortMetric.RIR) 4 else 10
        val avg = vals.sum().toDouble() / vals.size
        val percents = barPercentsOf(vals, min, max)
        return EffortView(
            average = String.format(Locale.US, "%.1f", avg),
            metric = metric,
            barPercents = percents,
            barLabels = vals.indices.map { (it + 1).toString() },
        )
    }

    // ── 肌肉地图（L1612-1704） ────────────────────────────────────

    /** 可点选/可着色的 18 组肌肉（原型 `NO`）。 */
    val MUSCLE_IDS = listOf(
        "trapezius", "deltoids", "chest", "upper-back", "serratus", "biceps", "triceps",
        "forearm", "abs", "obliques", "lower-back", "gluteal", "quadriceps", "hamstring",
        "adductors", "hip-flexors", "calves", "tibialis",
    )

    private val MUSCLE_LABEL_RES = mapOf(
        "trapezius" to R.string.review_muscle_trapezius, "deltoids" to R.string.review_muscle_deltoids,
        "chest" to R.string.review_muscle_chest, "upper-back" to R.string.review_muscle_upper_back,
        "serratus" to R.string.review_muscle_serratus, "biceps" to R.string.review_muscle_biceps,
        "triceps" to R.string.review_muscle_triceps, "forearm" to R.string.review_muscle_forearm,
        "abs" to R.string.review_muscle_abs, "obliques" to R.string.review_muscle_obliques,
        "lower-back" to R.string.review_muscle_lower_back, "gluteal" to R.string.review_muscle_gluteal,
        "quadriceps" to R.string.review_muscle_quadriceps, "hamstring" to R.string.review_muscle_hamstring,
        "adductors" to R.string.review_muscle_adductors, "hip-flexors" to R.string.review_muscle_hip_flexors,
        "calves" to R.string.review_muscle_calves, "tibialis" to R.string.review_muscle_tibialis,
    )

    /** 肌肉名资源；未收录的 id 返回 `null`（UI 层回落显示原始 id，同原型 `LABELS[k] || k`）。 */
    @StringRes
    fun muscleLabelRes(id: String): Int? = MUSCLE_LABEL_RES[id]

    private val LEVELS: Map<MuscleMode, Map<String, Int>> = mapOf(
        MuscleMode.BALANCE to mapOf(
            "chest" to 4, "quadriceps" to 4, "gluteal" to 3, "hamstring" to 3, "deltoids" to 3,
            "biceps" to 3, "triceps" to 3, "upper-back" to 3, "abs" to 3, "obliques" to 2,
            "lower-back" to 2, "serratus" to 2, "forearm" to 2, "trapezius" to 2, "calves" to 2,
            "adductors" to 1, "hip-flexors" to 1, "tibialis" to 1,
        ),
        MuscleMode.FATIGUE to mapOf(
            "chest" to 2, "quadriceps" to 4, "gluteal" to 4, "hamstring" to 3, "upper-back" to 3,
            "deltoids" to 2, "biceps" to 2, "triceps" to 2, "calves" to 1, "abs" to 1,
            "obliques" to 1, "lower-back" to 1, "serratus" to 1, "forearm" to 1, "trapezius" to 1,
            "adductors" to 1, "hip-flexors" to 1, "tibialis" to 1,
        ),
        MuscleMode.STRENGTH to mapOf(
            "chest" to 4, "quadriceps" to 4, "gluteal" to 3, "hamstring" to 3, "upper-back" to 3,
            "deltoids" to 3, "biceps" to 2, "triceps" to 2, "abs" to 2, "calves" to 2,
            "obliques" to 1, "lower-back" to 1, "serratus" to 1, "forearm" to 1, "trapezius" to 1,
            "adductors" to 1, "hip-flexors" to 1, "tibialis" to 1,
        ),
    )

    /** 原型 `LEVELS[mode][k] || 0`——未列出的肌肉取 0。 */
    fun muscleLevel(mode: MuscleMode, id: String): Int = LEVELS[mode]?.get(id) ?: 0

    // ── 真实派生（Wave 2）：肌群训练量与努力程度 ─────────────────────
    //
    // 内容库用 6 个粗肌群 id（muscle_chest/back/shoulders/arms/legs/core），而热力图用
    // [MUSCLE_IDS] 的 18 个身体图部位——下表是两者的映射。口径与鸿蒙
    // `ReviewInsightsService.createMuscleVolume/createMuscleLevels` 一致。

    /** 粗肌群 id → 身体图部位（与 [MUSCLE_IDS] 同名）。 */
    fun bodyPartsForMuscle(muscleId: String): List<String> = when (muscleId) {
        "muscle_chest" -> listOf("chest", "serratus")
        "muscle_back" -> listOf("upper-back", "lower-back", "trapezius")
        "muscle_shoulders" -> listOf("deltoids", "trapezius")
        "muscle_arms" -> listOf("biceps", "triceps", "forearm")
        "muscle_legs" -> listOf("quadriceps", "hamstring", "gluteal", "adductors", "calves")
        "muscle_core" -> listOf("abs", "obliques", "hip-flexors")
        else -> emptyList()
    }

    /**
     * 肌群训练量（近 [limit] 次训练）：按组数聚合到 18 个部位（与 [MUSCLE_IDS] 同序）。
     *
     * [resolvePrimaryMuscles] 由调用方注入（避免 data → ui 反向依赖 ContentRepository）。
     * 无数据时全 0（调用方据此渲染空态）。
     */
    fun muscleVolume(
        sessions: List<WorkoutSession>,
        resolvePrimaryMuscles: (String) -> List<String>,
        limit: Int,
    ): List<Int> {
        val volume = MutableList(MUSCLE_IDS.size) { 0 }
        if (sessions.isEmpty()) return volume
        val recent = sessions.sortedBy { it.startedAt }.takeLast(limit)
        for (session in recent) {
            for (set in session.sets) {
                for (muscleId in resolvePrimaryMuscles(set.exerciseId)) {
                    for (part in bodyPartsForMuscle(muscleId)) {
                        val index = MUSCLE_IDS.indexOf(part)
                        if (index >= 0) volume[index] = volume[index] + 1
                    }
                }
            }
        }
        return volume
    }

    /**
     * 训练量归一为 4 级（1–4）——用于热力图着色。无任何训练量时全 0（空态）。
     * 比值分档：≤25% → 1、≤50% → 2、≤75% → 3、否则 4。
     */
    fun muscleLevels(volume: List<Int>): List<Int> {
        val max = volume.maxOrNull() ?: 0
        if (max <= 0) return volume.map { 0 }
        return volume.map { value ->
            when {
                value <= 0 -> 0
                value.toDouble() / max <= 0.25 -> 1
                value.toDouble() / max <= 0.5 -> 2
                value.toDouble() / max <= 0.75 -> 3
                else -> 4
            }
        }
    }

    /** 努力程度序列（近 [count] 次训练的整体 RPE 1–10）；未评价（0）的场次跳过。 */
    fun effortLevels(sessions: List<WorkoutSession>, count: Int): List<Int> =
        sessions.sortedBy { it.startedAt }.takeLast(count)
            .map { it.sessionRpe }
            .filter { it > 0 }

    /**
     * 肌群结论文案（按真实最高/最低训练量部位拼装）；无数据返回空态文案。
     * 口径与鸿蒙 `ReviewInsightsService.createMuscleSummary` 一致。
     */
    fun muscleSummary(volume: List<Int>, labels: List<String>): String {
        var maxIndex = -1
        var minIndex = -1
        var maxValue = 0
        var minValue = -1
        for (index in volume.indices) {
            if (volume[index] > maxValue) {
                maxValue = volume[index]
                maxIndex = index
            }
            if (volume[index] > 0 && (minValue < 0 || volume[index] < minValue)) {
                minValue = volume[index]
                minIndex = index
            }
        }
        if (maxIndex < 0) return "完成训练后，这里会显示肌群训练分布。"
        val maxLabel = labels.getOrElse(maxIndex) { "" }
        if (minIndex < 0 || minIndex == maxIndex) return "${maxLabel}训练量最高。"
        val minLabel = labels.getOrElse(minIndex) { "" }
        return "${maxLabel}训练量最高，${minLabel}最少。"
    }

    private val MM_META_RES = mapOf(
        MuscleMode.BALANCE to R.string.review_muscle_meta_balance,
        MuscleMode.FATIGUE to R.string.review_muscle_meta_fatigue,
        MuscleMode.STRENGTH to R.string.review_muscle_meta_strength,
    )

    private val MM_NOTE_RES = mapOf(
        MuscleMode.BALANCE to R.string.review_muscle_note_balance,
        MuscleMode.FATIGUE to R.string.review_muscle_note_fatigue,
        MuscleMode.STRENGTH to R.string.review_muscle_note_strength,
    )

    private val MM_LABEL_RES = mapOf(
        MuscleMode.BALANCE to R.string.review_muscle_mode_balance,
        MuscleMode.FATIGUE to R.string.review_muscle_mode_fatigue,
        MuscleMode.STRENGTH to R.string.review_muscle_mode_strength,
    )

    private val MM_RECOVERY_RES = listOf(
        R.string.review_muscle_recovery_0,
        R.string.review_muscle_recovery_1,
        R.string.review_muscle_recovery_2,
        R.string.review_muscle_recovery_3,
    )

    private val MM_STRENGTH_RES = listOf(
        R.string.review_muscle_strength_0,
        R.string.review_muscle_strength_1,
        R.string.review_muscle_strength_2,
        R.string.review_muscle_strength_3,
    )

    @StringRes
    fun mmMetaRes(mode: MuscleMode): Int = MM_META_RES.getValue(mode)

    @StringRes
    fun mmNoteRes(mode: MuscleMode): Int = MM_NOTE_RES.getValue(mode)

    @StringRes
    fun mmLabelRes(mode: MuscleMode): Int = MM_LABEL_RES.getValue(mode)

    /**
     * 点选后的详情行取值（原型 `selectMuscle`）——文案走资源；等级**按下标直接取**
     * （不是从 1 开始），UI 层以 [MuscleDetail.textRes]（+ 可选 [MuscleDetail.arg]）插值。
     */
    fun muscleDetail(mode: MuscleMode, id: String): MuscleDetail {
        val lvl = muscleLevel(mode, id)
        return when (mode) {
            MuscleMode.BALANCE -> MuscleDetail(R.string.review_muscle_detail_sets, lvl * 10 + 8)
            MuscleMode.FATIGUE ->
                MuscleDetail(MM_RECOVERY_RES.getOrNull(lvl) ?: R.string.review_muscle_detail_none)

            MuscleMode.STRENGTH ->
                MuscleDetail(MM_STRENGTH_RES.getOrNull(lvl) ?: R.string.review_muscle_detail_none)
        }
    }

    /** 详情行进度条的填充宽度百分比（原型 `fill.style.width = lvl * 25 + '%'`）。 */
    fun muscleDetailPercent(mode: MuscleMode, id: String): Int = muscleLevel(mode, id) * 25

    // ── 肌肉地图图例（L1284-1300） ───────────────────────────────

    /** 图例两端的文案（原型 `.hm-legend` 里的「低」「高」）。 */
    @StringRes
    val LEGEND_LOW_RES = R.string.review_muscle_legend_low

    @StringRes
    val LEGEND_HIGH_RES = R.string.review_muscle_legend_high

    // ── W3-2b 真实数据接线：训练节奏 / 月历 / 体重（纯函数） ──────────
    //
    // 数据源为 data 层 `WorkoutSession`（会话）与 `WeightRecord`（体重）；空库时调用方回落上方
    // 样例常量，此处只做「有数据 → 渲染结构」的纯映射，不触 IO。日期口径同 `WorkoutSessionService` /
    // `BodyRecordService`（`java.util.Calendar` 本地时区，`minSdk = 24` 不用 `java.time`）。

    /** 周柱高度包络：对齐原型亮柱区间（`WEEK_BARS` 最低 / 最高柱），真实数据按当日训练量归一到此。 */
    const val WEEK_BAR_MIN_H = 38.1f
    const val WEEK_BAR_MAX_H = 105.2f

    /**
     * 本周（周首由 [weekStart] 决定，共 7 天）逐日训练量分桶为七根柱。柱高按当日训练量在当周最大值
     * 中的占比较 [WEEK_BAR_MIN_H]..[WEEK_BAR_MAX_H] 线性映射；未训练日取下限高、[WeekBar.on] = false。
     * 标签序随 [weekStart] 联动（[WeekWindow.dayLabels]）。
     * 训练量口径同 `WorkoutSessionService.sessionVolume`（非热身组 `weight × reps` 之和）。
     */
    fun weeklyBars(
        sessions: List<WorkoutSession>,
        nowMillis: Long = System.currentTimeMillis(),
        weekStart: WeekStart,
    ): List<WeekBar> {
        val weekStartMillis = mondayStart(nowMillis, weekStart)
        val volumes = DoubleArray(7)
        for (session in sessions) {
            if (mondayStart(session.startedAt, weekStart) != weekStartMillis) continue
            volumes[mondayIndex(session.startedAt, weekStart)] += sessionVolume(session)
        }
        val max = volumes.maxOrNull() ?: 0.0
        val labels = WeekWindow.dayLabels(weekStart)
        return List(7) { index ->
            val volume = volumes[index]
            val height = if (max <= 0.0) {
                WEEK_BAR_MIN_H
            } else {
                WEEK_BAR_MIN_H + (volume / max).toFloat() * (WEEK_BAR_MAX_H - WEEK_BAR_MIN_H)
            }
            WeekBar(labels[index], height, on = volume > 0.0)
        }
    }

    /**
     * 当前自然月（本地时区）的日期格：前置空位对齐当月 1 号在周首序中的位置（周首由 [weekStart] 决定）、
     * 尾部补到 7 的倍数。
     * [MonthCell.level] 按当日训练量在当月最大值中的占比映射到 `1..4`（未训练为 `0`），
     * 当月今天标 [MonthCell.today]。
     */
    fun monthGrid(
        sessions: List<WorkoutSession>,
        nowMillis: Long = System.currentTimeMillis(),
        weekStart: WeekStart,
    ): List<MonthCell> {
        val now = calendarOf(nowMillis)
        val year = now.get(Calendar.YEAR)
        val month0 = now.get(Calendar.MONTH)
        val daysInMonth = now.getActualMaximum(Calendar.DAY_OF_MONTH)
        val todayDom = now.get(Calendar.DAY_OF_MONTH)

        val volumes = DoubleArray(daysInMonth + 1)
        for (session in sessions) {
            val cal = calendarOf(session.startedAt)
            if (cal.get(Calendar.YEAR) == year && cal.get(Calendar.MONTH) == month0) {
                volumes[cal.get(Calendar.DAY_OF_MONTH)] += sessionVolume(session)
            }
        }
        val max = volumes.maxOrNull() ?: 0.0

        val cells = ArrayList<MonthCell>(35)
        repeat(mondayOffsetOfFirst(year, month0, weekStart)) { cells.add(MonthCell(day = 0, level = 0)) }
        for (day in 1..daysInMonth) {
            val volume = volumes[day]
            val level = if (volume <= 0.0 || max <= 0.0) {
                0
            } else {
                ceil(volume / max * 4.0).toInt().coerceIn(1, 4)
            }
            cells.add(MonthCell(day = day, level = level, today = day == todayDom))
        }
        while (cells.size % 7 != 0) cells.add(MonthCell(day = 0, level = 0))
        return cells
    }

    /** 月历标题参数：`年` / `月`——文案模板 `review_month_label` 由 UI 层插值。 */
    fun monthLabel(nowMillis: Long = System.currentTimeMillis()): MonthLabel {
        val cal = calendarOf(nowMillis)
        return MonthLabel(cal.get(Calendar.YEAR), cal.get(Calendar.MONTH) + 1)
    }

    /** 月历 meta 参数：`(当月去重训练日数, 总分钟)`——模板 `review_month_meta` 由 UI 层插值。 */
    fun monthMeta(
        sessions: List<WorkoutSession>,
        nowMillis: Long = System.currentTimeMillis(),
    ): MonthMeta {
        val cal = calendarOf(nowMillis)
        val year = cal.get(Calendar.YEAR)
        val month0 = cal.get(Calendar.MONTH)
        val days = LinkedHashSet<Int>()
        var seconds = 0
        for (session in sessions) {
            val s = calendarOf(session.startedAt)
            if (s.get(Calendar.YEAR) != year || s.get(Calendar.MONTH) != month0) continue
            days.add(s.get(Calendar.DAY_OF_MONTH))
            seconds += session.durationSeconds
        }
        return MonthMeta(days.size, seconds / 60)
    }

    /**
     * 某一天的训练摘要（与鸿蒙 `ReviewContent.initCalendarData` 同口径）：
     * 训练量 = Σ 非热身 `weight×reps`；组数同样排除热身；动作数按 `exerciseId` 去重。
     * 当天无训练返回 `hasSession=false`、其余字段为 0。
     */
    fun daySummary(
        sessions: List<WorkoutSession>,
        day: Int,
        nowMillis: Long = System.currentTimeMillis(),
        weekStart: WeekStart,
    ): DaySummary {
        val cal = calendarOf(nowMillis)
        val year = cal.get(Calendar.YEAR)
        val month0 = cal.get(Calendar.MONTH)
        val exerciseIds = LinkedHashSet<String>()
        var seconds = 0
        var setCount = 0
        var volume = 0.0
        var hasSession = false
        for (session in sessions) {
            val s = calendarOf(session.startedAt)
            if (s.get(Calendar.YEAR) != year || s.get(Calendar.MONTH) != month0) continue
            if (s.get(Calendar.DAY_OF_MONTH) != day) continue
            hasSession = true
            seconds += session.durationSeconds
            for (set in session.sets) {
                exerciseIds.add(set.exerciseId)
                if (!set.isWarmup) {
                    setCount++
                    volume += set.weight * set.reps
                }
            }
        }
        return DaySummary(
            day = day,
            durationMinutes = seconds / 60,
            exerciseCount = exerciseIds.size,
            setCount = setCount,
            volumeKg = volume,
            hasSession = hasSession,
        )
    }

    /** 体重曲线绘图区（与 `WEIGHT_POINTS` 同一 342×132 viewBox 内的落点范围）。 */
    const val WEIGHT_PLOT_X0 = 12f
    const val WEIGHT_PLOT_X1 = 330f
    const val WEIGHT_PLOT_TOP = 16f
    const val WEIGHT_PLOT_BOTTOM = 100f

    /**
     * 千克值序列 → 曲线点集：x 在 [WEIGHT_PLOT_X0]..[WEIGHT_PLOT_X1] 均分，y 按 min/max 归一到
     * [WEIGHT_PLOT_TOP]..[WEIGHT_PLOT_BOTTOM]（同 `FtBodyModel.chartPoints` 的归一化）；值全等时取中线。
     */
    fun weightPoints(values: List<Float>): List<Pair<Float, Float>> {
        if (values.isEmpty()) return emptyList()
        val lo = values.min()
        val hi = values.max()
        val span = hi - lo
        val step = if (values.size > 1) (WEIGHT_PLOT_X1 - WEIGHT_PLOT_X0) / (values.size - 1) else 0f
        val midY = (WEIGHT_PLOT_TOP + WEIGHT_PLOT_BOTTOM) / 2f
        return values.mapIndexed { index, value ->
            val x = WEIGHT_PLOT_X0 + step * index
            val y = if (span == 0f) {
                midY
            } else {
                WEIGHT_PLOT_BOTTOM - ((value - lo) / span) * (WEIGHT_PLOT_BOTTOM - WEIGHT_PLOT_TOP)
            }
            x to y
        }
    }

    /** 体重卡主数值：`%.1f kg`（千克基准，按当前单位换算后展示）。 */
    fun weightCurrentText(kg: Double, unit: WeightUnit): String =
        String.format(Locale.US, "%.1f %s", WeightUtils.kgToDisplay(kg, unit), WeightUtils.unitLabel(unit))

    /**
     * 统计卡「体重变化」数值：`%.1f`（无单位，单位由卡片 `unit` 给出）。
     *
     * 「较上月」脚注的文案模板是 `review_weight_delta_month`（`较上月 %1$s`），本函数返回值 +
     * 当前单位标签由 UI 层拼装后插值（模型层不持有 `Context`）；正负号沿用原型样例的 ASCII 连字符风格。
     */
    fun weightDeltaValue(deltaKg: Double, unit: WeightUnit): String =
        String.format(Locale.US, "%.1f", WeightUtils.kgToDisplay(deltaKg, unit))

    /** 1RM 行数值：kg 基准 → 当前单位下的展示文本（整数或 1 位小数）。 */
    fun oneRmValueText(kg: Double, unit: WeightUnit): String {
        val value: Double = WeightUtils.kgToDisplay(kg, unit)
        return if (Math.round(value * 10) % 10 == 0L) Math.round(value).toString()
        else String.format(Locale.US, "%.1f", value)
    }

    // --- 内部：日期与训练量（本地时区，同 WorkoutSessionService / BodyRecordService） ---

    private fun calendarOf(millis: Long): Calendar =
        Calendar.getInstance().apply { timeInMillis = millis }

    /** 本地时区日零点（对齐 JS `new Date(y, m, d)`）。 */
    private fun startOfDay(millis: Long): Long {
        val cal = calendarOf(millis)
        return calendarAt(cal.get(Calendar.YEAR), cal.get(Calendar.MONTH), cal.get(Calendar.DAY_OF_MONTH)).timeInMillis
    }

    /** 当周周首 00:00（周首由 [weekStart] 决定；`Calendar.DAY_OF_WEEK`：周日=1..周六=7）。 */
    private fun mondayStart(millis: Long, weekStart: WeekStart): Long {
        val cal = calendarOf(startOfDay(millis))
        return calendarAt(
            cal.get(Calendar.YEAR),
            cal.get(Calendar.MONTH),
            cal.get(Calendar.DAY_OF_MONTH) - mondayIndex(millis, weekStart),
        ).timeInMillis
    }

    /** 本地周几的周索引（自周首起）：周首 = 0 … 第 6 天 = 6。 */
    private fun mondayIndex(millis: Long, weekStart: WeekStart): Int {
        val dow = calendarOf(millis).get(Calendar.DAY_OF_WEEK) // 周日=1..周六=7
        return WeekWindow.offsetFromWeekStart(dow - 1, weekStart)
    }

    /** 某月 1 号的周索引（自周首起）：周首 = 0 … 第 6 天 = 6。 */
    private fun mondayOffsetOfFirst(year: Int, month0: Int, weekStart: WeekStart): Int {
        val dow = calendarAt(year, month0, 1).get(Calendar.DAY_OF_WEEK)
        return WeekWindow.offsetFromWeekStart(dow - 1, weekStart)
    }

    /** 本地时区午夜 Calendar（对齐 JS `new Date(y, m, d)`）。 */
    private fun calendarAt(year: Int, month0: Int, dayOfMonth: Int): Calendar {
        val cal = Calendar.getInstance()
        cal.clear()
        cal.set(year, month0, dayOfMonth)
        return cal
    }

    /** 会话训练量：非热身组的 `weight × reps` 之和（同 `WorkoutSessionService.sessionVolume`）。 */
    private fun sessionVolume(session: WorkoutSession): Double {
        var volume = 0.0
        for (set in session.sets) {
            if (!set.isWarmup) volume += set.weight * set.reps
        }
        return volume
    }
}

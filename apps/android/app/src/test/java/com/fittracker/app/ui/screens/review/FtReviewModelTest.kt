package com.fittracker.app.ui.screens.review

import com.fittracker.app.R
import com.fittracker.app.data.model.WorkoutSession
import com.fittracker.app.data.model.WorkoutSet
import com.fittracker.app.data.service.WeightUnit
import com.fittracker.app.data.service.WeekStart
import java.util.Calendar
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 训练回顾屏纯逻辑层的契约测试。
 *
 * 期望值逐条取自原型 `design/06_prototype_redraw/src/fittracker-review.html`：
 * WEEK/MONTH 数据（L1541-1563）、`renderEffort()`（L1779-1805）、
 * `saveGoal()`（L1744-1759）、月历格子（L1203-1260）、肌肉地图常量（L1612-1627）。
 *
 * **文案断言外移**（Wave 7 i18n）：模型只持资源 ID，逐字真值在
 * `values/strings_review.xml`——本类断言「哪个资源 ID」与纯逻辑（数值 / 坐标 / 归一化），
 * 文案**文本**的逐字校验见 [FtReviewStringsTest]（Robolectric + `context.getString`）。
 */
class FtReviewModelTest {

    // ── 时间尺度数据（原型 WEEK / MONTH，L1541-1563） ──────────────

    @Test
    fun `周尺度数据指向原型文案资源且样例值不变`() {
        val w = FtReviewModel.WEEK
        assertEquals(R.string.review_head_week_sample, w.weekRes)
        assertEquals("↑ +18%", w.badge)
        assertEquals(R.string.review_week_headline, w.headlineRes)
        assertEquals(R.string.review_week_desc, w.descRes)
        assertEquals(R.string.review_week_sub, w.subRes)
        assertEquals(
            listOf(
                ReviewStat(R.string.review_stat_workouts, "4", R.string.review_unit_times),
                ReviewStat(R.string.review_stat_duration, "186", R.string.review_unit_minutes),
                ReviewStat(R.string.review_stat_weight_change, "-0.8", R.string.review_unit_kg),
            ),
            w.stats,
        )
    }

    @Test
    fun `月尺度数据指向原型文案资源且样例值不变`() {
        val m = FtReviewModel.MONTH
        assertEquals(R.string.review_head_month_sample, m.weekRes)
        assertEquals("↑ +12%", m.badge)
        assertEquals(R.string.review_month_headline, m.headlineRes)
        assertEquals(R.string.review_month_desc, m.descRes)
        assertEquals(R.string.review_month_sub, m.subRes)
        assertEquals(
            listOf(
                ReviewStat(R.string.review_stat_workouts, "17", R.string.review_unit_times),
                ReviewStat(R.string.review_stat_duration, "720", R.string.review_unit_minutes),
                ReviewStat(R.string.review_stat_weight_change, "-1.6", R.string.review_unit_kg),
            ),
            m.stats,
        )
    }

    /** 周柱高度是原型写在 inline style 里的字面量（L1195-1201）；日标签取 `WeekWindow.dayLabels`。 */
    @Test
    fun `周柱状七天的高度与点亮状态逐条对齐原型`() {
        val bars = FtReviewModel.WEEK_BARS
        assertEquals(listOf("一", "二", "三", "四", "五", "六", "日"), bars.map { it.label })
        assertEquals(listOf(52.6f, 83.4f, 67.1f, 38.1f, 105.2f, 74.4f, 41.7f), bars.map { it.height })
        assertEquals(listOf(false, true, true, false, true, true, false), bars.map { it.on })
    }

    // ── 月历（原型 L1203-1260） ────────────────────────────────────

    @Test
    fun `月历为 6 月共 30 天加 5 个空位且 13 号为今天`() {
        val cells = FtReviewModel.MONTH_CELLS
        assertEquals(35, cells.size)
        // MONTH_HEAD 常量已移除（表头序改由 WeekWindow.dayLabels(weekStart) 驱动）——
        // 「一…日」表头断言由 WeekWindowTest 的 dayLabels 两态用例继承覆盖。

        val days = cells.filter { it.day > 0 }
        assertEquals(30, days.size)
        assertEquals(1, days.first().day)
        assertEquals(30, days.last().day)
        assertEquals(13, cells.first { it.today }.day)
        assertEquals(5, cells.count { it.day == 0 })
    }

    /** 月历标语与图例（原型 `.month-cal` 的 tip / `.month-legend`）指向资源。 */
    @Test
    fun `月历样例文案与图例指向资源`() {
        assertEquals(R.string.review_month_label_sample, FtReviewModel.MONTH_LABEL_RES)
        assertEquals(R.string.review_month_meta_sample, FtReviewModel.MONTH_META_RES)
        assertEquals(R.string.review_month_tip, FtReviewModel.MONTH_TIP_RES)
        assertEquals(
            listOf(
                R.string.review_month_legend_none,
                R.string.review_month_legend_light,
                R.string.review_month_legend_medium,
                R.string.review_month_legend_high,
                R.string.review_month_legend_max,
            ),
            FtReviewModel.MONTH_LEGEND_RES,
        )
    }

    /** 每格等级取自原型的 `mcal-cell lN` class（L1210-1249）。 */
    @Test
    fun `月历各格等级与原型 class 对齐`() {
        val byDay = FtReviewModel.MONTH_CELLS.filter { it.day > 0 }.associateBy { it.day }
        // 抽样几格：1 未练、2 轻(l1)、5 高(l3)、6 大(l4)、13 今天(l4)
        assertEquals(0, byDay.getValue(1).level)
        assertEquals(2, byDay.getValue(2).level)
        assertEquals(3, byDay.getValue(5).level)
        assertEquals(4, byDay.getValue(6).level)
        assertTrue(byDay.getValue(13).today)
        assertEquals(4, byDay.getValue(13).level)
        // 17 号 l1、20 号 l4
        assertEquals(1, byDay.getValue(17).level)
        assertEquals(4, byDay.getValue(20).level)
    }

    // ── 努力程度（原型 renderEffort，L1779-1805） ─────────────────

    @Test
    fun `RIR 视图的均值与柱高按原型公式`() {
        val e = FtReviewModel.effort(EffortMetric.RIR)
        assertEquals("2.3", e.average) // 18/8 = 2.25 → toFixed(1)
        assertEquals(EffortMetric.RIR, e.metric)
        assertEquals(R.string.review_effort_unit, FtReviewModel.EFFORT_UNIT_RES)
        assertEquals(listOf(50, 75, 25, 50, 100, 25, 75, 50), e.barPercents)
        assertEquals(listOf("1", "2", "3", "4", "5", "6", "7", "8"), e.barLabels)
    }

    @Test
    fun `RPE 视图为 10 减 RIR 且均值不同`() {
        val e = FtReviewModel.effort(EffortMetric.RPE)
        assertEquals("7.8", e.average) // 62/8 = 7.75 → toFixed(1)
        assertEquals(EffortMetric.RPE, e.metric)
        // (10-RIR − 6)/4 × 100，下限 8%
        assertEquals(listOf(50, 25, 75, 50, 8, 75, 25, 50), e.barPercents)
    }

    // ── 体重目标（原型 saveGoal，L1744-1759） ────────────────────

    @Test
    fun `目标线纵坐标按折线量程映射而非原型固定基准`() {
        // 原型公式 `16 + (71−goal)/4×100`（固定基准 71 kg / 跨度 4 kg）与真实曲线不同坐标系，
        // 已改为按折线量程 lo..hi 映射到绘图区 16..100（[FtReviewModel.WEIGHT_PLOT_TOP]..BOTTOM）。
        assertEquals(58.0f, FtReviewModel.goalLineY(65.0, 60.0, 70.0), 1e-3f) // 量程中点
        assertEquals(16.0f, FtReviewModel.goalLineY(70.0, 60.0, 70.0), 1e-3f) // 上界 → 顶边
        assertEquals(100.0f, FtReviewModel.goalLineY(60.0, 60.0, 70.0), 1e-3f) // 下界 → 底边
    }

    /** 数值文案由 UI 层套模板（`目标 %1$s kg`）；未设置时 UI 走「设置目标」空态文案。 */
    @Test
    fun `目标数值文案与边界夹取`() {
        assertEquals("68", FtReviewModel.goalValueText(68.0))
        assertEquals("68.5", FtReviewModel.goalValueText(68.5)) // 非整数保留一位
        assertEquals(30.0, FtReviewModel.clampGoal(10.0), 1e-6) // 低于下限夹到 30
        assertEquals(200.0, FtReviewModel.clampGoal(999.0), 1e-6) // 高于上限夹到 200
        assertEquals(68.0, FtReviewModel.clampGoal(68.0), 1e-6) // 区间内原样
    }

    // ── 体重曲线（原型 `.chart` SVG，L1311-1330） ────────────────

    @Test
    fun `体重曲线八点坐标与原型 polyline 一致`() {
        assertEquals(
            listOf(12f to 42f, 57f to 49f, 102f to 47f, 147f to 58f,
                192f to 64f, 237f to 60f, 282f to 68f, 330f to 74f),
            FtReviewModel.WEIGHT_POINTS,
        )
        assertEquals(342f, FtReviewModel.WEIGHT_VIEW_W, 1e-3f)
        assertEquals(132f, FtReviewModel.WEIGHT_VIEW_H, 1e-3f)
    }

    @Test
    fun `体重卡页脚样例指向资源且主数值不变`() {
        assertEquals(R.string.review_weight_foot_current, FtReviewModel.WEIGHT_FOOT_LEFT_RES)
        assertEquals("69.2 kg", FtReviewModel.WEIGHT_CURRENT)
        assertEquals(R.string.review_weight_delta_sample, FtReviewModel.WEIGHT_DELTA_RES)
    }

    // ── 肌肉地图常量（原型 L1612-1627） ─────────────────────────

    @Test
    fun `肌肉地图三档模式的 meta 与标签指向原型资源`() {
        assertEquals(R.string.review_muscle_meta_balance, FtReviewModel.mmMetaRes(MuscleMode.BALANCE))
        assertEquals(R.string.review_muscle_meta_fatigue, FtReviewModel.mmMetaRes(MuscleMode.FATIGUE))
        assertEquals(R.string.review_muscle_meta_strength, FtReviewModel.mmMetaRes(MuscleMode.STRENGTH))
        assertEquals(R.string.review_muscle_mode_balance, FtReviewModel.mmLabelRes(MuscleMode.BALANCE))
        assertEquals(R.string.review_muscle_mode_fatigue, FtReviewModel.mmLabelRes(MuscleMode.FATIGUE))
        assertEquals(R.string.review_muscle_mode_strength, FtReviewModel.mmLabelRes(MuscleMode.STRENGTH))
        assertEquals(R.string.review_muscle_legend_low, FtReviewModel.LEGEND_LOW_RES)
        assertEquals(R.string.review_muscle_legend_high, FtReviewModel.LEGEND_HIGH_RES)
    }

    @Test
    fun `肌群等级按真实等级表取值且未知回落 0`() {
        val levels = MutableList(FtReviewModel.MUSCLE_IDS.size) { 0 }
        levels[FtReviewModel.MUSCLE_IDS.indexOf("chest")] = 4
        levels[FtReviewModel.MUSCLE_IDS.indexOf("quadriceps")] = 2
        levels[FtReviewModel.MUSCLE_IDS.indexOf("tibialis")] = 1
        assertEquals(4, FtReviewModel.muscleLevel(levels, "chest"))
        assertEquals(2, FtReviewModel.muscleLevel(levels, "quadriceps"))
        assertEquals(1, FtReviewModel.muscleLevel(levels, "tibialis"))
        assertEquals(0, FtReviewModel.muscleLevel(levels, "deltoids"))
        // 未收录的 id、空等级表都回落 0（原型「未列出的肌肉取 0」的同语义）
        assertEquals(0, FtReviewModel.muscleLevel(levels, "not-a-muscle"))
        assertEquals(0, FtReviewModel.muscleLevel(emptyList(), "chest"))
        for (id in FtReviewModel.MUSCLE_IDS) {
            assertTrue("$id 超界", FtReviewModel.muscleLevel(levels, id) in 0..4)
        }
    }

    @Test
    fun `肌肉中文名资源与原型 LABELS 一一对应`() {
        assertEquals(R.string.review_muscle_trapezius, FtReviewModel.muscleLabelRes("trapezius"))
        assertEquals(R.string.review_muscle_deltoids, FtReviewModel.muscleLabelRes("deltoids"))
        assertEquals(R.string.review_muscle_chest, FtReviewModel.muscleLabelRes("chest"))
        assertEquals(R.string.review_muscle_upper_back, FtReviewModel.muscleLabelRes("upper-back"))
        assertEquals(R.string.review_muscle_serratus, FtReviewModel.muscleLabelRes("serratus"))
        assertEquals(R.string.review_muscle_biceps, FtReviewModel.muscleLabelRes("biceps"))
        assertEquals(R.string.review_muscle_triceps, FtReviewModel.muscleLabelRes("triceps"))
        assertEquals(R.string.review_muscle_forearm, FtReviewModel.muscleLabelRes("forearm"))
        assertEquals(R.string.review_muscle_abs, FtReviewModel.muscleLabelRes("abs"))
        assertEquals(R.string.review_muscle_obliques, FtReviewModel.muscleLabelRes("obliques"))
        assertEquals(R.string.review_muscle_lower_back, FtReviewModel.muscleLabelRes("lower-back"))
        assertEquals(R.string.review_muscle_gluteal, FtReviewModel.muscleLabelRes("gluteal"))
        assertEquals(R.string.review_muscle_quadriceps, FtReviewModel.muscleLabelRes("quadriceps"))
        assertEquals(R.string.review_muscle_hamstring, FtReviewModel.muscleLabelRes("hamstring"))
        assertEquals(R.string.review_muscle_adductors, FtReviewModel.muscleLabelRes("adductors"))
        assertEquals(R.string.review_muscle_hip_flexors, FtReviewModel.muscleLabelRes("hip-flexors"))
        assertEquals(R.string.review_muscle_calves, FtReviewModel.muscleLabelRes("calves"))
        assertEquals(R.string.review_muscle_tibialis, FtReviewModel.muscleLabelRes("tibialis"))
        // 未收录的 id 返回 null（UI 层回落显示原始 id，同原型 `LABELS[k] || k`）
        assertNull(FtReviewModel.muscleLabelRes("not-a-muscle"))
        assertEquals(18, FtReviewModel.MUSCLE_IDS.size)
    }

    /** 点选肌肉后详情行的取值（真实训练量派生，档位词口径同鸿蒙 `muscleStatWord`）。 */
    @Test
    fun `点选肌肉的详情取真实组数并按下标映射档位词`() {
        val levels = MutableList(FtReviewModel.MUSCLE_IDS.size) { 0 }
        levels[FtReviewModel.MUSCLE_IDS.indexOf("chest")] = 4
        levels[FtReviewModel.MUSCLE_IDS.indexOf("quadriceps")] = 2
        levels[FtReviewModel.MUSCLE_IDS.indexOf("tibialis")] = 1
        val volume = MutableList(FtReviewModel.MUSCLE_IDS.size) { 0 }
        volume[FtReviewModel.MUSCLE_IDS.indexOf("chest")] = 17
        volume[FtReviewModel.MUSCLE_IDS.indexOf("quadriceps")] = 9

        // 平衡模式：显示该部位真实组数（不再 等级×10+8）
        assertEquals(
            MuscleDetail(R.string.review_muscle_detail_sets, 17),
            FtReviewModel.muscleDetail(levels, volume, MuscleMode.BALANCE, "chest"),
        )
        assertEquals(
            MuscleDetail(R.string.review_muscle_detail_sets, 9),
            FtReviewModel.muscleDetail(levels, volume, MuscleMode.BALANCE, "quadriceps"),
        )
        assertEquals(
            MuscleDetail(R.string.review_muscle_detail_sets, 0),
            FtReviewModel.muscleDetail(levels, volume, MuscleMode.BALANCE, "tibialis"),
        )
        // 档位词按 level-1 取：4 档 → 「疲劳」/「强」；2 档 → 第 2 条；1 档 → 第 1 条
        assertEquals(
            MuscleDetail(R.string.review_muscle_recovery_3),
            FtReviewModel.muscleDetail(levels, volume, MuscleMode.FATIGUE, "chest"),
        )
        assertEquals(
            MuscleDetail(R.string.review_muscle_recovery_1),
            FtReviewModel.muscleDetail(levels, volume, MuscleMode.FATIGUE, "quadriceps"),
        )
        assertEquals(
            MuscleDetail(R.string.review_muscle_strength_0),
            FtReviewModel.muscleDetail(levels, volume, MuscleMode.STRENGTH, "tibialis"),
        )
        // 0 档（无训练量）与未知 id → 「—」
        assertEquals(
            MuscleDetail(R.string.review_muscle_detail_none),
            FtReviewModel.muscleDetail(levels, volume, MuscleMode.STRENGTH, "deltoids"),
        )
        assertEquals(
            MuscleDetail(R.string.review_muscle_detail_none),
            FtReviewModel.muscleDetail(levels, volume, MuscleMode.FATIGUE, "unknown"),
        )
        // 进度条仍按等级 × 25
        assertEquals(100, FtReviewModel.muscleDetailPercent(levels, "chest"))
        assertEquals(0, FtReviewModel.muscleDetailPercent(levels, "deltoids"))
    }

    // ── 估算 1RM（原型 L1352-1375） ──────────────────────────────

    @Test
    fun `估算 1RM 四行样例指向原型资源`() {
        assertEquals(
            listOf(
                OneRmSample(R.string.review_1rm_sample_bench_press, R.string.review_1rm_sample_bench_press_src, "62.5"),
                OneRmSample(R.string.review_1rm_sample_squat, R.string.review_1rm_sample_squat_src, "95"),
                OneRmSample(R.string.review_1rm_sample_deadlift, R.string.review_1rm_sample_deadlift_src, "105"),
                OneRmSample(R.string.review_1rm_sample_row, R.string.review_1rm_sample_row_src, "58"),
            ),
            FtReviewModel.ONE_RM_SAMPLES,
        )
    }

    // ── W3-2b 真实数据接线：训练节奏 / 月历 / 体重（纯函数） ──────────

    /** 本地时区日零点（与服务 `startOfDay` / `mondayStart` 同口径）。 */
    private fun day(year: Int, month1: Int, dayOfMonth: Int): Long {
        val cal = Calendar.getInstance()
        cal.clear()
        cal.set(year, month1 - 1, dayOfMonth)
        return cal.timeInMillis
    }

    /** 单会话：给定开始时刻、时长与工作组 `(重量, 次数)` 列表（全部非热身）。 */
    private fun session(
        startedAt: Long,
        durationSeconds: Int = 0,
        volumeSets: List<Pair<Double, Int>> = emptyList(),
    ): WorkoutSession = WorkoutSession(
        sessionId = "s-$startedAt-$durationSeconds",
        planId = "p",
        dayId = "d",
        startedAt = startedAt,
        endedAt = startedAt + durationSeconds * 1000L,
        durationSeconds = durationSeconds,
        totalSets = volumeSets.size,
        totalVolume = volumeSets.sumOf { (weight, reps) -> weight * reps },
        fatigueScore = 0.0,
        notes = "",
        sets = volumeSets.mapIndexed { index, (weight, reps) ->
            WorkoutSet(setId = "set-$index", exerciseId = "e", weight = weight, reps = reps, rpe = 8.0, isWarmup = false)
        },
    )

    @Test
    fun `训练节奏按本周逐日训练量分桶`() {
        val now = day(2026, 6, 10) // 周三
        val sessions = listOf(
            session(day(2026, 6, 8), volumeSets = listOf(50.0 to 2)), // 周一 · 100
            session(day(2026, 6, 10), volumeSets = listOf(100.0 to 2)), // 周三 · 200（本周最大）
            session(day(2026, 6, 15), volumeSets = listOf(999.0 to 1)), // 下周一 · 出周窗口
        )
        val bars = FtReviewModel.weeklyBars(sessions, now, WeekStart.MONDAY)
        assertEquals(listOf("一", "二", "三", "四", "五", "六", "日"), bars.map { it.label })
        assertEquals(listOf(true, false, true, false, false, false, false), bars.map { it.on })
        // 本周最大量（周三）取上限，未训练日取下限
        assertEquals(FtReviewModel.WEEK_BAR_MAX_H, bars[2].height, 1e-3f)
        assertEquals(FtReviewModel.WEEK_BAR_MIN_H, bars[1].height, 1e-3f)
        // 周一 100/200 = 半程 → 下限 + 半程跨度
        assertEquals(
            FtReviewModel.WEEK_BAR_MIN_H + (FtReviewModel.WEEK_BAR_MAX_H - FtReviewModel.WEEK_BAR_MIN_H) / 2f,
            bars[0].height,
            1e-3f,
        )
    }

    @Test
    fun `训练节奏空会话回落下限高且全灭`() {
        val bars = FtReviewModel.weeklyBars(emptyList(), day(2026, 6, 10), WeekStart.MONDAY)
        assertEquals(7, bars.size)
        assertTrue(bars.all { !it.on })
        assertTrue(bars.all { it.height == FtReviewModel.WEEK_BAR_MIN_H })
    }

    @Test
    fun `月历按会话逐日聚合并映射等级`() {
        val now = day(2026, 6, 10)
        val sessions = listOf(
            session(day(2026, 6, 2), volumeSets = listOf(50.0 to 2)), // 100
            session(day(2026, 6, 5), volumeSets = listOf(100.0 to 2)), // 200（当月最大）
            session(day(2026, 7, 1), volumeSets = listOf(999.0 to 1)), // 下月 · 排除
        )
        val cells = FtReviewModel.monthGrid(sessions, now, WeekStart.MONDAY)
        // 2026-06-01 是周一 → 无前置空位；30 天 + 5 个尾部占位 = 35
        assertEquals(35, cells.size)
        assertEquals(5, cells.count { it.day == 0 })
        assertEquals(30, cells.filter { it.day > 0 }.size)
        assertEquals(1, cells.first().day)
        assertEquals(2, cells.first { it.day == 2 }.level) // 100/200 → 半程 → 2
        assertEquals(4, cells.first { it.day == 5 }.level) // 当月最大 → 4
        assertEquals(0, cells.first { it.day == 1 }.level) // 未训练
        assertEquals(10, cells.first { it.today }.day)
    }

    @Test
    fun `当天摘要聚合时长动作数组数与容量`() {
        val now = day(2026, 6, 10)
        val sessions = listOf(
            session(day(2026, 6, 2), durationSeconds = 600, volumeSets = listOf(50.0 to 2, 30.0 to 3)), // 190
            session(day(2026, 6, 2), durationSeconds = 300, volumeSets = listOf(100.0 to 1)), // 同日第二场 +100
            session(day(2026, 6, 5), durationSeconds = 1200, volumeSets = listOf(999.0 to 1)), // 其它天
        )
        val summary = FtReviewModel.daySummary(sessions, 2, now, WeekStart.MONDAY)
        assertEquals(2, summary.day)
        assertTrue(summary.hasSession)
        assertEquals(15, summary.durationMinutes) // (600+300)/60
        assertEquals(1, summary.exerciseCount) // 两场同 exerciseId "e" → 去重
        assertEquals(3, summary.setCount) // 2 + 1 组
        assertEquals(290.0, summary.volumeKg, 1e-6) // (50*2 + 30*3) + 100*1
    }

    @Test
    fun `当天摘要无训练返回空态`() {
        val summary = FtReviewModel.daySummary(emptyList(), 9, day(2026, 6, 10), WeekStart.MONDAY)
        assertEquals(9, summary.day)
        assertTrue(!summary.hasSession)
        assertEquals(0, summary.durationMinutes)
        assertEquals(0, summary.exerciseCount)
        assertEquals(0, summary.setCount)
        assertEquals(0.0, summary.volumeKg, 1e-6)
    }

    @Test
    fun `当天摘要排除热身组且按 exerciseId 去重`() {
        val now = day(2026, 6, 10)
        val warmup = WorkoutSession(
            sessionId = "s-w",
            planId = "p",
            dayId = "d",
            startedAt = day(2026, 6, 3),
            endedAt = day(2026, 6, 3) + 300_000L,
            durationSeconds = 300,
            totalSets = 2,
            totalVolume = 0.0,
            fatigueScore = 0.0,
            notes = "",
            sets = listOf(
                WorkoutSet(setId = "w1", exerciseId = "warm", weight = 20.0, reps = 10, rpe = 5.0, isWarmup = true),
                WorkoutSet(setId = "w2", exerciseId = "a", weight = 40.0, reps = 5, rpe = 8.0, isWarmup = false),
                WorkoutSet(setId = "w3", exerciseId = "b", weight = 40.0, reps = 5, rpe = 8.0, isWarmup = false),
            ),
        )
        val summary = FtReviewModel.daySummary(listOf(warmup), 3, now, WeekStart.MONDAY)
        assertTrue(summary.hasSession)
        assertEquals(2, summary.setCount) // 排除热身
        assertEquals(3, summary.exerciseCount) // warmup/"a"/"b" 三个动作（热身也算做过该动作，双端口径一致）
        assertEquals(400.0, summary.volumeKg, 1e-6) // 40*5 + 40*5
    }

    @Test
    fun `月历图例五档取到与主格同源的五个颜色`() {
        val levels = (0..4).map { FtReviewColors.monthLegendSwatch(it) }
        assertEquals(5, levels.toSet().size) // 五档可辨（不再全同色）
        // 高/大两档须与主格同源
        assertEquals(FtReviewColors.mcalFill(1), levels[1])
        assertEquals(FtReviewColors.mcalFill(4), levels[4])
    }

    @Test
    fun `月历前置空位对齐当月首日周几`() {
        val now = day(2026, 7, 15)
        val cells = FtReviewModel.monthGrid(emptyList(), now, WeekStart.MONDAY)
        // 2026-07-01 是周三 → 2 个前置空位；31 天 + 2 = 33，补到 35
        assertEquals(35, cells.size)
        assertEquals(2, cells.take(2).count { it.day == 0 })
        assertEquals(1, cells[2].day)
        assertEquals(31, cells.count { it.day > 0 })
        assertEquals(15, cells.first { it.today }.day)
    }

    @Test
    fun `月历标题与 meta 按当月聚合`() {
        val now = day(2026, 6, 10)
        assertEquals(MonthLabel(2026, 6), FtReviewModel.monthLabel(now))
        val sessions = listOf(
            session(day(2026, 6, 2), durationSeconds = 600),
            session(day(2026, 6, 2), durationSeconds = 300), // 同日第二场
            session(day(2026, 6, 5), durationSeconds = 1200),
            session(day(2026, 7, 1), durationSeconds = 999), // 下月 · 排除
        )
        // 当月训练 2 天（2 号、5 号）；总时长 2100s → 35 分钟
        assertEquals(MonthMeta(2, 35), FtReviewModel.monthMeta(sessions, now))
    }

    @Test
    fun `体重曲线点集按 min max 归一`() {
        val points = FtReviewModel.weightPoints(listOf(70f, 72f, 71f))
        assertEquals(3, points.size)
        // x 在 12..330 均分
        assertEquals(12f, points[0].first, 1e-3f)
        assertEquals(171f, points[1].first, 1e-3f)
        assertEquals(330f, points[2].first, 1e-3f)
        // y：min(70)→下沿 100，max(72)→上沿 16，中值 71→58
        assertEquals(100f, points[0].second, 1e-3f)
        assertEquals(16f, points[1].second, 1e-3f)
        assertEquals(58f, points[2].second, 1e-3f)
    }

    @Test
    fun `体重曲线全等值取中线且空集为空`() {
        val points = FtReviewModel.weightPoints(listOf(70f, 70f, 70f))
        assertTrue(points.all { it.second == 58f })
        assertTrue(FtReviewModel.weightPoints(emptyList()).isEmpty())
    }

    @Test
    fun `体重数值文案格式`() {
        assertEquals("69.2 kg", FtReviewModel.weightCurrentText(69.2, WeightUnit.KG))
        assertEquals("152.6 lbs", FtReviewModel.weightCurrentText(69.2, WeightUnit.LBS))
        assertEquals("-0.8", FtReviewModel.weightDeltaValue(-0.8, WeightUnit.KG))
        assertEquals("1.6", FtReviewModel.weightDeltaValue(1.6, WeightUnit.KG))
        assertEquals("1.8", FtReviewModel.weightDeltaValue(0.8, WeightUnit.LBS))
    }

    // ── 周开始日两态（A5 / Wave 2 · 周首周一 vs 周日） ─────────────

    @Test
    fun `周柱图周首切周日时标签序与分桶联动`() {
        val now = day(2026, 6, 10) // 周三（2026-06-01 为周一）
        val sessions = listOf(
            session(day(2026, 6, 7), volumeSets = listOf(50.0 to 2)), // 本周日（周首）· 100
            session(day(2026, 6, 10), volumeSets = listOf(100.0 to 2)), // 周三 · 200（当周最大）
            session(day(2026, 6, 14), volumeSets = listOf(999.0 to 1)), // 下周日 · 出周窗口
        )
        val bars = FtReviewModel.weeklyBars(sessions, now, WeekStart.SUNDAY)
        assertEquals(listOf("日", "一", "二", "三", "四", "五", "六"), bars.map { it.label })
        assertEquals(listOf(true, false, false, true, false, false, false), bars.map { it.on })
        assertEquals(FtReviewModel.WEEK_BAR_MAX_H, bars[3].height, 1e-3f)
        assertEquals(
            FtReviewModel.WEEK_BAR_MIN_H + (FtReviewModel.WEEK_BAR_MAX_H - FtReviewModel.WEEK_BAR_MIN_H) / 2f,
            bars[0].height,
            1e-3f,
        )
    }

    @Test
    fun `月历前置空位随周首切周日`() {
        val now = day(2026, 6, 10)
        val cells = FtReviewModel.monthGrid(emptyList(), now, WeekStart.SUNDAY)
        // 2026-06-01 是周一 → 周日首模式下前置 1 格；30 天 + 1 = 31，补到 35
        assertEquals(35, cells.size)
        assertEquals(1, cells.take(1).count { it.day == 0 })
        assertEquals(1, cells[1].day)
        assertEquals(30, cells.count { it.day > 0 })
    }

    // ── 真实派生（Wave 2）：肌群训练量与努力程度 ─────────────────────

    @Test
    fun `肌群训练量_无数据全零`() {
        val volume = FtReviewModel.muscleVolume(emptyList(), { emptyList() }, 8)
        assertEquals(18, volume.size)
        assertEquals(0, volume.sum())
    }

    @Test
    fun `肌群训练量_按组数聚合到身体部位`() {
        // 2 条 set 且主肌群为胸 → chest / serratus 各 +2（每条 set 计 1）。
        val session = sessionWith(1000L, listOf("ex_a", "ex_b"))
        val volume = FtReviewModel.muscleVolume(listOf(session), { listOf("muscle_chest") }, 8)
        assertEquals(2, volume[FtReviewModel.MUSCLE_IDS.indexOf("chest")])
        assertEquals(2, volume[FtReviewModel.MUSCLE_IDS.indexOf("serratus")])
    }

    @Test
    fun `肌群级别_归一四级且无数据全零`() {
        assertEquals(List(18) { 0 }, FtReviewModel.muscleLevels(List(18) { 0 }))

        val volume = MutableList(18) { 0 }
        volume[0] = 100
        volume[1] = 10
        val levels = FtReviewModel.muscleLevels(volume)
        assertEquals(4, levels[0]) // 最大值 → 4
        assertEquals(1, levels[1]) // ≤25% → 1
        assertEquals(0, levels[2]) // 无训练量 → 0
    }

    @Test
    fun `努力程度_取已评价场次并跳过未评价`() {
        val unreviewed = sessionWith(1000L, listOf("ex_a"), rpe = 0)
        val reviewed = sessionWith(2000L, listOf("ex_a"), rpe = 8)
        assertEquals(listOf(8), FtReviewModel.effortLevels(listOf(unreviewed, reviewed), 8))
        assertEquals(emptyList<Int>(), FtReviewModel.effortLevels(listOf(unreviewed), 8))
    }

    @Test
    fun `肌群结论返回最高与最低部位索引`() {
        val volume = MutableList(18) { 0 }
        volume[2] = 50
        volume[5] = 5
        assertEquals(MuscleSummary(2, 5), FtReviewModel.muscleSummary(volume))
        // 只有一处有训练量：最高即最低，UI 层用 minIndex == maxIndex 判定成「单一部位」文案
        val single = MutableList(18) { 0 }
        single[2] = 12
        assertEquals(MuscleSummary(2, 2), FtReviewModel.muscleSummary(single))
        // 无训练量：maxIndex = -1，hasData = false（UI 走空态文案）
        val empty = FtReviewModel.muscleSummary(List(18) { 0 })
        assertEquals(MuscleSummary(-1, -1), empty)
        assertTrue(!empty.hasData)
    }

    @Test
    fun `肌群级别_全部相同训练量时同为四级`() {
        // 等级是相对量（相对最大值的分档），全相同 → 全 4；注释不得再声称「取中位 2」
        assertEquals(List(18) { 4 }, FtReviewModel.muscleLevels(List(18) { 2 }))
    }

    @Test
    fun `肌群详情_空等级表与空训练量回落 0`() {
        assertEquals(
            MuscleDetail(R.string.review_muscle_detail_sets, 0),
            FtReviewModel.muscleDetail(emptyList(), emptyList(), MuscleMode.BALANCE, "chest"),
        )
    }

    // ── 真实努力程度派生 effortFrom（未提交增量） ─────────────────

    @Test
    fun `effortFrom_空序列返回null`() {
        assertNull(FtReviewModel.effortFrom(EffortMetric.RIR, emptyList()))
        assertNull(FtReviewModel.effortFrom(EffortMetric.RPE, emptyList()))
    }

    /** RIR_DATA 的 RPE 镜像即完成页可采集到的真实 RPE；此路径应与样例视图逐字段一致。 */
    @Test
    fun `effortFrom_RIR口径等于样例视图当输入为RPE镜像`() {
        val mirrored = FtReviewModel.RIR_DATA.map { 10 - it }
        val real = FtReviewModel.effortFrom(EffortMetric.RIR, mirrored)
        val sample = FtReviewModel.effort(EffortMetric.RIR)
        assertEquals(sample.average, real?.average) // "2.3"
        assertEquals(sample.barPercents, real?.barPercents) // [50,75,25,50,100,25,75,50]
        assertEquals(sample.barLabels, real?.barLabels)
    }

    @Test
    fun `effortFrom_RPE直通且均值柱高按原型公式`() {
        val view = FtReviewModel.effortFrom(EffortMetric.RPE, listOf(8, 7, 9, 8, 6, 9, 7, 8))
        assertEquals("7.8", view?.average)
        assertEquals(listOf(50, 25, 75, 50, 8, 75, 25, 50), view?.barPercents)
    }

    /**
     * H1 探针：RIR 口径下低 RPE 输入的柱高上界。
     *
     * RPE=3 → `vals = 10 − 3 = 7`，`min=0 / max=4` 下 `percent = 7 × 100 / 4 = 175%`。
     * 柱高换算 `175 × 78 / 100 = 136.5` 超出 78 的轨道——`EFFORT_MIN_BAR_PERCENT` 只夹下限。
     * 本断言写期望语义（≤100）：红即实证缺陷，绿即证伪。
     */
    @Test
    fun `effortFrom_RIR口径下低RPE输入的柱高上界`() {
        val view = FtReviewModel.effortFrom(EffortMetric.RIR, listOf(3))
        val maxPercent = view?.barPercents?.max() ?: 0
        assertTrue("柱高百分比须 ≤ 100，实际 $maxPercent（rpe=3）", maxPercent <= 100)
    }

    @Test
    fun `EMPTY_VALUE_为仓内约定占位`() {
        assertEquals("--", FtReviewModel.EMPTY_VALUE)
    }

    /** 构造含若干 set 的会话（每个 exerciseId 一条 set）。 */
    private fun sessionWith(startedAt: Long, exerciseIds: List<String>, rpe: Int = 8): WorkoutSession {
        val sets = exerciseIds.mapIndexed { index, exerciseId ->
            WorkoutSet(
                setId = "set_$index",
                exerciseId = exerciseId,
                weight = 80.0,
                reps = 8,
                rpe = rpe.toDouble(),
                isWarmup = false,
            )
        }
        return WorkoutSession(
            sessionId = "session_$startedAt",
            planId = "plan_1",
            dayId = "day_1",
            startedAt = startedAt,
            endedAt = startedAt + 1800000L,
            durationSeconds = 1800,
            totalSets = sets.size,
            totalVolume = 640.0,
            fatigueScore = 3.0,
            sessionRpe = rpe,
            notes = "completed_sets=${sets.size};target_sets=${sets.size}",
            sets = sets,
        )
    }

    // ── 真数据收口：目标线 / 月度汇总 / 概览徽标 ─────────────────

    @Test
    fun `目标线未设置目标时不画线`() {
        // 0 = 用户从未设置过目标——原实现会按固定公式算出 y=89，画出一条「有目标」的假线。
        assertEquals(-1f, FtReviewModel.goalLineY(0.0, 60.0, 70.0), 1e-3f)
    }

    @Test
    fun `目标线目标落在折线量程外时不画线`() {
        // 贴着边界的线会被读成「已达成 / 已达上限」，比不画更容易误导。
        assertEquals(-1f, FtReviewModel.goalLineY(80.0, 60.0, 70.0), 1e-3f)
        assertEquals(-1f, FtReviewModel.goalLineY(50.0, 60.0, 70.0), 1e-3f)
    }

    @Test
    fun `目标线量程退化时不画线`() {
        // 0 或 1 个体重点：量程上下界相同，无法定位。
        assertEquals(-1f, FtReviewModel.goalLineY(65.0, 65.0, 65.0), 1e-3f)
    }

    @Test
    fun `月度汇总无本月会话返回空`() {
        val now = day(2026, 6, 10)
        val previousMonth = session(day(2026, 5, 10), durationSeconds = 1800, volumeSets = listOf(40.0 to 10))
        assertNull(FtReviewModel.monthlyStats(listOf(previousMonth), now))
        assertNull(FtReviewModel.monthlyStats(emptyList(), now))
    }

    @Test
    fun `月度汇总只累计本月会话且跳过热身组`() {
        val now = day(2026, 6, 20)
        val inMonth = session(day(2026, 6, 3), durationSeconds = 1200, volumeSets = listOf(40.0 to 10))
        val otherMonth = session(day(2026, 5, 28), durationSeconds = 3600, volumeSets = listOf(50.0 to 5))
        val stats = FtReviewModel.monthlyStats(listOf(inMonth, otherMonth), now)
        assertNotNull(stats)
        assertEquals(1, stats!!.count) // 只有本月那次
        assertEquals(1200, stats.duration)
        assertEquals(1, stats.sets)
        assertEquals(400.0, stats.volume, 1e-6)
    }

    @Test
    fun `概览徽标无会话时为待积累`() {
        assertEquals(FtReviewModel.BADGE_IDLE, FtReviewModel.badgeText(emptyList(), day(2026, 6, 10), WeekStart.MONDAY))
    }

    @Test
    fun `概览徽标本周有训练但上周无基线时为首次回顾`() {
        val now = day(2026, 6, 10) // 周三
        val thisWeek = session(day(2026, 6, 8), durationSeconds = 1800, volumeSets = listOf(40.0 to 10))
        assertEquals(
            FtReviewModel.BADGE_FIRST,
            FtReviewModel.badgeText(listOf(thisWeek), now, WeekStart.MONDAY),
        )
    }
}

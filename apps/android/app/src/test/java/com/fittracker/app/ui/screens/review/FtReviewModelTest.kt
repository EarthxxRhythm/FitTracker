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
    fun `肌群排行_平衡模式按真实组数降序且同值保原序`() {
        val volume = MutableList(18) { 0 }
        volume[FtReviewModel.MUSCLE_IDS.indexOf("chest")] = 12
        volume[FtReviewModel.MUSCLE_IDS.indexOf("quadriceps")] = 20
        volume[FtReviewModel.MUSCLE_IDS.indexOf("gluteal")] = 20
        val levels = FtReviewModel.muscleLevels(volume)
        val ranking = FtReviewModel.muscleRanking(levels, volume, MuscleMode.BALANCE)
        // 20 组并列：gluteal 在 MUSCLE_IDS 里（索引 11）先于 quadriceps（12）→ 稳定排序保留原序
        assertEquals(listOf("gluteal", "quadriceps", "chest"), ranking.take(3))
        assertEquals(18, ranking.size)
    }

    @Test
    fun `肌群排行_疲劳与力量模式按等级降序`() {
        val volume = MutableList(18) { 0 }
        volume[FtReviewModel.MUSCLE_IDS.indexOf("chest")] = 4
        val levels = FtReviewModel.muscleLevels(volume)
        // 唯一非零部位拿到最高档 → 两个非 balance 模式都把它排第一
        assertEquals("chest", FtReviewModel.muscleRanking(levels, volume, MuscleMode.FATIGUE).first())
        assertEquals("chest", FtReviewModel.muscleRanking(levels, volume, MuscleMode.STRENGTH).first())
    }

    @Test
    fun `肌群排行_无训练量时退回 MUSCLE_IDS 原序`() {
        val zeros = List(18) { 0 }
        assertEquals(FtReviewModel.MUSCLE_IDS, FtReviewModel.muscleRanking(zeros, zeros, MuscleMode.BALANCE))
        assertEquals(FtReviewModel.MUSCLE_IDS, FtReviewModel.muscleRanking(zeros, zeros, MuscleMode.FATIGUE))
    }

    @Test
    fun `EMPTY_VALUE_为仓内约定占位`() {
        assertEquals("--", FtReviewModel.EMPTY_VALUE)
    }

    /** 本地时区日零点（与服务 `startOfDay` 同口径）。 */
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

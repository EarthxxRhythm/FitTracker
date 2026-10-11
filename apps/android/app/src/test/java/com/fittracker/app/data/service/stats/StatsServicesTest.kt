package com.fittracker.app.data.service.stats

import com.fittracker.app.data.model.ExerciseRef
import com.fittracker.app.data.model.PlanDay
import com.fittracker.app.data.model.PlannedExercise
import com.fittracker.app.data.model.TrainingDay
import com.fittracker.app.data.model.TrainingPlan
import com.fittracker.app.data.model.UserGoal
import com.fittracker.app.data.model.UserPlan
import com.fittracker.app.data.model.WorkoutSession
import com.fittracker.app.data.model.WorkoutSet
import com.fittracker.app.data.service.WeekStart
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 统计/复盘派生服务族契约测试（Wave 3）。
 *
 * 期望值来源：鸿蒙 `shared/services/` 下 `ReviewService.ets` /
 * `ReviewDashboardService.ets` / `StatsDashboardService.ets` /
 * `HomePlanService.ets` / `PersonalRecordService.ets`（行号见各断言注释）。
 *
 * 纯函数，无需 Robolectric；日期相关断言一律用「相对当前时刻」构造会话，避免时区差异。
 */
class StatsServicesTest {

    // ────────────────────────── 构造工具 ──────────────────────────

    private fun set(
        exerciseId: String,
        weight: Double,
        reps: Int,
        isWarmup: Boolean = false,
    ): WorkoutSet = WorkoutSet(
        setId = "set", exerciseId = exerciseId, weight = weight, reps = reps, rpe = 0.0, isWarmup = isWarmup,
    )

    private fun session(
        sessionId: String = "s",
        startedAt: Long = 0L,
        durationSeconds: Int = 0,
        notes: String = "",
        sets: List<WorkoutSet> = emptyList(),
        dayId: String = "day_1",
    ): WorkoutSession = WorkoutSession(
        sessionId = sessionId, planId = "plan", dayId = dayId,
        startedAt = startedAt, endedAt = startedAt, durationSeconds = durationSeconds,
        totalSets = 0, totalVolume = 0.0, fatigueScore = 0.0, notes = notes, sets = sets,
    )

    /** notes 内嵌 `target_sets=` / `completed_sets=` 前缀（`;` 分隔，源 `getNumberAfterPrefix`）。 */
    private fun noted(
        sessionId: String,
        completed: Int,
        target: Int,
        startedAt: Long = 0L,
        durationSeconds: Int = 0,
    ): WorkoutSession = session(
        sessionId = sessionId, startedAt = startedAt, durationSeconds = durationSeconds,
        notes = "target_sets=$target; completed_sets=$completed",
    )

    private fun goal(
        weeklyDays: Int,
        sessionMinutes: Int,
        goalType: String = "hypertrophy",
        level: String = "intermediate",
        equipment: List<String> = emptyList(),
        restricted: List<String> = emptyList(),
    ): UserGoal = UserGoal(
        goalId = "goal", goalType = goalType, level = level,
        weeklyDays = weeklyDays, sessionMinutes = sessionMinutes,
        equipmentIds = equipment, restrictedMuscleIds = restricted, createdAt = 0L, updatedAt = 0L,
    )

    private fun planned(exerciseId: String, sets: Int = 3, reps: String = "8-12", note: String = "强度中") =
        PlannedExercise(
            plannedExerciseId = "pe-$exerciseId", exerciseId = exerciseId, targetSets = sets,
            targetReps = reps, intensityNote = note, alternativeExerciseIds = emptyList(),
        )

    private fun planDay(
        id: String,
        title: String,
        focus: List<String> = emptyList(),
        exercises: List<PlannedExercise> = emptyList(),
    ) = PlanDay(dayId = id, dayOfWeek = 1, title = title, focusMuscleIds = focus, exercises = exercises)

    private fun trainingPlan(vararg days: PlanDay) =
        TrainingPlan(
            planId = "plan", goalId = "goal", name = "我的计划", cycleWeeks = 4,
            days = days.toList(), generatedBy = "rule_v1", status = "active",
        )

    @After
    fun resetSeams() {
        ReviewDashboardService.planGenerator = { goal ->
            TrainingPlan("", goal.goalId, "", 0, emptyList(), "rule_v1", "active")
        }
        HomePlanService.exerciseNameResolver = { null }
        HomePlanService.equipmentNameResolver = { it }
        HomePlanService.muscleNameResolver = { it }
        PersonalRecordService.exerciseNameResolver = { null }
    }

    // ═══════════════════════ 1. ReviewService ═══════════════════════

    @Test
    fun `训练量仅累计非热身组`() {
        // 源 ReviewService.ets:9 calculateVolume
        val sets = listOf(
            set("bench", 60.0, 10, isWarmup = true), // 热身，排除
            set("bench", 100.0, 5), // 500
            set("bench", 62.5, 10), // 625
        )
        assertEquals(1125.0, ReviewService.calculateVolume(sets), 1e-9)
        assertEquals(0.0, ReviewService.calculateVolume(emptyList()), 1e-9)
        assertEquals(
            0.0,
            ReviewService.calculateVolume(listOf(set("bench", 100.0, 5, isWarmup = true))),
            1e-9,
        )
    }

    @Test
    fun `最佳1RM取非热身组最大且保留两位小数`() {
        // 源 ReviewService.ets:20 calculateBestEstimatedOneRepMax（复用 estimateOneRepMax 两位小数口径）
        val sets = listOf(
            set("bench", 200.0, 1, isWarmup = true), // 热身，排除
            set("bench", 100.0, 5), // 116.67
            set("bench", 60.0, 1), // 62.0
        )
        assertEquals(116.67, ReviewService.calculateBestEstimatedOneRepMax(sets), 1e-9)
        assertEquals(0.0, ReviewService.calculateBestEstimatedOneRepMax(emptyList()), 1e-9)
    }

    @Test
    fun `完成率取整到 0 到 100`() {
        // 源 ReviewService.ets:34 calculateCompletionRate（Math.round → 四舍五入）
        assertEquals(0, ReviewService.calculateCompletionRate(5, 0)) // planned <= 0 归零
        assertEquals(0, ReviewService.calculateCompletionRate(0, 10))
        assertEquals(69, ReviewService.calculateCompletionRate(69, 100))
        assertEquals(70, ReviewService.calculateCompletionRate(70, 100))
        assertEquals(94, ReviewService.calculateCompletionRate(94, 100))
        assertEquals(95, ReviewService.calculateCompletionRate(95, 100))
        assertEquals(100, ReviewService.calculateCompletionRate(100, 100))
        assertEquals(33, ReviewService.calculateCompletionRate(1, 3)) // 33.33 → 33
        assertEquals(67, ReviewService.calculateCompletionRate(2, 3)) // 66.67 → 67
    }

    // ════════════════ 2. ReviewDashboardService ════════════════

    @Test
    fun `完成率阈值 69 触发 reduce_load`() {
        // 源 ReviewDashboardService.ets:407 getAdjustmentHint
        val summary = ReviewDashboardService.createSummary(listOf(noted("s1", 69, 100)))
        assertEquals(69, summary.averageCompletionRate)
        assertEquals("reduce_load", summary.adjustmentHint)
        assertEquals("完成率偏低，下次建议减少训练天数或缩短单次时长。", summary.adjustmentText)
    }

    @Test
    fun `完成率阈值 70 保持 keep_plan`() {
        val summary = ReviewDashboardService.createSummary(listOf(noted("s1", 70, 100)))
        assertEquals(70, summary.averageCompletionRate)
        assertEquals("keep_plan", summary.adjustmentHint)
        assertEquals("完成率稳定，下次保持当前计划即可。", summary.adjustmentText)
    }

    @Test
    fun `完成率阈值 94 保持 keep_plan`() {
        val summary = ReviewDashboardService.createSummary(listOf(noted("s1", 94, 100)))
        assertEquals(94, summary.averageCompletionRate)
        assertEquals("keep_plan", summary.adjustmentHint)
    }

    @Test
    fun `完成率阈值 95 触发 increase_load`() {
        val summary = ReviewDashboardService.createSummary(listOf(noted("s1", 95, 100)))
        assertEquals(95, summary.averageCompletionRate)
        assertEquals("increase_load", summary.adjustmentHint)
        assertEquals("完成率很高，下次可以增加训练天数或延长单次时长。", summary.adjustmentText)
    }

    @Test
    fun `空会话返回空摘要`() {
        // 源 ReviewDashboardService.ets:116 createEmptySummary
        val summary = ReviewDashboardService.createSummary(emptyList())
        assertFalse(summary.hasSessions)
        assertEquals(0, summary.sessionCount)
        assertEquals("start_training", summary.adjustmentHint)
        assertEquals("先完成一次训练，再根据完成率调整下次计划。", summary.adjustmentText)
        assertEquals("0 分钟", summary.totalDurationText)
        assertTrue(summary.recentRecords.isEmpty())
        assertFalse(summary.trendSummary.hasTrend)
    }

    @Test
    fun `notes前缀解析 completed 与 target`() {
        // 源 getNumberAfterPrefix :387，`;` 分界
        val summary = ReviewDashboardService.createSummary(listOf(noted("s1", 10, 12)))
        assertEquals(10, summary.totalCompletedSets)
        assertEquals(12, summary.totalTargetSets)
        assertEquals(83, summary.averageCompletionRate) // 10/12 = 83.33 → 83
    }

    @Test
    fun `notes无分号时 target 回落到完成数`() {
        // 源以 ';' 为值域终点；无 ';' 时值域延到串尾，Number 解析失败回落（源 fallback = completed）
        val s = session(
            sessionId = "s1",
            notes = "target_sets=50 completed_sets=12",
        )
        val summary = ReviewDashboardService.createSummary(listOf(s))
        assertEquals(12, summary.totalCompletedSets)
        assertEquals(12, summary.totalTargetSets)
    }

    @Test
    fun `notes缺前缀时计数归零`() {
        val summary = ReviewDashboardService.createSummary(listOf(session(sessionId = "s1", notes = "no-prefix")))
        assertEquals(0, summary.totalCompletedSets)
        assertEquals(0, summary.totalTargetSets)
        assertEquals(0, summary.averageCompletionRate)
    }

    @Test
    fun `有sets时完成数按组统计且 target 仍取 notes`() {
        // 源 getCompletedSets :366（sets 有值走 countCompletedSets）/ getTargetSets :373
        val s = session(
            sessionId = "s1",
            notes = "target_sets=3",
            sets = listOf(
                set("bench", 100.0, 5),
                set("bench", 60.0, 10, isWarmup = true), // 热身排除
                set("bench", 80.0, 8),
            ),
        )
        val summary = ReviewDashboardService.createSummary(listOf(s))
        assertEquals(2, summary.totalCompletedSets)
        assertEquals(3, summary.totalTargetSets)
    }

    @Test
    fun `最近记录上限为 5 且最新在前`() {
        // 源 recentRecordLimit = 5（:76）、createRecentRecords :136
        val sessions = (1..6).map { noted("s$it", 10, 10, startedAt = it.toLong()) }
        val summary = ReviewDashboardService.createSummary(sessions)
        assertEquals(5, summary.recentRecords.size)
        assertEquals("s6", summary.recentRecords.first().sessionId)
        assertEquals("s2", summary.recentRecords.last().sessionId)
        assertEquals("10/10 组 · 100%", summary.recentRecords.first().completionText)
    }

    @Test
    fun `少于两次训练无趋势`() {
        // 源 createTrendSummary :181（sessions.length < 2）
        val summary = ReviewDashboardService.createSummary(listOf(noted("s1", 10, 10)))
        assertFalse(summary.trendSummary.hasTrend)
        assertEquals("至少保存两次训练后，可以查看历史趋势。", summary.trendSummary.summaryText)
    }

    @Test
    fun `趋势窗口为最近两次对比更早`() {
        // 源 trendWindowSize = 2，recentStartIndex = max(len-2, 1)
        val sessions = listOf(
            noted("s1", 5, 10, startedAt = 1), // 更早
            noted("s2", 10, 10, startedAt = 2), // 最近
            noted("s3", 10, 10, startedAt = 3), // 最近
        )
        val trend = ReviewDashboardService.createSummary(sessions).trendSummary
        assertTrue(trend.hasTrend)
        assertEquals(2, trend.recentSessionCount)
        assertEquals(1, trend.previousSessionCount)
        assertEquals(100, trend.recentCompletionRate)
        assertEquals(50, trend.previousCompletionRate)
        assertEquals("完成率上升 50%", trend.completionTrendText)
        assertEquals("训练量持平", trend.volumeTrendText)
        assertEquals("最近 2 次完成率提高，训练量可以稳步推进。", trend.summaryText)
    }

    @Test
    fun `恰好两次训练进入趋势且窗口各一次`() {
        val sessions = listOf(noted("s1", 5, 10, startedAt = 1), noted("s2", 10, 10, startedAt = 2))
        val trend = ReviewDashboardService.createSummary(sessions).trendSummary
        assertTrue(trend.hasTrend)
        assertEquals(1, trend.recentSessionCount)
        assertEquals(1, trend.previousSessionCount)
    }

    @Test
    fun `reduce_load 下调天数与时长`() {
        // 源 createGoalAdjustmentAction :248，adjustWeeklyDays :426 / adjustSessionMinutes :436
        val summary = ReviewDashboardService.createSummary(listOf(noted("s1", 69, 100)))
        val action = ReviewDashboardService.createGoalAdjustmentAction(summary, goal(weeklyDays = 4, sessionMinutes = 60))
        assertEquals("reduce_load", action.actionType)
        assertEquals("降低下次训练压力", action.title)
        assertEquals(3, action.targetWeeklyDays)
        assertEquals(45, action.targetSessionMinutes)
        assertTrue(action.canApply)
        assertEquals("应用调整并重新生成计划", action.buttonText)
        assertEquals("每周训练由 4 天调整为 3 天，单次时长由 60 分钟调整为 45 分钟。", action.description)
    }

    @Test
    fun `keep_plan 无变化不可应用`() {
        val summary = ReviewDashboardService.createSummary(listOf(noted("s1", 70, 100)))
        val action = ReviewDashboardService.createGoalAdjustmentAction(summary, goal(4, 60))
        assertEquals("keep_plan", action.actionType)
        assertEquals("保持当前目标", action.title)
        assertEquals(4, action.targetWeeklyDays)
        assertEquals(60, action.targetSessionMinutes)
        assertFalse(action.canApply)
        assertEquals("无需重新生成", action.buttonText)
        assertEquals("当前完成率稳定，本次不需要改动目标。", action.description)
    }

    @Test
    fun `increase_load 上调并受上下限夹取`() {
        // 天数上限 7、时长上限 90
        val summary = ReviewDashboardService.createSummary(listOf(noted("s1", 95, 100)))
        val action = ReviewDashboardService.createGoalAdjustmentAction(summary, goal(weeklyDays = 7, sessionMinutes = 90))
        assertEquals("increase_load", action.actionType)
        assertEquals("提高下次训练目标", action.title)
        assertEquals(7, action.targetWeeklyDays) // 8 → 夹到 7
        assertEquals(90, action.targetSessionMinutes) // 105 → 夹到 90
        assertFalse(action.canApply)
    }

    @Test
    fun `空调整动作`() {
        val action = ReviewDashboardService.createEmptyGoalAdjustmentAction()
        assertEquals("start_training", action.actionType)
        assertEquals("完成训练后再调整", action.title)
        assertFalse(action.canApply)
        assertEquals("暂无可应用调整", action.buttonText)
    }

    @Test
    fun `计划重生成使用注入的发生器并统计天数`() {
        // 源 createPlanRegenerationResult :284；PlanEngine 以插槽注入
        ReviewDashboardService.planGenerator = { adjusted ->
            TrainingPlan(
                planId = "regen", goalId = adjusted.goalId, name = "regenerated", cycleWeeks = 4,
                days = List(3) { planDay("d$it", "t$it") }, generatedBy = "rule_v1", status = "active",
            )
        }
        val summary = ReviewDashboardService.createSummary(listOf(noted("s1", 95, 100)))
        val action = ReviewDashboardService.createGoalAdjustmentAction(summary, goal(4, 60))
        val result = ReviewDashboardService.createPlanRegenerationResult(goal(4, 60), action, now = 1_000L)
        assertEquals(5, result.adjustedGoal.weeklyDays)
        assertEquals(75, result.adjustedGoal.sessionMinutes)
        assertEquals(1_000L, result.adjustedGoal.updatedAt)
        assertEquals(3, result.regeneratedPlan.days.size)
        assertEquals("已保存调整并重新生成 3 天计划", result.statusText)
    }

    @Test
    fun `最新训练日标签规范化`() {
        // 内联自 TrainingDayLabelService.formatCompact
        val summary = ReviewDashboardService.createSummary(
            listOf(session(sessionId = "s1", notes = "completed_sets=5", dayId = "day_3")),
        )
        assertEquals("第 3 天", summary.latestDayLabel)
    }

    // ════════════════ 3. StatsDashboardService ════════════════

    @Test
    fun `空摘要含 42 天与 6 行热力格`() {
        // 源 createHeatmapDays :107（42 格）/ createHeatmapRows :147（6 行）
        val now = System.currentTimeMillis()
        val summary = StatsDashboardService.createEmptySummary(now, WeekStart.MONDAY)
        assertEquals(42, summary.heatmapDays.size)
        assertEquals(6, summary.heatmapRows.size)
        assertTrue(summary.heatmapRows.all { it.days.size == 7 })
        assertEquals("week_0", summary.heatmapRows.first().rowId)
        assertEquals("week_5", summary.heatmapRows.last().rowId)
        assertEquals(0, summary.weeklyStats.sessionCount)
        assertEquals("0 分钟", summary.weeklyStats.totalDurationText)
        assertTrue(summary.monthTitle.endsWith(" 月"))
        assertTrue(summary.monthTitle.contains(" 年 "))
    }

    @Test
    fun `周统计聚合本周会话并排除窗口外`() {
        // 源 createWeeklyStats :68（窗口 = [本周一 00:00, 下周一 00:00)）
        val now = System.currentTimeMillis()
        val inWeek = session(
            sessionId = "in", startedAt = now, durationSeconds = 1800,
            sets = listOf(set("bench", 100.0, 5)), // volume 500, completed 1
        )
        val outOfWeek = session(
            sessionId = "out", startedAt = now + 90L * 24 * 3600 * 1000, durationSeconds = 9999,
            sets = listOf(set("bench", 200.0, 10)),
        )
        val stats = StatsDashboardService.createSummary(listOf(inWeek, outOfWeek), now, WeekStart.MONDAY).weeklyStats
        assertEquals(1, stats.sessionCount)
        assertEquals(1800, stats.totalDurationSeconds)
        assertEquals(1, stats.totalSets)
        assertEquals(500.0, stats.totalVolume, 1e-9)
        assertEquals("30 分钟", stats.totalDurationText)
    }

    @Test
    fun `热力等级按训练量分档`() {
        // 源 createHeatmapLevel :174（0/≤500/≤1000/≤1500/else）
        val now = System.currentTimeMillis()
        fun levelFor(weight: Double): Int {
            val s = session(
                sessionId = "s", startedAt = now, durationSeconds = 600,
                sets = listOf(set("bench", weight, 1)), // volume = weight
            )
            return StatsDashboardService.createSummary(listOf(s), now, WeekStart.MONDAY)
                .heatmapDays.first { it.sessionCount == 1 }.level
        }
        assertEquals(1, levelFor(500.0))
        assertEquals(2, levelFor(1000.0))
        assertEquals(3, levelFor(1500.0))
        assertEquals(4, levelFor(1500.5))
    }

    @Test
    fun `热力格可访问文案`() {
        val now = System.currentTimeMillis()
        val s = session(
            sessionId = "s", startedAt = now, durationSeconds = 600,
            sets = listOf(set("bench", 120.0, 10)), // 1200 → level 3
        )
        val summary = StatsDashboardService.createSummary(listOf(s), now, WeekStart.MONDAY)
        val day = summary.heatmapDays.first { it.sessionCount == 1 }
        assertEquals(1200.0, day.totalVolume, 1e-9)
        assertEquals(3, day.level)
        assertEquals("${day.dateText} 1 次训练 1200 kg", day.accessibilityText)
        // 空白日：无训练
        val emptyDay = summary.heatmapDays.first { it.sessionCount == 0 }
        assertEquals("${emptyDay.dateText} 无训练", emptyDay.accessibilityText)
        assertEquals(0, emptyDay.level)
    }

    @Test
    fun `findHeatmapDay 命中与未命中`() {
        // 源 findHeatmapDay :58
        val now = System.currentTimeMillis()
        val summary = StatsDashboardService.createSummary(emptyList(), now, WeekStart.MONDAY)
        val target = summary.heatmapDays[10]
        assertEquals(target, StatsDashboardService.findHeatmapDay(summary.heatmapDays, target.dateText))
        assertNull(StatsDashboardService.findHeatmapDay(summary.heatmapDays, "1900-01-01"))
    }

    @Test
    fun `周统计窗口随周首切周日`() {
        // weekStart=SUNDAY → 窗口 = [当周周日 00:00, 下个周日 00:00)
        val nowCal = java.util.Calendar.getInstance()
        nowCal.clear()
        nowCal.set(2026, 5, 10) // 2026-06-10 周三
        val now = nowCal.timeInMillis
        val sundayCal = java.util.Calendar.getInstance()
        sundayCal.clear()
        sundayCal.set(2026, 5, 7) // 2026-06-07 周日（周日首模式下为当周首）
        val s = session(
            sessionId = "sun", startedAt = sundayCal.timeInMillis, durationSeconds = 600,
            sets = listOf(set("bench", 100.0, 1)),
        )
        // 周一首模式：2026-06-07 属上一周 → 窗口外；周日首模式：属当周 → 窗口内
        assertEquals(
            0,
            StatsDashboardService.createSummary(listOf(s), now, WeekStart.MONDAY).weeklyStats.sessionCount,
        )
        assertEquals(
            1,
            StatsDashboardService.createSummary(listOf(s), now, WeekStart.SUNDAY).weeklyStats.sessionCount,
        )
    }

    // ════════════════════ 4. HomePlanService ════════════════════

    @Test
    fun `pickTodayDay 取模与边界`() {
        // 源 HomePlanService.ets:204 pickTodayDay
        val plan = trainingPlan(planDay("day_1", "一"), planDay("day_2", "二"), planDay("day_3", "三"))
        assertEquals("day_1", HomePlanService.pickTodayDay(plan, 1)!!.dayId)
        assertEquals("day_3", HomePlanService.pickTodayDay(plan, 3)!!.dayId)
        assertEquals("day_1", HomePlanService.pickTodayDay(plan, 4)!!.dayId) // (4-1)%3=0
        assertEquals("day_1", HomePlanService.pickTodayDay(plan, 0)!!.dayId) // 归一为 1
        assertEquals("day_3", HomePlanService.pickTodayDay(plan, 6)!!.dayId) // (6-1)%3=2
        assertNull(HomePlanService.pickTodayDay(trainingPlan(), 1))
    }

    @Test
    fun `createSummary 命中今日训练`() {
        // 源 createSummary :65（today != undefined 分支）
        val plan = trainingPlan(
            planDay(
                "day_1", "推日", focus = listOf("胸", "三头"),
                exercises = listOf(planned("bench"), planned("fly")),
            ),
        )
        val summary = HomePlanService.createSummary(goal(4, 60), plan, 1)
        assertTrue(summary.hasTodayWorkout)
        assertEquals("我的计划", summary.planName)
        assertEquals("每周 4 天", summary.primaryMetaText)
        assertEquals("单次 60 分钟", summary.secondaryMetaText)
        assertEquals("day_1", summary.todayDayId)
        assertEquals("今天训练 | 推日", summary.todayLabel)
        assertEquals(2, summary.todayExerciseCount)
        assertEquals(2, summary.todayMuscleGroupCount)
        assertEquals(listOf("bench", "fly"), summary.todayExerciseNames) // 解析器默认回落 id
        assertEquals("开始训练", summary.startButtonText)
        assertEquals(HomePlanService.START_ROUTE_WORKOUT, summary.startRoute)
        assertEquals(1, summary.weeklyPlanDays.size)
        assertTrue(summary.weeklyPlanDays.first().isToday)
        assertEquals("目标 增肌 | 进阶 | 每周 4 天 | 单次 60 分钟", summary.goalSummary)
        assertEquals("器械 徒手", summary.equipmentSummary)
        assertEquals("避开 无", summary.restrictionSummary)
        val recommended = summary.recommendedExercises.first()
        assertEquals("bench", recommended.exerciseId)
        assertEquals("3 组 x 8-12", recommended.prescription)
        assertEquals("强度中", recommended.intensityNote)
    }

    @Test
    fun `createSummary 空计划走休息日`() {
        val summary = HomePlanService.createSummary(goal(3, 45), trainingPlan(), 1)
        assertFalse(summary.hasTodayWorkout)
        assertEquals("休息日", summary.todayTitle)
        assertEquals("今天是恢复日", summary.todayLabel)
        assertEquals("今天休息", summary.startButtonText)
        assertEquals("", summary.startRoute)
        assertEquals("每周 3 天", summary.primaryMetaText)
    }

    @Test
    fun `装备与避开名称走注入解析器`() {
        HomePlanService.equipmentNameResolver = { id -> if (id == "barbell") "杠铃" else id }
        HomePlanService.muscleNameResolver = { id -> if (id == "chest") "胸" else id }
        val plan = trainingPlan(planDay("day_1", "一"))
        val summary = HomePlanService.createSummary(
            goal(4, 60, equipment = listOf("barbell", "dumbbell"), restricted = listOf("chest")),
            plan, 1,
        )
        assertEquals("器械 杠铃、dumbbell", summary.equipmentSummary)
        assertEquals("避开 胸", summary.restrictionSummary)
    }

    @Test
    fun `动作名走注入解析器未命中回落 id`() {
        HomePlanService.exerciseNameResolver = { id -> if (id == "bench") "杠铃卧推" else null }
        val plan = trainingPlan(
            planDay("day_1", "一", exercises = listOf(planned("bench"), planned("fly"))),
        )
        val summary = HomePlanService.createSummary(goal(4, 60), plan, 1)
        assertEquals(listOf("杠铃卧推", "fly"), summary.todayExerciseNames)
        assertEquals("杠铃卧推", summary.recommendedExercises.first().name)
    }

    @Test
    fun `createWeeklyPlanDays 标记今日`() {
        // 源 createWeeklyPlanDays :287
        val days = listOf(planDay("day_1", "一", exercises = listOf(planned("a"))), planDay("day_2", "二"))
        val rows = HomePlanService.createWeeklyPlanDays(days, "day_2")
        assertEquals(2, rows.size)
        assertFalse(rows[0].isToday)
        assertTrue(rows[1].isToday)
        assertEquals(1, rows[0].exerciseCount)
        assertEquals("一", rows[0].title)
    }

    @Test
    fun `createSummaryFromCurrentPlan 训练日`() {
        // 源 createSummaryFromCurrentPlan :128（todayTraining != null 分支）
        val plan = UserPlan(
            id = "my", name = "我的", coverColor = "#000", targetAudience = "初中级",
            weeklyFrequency = "4 天/周", description = "",
            days = listOf(
                TrainingDay("上肢A", listOf(ExerciseRef("卧推", "胸", 4, "8-12")), null),
                TrainingDay("下肢", listOf(ExerciseRef("深蹲", "腿", 4, "8-12")), null),
            ),
            enabledAt = 0L,
        )
        val summary = HomePlanService.createSummaryFromCurrentPlan(plan, "今天", plan.days[0], 60)
        assertTrue(summary.hasTodayWorkout)
        assertEquals("my", summary.planId)
        assertEquals(2, summary.weeklyDays)
        assertEquals("current_plan_day_1", summary.todayDayId)
        assertEquals("今天 | 上肢A", summary.todayLabel)
        assertEquals("4 天/周", summary.primaryMetaText)
        assertEquals("初中级", summary.secondaryMetaText)
        assertEquals("计划来源 预置训练计划", summary.equipmentSummary)
        assertEquals("适用人群 初中级", summary.restrictionSummary)
        assertEquals("训练流程接入中", summary.startButtonText)
        assertEquals(1, summary.todayMuscleGroupCount)
        assertEquals(listOf("卧推"), summary.todayExerciseNames)
        val recommended = summary.recommendedExercises.first()
        assertEquals("my_exercise_1", recommended.exerciseId)
        assertEquals("4 组 x 8-12", recommended.prescription)
        assertEquals("目标肌群 胸", recommended.intensityNote)
        assertEquals("current_plan_day_1", summary.weeklyPlanDays.first().dayId)
        assertTrue(summary.weeklyPlanDays.first().isToday)
    }

    @Test
    fun `createSummaryFromCurrentPlan 休息日`() {
        val plan = UserPlan(
            id = "my", name = "我的", coverColor = "#000", targetAudience = "初中级",
            weeklyFrequency = "4 天/周", description = "",
            days = listOf(TrainingDay("上肢A", emptyList(), null)), enabledAt = 0L,
        )
        val summary = HomePlanService.createSummaryFromCurrentPlan(plan, "今天", null, 45)
        assertFalse(summary.hasTodayWorkout)
        assertEquals("今天 | 休息日", summary.todayLabel)
        assertEquals("今天休息", summary.startButtonText)
        assertEquals("", summary.todayDayId)
        assertEquals("当前计划今天没有训练安排，保持恢复节奏就好。", summary.todayRestMessage)
    }

    @Test
    fun `countFocusMuscles 去重且忽略空`() {
        // 源 countFocusMuscles :240
        val refs = listOf(
            ExerciseRef("a", "胸", 1, "1"),
            ExerciseRef("b", "胸", 1, "1"),
            ExerciseRef("c", "腿", 1, "1"),
            ExerciseRef("d", "", 1, "1"), // 空肌群忽略
        )
        assertEquals(2, HomePlanService.countFocusMuscles(refs))
    }

    @Test
    fun `getCurrentPlanDayId 命中与未命中`() {
        // 源 getCurrentPlanDayId :317
        val days = listOf(TrainingDay("A", emptyList(), null), TrainingDay("B", emptyList(), null))
        assertEquals("current_plan_day_2", HomePlanService.getCurrentPlanDayId(days, "B"))
        assertEquals("", HomePlanService.getCurrentPlanDayId(days, "Z"))
    }

    // ════════════════ 5. PersonalRecordService ════════════════

    @Test
    fun `createRecords 按动作汇总最佳纪录并对1RM取整`() {
        // 源 PersonalRecordService.ets:37 createRecords；1RM 取整 :98 Math.round
        val sessions = listOf(
            session(
                sessionId = "s1", startedAt = 100,
                sets = listOf(
                    set("bench", 100.0, 5), // 116.67 → 117
                    set("bench", 60.0, 10, isWarmup = true), // 热身排除
                    set("squat", 120.0, 3), // 132.0
                    set("", 100.0, 5), // 无动作 id 排除
                    set("bench", 80.0, 0), // reps=0 排除
                ),
            ),
            session(
                sessionId = "s2", startedAt = 200,
                sets = listOf(
                    set("bench", 62.5, 10), // 83.33 → 83
                    set("bench", 110.0, 3), // 121.0 → 121
                ),
            ),
        )
        val records = PersonalRecordService.createRecords(sessions)
        assertEquals(2, records.size) // 首次出现顺序：bench, squat
        val bench = records.first { it.exerciseId == "bench" }
        assertEquals(121, bench.bestOneRepMax)
        assertEquals(110.0, bench.bestWeight, 1e-9)
        assertEquals(10, bench.bestReps)
        assertTrue(bench.bestDateText.isNotEmpty())
        val squat = records.first { it.exerciseId == "squat" }
        assertEquals(132, squat.bestOneRepMax)
        assertEquals(120.0, squat.bestWeight, 1e-9)
        assertEquals(3, squat.bestReps)
    }

    @Test
    fun `createRecordDetails 计数与按1RM降序排序`() {
        // 源 createRecordDetails :53 / sortRecordDetails :214（1RM 降序）
        val sessions = listOf(
            session(
                sessionId = "s1", startedAt = 100,
                sets = listOf(set("bench", 100.0, 5), set("bench", 90.0, 8), set("squat", 140.0, 3)),
            ),
            session(
                sessionId = "s2", startedAt = 200,
                sets = listOf(set("bench", 105.0, 5), set("squat", 150.0, 2)),
            ),
        )
        val details = PersonalRecordService.createRecordDetails(sessions)
        assertEquals(2, details.size)
        // squat best 160 > bench best 123
        assertEquals("squat", details[0].exerciseId)
        assertEquals("bench", details[1].exerciseId)
        val bench = details[1]
        assertEquals(123, bench.bestOneRepMax) // 105*1.1667=122.5 → 123
        assertEquals(2, bench.sessionCount)
        assertEquals(3, bench.performedSetCount)
        val squat = details[0]
        assertEquals(160, squat.bestOneRepMax) // 150*1.0667=160.0
        assertEquals(2, squat.sessionCount)
        assertEquals(2, squat.performedSetCount)
    }

    @Test
    fun `trendText 与最近表现`() {
        // 源 createTrendText :195 / updateRecordDetail :160
        val sessions = listOf(
            session(sessionId = "s1", startedAt = 1000, sets = listOf(set("bench", 100.0, 5))),
            session(sessionId = "s2", startedAt = 2000, sets = listOf(set("bench", 80.0, 5))),
        )
        val detail = PersonalRecordService.createRecordDetails(sessions).first { it.exerciseId == "bench" }
        assertEquals(117, detail.bestOneRepMax)
        assertEquals(93, detail.recentOneRepMax) // 80*1.1667=93.33 → 93
        assertEquals(2000L, detail.lastPerformedAt)
        assertEquals(400.0, detail.recentVolume, 1e-9) // 80*5
        assertEquals("最近一次距离 PR 还差 24 kg。", detail.trendText) // 117-93
    }

    @Test
    fun `最近一次追平PR`() {
        val detail = PersonalRecordService.createRecordDetails(
            listOf(session(sessionId = "s1", startedAt = 1000, sets = listOf(set("bench", 100.0, 5)))),
        ).first()
        assertEquals(117, detail.bestOneRepMax)
        assertEquals(117, detail.recentOneRepMax)
        assertEquals("最近一次训练已追平当前 PR。", detail.trendText)
    }

    @Test
    fun `空明细默认值`() {
        // 源 createEmptyRecordDetail :76
        val detail = PersonalRecordService.createEmptyRecordDetail()
        assertEquals("", detail.exerciseId)
        assertEquals(0, detail.bestOneRepMax)
        assertEquals(0L, detail.lastPerformedAt)
        assertEquals("完成训练后，这里会显示动作纪录变化。", detail.trendText)
    }

    @Test
    fun `个人纪录动作名走注入解析器未命中回落 id`() {
        PersonalRecordService.exerciseNameResolver = { id -> if (id == "bench") "杠铃卧推" else null }
        val records = PersonalRecordService.createRecords(
            listOf(
                session(
                    sessionId = "s1", startedAt = 100,
                    sets = listOf(set("bench", 100.0, 5), set("unknown", 50.0, 5)),
                ),
            ),
        ).associateBy { it.exerciseId }
        assertEquals("杠铃卧推", records.getValue("bench").exerciseName)
        assertEquals("unknown", records.getValue("unknown").exerciseName)
    }
}

package com.fittracker.app.data.service.stats

import com.fittracker.app.data.model.ExerciseRef
import com.fittracker.app.data.model.PlanDay
import com.fittracker.app.data.model.PlannedExercise
import com.fittracker.app.data.model.TrainingDay
import com.fittracker.app.data.model.TrainingPlan
import com.fittracker.app.data.model.UserGoal
import com.fittracker.app.data.model.UserPlan
import com.fittracker.app.data.service.ContentRepository

/** 首页周计划行（源 `HomePlanService.ets:26` `HomeWeeklyPlanDay`）。 */
data class HomeWeeklyPlanDay(
    val dayId: String,
    val title: String,
    val exerciseCount: Int,
    val isToday: Boolean,
)

/** 首页推荐动作（源 `HomePlanService.ets:33` `HomeRecommendedExercise`）。 */
data class HomeRecommendedExercise(
    val exerciseId: String,
    val name: String,
    val prescription: String,
    val intensityNote: String,
)

/** 首页计划汇总（源 `HomePlanService.ets:40` `HomePlanSummary`）。 */
data class HomePlanSummary(
    val hasGoal: Boolean,
    val planId: String,
    val planName: String,
    val weeklyDays: Int,
    val sessionMinutes: Int,
    val primaryMetaText: String,
    val secondaryMetaText: String,
    val goalSummary: String,
    val equipmentSummary: String,
    val restrictionSummary: String,
    val weeklyPlanDays: List<HomeWeeklyPlanDay>,
    val todayDayId: String,
    val todayTitle: String,
    val todayLabel: String,
    val hasTodayWorkout: Boolean,
    val todayRestMessage: String,
    val todayMuscleGroupCount: Int,
    val todayExerciseCount: Int,
    val todayExerciseNames: List<String>,
    val recommendedExercises: List<HomeRecommendedExercise>,
    val startButtonText: String,
    val startRoute: String,
)

/**
 * 首页计划摘要——逐函数移植自鸿蒙 `shared/services/HomePlanService.ets`。
 *
 * Feature #4/#5/#8（目标摘要 / 周计划行 / 今日入口）+ #19/#20（预置计划今日视图 / 休息日视图）。
 *
 * 依赖：名称反查 `ContentRepository`（`getExercise` / `getEquipmentName` / `getMuscleName`）。
 * 三个反查以**可注入插槽**暴露（默认接真实 `ContentRepository`，测试可注入确定性实现），
 * 便于纯函数断言；函数签名与源一致。路由常量见 [START_ROUTE_WORKOUT]。
 */
object HomePlanService {

    /** 首页「开始训练」目标路由。源 `AppRoutes.ets:19` `WORKOUT_PREVIEW`（Android 侧对应 `FtRoutes` 的 `workout`）。 */
    const val START_ROUTE_WORKOUT = "workout"

    /**
     * 动作名反查插槽——默认接 `ContentRepository.getExercise(id)?.nameZh`；
     * 回落 `null` 时调用方用 `exerciseId`（源 `getExerciseById` 未命中分支）。
     */
    var exerciseNameResolver: (String) -> String? = { id -> ContentRepository.getExercise(id)?.nameZh }

    /** 器械名反查插槽——默认接 `ContentRepository.getEquipmentName`（未命中返回 id）。 */
    var equipmentNameResolver: (String) -> String = { id -> ContentRepository.getEquipmentName(id) }

    /** 肌群名反查插槽——默认接 `ContentRepository.getMuscleName`（未命中返回 id）。 */
    var muscleNameResolver: (String) -> String = { id -> ContentRepository.getMuscleName(id) }

    /** 源 `createSummary`（`HomePlanService.ets:65`）。 */
    fun createSummary(goal: UserGoal, plan: TrainingPlan, daySeed: Int): HomePlanSummary {
        val today = pickTodayDay(plan, daySeed)
        val primaryMetaText = "每周 ${goal.weeklyDays} 天"
        val secondaryMetaText = "单次 ${goal.sessionMinutes} 分钟"
        if (today == null) {
            return HomePlanSummary(
                hasGoal = true,
                planId = plan.planId,
                planName = plan.name,
                weeklyDays = goal.weeklyDays,
                sessionMinutes = goal.sessionMinutes,
                primaryMetaText = primaryMetaText,
                secondaryMetaText = secondaryMetaText,
                goalSummary = createGoalSummary(goal),
                equipmentSummary = createEquipmentSummary(goal.equipmentIds),
                restrictionSummary = createRestrictionSummary(goal.restrictedMuscleIds),
                weeklyPlanDays = createWeeklyPlanDays(plan.days, ""),
                todayDayId = "",
                todayTitle = "休息日",
                todayLabel = "今天是恢复日",
                hasTodayWorkout = false,
                todayRestMessage = "当前安排没有训练动作，今天更适合恢复、散步或拉伸。",
                todayMuscleGroupCount = 0,
                todayExerciseCount = 0,
                todayExerciseNames = emptyList(),
                recommendedExercises = emptyList(),
                startButtonText = "今天休息",
                startRoute = "",
            )
        }

        val names = getExerciseNames(today.exercises)
        val recommendedExercises = createRecommendedExercises(today.exercises)
        return HomePlanSummary(
            hasGoal = true,
            planId = plan.planId,
            planName = plan.name,
            weeklyDays = goal.weeklyDays,
            sessionMinutes = goal.sessionMinutes,
            primaryMetaText = primaryMetaText,
            secondaryMetaText = secondaryMetaText,
            goalSummary = createGoalSummary(goal),
            equipmentSummary = createEquipmentSummary(goal.equipmentIds),
            restrictionSummary = createRestrictionSummary(goal.restrictedMuscleIds),
            weeklyPlanDays = createWeeklyPlanDays(plan.days, today.dayId),
            todayDayId = today.dayId,
            todayTitle = today.title,
            todayLabel = "今天训练 | ${today.title}",
            hasTodayWorkout = true,
            todayRestMessage = "",
            todayMuscleGroupCount = today.focusMuscleIds.size,
            todayExerciseCount = today.exercises.size,
            todayExerciseNames = names,
            recommendedExercises = recommendedExercises,
            startButtonText = "开始训练",
            startRoute = START_ROUTE_WORKOUT,
        )
    }

    /** 源 `createSummaryFromCurrentPlan`（`:128`）。 */
    fun createSummaryFromCurrentPlan(
        plan: UserPlan,
        todayLabel: String,
        todayTraining: TrainingDay?,
        sessionMinutes: Int,
    ): HomePlanSummary {
        val primaryMetaText = plan.weeklyFrequency
        val secondaryMetaText = plan.targetAudience
        val goalSummary = "当前已启用预置训练计划，首页会跟随今天的安排展示训练或恢复状态。"
        val equipmentSummary = "计划来源 预置训练计划"
        val restrictionSummary = "适用人群 ${plan.targetAudience}"
        val todayDayLabel = todayTraining?.dayLabel ?: ""
        val weeklyPlanDays = createWeeklyPlanDaysFromCurrentPlan(plan.days, todayDayLabel)

        if (todayTraining == null) {
            return HomePlanSummary(
                hasGoal = true,
                planId = plan.id,
                planName = plan.name,
                weeklyDays = plan.days.size,
                sessionMinutes = sessionMinutes,
                primaryMetaText = primaryMetaText,
                secondaryMetaText = secondaryMetaText,
                goalSummary = goalSummary,
                equipmentSummary = equipmentSummary,
                restrictionSummary = restrictionSummary,
                weeklyPlanDays = weeklyPlanDays,
                todayDayId = "",
                todayTitle = "休息日",
                todayLabel = "$todayLabel | 休息日",
                hasTodayWorkout = false,
                todayRestMessage = "当前计划今天没有训练安排，保持恢复节奏就好。",
                todayMuscleGroupCount = 0,
                todayExerciseCount = 0,
                todayExerciseNames = emptyList(),
                recommendedExercises = emptyList(),
                startButtonText = "今天休息",
                startRoute = "",
            )
        }

        val names = getExerciseNamesFromRefs(todayTraining.exercises)
        val recommendedExercises = createRecommendedExercisesFromRefs(plan.id, todayTraining.exercises)
        return HomePlanSummary(
            hasGoal = true,
            planId = plan.id,
            planName = plan.name,
            weeklyDays = plan.days.size,
            sessionMinutes = sessionMinutes,
            primaryMetaText = primaryMetaText,
            secondaryMetaText = secondaryMetaText,
            goalSummary = goalSummary,
            equipmentSummary = equipmentSummary,
            restrictionSummary = restrictionSummary,
            weeklyPlanDays = weeklyPlanDays,
            todayDayId = getCurrentPlanDayId(plan.days, todayTraining.dayLabel),
            todayTitle = todayTraining.dayLabel,
            todayLabel = "$todayLabel | ${todayTraining.dayLabel}",
            hasTodayWorkout = true,
            todayRestMessage = "",
            todayMuscleGroupCount = countFocusMuscles(todayTraining.exercises),
            todayExerciseCount = todayTraining.exercises.size,
            todayExerciseNames = names,
            recommendedExercises = recommendedExercises,
            startButtonText = "训练流程接入中",
            startRoute = START_ROUTE_WORKOUT,
        )
    }

    /** 源 `pickTodayDay`（`:204`）。`daySeed <= 0` 归一为 1；按 `(seed-1) % days.size` 取模。 */
    fun pickTodayDay(plan: TrainingPlan, daySeed: Int): PlanDay? {
        if (plan.days.isEmpty()) {
            return null
        }
        var normalizedSeed = daySeed
        if (normalizedSeed <= 0) {
            normalizedSeed = 1
        }
        val index = (normalizedSeed - 1) % plan.days.size
        return plan.days[index]
    }

    /** 源 `getExerciseNames`（`:217`）。 */
    fun getExerciseNames(exercises: List<PlannedExercise>): List<String> {
        val names = ArrayList<String>(exercises.size)
        for (planned in exercises) {
            names.add(exerciseNameResolver(planned.exerciseId) ?: planned.exerciseId)
        }
        return names
    }

    /** 源 `getExerciseNamesFromRefs`（`:231`）。 */
    fun getExerciseNamesFromRefs(exercises: List<ExerciseRef>): List<String> {
        val names = ArrayList<String>(exercises.size)
        for (exercise in exercises) {
            names.add(exercise.name)
        }
        return names
    }

    /** 源 `countFocusMuscles`（`:240`）。训练动作涉及的目标肌群去重计数。 */
    fun countFocusMuscles(exercises: List<ExerciseRef>): Int {
        val muscles = ArrayList<String>()
        for (exercise in exercises) {
            val muscle = exercise.targetMuscle
            if (muscle.isNotEmpty() && muscle !in muscles) {
                muscles.add(muscle)
            }
        }
        return muscles.size
    }

    /** 源 `createRecommendedExercises`（`:251`）。 */
    fun createRecommendedExercises(exercises: List<PlannedExercise>): List<HomeRecommendedExercise> {
        val items = ArrayList<HomeRecommendedExercise>(exercises.size)
        for (planned in exercises) {
            val name = exerciseNameResolver(planned.exerciseId) ?: planned.exerciseId
            items.add(
                HomeRecommendedExercise(
                    exerciseId = planned.exerciseId,
                    name = name,
                    prescription = "${planned.targetSets} 组 x ${planned.targetReps}",
                    intensityNote = planned.intensityNote,
                ),
            )
        }
        return items
    }

    /** 源 `createRecommendedExercisesFromRefs`（`:272`）。 */
    fun createRecommendedExercisesFromRefs(
        planId: String,
        exercises: List<ExerciseRef>,
    ): List<HomeRecommendedExercise> {
        val items = ArrayList<HomeRecommendedExercise>(exercises.size)
        for ((index, exercise) in exercises.withIndex()) {
            items.add(
                HomeRecommendedExercise(
                    exerciseId = "${planId}_exercise_${index + 1}",
                    name = exercise.name,
                    prescription = "${exercise.sets} 组 x ${exercise.reps}",
                    intensityNote = "目标肌群 ${exercise.targetMuscle}",
                ),
            )
        }
        return items
    }

    /** 源 `createWeeklyPlanDays`（`:287`）。 */
    fun createWeeklyPlanDays(days: List<PlanDay>, todayDayId: String): List<HomeWeeklyPlanDay> {
        val weeklyPlanDays = ArrayList<HomeWeeklyPlanDay>(days.size)
        for (day in days) {
            weeklyPlanDays.add(
                HomeWeeklyPlanDay(
                    dayId = day.dayId,
                    title = day.title,
                    exerciseCount = day.exercises.size,
                    isToday = day.dayId == todayDayId,
                ),
            )
        }
        return weeklyPlanDays
    }

    /** 源 `createWeeklyPlanDaysFromCurrentPlan`（`:302`）。 */
    fun createWeeklyPlanDaysFromCurrentPlan(
        days: List<TrainingDay>,
        todayDayLabel: String,
    ): List<HomeWeeklyPlanDay> {
        val weeklyPlanDays = ArrayList<HomeWeeklyPlanDay>(days.size)
        for ((index, day) in days.withIndex()) {
            weeklyPlanDays.add(
                HomeWeeklyPlanDay(
                    dayId = "current_plan_day_${index + 1}",
                    title = day.dayLabel,
                    exerciseCount = day.exercises.size,
                    isToday = day.dayLabel == todayDayLabel,
                ),
            )
        }
        return weeklyPlanDays
    }

    /** 源 `getCurrentPlanDayId`（`:317`）。 */
    fun getCurrentPlanDayId(days: List<TrainingDay>, todayDayLabel: String): String {
        for ((index, day) in days.withIndex()) {
            if (day.dayLabel == todayDayLabel) {
                return "current_plan_day_${index + 1}"
            }
        }
        return ""
    }

    /** 源 `createGoalSummary`（`:326`）。 */
    private fun createGoalSummary(goal: UserGoal): String =
        "目标 ${getGoalTypeLabel(goal.goalType)} | ${getLevelLabel(goal.level)}" +
            " | 每周 ${goal.weeklyDays} 天 | 单次 ${goal.sessionMinutes} 分钟"

    /** 源 `createEquipmentSummary`（`:331`）。 */
    private fun createEquipmentSummary(equipmentIds: List<String>): String {
        if (equipmentIds.isEmpty()) {
            return "器械 徒手"
        }
        return "器械 ${createNameList(equipmentIds, isEquipment = true)}"
    }

    /** 源 `createRestrictionSummary`（`:338`）。 */
    private fun createRestrictionSummary(restrictedMuscleIds: List<String>): String {
        if (restrictedMuscleIds.isEmpty()) {
            return "避开 无"
        }
        return "避开 ${createNameList(restrictedMuscleIds, isEquipment = false)}"
    }

    /** 源 `createNameList`（`:345`）。以「、」连接名称。 */
    private fun createNameList(ids: List<String>, isEquipment: Boolean): String {
        val builder = StringBuilder()
        for ((index, id) in ids.withIndex()) {
            if (index > 0) {
                builder.append('、')
            }
            builder.append(if (isEquipment) equipmentNameResolver(id) else muscleNameResolver(id))
        }
        return builder.toString()
    }

    /** 源 `getGoalTypeLabel`（`:360`）。 */
    private fun getGoalTypeLabel(goalType: String): String = when (goalType) {
        "hypertrophy" -> "增肌"
        "strength" -> "力量"
        "fat_loss" -> "减脂"
        "posture" -> "体态"
        else -> goalType
    }

    /** 源 `getLevelLabel`（`:376`）。 */
    private fun getLevelLabel(level: String): String = when (level) {
        "beginner" -> "初学"
        "intermediate" -> "进阶"
        "advanced" -> "高级"
        else -> level
    }
}

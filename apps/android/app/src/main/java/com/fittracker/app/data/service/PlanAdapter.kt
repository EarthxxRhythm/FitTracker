package com.fittracker.app.data.service

import com.fittracker.app.data.model.ExerciseContent
import com.fittracker.app.data.model.ExerciseRef
import com.fittracker.app.data.model.TrainingDay
import com.fittracker.app.data.model.TrainingPlan
import com.fittracker.app.data.model.UserGoal
import com.fittracker.app.data.model.UserPlan
import com.fittracker.app.data.persist.JsonStore

/**
 * 训练偏好 → 计划生成链的适配器（计划 D-4 / D-5 决策的落地）。
 *
 * 背景（模型断层）：本仓存在**两套计划模型**——`PlanEngine.generatePlan` 产出 `TrainingPlan`
 * （`PlanDay` / `PlannedExercise`，消费方为源侧 HomeContent），而 UI 实际消费的是 `UserPlan`
 * （`TrainingPlanRepository.getCurrentPlan`，见 `data/model/PlanModels.kt:6-8` 自陈）。两者
 * 此前**无适配器**、`TrainingPlan` 也无持久化路径，故「保存偏好 → 重新生成计划」的链在模型层
 * 断裂。本适配器把该链接通：偏好存库 → 落 `UserGoal` → `PlanEngine` 生成 → 转 `UserPlan`
 * → 同 id 覆盖并入「我的计划」并设为当前。
 *
 * 生成计划的 `id` 稳定为 `plan_${goalId}`（`PlanEngine.kt:109` 既定）——重复保存即**覆盖再生成**
 * （对齐原型按钮语义「重新生成本周训练计划」），用户手动启用的其他计划不受影响。
 */
object PlanAdapter {

    /** 生成计划封面色——取数据板既有翡翠主色（与其他计划卡同族）。 */
    const val DEFAULT_GENERATED_COVER: String = "#50ECA7"

    /** 生成计划描述（原型页脚语义：基于最新偏好重新生成本周计划）。 */
    const val GENERATED_DESCRIPTION: String = "根据训练偏好自动生成"

    /**
     * 生成计划的「第 N 天」→ 星期分配表（**Android 侧新增设计定义**，源侧无此链；计划 D-5）。
     *
     * 键 = 计划天数，值 = 各天分配的 JS `getDay()` 星期（1=周一…0=周日），均匀分布。
     * 不分配的后果：`TrainingPlanRepository.getTodayTraining`（`:413`）以星期命中，
     * 首页「今日训练」将永久空态。
     */
    private val DAY_ASSIGNMENT: Map<Int, List<Int>> = mapOf(
        2 to listOf(1, 4),
        3 to listOf(1, 3, 5),
        4 to listOf(1, 2, 4, 5),
        5 to listOf(1, 2, 3, 4, 5),
        6 to listOf(1, 2, 3, 4, 5, 6),
        7 to listOf(1, 2, 3, 4, 5, 6, 0),
    )

    /**
     * 保存偏好并「生成 + 启用」本周计划。
     *
     * 编排（顺序即语义）：[TrainingPreferencesService.savePreferences] → [GoalRepository.loadGoal]
     * （取既有 `goalId` 以稳定计划 id）→ [preferencesToGoal] → [GoalRepository.saveGoal] →
     * `PlanEngine.generatePlan` → [trainingPlanToUserPlan] → 同 id 覆盖后
     * [TrainingPlanRepository.replaceMyPlans]（写列表 + 设当前）。
     *
     * @return 全链成功为 `true`；任一步异常返回 `false`（不半写——但**偏好已保存**属正确的
     *   部分成功语义：生成失败时偏好仍在库中，重试即可）。注意 [GoalRepository] /
     *   [TrainingPlanRepository] 内部吞掉持久化异常并只置错误码，故这两步的写失败不会使本函数
     *   返回 `false`——与本仓既有的静默持久化口径一致。
     */
    suspend fun generateAndEnablePlan(store: JsonStore, preferences: FtTrainingPreferences): Boolean {
        return try {
            TrainingPreferencesService.savePreferences(store, preferences)
            val previous: UserGoal? = GoalRepository.loadGoal(store)
            val now: Long = System.currentTimeMillis()
            val goal: UserGoal = preferencesToGoal(preferences, previous, now)
            GoalRepository.saveGoal(store, goal)

            val exercises: List<ExerciseContent> = ContentRepository.exercises()
            val plan: TrainingPlan = generatePlan(goal, exercises)
            val userPlan: UserPlan = trainingPlanToUserPlan(plan, goal, exercises, now)

            val existing: List<UserPlan> = TrainingPlanRepository.getMyPlans(store)
            val merged: List<UserPlan> = existing.filterNot { it.id == userPlan.id } + userPlan
            TrainingPlanRepository.replaceMyPlans(store, merged, userPlan.id)
            true
        } catch (error: Exception) {
            false
        }
    }

    /**
     * 偏好 → [UserGoal] 映射。
     *
     * `goalId` 保持既有目标的 id（无既有目标时以 `now` 生成 `goal_<时间戳>`）——
     * 目标是「同一目标的偏好更新」，故同 id 生成计划会**覆盖自身**而非堆积新计划。
     *
     * @param previous 既有目标（来自 [GoalRepository.loadGoal]），可为 `null`。
     */
    internal fun preferencesToGoal(
        preferences: FtTrainingPreferences,
        previous: UserGoal?,
        now: Long,
    ): UserGoal = UserGoal(
        goalId = previous?.goalId ?: "goal_$now",
        goalType = preferences.goal.id,
        level = preferences.level.id,
        weeklyDays = preferences.daysPerWeek,
        sessionMinutes = preferences.sessionMinutes,
        equipmentIds = preferences.equipmentIds.toList(),
        restrictedMuscleIds = preferences.restrictedMuscleIds.toList(),
        createdAt = previous?.createdAt ?: now,
        updatedAt = now,
    )

    /**
     * [TrainingPlan] → [UserPlan] 适配器（字段映射见计划 B4）。
     *
     * - `id` = `plan.planId`（`plan_${goalId}`，稳定 → 覆盖语义）；
     * - `days` 复用 `PlanEngine` 的「第 N 天」标题，并按 [DAY_ASSIGNMENT] 分配星期；
     * - 动作名 / 目标肌群经 [exercises] 索引解析：动作缺失回落 `exerciseId`，无主肌群回落空串
     *   （兜底不抛，保证计划可用）。
     *
     * @param exercises 内容库动作清单（生产为 [ContentRepository.exercises]），供名称 / 肌群解析。
     */
    internal fun trainingPlanToUserPlan(
        plan: TrainingPlan,
        goal: UserGoal,
        exercises: List<ExerciseContent>,
        now: Long,
    ): UserPlan {
        val exercisesById: Map<String, ExerciseContent> = exercises.associateBy { it.exerciseId }
        val daySlots: List<Int> = dayAssignmentSlots(plan.days.size)
        return UserPlan(
            id = plan.planId,
            name = plan.name,
            coverColor = DEFAULT_GENERATED_COVER,
            targetAudience = targetAudienceOf(goal.level),
            weeklyFrequency = "${plan.days.size} 天 / 周",
            description = GENERATED_DESCRIPTION,
            days = plan.days.mapIndexed { index, day ->
                TrainingDay(
                    dayLabel = day.title,
                    dayOfWeek = listOf(daySlots[index % daySlots.size]),
                    exercises = day.exercises.map { planned ->
                        val content: ExerciseContent? = exercisesById[planned.exerciseId]
                        ExerciseRef(
                            name = content?.nameZh ?: planned.exerciseId,
                            targetMuscle = content?.primaryMuscleIds?.firstOrNull()
                                ?.let { ContentRepository.getMuscleName(it) }
                                ?: "",
                            sets = planned.targetSets,
                            reps = planned.targetReps,
                        )
                    },
                )
            },
            enabledAt = now,
        )
    }

    /**
     * 取某天数对应的星期分配槽位。表外天数（`0`/`1`/`>7`，正常链不会出现——
     * `daysPerWeek` 已在服务层归一为 `2..5`）按周一起连续分配，避免下标越界。
     */
    private fun dayAssignmentSlots(dayCount: Int): List<Int> =
        DAY_ASSIGNMENT[dayCount] ?: List(dayCount.coerceAtLeast(0)) { index -> (index % 7 + 1) % 7 }

    /** 经验档 → 计划卡「适合人群」中文（对齐原型 chip 标签：新手/进阶/熟练）。 */
    private fun targetAudienceOf(level: String): String = when (level) {
        PrefLevel.BEGINNER.id -> "新手"
        PrefLevel.ADVANCED.id -> "熟练"
        else -> "进阶"
    }
}

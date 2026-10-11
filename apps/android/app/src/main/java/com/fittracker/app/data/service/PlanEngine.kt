package com.fittracker.app.data.service

import com.fittracker.app.data.model.ExerciseContent
import com.fittracker.app.data.model.PlanDay
import com.fittracker.app.data.model.PlannedExercise
import com.fittracker.app.data.model.TrainingPlan
import com.fittracker.app.data.model.UserGoal

/**
 * 目标计划生成引擎——逐句移植自鸿蒙工程 `shared/services/PlanEngine.ets`（L1-308）。
 *
 * ## 设计偏差（唯一一处，相对源实现）
 * 源 `PlanEngineImpl.generatePlan(goal)` 在 `collectCandidates` 里直接调用
 * `ContentRepository.getExercises()` 取动作库（`PlanEngine.ets:177`）；本移植把**动作清单
 * 改为入参注入**（`exercises: List<ExerciseContent>`），规则表同样走默认参数注入
 * （`rules: List<PlanRule> = SeedPlanRules.ALL`）。原因：
 * 1. **可测性**——纯函数、无全局单例依赖，单测可构造确定性输入直接断言输出；
 * 2. **并行安全**——多套计划生成之间不共享可变状态，可并发调用。
 * 除「动作来源」这一处依赖反转外，打分/匹配/逐级放宽/排序策略与源实现**逐句一致**，
 * 未做任何行为改动；`generatedBy` 保持源字面量 `rule_v1`。
 */

/** 计划生成规则（`mock/SeedPlanRules.ets:7` 的 `PlanRule` 接口）。 */
data class PlanRule(
    val goalType: String,
    val planName: String,
    val cycleWeeks: Int,
    val targetSets: Int,
    val targetReps: String,
    val intensityNote: String,
)

/** 规则种子表（`mock/SeedPlanRules.ets:35-40`）。字段顺序与源 `createPlanRule` 实参一致。 */
object SeedPlanRules {
    val ALL: List<PlanRule> = listOf(
        PlanRule("hypertrophy", "增肌基础计划", 4, 3, "8-12", "控制节奏，保留 1-2 次余力"),
        PlanRule("strength", "力量基础计划", 4, 5, "3-5", "采用大重量组，组间充分休息"),
        PlanRule("fat_loss", "减脂基础计划", 4, 3, "10-15", "保持稳定节奏，缩短组间休息"),
        PlanRule("posture", "体态基础计划", 4, 2, "12-15", "动作节奏平稳，注意姿势精确"),
    )
}

/** `PlanEngine.ets:19`。 */
private const val GENERATED_BY_RULE_V1 = "rule_v1"

/** `PlanEngine.ets:20`。 */
private const val ACTIVE_STATUS = "active"

/** 每日动作上限（`PlanEngine.ets:29`）。 */
private const val MAX_EXERCISES_PER_DAY = 3

/** 目标未指定器械时的兜底器械（`PlanEngine.ets:30`）。 */
private const val BODYWEIGHT_EQUIPMENT_ID = "eq_bodyweight"

/** 三级选择说明（`PlanEngine.ets:31-33`）。 */
private const val EXACT_MATCH_NOTE = "精确匹配：目标、器械、肌群和难度均匹配。"
private const val RELAX_DIFFICULTY_NOTE = "已放宽难度：未找到完全匹配动作，优先保留目标、器械和肌群。"
private const val RELAX_EQUIPMENT_NOTE = "已放宽器械：未找到可用器械动作，请在执行前确认替代器械。"

/** 六个可轮换的焦点肌群（`PlanEngine.ets:21-28`）。 */
private val FOCUS_MUSCLE_IDS = listOf(
    "muscle_chest",
    "muscle_back",
    "muscle_legs",
    "muscle_shoulders",
    "muscle_arms",
    "muscle_core",
)

/** 候选动作及打分（`PlanEngine.ets:35-46` 的 `ScoredExercise`）。 */
private data class ScoredExercise(
    val exercise: ExerciseContent,
    val score: Int,
    val selectionNote: String,
)

/**
 * 生成目标计划（`PlanEngine.ets:48-77`）。
 *
 * @param goal 用户目标；`weeklyDays` 会被夹到 `0..7`。
 * @param exercises 动作库（源为 `ContentRepository.getExercises()`，此处注入）。
 * @param rules 规则表；默认取 `SeedPlanRules.ALL`。
 */
fun generatePlan(
    goal: UserGoal,
    exercises: List<ExerciseContent>,
    rules: List<PlanRule> = SeedPlanRules.ALL,
): TrainingPlan {
    val rule = findRule(goal.goalType, rules) // :49
    val days = mutableListOf<PlanDay>()
    val weeklyDays = normalizeWeeklyDays(goal.weeklyDays) // :51
    val availableFocusMuscleIds = getAvailableFocusMuscleIds(goal, exercises) // :52

    for (dayIndex in 0 until weeklyDays) {
        val focusMuscleId = pickFocusMuscleId(availableFocusMuscleIds, dayIndex) // :55
        val dayNumber = dayIndex + 1
        val dayFocusMuscleIds = listOf(focusMuscleId) // :57
        val planned = buildPlannedExercises(goal, rule, focusMuscleId, dayNumber, exercises) // :58
        days.add(
            PlanDay(
                dayId = "day_$dayNumber", // :60
                dayOfWeek = dayNumber,
                title = "第 $dayNumber 天", // :62
                focusMuscleIds = dayFocusMuscleIds,
                exercises = planned,
            ),
        )
    }

    return TrainingPlan(
        planId = "plan_${goal.goalId}", // :69
        goalId = goal.goalId,
        name = rule.planName,
        cycleWeeks = rule.cycleWeeks,
        days = days,
        generatedBy = GENERATED_BY_RULE_V1, // :74
        status = ACTIVE_STATUS, // :75
    )
}

/** 周训练天数夹到 `0..7`（`PlanEngine.ets:79-87`）。 */
private fun normalizeWeeklyDays(weeklyDays: Int): Int = when {
    weeklyDays < 0 -> 0
    weeklyDays > 7 -> 7
    else -> weeklyDays
}

/** 按 `goalType` 选规则，未命中回落首条（`PlanEngine.ets:89-97`，回落见 :96）。 */
private fun findRule(goalType: String, rules: List<PlanRule>): PlanRule =
    rules.firstOrNull { it.goalType == goalType } ?: rules.first()

/** 为某焦点肌群构造当日处方，最多 [MAX_EXERCISES_PER_DAY] 条（`PlanEngine.ets:99-127`）。 */
private fun buildPlannedExercises(
    goal: UserGoal,
    rule: PlanRule,
    muscleId: String,
    dayNumber: Int,
    exercises: List<ExerciseContent>,
): List<PlannedExercise> {
    val plannedExercises = mutableListOf<PlannedExercise>()
    val candidates = findScoredCandidates(goal, muscleId, exercises) // :106

    for (scored in candidates) {
        if (plannedExercises.size >= MAX_EXERCISES_PER_DAY) return plannedExercises // :109

        val exercise = scored.exercise
        plannedExercises.add(
            PlannedExercise(
                // :116
                plannedExerciseId = "planned_${dayNumber}_${plannedExercises.size + 1}",
                exerciseId = exercise.exerciseId,
                targetSets = rule.targetSets,
                targetReps = rule.targetReps,
                intensityNote = rule.intensityNote,
                alternativeExerciseIds = exercise.alternativeExerciseIds.toList(), // :121 copyStringArray
                selectionNote = scored.selectionNote,
            ),
        )
    }

    return plannedExercises
}

/** 未被受限、且有候选动作的焦点肌群，保持 [FOCUS_MUSCLE_IDS] 顺序（`PlanEngine.ets:129-138`）。 */
private fun getAvailableFocusMuscleIds(goal: UserGoal, exercises: List<ExerciseContent>): List<String> =
    FOCUS_MUSCLE_IDS.filter { muscleId -> // :133
        !containsValue(goal.restrictedMuscleIds, muscleId) && hasCandidateExercise(goal, muscleId, exercises)
    }

/** 按天轮换焦点肌群；可用列表为空时回落到全量焦点表（`PlanEngine.ets:140-145`）。 */
private fun pickFocusMuscleId(availableFocusMuscleIds: List<String>, dayIndex: Int): String =
    if (availableFocusMuscleIds.isNotEmpty()) {
        availableFocusMuscleIds[dayIndex % availableFocusMuscleIds.size] // :142
    } else {
        FOCUS_MUSCLE_IDS[dayIndex % FOCUS_MUSCLE_IDS.size] // :144
    }

/** 该肌群是否有候选动作（`PlanEngine.ets:147-150`）。 */
private fun hasCandidateExercise(
    goal: UserGoal,
    muscleId: String,
    exercises: List<ExerciseContent>,
): Boolean = findScoredCandidates(goal, muscleId, exercises).isNotEmpty() // :148-149

/**
 * 三级放宽策略，返回首个非空候选集（`PlanEngine.ets:152-164`）：
 * 精确匹配 → 放宽难度 → 放宽器械（并放开难度）。
 */
private fun findScoredCandidates(
    goal: UserGoal,
    muscleId: String,
    exercises: List<ExerciseContent>,
): List<ScoredExercise> {
    val exactMatches = collectCandidates(goal, muscleId, exercises, true, true, EXACT_MATCH_NOTE) // :153
    if (exactMatches.isNotEmpty()) return exactMatches // :154-155

    val relaxedDifficultyMatches =
        collectCandidates(goal, muscleId, exercises, true, false, RELAX_DIFFICULTY_NOTE) // :158
    if (relaxedDifficultyMatches.isNotEmpty()) return relaxedDifficultyMatches // :159-160

    return collectCandidates(goal, muscleId, exercises, false, false, RELAX_EQUIPMENT_NOTE) // :163
}

/** 按门槛过滤 + 打分，返回降序排序后的候选（`PlanEngine.ets:166-188`）。 */
private fun collectCandidates(
    goal: UserGoal,
    muscleId: String,
    exercises: List<ExerciseContent>,
    requireEquipment: Boolean,
    requireDifficulty: Boolean,
    selectionNote: String,
): List<ScoredExercise> {
    val equipmentIds = normalizeEquipmentIds(goal.equipmentIds) // :174
    val scoredExercises = mutableListOf<ScoredExercise>()

    for (exercise in exercises) {
        if (!matchesRequiredFields(exercise, goal, muscleId, equipmentIds, requireEquipment, requireDifficulty)) {
            continue // :179-181
        }
        val score = scoreExercise(exercise, goal, muscleId, equipmentIds) // :183
        scoredExercises.add(ScoredExercise(exercise, score, selectionNote))
    }

    return sortScoredExercises(scoredExercises) // :187
}

/** 硬性匹配门槛（`PlanEngine.ets:190-214`）。 */
private fun matchesRequiredFields(
    exercise: ExerciseContent,
    goal: UserGoal,
    muscleId: String,
    equipmentIds: List<String>,
    requireEquipment: Boolean,
    requireDifficulty: Boolean,
): Boolean {
    if (containsRestrictedMuscle(exercise, goal.restrictedMuscleIds)) return false // :198
    if (!containsValue(exercise.goalTags, goal.goalType)) return false // :201
    if (!containsValue(exercise.primaryMuscleIds, muscleId) &&
        !containsValue(exercise.secondaryMuscleIds, muscleId)
    ) {
        return false // :204
    }
    if (requireEquipment && !hasSharedValue(exercise.equipmentIds, equipmentIds)) return false // :207
    if (requireDifficulty && exercise.difficulty != goal.level) return false // :210-212
    return true
}

/** 打分：目标 40 / 器械 30 / 主肌群 20 或次肌群 10 / 难度 8 / 有替代 2（`PlanEngine.ets:216-236`）。 */
private fun scoreExercise(
    exercise: ExerciseContent,
    goal: UserGoal,
    muscleId: String,
    equipmentIds: List<String>,
): Int {
    var score = 0
    if (containsValue(exercise.goalTags, goal.goalType)) score += 40 // :219
    if (hasSharedValue(exercise.equipmentIds, equipmentIds)) score += 30 // :222
    if (containsValue(exercise.primaryMuscleIds, muscleId)) {
        score += 20 // :225
    } else if (containsValue(exercise.secondaryMuscleIds, muscleId)) {
        score += 10 // :227
    }
    if (exercise.difficulty == goal.level) score += 8 // :230
    if (exercise.alternativeExerciseIds.isNotEmpty()) score += 2 // :233
    return score
}

/** 排序：分数降序 → 替代动作数降序 → `exerciseId` 升序（`PlanEngine.ets:238-260`）。 */
private fun sortScoredExercises(source: List<ScoredExercise>): List<ScoredExercise> =
    source.sortedWith(
        Comparator { left, right ->
            when {
                left.score != right.score -> right.score - left.score // :243
                left.exercise.alternativeExerciseIds.size != right.exercise.alternativeExerciseIds.size ->
                    right.exercise.alternativeExerciseIds.size - left.exercise.alternativeExerciseIds.size // :246
                else -> left.exercise.exerciseId.compareTo(right.exercise.exerciseId) // :248-253
            }
        },
    )

/** 无器械时兜底为自重（`PlanEngine.ets:262-268`）。 */
private fun normalizeEquipmentIds(equipmentIds: List<String>): List<String> =
    if (equipmentIds.isNotEmpty()) {
        equipmentIds.toList() // :264 copyStringArray
    } else {
        listOf(BODYWEIGHT_EQUIPMENT_ID) // :266
    }

/** 动作是否触及任一受限肌群（`PlanEngine.ets:270-278`）。 */
private fun containsRestrictedMuscle(exercise: ExerciseContent, restrictedMuscleIds: List<String>): Boolean =
    restrictedMuscleIds.any { muscleId -> // :273
        containsValue(exercise.primaryMuscleIds, muscleId) || containsValue(exercise.secondaryMuscleIds, muscleId)
    }

/** 两列表是否有交集（`PlanEngine.ets:280-287`）。 */
private fun hasSharedValue(leftValues: List<String>, rightValues: List<String>): Boolean =
    leftValues.any { containsValue(rightValues, it) } // :282

/** 线性查找（`PlanEngine.ets:297-305`）。 */
private fun containsValue(values: List<String>, targetValue: String): Boolean = values.contains(targetValue)

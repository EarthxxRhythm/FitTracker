package com.fittracker.app.data.service

import com.fittracker.app.data.model.ExerciseContent
import com.fittracker.app.data.model.TrainingPlan
import com.fittracker.app.data.model.UserGoal
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 目标计划生成引擎契约测试。
 *
 * 期望值逐条取自源实现 `shared/services/PlanEngine.ets` 与 `mock/SeedPlanRules.ets`，
 * 注释标注源行号。测试只喂确定性输入、断言纯输出，无需 Robolectric（引擎不触 Android 运行时）。
 */
class PlanEngineTest {

    // ── 测试脚手架 ────────────────────────────────────────────────

    private fun exercise(
        id: String,
        primary: List<String> = listOf("muscle_chest"),
        secondary: List<String> = emptyList(),
        equipment: List<String> = listOf("eq_barbell"),
        difficulty: String = "beginner",
        goalTags: List<String> = listOf("hypertrophy"),
        alternatives: List<String> = emptyList(),
    ): ExerciseContent = ExerciseContent(
        exerciseId = id,
        nameZh = "动作-$id",
        nameEn = "Exercise $id",
        aliases = emptyList(),
        primaryMuscleIds = primary,
        secondaryMuscleIds = secondary,
        equipmentIds = equipment,
        difficulty = difficulty,
        goalTags = goalTags,
        videoUrl = "",
        coverUrl = "",
        coverSourceLabel = "",
        videoSourceLabel = "",
        mediaLicenseText = "",
        steps = emptyList(),
        cues = emptyList(),
        commonMistakes = emptyList(),
        safetyNotes = emptyList(),
        alternativeExerciseIds = alternatives,
        contentVersion = 1,
    )

    private fun goal(
        goalType: String = "hypertrophy",
        level: String = "beginner",
        weeklyDays: Int = 3,
        equipmentIds: List<String> = listOf("eq_barbell"),
        restrictedMuscleIds: List<String> = emptyList(),
    ): UserGoal = UserGoal(
        goalId = "goal-1",
        goalType = goalType,
        level = level,
        weeklyDays = weeklyDays,
        sessionMinutes = 60,
        equipmentIds = equipmentIds,
        restrictedMuscleIds = restrictedMuscleIds,
        createdAt = 1_700_000_000_000,
        updatedAt = 1_700_000_000_000,
    )

    private fun TrainingPlan.exerciseIds(): List<String> =
        days.flatMap { day -> day.exercises.map { it.exerciseId } }

    // ── ① 规则表完整性（源 SeedPlanRules.ets:35-40） ──────────────

    @Test
    fun `规则表为四套且字段与源种子逐字一致`() {
        val rules = SeedPlanRules.ALL
        assertEquals(4, rules.size)
        assertEquals(
            listOf("hypertrophy", "strength", "fat_loss", "posture"),
            rules.map { it.goalType },
        )
        assertEquals(
            listOf("增肌基础计划", "力量基础计划", "减脂基础计划", "体态基础计划"),
            rules.map { it.planName },
        )
        assertEquals(listOf(4, 4, 4, 4), rules.map { it.cycleWeeks })
        assertEquals(listOf(3, 5, 3, 2), rules.map { it.targetSets })
        assertEquals(listOf("8-12", "3-5", "10-15", "12-15"), rules.map { it.targetReps })
        assertEquals(
            listOf(
                "控制节奏，保留 1-2 次余力",
                "采用大重量组，组间充分休息",
                "保持稳定节奏，缩短组间休息",
                "动作节奏平稳，注意姿势精确",
            ),
            rules.map { it.intensityNote },
        )
    }

    // ── ② 固定输入 → 确定性输出 ──────────────────────────────────

    /** 4 个胸部 + 2 个背部候选；器械/难度/目标标签均匹配。 */
    private fun deterministicExercises(): List<ExerciseContent> = listOf(
        // 分数 40+30+20+8+2 = 100（源 :219/:222/:225/:230/:233）
        exercise("chest-a", alternatives = listOf("alt1")),
        exercise("chest-b"),
        exercise("chest-c"),
        exercise("chest-d"),
        exercise("back-e", primary = listOf("muscle_back")),
        exercise("back-f", primary = listOf("muscle_back")),
    )

    @Test
    fun `固定输入产出确定性的三天计划`() {
        val plan = generatePlan(goal(weeklyDays = 3), deterministicExercises())

        // 计划外壳（源 :68-75）
        assertEquals("plan_goal-1", plan.planId) // :69
        assertEquals("goal-1", plan.goalId)
        assertEquals("增肌基础计划", plan.name)
        assertEquals(4, plan.cycleWeeks)
        assertEquals("rule_v1", plan.generatedBy) // :74 保持源值
        assertEquals("active", plan.status) // :75

        // 天数为 weeklyDays（源 :53-66）
        assertEquals(3, plan.days.size)
        assertEquals(listOf("day_1", "day_2", "day_3"), plan.days.map { it.dayId }) // :60
        assertEquals(listOf("第 1 天", "第 2 天", "第 3 天"), plan.days.map { it.title }) // :62

        // 焦点肌群按可用列表轮换：chest, back, chest（源 pickFocusMuscleId :142）
        assertEquals(
            listOf("muscle_chest", "muscle_back", "muscle_chest"),
            plan.days.map { it.focusMuscleIds.single() },
        )

        // 每日动作数不超过源上限 3（源 MAX_EXERCISES_PER_DAY :29、:109）
        assertTrue(plan.days.all { it.exercises.size <= 3 })
        assertEquals(listOf(3, 2, 3), plan.days.map { it.exercises.size })

        // 每日动作不重复（源逐条取排序后候选，无重复条目）
        plan.days.forEach { day ->
            val ids = day.exercises.map { it.exerciseId }
            assertEquals("第 ${day.dayOfWeek} 天有重复动作", ids.size, ids.toSet().size)
        }

        // 第 1 天取分数最高的 3 条；98 分并列按 exerciseId 升序（源 :243/:248-253）
        assertEquals(
            listOf("chest-a", "chest-b", "chest-c"),
            plan.days[0].exercises.map { it.exerciseId },
        )
        // 第 2 天只有 2 条背部候选
        assertEquals(listOf("back-e", "back-f"), plan.days[1].exercises.map { it.exerciseId })

        // 处方字段取自规则表（源 buildPlannedExercises :118-124）
        val first = plan.days[0].exercises.first()
        assertEquals("planned_1_1", first.plannedExerciseId) // :116
        assertEquals(3, first.targetSets)
        assertEquals("8-12", first.targetReps)
        assertEquals("控制节奏，保留 1-2 次余力", first.intensityNote)
        assertEquals(listOf("alt1"), first.alternativeExerciseIds) // :121
        assertEquals("planned_1_2", plan.days[0].exercises[1].plannedExerciseId)

        // 同输入两次调用 → 结果完全相等（确定性）
        assertEquals(plan, generatePlan(goal(weeklyDays = 3), deterministicExercises()))
    }

    /** 焦点肌群循环会在跨天重复：dayIndex % 可用数（源 :142），第 3 天回到胸部。 */
    @Test
    fun `焦点肌群每两天一循环使首日与第三日相同`() {
        val plan = generatePlan(goal(weeklyDays = 3), deterministicExercises())
        assertEquals(
            plan.days[0].exercises.map { it.exerciseId },
            plan.days[2].exercises.map { it.exerciseId },
        )
    }

    @Test
    fun `主肌群候选排在次肌群候选之前`() {
        val exercises = listOf(
            exercise("pri", primary = listOf("muscle_chest")), // 40+30+20+8 = 98
            exercise("sec", primary = listOf("muscle_shoulders"), secondary = listOf("muscle_chest")), // 88
        )
        val plan = generatePlan(goal(weeklyDays = 1), exercises)
        assertEquals(listOf("pri", "sec"), plan.days[0].exercises.map { it.exerciseId })
    }

    @Test
    fun `同分时替代动作更多的候选排前`() {
        val exercises = listOf(
            exercise("alt-short", alternatives = listOf("a")), // 100
            exercise("alt-long", alternatives = listOf("x", "y", "z")), // 100
        )
        val plan = generatePlan(goal(weeklyDays = 1), exercises)
        assertEquals(listOf("alt-long", "alt-short"), plan.days[0].exercises.map { it.exerciseId })
    }

    @Test
    fun `同分同替代数时按动作 id 升序`() {
        val exercises = listOf(
            exercise("b-ex"),
            exercise("a-ex"),
        )
        val plan = generatePlan(goal(weeklyDays = 1), exercises)
        assertEquals(listOf("a-ex", "b-ex"), plan.days[0].exercises.map { it.exerciseId })
    }

    // ── ③ 逐级放宽策略（源 findScoredCandidates :152-164） ────────

    @Test
    fun `难度无精确匹配时降到放宽难度并带对应说明`() {
        val exercises = listOf(
            exercise("ex-b", difficulty = "beginner"), // 目标等级 advanced → 难度不符
        )
        val plan = generatePlan(goal(level = "advanced", weeklyDays = 1), exercises)
        assertEquals(1, plan.days[0].exercises.size)
        assertEquals(
            "已放宽难度：未找到完全匹配动作，优先保留目标、器械和肌群。", // 源 :32 / :158
            plan.days[0].exercises[0].selectionNote,
        )
    }

    @Test
    fun `器械无匹配时降到放宽器械并带对应说明`() {
        val exercises = listOf(
            exercise("ex-b", equipment = listOf("eq_barbell"), difficulty = "beginner"), // 器械与难度均不符
        )
        val plan = generatePlan(
            goal(level = "advanced", equipmentIds = listOf("eq_machine"), weeklyDays = 1),
            exercises,
        )
        assertEquals(1, plan.days[0].exercises.size)
        assertEquals(
            "已放宽器械：未找到可用器械动作，请在执行前确认替代器械。", // 源 :33 / :163
            plan.days[0].exercises[0].selectionNote,
        )
    }

    @Test
    fun `器械全匹配时取精确匹配说明`() {
        val exercises = listOf(exercise("ex-b")) // eq_barbell + beginner 全中
        val plan = generatePlan(goal(weeklyDays = 1), exercises)
        assertEquals(
            "精确匹配：目标、器械、肌群和难度均匹配。", // 源 :31 / :153
            plan.days[0].exercises[0].selectionNote,
        )
    }

    @Test
    fun `空器械回落自重且只精确匹配自重动作`() {
        // 源 normalizeEquipmentIds :262-268：空列表 → ['eq_bodyweight']
        val exercises = listOf(
            exercise("bw", equipment = listOf("eq_bodyweight")),
            exercise("bb", equipment = listOf("eq_barbell")), // 与自重无交集 → 精确匹配落空
        )
        val plan = generatePlan(goal(equipmentIds = emptyList(), weeklyDays = 1), exercises)
        assertEquals(listOf("bw"), plan.days[0].exercises.map { it.exerciseId })
        assertEquals(
            "精确匹配：目标、器械、肌群和难度均匹配。",
            plan.days[0].exercises[0].selectionNote,
        )
    }

    // ── 边界与注入 ────────────────────────────────────────────────

    @Test
    fun `受限肌群被排除出可用焦点`() {
        val exercises = listOf(
            exercise("chest-x"),
            exercise("back-x", primary = listOf("muscle_back")),
        )
        val plan = generatePlan(goal(weeklyDays = 1, restrictedMuscleIds = listOf("muscle_chest")), exercises)
        assertEquals(listOf("muscle_back"), plan.days[0].focusMuscleIds) // 源 containsRestrictedMuscle :273
        assertEquals(listOf("back-x"), plan.days[0].exercises.map { it.exerciseId })
    }

    @Test
    fun `无候选时焦点回落到全量焦点表`() {
        // 源 pickFocusMuscleId 空列表分支 :144：FOCUS_MUSCLE_IDS[dayIndex % 6]
        val plan = generatePlan(goal(weeklyDays = 2), emptyList())
        assertEquals(2, plan.days.size)
        assertEquals(listOf("muscle_chest"), plan.days[0].focusMuscleIds)
        assertEquals(listOf("muscle_back"), plan.days[1].focusMuscleIds)
        assertTrue(plan.days.all { it.exercises.isEmpty() })
    }

    @Test
    fun `周天数夹到 0 到 7`() {
        // 源 normalizeWeeklyDays :79-87
        assertEquals(7, generatePlan(goal(weeklyDays = 10), emptyList()).days.size)
        assertEquals(0, generatePlan(goal(weeklyDays = -1), emptyList()).days.size)
        assertEquals(0, generatePlan(goal(weeklyDays = 0), emptyList()).days.size)
    }

    @Test
    fun `未知目标类型回落到规则表首条`() {
        // 源 findRule :96 return SEED_PLAN_RULES[0]
        val plan = generatePlan(goal(goalType = "unknown", weeklyDays = 1), emptyList())
        assertEquals("增肌基础计划", plan.name)
        assertEquals(4, plan.cycleWeeks)
    }

    @Test
    fun `注入自定义规则表时生效且 generatedBy 不变`() {
        val custom = listOf(PlanRule("hypertrophy", "自定义计划", 6, 4, "6-8", "备注"))
        val plan = generatePlan(goal(weeklyDays = 1), listOf(exercise("only")), rules = custom)
        assertEquals("自定义计划", plan.name)
        assertEquals(6, plan.cycleWeeks)
        assertEquals("rule_v1", plan.generatedBy)
        val planned = plan.days[0].exercises.single()
        assertEquals(4, planned.targetSets)
        assertEquals("6-8", planned.targetReps)
        assertEquals("备注", planned.intensityNote)
    }
}

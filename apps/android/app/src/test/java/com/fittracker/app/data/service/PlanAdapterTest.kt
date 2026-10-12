package com.fittracker.app.data.service

import android.content.Context
import androidx.datastore.preferences.core.PreferenceDataStoreFactory
import androidx.test.core.app.ApplicationProvider
import com.fittracker.app.data.model.ExerciseContent
import com.fittracker.app.data.model.ExerciseRef
import com.fittracker.app.data.model.PlanDay
import com.fittracker.app.data.model.PlannedExercise
import com.fittracker.app.data.model.TrainingDay
import com.fittracker.app.data.model.TrainingPlan
import com.fittracker.app.data.model.UserGoal
import com.fittracker.app.data.model.UserPlan
import com.fittracker.app.data.persist.JsonStore
import java.io.File
import java.util.concurrent.atomic.AtomicInteger
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * [PlanAdapter] 契约测试（Wave 5 · B4，训练偏好 → 计划生成链）。
 *
 * 覆盖：① 偏好 → `UserGoal` 映射全字段（含既有目标 id / createdAt 保留）；② 目标 id 与
 * `SeedPlanRules.goalType` 口径一致（防契约漂移）；③ `TrainingPlan` → `UserPlan` 字段映射；
 * ④ 天→星期分配 [PlanAdapter] 的 `DAY_ASSIGNMENT` 2..7 全档；⑤ 动作名 / 肌群解析兜底；
 * ⑥ 同 id 覆盖 + 用户手动启用的其他计划不受影响；⑦ 端到端链路——
 * `generateAndEnablePlan` 后 `getCurrentPlan` 非空、id 正确、今日训练命中分配日。
 *
 * `@Config(sdk = [34])`：项目 targetSdk 37 超出 Robolectric 4.16 支持范围，必须钉到受支持 SDK。
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34], qualifiers = "zh-rCN") // 肌肉/器械名 locale 化后：中文语义断言需钉 zh 区域
class PlanAdapterTest {

    @get:Rule
    val tempFolder: TemporaryFolder = TemporaryFolder()

    private val counter = AtomicInteger()

    private val context: Context get() = ApplicationProvider.getApplicationContext()

    private fun createStore(): JsonStore {
        val file = File(tempFolder.root, "plan_adapter_${counter.incrementAndGet()}.preferences_pb")
        val dataStore = PreferenceDataStoreFactory.create(
            scope = CoroutineScope(Dispatchers.IO + SupervisorJob()),
        ) { file }
        return JsonStore(dataStore)
    }

    /** 内容库单例需装载后方能解析肌群中文名；仓储单例跨用例存活，逐例复位。 */
    @Before
    fun setUp() {
        TrainingPlanRepository.clearLocal()
        GoalRepository.clearLocal()
        runBlocking { ContentRepository.load(context) }
    }

    // ── 测试脚手架 ────────────────────────────────────────────────

    private fun preferences(
        goal: PrefGoal = PrefGoal.MUSCLE_GAIN,
        level: PrefLevel = PrefLevel.INTERMEDIATE,
        daysPerWeek: Int = 3,
        sessionMinutes: Int = 45,
        equipmentIds: Set<String> = setOf("eq_bodyweight", "eq_dumbbell"),
        restrictedMuscleIds: Set<String> = emptySet(),
    ): FtTrainingPreferences = FtTrainingPreferences(
        goal = goal,
        level = level,
        daysPerWeek = daysPerWeek,
        sessionMinutes = sessionMinutes,
        equipmentIds = equipmentIds,
        restrictedMuscleIds = restrictedMuscleIds,
    )

    private fun goal(level: String = "intermediate"): UserGoal = UserGoal(
        goalId = "goal_test",
        goalType = "hypertrophy",
        level = level,
        weeklyDays = 3,
        sessionMinutes = 45,
        equipmentIds = listOf("eq_dumbbell"),
        restrictedMuscleIds = emptyList(),
        createdAt = 100,
        updatedAt = 200,
    )

    private fun exercise(
        id: String,
        nameZh: String = "动作-$id",
        primary: List<String> = listOf("muscle_chest"),
    ): ExerciseContent = ExerciseContent(
        exerciseId = id,
        nameZh = nameZh,
        nameEn = "Exercise $id",
        aliases = emptyList(),
        primaryMuscleIds = primary,
        secondaryMuscleIds = emptyList(),
        equipmentIds = listOf("eq_dumbbell"),
        difficulty = "intermediate",
        goalTags = listOf("hypertrophy"),
        videoUrl = "",
        coverUrl = "",
        coverSourceLabel = "",
        videoSourceLabel = "",
        mediaLicenseText = "",
        steps = emptyList(),
        cues = emptyList(),
        commonMistakes = emptyList(),
        safetyNotes = emptyList(),
        alternativeExerciseIds = emptyList(),
        contentVersion = 1,
    )

    private fun trainingPlan(dayCount: Int, exerciseId: String = "ex_1"): TrainingPlan = TrainingPlan(
        planId = "plan_goal_test",
        goalId = "goal_test",
        name = "增肌基础计划",
        cycleWeeks = 4,
        days = (1..dayCount).map { dayNumber ->
            PlanDay(
                dayId = "day_$dayNumber",
                dayOfWeek = dayNumber,
                title = "第 $dayNumber 天",
                focusMuscleIds = listOf("muscle_chest"),
                exercises = listOf(
                    PlannedExercise(
                        plannedExerciseId = "planned_${dayNumber}_1",
                        exerciseId = exerciseId,
                        targetSets = 3,
                        targetReps = "8-12",
                        intensityNote = "控制节奏",
                        alternativeExerciseIds = emptyList(),
                    ),
                ),
            )
        },
        generatedBy = "rule_v1",
        status = "active",
    )

    // ── ① 偏好 → UserGoal ─────────────────────────────────────────

    @Test
    fun `偏好映射目标全字段（无既有目标）`() {
        val mapped = PlanAdapter.preferencesToGoal(
            preferences(
                goal = PrefGoal.FAT_LOSS,
                level = PrefLevel.ADVANCED,
                daysPerWeek = 5,
                sessionMinutes = 60,
                equipmentIds = setOf("eq_barbell"),
                restrictedMuscleIds = setOf("muscle_back"),
            ),
            previous = null,
            now = 1_700_000_000_000,
        )

        assertEquals("goal_1700000000000", mapped.goalId)
        assertEquals("fat_loss", mapped.goalType)
        assertEquals("advanced", mapped.level)
        assertEquals(5, mapped.weeklyDays)
        assertEquals(60, mapped.sessionMinutes)
        assertEquals(listOf("eq_barbell"), mapped.equipmentIds)
        assertEquals(listOf("muscle_back"), mapped.restrictedMuscleIds)
        assertEquals(1_700_000_000_000, mapped.createdAt)
        assertEquals(1_700_000_000_000, mapped.updatedAt)
    }

    @Test
    fun `偏好映射保留既有 goalId 与 createdAt`() {
        val previous = goal(level = "beginner").copy(createdAt = 1_600_000_000_000)

        val mapped = PlanAdapter.preferencesToGoal(
            preferences(goal = PrefGoal.STRENGTH, level = PrefLevel.ADVANCED),
            previous = previous,
            now = 1_700_000_000_000,
        )

        assertEquals("goal_test", mapped.goalId) // id 稳定 → 生成计划覆盖自身
        assertEquals(1_600_000_000_000, mapped.createdAt)
        assertEquals(1_700_000_000_000, mapped.updatedAt)
        assertEquals("strength", mapped.goalType)
        assertEquals("advanced", mapped.level)
    }

    @Test
    fun `偏好目标 id 全部落在 SeedPlanRules 口径内`() {
        val ruleGoalTypes = SeedPlanRules.ALL.map { it.goalType }
        PrefGoal.values().forEach { prefGoal ->
            assertTrue("${prefGoal.id} 不在 SeedPlanRules.goalType 中", prefGoal.id in ruleGoalTypes)
        }
        assertEquals(listOf("hypertrophy", "strength", "fat_loss"), PrefGoal.values().map { it.id })
    }

    @Test
    fun `经验 id 全部落在动作库 difficulty 口径内`() {
        val difficulties = ContentRepository.exercises().map { it.difficulty }.toSet()
        PrefLevel.values().forEach { level ->
            assertTrue("${level.id} 不在内容库 difficulty 中", level.id in difficulties)
        }
    }

    // ── ② TrainingPlan → UserPlan 字段映射 ───────────────────────

    @Test
    fun `生成计划转用户计划字段映射`() {
        val converted = PlanAdapter.trainingPlanToUserPlan(
            plan = trainingPlan(dayCount = 3, exerciseId = "ex_chest"),
            goal = goal(level = "intermediate"),
            exercises = listOf(exercise("ex_chest", nameZh = "哑铃卧推", primary = listOf("muscle_chest"))),
            now = 500,
        )

        assertEquals("plan_goal_test", converted.id)
        assertEquals("增肌基础计划", converted.name)
        assertEquals(PlanAdapter.DEFAULT_GENERATED_COVER, converted.coverColor)
        assertEquals("进阶", converted.targetAudience)
        assertEquals("3 天 / 周", converted.weeklyFrequency)
        assertEquals(PlanAdapter.GENERATED_DESCRIPTION, converted.description)
        assertEquals(500, converted.enabledAt)
        assertEquals(3, converted.days.size)
        assertEquals("第 1 天", converted.days[0].dayLabel)
        assertEquals(listOf(1), converted.days[0].dayOfWeek)
        assertEquals(ExerciseRef("哑铃卧推", "胸部", 3, "8-12"), converted.days[0].exercises[0])
    }

    @Test
    fun `适合人群随经验档变化`() {
        fun audienceOf(level: String): String = PlanAdapter.trainingPlanToUserPlan(
            plan = trainingPlan(dayCount = 2),
            goal = goal(level = level),
            exercises = listOf(exercise("ex_1")),
            now = 1,
        ).targetAudience

        assertEquals("新手", audienceOf("beginner"))
        assertEquals("进阶", audienceOf("intermediate"))
        assertEquals("熟练", audienceOf("advanced"))
    }

    // ── ③ 天→星期分配 2..7 全档 ──────────────────────────────────

    @Test
    fun `天到星期分配覆盖 2 至 7 全档`() {
        val expected = mapOf(
            2 to listOf(1, 4),
            3 to listOf(1, 3, 5),
            4 to listOf(1, 2, 4, 5),
            5 to listOf(1, 2, 3, 4, 5),
            6 to listOf(1, 2, 3, 4, 5, 6),
            7 to listOf(1, 2, 3, 4, 5, 6, 0),
        )

        expected.forEach { (dayCount, slots) ->
            val converted = PlanAdapter.trainingPlanToUserPlan(
                plan = trainingPlan(dayCount = dayCount),
                goal = goal(),
                exercises = listOf(exercise("ex_1")),
                now = 1,
            )
            assertEquals("$dayCount 天档分配", slots, converted.days.map { it.dayOfWeek?.single() })
        }
    }

    // ── ④ 名称 / 肌群解析兜底 ────────────────────────────────────

    @Test
    fun `动作缺失回落 exerciseId_无主肌群回落空串`() {
        val converted = PlanAdapter.trainingPlanToUserPlan(
            plan = trainingPlan(dayCount = 2, exerciseId = "ex_missing"),
            goal = goal(),
            exercises = emptyList(),
            now = 1,
        )

        assertEquals("ex_missing", converted.days[0].exercises[0].name)
        assertEquals("", converted.days[0].exercises[0].targetMuscle)
    }

    @Test
    fun `动作无主肌群回落空串`() {
        val converted = PlanAdapter.trainingPlanToUserPlan(
            plan = trainingPlan(dayCount = 2, exerciseId = "ex_nomuscle"),
            goal = goal(),
            exercises = listOf(exercise("ex_nomuscle", nameZh = "平板支撑", primary = emptyList())),
            now = 1,
        )

        assertEquals("平板支撑", converted.days[0].exercises[0].name)
        assertEquals("", converted.days[0].exercises[0].targetMuscle)
    }

    // ── ⑤ 同 id 覆盖 + 其他计划保留 ──────────────────────────────

    @Test
    fun `重复保存同 id 覆盖且不影响手动启用的计划`() = runBlocking {
        val store = createStore()
        val manual = UserPlan(
            id = "user_plan_manual",
            name = "自定义计划",
            coverColor = "#E53935",
            targetAudience = "新手",
            weeklyFrequency = "2 天 / 周",
            description = "手动启用",
            days = listOf(
                TrainingDay(
                    dayLabel = "上肢",
                    dayOfWeek = listOf(1),
                    exercises = listOf(ExerciseRef("哑铃卧推", "胸部", 3, "8-12")),
                ),
            ),
            enabledAt = 1,
        )
        TrainingPlanRepository.replaceMyPlans(store, listOf(manual), manual.id)

        assertTrue(PlanAdapter.generateAndEnablePlan(context, store, preferences(daysPerWeek = 3)))
        val afterFirst = TrainingPlanRepository.getMyPlans(store)
        assertEquals(2, afterFirst.size) // 手动计划 + 生成计划
        assertTrue(afterFirst.any { it.id == manual.id })

        val generatedId = TrainingPlanRepository.getCurrentPlanId(store)
        assertTrue(PlanAdapter.generateAndEnablePlan(context, store, preferences(daysPerWeek = 5)))
        val afterSecond = TrainingPlanRepository.getMyPlans(store)
        assertEquals(2, afterSecond.size) // 同 id 覆盖，不新增
        assertEquals(generatedId, TrainingPlanRepository.getCurrentPlanId(store))
    }

    // ── ⑥ 端到端链路 ─────────────────────────────────────────────

    @Test
    fun `生成并启用后当前计划可见且今日训练命中`() = runBlocking {
        val store = createStore()
        val prefs = preferences(goal = PrefGoal.MUSCLE_GAIN, level = PrefLevel.BEGINNER, daysPerWeek = 3)

        assertTrue(PlanAdapter.generateAndEnablePlan(context, store, prefs))

        // 真机回归（2026-10-12）：内容库未加载时曾生成「空动作计划」——生成前 ensureLoaded 后每天必须有动作
        val generated = TrainingPlanRepository.getCurrentPlan(store)!!
        assertTrue("生成计划每天应有动作", generated.days.all { it.exercises.isNotEmpty() })

        // 偏好已落库
        assertEquals(prefs, TrainingPreferencesService.loadPreferences(store))

        // 目标已落库且口径一致
        val savedGoal = GoalRepository.loadGoal(store)
        assertNotNull(savedGoal)
        assertEquals("hypertrophy", savedGoal!!.goalType)
        assertEquals("beginner", savedGoal.level)
        assertEquals(3, savedGoal.weeklyDays)

        // 当前计划可见，id 稳定为 plan_<goalId>
        val current = TrainingPlanRepository.getCurrentPlan(store)
        assertNotNull(current)
        val currentId = TrainingPlanRepository.getCurrentPlanId(store)
        assertEquals(currentId, current!!.id)
        assertTrue("id 应为 plan_goal_ 前缀：$currentId", currentId.startsWith("plan_goal_"))
        assertEquals(3, current.days.size)

        // 今日训练按 D-5 分配命中（3 天档 = 周一 / 周三 / 周五）
        assertNotNull(TrainingPlanRepository.getTodayTraining(current, todayOfWeek = 1))
        assertNotNull(TrainingPlanRepository.getTodayTraining(current, todayOfWeek = 3))
        assertNotNull(TrainingPlanRepository.getTodayTraining(current, todayOfWeek = 5))
        assertNull(TrainingPlanRepository.getTodayTraining(current, todayOfWeek = 0))
    }
}

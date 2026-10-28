package com.fittracker.app.data.service

import androidx.datastore.preferences.core.PreferenceDataStoreFactory
import com.fittracker.app.data.model.ExerciseRef
import com.fittracker.app.data.model.TrainingDay
import com.fittracker.app.data.model.UserPlan
import com.fittracker.app.data.model.WorkoutSession
import com.fittracker.app.data.model.WorkoutSet
import com.fittracker.app.data.persist.JsonStore
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
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
import java.io.File
import java.util.concurrent.atomic.AtomicInteger

/**
 * Wave 3 训练计划仓储（[PresetPlans] / [TrainingPlanRepository]）与训练会话服务
 * （[WorkoutSessionService]）的契约测试。
 *
 * 测试手段照 `RepositoriesTest` / `JsonStoreTest`：以 [PreferenceDataStoreFactory] 把每个用例的
 * 存储指向独立临时文件（互不污染、不触真实应用存储）。
 *
 * `@Config(sdk = [34])`：项目 targetSdk 37 超出 Robolectric 4.16 支持范围，必须钉到受支持
 * SDK（原因同 `JsonStoreTest`）。
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class SessionAndPlanTest {

    @get:Rule
    val tempFolder: TemporaryFolder = TemporaryFolder()

    private val counter = AtomicInteger()

    private fun createStore(): JsonStore {
        val file = File(tempFolder.root, "session_plan_${counter.incrementAndGet()}.preferences_pb")
        val dataStore = PreferenceDataStoreFactory.create(
            scope = CoroutineScope(Dispatchers.IO + SupervisorJob()),
        ) { file }
        return JsonStore(dataStore)
    }

    /** [TrainingPlanRepository] 单例在 JVM 内跨用例存活——每例前清内存回落缓存，避免串场。 */
    @Before
    fun resetSingletonState() {
        TrainingPlanRepository.clearLocal()
    }

    private fun samplePlan(id: String, name: String): UserPlan = UserPlan(
        id = id,
        name = name,
        coverColor = "#43A047",
        targetAudience = "初中级健身者",
        weeklyFrequency = "4 天/周",
        description = "测试计划",
        days = listOf(
            TrainingDay(
                dayLabel = "上肢A",
                dayOfWeek = listOf(1),
                exercises = listOf(ExerciseRef("杠铃平板卧推", "胸部", 4, "8-12")),
            ),
            TrainingDay(
                dayLabel = "下肢A",
                dayOfWeek = listOf(2),
                exercises = listOf(ExerciseRef("杠铃深蹲", "腿部", 4, "8-12")),
            ),
        ),
        enabledAt = 1_759_000_000_000,
    )

    /** 模型统一（2026-10-03 整合）后的会话构造：扁平 sets 的 [WorkoutSession]。 */
    private fun modelSession(
        id: String,
        startedAt: Long,
        durationSeconds: Int,
        sets: List<WorkoutSet>,
    ): WorkoutSession = WorkoutSession(
        sessionId = id,
        planId = "plan-1",
        dayId = "上肢A",
        startedAt = startedAt,
        endedAt = startedAt + durationSeconds * 1000L,
        durationSeconds = durationSeconds,
        totalSets = sets.size,
        totalVolume = 0.0,
        fatigueScore = 0.0,
        notes = "",
        sets = sets,
    )

    private fun wset(
        id: String,
        exerciseId: String,
        weight: Double,
        reps: Int,
        warmup: Boolean = false,
    ): WorkoutSet = WorkoutSet(
        setId = id,
        exerciseId = exerciseId,
        weight = weight,
        reps = reps,
        rpe = 0.0,
        isWarmup = warmup,
    )

    // --- PresetPlans ---------------------------------------------------------

    @Test
    fun `预置计划四套_名字_id_天数对齐源`() {
        assertEquals(4, PresetPlans.count())
        assertEquals(
            listOf("二分化（上下肢）", "三分化 · 谭成义", "四分化", "五分化"),
            PresetPlans.ALL.map { it.name },
        )
        assertEquals(
            listOf("preset_upper_lower", "preset_ppl", "preset_split_4", "preset_bro_split"),
            PresetPlans.ALL.map { it.id },
        )
        // 源各套训练日数：4 / 3 / 4 / 5
        assertEquals(listOf(4, 3, 4, 5), PresetPlans.ALL.map { it.days.size })
    }

    @Test
    fun `预置计划字段完整_动作清单非空`() {
        PresetPlans.ALL.forEach { plan ->
            assertTrue("计划名非空", plan.name.isNotBlank())
            assertTrue("封面色为 #RRGGBB", Regex("^#[0-9A-Fa-f]{6}$").matches(plan.coverColor))
            assertTrue("目标人群非空", plan.targetAudience.isNotBlank())
            assertTrue("频率非空", plan.weeklyFrequency.isNotBlank())
            assertTrue("描述非空", plan.description.isNotBlank())
            assertTrue("至少一天", plan.days.isNotEmpty())

            plan.days.forEach { day ->
                assertTrue("训练日标签非空", day.dayLabel.isNotBlank())
                assertFalse("训练日 dayOfWeek 已分配", day.dayOfWeek.isNullOrEmpty())
                assertTrue("训练日至少一个动作", day.exercises.isNotEmpty())
                day.exercises.forEach { exercise ->
                    assertTrue("动作名非空", exercise.name.isNotBlank())
                    assertTrue("目标肌群非空", exercise.targetMuscle.isNotBlank())
                    assertTrue("组数为正", exercise.sets > 0)
                    assertTrue("次数区间非空", exercise.reps.isNotBlank())
                }
            }
        }

        // 每套计划动作总数 = 天数 × 5（源每训练日恒 5 个动作）
        PresetPlans.ALL.forEach { plan ->
            plan.days.forEach { day -> assertEquals(5, day.exercises.size) }
        }
    }

    // --- TrainingPlanRepository ---------------------------------------------

    @Test
    fun `我的计划存取往返全等_清缓存后真读盘`() = runBlocking {
        val store = createStore()
        val plan = samplePlan("user_plan_1", "二分化（上下肢）")
        TrainingPlanRepository.replaceMyPlans(store, listOf(plan), plan.id)

        // 清内存回落缓存，强制从 DataStore 读回——验证的是落盘而非缓存。
        TrainingPlanRepository.clearLocal()
        assertEquals(listOf(plan), TrainingPlanRepository.getMyPlans(store))
        assertEquals(plan.id, TrainingPlanRepository.getCurrentPlanId(store))
        assertEquals(plan, TrainingPlanRepository.getCurrentPlan(store))
        assertTrue(TrainingPlanRepository.hasMyPlans(store))
    }

    @Test
    fun `当前指针_不在列表时回退首个_空列表回退空串`() = runBlocking {
        val store = createStore()
        val p1 = samplePlan("user_plan_1", "A")
        val p2 = samplePlan("user_plan_2", "B")

        TrainingPlanRepository.replaceMyPlans(store, listOf(p1, p2), "not-in-list")
        TrainingPlanRepository.clearLocal()
        assertEquals("user_plan_1", TrainingPlanRepository.getCurrentPlanId(store))

        TrainingPlanRepository.replaceMyPlans(store, emptyList(), "user_plan_1")
        TrainingPlanRepository.clearLocal()
        assertEquals("", TrainingPlanRepository.getCurrentPlanId(store))
        assertNull(TrainingPlanRepository.getCurrentPlan(store))
        assertFalse(TrainingPlanRepository.hasMyPlans(store))
    }

    @Test
    fun `启用预置计划_克隆为我的计划并设为当前_模板不被污染`() = runBlocking {
        val store = createStore()
        val enabled: UserPlan = TrainingPlanRepository.enablePlan(store, "preset_ppl")!!
        assertEquals("三分化 · 谭成义", enabled.name)
        assertTrue(enabled.id.startsWith("user_plan_"))

        TrainingPlanRepository.clearLocal()
        assertEquals(1, TrainingPlanRepository.getMyPlans(store).size)
        assertEquals(enabled.id, TrainingPlanRepository.getCurrentPlanId(store))

        // 预置模板只读：克隆出的计划与模板同名、复制了 days，但 id 不同
        val preset = PresetPlans.getById("preset_ppl")!!
        assertEquals(preset.name, enabled.name)
        assertEquals(preset.days, enabled.days)
        assertTrue(enabled.id != preset.id)
    }

    @Test
    fun `删除当前计划_指针回退剩余首个`() = runBlocking {
        val store = createStore()
        val p1 = samplePlan("user_plan_1", "A")
        val p2 = samplePlan("user_plan_2", "B")
        TrainingPlanRepository.replaceMyPlans(store, listOf(p1, p2), p2.id)

        TrainingPlanRepository.removeMyPlan(store, p2.id)
        TrainingPlanRepository.clearLocal()
        assertEquals(listOf(p1), TrainingPlanRepository.getMyPlans(store))
        assertEquals(p1.id, TrainingPlanRepository.getCurrentPlanId(store))
        assertEquals(p1, TrainingPlanRepository.getCurrentPlan(store))
    }

    @Test
    fun `setCurrentPlan_指向不存在计划时_currentPlan为null`() = runBlocking {
        val store = createStore()
        TrainingPlanRepository.replaceMyPlans(store, listOf(samplePlan("user_plan_1", "A")), "user_plan_1")

        TrainingPlanRepository.setCurrentPlan(store, "user_plan_absent")
        TrainingPlanRepository.clearLocal()
        assertEquals("user_plan_absent", TrainingPlanRepository.getCurrentPlanId(store))
        assertNull(TrainingPlanRepository.getCurrentPlan(store))
    }

    // --- 切换语义回归（真机缺陷「计划组切换功能没用」） -----------------------

    @Test
    fun `重复启用预置计划_落盘恒为单份当前计划`() = runBlocking {
        val store = createStore()

        val first: UserPlan = TrainingPlanRepository.enablePlan(store, "preset_ppl")!!
        val second: UserPlan = TrainingPlanRepository.enablePlan(store, "preset_upper_lower")!!

        // 旧实现每次切换追加一份完整克隆（鸿蒙侧因此撑爆单值上限、写入静默失败）：
        // 现语义「切换 = 整块替换为这一份」，重复切换后落盘只有当前这一份。
        TrainingPlanRepository.clearLocal()
        val plans = TrainingPlanRepository.getMyPlans(store)
        assertEquals(1, plans.size)
        assertEquals(second.id, plans[0].id)
        assertEquals(second.id, TrainingPlanRepository.getCurrentPlanId(store))
        assertEquals("二分化（上下肢）", TrainingPlanRepository.getCurrentPlan(store)!!.name)

        // 内存缓存与落盘一致（防回落缓存谎报旧值）
        assertEquals(1, TrainingPlanRepository.getMyPlans(store).size)
        assertTrue(first.id != second.id)
    }

    @Test
    fun `预置身份解析_克隆副本回查到来源预置id`() = runBlocking {
        val store = createStore()

        // 无当前计划 → 空串
        assertEquals("", TrainingPlanRepository.getCurrentPresetId(store))

        val enabled: UserPlan = TrainingPlanRepository.enablePlan(store, "preset_split_4")!!
        // 克隆 id 是 user_plan_<时间戳>，不是预置 id——身份靠计划名回查预置表
        assertTrue(enabled.id.startsWith("user_plan_"))
        assertEquals("preset_split_4", TrainingPlanRepository.getPresetIdForPlan(enabled))
        assertEquals("preset_split_4", TrainingPlanRepository.getCurrentPresetId(store))

        // 自定义计划（名字不在预置表）→ 空串
        assertEquals(
            "",
            TrainingPlanRepository.getPresetIdForPlan(samplePlan("user_plan_custom", "我的自定义计划")),
        )
    }

    @Test
    fun `replaceMyPlans_重复id副本去重保序`() = runBlocking {
        val store = createStore()
        val p1 = samplePlan("user_plan_1", "A")
        val p2 = samplePlan("user_plan_2", "B")

        TrainingPlanRepository.replaceMyPlans(store, listOf(p1, samplePlan("user_plan_1", "A副本"), p2), p2.id)
        TrainingPlanRepository.clearLocal()

        val plans = TrainingPlanRepository.getMyPlans(store)
        assertEquals(listOf("user_plan_1", "user_plan_2"), plans.map { it.id })
        // 保留首次出现（A，而非 A副本）——读端 firstOrNull 命中不再凭顺序碰运气
        assertEquals("A", plans[0].name)
    }

    // --- WorkoutSessionService ----------------------------------------------

    @Test
    fun `会话写入读回与周统计聚合`() = runBlocking {
        val store = createStore()
        val now = System.currentTimeMillis()
        val today = WorkoutSessionService.formatDate(now)
        val longAgo = WorkoutSessionService.formatDate(now - 20L * 24 * 60 * 60 * 1000)

        val s1 = modelSession(
            id = "s-1",
            startedAt = now,
            durationSeconds = 1800,
            sets = listOf(
                wset("set-1", "bench-press", 60.0, 10),
                wset("set-2", "bench-press", 60.0, 8),
                wset("set-3", "bench-press", 40.0, 10, warmup = true),
            ),
        )
        val s2 = modelSession(
            id = "s-2",
            startedAt = now,
            durationSeconds = 600,
            sets = listOf(wset("set-4", "squat", 100.0, 5)),
        )
        // 周窗口外：无动作明细，仅用于验证「不计入周统计」
        val s3 = modelSession(
            id = "s-3",
            startedAt = now - 20L * 24 * 60 * 60 * 1000,
            durationSeconds = 9999,
            sets = emptyList(),
        )

        // 持久化路径（统一）：WorkoutRepository @ StoreNames.SESSIONS
        WorkoutRepository.saveSession(store, s1)
        WorkoutRepository.saveSession(store, s2)
        WorkoutRepository.saveSession(store, s3)

        // 写入 → 读回
        val all = WorkoutRepository.getSessions(store)
        assertEquals(3, all.size)
        assertEquals(s1, all[0])
        assertEquals(s2, all[1])

        // 周统计：仅本周 2 条；duration=1800+600；sets=2+1；volume=(60×10+60×8)+(100×5)
        assertEquals(
            WeeklyStats(count = 2, duration = 2400, sets = 3, volume = 1580.0),
            WorkoutSessionService.weeklyStats(all, now, WeekStart.MONDAY),
        )

        // 训练日期去重（保首次出现序）
        assertEquals(listOf(today, longAgo), WorkoutSessionService.trainingDates(all))
    }

    @Test
    fun `会话更新_删除_恢复与个人纪录`() = runBlocking {
        val store = createStore()
        val now = System.currentTimeMillis()
        val today = WorkoutSessionService.formatDate(now)
        val s1 = modelSession(
            id = "s-1",
            startedAt = now,
            durationSeconds = 1200,
            sets = listOf(wset("set-1", "bench-press", 60.0, 10)),
        )
        WorkoutRepository.saveSession(store, s1)

        assertTrue(WorkoutRepository.updateSession(store, s1.copy(notes = "已更新")))
        assertEquals("已更新", WorkoutRepository.getSessions(store)[0].notes)
        assertFalse(WorkoutRepository.updateSession(store, s1.copy(sessionId = "absent")))

        val removed = WorkoutRepository.removeSession(store, "s-1")
        assertEquals("s-1", removed?.sessionId)
        assertTrue(WorkoutRepository.getSessions(store).isEmpty())
        assertNull(WorkoutRepository.removeSession(store, "s-1"))

        assertTrue(WorkoutRepository.restoreSession(store, s1))
        assertFalse(WorkoutRepository.restoreSession(store, s1))

        // 个人纪录：Epley 取整，1RM = round(60 × (1 + 10/30)) = 80；名字经 resolver 注入
        val records = WorkoutSessionService.exerciseRecords(WorkoutRepository.getSessions(store)) { id ->
            if (id == "bench-press") "杠铃卧推" else id
        }
        assertEquals(1, records.size)
        val record = records.first()
        assertEquals("杠铃卧推", record.exerciseName)
        assertEquals(80, record.best1RM)
        assertEquals(60.0, record.bestWeight, 0.0)
        assertEquals(10, record.bestReps)
        assertEquals(today, record.bestDate)
    }

    @Test
    fun `空存储_会话读回空_周统计清零`() = runBlocking {
        val store = createStore()
        assertTrue(WorkoutRepository.getSessions(store).isEmpty())
        val empty = WorkoutRepository.getSessions(store)
        assertTrue(WorkoutSessionService.trainingDates(empty).isEmpty())
        assertTrue(WorkoutSessionService.exerciseRecords(empty) { it }.isEmpty())
        assertEquals(
            WeeklyStats(count = 0, duration = 0, sets = 0, volume = 0.0),
            WorkoutSessionService.weeklyStats(empty, System.currentTimeMillis(), WeekStart.MONDAY),
        )
        assertNotNull(store)
    }
}

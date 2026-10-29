package com.fittracker.app.data.service

import androidx.datastore.preferences.core.PreferenceDataStoreFactory
import com.fittracker.app.data.persist.JsonStore
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import java.io.File
import java.util.concurrent.atomic.AtomicInteger

/**
 * Wave 3b 进行中训练链路契约测试——[WorkoutDraftService]（草稿持久化）+ [ActiveWorkoutService]
 * （活跃态引擎）。
 *
 * 覆盖（见任务）：草稿**写入 → 读回 → 清空**；活跃态**开始 / 更新 / 完成**关键路径。
 *
 * 测试手段照 `SessionAndPlanTest`：以 [PreferenceDataStoreFactory] 把每例存储指向独立临时文件
 * （互不污染、不触真实应用存储）。
 *
 * `@Config(sdk = [34])`：项目 targetSdk 37 超出 Robolectric 4.16 支持范围，必须钉到受支持 SDK
 * （原因同 `JsonStoreTest` / `SessionAndPlanTest`）。
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class WorkoutDraftAndActiveTest {

    @get:Rule
    val tempFolder: TemporaryFolder = TemporaryFolder()

    private val counter = AtomicInteger()

    private fun createStore(): JsonStore {
        val file = File(tempFolder.root, "draft_active_${counter.incrementAndGet()}.preferences_pb")
        val dataStore = PreferenceDataStoreFactory.create(
            scope = CoroutineScope(Dispatchers.IO + SupervisorJob()),
        ) { file }
        return JsonStore(dataStore)
    }

    // --- 夹具 ---------------------------------------------------------------

    private fun sampleDraft(): WorkoutDraftSnapshot = WorkoutDraftSnapshot(
        planId = "plan-1",
        planName = "二分化（上下肢）",
        dayLabel = "上肢A",
        startedAt = 1_759_000_000_000L,
        totalTargetSets = 3,
        completedSets = 1,
        currentExerciseName = "杠铃卧推",
        currentExerciseProgress = "1/2",
        exercises = listOf(
            WorkoutExerciseDraft(
                exerciseId = "bench-press",
                name = "杠铃卧推",
                targetMuscle = "胸部",
                targetSets = 2,
                targetReps = "8-12",
                completedSets = 1,
                sets = listOf(
                    WorkoutSetDraft(0, "60", "10", 80.0, "参考 1RM 80 kg", isComplete = true),
                    WorkoutSetDraft(1, "", "", 0.0, "录入重量和次数后显示 1RM", isComplete = false),
                ),
            ),
        ),
        updatedAt = 1_759_000_001_000L,
    )

    private fun samplePreview(): WorkoutPreviewSummary = WorkoutPreviewSummary(
        hasWorkout = true,
        planId = "plan-1",
        dayId = "day-1",
        title = "上肢力量",
        exercises = listOf(
            WorkoutPreviewExercise("pe-1", "bench-press", "杠铃卧推", 2, "8-12", "目标肌群 胸部"),
            WorkoutPreviewExercise("pe-2", "squat", "杠铃深蹲", 1, "5", "目标肌群 腿部"),
        ),
    )

    // --- WorkoutDraftService：写入 → 读回 → 清空 -----------------------------

    @Test
    fun `草稿写入读回清空往返`() = runBlocking {
        val store = createStore()
        assertNull("空存储无草稿", WorkoutDraftService.getDraft(store))

        val snapshot = sampleDraft()
        WorkoutDraftService.saveDraft(store, snapshot)
        assertEquals("读回全等（含内层 sets 深拷贝）", snapshot, WorkoutDraftService.getDraft(store))

        WorkoutDraftService.clearDraft(store)
        assertNull("清空后无草稿", WorkoutDraftService.getDraft(store))
    }

    @Test
    fun `草稿损坏或空串读回null`() = runBlocking {
        val store = createStore()
        store.writeString(WorkoutDraftService.STORE_KEY, "{not-valid-json")
        assertNull("非法 JSON 回落 null", WorkoutDraftService.getDraft(store))

        store.writeString(WorkoutDraftService.STORE_KEY, "")
        assertNull("空串回落 null", WorkoutDraftService.getDraft(store))
    }

    @Test
    fun `草稿进度判定与空快照`() {
        val empty = createEmptyWorkoutDraftSnapshot(1000L)
        assertEquals(1000L, empty.startedAt)
        assertEquals("0/0", empty.currentExerciseProgress)
        assertTrue(empty.exercises.isEmpty())
        assertFalse("空快照无进度", hasWorkoutDraftProgress(empty))

        assertTrue("completedSets>0 即有进度", hasWorkoutDraftProgress(empty.copy(completedSets = 1)))

        // 仅录入文本（未 complete、completedSets=0）也视为有进度
        val textOnly = empty.copy(
            exercises = listOf(
                WorkoutExerciseDraft(
                    exerciseId = "e", name = "n", targetMuscle = "m",
                    targetSets = 1, targetReps = "8", completedSets = 0,
                    sets = listOf(WorkoutSetDraft(0, "60", "", 0.0, "t", isComplete = false)),
                ),
            ),
        )
        assertTrue("文本录入即算进度", hasWorkoutDraftProgress(textOnly))
    }

    // --- ActiveWorkoutService：开始 -----------------------------------------

    @Test
    fun `开始_由预览编译初始状态`() {
        val state = ActiveWorkoutService.createState(samplePreview())
        assertTrue(state.hasWorkout)
        assertEquals("plan-1", state.planId)
        assertEquals("day-1", state.dayId)
        assertEquals("上肢力量", state.title)
        assertEquals(3, state.totalTargetSets) // 2 + 1
        assertEquals(0, state.completedSets)
        assertEquals("杠铃卧推", state.currentExerciseName)
        assertEquals("0/2 正式组", state.currentExerciseSetProgress)
        assertEquals(2, state.exercises[0].sets.size)
        assertFalse(state.exercises[0].sets[0].isComplete)
        assertEquals("录入重量和次数后显示 1RM", state.exercises[0].sets[0].oneRepMaxText)
        assertEquals(0, ActiveWorkoutService.countRecordedSets(state.exercises))
    }

    @Test
    fun `休息日_空预览不产生训练`() {
        val state = ActiveWorkoutService.createState(
            WorkoutPreviewSummary(false, "plan-1", "", "休息日", emptyList()),
        )
        assertFalse(state.hasWorkout)
        assertEquals(0, state.totalTargetSets)
        assertEquals(0, state.completedSets)
        assertEquals("", state.currentExerciseName)
        assertEquals("0/0 正式组", state.currentExerciseSetProgress)
    }

    // --- ActiveWorkoutService：更新 -----------------------------------------

    @Test
    fun `更新_录入组_计数与1RM重算`() {
        val state = ActiveWorkoutService.createState(samplePreview())
        val updated = ActiveWorkoutService.updateSetEntry(state.exercises, "pe-1", 0, "60", "10")

        val ex1 = updated.first { it.plannedExerciseId == "pe-1" }
        assertEquals("命中动作有效组重算", 1, ex1.completedSets)
        val set0 = ex1.sets.first { it.setIndex == 0 }
        assertTrue(set0.isComplete)
        // Epley：round(60 × (1 + 10/30)) = 80
        assertEquals(80.0, set0.estimatedOneRepMax, 0.0)
        assertEquals("参考 1RM 80 kg", set0.oneRepMaxText)

        // 未命中的动作保持原状（completedSets 仍 0）
        assertEquals(0, updated.first { it.plannedExerciseId == "pe-2" }.completedSets)

        // 顶层聚合随之重算
        val next = ActiveWorkoutService.createStateWithProgress(state, updated)
        assertEquals(1, next.completedSets)
        assertEquals("1/2 正式组", next.currentExerciseSetProgress)
        assertEquals(1, ActiveWorkoutService.countRecordedSets(updated))
    }

    @Test
    fun `更新_只改重量或次数`() {
        val state = ActiveWorkoutService.createState(samplePreview())
        val withEntry = ActiveWorkoutService.updateSetEntry(state.exercises, "pe-1", 0, "60", "10")

        val onlyWeight = ActiveWorkoutService.updateSetWeight(withEntry, "pe-1", 0, "70")
        val w = onlyWeight.first { it.plannedExerciseId == "pe-1" }.sets.first { it.setIndex == 0 }
        assertEquals("70", w.weightText)
        assertEquals("10", w.repsText) // 次数沿用

        val onlyReps = ActiveWorkoutService.updateSetReps(onlyWeight, "pe-1", 0, "12")
        val r = onlyReps.first { it.plannedExerciseId == "pe-1" }.sets.first { it.setIndex == 0 }
        assertEquals("70", r.weightText) // 重量沿用
        assertEquals("12", r.repsText)
    }

    @Test
    fun `更新_热身组不计入有效组`() {
        val state = ActiveWorkoutService.createState(samplePreview())
        val withEntry = ActiveWorkoutService.updateSetEntry(state.exercises, "pe-1", 0, "60", "10")
        val warmed = ActiveWorkoutService.updateSetWarmup(withEntry, "pe-1", 0, true)

        val set0 = warmed.first { it.plannedExerciseId == "pe-1" }.sets.first { it.setIndex == 0 }
        assertTrue(set0.isWarmup)
        assertTrue("热身组仍算已记录", set0.isComplete)
        assertEquals("热身组已记录，不参与 PR 与训练量", set0.oneRepMaxText)
        // 有效工作组 = 0（热身被排除）；已记录组 = 1
        assertEquals(0, warmed.first { it.plannedExerciseId == "pe-1" }.completedSets)
        assertEquals(1, ActiveWorkoutService.countRecordedSets(warmed))
    }

    @Test
    fun `更新_追加组`() {
        val state = ActiveWorkoutService.createState(samplePreview())
        val exercises = ActiveWorkoutService.addSetEntry(state.exercises, "pe-1")
        val ex1 = exercises.first { it.plannedExerciseId == "pe-1" }
        assertEquals("targetSets=2 → 追加至 3 组", 3, ex1.sets.size)
        assertEquals(2, ex1.sets.last().setIndex) // getNextSetIndex = 最大 + 1
        assertFalse(ex1.sets.last().isComplete)
        // 未命中动作不变
        assertEquals(1, exercises.first { it.plannedExerciseId == "pe-2" }.sets.size)
    }

    // --- ActiveWorkoutService：完成 -----------------------------------------

    @Test
    fun `完成_会话字段与组记录`() {
        val state = ActiveWorkoutService.createState(samplePreview())
        var exercises = ActiveWorkoutService.updateSetEntry(state.exercises, "pe-1", 0, "60", "10")
        exercises = ActiveWorkoutService.addSetEntry(exercises, "pe-1")
        val progressed = ActiveWorkoutService.createStateWithProgress(state, exercises)

        val session = ActiveWorkoutService.createCompletedSession(
            sessionId = "sess-1",
            state = progressed,
            startedAt = 1000L,
            endedAt = 61000L,
            completedSets = 1, // 遗留形参——实算 1，此处验证入参被忽略
        )

        assertEquals("sess-1", session.sessionId)
        assertEquals("plan-1", session.planId)
        assertEquals("day-1", session.dayId)
        assertEquals(1000L, session.startedAt)
        assertEquals(61000L, session.endedAt)
        assertEquals(60, session.durationSeconds)
        assertEquals(1, session.totalSets)
        assertEquals("训练量 = 60×10", 600.0, session.totalVolume, 0.0)
        assertEquals(0.0, session.fatigueScore, 0.0)
        assertEquals("completed_sets=1;target_sets=3", session.notes)
        assertEquals(1, session.sets.size)

        val set = session.sets.first()
        assertEquals("pe-1_set_1", set.setId)
        assertEquals("bench-press", set.exerciseId)
        assertEquals(60.0, set.weight, 0.0)
        assertEquals(10, set.reps)
        assertFalse(set.isWarmup)
    }

    @Test
    fun `完成_热身组计入组记录但不计训练量`() {
        val state = ActiveWorkoutService.createState(samplePreview())
        var exercises = ActiveWorkoutService.updateSetEntry(state.exercises, "pe-1", 0, "40", "10")
        exercises = ActiveWorkoutService.updateSetWarmup(exercises, "pe-1", 0, true) // 第 1 组转热身
        exercises = ActiveWorkoutService.updateSetEntry(exercises, "pe-1", 1, "60", "8") // 第 2 组正式
        val progressed = ActiveWorkoutService.createStateWithProgress(state, exercises)

        val session = ActiveWorkoutService.createCompletedSession("sess-2", progressed, 0L, 120000L, 0)
        assertEquals("组记录含热身 + 正式", 2, session.sets.size)
        assertEquals("有效工作组仅正式组", 1, session.totalSets)
        assertEquals("训练量排除热身", 480.0, session.totalVolume, 0.0)
        assertEquals(120, session.durationSeconds)
    }

    // --- 提前结束动作（长按「完成」） ---------------------------------------

    @Test
    fun `提前结束动作收缩到已完成组数并重算总组数`() {
        val state = ActiveWorkoutService.createState(samplePreview())
        val before: ActiveWorkoutExercise = state.exercises[0]
        // 做 1 组后提前结束
        val oneSet = ActiveWorkoutService.recordSetFor(state, "pe-1", "40", "10")
        val ended = ActiveWorkoutService.endExercise(oneSet, "pe-1")
        val after: ActiveWorkoutExercise = ended.exercises[0]

        assertEquals("目标收缩到已完成组数", 1, after.targetSets)
        assertEquals(1, after.completedSets)
        assertEquals("未被完成的空组被裁掉", 1, after.sets.size)
        assertTrue(after.sets[0].isComplete)
        // 其它动作不受影响
        assertEquals(before.targetSets, state.exercises[0].targetSets)
        assertEquals(state.exercises[1].targetSets, ended.exercises[1].targetSets)
        // 总组数按新的 targetSets 求和
        assertEquals(ended.exercises.sumOf { it.targetSets }, ended.totalTargetSets)
    }

    @Test
    fun `提前结束已录满动作返回同一实例`() {
        var state = ActiveWorkoutService.createState(samplePreview())
        val target: Int = state.exercises[0].targetSets
        repeat(target) { state = ActiveWorkoutService.recordSetFor(state, "pe-1", "40", "10") }
        val afterEnd = ActiveWorkoutService.endExercise(state, "pe-1")
        assertTrue("已录满时原样返回同一引用", afterEnd === state)
    }

    @Test
    fun `一组未做就提前结束，该动作不再处于未录满状态`() {
        val state = ActiveWorkoutService.createState(samplePreview())
        val ended = ActiveWorkoutService.endExercise(state, "pe-1")
        assertEquals(0, ended.exercises[0].targetSets)
        assertEquals(0, ended.exercises[0].sets.size)
        assertEquals(
            "结束的动作 completedSets 追平 targetSets",
            ended.exercises[0].targetSets,
            ended.exercises[0].completedSets,
        )
    }
}

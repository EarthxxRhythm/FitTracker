package com.fittracker.app.ui.screens.workout

import androidx.datastore.preferences.core.PreferenceDataStoreFactory
import com.fittracker.app.data.model.WorkoutSession
import com.fittracker.app.data.persist.JsonStore
import com.fittracker.app.data.service.ActiveWorkoutExercise
import com.fittracker.app.data.service.ActiveWorkoutSetEntry
import com.fittracker.app.data.service.ActiveWorkoutState
import com.fittracker.app.data.service.WorkoutDraftService
import com.fittracker.app.data.service.WorkoutDraftSnapshot
import com.fittracker.app.data.service.WorkoutExerciseDraft
import com.fittracker.app.data.service.WorkoutRepository
import com.fittracker.app.data.service.WorkoutSetDraft
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
 * 训练收尾契约测试（D2 边缘态兜底）：
 * - [isRecordedDraftResidue]：录满残留草稿的恢复分支新判据；
 * - [recordedSessionOutcome]：收尾查重的命中 / 未命中两条路径（含「同计划同天两场都录满」反例）；
 * - [finalizeRecordedWorkout]：**幂等**——重入时不双写 session，只清草稿。
 *
 * 幂等用例走真实 [JsonStore]（Robolectric + 临时 preferences 文件），
 * 与 `RepositoriesTest` 同一手法：每个用例独立文件，互不串场。
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class FinalizeRecordedWorkoutTest {

    @get:Rule
    val tempFolder: TemporaryFolder = TemporaryFolder()

    private val counter = AtomicInteger()

    private val startedAt: Long = 1_759_000_000_000L

    private fun createStore(): JsonStore {
        val file = File(tempFolder.root, "finalize_${counter.incrementAndGet()}.preferences_pb")
        val dataStore = PreferenceDataStoreFactory.create(
            scope = CoroutineScope(Dispatchers.IO + SupervisorJob()),
        ) { file }
        return JsonStore(dataStore)
    }

    // --- 夹具 ---------------------------------------------------------------

    private fun exercise(id: String, targetSets: Int, completedSets: Int): ActiveWorkoutExercise =
        ActiveWorkoutExercise(
            plannedExerciseId = id,
            exerciseId = id,
            name = id,
            targetSets = targetSets,
            targetReps = "8-10",
            intensityNote = "胸",
            completedSets = completedSets,
            sets = List(targetSets.coerceAtLeast(1)) { index ->
                ActiveWorkoutSetEntry(
                    setIndex = index,
                    weightText = if (index < completedSets) "60" else "",
                    repsText = if (index < completedSets) "10" else "",
                    estimatedOneRepMax = 0.0,
                    oneRepMaxText = "",
                    isWarmup = false,
                    isComplete = index < completedSets,
                )
            },
        )

    private fun stateOf(vararg exercises: ActiveWorkoutExercise): ActiveWorkoutState =
        ActiveWorkoutState(
            hasWorkout = exercises.isNotEmpty(),
            planId = "plan-1",
            dayId = "day-a",
            title = "上肢A",
            totalTargetSets = exercises.sumOf { it.targetSets },
            completedSets = exercises.sumOf { it.completedSets },
            currentExerciseName = exercises.firstOrNull()?.name ?: "",
            currentExerciseSetProgress = "",
            exercises = exercises.toList(),
        )

    /** 整场录满的草稿快照（= 上次收尾被打断后留在盘上的残留形态）。 */
    private fun residueDraft(startedAt: Long = this.startedAt): WorkoutDraftSnapshot =
        WorkoutDraftSnapshot(
            planId = "plan-1",
            planName = "上肢A",
            dayLabel = "day-a",
            startedAt = startedAt,
            totalTargetSets = 2,
            completedSets = 2,
            currentExerciseName = "ex_0",
            currentExerciseProgress = "2/2",
            exercises = listOf(
                WorkoutExerciseDraft(
                    exerciseId = "ex_0",
                    name = "ex_0",
                    targetMuscle = "胸",
                    targetSets = 2,
                    targetReps = "8-10",
                    completedSets = 2,
                    sets = listOf(
                        WorkoutSetDraft(0, "60", "10", 0.0, "", isComplete = true),
                        WorkoutSetDraft(1, "60", "10", 0.0, "", isComplete = true),
                    ),
                ),
            ),
            updatedAt = startedAt,
        )

    private fun sessionOf(
        startedAt: Long,
        totalSets: Int = 2,
        planId: String = "plan-1",
        dayId: String = "day-a",
        sessionId: String = "session_$startedAt",
    ): WorkoutSession = WorkoutSession(
        sessionId = sessionId,
        planId = planId,
        dayId = dayId,
        startedAt = startedAt,
        endedAt = startedAt + 1_800_000L,
        durationSeconds = 1800,
        totalSets = totalSets,
        totalVolume = 1200.0,
        fatigueScore = 6.0,
        notes = "completed_sets=$totalSets;target_sets=2",
        sets = emptyList(),
    )

    private fun fullyRecordedState(): ActiveWorkoutState =
        stateOf(exercise("ex_0", targetSets = 2, completedSets = 2))

    // --- ① 录满残留判据 -----------------------------------------------------

    @Test
    fun `整场录满的草稿被判为残留`() {
        assertTrue(isRecordedDraftResidue(residueDraft()))
    }

    @Test
    fun `未录满 零进度 空动作的草稿都不算残留`() {
        // 未录满：还有组可记 → 应走正常恢复
        val partial = residueDraft().copy(
            totalTargetSets = 4,
            completedSets = 2,
            exercises = listOf(
                WorkoutExerciseDraft(
                    exerciseId = "ex_0",
                    name = "ex_0",
                    targetMuscle = "胸",
                    targetSets = 4,
                    targetReps = "8-10",
                    completedSets = 2,
                    sets = listOf(
                        WorkoutSetDraft(0, "60", "10", 0.0, "", isComplete = true),
                        WorkoutSetDraft(1, "60", "10", 0.0, "", isComplete = true),
                    ),
                ),
            ),
        )
        assertFalse(isRecordedDraftResidue(partial))
        // 零进度 / 空动作：既不是残留，也不是可续练
        assertFalse(isRecordedDraftResidue(residueDraft().copy(totalTargetSets = 0, completedSets = 0)))
        assertFalse(isRecordedDraftResidue(residueDraft().copy(exercises = emptyList())))
    }

    // --- ② 查重命中 ---------------------------------------------------------

    @Test
    fun `同计划同天同 startedAt 判为已落库`() {
        val outcome = recordedSessionOutcome(
            sessions = listOf(sessionOf(startedAt)),
            state = fullyRecordedState(),
            origin = startedAt,
        )
        assertEquals(FinalizeOutcome.ALREADY_RECORDED, outcome)
    }

    @Test
    fun `startedAt 在查重窗口内抖动仍判为已落库`() {
        assertEquals(
            FinalizeOutcome.ALREADY_RECORDED,
            recordedSessionOutcome(
                sessions = listOf(sessionOf(startedAt)),
                state = fullyRecordedState(),
                origin = startedAt + FINALIZE_DEDUPE_WINDOW_MILLIS,
            ),
        )
    }

    // --- ③ 查重未命中 -------------------------------------------------------

    @Test
    fun `空库判为需要落库`() {
        assertEquals(
            FinalizeOutcome.NEEDS_SAVE,
            recordedSessionOutcome(emptyList(), fullyRecordedState(), startedAt),
        )
    }

    /** 反例（高危风险缓解承诺）：同计划同天两场都录满，第二场不能被误判成重复而丢失。 */
    @Test
    fun `同计划同天两场录满时第二场判为需要落库`() {
        val previous = sessionOf(startedAt - 3_600_000L)
        assertEquals(
            FinalizeOutcome.NEEDS_SAVE,
            recordedSessionOutcome(listOf(previous), fullyRecordedState(), startedAt),
        )
    }

    @Test
    fun `换计划或换训练日不命中查重`() {
        assertEquals(
            FinalizeOutcome.NEEDS_SAVE,
            recordedSessionOutcome(
                listOf(sessionOf(startedAt, planId = "plan-2")),
                fullyRecordedState(),
                startedAt,
            ),
        )
        assertEquals(
            FinalizeOutcome.NEEDS_SAVE,
            recordedSessionOutcome(
                listOf(sessionOf(startedAt, dayId = "day-b")),
                fullyRecordedState(),
                startedAt,
            ),
        )
    }

    /** origin 无效（历史数据 startedAt=0）时才退化到「组数录满」辅助判据。 */
    @Test
    fun `origin 无效时退化到组数判据`() {
        assertEquals(
            FinalizeOutcome.ALREADY_RECORDED,
            recordedSessionOutcome(listOf(sessionOf(startedAt, totalSets = 2)), fullyRecordedState(), 0L),
        )
        assertEquals(
            FinalizeOutcome.NEEDS_SAVE,
            recordedSessionOutcome(listOf(sessionOf(startedAt, totalSets = 1)), fullyRecordedState(), 0L),
        )
    }

    // --- ④ 收尾幂等（真实存储） --------------------------------------------

    @Test
    fun `首次收尾落库并清草稿 重入只清草稿不再双写`() = runBlocking {
        val store = createStore()
        val draft = residueDraft()
        WorkoutDraftService.saveDraft(store, draft)
        val state = draftToActiveState(draft)

        finalizeRecordedWorkout(store, state, draft.startedAt)

        val afterFirst = WorkoutRepository.getSessions(store)
        assertEquals(1, afterFirst.size)
        assertEquals(draft.startedAt, afterFirst[0].startedAt)
        assertNull(WorkoutDraftService.getDraft(store))

        // 重入（进程重启后再次进入训练页 / 退出补收尾）：查重命中 → 只清草稿
        finalizeRecordedWorkout(store, state, draft.startedAt)

        assertEquals(1, WorkoutRepository.getSessions(store).size)
        assertNull(WorkoutDraftService.getDraft(store))
    }

    @Test
    fun `本场已落库时收尾不重复写 session`() = runBlocking {
        val store = createStore()
        val draft = residueDraft()
        WorkoutDraftService.saveDraft(store, draft)
        // 先手工落一条本场记录（模拟「上一次收尾已写完 session、clearDraft 前被打断」）
        WorkoutRepository.saveSession(store, sessionOf(draft.startedAt))

        finalizeRecordedWorkout(store, draftToActiveState(draft), draft.startedAt)

        assertEquals(1, WorkoutRepository.getSessions(store).size)
        assertNull(WorkoutDraftService.getDraft(store))
    }
}

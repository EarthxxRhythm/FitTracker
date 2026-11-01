package com.fittracker.app.ui.screens.workout

import androidx.datastore.preferences.core.PreferenceDataStoreFactory
import com.fittracker.app.data.persist.JsonStore
import com.fittracker.app.data.service.ActiveWorkoutExercise
import com.fittracker.app.data.service.ActiveWorkoutService
import com.fittracker.app.data.service.ActiveWorkoutSetEntry
import com.fittracker.app.data.service.ActiveWorkoutState
import com.fittracker.app.data.service.WorkoutDraftService
import com.fittracker.app.data.service.WorkoutRepository
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
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
 * 训练页退出路径（收起 / 返回 / 重入恢复）→ **首页入口可见性** 的端到端落盘契约测试。
 *
 * 与邻居测试的分工（避免重复锁定同一层）：
 * - [CollapseDraftDecisionTest]：只测决策谓词（SKIP / SNAPSHOT / CLEAR 三态判据）；
 * - [FinalizeRecordedWorkoutTest]：只测收尾函数内部（查重判据、窗口抖动、重入不双写）；
 * - 本文件：把两层**接起来**跑——决策执行完、收尾跑完，盘上是什么，用户看到什么。
 *   即首页 CTA 显示「开始训练」还是「继续训练」、悬浮条出不出、回顾页有几条。
 *
 * 入口可见性只断言**唯一读盘口径** [WorkoutDraftService.resumeSnapshot]（`getDraft` +
 * `hasWorkoutDraftProgress`）：首页 CTA、壳层悬浮条（`FtApp.loadResumeDraft`）与训练页重入恢复
 * 三处共用它。若将来某处另拼 `getDraft` 表达式，本文件不会跟着漂。
 *
 * 执行体走**生产函数**：[collapseDraftDecision] → [finalizeRecordedWorkout] / [WorkoutDraftService.saveDraft]，
 * 不在这里复刻 ActiveScreen 的分支内容——否则测的是测试自己的复刻件。
 *
 * 用例对齐工单场景：
 * - ② 有进度收起 → 落草稿 → 入口「继续训练」；
 * - ③ 零组收起 → SKIP 不写盘 → 入口仍「开始训练」；
 * - ④ 整场录满收起 → CLEAR 收尾 → 无幽灵续练入口，session 恰一条；
 * - ⑤ 录满残留态被兜底接管：盘上陈旧录满草稿 → 恢复分支判残留 → 收尾清草稿、历史记录不动、
 *   重入不双写（回顾页仍只有一条本场记录）。
 *
 * 存储桩照 `WorkoutDraftAndActiveTest`：每例独立临时 DataStore 文件；`@Config(sdk = [34])`
 * 因 targetSdk 37 超出 Robolectric 4.16 支持范围。
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class WorkoutExitGateTest {

    @get:Rule
    val tempFolder: TemporaryFolder = TemporaryFolder()

    private val counter = AtomicInteger()

    private val startedAt: Long = 1_759_000_000_000L

    private fun createStore(): JsonStore {
        val file = File(tempFolder.root, "exit_gate_${counter.incrementAndGet()}.preferences_pb")
        val dataStore = PreferenceDataStoreFactory.create(
            scope = CoroutineScope(Dispatchers.IO + SupervisorJob()),
        ) { file }
        return JsonStore(dataStore)
    }

    // --- 夹具 ---------------------------------------------------------------

    /** 按完成组数构造单个动作（sets 内前 doneSets 组为有效完成组）。 */
    private fun exercise(
        id: String,
        targetSets: Int,
        completedSets: Int,
    ): ActiveWorkoutExercise = ActiveWorkoutExercise(
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

    /**
     * 按生产决策执行一次收起落盘，返回实际走的分支。
     *
     * 分支体与 ActiveScreen 的 `requestCollapse` 一一对应：SNAPSHOT → `saveDraft(activeStateToDraft)`；
     * CLEAR → `finalizeRecordedWorkout`；SKIP → 不动盘。
     */
    private suspend fun applyCollapse(store: JsonStore, state: ActiveWorkoutState): CollapseDraftAction {
        val decision = collapseDraftDecision(state, startedAt)
        when (decision) {
            CollapseDraftAction.SNAPSHOT ->
                WorkoutDraftService.saveDraft(store, activeStateToDraft(state, startedAt))
            CollapseDraftAction.CLEAR -> finalizeRecordedWorkout(store, state, startedAt)
            CollapseDraftAction.SKIP -> Unit
        }
        return decision
    }

    // --- ③ 零组收起：入口仍「开始训练」 --------------------------------------

    @Test
    fun `zero completed sets leaves no draft so home still offers start`() = runBlocking {
        val store = createStore()
        val state = stateOf(exercise("ex_0", targetSets = 4, completedSets = 0))

        assertEquals(CollapseDraftAction.SKIP, applyCollapse(store, state))
        assertNull(
            "零组收起不得留下可续练草稿，否则首页会显示「继续训练」这一幽灵入口",
            WorkoutDraftService.resumeSnapshot(store),
        )
    }

    // --- ② 有进度收起：入口「继续训练」且摘要取自草稿 -------------------------

    @Test
    fun `progress collapse leaves resumable draft for home and floating bar`() = runBlocking {
        val store = createStore()
        val state = stateOf(
            exercise("ex_0", targetSets = 2, completedSets = 1),
            exercise("ex_1", targetSets = 2, completedSets = 0),
        )

        assertEquals(CollapseDraftAction.SNAPSHOT, applyCollapse(store, state))

        val resumed = WorkoutDraftService.resumeSnapshot(store)
        assertNotNull("有进度收起 → 首页 CTA 与悬浮条都靠这个口径读到草稿", resumed)
        assertEquals(state.completedSets, resumed!!.completedSets)
        assertEquals(state.totalTargetSets, resumed.totalTargetSets)
        assertEquals(
            "草稿需保留 plan/day 身份，入口点进去才回到同一场训练",
            "plan-1",
            resumed.planId,
        )
    }

    // --- ④ 整场录满收起：无幽灵入口 + session 恰一条 -------------------------

    @Test
    fun `fully recorded collapse clears draft and persists exactly one session`() = runBlocking {
        val store = createStore()
        // 前置：盘上已有一份进度草稿（模拟「做了一部分就收起过」）
        val partial = stateOf(exercise("ex_0", targetSets = 2, completedSets = 1))
        WorkoutDraftService.saveDraft(store, activeStateToDraft(partial, startedAt))
        assertNotNull("前置：盘上确有残留草稿", WorkoutDraftService.resumeSnapshot(store))

        val finished = stateOf(
            exercise("ex_0", targetSets = 2, completedSets = 2),
            exercise("ex_1", targetSets = 1, completedSets = 1),
        )
        assertEquals(CollapseDraftAction.CLEAR, applyCollapse(store, finished))

        assertNull(
            "整场完成不得留下续练入口——否则首页出现点进去是空场的幽灵入口",
            WorkoutDraftService.resumeSnapshot(store),
        )
        val sessions = WorkoutRepository.getSessions(store)
        assertEquals("收尾只写一条 session，回顾页不应出现两条记录", 1, sessions.size)
        assertEquals(3, sessions.single().totalSets)
    }

    // --- ⑤ 录满残留态被兜底接管（ActiveScreen 恢复分支的调用点）-------------

    @Test
    fun `recorded residue draft is taken over on reentry without duplicating history`() = runBlocking {
        val store = createStore()
        // 历史：昨天已完成的一场训练，收尾不得动它
        val history = ActiveWorkoutService.createCompletedSession(
            sessionId = "session_history",
            state = stateOf(exercise("ex_9", targetSets = 1, completedSets = 1)),
            startedAt = startedAt - 86_400_000L,
            endedAt = startedAt - 86_300_000L,
            completedSets = 1,
        )
        WorkoutRepository.saveSession(store, history)

        // 今天：录满残留草稿（上一场收尾没走完，盘上留了全录满快照）
        val finished = stateOf(exercise("ex_0", targetSets = 3, completedSets = 3))
        val residue = activeStateToDraft(finished, startedAt)
        WorkoutDraftService.saveDraft(store, residue)

        // 重入恢复分支：isRecordedDraftResidue 命中 → finalizeRecordedWorkout 兜底接管
        assertTrue("全录满快照必须被判为残留（否则重入会把它当可续练场次）", isRecordedDraftResidue(residue))
        finalizeRecordedWorkout(store, draftToActiveState(residue), residue.startedAt)

        assertNull("残留草稿必须被收尾清掉，否则首页挂着点不进去的续练入口", WorkoutDraftService.resumeSnapshot(store))
        val sessions = WorkoutRepository.getSessions(store)
        assertEquals("历史记录保留 + 本次收尾一条 = 2", 2, sessions.size)
        assertEquals("session_history", sessions.first().sessionId)

        // 幂等：同一场再收一次（重入 / 二次返回）不得追加副本，回顾页仍只有一条本场记录
        finalizeRecordedWorkout(store, draftToActiveState(residue), residue.startedAt)
        assertEquals(
            "重入收尾不得双写——回顾页出现两条同场记录即为数据一致性破裂",
            2,
            WorkoutRepository.getSessions(store).size,
        )
    }
}

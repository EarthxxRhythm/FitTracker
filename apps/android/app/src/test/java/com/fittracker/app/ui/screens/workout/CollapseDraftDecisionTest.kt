package com.fittracker.app.ui.screens.workout

import com.fittracker.app.data.service.ActiveWorkoutExercise
import com.fittracker.app.data.service.ActiveWorkoutSetEntry
import com.fittracker.app.data.service.ActiveWorkoutState
import com.fittracker.app.data.service.WorkoutDraftSnapshot
import com.fittracker.app.data.service.WorkoutExerciseDraft
import com.fittracker.app.data.service.WorkoutSetDraft
import com.fittracker.app.data.service.hasWorkoutDraftProgress
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * 收起训练三态落盘决策 [collapseDraftDecision] 的契约测试。
 *
 * 判据对齐鸿蒙 `ActiveContent.persistDraftOnExit` 的 finished / 零组守卫：
 * - SKIP（不写不删）：startedAt 无效或零完成组；
 * - CLEAR（清残留草稿防幽灵入口）：exercises 非空、总目标组数 > 0 且全部动作录满
 *   （与 ActiveScreen 的 finished 判据 `firstUnfinishedIndex < 0` 同一谓词 `completedSets < targetSets`）；
 * - SNAPSHOT（落快照）：其余有进度状态。
 *
 * 用例⑥是不变量：非 SKIP 分支 ⇔ 快照 hasWorkoutDraftProgress == true，
 * 让「首页接续态判据」与「退出落盘判据」两套口径互相锁定，避免将来分叉。
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class CollapseDraftDecisionTest {

    private val startedAt: Long = 1_759_000_000_000L

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

    private fun stateOf(vararg exercises: ActiveWorkoutExercise): ActiveWorkoutState {
        val completed = exercises.sumOf { it.completedSets }
        val target = exercises.sumOf { it.targetSets }
        return ActiveWorkoutState(
            hasWorkout = exercises.isNotEmpty(),
            planId = "plan-1",
            dayId = "day-a",
            title = "上肢A",
            totalTargetSets = target,
            completedSets = completed,
            currentExerciseName = exercises.firstOrNull()?.name ?: "",
            currentExerciseSetProgress = "",
            exercises = exercises.toList(),
        )
    }

    private fun snapshotOf(state: ActiveWorkoutState): WorkoutDraftSnapshot =
        activeStateToDraft(state, startedAt)

    // --- 用例 ---------------------------------------------------------------

    /** ① 有进度 → SNAPSHOT，且快照被首页接续态判据认可。 */
    @Test
    fun `returns snapshot when there is progress`() {
        val state = stateOf(exercise("ex_0", targetSets = 4, completedSets = 1))
        assertEquals(CollapseDraftAction.SNAPSHOT, collapseDraftDecision(state, startedAt))
        assertTrue(hasWorkoutDraftProgress(snapshotOf(state)))
    }

    /** ② 零完成组 → SKIP（对齐鸿蒙 countCompletedSets<=0 早退）。 */
    @Test
    fun `skips when nothing completed`() {
        val state = stateOf(exercise("ex_0", targetSets = 4, completedSets = 0))
        assertEquals(CollapseDraftAction.SKIP, collapseDraftDecision(state, startedAt))
    }

    /** ③ 全部动作录满 → CLEAR（防幽灵入口）。 */
    @Test
    fun `clears when every exercise is fully recorded`() {
        val state = stateOf(
            exercise("ex_0", targetSets = 2, completedSets = 2),
            exercise("ex_1", targetSets = 3, completedSets = 3),
        )
        assertEquals(CollapseDraftAction.CLEAR, collapseDraftDecision(state, startedAt))
    }

    /** ④ 「跳着做」边界：动作 1 未录满、动作 2 已录满 → SNAPSHOT 而非 CLEAR。 */
    @Test
    fun `jumping ahead does not read as fully done`() {
        val state = stateOf(
            exercise("ex_0", targetSets = 4, completedSets = 1),
            exercise("ex_1", targetSets = 2, completedSets = 2),
        )
        assertEquals(CollapseDraftAction.SNAPSHOT, collapseDraftDecision(state, startedAt))
    }

    /** ⑤ startedAt 无效 → SKIP（不写出 startedAt=0 的快照）。 */
    @Test
    fun `skips when startedAt is invalid`() {
        val state = stateOf(exercise("ex_0", targetSets = 4, completedSets = 1))
        assertEquals(CollapseDraftAction.SKIP, collapseDraftDecision(state, 0L))
        assertEquals(CollapseDraftAction.SKIP, collapseDraftDecision(state, -1L))
    }

    /** ⑥ 不变量：非 SKIP ⇔ 快照 hasWorkoutDraftProgress == true（双向锁定两套口径）。 */
    @Test
    fun `non-skip decision iff snapshot has progress`() {
        val samples = listOf(
            stateOf(exercise("ex_0", 4, 0)),
            stateOf(exercise("ex_0", 4, 1)),
            stateOf(exercise("ex_0", 4, 4)),
            stateOf(exercise("ex_0", 4, 1), exercise("ex_1", 2, 2)),
            stateOf(),
        )
        for (sample in samples) {
            val decision = collapseDraftDecision(sample, startedAt)
            val hasProgress = hasWorkoutDraftProgress(snapshotOf(sample))
            assertEquals(
                "decision=$decision, hasProgress=$hasProgress, state=${sample.completedSets}/${sample.totalTargetSets}",
                decision != CollapseDraftAction.SKIP,
                hasProgress,
            )
        }
    }

    /** ⑦ 空 exercises → SKIP（SKIP 先于 CLEAR，空状态不进 CLEAR 分支）。 */
    @Test
    fun `skips when exercises list is empty`() {
        val state = stateOf()
        assertEquals(CollapseDraftAction.SKIP, collapseDraftDecision(state, startedAt))
    }

    /** ⑧ 草稿恢复往返：draftToActiveState 后 completedSets 与逐动作求和一致。 */
    @Test
    fun `restored state keeps completedSets consistent with per-exercise sum`() {
        val draft = WorkoutDraftSnapshot(
            planId = "plan-1",
            planName = "上肢A",
            dayLabel = "day-a",
            startedAt = startedAt,
            totalTargetSets = 3,
            completedSets = 2,
            currentExerciseName = "ex_0",
            currentExerciseProgress = "1/2",
            exercises = listOf(
                WorkoutExerciseDraft(
                    exerciseId = "ex_0",
                    name = "ex_0",
                    targetMuscle = "胸",
                    targetSets = 2,
                    targetReps = "8-10",
                    completedSets = 1,
                    sets = listOf(
                        WorkoutSetDraft(0, "60", "10", 0.0, "", isComplete = true),
                        WorkoutSetDraft(1, "", "", 0.0, "", isComplete = false),
                    ),
                ),
                WorkoutExerciseDraft(
                    exerciseId = "ex_1",
                    name = "ex_1",
                    targetMuscle = "胸",
                    targetSets = 1,
                    targetReps = "8-10",
                    completedSets = 1,
                    sets = listOf(WorkoutSetDraft(0, "50", "8", 0.0, "", isComplete = true)),
                ),
            ),
            updatedAt = startedAt,
        )
        val restored = draftToActiveState(draft)
        assertEquals(restored.exercises.sumOf { it.completedSets }, restored.completedSets)
        assertFalse(restored.exercises.isEmpty())
    }
}

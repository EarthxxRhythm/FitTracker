package com.fittracker.app.ui.components

import androidx.datastore.preferences.core.PreferenceDataStoreFactory
import com.fittracker.app.data.persist.JsonStore
import com.fittracker.app.data.service.WorkoutDraftService
import com.fittracker.app.data.service.WorkoutDraftSnapshot
import com.fittracker.app.data.service.WorkoutExerciseDraft
import com.fittracker.app.ui.loadResumeDraft
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
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
 * 悬浮胶囊的两条纯逻辑：时钟格式化 + 「草稿 → 展示摘要」的构造。
 *
 * 为什么这两条值得钉死：
 * 1. [formatElapsedClock] 是 `mm:ss` 的唯一实现，训练页顶栏与胶囊共用同一格式口径；
 *    边界（0s / 59s / 60s / 过 100 分钟）错一位，用户看到的就是 `00:60` 或 `1:00`。
 * 2. [loadResumeDraft] 把草稿铺成 `ResumeDraftSummary`：`startedAt` 是摘要里**唯一**的时间源，
 *    秒数由显示层（胶囊每秒 tick / 训练页恢复）从它现算，摘要自身不再携带 `elapsedSeconds` 快照。
 *    构造时把 `startedAt` 漏传（或写成派生值）不会有编译错误，只会在胶囊上显示
 *    `00:00` 或天文数字——所以要有构造层回归。
 *
 * `@Config(sdk = [34])`：项目 targetSdk 37 超出 Robolectric 4.16 支持范围，与既有
 * Robolectric 测试一致钉到受支持的 SDK。
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class ResumeWorkoutBarTest {

    @get:Rule
    val tempFolder: TemporaryFolder = TemporaryFolder()

    private val storeCounter = AtomicInteger()

    /** 临时文件注入的数据仓，不触碰真实应用存储——与 `JsonStoreTest` 同一手法。 */
    private fun createStore(): JsonStore {
        val file = File(tempFolder.root, "resume_${storeCounter.incrementAndGet()}.preferences_pb")
        val dataStore = PreferenceDataStoreFactory.create(
            scope = CoroutineScope(Dispatchers.IO + SupervisorJob()),
        ) { file }
        return JsonStore(dataStore)
    }

    // ── formatElapsedClock 边界 ────────────────────────────────────────────

    @Test
    fun `零秒显示 00 00`() {
        assertEquals("00:00", formatElapsedClock(0))
    }

    @Test
    fun `59 秒仍是 00 59`() {
        assertEquals("00:59", formatElapsedClock(59))
    }

    @Test
    fun `60 秒进位到 01 00 不出现 00 60`() {
        assertEquals("01:00", formatElapsedClock(60))
    }

    @Test
    fun `61 秒为 01 01`() {
        assertEquals("01:01", formatElapsedClock(61))
    }

    @Test
    fun `59 分 59 秒为 59 59`() {
        assertEquals("59:59", formatElapsedClock(3599))
    }

    @Test
    fun `大分钟不折回小时 6000 秒为 100 00`() {
        // 胶囊不显示小时位：练满 100 分钟就是 `100:00`，而不是 `01:40:00` 或 `40:00`。
        assertEquals("100:00", formatElapsedClock(6000))
    }

    @Test
    fun `一整天级大分钟 86400 秒为 1440 00`() {
        assertEquals("1440:00", formatElapsedClock(86400))
    }

    // ── elapsedSecondsSince 派生与兜底 ────────────────────────────────────

    @Test
    fun `刚开练同毫秒为 0 秒`() {
        assertEquals(0, elapsedSecondsSince(1_700_000_000_000L, 1_700_000_000_000L))
    }

    @Test
    fun `不足一秒向下取整`() {
        assertEquals(0, elapsedSecondsSince(1_700_000_000_000L, 1_700_000_000_999L))
        assertEquals(59, elapsedSecondsSince(1_700_000_000_000L, 1_700_000_059_999L))
        assertEquals(60, elapsedSecondsSince(1_700_000_000_000L, 1_700_000_060_000L))
    }

    @Test
    fun `大时长不截断 一小时为 3600 秒`() {
        assertEquals(3600, elapsedSecondsSince(1_700_000_000_000L, 1_700_003_600_000L))
    }

    @Test
    fun `startedAt 缺失或非正退化为 0 而不是天文数字`() {
        // 旧草稿/异常写入：`startedAt == 0` 时 (now - 0)/1000 是 1.7e9 秒。
        assertEquals(0, elapsedSecondsSince(0L, 1_700_000_000_000L))
        assertEquals(0, elapsedSecondsSince(-1L, 1_700_000_000_000L))
    }

    @Test
    fun `时钟回拨 now 早于 startedAt 退化为 0 而不是负数`() {
        assertEquals(0, elapsedSecondsSince(1_700_000_000_000L, 1_699_999_999_000L))
    }

    // ── loadResumeDraft → ResumeDraftSummary 构造回归 ──────────────────────

    private fun draft(
        startedAt: Long,
        completedSets: Int = 3,
        totalTargetSets: Int = 12,
        exercises: List<WorkoutExerciseDraft> = listOf(
            exercise("ex-bench", "卧推", completed = 1, target = 4),
            exercise("ex-squat", "深蹲", completed = 2, target = 4),
        ),
        currentExerciseName: String = "卧推",
    ): WorkoutDraftSnapshot = WorkoutDraftSnapshot(
        planId = "plan-1",
        planName = "三分化",
        dayLabel = "Push",
        startedAt = startedAt,
        totalTargetSets = totalTargetSets,
        completedSets = completedSets,
        currentExerciseName = currentExerciseName,
        currentExerciseProgress = "1/4",
        exercises = exercises,
        updatedAt = System.currentTimeMillis(),
    )

    private fun exercise(id: String, name: String, completed: Int, target: Int) =
        WorkoutExerciseDraft(
            exerciseId = id,
            name = name,
            targetMuscle = "胸",
            targetSets = target,
            targetReps = "8",
            completedSets = completed,
            sets = emptyList(),
        )

    @Test
    fun `无草稿时返回 null`() = runBlocking {
        assertNull(loadResumeDraft(createStore()))
    }

    @Test
    fun `草稿构造出完整摘要且秒数锚定 startedAt`() = runBlocking {
        val store = createStore()
        val startedAt = System.currentTimeMillis() - 65_000L
        WorkoutDraftService.saveDraft(store, draft(startedAt = startedAt))

        val summary = loadResumeDraft(store)

        assertTrue("有进度时必须返回摘要", summary != null)
        requireNotNull(summary)
        // startedAt 必须原样透传：胶囊中栏时钟全靠它自己走，漏传就退化成静态快照。
        assertEquals(startedAt, summary.startedAt)
        assertEquals(3, summary.completedSets)
        assertEquals(12, summary.totalSets)
        // 当前动作 = 首个未录满的动作（卧推 1/4），不是最后一个、也不是 completedSets 最大的。
        assertEquals("卧推", summary.exerciseName)
        assertEquals(1, summary.exerciseCompletedSets)
        assertEquals(4, summary.exerciseTargetSets)
        // 摘要只透传 startedAt，秒数由胶囊从它现算：这里断言「用摘要的 startedAt
        // 派生出的秒数」≈65s（留 2s 余量容忍执行耗时）。
        val derivedSeconds = elapsedSecondsSince(summary.startedAt, System.currentTimeMillis())
        assertTrue(
            "从 startedAt 派生应约为 65 秒，实际 $derivedSeconds",
            derivedSeconds in 63..67,
        )
    }

    @Test
    fun `startedAt 为 0 的旧草稿派生秒数为 0 且不抛异常`() = runBlocking {
        val store = createStore()
        WorkoutDraftService.saveDraft(store, draft(startedAt = 0L))

        val summary = requireNotNull(loadResumeDraft(store))

        assertEquals(0L, summary.startedAt)
        // 旧草稿缺 startedAt：胶囊派生时退化为 0（`00:00`），不显示天文数字。
        assertEquals(0, elapsedSecondsSince(summary.startedAt, System.currentTimeMillis()))
    }

    @Test
    fun `全部动作录满时当前动作退到最后一个`() = runBlocking {
        val store = createStore()
        WorkoutDraftService.saveDraft(
            store,
            draft(
                startedAt = System.currentTimeMillis() - 1_000L,
                exercises = listOf(
                    exercise("ex-bench", "卧推", completed = 4, target = 4),
                    exercise("ex-squat", "深蹲", completed = 4, target = 4),
                ),
            ),
        )

        val summary = requireNotNull(loadResumeDraft(store))

        assertEquals("深蹲", summary.exerciseName)
        assertEquals(4, summary.exerciseCompletedSets)
    }
}

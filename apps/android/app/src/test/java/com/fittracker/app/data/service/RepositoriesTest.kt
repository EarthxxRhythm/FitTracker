package com.fittracker.app.data.service

import androidx.datastore.preferences.core.PreferenceDataStoreFactory
import com.fittracker.app.data.model.UserGoal
import com.fittracker.app.data.model.WorkoutSession
import com.fittracker.app.data.model.WorkoutSet
import com.fittracker.app.data.persist.JsonStore
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
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
 * Wave 3 三仓储（[GoalRepository] / [WorkoutRepository] / [UserProfileService]）的
 * DataStore 契约测试。
 *
 * 测试手段照 `JsonStoreTest`：以 [PreferenceDataStoreFactory] 把每个用例的存储指向
 * 独立临时文件（互不污染、不触真实应用存储）。
 *
 * `@Config(sdk = [34])`：项目 targetSdk 37 超出 Robolectric 4.16 支持范围，
 * 必须钉到受支持 SDK（原因同 `JsonStoreTest`）。
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class RepositoriesTest {

    @get:Rule
    val tempFolder: TemporaryFolder = TemporaryFolder()

    private val counter = AtomicInteger()

    private fun createStore(): JsonStore {
        val file = File(tempFolder.root, "repos_${counter.incrementAndGet()}.preferences_pb")
        val dataStore = PreferenceDataStoreFactory.create(
            scope = CoroutineScope(Dispatchers.IO + SupervisorJob()),
        ) { file }
        return JsonStore(dataStore)
    }

    /** 单例在 JVM 内跨用例存活——每例前清掉 [GoalRepository] 的内存缓存，避免串场。 */
    @Before
    fun resetSingletonState() {
        GoalRepository.clearLocal()
    }

    private val sampleGoal = UserGoal(
        goalId = "goal-1",
        goalType = "muscle_gain",
        level = "beginner",
        weeklyDays = 3,
        sessionMinutes = 45,
        equipmentIds = listOf("dumbbell", "barbell"),
        restrictedMuscleIds = listOf("lower_back"),
        createdAt = 1_759_000_000_000,
        updatedAt = 1_759_000_100_000,
    )

    private fun sampleSession(id: String, notes: String = "target_sets=3;completed_sets=3"): WorkoutSession =
        WorkoutRepository.createSession(
            sessionId = id,
            planId = "plan-1",
            dayId = "day-1",
            startedAt = 1_759_000_000_000,
            endedAt = 1_759_000_003_600,
            durationSeconds = 3600,
            totalSets = 2,
            totalVolume = 1_500.0,
            fatigueScore = 7.5,
            notes = notes,
            sets = listOf(
                WorkoutSet(setId = "set-1", exerciseId = "ex-1", weight = 50.0, reps = 10, rpe = 8.0, isWarmup = false),
                WorkoutSet(setId = "set-2", exerciseId = "ex-1", weight = 60.0, reps = 8, rpe = 8.5, isWarmup = true),
            ),
        )

    // --- GoalRepository ------------------------------------------------------

    @Test
    fun `goal 存取往返全等（清缓存后真读盘）`() = runBlocking {
        val store = createStore()
        GoalRepository.saveGoal(store, sampleGoal)

        // 清掉内存缓存，强制 loadGoal 从 DataStore 读回——验证的是落盘而非缓存。
        GoalRepository.clearLocal()
        assertEquals(sampleGoal, GoalRepository.loadGoal(store))
    }

    @Test
    fun `goal 空 store 读回 null`() = runBlocking {
        val store = createStore()
        assertNull(GoalRepository.loadGoal(store))
        assertFalse(GoalRepository.hasSavedGoal(store))
    }

    @Test
    fun `goal 清空后读回 null`() = runBlocking {
        val store = createStore()
        GoalRepository.saveGoal(store, sampleGoal)
        assertTrue(GoalRepository.hasSavedGoal(store))

        GoalRepository.clearSavedGoal(store)
        assertNull(GoalRepository.loadGoal(store))
        assertFalse(GoalRepository.hasSavedGoal(store))
    }

    // --- WorkoutRepository ---------------------------------------------------

    @Test
    fun `workout 存取往返全等`() = runBlocking {
        val store = createStore()
        val session = sampleSession("s-1")
        WorkoutRepository.saveSession(store, session)

        val all = WorkoutRepository.getSessions(store)
        assertEquals(1, all.size)
        assertEquals(session, all[0])
        assertEquals(session, WorkoutRepository.getSessionById(store, "s-1"))
        assertEquals(session, WorkoutRepository.getLatestSession(store))
    }

    @Test
    fun `workout 空 store 读回空列表与 null`() = runBlocking {
        val store = createStore()
        assertTrue(WorkoutRepository.getSessions(store).isEmpty())
        assertNull(WorkoutRepository.getSessionById(store, "missing"))
        assertNull(WorkoutRepository.getLatestSession(store))
    }

    @Test
    fun `workout 更新_删除_恢复语义`() = runBlocking {
        val store = createStore()
        WorkoutRepository.saveSession(store, sampleSession("s-1"))

        assertTrue(WorkoutRepository.updateSession(store, sampleSession("s-1", notes = "已更新")))
        assertEquals("已更新", WorkoutRepository.getSessionById(store, "s-1")?.notes)
        assertFalse(WorkoutRepository.updateSession(store, sampleSession("s-absent")))

        val removed = WorkoutRepository.removeSession(store, "s-1")
        assertEquals("s-1", removed?.sessionId)
        assertNull(WorkoutRepository.getSessionById(store, "s-1"))
        assertNull(WorkoutRepository.removeSession(store, "s-1"))

        assertTrue(WorkoutRepository.restoreSession(store, sampleSession("s-1")))
        assertFalse(WorkoutRepository.restoreSession(store, sampleSession("s-1")))
    }

    @Test
    fun `workout clear 清空会话`() = runBlocking {
        val store = createStore()
        WorkoutRepository.saveSession(store, sampleSession("s-1"))
        WorkoutRepository.saveSession(store, sampleSession("s-2"))

        WorkoutRepository.clear(store)
        assertTrue(WorkoutRepository.getSessions(store).isEmpty())
        assertNull(WorkoutRepository.getLatestSession(store))
    }

    // --- UserProfileService --------------------------------------------------

    @Test
    fun `profile 存取往返全等`() = runBlocking {
        val store = createStore()
        val profile = UserProfile(nickname = "阿明", avatar = "avatar://1", weightUnit = WeightUnit.LBS)
        UserProfileService.saveProfile(store, profile)

        assertEquals(profile, UserProfileService.loadProfile(store))
    }

    @Test
    fun `profile 空 store 读回默认`() = runBlocking {
        val store = createStore()
        assertEquals(UserProfileService.getDefaultProfile(), UserProfileService.loadProfile(store))
    }

    @Test
    fun `profile 清空后读回默认`() = runBlocking {
        val store = createStore()
        UserProfileService.saveProfile(store, UserProfile("阿明", "avatar://1", WeightUnit.LBS))

        UserProfileService.clearProfile(store)
        assertEquals(UserProfileService.getDefaultProfile(), UserProfileService.loadProfile(store))
    }

    @Test
    fun `profile 单字段写不丢其它字段`() = runBlocking {
        val store = createStore()
        UserProfileService.saveProfile(store, UserProfile("阿明", "avatar://1", WeightUnit.KG))

        UserProfileService.saveNickname(store, "小明")
        UserProfileService.saveWeightUnit(store, WeightUnit.LBS)

        val loaded = UserProfileService.loadProfile(store)
        assertEquals("小明", loaded.nickname)
        assertEquals("avatar://1", loaded.avatar)
        assertEquals(WeightUnit.LBS, loaded.weightUnit)
    }

    @Test
    fun `profile 未知单位归一为 kg`() {
        assertEquals(WeightUnit.KG, UserProfileService.normalizeWeightUnit("stone"))
        assertEquals(WeightUnit.LBS, UserProfileService.normalizeWeightUnit("lbs"))
        assertEquals(WeightUnit.KG, UserProfileService.normalizeWeightUnit("kg"))
    }
}

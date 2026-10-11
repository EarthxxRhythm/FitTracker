package com.fittracker.app.data.service

import androidx.datastore.preferences.core.PreferenceDataStoreFactory
import com.fittracker.app.data.persist.JsonStore
import com.fittracker.app.data.persist.StoreNames
import java.io.File
import java.util.concurrent.atomic.AtomicInteger
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.async
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * [TrainingPreferencesService] 契约测试（Wave 5 · B2）。
 *
 * 覆盖：① 空 store 回落原型静止态缺省；② 整份存取往返；③ 宽容解析——未知目标 / 经验归一
 * 为缺省且不连带丢其余字段；④ `daysPerWeek` 越界归一为缺省；⑤ [TrainingPreferencesService.clearPreferences]
 * 回落缺省；⑥ 归一函数边界；⑦ 并发整份写不产生「半写」（Mutex 串行化）。
 *
 * 测试手段照 `SettingsServiceTest` / `RepositoriesTest`：[PreferenceDataStoreFactory] 把每例存储
 * 指向独立临时文件（互不污染、不触真实应用存储）。
 *
 * `@Config(sdk = [34])`：项目 targetSdk 37 超出 Robolectric 4.16 支持范围，必须钉到受支持 SDK。
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class TrainingPreferencesServiceTest {

    @get:Rule
    val tempFolder: TemporaryFolder = TemporaryFolder()

    private val counter = AtomicInteger()

    private fun createStore(): JsonStore {
        val file = File(tempFolder.root, "prefs_${counter.incrementAndGet()}.preferences_pb")
        val dataStore = PreferenceDataStoreFactory.create(
            scope = CoroutineScope(Dispatchers.IO + SupervisorJob()),
        ) { file }
        return JsonStore(dataStore)
    }

    // --- 存储模型 -----------------------------------------------------------

    @Test
    fun `空 store 读回原型静止态缺省`() = runBlocking {
        val store = createStore()
        val preferences = TrainingPreferencesService.loadPreferences(store)

        assertEquals(FtTrainingPreferences(), preferences)
        // 原型静止态：增肌 / 进阶 / 每周 4 天 / 45 分钟 / 自重+哑铃 / 无限制肌群
        assertEquals(PrefGoal.MUSCLE_GAIN, preferences.goal)
        assertEquals(PrefLevel.INTERMEDIATE, preferences.level)
        assertEquals(4, preferences.daysPerWeek)
        assertEquals(45, preferences.sessionMinutes)
        assertEquals(setOf("eq_bodyweight", "eq_dumbbell"), preferences.equipmentIds)
        assertTrue(preferences.restrictedMuscleIds.isEmpty())
    }

    @Test
    fun `整份存取往返全等`() = runBlocking {
        val store = createStore()
        val preferences = FtTrainingPreferences(
            goal = PrefGoal.FAT_LOSS,
            level = PrefLevel.ADVANCED,
            daysPerWeek = 5,
            sessionMinutes = 60,
            equipmentIds = setOf("eq_barbell", "eq_cable"),
            restrictedMuscleIds = setOf("muscle_back", "muscle_legs"),
        )
        TrainingPreferencesService.savePreferences(store, preferences)

        assertEquals(preferences, TrainingPreferencesService.loadPreferences(store))
    }

    @Test
    fun `未知目标与经验归一为缺省且不丢其余字段`() = runBlocking {
        val store = createStore()
        // 直接写一块含未知枚举值的 JSON——模拟旧版 / 跨端写入的宽容读取场景
        store.writeString(
            StoreNames.TRAINING_PREFERENCES,
            """{"goal":"klingon","level":"elite","daysPerWeek":3,"sessionMinutes":75,""" +
                """"equipmentIds":["eq_band"],"restrictedMuscleIds":["muscle_core"]}""",
        )

        val loaded = TrainingPreferencesService.loadPreferences(store)
        assertEquals(PrefGoal.MUSCLE_GAIN, loaded.goal) // 未知目标 → 缺省
        assertEquals(PrefLevel.INTERMEDIATE, loaded.level) // 未知经验 → 缺省
        assertEquals(3, loaded.daysPerWeek) // 已知字段原样保留
        assertEquals(75, loaded.sessionMinutes)
        assertEquals(setOf("eq_band"), loaded.equipmentIds)
        assertEquals(setOf("muscle_core"), loaded.restrictedMuscleIds)
    }

    @Test
    fun `每周天数越界归一为缺省`() = runBlocking {
        val store = createStore()
        store.writeString(StoreNames.TRAINING_PREFERENCES, """{"daysPerWeek":9}""")
        assertEquals(4, TrainingPreferencesService.loadPreferences(store).daysPerWeek)

        store.writeString(StoreNames.TRAINING_PREFERENCES, """{"daysPerWeek":1}""")
        assertEquals(4, TrainingPreferencesService.loadPreferences(store).daysPerWeek)
    }

    @Test
    fun `缺字段回落缺省`() = runBlocking {
        val store = createStore()
        store.writeString(StoreNames.TRAINING_PREFERENCES, """{"goal":"strength"}""")

        val loaded = TrainingPreferencesService.loadPreferences(store)
        assertEquals(PrefGoal.STRENGTH, loaded.goal)
        assertEquals(PrefLevel.INTERMEDIATE, loaded.level)
        assertEquals(4, loaded.daysPerWeek)
        assertEquals(setOf("eq_bodyweight", "eq_dumbbell"), loaded.equipmentIds)
    }

    @Test
    fun `解析失败回落缺省`() = runBlocking {
        val store = createStore()
        store.writeString(StoreNames.TRAINING_PREFERENCES, "{ not json")

        assertEquals(FtTrainingPreferences(), TrainingPreferencesService.loadPreferences(store))
    }

    @Test
    fun `清空后读回缺省`() = runBlocking {
        val store = createStore()
        TrainingPreferencesService.savePreferences(store, FtTrainingPreferences(goal = PrefGoal.STRENGTH))

        TrainingPreferencesService.clearPreferences(store)

        assertEquals(FtTrainingPreferences(), TrainingPreferencesService.loadPreferences(store))
    }

    // --- 归一函数 -----------------------------------------------------------

    @Test
    fun `归一函数仅识别已知取值`() {
        assertEquals(PrefGoal.MUSCLE_GAIN, TrainingPreferencesService.normalizeGoal("hypertrophy"))
        assertEquals(PrefGoal.STRENGTH, TrainingPreferencesService.normalizeGoal("strength"))
        assertEquals(PrefGoal.FAT_LOSS, TrainingPreferencesService.normalizeGoal("fat_loss"))
        assertEquals(PrefGoal.MUSCLE_GAIN, TrainingPreferencesService.normalizeGoal("posture"))

        assertEquals(PrefLevel.BEGINNER, TrainingPreferencesService.normalizeLevel("beginner"))
        assertEquals(PrefLevel.INTERMEDIATE, TrainingPreferencesService.normalizeLevel("intermediate"))
        assertEquals(PrefLevel.ADVANCED, TrainingPreferencesService.normalizeLevel("advanced"))
        assertEquals(PrefLevel.INTERMEDIATE, TrainingPreferencesService.normalizeLevel("elite"))

        assertEquals(2, TrainingPreferencesService.normalizeDaysPerWeek(2))
        assertEquals(5, TrainingPreferencesService.normalizeDaysPerWeek(5))
        assertEquals(4, TrainingPreferencesService.normalizeDaysPerWeek(1))
        assertEquals(4, TrainingPreferencesService.normalizeDaysPerWeek(6))
        assertEquals(4, TrainingPreferencesService.normalizeDaysPerWeek(0))
    }

    @Test
    fun `落盘键对齐 StoreNames 常量`() {
        assertEquals(StoreNames.TRAINING_PREFERENCES, TrainingPreferencesService.STORE_KEY)
        assertEquals("fit_tracker_training_preferences", TrainingPreferencesService.STORE_KEY)
        assertEquals(TrainingPreferencesService.STORE_KEY, TrainingPreferencesService.STORE_NAME)
    }

    // --- 并发 ---------------------------------------------------------------

    @Test
    fun `并发整份写不产生半写`() = runBlocking {
        val store = createStore()
        val first = FtTrainingPreferences(
            goal = PrefGoal.STRENGTH,
            level = PrefLevel.BEGINNER,
            daysPerWeek = 3,
            sessionMinutes = 60,
            equipmentIds = setOf("eq_barbell"),
            restrictedMuscleIds = emptySet(),
        )
        val second = FtTrainingPreferences(
            goal = PrefGoal.FAT_LOSS,
            level = PrefLevel.ADVANCED,
            daysPerWeek = 5,
            sessionMinutes = 30,
            equipmentIds = setOf("eq_cable"),
            restrictedMuscleIds = setOf("muscle_back"),
        )
        // 两协程并发整份写——Mutex 若未串行化，可能出现两写的字段混合（半写）。
        val firstWrite = async(Dispatchers.Default) { TrainingPreferencesService.savePreferences(store, first) }
        val secondWrite = async(Dispatchers.Default) { TrainingPreferencesService.savePreferences(store, second) }
        firstWrite.await()
        secondWrite.await()

        val loaded = TrainingPreferencesService.loadPreferences(store)
        assertTrue("后写者应整块覆盖，不得出现字段混合：$loaded", loaded == first || loaded == second)
        assertFalse(loaded.equipmentIds.isEmpty())
    }
}

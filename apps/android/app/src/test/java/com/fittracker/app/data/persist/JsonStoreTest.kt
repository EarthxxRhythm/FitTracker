package com.fittracker.app.data.persist

import androidx.datastore.preferences.core.PreferenceDataStoreFactory
import com.fittracker.app.data.model.UserGoal
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.runBlocking
import kotlinx.serialization.encodeToString
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
 * DataStore 整块 JSON 存取契约测试。
 *
 * 测试通过 [PreferenceDataStoreFactory] 注入临时文件（不触碰真实应用存储），
 * 覆盖：写入→读回、`remove` 清空、读缺键、键名清单。
 *
 * `@Config(sdk = [34])`：与既有 Robolectric 测试一致——项目 targetSdk 37 超出
 * Robolectric 4.16 支持范围，必须钉到受支持的 SDK，否则 DefaultSdkPicker 直接抛错。
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class JsonStoreTest {

    @get:Rule
    val tempFolder: TemporaryFolder = TemporaryFolder()

    private val counter = AtomicInteger()

    private fun createStore(): JsonStore {
        val file = File(tempFolder.root, "fit_${counter.incrementAndGet()}.preferences_pb")
        val dataStore = PreferenceDataStoreFactory.create(
            scope = CoroutineScope(Dispatchers.IO + SupervisorJob()),
        ) { file }
        return JsonStore(dataStore)
    }

    private val sampleGoal = UserGoal(
        goalId = "goal-1", goalType = "muscle_gain", level = "beginner",
        weeklyDays = 3, sessionMinutes = 45,
        equipmentIds = listOf("dumbbell"), restrictedMuscleIds = emptyList(),
        createdAt = 1_759_000_000_000, updatedAt = 1_759_000_000_000,
    )

    @Test
    fun `写入读回往返全等`() = runBlocking {
        val store = createStore()
        store.write(StoreNames.GOAL, sampleGoal) { JsonCodec.json.encodeToString(UserGoal.serializer(), it) }

        val read = store.read(StoreNames.GOAL) { JsonCodec.json.decodeFromString(UserGoal.serializer(), it) }
        assertEquals(sampleGoal, read)
    }

    @Test
    fun `remove清空键后读回为null`() = runBlocking {
        val store = createStore()
        store.writeString(StoreNames.SESSION, "token")
        assertEquals("token", store.readString(StoreNames.SESSION))

        store.remove(StoreNames.SESSION)
        assertNull(store.readString(StoreNames.SESSION))
    }

    @Test
    fun `读取不存在的键返回null`() = runBlocking {
        val store = createStore()
        assertNull(store.readString("fit_tracker_never_written"))
    }

    @Test
    fun `键名清单_十六项_带语义前缀_无重复`() {
        // 16 项 = 10 基键 + CLOUD_SESSION（Wave 6 云端会话）
        //        + PLAN_STATE（plan 屏浏览状态，原型完整实现 Wave 1）
        //        + SETTINGS（设置偏好，原型完整实现 Wave 1）
        //        + BODY_RECORDS（体重记录，原型完整实现 Wave 3 · W3-1）
        //        + TRAINING_PREFERENCES（训练偏好，原型完整实现 Wave 5 · B2）
        //        + BODY_MEASUREMENTS（身体测量记录，新增数据源 Wave 0）
        assertEquals(16, StoreNames.ALL.size)
        assertTrue(StoreNames.ALL.all { it.startsWith("fit_tracker_") })
        assertEquals(StoreNames.ALL.size, StoreNames.ALL.toSet().size)
    }
}

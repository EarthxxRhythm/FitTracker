package com.fittracker.app.data.service.backup

import androidx.datastore.preferences.core.PreferenceDataStoreFactory
import com.fittracker.app.data.model.BodyMeasurement
import com.fittracker.app.data.model.WeightRecord
import com.fittracker.app.data.persist.JsonCodec
import com.fittracker.app.data.persist.JsonStore
import com.fittracker.app.data.service.BodyMeasurementService
import com.fittracker.app.data.service.BodyRecordService
import com.fittracker.app.data.sync.LocalSnapshotStore
import java.io.File
import java.util.Calendar
import java.util.concurrent.atomic.AtomicInteger
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * 新增身体数据域（Wave 0）在**备份包**与**云同步变更检测**两条链路上的契约测试。
 *
 * 这是计划里点名的红灯判据：新增数据域若不进备份包 / 不进 `normalizePayloadForHash` 白名单，
 * 会出现「功能看着正常、但数据不进备份、云同步永不触发」的静默失效。本测试同时锁住正向
 * （新域随包往返）与反向（旧包缺字段时不清空本地）。
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class BodyDomainBackupTest {

    @get:Rule
    val tempFolder: TemporaryFolder = TemporaryFolder()

    private val counter = AtomicInteger()

    private fun createStore(): JsonStore {
        val file = File(tempFolder.root, "bodybackup_${counter.incrementAndGet()}.preferences_pb")
        val dataStore = PreferenceDataStoreFactory.create(
            scope = CoroutineScope(Dispatchers.IO + SupervisorJob()),
        ) { file }
        return JsonStore(dataStore)
    }

    private fun day(year: Int, month1: Int, dayOfMonth: Int): Long {
        val cal = Calendar.getInstance()
        cal.clear()
        cal.set(year, month1 - 1, dayOfMonth)
        return cal.timeInMillis
    }

    @Test
    fun `体重与测量记录随备份包往返不丢`() = runBlocking {
        val source = createStore()
        BodyRecordService.addRecord(source, WeightRecord(dateMillis = day(2026, 3, 10), kg = 72.5))
        BodyMeasurementService.addMeasurement(
            source,
            BodyMeasurement(dateMillis = day(2026, 3, 10), chestCm = 96.0, bodyFatPercent = 16.2),
        )

        val exported = UserDataBackupService.exportPackage(source)

        // 导入到另一份干净存储，验证数据确实随包带过去了。
        val target = createStore()
        val result = UserDataBackupService.importPackage(target, exported)
        assertTrue(result.success)

        val weights = BodyRecordService.loadRecords(target)
        assertEquals(1, weights.size)
        assertEquals(72.5, weights[0].kg, 0.001)

        val measurements = BodyMeasurementService.loadMeasurements(target)
        assertEquals(1, measurements.size)
        assertEquals(96.0, measurements[0].chestCm, 0.001)
        assertEquals(16.2, measurements[0].bodyFatPercent, 0.001)
    }

    @Test
    fun `旧备份包缺身体数据字段时不清空本地记录`() = runBlocking {
        val store = createStore()
        BodyRecordService.addRecord(store, WeightRecord(dateMillis = day(2026, 3, 10), kg = 72.5))

        // 模拟旧版本备份包：手工拼一个不含 bodyRecords / bodyMeasurements 的合法包。
        val legacyPackage = UserDataBackupService.createPackage(
            goal = null,
            plans = emptyList(),
            currentPlanId = "",
            sessions = emptyList(),
            exportedAt = System.currentTimeMillis(),
            bodyRecords = null,
            bodyMeasurements = null,
        )
        val legacyJson = JsonCodec.prettyJson.encodeToString(
            com.fittracker.app.data.model.UserDataBackupPackage.serializer(),
            legacyPackage,
        )

        val result = UserDataBackupService.importPackage(store, legacyJson)
        assertTrue(result.success)

        // 本地既有体重记录须保留（旧包「无该域」≠「该域为空」）。
        assertEquals(1, BodyRecordService.loadRecords(store).size)
    }

    @Test
    fun `身体数据变化会改变云同步 hash`() = runBlocking {
        val store = createStore()
        val before = LocalSnapshotStore.hashPayload(LocalSnapshotStore.buildLocalPayload(store))

        BodyMeasurementService.addMeasurement(
            store,
            BodyMeasurement(dateMillis = day(2026, 3, 10), chestCm = 96.0),
        )
        val after = LocalSnapshotStore.hashPayload(LocalSnapshotStore.buildLocalPayload(store))

        assertNotEquals(
            "测量记录新增后 hash 必须变化，否则云同步对该域失明",
            before,
            after,
        )
    }

    @Test
    fun `体重记录变化会改变云同步 hash`() = runBlocking {
        val store = createStore()
        val before = LocalSnapshotStore.hashPayload(LocalSnapshotStore.buildLocalPayload(store))

        BodyRecordService.addRecord(store, WeightRecord(dateMillis = day(2026, 3, 10), kg = 72.5))
        val after = LocalSnapshotStore.hashPayload(LocalSnapshotStore.buildLocalPayload(store))

        assertNotEquals("体重记录新增后 hash 必须变化", before, after)
    }

    @Test
    fun `无变更时 hash 稳定`() = runBlocking {
        val store = createStore()
        BodyMeasurementService.addMeasurement(
            store,
            BodyMeasurement(dateMillis = day(2026, 3, 10), chestCm = 96.0),
        )
        val first = LocalSnapshotStore.hashPayload(LocalSnapshotStore.buildLocalPayload(store))
        val second = LocalSnapshotStore.hashPayload(LocalSnapshotStore.buildLocalPayload(store))
        assertEquals("无数据变更时 hash 必须稳定（否则每次同步都误判有变更）", first, second)
    }
}

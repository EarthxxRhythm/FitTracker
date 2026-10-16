package com.fittracker.app.data.service

import androidx.datastore.preferences.core.PreferenceDataStoreFactory
import com.fittracker.app.data.model.BodyMeasurement
import com.fittracker.app.data.model.MEASUREMENT_UNSET
import com.fittracker.app.data.model.WeightRecord
import com.fittracker.app.data.persist.JsonStore
import java.io.File
import java.util.Calendar
import java.util.concurrent.atomic.AtomicInteger
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * [BodyMeasurementService] 契约测试（新增数据源 Wave 0）。
 *
 * 覆盖：
 * ① **存储**：空 store 回落空、整份存取往返（升序归一）、同日**逐项合并**（未录项保留既有值）、
 *    跨日追加、清空；
 * ② **查询纯函数**：[BodyMeasurementService.latest] / [BodyMeasurementService.previous] /
 *    [BodyMeasurementService.delta]（任一侧未录返回 null）。
 *
 * 手段照 [BodyRecordServiceTest]：以 [PreferenceDataStoreFactory] 把每个用例指向独立临时文件。
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class BodyMeasurementServiceTest {

    @get:Rule
    val tempFolder: TemporaryFolder = TemporaryFolder()

    private val counter = AtomicInteger()

    private fun createStore(): JsonStore {
        val file = File(tempFolder.root, "measurement_${counter.incrementAndGet()}.preferences_pb")
        val dataStore = PreferenceDataStoreFactory.create(
            scope = CoroutineScope(Dispatchers.IO + SupervisorJob()),
        ) { file }
        return JsonStore(dataStore)
    }

    /** 本地时区日零点（与服务 `startOfDay` 同口径）。 */
    private fun day(year: Int, month1: Int, dayOfMonth: Int): Long {
        val cal = Calendar.getInstance()
        cal.clear()
        cal.set(year, month1 - 1, dayOfMonth)
        return cal.timeInMillis
    }

    private val unset: Double = MEASUREMENT_UNSET.toDouble()

    @Test
    fun `空 store 回落空列表`() = runBlocking {
        val store = createStore()
        assertEquals(emptyList<BodyMeasurement>(), BodyMeasurementService.loadMeasurements(store))
    }

    @Test
    fun `整份存取往返保持值并按日期升序`() = runBlocking {
        val store = createStore()
        val first = BodyMeasurement(dateMillis = day(2026, 3, 10), chestCm = 96.5, waistCm = 78.0)
        val second = BodyMeasurement(dateMillis = day(2026, 3, 1), chestCm = 95.0, waistCm = 79.0)
        BodyMeasurementService.saveMeasurements(store, listOf(first, second))

        val loaded = BodyMeasurementService.loadMeasurements(store)
        assertEquals(2, loaded.size)
        assertEquals(day(2026, 3, 1), loaded[0].dateMillis)
        assertEquals(95.0, loaded[0].chestCm, 0.001)
        assertEquals(day(2026, 3, 10), loaded[1].dateMillis)
        assertEquals(96.5, loaded[1].chestCm, 0.001)
    }

    @Test
    fun `同日重复录入逐项合并——未录项保留既有值`() = runBlocking {
        val store = createStore()
        val date = day(2026, 3, 10)
        // 先录围度 + 体脂 + 骨骼肌。
        BodyMeasurementService.addMeasurement(
            store,
            BodyMeasurement(
                dateMillis = date,
                chestCm = 96.0,
                bodyFatPercent = 16.2,
                skeletalMuscleKg = 34.2,
            ),
        )
        // 同日只补腰围——其余项须保留。
        BodyMeasurementService.addMeasurement(
            store,
            BodyMeasurement(dateMillis = date, waistCm = 78.0),
        )

        val loaded = BodyMeasurementService.loadMeasurements(store)
        assertEquals(1, loaded.size)
        val merged = loaded[0]
        assertEquals(96.0, merged.chestCm, 0.001)
        assertEquals(78.0, merged.waistCm, 0.001)
        assertEquals(16.2, merged.bodyFatPercent, 0.001)
        assertEquals(34.2, merged.skeletalMuscleKg, 0.001)
    }

    @Test
    fun `跨日追加保留两条`() = runBlocking {
        val store = createStore()
        BodyMeasurementService.addMeasurement(store, BodyMeasurement(dateMillis = day(2026, 3, 10), waistCm = 78.0))
        BodyMeasurementService.addMeasurement(store, BodyMeasurement(dateMillis = day(2026, 3, 11), waistCm = 77.5))

        assertEquals(2, BodyMeasurementService.loadMeasurements(store).size)
    }

    @Test
    fun `未录项在往返后仍为 -1`() = runBlocking {
        val store = createStore()
        BodyMeasurementService.addMeasurement(store, BodyMeasurement(dateMillis = day(2026, 3, 10), chestCm = 96.0))

        val loaded = BodyMeasurementService.loadMeasurements(store)
        assertEquals(unset, loaded[0].waistCm, 0.001)
        assertEquals(unset, loaded[0].bodyFatPercent, 0.001)
    }

    @Test
    fun `latest 与 previous 按日期取首尾`() = runBlocking {
        val store = createStore()
        BodyMeasurementService.saveMeasurements(
            store,
            listOf(
                BodyMeasurement(dateMillis = day(2026, 3, 1), waistCm = 80.0),
                BodyMeasurement(dateMillis = day(2026, 3, 5), waistCm = 79.0),
                BodyMeasurement(dateMillis = day(2026, 3, 10), waistCm = 78.0),
            ),
        )
        val records = BodyMeasurementService.loadMeasurements(store)

        assertEquals(day(2026, 3, 10), BodyMeasurementService.latest(records)?.dateMillis)
        assertEquals(day(2026, 3, 5), BodyMeasurementService.previous(records)?.dateMillis)
        assertNull(BodyMeasurementService.previous(listOf(records[0])))
    }

    @Test
    fun `delta 在任一侧未录时返回 null`() {
        assertEquals(-2.0, BodyMeasurementService.delta(78.0, 80.0)!!, 0.001)
        assertNull(BodyMeasurementService.delta(unset, 80.0))
        assertNull(BodyMeasurementService.delta(78.0, unset))
    }

    @Test
    fun `清空后回落空列表`() = runBlocking {
        val store = createStore()
        BodyMeasurementService.addMeasurement(store, BodyMeasurement(dateMillis = day(2026, 3, 10), waistCm = 78.0))
        BodyMeasurementService.clearMeasurements(store)
        assertEquals(emptyList<BodyMeasurement>(), BodyMeasurementService.loadMeasurements(store))
    }
}

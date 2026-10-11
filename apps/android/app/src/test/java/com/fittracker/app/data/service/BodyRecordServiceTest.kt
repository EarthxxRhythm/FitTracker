package com.fittracker.app.data.service

import androidx.datastore.preferences.core.PreferenceDataStoreFactory
import com.fittracker.app.data.model.WeightRecord
import com.fittracker.app.data.persist.JsonStore
import com.fittracker.app.data.persist.StoreNames
import java.io.File
import java.util.Calendar
import java.util.concurrent.atomic.AtomicInteger
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.async
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

/**
 * [BodyRecordService] 契约测试（原型完整实现 Wave 3 · W3-1）。
 *
 * 覆盖三层：
 * ① **模型/存储**：空 store 回落空、整份存取往返（升序归一）、[BodyRecordService.addRecord] 同日
 *    upsert 与跨日追加、并发读-改-写不丢记录、清空；
 * ② **统计纯函数**：周/月/年趋势恒为 7 点（与 `FtBodyModel.CHART_X` 逐点对齐）、前向填充、
 *    delta（末点 − 首点）与「较上周」delta；空记录回落 null / 0.0。
 *
 * 测试手段照 [SettingsServiceTest] / `RepositoriesTest`：以 [PreferenceDataStoreFactory] 把每个
 * 用例的存储指向独立临时文件（互不污染、不触真实应用存储）。
 *
 * 日期口径：用例内用 [Calendar] 构造本地日零点，与服务同一时区语义；`addDays` / `mondayOf`
 * 复刻服务的日粒度算术，使「本周一–周日」索引映射与真实日历无关地自洽。
 *
 * `@Config(sdk = [34])`：项目 targetSdk 37 超出 Robolectric 4.16 支持范围，必须钉到受支持 SDK。
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class BodyRecordServiceTest {

    @get:Rule
    val tempFolder: TemporaryFolder = TemporaryFolder()

    private val counter = AtomicInteger()

    private fun createStore(): JsonStore {
        val file = File(tempFolder.root, "body_${counter.incrementAndGet()}.preferences_pb")
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

    private fun startOfDay(millis: Long): Long {
        val cal = Calendar.getInstance().apply { timeInMillis = millis }
        return day(cal.get(Calendar.YEAR), cal.get(Calendar.MONTH) + 1, cal.get(Calendar.DAY_OF_MONTH))
    }

    private fun addDays(millis: Long, days: Int): Long {
        val cal = Calendar.getInstance().apply { timeInMillis = millis }
        return day(cal.get(Calendar.YEAR), cal.get(Calendar.MONTH) + 1, cal.get(Calendar.DAY_OF_MONTH) + days)
    }

    /** 复刻服务 `mondayStart`——本周一 00:00。 */
    private fun mondayOf(millis: Long): Long {
        val cal = Calendar.getInstance().apply { timeInMillis = millis }
        val dow = cal.get(Calendar.DAY_OF_WEEK)
        val offset = if (dow == Calendar.SUNDAY) 6 else dow - Calendar.MONDAY
        return addDays(startOfDay(millis), -offset)
    }

    // --- 模型 / 存储（W3-1） -------------------------------------------------

    @Test
    fun `键名与语义库名一致`() {
        assertEquals(StoreNames.BODY_RECORDS, BodyRecordService.STORE_KEY)
        assertEquals("fit_tracker_body_records", BodyRecordService.STORE_NAME)
    }

    @Test
    fun `空 store 读回空列表`() = runBlocking {
        val store = createStore()
        assertEquals(emptyList<WeightRecord>(), BodyRecordService.loadRecords(store))
    }

    @Test
    fun `整份存取往返_按日期升序`() = runBlocking {
        val store = createStore()
        BodyRecordService.saveRecords(
            store,
            listOf(
                WeightRecord(day(2026, 8, 21), 72.5),
                WeightRecord(day(2026, 8, 19), 72.0),
            ),
        )

        val loaded = BodyRecordService.loadRecords(store)
        assertEquals(listOf(day(2026, 8, 19), day(2026, 8, 21)), loaded.map { it.dateMillis })
        assertEquals(listOf(72.0, 72.5), loaded.map { it.kg })
    }

    @Test
    fun `addRecord 同日覆盖与跨日追加`() = runBlocking {
        val store = createStore()
        BodyRecordService.addRecord(store, WeightRecord(day(2026, 8, 20), 70.0))
        BodyRecordService.addRecord(store, WeightRecord(day(2026, 8, 21), 72.5))
        BodyRecordService.addRecord(store, WeightRecord(day(2026, 8, 20), 71.0)) // 同日 → 覆盖

        val loaded = BodyRecordService.loadRecords(store)
        assertEquals(2, loaded.size)
        assertEquals(listOf(71.0, 72.5), loaded.map { it.kg })
    }

    @Test
    fun `addRecord 归一日期到日零点`() = runBlocking {
        val store = createStore()
        // 非零点的同日时间戳 → 落盘归一为日零点。
        BodyRecordService.addRecord(store, WeightRecord(day(2026, 8, 20) + 5 * 3_600_000L, 70.0))

        val loaded = BodyRecordService.loadRecords(store)
        assertEquals(day(2026, 8, 20), loaded.single().dateMillis)
        assertTrue(loaded.all { it.dateMillis == startOfDay(it.dateMillis) })
    }

    @Test
    fun `并发 addRecord 不丢记录`() = runBlocking {
        val store = createStore()
        // 两协程并发读-改-写两个不同自然日——未串行化时后写者会以旧快照覆盖先写者（丢更新）。
        val first = async(Dispatchers.Default) {
            BodyRecordService.addRecord(store, WeightRecord(day(2026, 8, 19), 70.0))
        }
        val second = async(Dispatchers.Default) {
            BodyRecordService.addRecord(store, WeightRecord(day(2026, 8, 20), 71.0))
        }
        first.await()
        second.await()

        assertEquals(listOf(70.0, 71.0), BodyRecordService.loadRecords(store).map { it.kg })
    }

    @Test
    fun `清空后读回空列表`() = runBlocking {
        val store = createStore()
        BodyRecordService.saveRecords(store, listOf(WeightRecord(day(2026, 8, 21), 72.5)))

        BodyRecordService.clearRecords(store)

        assertEquals(emptyList<WeightRecord>(), BodyRecordService.loadRecords(store))
    }

    // --- 统计（W3-1） --------------------------------------------------------

    @Test
    fun `周趋势_恒为七点_单条记录全等且delta为零`() {
        val records = listOf(WeightRecord(day(2026, 8, 21), 72.5))
        val trend = BodyRecordService.weekTrend(records, day(2026, 8, 21), WeekStart.MONDAY)!!

        assertEquals(7, trend.values.size)
        assertEquals(7, trend.labels.size)
        assertEquals(listOf("一", "二", "三", "四", "五", "六", "日"), trend.labels)
        assertTrue(trend.values.all { it == 72.5f })
        assertEquals(0.0, trend.deltaKg, 0.0)
        assertEquals("近 7 天", trend.rangeText)
    }

    @Test
    fun `周趋势_前向填充与delta`() {
        val now = day(2026, 8, 21)
        val monday = mondayOf(now)
        // 周一 70.0；周五（周一+4）72.5；周二–周四前向填充周一值，周六周日前向填充周五值。
        val records = listOf(
            WeightRecord(monday, 70.0),
            WeightRecord(addDays(monday, 4), 72.5),
        )
        val trend = BodyRecordService.weekTrend(records, now, WeekStart.MONDAY)!!

        assertEquals(70.0f, trend.values[0], 0f)
        assertEquals(70.0f, trend.values[3], 0f)
        assertEquals(72.5f, trend.values[4], 0f)
        assertEquals(72.5f, trend.values[6], 0f)
        assertEquals(2.5, trend.deltaKg, 1e-9)
    }

    @Test
    fun `月趋势与年趋势_恒为七点_标签对齐原型稀疏样式`() {
        val now = day(2026, 8, 21)
        val records = listOf(WeightRecord(now, 72.5))

        val month = BodyRecordService.monthTrend(records, now)!!
        assertEquals(7, month.values.size)
        assertEquals(7, month.labels.size)
        assertEquals("30天前", month.labels[0])
        assertEquals("15天前", month.labels[3])
        assertEquals("现在", month.labels[6])
        assertEquals("近 30 天", month.rangeText)

        val year = BodyRecordService.yearTrend(records, now)!!
        assertEquals(7, year.values.size)
        assertEquals(7, year.labels.size)
        assertEquals("12个月前", year.labels[0])
        assertEquals("6个月前", year.labels[3])
        assertEquals("现在", year.labels[6])
        assertEquals("近 12 个月", year.rangeText)
    }

    @Test
    fun `较上周delta 与空记录回落`() {
        val now = day(2026, 8, 21)
        val records = listOf(
            WeightRecord(addDays(now, -7), 70.0),
            WeightRecord(now, 72.5),
        )
        assertEquals(2.5, BodyRecordService.weekDeltaKg(records, now), 1e-9)

        assertEquals(0.0, BodyRecordService.weekDeltaKg(emptyList(), now), 0.0)
        assertNull(BodyRecordService.weekTrend(emptyList(), now, WeekStart.MONDAY))
        assertNull(BodyRecordService.monthTrend(emptyList(), now))
        assertNull(BodyRecordService.yearTrend(emptyList(), now))
    }

    @Test
    fun `周趋势_周首切周日时窗口与标签联动`() {
        // 2026-08-21 为周五；周日首模式下当周 = [2026-08-16（周日）, 2026-08-23)
        val now = day(2026, 8, 21)
        val records = listOf(
            WeightRecord(day(2026, 8, 16), 70.0), // 当周周日（周首）
            WeightRecord(day(2026, 8, 21), 72.5), // 周五
        )
        val trend = BodyRecordService.weekTrend(records, now, WeekStart.SUNDAY)!!

        assertEquals(listOf("日", "一", "二", "三", "四", "五", "六"), trend.labels)
        assertEquals(70.0f, trend.values[0], 0f)
        assertEquals(72.5f, trend.values[5], 0f)
        assertEquals(72.5f, trend.values[6], 0f) // 周六前向填充
        assertEquals(2.5, trend.deltaKg, 1e-9)
    }
}

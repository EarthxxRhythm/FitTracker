package com.fittracker.app.data.service

import com.fittracker.app.data.model.WeightRecord
import com.fittracker.app.data.persist.JsonCodec
import com.fittracker.app.data.persist.JsonStore
import com.fittracker.app.data.persist.StoreNames
import java.util.Calendar
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.serialization.decodeFromString
import kotlinx.serialization.encodeToString

/**
 * 一段体重趋势（Wave 3 · W3-1）——与 UI 层 `FtBodyModel.TrendSeries` **同形**（点集 + 标签 + caption 素材）。
 *
 * 恒为 **7 点**：[values] / [labels] 长度均为 7，与 `FtBodyModel.CHART_X`（7 项）逐点对齐，
 * 供 `FtBodyModel.chartPoints` 直接消费而不越界。[deltaKg] 为末点 − 首点（千克基准）；
 * [rangeText] 为区间前缀（`近 7 天` / `近 30 天` / `近 12 个月`）——caption 由 UI 层拼装单位后成文。
 */
data class BodyTrend(
    val values: List<Float>,
    val labels: List<String>,
    val deltaKg: Double,
    val rangeText: String,
)

/**
 * 体重记录本地持久化与统计服务（Wave 3 · W3-1）。
 *
 * 落盘模型沿用本仓既有口径（[SettingsService] / [UserProfileService] / `TrainingPlanRepository`）：
 * 整份记录以**一块 JSON 数组**存于单键 [StoreNames.BODY_RECORDS]（`fit_tracker_body_records`）。
 * 写入（整份 [saveRecords] / 追加 [addRecord] / 清空 [clearRecords]）共用一把 [writeMutex] 串行化：
 * [addRecord] 的「读-改-写」是两次 suspend 往返，并发交错时后写者会以旧快照覆盖先写者已提交的
 * 记录（丢更新），加锁后每个临界区原子完成。
 *
 * 统计为**纯函数**（无状态、可单测）：周/月/年三段趋势 + 「较上周」delta。日期口径用
 * `java.util.Calendar` 本地时区（同 `StatsDashboardService`，`minSdk = 24` 不用 `java.time`）。
 *
 * **与 UI 层的边界**：本服务返回 data 层类型 [BodyTrend]（同 `StatsDashboardService` 返回 data 层结果），
 * 不依赖 `ui.screens.body.TrendSeries`——避免 data → ui 反向依赖；由 `FtBodyModel` 适配为展示层序列。
 */
object BodyRecordService {

    /** 实际 JsonStore 键——语义库名 `fit_tracker_body_records`。 */
    const val STORE_KEY: String = StoreNames.BODY_RECORDS

    /** 语义库名（与落盘键同值，供排障对照）。 */
    const val STORE_NAME: String = "fit_tracker_body_records"

    /** 最近一次持久化错误码（对齐 [SettingsService.getLastPersistenceError] 口径）。 */
    private var lastPersistenceError: String = ""

    /**
     * 串行化对记录库的写入。[addRecord] 的读-改-写与整份 [saveRecords] / [clearRecords] 共用此锁，
     * 消除并发交错下「后写者以旧快照覆盖先写者」的丢更新窗口。
     */
    private val writeMutex: Mutex = Mutex()

    /** 最近一次持久化错误码；无错误为空串。 */
    fun getLastPersistenceError(): String = lastPersistenceError

    // --- 读 / 写 -------------------------------------------------------------

    /** 读回全部记录（按 [WeightRecord.dateMillis] 升序）。缺键 / 空串 / 解析失败一律回落空列表。 */
    suspend fun loadRecords(store: JsonStore): List<WeightRecord> {
        lastPersistenceError = ""
        val raw: String? = try {
            store.readString(STORE_KEY)
        } catch (error: Exception) {
            lastPersistenceError = "load_body_records_failed"
            return emptyList()
        }
        return decodeQuiet(raw)
    }

    /** 整份写入（先归一日期到日零点、再升序）。 */
    suspend fun saveRecords(store: JsonStore, records: List<WeightRecord>) {
        lastPersistenceError = ""
        try {
            writeMutex.withLock { writeRecords(store, records) }
        } catch (error: Exception) {
            lastPersistenceError = "save_body_records_failed"
        }
    }

    /**
     * 追加一条记录（读-改-写）。落在**同一自然日**的既有记录被覆盖（upsert by day）；
     * 其余记录保留。整段读-改-写在 [writeMutex] 临界区内原子完成。
     */
    suspend fun addRecord(store: JsonStore, record: WeightRecord) {
        lastPersistenceError = ""
        try {
            writeMutex.withLock {
                val day = startOfDay(record.dateMillis)
                val others = readQuiet(store).filterNot { startOfDay(it.dateMillis) == day }
                writeRecords(store, others + record.copy(dateMillis = day))
            }
        } catch (error: Exception) {
            lastPersistenceError = "save_body_record_failed"
        }
    }

    /** 清空全部记录（删键）。 */
    suspend fun clearRecords(store: JsonStore) {
        lastPersistenceError = ""
        try {
            writeMutex.withLock { store.remove(STORE_KEY) }
        } catch (error: Exception) {
            lastPersistenceError = "clear_body_records_failed"
        }
    }

    // --- 统计（纯函数） ------------------------------------------------------

    /**
     * 周趋势：**本周（周首由 [weekStart] 决定，共 7 天）**逐日点。缺记录的日子按「最近一条 ≤ 该日的
     * 记录」前向填充（carry-forward；若皆晚于该日则回填最早一条），与折线连续观感一致。
     * 标签序随 [weekStart] 联动（[WeekWindow.dayLabels]）。[records] 为空返回 null（调用方回落样例态）。
     */
    fun weekTrend(
        records: List<WeightRecord>,
        now: Long,
        weekStart: WeekStart,
        languageTag: String,
    ): BodyTrend? {
        if (records.isEmpty()) return null
        val sorted = records.sortedBy { it.dateMillis }
        val start = mondayStart(now, weekStart)
        val values = (0 until 7).map { day -> sampleAt(sorted, addDays(start, day)).toFloat() }
        return BodyTrend(
            values = values,
            labels = WeekWindow.dayLabels(weekStart, languageTag),
            deltaKg = (values[6] - values[0]).toDouble(),
            rangeText = if (languageTag.startsWith("zh")) "近 7 天" else "Last 7 days",
        )
    }

    /** 月趋势：近 30 天 7 个锚点（今天回溯 30/25/20/15/10/5/0 天）的取样点。 */
    fun monthTrend(records: List<WeightRecord>, now: Long): BodyTrend? {
        if (records.isEmpty()) return null
        val sorted = records.sortedBy { it.dateMillis }
        val today = startOfDay(now)
        val values = MONTH_OFFSETS.map { offset -> sampleAt(sorted, addDays(today, -offset)).toFloat() }
        return BodyTrend(
            values = values,
            labels = MONTH_LABELS,
            deltaKg = (values[6] - values[0]).toDouble(),
            rangeText = "近 30 天",
        )
    }

    /** 年趋势：近 12 个月 7 个锚点（本月回溯 12/10/8/6/4/2/0 月）的取样点。 */
    fun yearTrend(records: List<WeightRecord>, now: Long): BodyTrend? {
        if (records.isEmpty()) return null
        val sorted = records.sortedBy { it.dateMillis }
        val values = YEAR_OFFSETS.map { offset -> sampleAt(sorted, addMonths(now, -offset)).toFloat() }
        return BodyTrend(
            values = values,
            labels = YEAR_LABELS,
            deltaKg = (values[6] - values[0]).toDouble(),
            rangeText = "近 12 个月",
        )
    }

    /**
     * 「较上周」delta（千克）：最新一条记录 − 该记录日期回溯 7 天的取样值。
     * [records] 为空返回 0.0。
     */
    fun weekDeltaKg(records: List<WeightRecord>, now: Long): Double {
        if (records.isEmpty()) return 0.0
        val sorted = records.sortedBy { it.dateMillis }
        val latest = sorted.last()
        val weekAgo = sampleAt(sorted, addDays(latest.dateMillis, -7))
        return latest.kg - weekAgo
    }

    // --- 内部：整块 JSON 读写 ------------------------------------------------

    /** 静默读回当前记录（缺键 / 解析失败回落空列表），**不触碰** [lastPersistenceError]——供读-改-写用。 */
    private suspend fun readQuiet(store: JsonStore): List<WeightRecord> = decodeQuiet(store.readString(STORE_KEY))

    private fun decodeQuiet(raw: String?): List<WeightRecord> {
        if (raw.isNullOrEmpty()) return emptyList()
        return try {
            JsonCodec.json.decodeFromString<List<WeightRecord>>(raw).sortedBy { it.dateMillis }
        } catch (error: Exception) {
            emptyList()
        }
    }

    private suspend fun writeRecords(store: JsonStore, records: List<WeightRecord>) {
        val normalized = records
            .map { it.copy(dateMillis = startOfDay(it.dateMillis)) }
            .sortedBy { it.dateMillis }
        store.writeString(STORE_KEY, JsonCodec.json.encodeToString(normalized))
    }

    // --- 内部：取样与日期算术（本地时区，同 StatsDashboardService） ----------

    /**
     * 取 [day]（含）之前最近一条记录的 kg；若无（皆晚于该日）则回填最早一条。
     * [sorted] 须按 [WeightRecord.dateMillis] 升序（调用方保证）。
     */
    private fun sampleAt(sorted: List<WeightRecord>, day: Long): Double {
        var value = sorted.first().kg
        for (record in sorted) {
            if (record.dateMillis <= day) value = record.kg else break
        }
        return value
    }

    /** 本地时区日零点（对齐 JS `new Date(y, m, d)`）。 */
    private fun startOfDay(millis: Long): Long {
        val cal = Calendar.getInstance().apply { timeInMillis = millis }
        return calendarAt(cal.get(Calendar.YEAR), cal.get(Calendar.MONTH), cal.get(Calendar.DAY_OF_MONTH)).timeInMillis
    }

    /** 日粒度偏移（跨月/跨年由 Calendar 归一）。 */
    private fun addDays(millis: Long, days: Int): Long {
        val cal = Calendar.getInstance().apply { timeInMillis = millis }
        return calendarAt(cal.get(Calendar.YEAR), cal.get(Calendar.MONTH), cal.get(Calendar.DAY_OF_MONTH) + days).timeInMillis
    }

    /** 月粒度偏移（月末溢出由 Calendar 归一，如 1/31 -1 月 → 12/31）。 */
    private fun addMonths(millis: Long, months: Int): Long {
        val cal = Calendar.getInstance().apply { timeInMillis = millis }
        return calendarAt(cal.get(Calendar.YEAR), cal.get(Calendar.MONTH) + months, cal.get(Calendar.DAY_OF_MONTH)).timeInMillis
    }

    /** 当周周首 00:00（周首由 [weekStart] 决定；`Calendar.DAY_OF_WEEK`：周日=1..周六=7）。 */
    private fun mondayStart(millis: Long, weekStart: WeekStart): Long {
        val cal = Calendar.getInstance().apply { timeInMillis = millis }
        val offset = WeekWindow.offsetFromWeekStart(cal.get(Calendar.DAY_OF_WEEK) - 1, weekStart)
        return addDays(startOfDay(millis), -offset)
    }

    /** 本地时区午夜 Calendar（对齐 JS `new Date(y, m, d)`）。 */
    private fun calendarAt(year: Int, month0: Int, dayOfMonth: Int): Calendar {
        val cal = Calendar.getInstance()
        cal.clear()
        cal.set(year, month0, dayOfMonth)
        return cal
    }

    /** 月趋势锚点回溯天数。 */
    private val MONTH_OFFSETS: List<Int> = listOf(30, 25, 20, 15, 10, 5, 0)

    /** 月趋势标签（稀疏样式，对齐原型 `SERIES.month.labels` 的空串留白）。 */
    private val MONTH_LABELS: List<String> = listOf("30天前", "", "", "15天前", "", "", "现在")

    /** 年趋势锚点回溯月数。 */
    private val YEAR_OFFSETS: List<Int> = listOf(12, 10, 8, 6, 4, 2, 0)

    /** 年趋势标签（稀疏样式，对齐原型 `SERIES.year.labels` 的空串留白）。 */
    private val YEAR_LABELS: List<String> = listOf("12个月前", "", "", "6个月前", "", "", "现在")
}

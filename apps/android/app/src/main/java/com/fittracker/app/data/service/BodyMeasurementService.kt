package com.fittracker.app.data.service

import com.fittracker.app.data.model.BodyMeasurement
import com.fittracker.app.data.model.MEASUREMENT_UNSET
import com.fittracker.app.data.persist.JsonCodec
import com.fittracker.app.data.persist.JsonStore
import com.fittracker.app.data.persist.StoreNames
import java.util.Calendar
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.serialization.decodeFromString
import kotlinx.serialization.encodeToString

/**
 * 身体测量记录持久化（围度 + 体成分）——镜像鸿蒙 `shared/services/BodyMeasurementService.ets`。
 *
 * 落盘模型沿用本仓既有口径（[BodyRecordService]）：整份记录以**一块 JSON 数组**存于单键
 * [StoreNames.BODY_MEASUREMENTS]。写入共用一把 [writeMutex] 串行化（[addMeasurement] 的读-改-写
 * 是两次 suspend 往返，并发交错会丢更新）。
 *
 * 与 [BodyRecordService] 的差异：一条记录承载多项测量，未录入项为 [MEASUREMENT_UNSET]（-1）。
 * [addMeasurement] 采用**逐项合并**语义——同日重复录入时只覆盖本次明确提供的项，其余保留既有值
 * （避免「只记围度」把已录的体脂清掉）。
 */
object BodyMeasurementService {

    /** 实际 JsonStore 键——语义库名 `fit_tracker_body_measurements`。 */
    const val STORE_KEY: String = StoreNames.BODY_MEASUREMENTS

    /** 语义库名（与落盘键同值，供排障对照）。 */
    const val STORE_NAME: String = "fit_tracker_body_measurements"

    /** 最近一次持久化错误码。 */
    private var lastPersistenceError: String = ""

    /** 串行化对记录库的写入（同 [BodyRecordService.writeMutex] 的理由）。 */
    private val writeMutex: Mutex = Mutex()

    /** 最近一次持久化错误码；无错误为空串。 */
    fun getLastPersistenceError(): String = lastPersistenceError

    // --- 读 / 写 -------------------------------------------------------------

    /** 读回全部记录（按日期升序）。缺键 / 空串 / 解析失败一律回落空列表。 */
    suspend fun loadMeasurements(store: JsonStore): List<BodyMeasurement> {
        lastPersistenceError = ""
        val raw: String? = try {
            store.readString(STORE_KEY)
        } catch (error: Exception) {
            lastPersistenceError = "load_body_measurements_failed"
            return emptyList()
        }
        return decodeQuiet(raw)
    }

    /** 整份写入（先归一日期到日零点、再升序）。 */
    suspend fun saveMeasurements(store: JsonStore, records: List<BodyMeasurement>) {
        lastPersistenceError = ""
        try {
            writeMutex.withLock { writeRecords(store, records) }
        } catch (error: Exception) {
            lastPersistenceError = "save_body_measurements_failed"
        }
    }

    /**
     * 写入一条记录（读-改-写）。落在同一自然日的既有记录按**逐项合并**：
     * 本次为 [MEASUREMENT_UNSET] 的项保留既有值。
     */
    suspend fun addMeasurement(store: JsonStore, record: BodyMeasurement) {
        lastPersistenceError = ""
        try {
            writeMutex.withLock {
                val day = startOfDay(record.dateMillis)
                val existing = readQuiet(store)
                val previous = existing.firstOrNull { startOfDay(it.dateMillis) == day }
                val others = existing.filterNot { startOfDay(it.dateMillis) == day }
                writeRecords(store, others + merge(previous, record, day))
            }
        } catch (error: Exception) {
            lastPersistenceError = "save_body_measurement_failed"
        }
    }

    /** 清空全部记录（删键）。 */
    suspend fun clearMeasurements(store: JsonStore) {
        lastPersistenceError = ""
        try {
            writeMutex.withLock { store.remove(STORE_KEY) }
        } catch (error: Exception) {
            lastPersistenceError = "clear_body_measurements_failed"
        }
    }

    // --- 查询（纯函数） ------------------------------------------------------

    /** 最新一条记录；空列表返回 null。 */
    fun latest(records: List<BodyMeasurement>): BodyMeasurement? =
        records.maxByOrNull { it.dateMillis }

    /** 倒数第二条记录（用于「较上次」差值）；记录不足 2 条返回 null。 */
    fun previous(records: List<BodyMeasurement>): BodyMeasurement? =
        records.sortedBy { it.dateMillis }.let { if (it.size < 2) null else it[it.size - 2] }

    /** 某项的「较上次」差值；任一侧未录入返回 null。 */
    fun delta(latest: Double, previous: Double): Double? {
        if (latest == UNSET || previous == UNSET) return null
        return Math.round((latest - previous) * 10.0) / 10.0
    }

    // --- 内部 ---------------------------------------------------------------

    /** 未录入标记（[BodyMeasurement] 各数值字段的默认值）。 */
    private val UNSET: Double = MEASUREMENT_UNSET.toDouble()

    /** 逐项合并：`record` 中未录入（-1）的项沿用 `previous` 的既有值。 */
    private fun merge(previous: BodyMeasurement?, record: BodyMeasurement, day: Long): BodyMeasurement =
        BodyMeasurement(
            dateMillis = day,
            chestCm = pick(record.chestCm, previous?.chestCm),
            waistCm = pick(record.waistCm, previous?.waistCm),
            hipCm = pick(record.hipCm, previous?.hipCm),
            armCm = pick(record.armCm, previous?.armCm),
            thighCm = pick(record.thighCm, previous?.thighCm),
            bodyFatPercent = pick(record.bodyFatPercent, previous?.bodyFatPercent),
            skeletalMuscleKg = pick(record.skeletalMuscleKg, previous?.skeletalMuscleKg),
            bodyWaterPercent = pick(record.bodyWaterPercent, previous?.bodyWaterPercent),
        )

    private fun pick(incoming: Double, fallback: Double?): Double =
        if (incoming == UNSET) (fallback ?: UNSET) else incoming

    /** 静默读回当前记录（缺键 / 解析失败回落空列表），不触碰 [lastPersistenceError]。 */
    private suspend fun readQuiet(store: JsonStore): List<BodyMeasurement> =
        decodeQuiet(store.readString(STORE_KEY))

    private fun decodeQuiet(raw: String?): List<BodyMeasurement> {
        if (raw.isNullOrEmpty()) return emptyList()
        return try {
            JsonCodec.json.decodeFromString<List<BodyMeasurement>>(raw).sortedBy { it.dateMillis }
        } catch (error: Exception) {
            emptyList()
        }
    }

    private suspend fun writeRecords(store: JsonStore, records: List<BodyMeasurement>) {
        val normalized = records
            .map { it.copy(dateMillis = startOfDay(it.dateMillis)) }
            .sortedBy { it.dateMillis }
        store.writeString(STORE_KEY, JsonCodec.json.encodeToString(normalized))
    }

    /** 本地时区日零点（对齐 [BodyRecordService]：先取值，再在干净 Calendar 上设值）。 */
    private fun startOfDay(millis: Long): Long {
        val source = Calendar.getInstance().apply { timeInMillis = millis }
        val year = source.get(Calendar.YEAR)
        val month0 = source.get(Calendar.MONTH)
        val dayOfMonth = source.get(Calendar.DAY_OF_MONTH)
        val cal = Calendar.getInstance()
        cal.clear()
        cal.set(year, month0, dayOfMonth)
        return cal.timeInMillis
    }
}

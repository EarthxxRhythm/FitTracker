package com.fittracker.app.data.service

import com.fittracker.app.data.persist.JsonCodec
import com.fittracker.app.data.persist.JsonStore
import com.fittracker.app.data.persist.StoreNames
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.decodeFromString
import kotlinx.serialization.encodeToString

/** 缺省语言 id（原型 `settings.html:397` `简体中文` 为 active）。 */
private const val DEFAULT_LANGUAGE_ID: String = "zh"

/** 缺省周开始日 id（原型 `settings.html:404` `周一` 为 active）。 */
private const val DEFAULT_WEEK_START_ID: String = "monday"

/** 体重目标合法区间（kg）——与复盘页目标弹窗的越界校验同口径（对齐鸿蒙 `SettingsService`）。 */
private const val WEIGHT_GOAL_MIN_KG: Double = 30.0
private const val WEIGHT_GOAL_MAX_KG: Double = 200.0

/**
 * 界面语言——原型 `settings.html:395-399` 的 `简体中文` / `English` 分段。
 *
 * 本轮口径（D3）：「存储 + 回显 + toast」全量；**应用级语言切换（字符串资源重载）为 V2**，
 * 故 [id] 只作落盘 / 回显标识，不驱动资源。
 */
@Serializable
enum class SettingsLanguage(val id: String) {
    @SerialName("zh")
    ZH("zh"),

    @SerialName("en")
    EN("en"),
}

/** 周开始日——原型 `settings.html:402-406` 的 `周一` / `周日` 分段。 */
@Serializable
enum class WeekStart(val id: String) {
    @SerialName("monday")
    MONDAY("monday"),

    @SerialName("sunday")
    SUNDAY("sunday"),
}

/**
 * 设置屏偏好模型——原型 `settings.html` 的 3 分段（L389-406）+ 6 开关（L409-443）。
 *
 * 缺省值即原型**静止态初值**（`.active` / `class="on"`）：语言 `简体中文`、周开始日 `周一`、
 * 训练提醒 / 声音与震动 / 训练中屏幕常亮 为开，成就提醒 / 匿名使用数据 为关。
 *
 * 云同步为恒定自动（无开关项），不在本模型也不落盘。
 */
data class FtSettings(
    val language: SettingsLanguage = SettingsLanguage.ZH,
    val weekStart: WeekStart = WeekStart.MONDAY,
    val workoutReminder: Boolean = true,
    val achievementReminder: Boolean = false,
    val soundVibration: Boolean = true,
    val keepScreenOn: Boolean = true,
    val anonymousData: Boolean = false,
    /**
     * 复盘页体重目标（kg）；`0.0` = 用户从未设置。
     *
     * 归本模型而不归 `UserProfileService`：单位是随云同步 envelope 流转的档案字段，而目标体重
     * 只是复盘页的展示辅助值——纳入 envelope 需同步改备份包与 `LocalSnapshotStore` 的 hash
     * 视图白名单。故仅本地持久化（与鸿蒙 `SettingsService.weightGoalKg` 同口径）。
     */
    val weightGoalKg: Double = 0.0,
)

/**
 * 设置偏好的本地持久化服务。
 *
 * 落盘模型沿用本仓既有口径（[UserProfileService] / `PlanState` 等）：整份偏好以**一块 JSON**
 * 存于单键 [StoreNames.SETTINGS]（`fit_tracker_settings`）；单字段写入实现为**读-改-写**
 * （只改目标字段、其余保留）。落盘线格式见 [FtSettingsWire]——语言 / 周开始日以**原始字符串**
 * 承载并经 [normalizeLanguage] / [normalizeWeekStart] 归一，未知值不连带丢其余字段（宽容解析）。
 *
 * 与系统的联动：其余开关（提醒 / 常亮 / 匿名数据）本轮只做存储与回显，
 * **通知 / 屏幕常亮等系统行为为 V2**——值照常持久化，接入系统 API 时读同一模型即可。
 */
object SettingsService {

    /** 实际 JsonStore 键——语义库名 `fit_tracker_settings`（见 [StoreNames.SETTINGS]）。 */
    const val STORE_KEY: String = StoreNames.SETTINGS

    /** 语义库名（与落盘键同值，供排障对照）。 */
    const val STORE_NAME: String = "fit_tracker_settings"

    /** 最近一次持久化错误码（对齐 [UserProfileService.getLastPersistenceError] 口径）。 */
    private var lastPersistenceError: String = ""

    /**
     * 串行化对偏好库的写入。单字段 setter 的「读-改-写」（[mutateWire]）与整份写入
     * （[saveSettings]）／清空（[clearSettings]）共用这把锁：这些操作各自是多次 suspend
     * 往返（读一次、写一次），并发交错时后写者会以自己读到的旧快照覆盖先写者已提交的
     * 字段（丢更新）。加锁后每个临界区原子完成，消除该窗口。
     */
    private val writeMutex: Mutex = Mutex()

    /** 最近一次持久化错误码；无错误为空串。 */
    fun getLastPersistenceError(): String = lastPersistenceError

    // --- 读 / 写 -------------------------------------------------------------

    /**
     * 读回偏好。缺键 / 空串 / 解析失败一律回落 [getDefaultSettings]。
     */
    suspend fun loadSettings(store: JsonStore): FtSettings {
        lastPersistenceError = ""
        val raw: String? = try {
            store.readString(STORE_KEY)
        } catch (error: Exception) {
            lastPersistenceError = "load_settings_failed"
            return getDefaultSettings()
        }
        val wire: FtSettingsWire = if (raw.isNullOrEmpty()) getDefaultWire() else decodeWire(raw)
        return wire.toSettings()
    }

    /** 整份写入。 */
    suspend fun saveSettings(store: JsonStore, settings: FtSettings) {
        lastPersistenceError = ""
        try {
            writeMutex.withLock { writeWire(store, settings.toWire()) }
        } catch (error: Exception) {
            lastPersistenceError = "save_settings_failed"
        }
    }

    /** 只改语言（读-改-写）。 */
    suspend fun setLanguage(store: JsonStore, language: SettingsLanguage) {
        lastPersistenceError = ""
        try {
            mutateWire(store) { it.copy(language = language.id) }
        } catch (error: Exception) {
            lastPersistenceError = "save_settings_failed"
        }
    }

    /** 只改周开始日（读-改-写）。 */
    suspend fun setWeekStart(store: JsonStore, weekStart: WeekStart) {
        lastPersistenceError = ""
        try {
            mutateWire(store) { it.copy(weekStart = weekStart.id) }
        } catch (error: Exception) {
            lastPersistenceError = "save_settings_failed"
        }
    }

    /** 只改「训练提醒」开关（读-改-写）。 */
    suspend fun setWorkoutReminder(store: JsonStore, on: Boolean) {
        lastPersistenceError = ""
        try {
            mutateWire(store) { it.copy(workoutReminder = on) }
        } catch (error: Exception) {
            lastPersistenceError = "save_settings_failed"
        }
    }

    /** 只改「成就提醒」开关（读-改-写）。 */
    suspend fun setAchievementReminder(store: JsonStore, on: Boolean) {
        lastPersistenceError = ""
        try {
            mutateWire(store) { it.copy(achievementReminder = on) }
        } catch (error: Exception) {
            lastPersistenceError = "save_settings_failed"
        }
    }

    /** 只改「声音与震动」开关（读-改-写）。 */
    suspend fun setSoundVibration(store: JsonStore, on: Boolean) {
        lastPersistenceError = ""
        try {
            mutateWire(store) { it.copy(soundVibration = on) }
        } catch (error: Exception) {
            lastPersistenceError = "save_settings_failed"
        }
    }

    /** 只改「训练中屏幕常亮」开关（读-改-写）。 */
    suspend fun setKeepScreenOn(store: JsonStore, on: Boolean) {
        lastPersistenceError = ""
        try {
            mutateWire(store) { it.copy(keepScreenOn = on) }
        } catch (error: Exception) {
            lastPersistenceError = "save_settings_failed"
        }
    }

    /** 只改「匿名使用数据」开关（读-改-写）。 */
    suspend fun setAnonymousData(store: JsonStore, on: Boolean) {
        lastPersistenceError = ""
        try {
            mutateWire(store) { it.copy(anonymousData = on) }
        } catch (error: Exception) {
            lastPersistenceError = "save_settings_failed"
        }
    }

    /**
     * 持久化体重目标（kg）；传 `0.0` 表示清除。
     *
     * 越界值不写入（[normalizeWeightGoalKg] 归零），避免把越界值带进下次启动的展示态。
     */
    suspend fun saveWeightGoal(store: JsonStore, kg: Double) {
        lastPersistenceError = ""
        try {
            mutateWire(store) { it.copy(weightGoalKg = normalizeWeightGoalKg(kg)) }
        } catch (error: Exception) {
            lastPersistenceError = "save_weight_goal_failed"
        }
    }

    /** 缺省偏好（原型静止态初值）。 */
    fun getDefaultSettings(): FtSettings = FtSettings()

    /** 清空偏好（删键）——回落缺省。 */
    suspend fun clearSettings(store: JsonStore) {
        lastPersistenceError = ""
        try {
            writeMutex.withLock { store.remove(STORE_KEY) }
        } catch (error: Exception) {
            lastPersistenceError = "clear_settings_failed"
        }
    }

    /** 仅 `"en"` 判为 [SettingsLanguage.EN]，其余一律 [SettingsLanguage.ZH]。 */
    fun normalizeLanguage(value: String): SettingsLanguage =
        if (value == SettingsLanguage.EN.id) SettingsLanguage.EN else SettingsLanguage.ZH

    /** 仅 `"sunday"` 判为 [WeekStart.SUNDAY]，其余一律 [WeekStart.MONDAY]。 */
    fun normalizeWeekStart(value: String): WeekStart =
        if (value == WeekStart.SUNDAY.id) WeekStart.SUNDAY else WeekStart.MONDAY

    /**
     * 目标体重归一到「合法值或 0」。
     *
     * `0`、负数、`NaN`、越界值一律归 0（= 未设置）——UI 据此渲染空态。不静默收敛到边界：
     * 那会把用户输入的 250 kg 变成 200 kg 并当作真实目标保存。
     */
    fun normalizeWeightGoalKg(value: Double): Double {
        if (value.isNaN() || value < WEIGHT_GOAL_MIN_KG || value > WEIGHT_GOAL_MAX_KG) {
            return 0.0
        }
        return value
    }

    // --- 内部：整块 JSON 读写 ------------------------------------------------

    /** 静默读回当前线格式（缺键 / 解析失败回落缺省），供读-改-写用。 */
    private suspend fun readWireQuiet(store: JsonStore): FtSettingsWire {
        val raw: String? = store.readString(STORE_KEY)
        if (raw.isNullOrEmpty()) {
            return getDefaultWire()
        }
        return decodeWire(raw)
    }

    private fun decodeWire(raw: String): FtSettingsWire = try {
        JsonCodec.json.decodeFromString(raw)
    } catch (error: Exception) {
        getDefaultWire()
    }

    private fun getDefaultWire(): FtSettingsWire = FtSettingsWire()

    private suspend fun writeWire(store: JsonStore, wire: FtSettingsWire) {
        store.writeString(STORE_KEY, JsonCodec.json.encodeToString(wire))
    }

    private suspend fun mutateWire(store: JsonStore, transform: (FtSettingsWire) -> FtSettingsWire) {
        // 读-改-写整体作为临界区：readWireQuiet / writeWire 各是一次 suspend 往返，
        // 并发下若在两者之间交错，后写者会以旧快照覆盖先写者已提交的字段（丢更新）。
        writeMutex.withLock {
            writeWire(store, transform(readWireQuiet(store)))
        }
    }
}

/**
 * 落盘线格式：语言 / 周开始日以**原始字符串**承载，使未知值能经
 * [SettingsService.normalizeLanguage] / [SettingsService.normalizeWeekStart] 归一而不连带
 * 丢弃其余字段（宽容解析）。**不含云同步开关**——同步恒定自动。
 * 只在读写边界使用，不外泄。
 */
@Serializable
private data class FtSettingsWire(
    val language: String = DEFAULT_LANGUAGE_ID,
    val weekStart: String = DEFAULT_WEEK_START_ID,
    val workoutReminder: Boolean = true,
    val achievementReminder: Boolean = false,
    val soundVibration: Boolean = true,
    val keepScreenOn: Boolean = true,
    val anonymousData: Boolean = false,
    /** 体重目标（kg）；0 = 未设置。缺省值保证旧包（无此键）解码后即「未设置」而非解码失败。 */
    val weightGoalKg: Double = 0.0,
)

private fun FtSettingsWire.toSettings(): FtSettings = FtSettings(
    language = SettingsService.normalizeLanguage(language),
    weekStart = SettingsService.normalizeWeekStart(weekStart),
    workoutReminder = workoutReminder,
    achievementReminder = achievementReminder,
    soundVibration = soundVibration,
    keepScreenOn = keepScreenOn,
    anonymousData = anonymousData,
    weightGoalKg = SettingsService.normalizeWeightGoalKg(weightGoalKg),
)

private fun FtSettings.toWire(): FtSettingsWire = FtSettingsWire(
    language = language.id,
    weekStart = weekStart.id,
    workoutReminder = workoutReminder,
    achievementReminder = achievementReminder,
    soundVibration = soundVibration,
    keepScreenOn = keepScreenOn,
    anonymousData = anonymousData,
    weightGoalKg = weightGoalKg,
)

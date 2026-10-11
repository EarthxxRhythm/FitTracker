package com.fittracker.app.data.service

import com.fittracker.app.data.persist.JsonCodec
import com.fittracker.app.data.persist.JsonStore
import com.fittracker.app.data.persist.StoreNames
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.serialization.Serializable
import kotlinx.serialization.decodeFromString
import kotlinx.serialization.encodeToString

/** 每周训练天数缺省值（原型 `fittracker-training-preferences.html` 默认选中「4 天」）。 */
private const val DEFAULT_DAYS_PER_WEEK: Int = 4

/** 每周训练天数合法下界（原型档位 2/3/4/5 天）。 */
private const val MIN_DAYS_PER_WEEK: Int = 2

/** 每周训练天数合法上界（原型档位 2/3/4/5 天）。 */
private const val MAX_DAYS_PER_WEEK: Int = 5

/**
 * 训练目标——原型 `fittracker-training-preferences.html` chip 组 1「训练目标」（增肌/力量/减脂）。
 *
 * [id] 与 `SeedPlanRules` 的 `goalType` 口径**逐字一致**（`PlanEngine.kt:34-40`：`hypertrophy` /
 * `strength` / `fat_loss` / `posture`）——因此「增肌 → `hypertrophy`」等中文标签到生成规则的
 * 映射无需二次转换。原型无「体态」档，故不含 `posture`。
 */
enum class PrefGoal(val id: String) {
    MUSCLE_GAIN("hypertrophy"),
    STRENGTH("strength"),
    FAT_LOSS("fat_loss"),
}

/**
 * 训练经验——原型 chip 组 1「训练经验」（新手/进阶/熟练）。
 *
 * [id] 直接作为 `UserGoal.level` 进入 `PlanEngine`：`level` 参与**难度硬匹配**
 * （`PlanEngine.kt:210-212`：`exercise.difficulty != goal.level` 则被过滤）与**打分**
 * （`:230`：难度一致 +8）。故取值须落在动作库 `difficulty` 的实际集合内
 * （`beginner` / `intermediate` / `advanced`）。（Android 侧新增，供计划生成个性化。）
 */
enum class PrefLevel(val id: String) {
    BEGINNER("beginner"),
    INTERMEDIATE("intermediate"),
    ADVANCED("advanced"),
}

/**
 * 训练偏好模型——原型 `fittracker-training-preferences.html` 的 6 组 chip
 * （目标/经验/每周天数/单次时长/可用器械/限制肌群）。
 *
 * 缺省值即原型**静止态初值**：目标「增肌」、经验「进阶」、每周 4 天、单次 45 分钟、
 * 器械「自重 + 哑铃」、限制肌群全不选。
 *
 * 与 [UserGoal] 的关系：本模型经 `PlanAdapter.preferencesToGoal` 映射为目标 →
 * `PlanEngine` 生成计划；`daysPerWeek` 边界 `2..5`、非法值在 [TrainingPreferencesService]
 * 读取时归一为 [DEFAULT_DAYS_PER_WEEK]（宽容解析）。
 */
data class FtTrainingPreferences(
    val goal: PrefGoal = PrefGoal.MUSCLE_GAIN,
    val level: PrefLevel = PrefLevel.INTERMEDIATE,
    val daysPerWeek: Int = DEFAULT_DAYS_PER_WEEK,
    val sessionMinutes: Int = 45,
    val equipmentIds: Set<String> = setOf("eq_bodyweight", "eq_dumbbell"),
    val restrictedMuscleIds: Set<String> = emptySet(),
)

/**
 * 训练偏好的本地持久化服务。
 *
 * 落盘模型沿用本仓既有口径（[SettingsService] / [UserProfileService]）：整份偏好以**一块 JSON**
 * 存于单键 [StoreNames.TRAINING_PREFERENCES]（`fit_tracker_training_preferences`）。
 * 落盘线格式见 [FtTrainingPreferencesWire]——目标 / 经验以**原始字符串**承载并经
 * [normalizeGoal] / [normalizeLevel] 归一，未知值不连带丢其余字段（宽容解析）；
 * [FtTrainingPreferences.daysPerWeek] 出界时经 [normalizeDaysPerWeek] 归一回缺省。
 *
 * **不进备份包**（计划决策 D-6）：备份包与鸿蒙工程 `schemaVersion=1` 互通，鸿蒙无此模型，
 * 加字段会破坏互通口径；换机场景经「重新设置偏好」重建。
 *
 * 并发：[writeMutex] 串行化整份写入与清空——两者各是多次 suspend 往返（读写 / 删除），
 * 并发交错时会互相覆盖（丢更新），加锁后每个临界区原子完成。
 */
object TrainingPreferencesService {

    /** 实际 JsonStore 键——语义库名 `fit_tracker_training_preferences`。 */
    const val STORE_KEY: String = StoreNames.TRAINING_PREFERENCES

    /** 语义库名（与落盘键同值，供排障对照）。 */
    const val STORE_NAME: String = "fit_tracker_training_preferences"

    /** 最近一次持久化错误码（对齐 [SettingsService.getLastPersistenceError] 口径）。 */
    private var lastPersistenceError: String = ""

    /** 串行化对偏好库的写入（整份写入 [savePreferences] 与清空 [clearPreferences] 共用）。 */
    private val writeMutex: Mutex = Mutex()

    /** 最近一次持久化错误码；无错误为空串。 */
    fun getLastPersistenceError(): String = lastPersistenceError

    // --- 读 / 写 -------------------------------------------------------------

    /**
     * 读回偏好。缺键 / 空串 / 解析失败一律回落 [getDefaultPreferences]；
     * 已知字段出界（未知目标/经验 / 天数越界）按各自归一规则夹取，不连带丢其余字段。
     */
    suspend fun loadPreferences(store: JsonStore): FtTrainingPreferences {
        lastPersistenceError = ""
        val raw: String? = try {
            store.readString(STORE_KEY)
        } catch (error: Exception) {
            lastPersistenceError = "load_training_preferences_failed"
            return getDefaultPreferences()
        }
        val wire: FtTrainingPreferencesWire = if (raw.isNullOrEmpty()) {
            getDefaultWire()
        } else {
            decodeWire(raw)
        }
        return wire.toPreferences()
    }

    /** 整份写入（Mutex 包临界区）。 */
    suspend fun savePreferences(store: JsonStore, preferences: FtTrainingPreferences) {
        lastPersistenceError = ""
        try {
            writeMutex.withLock { writeWire(store, preferences.toWire()) }
        } catch (error: Exception) {
            lastPersistenceError = "save_training_preferences_failed"
        }
    }

    /** 缺省偏好（原型静止态初值）。 */
    fun getDefaultPreferences(): FtTrainingPreferences = FtTrainingPreferences()

    /** 清空偏好（删键）——回落缺省。 */
    suspend fun clearPreferences(store: JsonStore) {
        lastPersistenceError = ""
        try {
            writeMutex.withLock { store.remove(STORE_KEY) }
        } catch (error: Exception) {
            lastPersistenceError = "clear_training_preferences_failed"
        }
    }

    // --- 归一（宽容解析） ----------------------------------------------------

    /** 仅 `"strength"` / `"fat_loss"` 判为对应档，其余一律 [PrefGoal.MUSCLE_GAIN]。 */
    fun normalizeGoal(value: String): PrefGoal = when (value) {
        PrefGoal.STRENGTH.id -> PrefGoal.STRENGTH
        PrefGoal.FAT_LOSS.id -> PrefGoal.FAT_LOSS
        else -> PrefGoal.MUSCLE_GAIN
    }

    /** 仅 `"beginner"` / `"advanced"` 判为对应档，其余一律 [PrefLevel.INTERMEDIATE]。 */
    fun normalizeLevel(value: String): PrefLevel = when (value) {
        PrefLevel.BEGINNER.id -> PrefLevel.BEGINNER
        PrefLevel.ADVANCED.id -> PrefLevel.ADVANCED
        else -> PrefLevel.INTERMEDIATE
    }

    /** 落在 `2..5` 内原样返回，否则回落缺省 [DEFAULT_DAYS_PER_WEEK]。 */
    fun normalizeDaysPerWeek(value: Int): Int =
        if (value in MIN_DAYS_PER_WEEK..MAX_DAYS_PER_WEEK) value else DEFAULT_DAYS_PER_WEEK

    // --- 内部：整块 JSON 读写 ------------------------------------------------

    private fun decodeWire(raw: String): FtTrainingPreferencesWire = try {
        JsonCodec.json.decodeFromString(raw)
    } catch (error: Exception) {
        getDefaultWire()
    }

    private fun getDefaultWire(): FtTrainingPreferencesWire = FtTrainingPreferencesWire()

    private suspend fun writeWire(store: JsonStore, wire: FtTrainingPreferencesWire) {
        store.writeString(STORE_KEY, JsonCodec.json.encodeToString(wire))
    }
}

/**
 * 落盘线格式：目标 / 经验以**原始字符串**承载，使未知值能经
 * [TrainingPreferencesService.normalizeGoal] / [TrainingPreferencesService.normalizeLevel]
 * 归一而不连带丢弃其余字段（宽容解析）。只在读写边界使用，不外泄。
 */
@Serializable
private data class FtTrainingPreferencesWire(
    val goal: String = "hypertrophy",
    val level: String = "intermediate",
    val daysPerWeek: Int = DEFAULT_DAYS_PER_WEEK,
    val sessionMinutes: Int = 45,
    val equipmentIds: List<String> = listOf("eq_bodyweight", "eq_dumbbell"),
    val restrictedMuscleIds: List<String> = emptyList(),
)

private fun FtTrainingPreferencesWire.toPreferences(): FtTrainingPreferences = FtTrainingPreferences(
    goal = TrainingPreferencesService.normalizeGoal(goal),
    level = TrainingPreferencesService.normalizeLevel(level),
    daysPerWeek = TrainingPreferencesService.normalizeDaysPerWeek(daysPerWeek),
    sessionMinutes = sessionMinutes,
    equipmentIds = equipmentIds.toSet(),
    restrictedMuscleIds = restrictedMuscleIds.toSet(),
)

private fun FtTrainingPreferences.toWire(): FtTrainingPreferencesWire = FtTrainingPreferencesWire(
    goal = goal.id,
    level = level.id,
    daysPerWeek = daysPerWeek,
    sessionMinutes = sessionMinutes,
    equipmentIds = equipmentIds.toList(),
    restrictedMuscleIds = restrictedMuscleIds.toList(),
)

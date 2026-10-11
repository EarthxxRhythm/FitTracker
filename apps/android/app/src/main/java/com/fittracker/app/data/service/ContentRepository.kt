package com.fittracker.app.data.service

import android.content.Context
import androidx.appcompat.app.AppCompatDelegate
import com.fittracker.app.data.model.EquipmentItem
import com.fittracker.app.data.model.ExerciseContent
import com.fittracker.app.data.model.MuscleGroup
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import java.util.Locale

/**
 * 内容库资产（`assets/exercise-content.json`）的顶层 schema。
 *
 * 字段名与鸿蒙 `LLocalContent` 种子一致（见 `LocalExerciseContent.ets:7/16/25` 的三个导出数组）。
 */
@Serializable
internal data class ExerciseContentBundle(
    val muscles: List<MuscleGroup> = emptyList(),
    val equipment: List<EquipmentItem> = emptyList(),
    val exercises: List<ExerciseContent> = emptyList(),
)

/**
 * 本地动作内容库——只读内容访问单例。
 *
 * 移植自鸿蒙 `shared/services/ContentRepository.ets`（`ContentRepositoryImpl`，L120-613）
 * 的只读子集：装载种子内容 + 建索引 + 查询。鸿蒙侧的可插拔数据源
 * （`ContentDataSource` / `JsonlSeedContentDataSource`）与远程同步**不在本波范围**——
 * 安卓侧内容源即内置资产文件。
 *
 * 数据源：`app/src/main/assets/exercise-content.json`，由
 * `tools/` 外的抽取脚本从鸿蒙 `generated/LocalExerciseContent.ets` 逐字转换
 * （6 肌群 / 6 器械 / 50 动作，字段名对齐 `data/model/TrainingModels.kt`）。
 *
 * 互操作约束：字段名与鸿蒙 JSON 序列化输出**逐字一致**——不要为了「Kotlin 味」重命名。
 */
object ContentRepository {

    /** 资产文件名（`app/src/main/assets/`）。 */
    const val ASSET_NAME: String = "exercise-content.json"

    private val json = Json { ignoreUnknownKeys = true }

    private var orderedMuscles: List<MuscleGroup> = emptyList()
    private var orderedEquipment: List<EquipmentItem> = emptyList()
    private var orderedExercises: List<ExerciseContent> = emptyList()

    private var muscleIndex: Map<String, MuscleGroup> = emptyMap()
    private var equipmentIndex: Map<String, EquipmentItem> = emptyMap()
    private var exerciseIndex: Map<String, ExerciseContent> = emptyMap()

    /** 是否已成功装载过一次（`load` 幂等，重复调用会重建索引）。 */
    var isLoaded: Boolean = false
        private set

    /**
     * 从应用的 [Context.getAssets] 装载内容库并建索引。
     *
     * 抛 [java.io.IOException]（资产缺失）或 [kotlinx.serialization.SerializationException]（schema 不符）
     * 时保持原状态不变——由调用方决定是否降级。
     */
    suspend fun load(context: Context) {
        val text = context.assets.open(ASSET_NAME).bufferedReader().use { it.readText() }
        val bundle = json.decodeFromString(ExerciseContentBundle.serializer(), text)

        orderedMuscles = bundle.muscles
        orderedEquipment = bundle.equipment
        orderedExercises = bundle.exercises

        muscleIndex = bundle.muscles.associateBy { it.muscleId }
        equipmentIndex = bundle.equipment.associateBy { it.equipmentId }
        exerciseIndex = bundle.exercises.associateBy { it.exerciseId }

        isLoaded = true
    }

    /** 全部肌群（种子顺序）。 */
    fun muscles(): List<MuscleGroup> = orderedMuscles

    /** 全部器械（种子顺序）。 */
    fun equipment(): List<EquipmentItem> = orderedEquipment

    /** 全部动作（种子顺序）。 */
    fun exercises(): List<ExerciseContent> = orderedExercises

    /**
     * 当前语言标签——应用级 per-app locale（`AppCompatDelegate`，设置页语言分段）
     * 优先；未设置时回落系统 `Locale.getDefault()`。
     *
     * 载入内容库时**不**缓存语言（展示名按调用时语言解析），这样切语言后无需重新装载。
     */
    fun currentLanguageTag(): String {
        val appLocales = AppCompatDelegate.getApplicationLocales()
        val tag = if (appLocales.isEmpty) "" else appLocales.toLanguageTags()
        return tag.ifBlank { Locale.getDefault().language }
    }

    /**
     * 肌群展示名（纯函数，便于单测）：[languageTag] 以 `zh` 开头取 [MuscleGroup.nameZh]，
     * 否则取 [MuscleGroup.nameEn]（为空则回落中文——兼容旧数据 / 旧互通包）。
     */
    fun muscleDisplayName(muscle: MuscleGroup, languageTag: String): String =
        if (languageTag.startsWith("zh")) muscle.nameZh
        else muscle.nameEn.ifBlank { muscle.nameZh }

    /** 器械展示名（纯函数）：语义同 [muscleDisplayName]。 */
    fun equipmentDisplayName(equipment: EquipmentItem, languageTag: String): String =
        if (languageTag.startsWith("zh")) equipment.nameZh
        else equipment.nameEn.ifBlank { equipment.nameZh }

    /**
     * 肌群展示名（**按当前语言**）；未知 id 回退为 id 本身
     * （对齐 `ContentRepository.ets:250` 的 `getMuscleName`）。
     */
    fun getMuscleName(id: String): String =
        muscleIndex[id]?.let { muscleDisplayName(it, currentLanguageTag()) } ?: id

    /**
     * 器械展示名（**按当前语言**）；未知 id 回退为 id 本身
     * （对齐 `ContentRepository.ets:261` 的 `getEquipmentName`）。
     */
    fun getEquipmentName(id: String): String =
        equipmentIndex[id]?.let { equipmentDisplayName(it, currentLanguageTag()) } ?: id

    /**
     * 按 id 取动作；未知返回 `null`
     * （对齐 `ContentRepository.ets:213` 的 `getExerciseById` 返回 `undefined`）。
     */
    fun getExercise(id: String): ExerciseContent? = exerciseIndex[id]

    /**
     * 统一检索——把鸿蒙侧分立的 `searchExercises(query)`（`ContentRepository.ets:300`）
     * 与 `filterExerciseLibraryItems(...)`（L178-206）合成一个入口。
     *
     * 过滤语义（合并后的口径，逐条对照源）：
     * - `query` 非空白：动作的 `exerciseId` / `nameZh` / `nameEn` / 任一 `alias` 含该串即命中，
     *   大小写不敏感、子串匹配（对齐 `matchesExercise`，L363-378）。
     * - `muscleId` 非空白：`primaryMuscleIds` 或 `secondaryMuscleIds` 含之即命中
     *   （对齐 `matchesLibraryFilter` 的肌群分支，L441-462）。
     * - `equipmentId` 非空白：`equipmentIds` 含之即命中（同源）。
     * - **三者皆空**（`query` 空白且两个过滤为 `null`/空白）→ 返回全库：
     *   对齐 `matchesLibraryFilter` 里「空参数即不约束」的判定（L441-462），
     *   而非 `searchExercises` 的「空查询返回空」。空过滤 = 无过滤，是库屏默认态。
     *
     * 返回顺序 = 种子顺序（稳定，便于 UI 分页/分组）。
     */
    fun search(
        query: String = "",
        muscleId: String? = null,
        equipmentId: String? = null,
    ): List<ExerciseContent> {
        val normalizedQuery = query.trim().lowercase()
        val muscle: String = muscleId?.trim().orEmpty()
        val equipment: String = equipmentId?.trim().orEmpty()
        return orderedExercises.filter { exercise ->
            matchesQuery(exercise, normalizedQuery) &&
                matchesMuscle(exercise, muscle) &&
                matchesEquipment(exercise, equipment)
        }
    }

    /** 对齐 `ContentRepository.ets:363-378` 的 `matchesExercise`。 */
    private fun matchesQuery(exercise: ExerciseContent, normalizedQuery: String): Boolean {
        if (normalizedQuery.isEmpty()) {
            return true
        }
        if (exercise.exerciseId.lowercase().contains(normalizedQuery)) {
            return true
        }
        if (exercise.nameZh.lowercase().contains(normalizedQuery)) {
            return true
        }
        if (exercise.nameEn.lowercase().contains(normalizedQuery)) {
            return true
        }
        return exercise.aliases.any { it.lowercase().contains(normalizedQuery) }
    }

    /** 对齐 `ContentRepository.ets:441-462` 的肌群分支（主/次肌群任一命中）。 */
    private fun matchesMuscle(exercise: ExerciseContent, muscleId: String): Boolean {
        if (muscleId.isEmpty()) {
            return true
        }
        return muscleId in exercise.primaryMuscleIds || muscleId in exercise.secondaryMuscleIds
    }

    /** 对齐 `ContentRepository.ets:441-462` 的器械分支。 */
    private fun matchesEquipment(exercise: ExerciseContent, equipmentId: String): Boolean {
        if (equipmentId.isEmpty()) {
            return true
        }
        return equipmentId in exercise.equipmentIds
    }
}

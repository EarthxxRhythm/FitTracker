package com.fittracker.app.ui.screens.library

import androidx.annotation.StringRes
import com.fittracker.app.R
import com.fittracker.app.data.model.ExerciseContent
import com.fittracker.app.data.service.ContentRepository

/**
 * 动作库条目模型——原型 `EXERCISES[]`（L650-674）的**演示样例**与内容库
 * `data/model/ExerciseContent`（`TrainingModels.ets` 移植、面向真实内容同步）
 * 的屏内轻量视图。
 *
 * 两个来源共用本模型：
 * - **真实内容**（`assets/exercise-content.json`，50 动作，经 [FtLibraryModel.toLibraryExercise]
 *   映射）填满 [partId] / [equipmentId] / [muscleIds] 三个 id 字段——筛选 / 分组一律按 id 匹配，
 *   与语言无关；
 * - **原型演示样例**（[FtLibraryModel.EXERCISES]，内容库装载失败时的降级清单）为纯展示数据，
 *   三个 id 字段留空。
 *
 * 展示名（[part] / [equipment] / [muscles] / [name]）来自内容库
 * （`ContentRepository`，按当前语言取 `nameZh` / `nameEn`），屏内不硬编码部位 / 器械名。
 */
data class FtLibraryExercise(
    /** 原型 `id`（同时用作演示 GIF 资源名 `${id}.gif`，L705）。 */
    val id: String,
    /** 动作名（原型 `name`）。 */
    val name: String,
    /** 部位**展示名**（原型 `part` 的中文名；真实内容取主肌群展示名）。 */
    val part: String,
    /**
     * 肌群展示位（原型 `muscle`）。原型样例里是细分肌群（如「胸大肌」）；真实内容仅一层
     * 部位级肌群，此字段即主肌群展示名（如「胸部」）。
     * **筛选不再对该字段做等值匹配**（二级筛选改按 [muscleIds]，见 [FtLibraryModel.filterSource]）。
     */
    val muscle: String,
    /** 器械**展示名**（原型 `equipment`，对应分组标题）。 */
    val equipment: String,
    /** 难度（真实内容为语言无关 token：`beginner` / `intermediate` / `advanced`，
     *  展示由 [FtLibraryModel.difficultyLabelRes] 解析；原型样例为已本地化标签）。 */
    val level: String,
    /** 「目标肌群」展示串（原型 `muscles`，分隔符 [FtLibraryModel.MUSCLE_SEP]）。 */
    val muscles: String,
    /** 动作要点（原型 `tip`）。 */
    val tip: String,
    /** 部位（主肌群）id，如 `muscle_chest`——「部位」一级筛选的匹配键；原型样例留空。 */
    val partId: String = "",
    /** 器械 id，如 `eq_barbell`——分组 / 匹配键；原型样例留空。 */
    val equipmentId: String = "",
    /** 涉及的全部肌群 id（主 + 辅）——「肌群」二级筛选的匹配键；原型样例留空。 */
    val muscleIds: List<String> = emptyList(),
)

/** 按器械归并后的一个分组（原型 `.eq-group`，渲染见 L755-763）。 */
data class FtLibraryGroup(
    val equipment: String,
    val items: List<FtLibraryExercise>,
)

/**
 * 动作库屏的纯逻辑层——无 Compose 依赖，可单测。
 *
 * 规格源：原型 `design/06_prototype_redraw/src/fittracker-exercise-library.html`
 * （器材顺序 L640 · 器械 slug L641 · 肌群表 L642-649 · 动作集 L650-674 ·
 * 部位筛选条 L581-587 · 搜索键 L577 · 空态文案 L747-750 · 详情弹层填充 L767-781）。
 */
object FtLibraryModel {

    /**
     * 「全部」部位筛选哨兵。**不是展示文案**——展示名走资源 `library_part_all`
     * （原型 `currentPart` 初值「全部」，L686）。
     */
    const val ALL_PARTS = "__all__"

    /**
     * 「全部肌群」筛选哨兵。**不是展示文案**——展示名走资源 `library_muscle_all`
     * （原型 `currentMuscle` 初值「全部肌群」，L687）。
     */
    const val ALL_MUSCLES = "__all_muscles__"

    /**
     * 部位一级筛选条的稳定 id 序列——哨兵 [ALL_PARTS] + 6 个肌群 id，序对齐原型
     * L581-587 的七个 `data-part` 按钮（全部 / 胸 / 背 / 肩 / 臂 / 腿 / 核心）。
     *
     * 展示名不在此处：哨兵 → [PART_ALL_RES]；其余 → `ContentRepository.getMuscleName(id)`
     * （内容库按当前语言返回 `nameZh` / `nameEn`）。
     */
    val PART_IDS: List<String> = listOf(
        ALL_PARTS,
        "muscle_chest",
        "muscle_back",
        "muscle_shoulders",
        "muscle_arms",
        "muscle_legs",
        "muscle_core",
    )

    // ── 屏内文案资源（Wave 8 i18n；中文真源在 `values/strings_library.xml`） ─────
    // 部位 / 肌群 / 器械名**不在此列**——它们来自内容库（`ContentRepository`）。

    /** 「全部」部位胶囊展示名。 */
    @StringRes
    val PART_ALL_RES = R.string.library_part_all

    /** 「全部肌群」胶囊展示名。 */
    @StringRes
    val MUSCLE_ALL_RES = R.string.library_muscle_all

    /** 搜索框占位文案（原型 `placeholder`，L577）。 */
    @StringRes
    val SEARCH_HINT_RES = R.string.library_search_hint

    /** 滚动区页脚说明（原型 `.st-foot-note`，L599）。 */
    @StringRes
    val FOOT_NOTE_RES = R.string.library_foot_note

    /** 详情弹层演示小旗（原型 `.lib-sheet-media-tag`，L610）。 */
    @StringRes
    val SHEET_MEDIA_TAG_RES = R.string.library_sheet_media_tag

    /** 详情弹层三行标签（原型 `.lib-sheet-row .k`，L618-620）：目标肌群 / 器械 / 难度。 */
    val SHEET_ROW_LABEL_RES: List<Int> = listOf(
        R.string.library_sheet_row_muscles,
        R.string.library_sheet_row_equipment,
        R.string.library_sheet_row_level,
    )

    /** 详情弹层主按钮文案（原型 `data-od-id="add-to-plan"`，L623）。 */
    @StringRes
    val SHEET_CTA_RES = R.string.library_sheet_cta

    /** 主按钮点击后的置灰文案（原型 L885，1600ms 后复原，L886）。 */
    @StringRes
    val SHEET_CTA_DONE_RES = R.string.library_sheet_cta_done

    /**
     * 加入计划的浮层文案模板（原型 L887：`'已把「' + name + '」加入今日计划'`）——
     * UI 层 `stringResource(TOAST_ADDED_RES, 动作名)` 插值。
     */
    @StringRes
    val TOAST_ADDED_RES = R.string.library_toast_added

    /**
     * 动作集（原型 `EXERCISES`，L650-674，逐字移植）。
     *
     * 顺序即原型声明顺序——同一分组内的卡片按此序排列。
     */
    val EXERCISES: List<FtLibraryExercise> = listOf(
        FtLibraryExercise("push-up", "俯卧撑", "胸部", "胸大肌", "自重", "入门",
            "胸大肌 · 三角肌前束 · 肱三头肌", "核心收紧，身体保持一条直线，下放至胸部接近地面后推起。"),
        FtLibraryExercise("barbell-bench-press", "杠铃卧推", "胸部", "胸大肌", "杠铃", "进阶",
            "胸大肌 · 三角肌前束 · 肱三头肌", "肩胛后收下沉，杠铃下放至胸部中段，推起时呼气。"),
        FtLibraryExercise("dumbbell-fly", "哑铃飞鸟", "胸部", "胸大肌", "哑铃", "进阶",
            "胸大肌", "肘部保持微屈，双臂向两侧展开至胸部充分拉伸，再夹拢。"),
        FtLibraryExercise("cable-crossover", "绳索夹胸", "胸部", "胸大肌", "器械", "进阶",
            "胸大肌内侧", "身体略前倾，双手向身体中线夹拢，顶峰收缩 1 秒。"),
        FtLibraryExercise("pull-up", "引体向上", "背部", "背阔肌", "自重", "进阶",
            "背阔肌 · 肱二头肌", "肩胛下沉，将胸部引向横杆，避免摆动借力。"),
        FtLibraryExercise("barbell-row", "杠铃划船", "背部", "背阔肌", "杠铃", "进阶",
            "背阔肌 · 斜方肌 · 菱形肌", "髋部后移、背部平直，将杠铃拉向腹部，肩胛主动后收。"),
        FtLibraryExercise("seated-row", "坐姿划船", "背部", "菱形肌", "器械", "入门",
            "背阔肌 · 菱形肌", "挺胸收腹，肘部贴近身体向后拉，挤压肩胛骨。"),
        FtLibraryExercise("lat-pulldown", "高位下拉", "背部", "背阔肌", "器械", "入门",
            "背阔肌", "下拉至锁骨上方，控制还原，避免耸肩和身体后仰。"),
        FtLibraryExercise("band-pulldown", "弹力带高位下拉", "背部", "背阔肌", "弹力带", "入门",
            "背阔肌", "固定弹力带于高位，下拉至锁骨，控制还原。"),
        FtLibraryExercise("overhead-press", "站姿推举", "肩部", "三角肌前束", "哑铃", "进阶",
            "三角肌前中束", "核心收紧，将哑铃推至头顶上方，避免腰部过度反弓。"),
        FtLibraryExercise("lateral-raise", "侧平举", "肩部", "三角肌中束", "哑铃", "入门",
            "三角肌中束", "肘部微屈，抬至与肩同高即可，避免耸肩借力。"),
        FtLibraryExercise("band-lateral-raise", "弹力带侧平举", "肩部", "三角肌中束", "弹力带", "入门",
            "三角肌中束", "踩住弹力带，双臂向两侧抬至与肩同高。"),
        FtLibraryExercise("face-pull", "面拉", "肩部", "三角肌后束", "器械", "入门",
            "三角肌后束 · 上背", "拉向面部，肘部外展高于手腕，改善圆肩体态。"),
        FtLibraryExercise("biceps-curl", "二头弯举", "手臂", "肱二头肌", "哑铃", "入门",
            "肱二头肌", "上臂贴紧身体，避免摆动借力，顶峰收缩。"),
        FtLibraryExercise("triceps-pushdown", "绳索下压", "手臂", "肱三头肌", "器械", "入门",
            "肱三头肌", "肘部固定于身体两侧，下压至手臂完全伸直。"),
        FtLibraryExercise("squat", "深蹲", "腿部", "股四头肌", "杠铃", "进阶",
            "股四头肌 · 臀大肌", "膝盖与脚尖同向，下蹲至大腿接近平行地面，保持躯干稳定。"),
        FtLibraryExercise("lunge", "弓步蹲", "腿部", "股四头肌", "哑铃", "入门",
            "股四头肌 · 臀大肌", "前膝与脚尖同向，身体垂直下沉，后膝轻触地面。"),
        FtLibraryExercise("leg-press", "腿举", "腿部", "股四头肌", "器械", "入门",
            "股四头肌 · 臀大肌", "下放至膝盖约 90 度，避免完全锁死膝关节。"),
        FtLibraryExercise("leg-curl", "腿弯举", "腿部", "腘绳肌", "器械", "入门",
            "腘绳肌", "控制离心下放，顶峰收缩大腿后侧。"),
        FtLibraryExercise("band-squat", "弹力带深蹲", "腿部", "股四头肌", "弹力带", "入门",
            "股四头肌 · 臀大肌", "踩住弹力带下蹲，起身时保持弹力带张力。"),
        FtLibraryExercise("plank", "平板支撑", "核心", "腹直肌", "自重", "入门",
            "腹横肌 · 腹直肌", "身体保持一条直线，收紧核心与臀部，避免塌腰。"),
        FtLibraryExercise("crunch", "卷腹", "核心", "腹直肌", "自重", "入门",
            "腹直肌", "下背贴地，卷起上背而非颈部，呼气时收缩腹部。"),
        FtLibraryExercise("hanging-leg-raise", "悬垂举腿", "核心", "腹直肌", "自重", "熟练",
            "腹直肌 · 髂腰肌", "控制身体不摆动，抬腿至与地面平行或更高。"),
    )

    // ── 动作 GIF 素材映射（W2-2） ───────────────────────────────────────────
    // 素材：`design/06_prototype_redraw/assets/exercise-gifs/`（23 个 GIF，© Gym visual，
    // 经 hasaneyldrm/exercises-dataset 授权）→ 已拷贝到 `app/src/main/assets/exercise-gifs/`。
    // 原型 `fittracker-exercise-library.html` L705/L771 以 `assets/exercise-gifs/<id>.gif` 引用，
    // 即**素材文件名 == 原型动作 id**（[EXERCISES] 的 `id`）。真实内容 id 为 `ex_*` 不同名，
    // 故先按 id 命中，再按动作名（[GIF_BY_NAME] / [GIF_NAME_ALIASES]）；未匹配返回 null 保留占位。

    /**
     * 已停用：原「线稿」素材目录。
     *
     * 2026-10-28 版权清理：该套 23 个 GIF 为 Gym Visual（© gymvisual.com）素材，
     * 经第三方数据集转授权，授权链条不成立，已从仓库移除。见仓库根 ASSETS.md。
     * 现在动作演示统一走 [PhotoGifCatalog]（free-exercise-db，Unlicense）。
     */
    const val GIF_ASSET_DIR: String = "exercise-gifs-photo"

    /** 已有素材的文件名集合（不含目录与扩展名）——即 [EXERCISES] 各 `id`。 */
    val GIF_FILE_NAMES: Set<String> = EXERCISES.map { it.id }.toSet()

    /** 动作名 → GIF 文件名（由 [EXERCISES] 的 `name` → `id` 派生）。 */
    val GIF_BY_NAME: Map<String, String> = EXERCISES.associate { it.name to it.id }

    /** 真实内容中与原型样例**同义**的动作名 → GIF 文件名（仅收器械/轨迹一致的等价动作）。 */
    val GIF_NAME_ALIASES: Map<String, String> = mapOf(
        "杠铃深蹲" to "squat",
        "哑铃弯举" to "biceps-curl",
        "坐姿绳索划船" to "seated-row",
        "行进弓步" to "lunge",
        "哑铃侧平举" to "lateral-raise",
        // 2026-10-09 扩充（真机反馈「有些 gif 没有显示」）：把同一动作家族/变式的产物名并入素材映射。
        // 覆盖 16 → 22/50；其余动作暂无对应素材（素材库 23 个的客观边界）。
        "悬垂提膝" to "hanging-leg-raise", // 同名动作（Hanging Leg Raise）
        "窄距俯卧撑" to "push-up", // 俯卧撑变式
        "反握高位下拉" to "lat-pulldown", // 下拉变式
        "哑铃肩推" to "overhead-press", // 肩推/推举
        "杠铃推举" to "overhead-press", // 杠铃推举 = Overhead Press（与哑铃肩推共用演示素材）
        "杠铃弯举" to "biceps-curl", // 弯举（与哑铃弯举共用演示素材）
        "单腿腿举" to "leg-press", // 腿举器械变式
    )

    /**
     * 动作对应的 GIF asset 路径；无匹配返回 null。
     *
     * 两套素材，与鸿蒙端同规则：
     * 1. **线稿优先**——先按 id 命中（原型样例 id == 文件名），否则按动作名
     *    （[GIF_BY_NAME] / [GIF_NAME_ALIASES]），命中即用 [GIF_ASSET_DIR]（抠图透明版）。
     *    这一层保证「杠铃划船」「腿弯举」等两组同有的动作在老端上观感不变。
     * 2. **实拍兜底**——线稿未覆盖时查 [PhotoGifCatalog.BY_NAME]（free-exercise-db 实拍照
     *    合成的 59 个素材），命中即用其 [PhotoGifCatalog.ASSET_DIR]。这些是全彩矩形实景、
     *    无白底，靠调用方已有的卡片圆角（LibraryScreen 的 `RoundedCornerShape(14.dp)`）
     *    收敛，故此处只给出路径，不改视觉。
     */
    fun gifAssetFor(id: String, name: String): String? {
        // 2026-10-28：线稿层已随版权清理整体停用，不再参与解析。
        // 若保留「线稿 id 先命中」的逻辑，它会返回 exercise-gifs-photo/<线稿id>.gif —— 该文件
        // 不存在，于是连本可用的实拍兜底也被跳过，导致「杠铃划船」这类两端都有的动作退化成占位块。
        // 故此处直接短路到实拍层，未知动作返回 null，由调用方渲染占位。
        val photo = PhotoGifCatalog.BY_NAME[name]
        return photo?.let { "${PhotoGifCatalog.ASSET_DIR}/$it.gif" }
    }

    /**
     * 该动作是否走实拍素材（供调用方决定容器形态，如需额外圆角/描边时使用）。
     * 与 [gifAssetFor] 的分派规则严格一致：线稿命中即 false。
     */
    fun usesPhotoStyle(id: String, name: String): Boolean {
        if (id in GIF_FILE_NAMES) return false
        if (GIF_BY_NAME[name] != null || GIF_NAME_ALIASES[name] != null) return false
        return PhotoGifCatalog.BY_NAME[name] != null
    }

    /** [FtLibraryExercise] 重载。 */
    fun gifAssetFor(exercise: FtLibraryExercise): String? = gifAssetFor(exercise.id, exercise.name)

    // 原型口径的 `filter(part, muscle, …)`（展示名等值匹配）与 `groups(items)`
    // （按 `EQUIPMENT_ORDER` 顺序分组）已随 Wave 8「筛选改按 id」移除——屏内一律走
    // [filterSource]（id 匹配）与 `LibraryScreen.groupExercises`（按内容库器械首次出现序分组）。

    /** 空态标题资源（原型 L749）。 */
    @StringRes
    fun emptyTitleRes(favOnly: Boolean, query: String): Int = when {
        favOnly -> R.string.library_empty_fav_title
        query.isNotBlank() -> R.string.library_empty_query_title
        else -> R.string.library_empty_part_title
    }

    /** 空态提示资源（原型 L750）。 */
    @StringRes
    fun emptyHintRes(favOnly: Boolean, query: String): Int = when {
        favOnly -> R.string.library_empty_fav_hint
        query.isNotBlank() -> R.string.library_empty_query_hint
        else -> R.string.library_empty_part_hint
    }

    // ── 真实内容适配（ContentRepository → 屏内轻量模型） ────────────────────
    //
    // 真实内容（`assets/exercise-content.json`，50 动作）的肌群字段只有**一层**：
    // 6 个部位级肌群（胸部 / 背部 / 腿部 / 肩部 / 手臂 / 核心），每个动作 1 个主肌群
    // + 若干辅助肌群（`secondaryMuscleIds`）——没有原型样例里的细分肌群（胸大肌 / 背阔肌 …）。
    // Wave 8 起这一层肌群带稳定 id（`muscle_chest` 等），故筛选口径为：
    //   · 「部位」一级项 = 主肌群 **id**（[FtLibraryExercise.partId]，展示名走内容库）；
    //   · 「二级肌群」项 = 该部位下各动作**涉及的全部肌群 id**（主 + 辅）去重后剔除部位本身者
    //     （见 [muscleChipsFrom]）。
    // 历史缺陷（已修）：映射把 `muscle` 也填成主肌群名（`muscle == part`），而二级项又按
    // `it.muscle != part` 过滤——两处叠加使二级行恒剩「全部肌群」；现二级项改按 id 派生。

    /** 目标肌群串（[FtLibraryExercise.muscles]）的分隔符——原型 `EXERCISES[].muscles` 同用一个。 */
    const val MUSCLE_SEP: String = " · "

    /**
     * 难度 token → 文案资源（`beginner` / `intermediate` / `advanced`）；
     * 未知 token 返回 `null`，UI 层回落显示原文（同原型 `else → raw`）。
     */
    @StringRes
    fun difficultyLabelRes(raw: String): Int? = when (raw.lowercase()) {
        "beginner" -> R.string.library_level_beginner
        "intermediate" -> R.string.library_level_intermediate
        "advanced" -> R.string.library_level_advanced
        else -> null
    }

    /**
     * [ExerciseContent] → 屏内轻量模型。
     *
     * **id 域**（筛选 / 分组匹配键，与语言无关）：[FtLibraryExercise.partId] = 主肌群 id，
     * [FtLibraryExercise.equipmentId] = 首个器械 id，[FtLibraryExercise.muscleIds] = 主 + 辅肌群 id 去重。
     * **展示域**：[FtLibraryExercise.part] / [FtLibraryExercise.equipment] /
     * [FtLibraryExercise.muscles] 一律经 [ContentRepository] 按**当前语言**取名
     * （`nameZh` / `nameEn`）；[FtLibraryExercise.level] 保留语言无关 token，展示由
     * [difficultyLabelRes] 解析。
     */
    fun toLibraryExercise(exercise: ExerciseContent): FtLibraryExercise {
        val partId = exercise.primaryMuscleIds.firstOrNull().orEmpty()
        val equipmentId = exercise.equipmentIds.firstOrNull().orEmpty()
        val muscleIds = (exercise.primaryMuscleIds + exercise.secondaryMuscleIds).distinct()
        return FtLibraryExercise(
            id = exercise.exerciseId,
            name = exercise.nameZh,
            part = ContentRepository.getMuscleName(partId),
            muscle = ContentRepository.getMuscleName(partId),
            equipment = ContentRepository.getEquipmentName(equipmentId),
            level = exercise.difficulty,
            muscles = muscleIds.map { ContentRepository.getMuscleName(it) }
                .distinct()
                .joinToString(MUSCLE_SEP),
            tip = exercise.cues.firstOrNull() ?: exercise.steps.firstOrNull() ?: "",
            partId = partId,
            equipmentId = equipmentId,
            muscleIds = muscleIds,
        )
    }

    /** 目标肌群展示串 → 肌群名列表（真实内容里含主 + 辅肌群）。 */
    fun muscleNames(exercise: FtLibraryExercise): List<String> =
        exercise.muscles.split(MUSCLE_SEP).map { it.trim() }.filter { it.isNotEmpty() }

    /** 「肌群」命中判定（id 域）：命中部位（主肌群）id，或命中任一涉及肌群 id。 */
    fun matchesMuscle(exercise: FtLibraryExercise, muscleId: String): Boolean =
        muscleId == exercise.partId || muscleId in exercise.muscleIds

    /**
     * 二级肌群筛选条（id 域）——由该部位下动作的**涉及肌群 id**（主 + 辅）去重派生，
     * 剔除部位自身（与一级筛选重复）。首项恒为哨兵 [ALL_MUSCLES]。
     *
     * 部位为哨兵 [ALL_PARTS] 时返回空表（二级行不显示，原型 `buildMuscleRow` 同）。
     */
    fun muscleChipsFrom(partId: String, source: List<FtLibraryExercise>): List<String> {
        if (partId == ALL_PARTS) return emptyList()
        val ids = source.filter { it.partId == partId }
            .flatMap { it.muscleIds }
            .filter { it != partId }
            .distinct()
        return listOf(ALL_MUSCLES) + ids
    }

    /**
     * 过滤（作用于传入清单）——四项条件与原型 `render()`（L733-745）同构
     * （部位 / 肌群 / 只显示收藏 / 关键词），但前两项一律按 **id** 匹配
     * （[partId] / [muscleId] 对 [FtLibraryExercise.partId] / [FtLibraryExercise.muscleIds]），
     * 这样切语言后筛选态不失效。
     *
     * 关键词命中串取**展示名**（`name` / `part` / `equipment` / `muscles`）——即按当前语言搜索。
     */
    fun filterSource(
        source: List<FtLibraryExercise>,
        partId: String,
        muscleId: String,
        favOnly: Boolean,
        favorites: Set<String>,
        query: String,
    ): List<FtLibraryExercise> {
        val q = query.trim().lowercase()
        return source.filter { ex ->
            if (partId != ALL_PARTS && ex.partId != partId) return@filter false
            if (muscleId != ALL_MUSCLES && !matchesMuscle(ex, muscleId)) return@filter false
            if (favOnly && ex.id !in favorites) return@filter false
            if (q.isNotEmpty()) {
                val hay = "${ex.name} ${ex.part} ${ex.equipment} ${ex.muscles}".lowercase()
                if (!hay.contains(q)) return@filter false
            }
            true
        }
    }
}

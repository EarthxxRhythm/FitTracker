package com.fittracker.app.ui.screens.preferences

import androidx.annotation.StringRes
import com.fittracker.app.R
import com.fittracker.app.data.service.FtTrainingPreferences
import com.fittracker.app.data.service.PrefGoal
import com.fittracker.app.data.service.PrefLevel

/**
 * 一枚 chip（原型 `.chip`，`fittracker-training-preferences.html` L228-246）。
 *
 * @param id    落库标识——目标/经验用枚举名（`PrefGoal`/`PrefLevel` 的 `name`）、
 *              天数/时长用数字字面量、器械/限制肌群用内容 id；与 [FtTrainingPreferences]
 *              的字段口径逐项对应。
 * @param label 显示文案的资源 id（Wave 6 · 6b：文案迁入 `res/values/strings_preferences.xml`，
 *              中文值逐字取自原型标记）。
 */
data class FtPrefChip(val id: String, @StringRes val label: Int)

/**
 * 一组 chip（原型 `.pref-group`，L222-227 的样式 + L353 起的标记）：眉标 + 标题 + 可选说明 + 选项序 + 单选/多选。
 *
 * @param key   选中态的键（六组固定为 [FtTrainingPreferencesModel.KEY_GOAL] 等六个常量）
 * @param eyebrow 眉标资源 id（`.pref-eyebrow` L224）
 * @param title   组标题资源 id（`.pref-title` L225）
 * @param note  原型 `.pref-note`（L226）说明文案的资源 id；该组无说明时为 null（如「训练经验」L364-365）
 * @param multi 原型 `data-multi`（L410 / L421）为多选；缺省 `data-single`（L357/L366/L382/L392）为单选
 */
data class FtPrefGroup(
    val key: String,
    @StringRes val eyebrow: Int,
    @StringRes val title: Int,
    @StringRes val note: Int?,
    val options: List<FtPrefChip>,
    val multi: Boolean = false,
)

/** 一张 `.sub-card`（L212-217）：标题 + meta（「单选」/「多选」）+ 若干组（文案均为资源 id）。 */
data class FtPrefCard(
    @StringRes val title: Int,
    @StringRes val meta: Int,
    val groups: List<FtPrefGroup>,
)

/**
 * 训练偏好页的纯逻辑层——无 Compose 依赖，可单测。
 *
 * 规格源：`design/06_prototype_redraw/src/fittracker-training-preferences.html`
 * （frame `screen-training-preferences`）；文案逐字取自标记（括号内为**原型实读行号**），
 * Wave 6 · 6b 起以资源 id 承载（`res/values` 中文逐字 / `res/values-en` 英文）。
 * 数据模型（[FtTrainingPreferences] / [PrefGoal] / [PrefLevel]）来自 `data.service`。
 *
 * chip 的选中态在 UI 层统一存为 `Map<组 key, Set<chip id>>`（单选组恒为 0..1 元素集），
 * 由本对象提供「初始化 / 切换 / 落库」三条纯函数，UI 与测试共用。
 */
object FtTrainingPreferencesModel {

    // ── 顶栏 / 卡片 / 按钮 / 页脚文案（资源 id） ────────────────

    /** 标题「训练偏好」（标记 L341；样式 `.st-title` L200）。 */
    @StringRes
    val TITLE = R.string.preferences_title

    /** `.st-back` 的 `aria-label="返回个人页"`（L338）。 */
    @StringRes
    val BACK_A11Y = R.string.preferences_a11y_back

    /** 入口在个人页（原型 footer L448 明示）；直达无栈可退时的回退目标——**非文案**，故不进资源。 */
    const val BACK_ROUTE = "profile"

    /** `.sub-sec-meta`「单选」（L351 / L377）。 */
    @StringRes
    val META_SINGLE = R.string.preferences_meta_single

    /** `.sub-sec-meta`「多选」（L404）。 */
    @StringRes
    val META_MULTI = R.string.preferences_meta_multi

    /** `.sub-sec-title`（L219）——三张卡片标题（标记 L350 / L376 / L403）。 */
    @StringRes
    val CARD_GOAL_LEVEL = R.string.preferences_card_goal_level
    @StringRes
    val CARD_RHYTHM = R.string.preferences_card_rhythm
    @StringRes
    val CARD_EQUIPMENT = R.string.preferences_card_equipment

    /** `.save-btn`（样式 L249-263）标记 L433。 */
    @StringRes
    val SAVE_LABEL = R.string.preferences_save

    /** `.st-foot-note`（样式 L265）标记 L436——原型两行由 `<br/>` 分行，此处保持单句（逐字）。 */
    @StringRes
    val FOOT_NOTE = R.string.preferences_foot_note

    /** 保存成功 toast（原型脚本 L497「偏好已保存，已重新生成本周训练计划（原型）」去原型后缀，见计划 D-7）。 */
    @StringRes
    val TOAST_SAVED = R.string.preferences_toast_saved

    /** 保存失败 toast（生成 / 落库任一步异常）。 */
    @StringRes
    val TOAST_FAILED = R.string.preferences_toast_failed

    // ── 六组的选中态键 ──────────────────────────────────────────

    const val KEY_GOAL = "goal"
    const val KEY_LEVEL = "level"
    const val KEY_DAYS = "days"
    const val KEY_MINUTES = "minutes"
    const val KEY_EQUIPMENT = "equipment"
    const val KEY_MUSCLES = "muscles"

    // ── 器械 / 限制肌群 id（口径：`assets/exercise-content.json` 与 `PlanEngine.FOCUS_MUSCLE_IDS`） ──

    /**
     * 可用器械 = 原型四槽（标记 L411-414）。动作库内容另有 `eq_machine` / `eq_band` 两种，
     * 不在原型槽内，故不入选项。
     */
    val EQUIPMENT_CHOICES: List<String> =
        listOf("eq_bodyweight", "eq_dumbbell", "eq_barbell", "eq_cable")

    /** 限制肌群 = `PlanEngine` 六项焦点肌群的同六项（`PlanEngine.kt:61-68`）。 */
    val MUSCLE_CHOICES: List<String> = listOf(
        "muscle_chest", "muscle_back", "muscle_legs",
        "muscle_shoulders", "muscle_arms", "muscle_core",
    )

    // ── 六组（选项序逐字对齐原型标记） ───────────────────────────

    /** 组 1：训练目标（L353-361，默认「增肌」）。 */
    val GOAL_GROUP: FtPrefGroup = FtPrefGroup(
        key = KEY_GOAL,
        eyebrow = R.string.preferences_goal_eyebrow,   // L354
        title = R.string.preferences_goal_title,       // L355
        note = R.string.preferences_goal_note,         // L356
        options = listOf(
            FtPrefChip(PrefGoal.MUSCLE_GAIN.name, R.string.preferences_goal_muscle_gain),  // L358（默认选中）
            FtPrefChip(PrefGoal.STRENGTH.name, R.string.preferences_goal_strength),        // L359
            FtPrefChip(PrefGoal.FAT_LOSS.name, R.string.preferences_goal_fat_loss),        // L360
        ),
    )

    /** 组 2：训练经验（L363-370，默认「进阶」，无 `.pref-note`）。 */
    val LEVEL_GROUP: FtPrefGroup = FtPrefGroup(
        key = KEY_LEVEL,
        eyebrow = R.string.preferences_level_eyebrow,  // L364
        title = R.string.preferences_level_title,      // L365
        note = null,                                   // 原型该组无说明行
        options = listOf(
            FtPrefChip(PrefLevel.BEGINNER.name, R.string.preferences_level_beginner),        // L367
            FtPrefChip(PrefLevel.INTERMEDIATE.name, R.string.preferences_level_intermediate), // L368（默认选中）
            FtPrefChip(PrefLevel.ADVANCED.name, R.string.preferences_level_advanced),         // L369
        ),
    )

    /** 组 3：每周训练天数（L379-387，默认「4 天」）。 */
    val DAYS_GROUP: FtPrefGroup = FtPrefGroup(
        key = KEY_DAYS,
        eyebrow = R.string.preferences_days_eyebrow,   // L380
        title = R.string.preferences_days_title,       // L381
        note = null,
        options = listOf(
            FtPrefChip("2", R.string.preferences_days_2),  // L383
            FtPrefChip("3", R.string.preferences_days_3),  // L384
            FtPrefChip("4", R.string.preferences_days_4),  // L385（默认选中）
            FtPrefChip("5", R.string.preferences_days_5),  // L386
        ),
    )

    /** 组 4：单次训练时长（L389-397，默认「45 分钟」）。 */
    val MINUTES_GROUP: FtPrefGroup = FtPrefGroup(
        key = KEY_MINUTES,
        eyebrow = R.string.preferences_minutes_eyebrow, // L390
        title = R.string.preferences_minutes_title,     // L391
        note = null,
        options = listOf(
            FtPrefChip("30", R.string.preferences_minutes_30),  // L393
            FtPrefChip("45", R.string.preferences_minutes_45),  // L394（默认选中）
            FtPrefChip("60", R.string.preferences_minutes_60),  // L395
            FtPrefChip("75", R.string.preferences_minutes_75),  // L396
        ),
    )

    /** 组 5：可用器械（L406-415，多选，默认「自重 + 哑铃」）。 */
    val EQUIPMENT_GROUP: FtPrefGroup = FtPrefGroup(
        key = KEY_EQUIPMENT,
        eyebrow = R.string.preferences_equipment_eyebrow, // L407
        title = R.string.preferences_equipment_title,     // L408
        note = R.string.preferences_equipment_note,       // L409
        options = listOf(
            FtPrefChip("eq_bodyweight", R.string.preferences_equipment_bodyweight), // L411（默认选中）
            FtPrefChip("eq_dumbbell", R.string.preferences_equipment_dumbbell),     // L412（默认选中）
            FtPrefChip("eq_barbell", R.string.preferences_equipment_barbell),       // L413
            FtPrefChip("eq_cable", R.string.preferences_equipment_cable),           // L414
        ),
        multi = true,                                     // `data-multi`（L410）
    )

    /** 组 6：限制肌群（L417-428，多选，默认全不选）。 */
    val MUSCLES_GROUP: FtPrefGroup = FtPrefGroup(
        key = KEY_MUSCLES,
        eyebrow = R.string.preferences_muscles_eyebrow,   // L418
        title = R.string.preferences_muscles_title,       // L419
        note = R.string.preferences_muscles_note,         // L420
        options = listOf(
            FtPrefChip("muscle_chest", R.string.preferences_muscle_chest),          // L422
            FtPrefChip("muscle_back", R.string.preferences_muscle_back),            // L423
            FtPrefChip("muscle_legs", R.string.preferences_muscle_legs),            // L424
            FtPrefChip("muscle_shoulders", R.string.preferences_muscle_shoulders),  // L425
            FtPrefChip("muscle_arms", R.string.preferences_muscle_arms),            // L426
            FtPrefChip("muscle_core", R.string.preferences_muscle_core),            // L427
        ),
        multi = true,                                     // `data-multi`（L421）
    )

    /** 三张卡片的结构（UI 遍历渲染；卡片顺序 = 原型 L349 / L375 / L402）。 */
    val CARDS: List<FtPrefCard> = listOf(
        FtPrefCard(CARD_GOAL_LEVEL, META_SINGLE, listOf(GOAL_GROUP, LEVEL_GROUP)),
        FtPrefCard(CARD_RHYTHM, META_SINGLE, listOf(DAYS_GROUP, MINUTES_GROUP)),
        FtPrefCard(CARD_EQUIPMENT, META_MULTI, listOf(EQUIPMENT_GROUP, MUSCLES_GROUP)),
    )

    /** 六组全表（测试遍历用），顺序即原型出现序。 */
    val GROUPS: List<FtPrefGroup> = CARDS.flatMap { it.groups }

    // ── 纯逻辑：初始化 / 切换 / 落库 ─────────────────────────────

    /** 由落库模型得各组的初始选中集（单选组恒为 0..1 元素集）。 */
    fun initialSelection(prefs: FtTrainingPreferences): Map<String, Set<String>> = mapOf(
        KEY_GOAL to setOf(prefs.goal.name),
        KEY_LEVEL to setOf(prefs.level.name),
        KEY_DAYS to setOf(prefs.daysPerWeek.toString()),
        KEY_MINUTES to setOf(prefs.sessionMinutes.toString()),
        KEY_EQUIPMENT to prefs.equipmentIds,
        KEY_MUSCLES to prefs.restrictedMuscleIds,
    )

    /**
     * 点击一枚 chip 后的新选中集。
     *
     * 多选组（`data-multi`）为开关切换；单选组（`data-single`）替换为新 id——
     * 原型脚本（L475-483）对已选中项再点仍是选中（先 `remove` 后 `add`），**无取消语义**。
     */
    fun toggleSelection(group: FtPrefGroup, current: Set<String>, chipId: String): Set<String> =
        if (group.multi) {
            if (chipId in current) current - chipId else current + chipId
        } else {
            setOf(chipId)
        }

    /** 由选中态构造落库模型；缺组 / 非法值一律回落到 [FtTrainingPreferences] 的默认值（宽容解析）。 */
    fun toPreferences(selection: Map<String, Set<String>>): FtTrainingPreferences {
        val fallback = FtTrainingPreferences()
        return FtTrainingPreferences(
            goal = goalOf(selection[KEY_GOAL]?.firstOrNull(), fallback.goal),
            level = levelOf(selection[KEY_LEVEL]?.firstOrNull(), fallback.level),
            daysPerWeek = selection[KEY_DAYS]?.firstOrNull()?.toIntOrNull() ?: fallback.daysPerWeek,
            sessionMinutes = selection[KEY_MINUTES]?.firstOrNull()?.toIntOrNull() ?: fallback.sessionMinutes,
            equipmentIds = selection[KEY_EQUIPMENT] ?: fallback.equipmentIds,
            restrictedMuscleIds = selection[KEY_MUSCLES] ?: fallback.restrictedMuscleIds,
        )
    }

    /** chip id（= 枚举名）→ [PrefGoal]；未命中回落到 [fallback]。 */
    fun goalOf(id: String?, fallback: PrefGoal = FtTrainingPreferences().goal): PrefGoal =
        PrefGoal.values().firstOrNull { it.name == id } ?: fallback

    /** chip id（= 枚举名）→ [PrefLevel]；未命中回落到 [fallback]。 */
    fun levelOf(id: String?, fallback: PrefLevel = FtTrainingPreferences().level): PrefLevel =
        PrefLevel.values().firstOrNull { it.name == id } ?: fallback
}

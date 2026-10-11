package com.fittracker.app.ui.screens.settings

import androidx.annotation.StringRes
import com.fittracker.app.R
import com.fittracker.app.data.service.FtSettings
import com.fittracker.app.data.service.SettingsLanguage
import com.fittracker.app.data.service.WeekStart
import com.fittracker.app.data.service.WeightUnit

/**
 * 分段控件的一个选项（原型 `.seg button`，L390-405）。
 *
 * [labelRes] 为字符串资源 ID（`values/strings_settings.xml`）——文案不落模型层，
 * 由 UI 层 `stringResource` 解析（模型保持无 Compose 依赖，见 [FtSettingsModel] 类注释）。
 */
data class FtSegOption(@StringRes val labelRes: Int, val active: Boolean)

/**
 * 设置行右侧控件的形态——对应原型 `.set-row` 的三种 markup。
 *
 * 分段与开关的 `aria-label` 在原型里**与行标题逐字相同**（如 `aria-label="体重单位"` 对
 * `.sr-label`「体重单位」），故不单独存放：开关的 `aria-label` 由行标题资源复用（见
 * `SwitchControl` 的 `contentDescription`），分段组同义。`data-seg` 的值（`weight-unit` /
 * `language` / `week-start`）落为行的 [FtSettingRow.key]。
 */
sealed interface FtSettingTrailing {

    /** 分段控件 `.seg`（L242-266）。 */
    data class Segment(val options: List<FtSegOption>) : FtSettingTrailing

    /** 开关 `.switch`（L268-293）。[on] 取自 `class="on"` / `aria-checked`。 */
    data class Switch(val on: Boolean) : FtSettingTrailing

    /** 纯文本值 `.sr-value`（L237）。值多为**运行期数据**（如版本号），故为已解析字符串。 */
    data class Value(val text: String) : FtSettingTrailing

    /** 值 + 右箭头：`.sr-right`（L240）= `.sr-value`（L237）+ `.sr-chev`（L238）。值为静态文案，走资源。 */
    data class ValueLink(@StringRes val textRes: Int) : FtSettingTrailing

    /** 仅右箭头 `.sr-chev`（L238）。 */
    data object Link : FtSettingTrailing
}

/**
 * 一行设置（原型 `.set-row`，L224-235）。
 *
 * [labelRes] 是行标题的字符串资源 ID；原型里开关的 `aria-label`、项内文案均与行标题同源。
 *
 * [key] 是交互派发用的**稳定标识**（对应原型分段 `data-seg`、开关 `aria-label`、
 * 行 `data-action` 的语义位）。可点击行必须有 [key]；静态行（如「版本」）留 `null`。
 *
 * [action] 对应原型的 `data-action`（`health` L430 · `privacy` L458）——`<button class="set-row">`
 * 与纯 `<div class="set-row">` 的**视觉无差别**，此字段区分该行是否可点击并指示其动作。
 */
data class FtSettingRow(
    @StringRes val labelRes: Int,
    val trailing: FtSettingTrailing,
    val action: String? = null,
    val key: String? = null,
)

/**
 * 一组设置（原型 `.sub-card`，L213-221）。
 *
 * [metaRes] 是右上角 `.sub-sec-meta`，三段里只有「关于」带它（L451）。
 */
data class FtSettingsSection(
    @StringRes val titleRes: Int,
    @StringRes val metaRes: Int? = null,
    val rows: List<FtSettingRow>,
)

/**
 * 设置屏的纯逻辑层——无 Compose 依赖，可单测。
 *
 * 规格源：原型 `settings.html`（文案 L374/377/465 · 通用 7 行 L387-423 ·
 * 数据与隐私 3 行 L428-444 · 关于 2 行 L448-462 · 脚本 L480-557）。
 *
 * **文案外置**（Wave 6 i18n）：所有用户可见文案改为字符串资源 ID（`values/strings_settings.xml`
 * 的中文值为逐字真源），本对象只持有 `@StringRes Int` / 派发键 / 纯逻辑函数，
 * 由 UI 层 `stringResource` 或 `context.getString` 解析——本文件不出现文案字面量。
 *
 * [SECTIONS] 是**原型静止态**（未接线时 1:1）；接线后由 [sections] 按当前
 * [WeightUnit] / [FtSettings] 重算分段 active 与开关 on。
 */
object FtSettingsModel {

    /** `.st-back` 的 `aria-label`（L374），中文值逐字取自源码。 */
    @StringRes
    val BACK_A11Y_RES = R.string.settings_a11y_back

    /** `.st-title`（L377）。 */
    @StringRes
    val TITLE_RES = R.string.settings_title

    /** `.st-foot-note`（L465）。 */
    @StringRes
    val FOOT_NOTE_RES = R.string.settings_foot_note

    /** 返回目标——`FT_APP.routes` 的 `['[data-action="back"]','profile']`（L560）。非文案，不资源化。 */
    const val BACK_ROUTE = "profile"

    // --- 交互派发键（对应原型分段 data-seg / 行 data-action） -------------------

    /** 分段 `data-seg="weight-unit"`（L389）。落盘走 `UserProfileService`（资料域）。 */
    const val KEY_WEIGHT_UNIT = "weight-unit"

    /** 分段 `data-seg="language"`（L396）。 */
    const val KEY_LANGUAGE = "language"

    /** 分段 `data-seg="week-start"`（L403）。 */
    const val KEY_WEEK_START = "week-start"

    /** 开关 `aria-label="训练提醒"`（L410）。 */
    const val KEY_WORKOUT_REMINDER = "workout-reminder"

    /** 开关 `aria-label="成就提醒"`（L414）。 */
    const val KEY_ACHIEVEMENT_REMINDER = "achievement-reminder"

    /** 开关 `aria-label="声音与震动"`（L418）。 */
    const val KEY_SOUND_VIBRATION = "sound-vibration"

    /** 开关 `aria-label="训练中屏幕常亮"`（L422）。 */
    const val KEY_KEEP_SCREEN_ON = "keep-screen-on"

    /** 开关 `aria-label="训练数据同步"`（L439）——联动 `SyncOrchestrator.autoEnabled`。 */
    const val KEY_DATA_SYNC = "data-sync"

    /** 开关 `aria-label="匿名使用数据"`（L443）。 */
    const val KEY_ANONYMOUS_DATA = "anonymous-data"

    /** 行 `data-action="health"`（L430）。 */
    const val ACTION_HEALTH = "health"

    /** 行 `data-action="privacy"`（L458）。隐私说明行点击改为**导航** `legal?kind=privacy`（对齐鸿蒙），不再 toast。 */
    const val ACTION_PRIVACY = "privacy"

    /** 「版本」行的稳定键——值由 [sections] 以 `BuildConfig.VERSION_NAME` 注入。 */
    const val KEY_VERSION = "version"

    // --- toast 文案（功能真实化后：去「（原型）」后缀，主句保留） -------------

    /**
     * 分段点击（原型 L507 主句，去演示后缀）：`%1$s已切换为「%2$s」`。
     *
     * 含参文案由 UI 层解析（`context.getString(TOAST_SEGMENT_RES, 行标题, 选项)`）——
     * 模型层不持有 `Context`，保持可单测。
     */
    @StringRes
    val TOAST_SEGMENT_RES = R.string.settings_toast_segment

    /** 开关点击（原型 L519 主句）：开启 `%1$s已开启` / 关闭 `%1$s已关闭`。 */
    @StringRes
    fun switchToastRes(on: Boolean): Int =
        if (on) R.string.settings_toast_switch_on else R.string.settings_toast_switch_off

    /** 「健康数据授权」行点击——Android 无对等数据源，如实说明（见计划非目标）。 */
    @StringRes
    val TOAST_HEALTH_RES = R.string.settings_toast_health

    /**
     * 未登录时开启「训练数据同步」的提示——中文值逐字对齐鸿蒙
     * `SettingsContent.ets` `toggleSyncRow`（「请先登录后再开启同步」）。
     */
    @StringRes
    val TOAST_SYNC_NEED_LOGIN_RES = R.string.settings_toast_sync_need_login

    /**
     * 「训练数据同步」开关的可切换性：**开启需已登录**；关闭不受限。
     * 决策逻辑纯函数化（UI 接线见 SettingsScreen.onToggle），对齐鸿蒙 UI 层校验位置。
     */
    fun canToggleDataSync(enable: Boolean, loggedIn: Boolean): Boolean = !enable || loggedIn

    /** 三段 `.sub-card`（L384-463）——**原型静止态**（未接线时的 1:1 基线）。 */
    val SECTIONS: List<FtSettingsSection> = listOf(
        FtSettingsSection(
            titleRes = R.string.settings_section_general, // `.sub-sec-title`（L385）
            rows = listOf(
                // `.sr-label` L388 + `.seg` L389-392（`千克` active L390 / `磅` L391）
                FtSettingRow(
                    labelRes = R.string.settings_row_weight_unit,
                    trailing = FtSettingTrailing.Segment(
                        listOf(
                            FtSegOption(R.string.settings_option_kg, true),
                            FtSegOption(R.string.settings_option_lbs, false),
                        ),
                    ),
                    key = KEY_WEIGHT_UNIT,
                ),
                // `.sr-label` L395 + `.seg` L396-399（`简体中文` active L397 / `English` L398）
                FtSettingRow(
                    labelRes = R.string.settings_row_language,
                    trailing = FtSettingTrailing.Segment(
                        listOf(
                            FtSegOption(R.string.settings_option_zh, true),
                            FtSegOption(R.string.settings_option_en, false),
                        ),
                    ),
                    key = KEY_LANGUAGE,
                ),
                // `.sr-label` L402 + `.seg` L403-406（`周一` active L404 / `周日` L405）
                FtSettingRow(
                    labelRes = R.string.settings_row_week_start,
                    trailing = FtSettingTrailing.Segment(
                        listOf(
                            FtSegOption(R.string.settings_option_monday, true),
                            FtSegOption(R.string.settings_option_sunday, false),
                        ),
                    ),
                    key = KEY_WEEK_START,
                ),
                FtSettingRow( // L409-410
                    R.string.settings_row_workout_reminder,
                    FtSettingTrailing.Switch(on = true),
                    key = KEY_WORKOUT_REMINDER,
                ),
                FtSettingRow( // L413-414
                    R.string.settings_row_achievement_reminder,
                    FtSettingTrailing.Switch(on = false),
                    key = KEY_ACHIEVEMENT_REMINDER,
                ),
                FtSettingRow( // L417-418
                    R.string.settings_row_sound_vibration,
                    FtSettingTrailing.Switch(on = true),
                    key = KEY_SOUND_VIBRATION,
                ),
                FtSettingRow( // L421-422
                    R.string.settings_row_keep_screen_on,
                    FtSettingTrailing.Switch(on = true),
                    key = KEY_KEEP_SCREEN_ON,
                ),
            ),
        ),
        FtSettingsSection(
            titleRes = R.string.settings_section_data_privacy, // `.sub-sec-title`（L428）
            rows = listOf(
                // `<button class="set-row" data-action="health">` L430-435：`.sr-value`=`已授权`（L433）+ `.sr-chev`（L434）
                FtSettingRow(
                    labelRes = R.string.settings_row_health_auth,
                    trailing = FtSettingTrailing.ValueLink(R.string.settings_row_value_authorized),
                    action = ACTION_HEALTH,
                ),
                FtSettingRow( // L438-439
                    R.string.settings_row_data_sync,
                    FtSettingTrailing.Switch(on = true),
                    key = KEY_DATA_SYNC,
                ),
                FtSettingRow( // L442-443
                    R.string.settings_row_anonymous_data,
                    FtSettingTrailing.Switch(on = false),
                    key = KEY_ANONYMOUS_DATA,
                ),
            ),
        ),
        FtSettingsSection(
            titleRes = R.string.settings_section_about, // `.sub-sec-title`（L450）
            metaRes = R.string.settings_section_about_meta, // `.sub-sec-meta`（L451）
            rows = listOf(
                // `.sr-label` L455；值由 [sections] 注入（运行期版本号，故为已解析字符串）
                FtSettingRow(R.string.settings_row_version, FtSettingTrailing.Value(""), key = KEY_VERSION),
                // `<button class="set-row" data-action="privacy">` L458-461：只带 `.sr-chev`（L460）
                FtSettingRow(
                    labelRes = R.string.settings_row_privacy,
                    trailing = FtSettingTrailing.Link,
                    action = ACTION_PRIVACY,
                ),
            ),
        ),
    )

    /**
     * 按当前状态重算各分组：分段 active（体重单位 / 语言 / 周开始日）与 6 个开关的 on，
     * 并将 [versionName] 注入「版本」行（[KEY_VERSION]）。
     *
     * 静止态基线仍是 [SECTIONS]，仅对**带 [FtSettingRow.key] 的交互行**与版本行改写 trailing——
     * 「健康数据授权」值行原样保留（其行为说明见 [TOAST_HEALTH_RES]）。
     */
    fun sections(
        weightUnit: WeightUnit,
        settings: FtSettings,
        versionName: String,
    ): List<FtSettingsSection> =
        SECTIONS.map { section ->
            section.copy(rows = section.rows.map { row -> row.withState(weightUnit, settings, versionName) })
        }

    private fun FtSettingRow.withState(
        weightUnit: WeightUnit,
        settings: FtSettings,
        versionName: String,
    ): FtSettingRow =
        when (val trailing = trailing) {
            is FtSettingTrailing.Segment -> {
                val activeIndex = segmentActiveIndex(weightUnit, settings) ?: return this
                copy(
                    trailing = FtSettingTrailing.Segment(
                        trailing.options.mapIndexed { index, option -> option.copy(active = index == activeIndex) },
                    ),
                )
            }

            is FtSettingTrailing.Switch -> {
                val on = switchState(settings) ?: return this
                copy(trailing = FtSettingTrailing.Switch(on))
            }

            is FtSettingTrailing.Value ->
                if (key == KEY_VERSION) copy(trailing = FtSettingTrailing.Value(versionName)) else this

            else -> this
        }

    /** 分段行当前 active 的下标：体重单位 0=千克 / 1=磅；语言 0=简体中文 / 1=English；周开始日 0=周一 / 1=周日。 */
    private fun FtSettingRow.segmentActiveIndex(weightUnit: WeightUnit, settings: FtSettings): Int? =
        when (key) {
            KEY_WEIGHT_UNIT -> if (weightUnit == WeightUnit.KG) 0 else 1
            KEY_LANGUAGE -> if (settings.language == SettingsLanguage.ZH) 0 else 1
            KEY_WEEK_START -> if (settings.weekStart == WeekStart.MONDAY) 0 else 1
            else -> null
        }

    /** 开关行当前值；非开关行返回 `null`（表示保持静止态）。 */
    private fun FtSettingRow.switchState(settings: FtSettings): Boolean? =
        when (key) {
            KEY_WORKOUT_REMINDER -> settings.workoutReminder
            KEY_ACHIEVEMENT_REMINDER -> settings.achievementReminder
            KEY_SOUND_VIBRATION -> settings.soundVibration
            KEY_KEEP_SCREEN_ON -> settings.keepScreenOn
            KEY_DATA_SYNC -> settings.dataSync
            KEY_ANONYMOUS_DATA -> settings.anonymousData
            else -> null
        }
}

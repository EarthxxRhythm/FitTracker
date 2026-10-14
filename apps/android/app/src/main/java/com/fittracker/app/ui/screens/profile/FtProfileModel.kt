package com.fittracker.app.ui.screens.profile

import androidx.annotation.StringRes
import com.fittracker.app.R

/**
 * 图标种类——首三枚与末枚逐枚对应原型本文件 `<symbol>`（L1255-1305）。
 *
 * 之所以带进数据层：成就行与快捷入口各用两枚不同图标，语义（火苗/奖杯/天平/网格）
 * 属于「这条数据长什么样」，不属于「怎么画」，故由模型声明、屏内映射到 Canvas 绘制。
 *
 * [SLIDERS]（调节滑块）为**设计侧新增**——原型 `fittracker-personal.html` 无此 symbol，
 * 来源是训练偏好原型 footer（`fittracker-training-preferences.html:448`）明示的
 * 「个人页『训练偏好』快捷入口」；绘制规格见 `ProfileScreen.SlidersIcon`。
 */
enum class FtProfileIcon { FLAME, TROPHY, SCALE, LIBRARY, SLIDERS }

/**
 * 连续记录里的一天（原型 `.streak-day` / `.streak-day.active`，L1411-1417）。
 *
 * [labelRes] 为日标签的字符串资源 ID（`values/strings_profile.xml`）——文案不落模型层，
 * 由 UI 层 `stringResource` 解析；运行期真实标签由 `WeekWindow.dayLabels` 给定（见 `ProfileScreen`）。
 */
data class FtProfileStreakDay(@StringRes val labelRes: Int, val active: Boolean)

/**
 * 本周概览里的一格小指标（原型 `.focus-meta`，L1392-1401）。
 *
 * [labelRes] / [unitRes] 为资源 ID；[value] 是**运行期数值文本**（由会话仓储统计注入，
 * 无数据时保持原型样例），故为已解析字符串。
 */
data class FtProfileMetric(@StringRes val labelRes: Int, val value: String, @StringRes val unitRes: Int)

/**
 * 一条最近成就（原型 `.achievement` / `.achievement.gold`，L1423-1438）；文案为静态资源。
 *
 * [weightKgParam] 非空时，`noteRes` 以该值（kg 基准）按「设置 · 体重单位」换算后作 `%1$s` 注入
 * （「重量突破」条）；为空时 `noteRes` 为无参文案。
 */
data class FtProfileAchievement(
    val icon: FtProfileIcon,
    @StringRes val titleRes: Int,
    @StringRes val noteRes: Int,
    @StringRes val valueRes: Int,
    /** 金色变体：`.achievement.gold`（L1431）走 `--gold-12` 底 / `--gold` 字（L417-421）。 */
    val gold: Boolean,
    /** 卡片文案里的样例重量（kg 基准），需按单位换算注入 `noteRes` 的 `%1$s`。 */
    val weightKgParam: Int? = null,
)

/** 一个快捷入口（原型 `.shortcut`，L1442-1451）。 */
data class FtProfileShortcut(
    val icon: FtProfileIcon,
    @StringRes val labelRes: Int,
    /** 目标路由 id，取自原型脚本 `bindOpen`（L1767-1768）。非文案，不资源化。 */
    val route: String,
)

/**
 * 个人页（我的）的纯逻辑层——无 Compose 依赖，可单测。
 *
 * 规格源：原型 `design/06_prototype_redraw/src/fittracker-personal.html`
 * 的 `screen-personal` 帧内 `pane-profile`（L1366-1455）。
 * 每条常量后的括号是原型行号。
 *
 * **文案外置**（Wave 8 i18n）：所有用户可见文案改为字符串资源 ID（`values/strings_profile.xml`
 * 的中文值为逐字真源），本对象只持有 `@StringRes Int` / 路由 id / 数值样例，
 * 由 UI 层 `stringResource` 解析——本文件不出现文案字面量。
 *
 * 空数据降级样例（原型静态基线）键名以 `_sample` 结尾；周范围日期文本与日标签
 * （`WeekWindow.weekRangeText` / `dayLabels`）属 WeekWindow 域，本域不重复资源化。
 */
object FtProfileModel {

    // ── 头部（L1369-1378） ────────────────────────────────────────

    /** `.avatar` 的文字头像（L1370）——空资料时的降级样例。 */
    @StringRes
    val SAMPLE_AVATAR_INITIAL_RES = R.string.profile_sample_avatar_initial

    /** `.p-name`（L1372）——未接 `UserProfileService` 时的降级样例。 */
    @StringRes
    val SAMPLE_NAME_RES = R.string.profile_sample_name

    /** `.p-sub`（L1373）——同上。 */
    @StringRes
    val SAMPLE_SUB_RES = R.string.profile_sample_sub

    /** `.p-settings` 的 `aria-label="设置"`（L1375），中文值逐字取自源码。 */
    @StringRes
    val SETTINGS_A11Y_RES = R.string.profile_a11y_settings

    /** 设置按钮的目标路由，取自原型脚本 `bindOpen('[data-od-id="btn-settings"]', 'settings')`（L1769）。 */
    const val SETTINGS_ROUTE = "settings"

    // ── 本周概览（L1380-1403） ────────────────────────────────────

    /** `.card-title`（L1382）。 */
    @StringRes
    val WEEK_TITLE_RES = R.string.profile_week_title

    /**
     * `.card-meta`（L1383）——**首帧占位**（原型样例），加载后由 `WeekWindow.weekRangeText`
     * 按真实周范围替换；格式注意 en dash「–」。
     */
    @StringRes
    val WEEK_META_SAMPLE_RES = R.string.profile_week_meta_sample

    /** `.focus-hero-value`（L1386）——数值样例（运行期由会话仓储注入），非文案。 */
    const val WEEK_VALUE = "186"

    /** `.focus-hero-unit`（L1387）。 */
    @StringRes
    val WEEK_UNIT_RES = R.string.profile_week_unit

    /** `.focus-hero-label`（L1389）。 */
    @StringRes
    val WEEK_LABEL_RES = R.string.profile_week_label

    /** `.focus-meta-row` 的两格（L1392-1401）；数值为运行期注入的样例。 */
    val WEEK_METRICS: List<FtProfileMetric> = listOf(
        FtProfileMetric( // L1393-1395
            labelRes = R.string.profile_week_metric_workouts,
            value = "4",
            unitRes = R.string.profile_unit_times,
        ),
        FtProfileMetric( // L1398-1400
            labelRes = R.string.profile_week_metric_burned,
            value = "1,240",
            unitRes = R.string.profile_unit_kcal,
        ),
    )

    // ── 训练连续记录（L1405-1419） ───────────────────────────────

    /** `.card-title`（L1407）。 */
    @StringRes
    val STREAK_TITLE_RES = R.string.profile_streak_title

    /** `.streak-count`（L1408）。 */
    @StringRes
    val STREAK_COUNT_RES = R.string.profile_streak_count

    /**
     * 周一至周六 `.active`、周日未激活（L1411-1417）——**原型序（周一起始）基线**；
     * 进屏后标签与激活态由 `WeekWindow.dayLabels` 与本周训练日重排（见 `ProfileScreen`）。
     */
    val STREAK_DAYS: List<FtProfileStreakDay> = listOf(
        FtProfileStreakDay(R.string.profile_streak_day_mon, true),
        FtProfileStreakDay(R.string.profile_streak_day_tue, true),
        FtProfileStreakDay(R.string.profile_streak_day_wed, true),
        FtProfileStreakDay(R.string.profile_streak_day_thu, true),
        FtProfileStreakDay(R.string.profile_streak_day_fri, true),
        FtProfileStreakDay(R.string.profile_streak_day_sat, true),
        FtProfileStreakDay(R.string.profile_streak_day_sun, false),
    )

    // ── 最近成就（L1421-1439） ────────────────────────────────────

    /** `.achievements-title`（L1422）。 */
    @StringRes
    val ACHIEVEMENTS_TITLE_RES = R.string.profile_achievements_title

    /** 第一条用 `#i-flame`（L1424）、第二条 `.gold` 用 `#i-trophy`（L1432）。 */
    val ACHIEVEMENTS: List<FtProfileAchievement> = listOf(
        FtProfileAchievement(
            icon = FtProfileIcon.FLAME,
            titleRes = R.string.profile_achievement_streak_title, // L1426
            noteRes = R.string.profile_achievement_streak_note,   // L1427
            valueRes = R.string.profile_achievement_streak_value, // L1429
            gold = false,
        ),
        FtProfileAchievement(
            icon = FtProfileIcon.TROPHY,
            titleRes = R.string.profile_achievement_pr_title, // L1434
            noteRes = R.string.profile_achievement_pr_note,   // L1435
            valueRes = R.string.profile_achievement_pr_value, // L1437
            gold = true,
            weightKgParam = 80, // 原型样例「深蹲达到 80 kg」——按单位换算后注入
        ),
    )

    // ── 快捷入口（L1441-1452） ────────────────────────────────────

    /**
     * 身体数据 → `body`、训练偏好 → `trainingPreferences`、动作库 → `library`
     * （首末两项原型脚本 L1767-1768；中间项为设计侧新增，出处见 [FtProfileIcon.SLIDERS]）。
     */
    val SHORTCUTS: List<FtProfileShortcut> = listOf(
        FtProfileShortcut(FtProfileIcon.SCALE, R.string.profile_shortcut_body, "body"),                   // L1444
        FtProfileShortcut(                                                                                // 设计侧新增（中间位）
            FtProfileIcon.SLIDERS,
            R.string.profile_shortcut_training_preferences,
            "trainingPreferences",
        ),
        FtProfileShortcut(FtProfileIcon.LIBRARY, R.string.profile_shortcut_library, "library"),           // L1449
    )
}

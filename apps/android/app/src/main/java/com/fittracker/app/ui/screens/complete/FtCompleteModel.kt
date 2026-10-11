package com.fittracker.app.ui.screens.complete

import androidx.annotation.StringRes
import com.fittracker.app.R
import kotlin.math.roundToInt

/** 连续记录里的一天（原型 `.streak-day.on/off`，L418-425）。 */
data class FtStreakDay(val label: String, val active: Boolean)

/** 一片飘落彩带的参数（原型为每片写的 inline 变量，L459-472）。 */
data class FtConfettiPiece(
    /** `left`（视口宽度的百分比，原型写 `%`）。 */
    val leftPercent: Float,
    /** `width`（px）。 */
    val width: Float,
    /** `height`（px）。 */
    val height: Float,
    /** `--dur`（秒）。 */
    val durationSeconds: Float,
    /** `--delay`（秒）。 */
    val delaySeconds: Float,
    /** `--rot`：终态旋转角（度，整数）。 */
    val rotationDeg: Int,
    /** 配色下标（0–4）。 */
    val colorIndex: Int,
)

/**
 * 训练完成屏的纯逻辑层——无 Compose 依赖，可单测。
 *
 * 规格源：原型 `design/06_prototype_redraw/src/fittracker-training-complete.html`
 * （文案 L412/L413/L419/L420/L436 · 连续记录 L418-425 · confetti L459-472）。
 */
object FtCompleteModel {

    /**
     * 文案外置（Wave 7 i18n）：本对象只持有字符串资源 ID（`values/strings_complete.xml`
     * 的中文值为逐字真源），由 UI 层 `stringResource` 解析——本文件不出现文案字面量。
     */

    /** `.cf-title`（L412）。 */
    @StringRes
    val TITLE_RES = R.string.complete_title

    /** `.cf-sub`（L413）。 */
    @StringRes
    val SUBTITLE_RES = R.string.complete_subtitle

    /** `.streak-title`（L419）。 */
    @StringRes
    val STREAK_TITLE_RES = R.string.complete_streak_title

    /** `.streak-count`（L420）——`%1$d` 为连续天数（屏内 `streakCount` 插值）。 */
    @StringRes
    val STREAK_COUNT_RES = R.string.complete_streak_count

    /** `.cf-btn-primary`（L436）。 */
    @StringRes
    val CONTINUE_LABEL_RES = R.string.complete_continue

    /** `.streak-days` 的 `role="img"` aria-label（L417），逐字取自源码。 */
    @StringRes
    val STREAK_A11Y_RES = R.string.complete_a11y_streak

    /** 周一至周六打卡、周日未打卡（L418-425）。 */
    val STREAK_DAYS: List<FtStreakDay> = listOf(
        FtStreakDay("一", true),
        FtStreakDay("二", true),
        FtStreakDay("三", true),
        FtStreakDay("四", true),
        FtStreakDay("五", true),
        FtStreakDay("六", true),
        FtStreakDay("日", false),
    )

    /** `for (var i = 0; i < 38; i++)`（L460）。 */
    const val CONFETTI_COUNT = 38

    /**
     * `confetti` 的生成（L459-472）。
     *
     * 每片按序消耗 6 个 `[0,1)` 随机数：left / width / height / dur / delay / rot——
     * [rnd] 由调用方注入（屏内传 `Random.nextFloat()`，测试传定值以断言参数）。
     *
     * 公式逐字对齐原型：
     * `left = rnd·100%`；`width = 6 + rnd·6`；`height = 10 + rnd·8`；
     * `dur = 2.2 + rnd·1.6`；`delay = rnd·0.45`；`rot = round(rnd·720 − 360)`；
     * `colorIndex = i % 5`。
     */
    fun confetti(count: Int = CONFETTI_COUNT, rnd: () -> Float): List<FtConfettiPiece> =
        List(count) { i ->
            FtConfettiPiece(
                leftPercent = rnd() * 100f,
                width = 6f + rnd() * 6f,
                height = 10f + rnd() * 8f,
                durationSeconds = 2.2f + rnd() * 1.6f,
                delaySeconds = rnd() * 0.45f,
                rotationDeg = (rnd() * 720f - 360f).roundToInt(),
                colorIndex = i % 5,
            )
        }
}

package com.fittracker.app.ui.theme

import androidx.compose.animation.core.CubicBezierEasing
import androidx.compose.animation.core.Easing

/**
 * 动效令牌。
 *
 * 时长与曲线取自 `design/06_prototype_redraw/TOKENS.md` §4.2（由原型 CSS 解析得出），
 * 曲线字面值来自各屏 `@keyframes` / `transition` 声明。
 * 屏内禁止散落魔法时长，一律引用本表。
 */
object FtMotion {

    // ── 时长（毫秒） ──────────────────────────────────────────
    const val DURATION_PRESS = 120          // .12s 按压
    const val DURATION_COLOR_FAST = 160     // .16s 色/边框
    const val DURATION_COLOR_BASE = 180     // .18s 色
    const val DURATION_OVERLAY = 220        // .22s backdrop / modal / veil
    const val DURATION_PANEL = 280          // .28s ~ .3s sheet
    const val DURATION_RECORD = 180         // recordIn .18s
    const val DURATION_MARKER = 300         // markerPop .3s
    const val DURATION_PROGRESS = 350       // .goal-fill width .35s（TOKENS §5 建议补入）
    const val DURATION_CORE = 460           // coreIn .46s
    const val DURATION_SEG_POP = 460        // segPop .46s
    const val DURATION_CF_POP = 500         // cf-pop .5s
    const val DURATION_CF_RISE_FAST = 450   // cf-rise .45s
    const val DURATION_CF_RISE_BASE = 500   // cf-rise .5s
    const val DURATION_CONFETTI_FLY = 1100  // confettiFly 1.1s
    const val DURATION_CONFETTI_FALL = 2600 // cf-fall 2.6s
    const val DURATION_PULSE = 1600         // livePulse 1.6s

    // ── 曲线 ──────────────────────────────────────────────────
    /** 原型全局 `--ease`：cubic-bezier(.2, .7, .2, 1) */
    val EASE_MOTION: Easing = CubicBezierEasing(0.2f, 0.7f, 0.2f, 1f)

    /** 面板 / sheet：cubic-bezier(.32, .72, .3, 1) */
    val EASE_PANEL: Easing = CubicBezierEasing(0.32f, 0.72f, 0.3f, 1f)

    /** 彩带飞散：cubic-bezier(.16, .7, .3, 1) */
    val EASE_FLY: Easing = CubicBezierEasing(0.16f, 0.7f, 0.3f, 1f)

    /** 彩带下落：cubic-bezier(.2, .55, .35, 1) */
    val EASE_FALL: Easing = CubicBezierEasing(0.2f, 0.55f, 0.35f, 1f)

    // ── 按压缩放系数（原型多处 `.985` / `.96` / `.98` / `.94`） ──
    const val PRESS_SCALE_CTA = 0.985f
    const val PRESS_SCALE_CARD = 0.98f
    const val PRESS_SCALE_TAB_CENTER = 0.96f
    const val PRESS_SCALE_ICON_BTN = 0.94f
}

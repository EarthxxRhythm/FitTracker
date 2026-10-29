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
    const val DURATION_MODAL = 200          // .2s 全模态面板进场（训练预览覆盖层，对齐鸿蒙 PencilAppShell）
    const val DURATION_PANEL = 280          // .28s ~ .3s sheet
    const val DURATION_CHROME = 220         // 头部/底栏收起（沿用 OVERLAY 语汇，单列便于调参）
    const val DURATION_SEG_SLIDE = 220      // 分段控件选中块滑动（与鸿蒙 DURATION_SEG_SLIDE 同值）
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

    // ── 字段校验失败的「左右抖动」（原型 CSS `@keyframes shake` 的等价物） ──
    //
    // 数值与 Harmony 侧 `common/utils/FieldShake.ets` + `MotionTokens.SHAKE_*` 逐值一致，
    // 保证双端观感相同：峰值 10、10 段 × 50ms（总 500ms）。
    // 设计基准 430 空间下 1px = 1dp——画布缩放由 FtCanvas 统一施加。
    const val SHAKE_AMPLITUDE = 10f
    const val DURATION_SHAKE_STEP = 50

    /**
     * 抖动位移序列（[SHAKE_AMPLITUDE] 的倍数），逐段对应 CSS `@keyframes shake`：
     * 10%→-1 20%→+1 30%→-0.8 40%→+0.6 50%→-1
     * 60%→+1 70%→-0.8 80%→+0.6 90%→-0.4 100%→0。
     *
     * 50% 处回到满幅 -1——CSS 是「两轮满幅 + 尾部收敛」，不是单向衰减；末项为 0 保证回到原位。
     */
    val SHAKE_STEPS: List<Float> = listOf(-1f, 1f, -0.8f, 0.6f, -1f, 1f, -0.8f, 0.6f, -0.4f, 0f)

    // ── 曲线 ──────────────────────────────────────────────────
    /** 原型全局 `--ease`：cubic-bezier(.2, .7, .2, 1) */
    val EASE_MOTION: Easing = CubicBezierEasing(0.2f, 0.7f, 0.2f, 1f)

    /** 面板 / sheet：cubic-bezier(.32, .72, .3, 1) */
    val EASE_PANEL: Easing = CubicBezierEasing(0.32f, 0.72f, 0.3f, 1f)

    /** 彩带飞散：cubic-bezier(.16, .7, .3, 1) */
    val EASE_FLY: Easing = CubicBezierEasing(0.16f, 0.7f, 0.3f, 1f)

    /** 彩带下落：cubic-bezier(.2, .55, .35, 1) */
    val EASE_FALL: Easing = CubicBezierEasing(0.2f, 0.55f, 0.35f, 1f)

    /**
     * 入场曲线：cubic-bezier(.2, .8, .2, 1) —— 起步快、收尾稳。
     *
     * 与按压语汇 [EASE_MOTION] 不同：按压要「立刻给反馈」，入场要「柔和落位」。
     * 用于卡片入场、页面元素错峰出现。
     */
    val EASE_ENTER: Easing = CubicBezierEasing(0.2f, 0.8f, 0.2f, 1f)

    /** 入场时长（卡片淡入 + 上移落位）。 */
    const val DURATION_ENTER = 320

    /** 列表项错峰间隔。 */
    const val DURATION_STAGGER = 40

    /**
     * 首页今日卡环形进度补间：环的扫过角度与中心数字在同一 1200ms 内从 0 走到目标。
     *
     * 与鸿蒙 `MotionTokens.DURATION_RING_FILL` 同值，曲线同为 [EASE_ENTER]——
     * 两端都由「一个缓动后的完成度」同时驱动环和数字，同步不是两条动画的巧合。
     */
    const val DURATION_RING_FILL = 1200

    // ── 居中模态弹窗（首页体重 gate）进场弹簧 ──────────────────────────
    //
    // 与鸿蒙 `MotionTokens.SPRING_MODAL_IN = curves.springMotion(0.42, 0.72)` 同源：
    // dampingFraction 0.72 → 有可见过冲；response 0.42s → stiffness = (2π / 0.42)² ≈ 224。
    /** 进场缩放起点（鸿蒙 `MotionTokens.MODAL_GATE_SCALE` 同值）。 */
    const val GATE_ENTER_SCALE = 0.86f

    /** 阻尼比：< 1 才有回弹（对齐鸿蒙 springMotion 第二参）。 */
    const val GATE_SPRING_DAMPING = 0.72f

    /** 刚度：由鸿蒙 response 0.42s 换算 (2π / 0.42)² ≈ 224。 */
    const val GATE_SPRING_STIFFNESS = 224f

    // ── 体重记录底部面板（对齐鸿蒙 WeightRecordDialog） ──────────────
    /** 面板自屏外升起（用户指定 0.5s）。 */
    const val DURATION_PANEL_RAISE = 500

    /** 面板内平滑曲线绘制 / 末端数字滚动（用户指定 1.2s）。 */
    const val DURATION_CHART_DRAW = 1200

    /**
     * 抖动曲线：CSS `ease-in-out` 的等价贝塞尔 (0.42, 0, 0.58, 1)。
     *
     * 不复用 [EASE_MOTION]——那是按压语汇（更快收束）；抖动需在每段关键帧间隔内缓入缓出。
     * 与 Harmony 侧 `MotionTokens.EASE_SHAKE` 同值。
     */
    val EASE_SHAKE: Easing = CubicBezierEasing(0.42f, 0f, 0.58f, 1f)

    // ── 按压缩放系数（原型多处 `.985` / `.96` / `.98` / `.94`） ──
    const val PRESS_SCALE_CTA = 0.985f
    const val PRESS_SCALE_CARD = 0.98f
    const val PRESS_SCALE_TAB_CENTER = 0.96f
    const val PRESS_SCALE_ICON_BTN = 0.94f

    /**
     * 按压回弹弹簧（对齐鸿蒙 `MotionTokens.SPRING_PRESS` = `curves.springMotion(0.28, 0.85)`）。
     *
     * response 0.28s → stiffness = (2π / 0.28)² ≈ 504；dampingFraction 0.85 → 轻微过冲。
     * 与上方 `GATE_SPRING_*` 同一换算式，但取「快而脆」而非 0.42s 的慢弹簧。
     */
    const val PRESS_SPRING_DAMPING = 0.85f

    /** 刚度：由鸿蒙 response 0.28s 换算 (2π / 0.28)² ≈ 504。 */
    const val PRESS_SPRING_STIFFNESS = 504f

    /** 按压收起比例（鸿蒙 `MotionTokens.PRESS_CLOSE` 同值）。比 `PRESS_SCALE_ICON_BTN`(0.94) 更收。 */
    const val PRESS_CLOSE_SCALE = 0.86f
}

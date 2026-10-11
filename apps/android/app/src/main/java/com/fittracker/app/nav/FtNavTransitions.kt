package com.fittracker.app.nav

import androidx.compose.animation.EnterTransition
import androidx.compose.animation.ExitTransition
import androidx.compose.animation.core.CubicBezierEasing
import androidx.compose.animation.core.Easing
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.scaleOut
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideOutHorizontally
import androidx.navigation.NavBackStackEntry

/**
 * 换屏方向三态。
 *
 * 与原型外壳 `fittracker-webapp.html` 的 `data-nav` 取值一一对应
 * （`forward` / `back` / `instant`，见 L206-222）。
 */
enum class FtNavDirection {
    /** 父 → 子：新屏自右推入，旧屏向左退让 */
    FORWARD,

    /** 子 → 父：forward 的完全镜像 */
    BACK,

    /**
     * Tab 之间 / 无层级关系的跳转：**同帧换屏，无位移、无淡入淡出**。
     * 两端都自带底栏时任何交叠动画都会让底栏重影，故必须保持静止。
     */
    INSTANT,
}

/**
 * 换屏语义（[navDir] / [backTarget]）与转场动画（[enter] / [exit]）。
 *
 * 规格源（逐字取原型外壳，非文档转述）：
 *  - `PARENT` 表与 `navDir`——冻结副本 `design/06_prototype_redraw/src/fittracker-webapp.html`
 *    L571-583；同一份实现在 Open Design 项目 `webapp.html` 中亦为 L571-583（本文件按原型冻结副本对齐）；
 *  - `.wa-screen` 转场声明——同文件 CSS L190-222（时长 / 曲线 / 位移 / 缩放）；
 *  - `finishSwap` 交接节拍 420ms——同文件 L705。
 *
 * ⚠️ 原型 `navDir` 含**二级**关系判定（`PARENT[PARENT[to]] === from`）：`plan → planGroup`
 * 跨越 `plans` 一级仍算 forward，`planGroup → plan` 同理算 back。本实现逐字复刻，
 * **不可**简化成只看一级——否则「计划 Tab → 计划组详细」会退化成 instant（无动画）。
 */
object FtNavTransitions {

    /** 无父屏时的回退目标。工单口径：无父则 home（避免返回直接退出 App）。 */
    const val HOME: String = "home"

    /**
     * 层级表（`PARENT[child] = parent`）。
     *
     * 前 10 条逐字取自原型 `fittracker-webapp.html:571-575`；后 2 条为原型外补充：
     * - `accountSync`：鸿蒙独有页（原型无此屏），入口在设置页（`settings`），故补为 `settings` 的子屏——
     *   其返回回退与屏内既有语义（源 `SettingsContent.ets:304`）一致；
     * - `trainingPreferences`：设计侧新增页，入口在个人页快捷（`fittracker-training-preferences.html:448`），
     *   故父屏为 `profile`。
     */
    val PARENT: Map<String, String> = mapOf(
        "login" to "welcome",
        "register" to "login",
        "home" to "welcome",
        "plans" to "plan",
        "planGroup" to "plans",
        "active" to "workout",
        "complete" to "active",
        "library" to "profile",
        "body" to "profile",
        "settings" to "profile",
        "accountSync" to "settings",
        "trainingPreferences" to "profile",
    )

    /** 直接父屏；不在层级表内（含 null / 空串）返回 `null`。 */
    fun parentOf(routeId: String?): String? = routeId?.let { PARENT[it] }

    /**
     * 返回（`popBackStack` 无可退）时的落点：父屏；无父则 [HOME]。
     *
     * 用途见 `FtNavHost.ftBack`——深链直达 / 唯一屏时栈内无可退，直接退出 App 会
     * 让用户丢失上下文，故回退到层级上的父屏。
     */
    fun backTarget(routeId: String?): String = parentOf(routeId) ?: HOME

    /**
     * 由「从哪来 / 到哪去」判定换屏方向。
     *
     * 判定顺序与原型一致：**先 forward 后 back**；
     * `from`/`to` 为空（未就绪的初始态）或同屏视为 [FtNavDirection.INSTANT]。
     *
     * 原型 JS（L578-583）：
     * ```
     * if (isBack) return 'back';
     * if (PARENT[to] === from || PARENT[PARENT[to]] === from) return 'forward';
     * if (PARENT[from] === to || PARENT[PARENT[from]] === to) return 'back';
     * return 'instant';
     * ```
     * 原型里的 `isBack` 参数（返回手势显式声明）由本实现的调用点「pop 走同一判定」
     * 替代——见 `FtNavHost`：pop 时 `initialState` 是退出的子屏、`targetState` 是进入的父屏，
     * 判定结果天然为 back，无需额外 flag；Tab 间的 pop 则天然为 instant。
     */
    fun navDir(from: String?, to: String?): FtNavDirection {
        if (from == null || to == null || from == to) return FtNavDirection.INSTANT

        val toParent = parentOf(to)
        if (toParent == from || parentOf(toParent) == from) return FtNavDirection.FORWARD

        val fromParent = parentOf(from)
        if (fromParent == to || parentOf(fromParent) == to) return FtNavDirection.BACK

        return FtNavDirection.INSTANT
    }

    // ── 转场动画构造器 ──────────────────────────────────────────
    // 数值来源：原型 CSS L190-206。`.wa-screen` 的 transition 是
    //   opacity .30s cubic-bezier(.28, 0, .22, 1),
    //   transform .38s cubic-bezier(.22, 1, .3, 1)
    // 位移（§L206-210）：前进 enter +7% / exit -5%；返回 enter -7% / exit +5%；缩放均 .985。

    /** 进入屏的动画（forward / back 两向由位移符号决定）。 */
    fun enter(direction: FtNavDirection): EnterTransition = when (direction) {
        FtNavDirection.FORWARD -> screenEnter(SHIFT_ENTER_FORWARD)
        FtNavDirection.BACK -> screenEnter(SHIFT_ENTER_BACK)
        FtNavDirection.INSTANT -> EnterTransition.None
    }

    /** 退出屏的动画（forward / back 两向由位移符号决定）。 */
    fun exit(direction: FtNavDirection): ExitTransition = when (direction) {
        FtNavDirection.FORWARD -> screenExit(SHIFT_EXIT_FORWARD)
        FtNavDirection.BACK -> screenExit(SHIFT_EXIT_BACK)
        FtNavDirection.INSTANT -> ExitTransition.None
    }
}

/** 屏路由 id：`NavBackStackEntry.destination.route` 去掉 `?` 之后的查询串。 */
fun NavBackStackEntry.ftRouteId(): String? = destination.route?.substringBefore('?')

// ── 转场数值与构造（原型 CSS L190-210） ──────────────────────────

/** transform 时长：`.38s` */
private const val DURATION_TRANSFORM = 380

/** opacity 时长：`.30s` */
private const val DURATION_OPACITY = 300

/** 进入位移（%），forward 自右推入 */
private const val SHIFT_ENTER_FORWARD = 7

/** 退出位移（%），forward 向左退让 */
private const val SHIFT_EXIT_FORWARD = -5

/** 进入位移（%），back 自左推入（forward 镜像） */
private const val SHIFT_ENTER_BACK = -7

/** 退出位移（%），back 向右退让（forward 镜像） */
private const val SHIFT_EXIT_BACK = 5

/** 交叠期的缩放：`.985` */
private const val SCREEN_SCALE = 0.985f

/** transform 曲线：`cubic-bezier(.22, 1, .3, 1)` */
private val EASE_TRANSFORM: Easing = CubicBezierEasing(0.22f, 1f, 0.3f, 1f)

/** opacity 曲线：`cubic-bezier(.28, 0, .22, 1)` */
private val EASE_OPACITY: Easing = CubicBezierEasing(0.28f, 0f, 0.22f, 1f)

private fun screenEnter(shiftPercent: Int): EnterTransition =
    slideInHorizontally(
        animationSpec = tween(durationMillis = DURATION_TRANSFORM, easing = EASE_TRANSFORM),
        initialOffsetX = { width -> width * shiftPercent / 100 },
    ) + scaleIn(
        animationSpec = tween(durationMillis = DURATION_TRANSFORM, easing = EASE_TRANSFORM),
        initialScale = SCREEN_SCALE,
    ) + fadeIn(
        animationSpec = tween(durationMillis = DURATION_OPACITY, easing = EASE_OPACITY),
    )

private fun screenExit(shiftPercent: Int): ExitTransition =
    slideOutHorizontally(
        animationSpec = tween(durationMillis = DURATION_TRANSFORM, easing = EASE_TRANSFORM),
        targetOffsetX = { width -> width * shiftPercent / 100 },
    ) + scaleOut(
        animationSpec = tween(durationMillis = DURATION_TRANSFORM, easing = EASE_TRANSFORM),
        targetScale = SCREEN_SCALE,
    ) + fadeOut(
        animationSpec = tween(durationMillis = DURATION_OPACITY, easing = EASE_OPACITY),
    )

package com.fittracker.app.nav

import kotlin.math.min

/**
 * 屏的画布口径。
 *
 * 判定依据：`.phone` 首个子元素的 computed `transform` 是否为非 1 的缩放。
 * 逐屏实测结果见 `tools/audit-canvas.mjs`（输出存 `.rivet/scratch/canvas-audit.json`）。
 */
enum class FtCanvasKind {
    /** 内容直接落在外层 390×844 视口内，与设备 vp 1:1 */
    Direct,

    /** 内容在 430×(设计高) 的空间内绘制，整体按 scale 从左上角缩放 */
    Scaled,
}

/**
 * 画布几何（纯计算，可单测）。
 *
 * 原型事实（逐帧实测，非文档转述）：
 * | 屏 | 容器 | 设计空间 | scale | 实测占位 |
 * |---|---|---|---|---|
 * | welcome | `.w-frame` | 430×900 | 0.90698 | 390×816 |
 * | login / register | `.auth-frame` | 430×900 | 0.90698 | 390×816 |
 * | complete | `.cf-frame` | 430×930.56 | 0.90698 | 390×844 |
 *
 * `complete` 的设计高度由 `height: calc(844px / var(--scale))` 得出
 * （`fittracker-training-complete.html:181`），**不是** 900——硬编码 430×900 会把它误判为直绘。
 *
 * ⚠️ `docs/opendesign-1to1-rules.md` §2 称「除 welcome 外其余 14 屏均为 390×844 直绘」，
 * 与源码冲突（实测缩放屏为 welcome / login / register / complete 共 4 屏）。以源码为准。
 */
object FtCanvasSpec {

    /** 原型写死的缩放比（`fittracker-welcome-home.html:195`、`fittracker-auth.html:181`） */
    const val PROTOTYPE_SCALE = 0.90698f

    /** 缩放屏的设计宽度，恒为 430 */
    const val DESIGN_W = 430f

    /** welcome / login / register 的设计高度 */
    const val DESIGN_H_BASE = 900f

    /** 参考视口（原型 `.phone`） */
    const val REF_W = 390f
    const val REF_H = 844f

    /** 设备直绘屏的设计空间 */
    const val DIRECT_W = 390f
    const val DIRECT_H = 844f

    /** `complete` 的设计高度：`calc(844px / var(--scale))` ≈ 930.56 */
    const val DESIGN_H_COMPLETE = REF_H / PROTOTYPE_SCALE

    /**
     * 由可用视口推导缩放比：`min(availW / designW, availH / designH)`。
     *
     * 在参考视口 390×844 下：
     * - welcome/login/register（设计 430×900）→ `min(0.906976, 0.937778) = 0.906976`，与原型一致；
     * - complete（设计 430×930.56）→ `min(0.906976, 0.906972) = 0.906972`，与原型一致。
     */
    fun fitScale(
        availW: Float,
        availH: Float,
        designW: Float = DESIGN_W,
        designH: Float = DESIGN_H_BASE,
    ): Float = min(availW / designW, availH / designH)

    /**
     * 缩放上限。超过 1.0 意味着 430 设计空间被**放大**——字号、描边、圆角同比变粗，
     * 在折叠屏/平板上会显得笨重失真。故封顶 1.0，多余宽度留作两侧留白并居中。
     *
     * 参考视口下 `fitScale = 0.906976 < 1.0`，此上限**不改变参考态**。
     */
    const val MAX_SCALE = 1f

    /**
     * 自适应缩放比：`min(fitScale, MAX_SCALE)`。
     *
     * - 参考视口 390×844 → 0.906976（与原型写死的 0.90698 一致）
     * - 窄屏 320×569 → 0.744（内容整体收小，不溢出）
     * - 超宽 800×1200 → 封顶 1.0（不再放大）
     */
    fun adaptiveScale(
        availW: Float,
        availH: Float,
        designW: Float = DESIGN_W,
        designH: Float = DESIGN_H_BASE,
    ): Float = min(fitScale(availW, availH, designW, designH), MAX_SCALE)

    /**
     * 缩放后内容在可用区域内**水平居中**所需的左偏移。
     *
     * 参考视口下缩放是宽度驱动（`430 × 0.90698 = 390 = 可用宽`），左偏移为 0，
     * 与原型的 `left: 0` 一致；仅在封顶或高度驱动时产生非零偏移。
     * 垂直方向**不居中**——原型 `.w-frame` 是 `top: 0`，留白在底部。
     */
    fun horizontalInset(availW: Float, scale: Float, designW: Float = DESIGN_W): Float =
        ((availW - designW * scale) / 2f).coerceAtLeast(0f)

    /** 缩放后占用的实际尺寸 */
    fun scaledSize(scale: Float, designW: Float, designH: Float): Pair<Float, Float> =
        designW * scale to designH * scale
}

/**
 * 一条屏路由。
 *
 * @param id      路由标识，与原型 webapp 壳的 ROUTES 键一致
 * @param label   中文屏名，逐字取自原型 ROUTES.label
 * @param srcFile 冻结规格副本中的源文件名（`design/06_prototype_redraw/src/` 下）
 * @param frame   源文件内的 `data-od-id` 帧标识
 * @param canvas  画布口径
 * @param designW 设计空间宽（[FtCanvasKind.Scaled] 时有效）
 * @param designH 设计空间高（[FtCanvasKind.Scaled] 时有效）
 * @param isTab   是否为底部 Tab 一级入口
 * @param tabLabel 底栏 Tab 文案。**与 [label] 不是一回事**——原型里 webapp 壳的
 *   `ROUTES[key].label` 与 tabbar 标记内的 `<span>` 文案存在差异（如 review：路由 label 为
 *   「训练回顾」，而 `fittracker-welcome-home.html:940` 的 Tab 文案是「回顾」）。
 *   为 null 时退回 [label]。
 * @param isTabCenter 是否为 Tab 栏中央的胶囊入口（原型 `fittracker-welcome-home.html:934` 的 `.tab-center`）
 */
data class FtRoute(
    val id: String,
    val label: String,
    val srcFile: String,
    val frame: String,
    val canvas: FtCanvasKind,
    val designW: Float = FtCanvasSpec.DIRECT_W,
    val designH: Float = FtCanvasSpec.DIRECT_H,
    val isTab: Boolean = false,
    val tabLabel: String? = null,
    val isTabCenter: Boolean = false,
)

/**
 * 15 条路由的权威表。
 *
 * 顺序逐字对应原型 `fittracker-webapp.html` 的 `ROUTE_ORDER`。
 */
object FtRoutes {

    /**
     * 启动目的地（`FtNavHost` 的 startDestination）。
     *
     * 对齐鸿蒙启动链（`PencilSplashPage` + `StartupDecision`）：启动进 splash 分流
     * （未登录 → login / 已登录 → home）；原型首屏 `welcome` 仍注册可达（深链/自测）。
     */
    const val START: String = "splash"

    /** 深链接 scheme：`fittracker://<routeId>`，用于外部直达与验收脚本。 */
    const val DEEP_LINK_SCHEME: String = "fittracker"

    private const val WELCOME_HOME = "fittracker-welcome-home.html"
    private const val AUTH = "fittracker-auth.html"

    private val scaled = FtCanvasKind.Scaled

    val all: List<FtRoute> = listOf(
        FtRoute("welcome", "欢迎页", WELCOME_HOME, "screen-welcome", scaled,
            FtCanvasSpec.DESIGN_W, FtCanvasSpec.DESIGN_H_BASE),
        FtRoute("login", "登录", AUTH, "screen-login", scaled,
            FtCanvasSpec.DESIGN_W, FtCanvasSpec.DESIGN_H_BASE),
        FtRoute("register", "注册", AUTH, "screen-register", scaled,
            FtCanvasSpec.DESIGN_W, FtCanvasSpec.DESIGN_H_BASE),
        FtRoute("home", "首页", WELCOME_HOME, "screen-home", FtCanvasKind.Direct, isTab = true),
        FtRoute("plan", "计划", "fittracker-plan.html", "screen-plan", FtCanvasKind.Direct, isTab = true),
        FtRoute("workout", "训练", "fittracker-training-preview.html", "screen-training-preview",
            FtCanvasKind.Direct, isTab = true, isTabCenter = true),
        FtRoute("plans", "计划组", "fittracker-plan-detail.html", "screen-plan-detail", FtCanvasKind.Direct),
        FtRoute("planGroup", "计划组详细", "fittracker-plan-group-detail.html", "screen-plan-group-detail",
            FtCanvasKind.Direct),
        FtRoute("active", "训练执行", "fittracker-training.html", "screen-training", FtCanvasKind.Direct),
        FtRoute("complete", "训练完成", "fittracker-training-complete.html", "screen-training-complete", scaled,
            FtCanvasSpec.DESIGN_W, FtCanvasSpec.DESIGN_H_COMPLETE),
        FtRoute("review", "训练回顾", "fittracker-review.html", "screen-review", FtCanvasKind.Direct,
            isTab = true, tabLabel = "回顾"),
        FtRoute("library", "动作库", "fittracker-exercise-library.html", "screen-exercise-library",
            FtCanvasKind.Direct),
        FtRoute("body", "身体数据", "fittracker-body-data.html", "screen-body-data", FtCanvasKind.Direct),
        FtRoute("profile", "我的", "fittracker-personal.html", "screen-personal", FtCanvasKind.Direct, isTab = true),
        FtRoute("settings", "设置", "fittracker-settings.html", "screen-settings", FtCanvasKind.Direct),
    )

    /** 底部 Tab 一级入口，顺序即 Tab 栏从左到右。 */
    val tabs: List<FtRoute> = all.filter { it.isTab }

    /**
     * [all]（原型 15 条）之外的可导航屏，共 4 条，两类来源：
     * - **鸿蒙独有 3 页**（`splash` / `exerciseDetail` / `legal`）：无原型 HTML 帧，
     *   规格源为鸿蒙工程 ets（`srcFile` 字段记源文件名，非冻结副本文件）；
     * - **`trainingPreferences`**：设计侧新增页——训练偏好原型 footer（`fittracker-training-preferences.html:448`）
     *   明示「真实路由应由个人页『训练偏好』快捷入口跳转至本页」；该页不在原型 webapp 的 `ROUTE_ORDER` 内，
     *   故不入 [all]，但其 `srcFile` 是冻结副本内的原型文件（含真实帧 `screen-training-preferences`）。
     * 与 [all] 分开维护（[all] 的保真断言见 `FtRoutesTest`）；导航注册用 [navigable]。
     */
    val extra: List<FtRoute> = listOf(
        FtRoute("splash", "启动", "PencilSplashPage.ets", "screen-splash", FtCanvasKind.Direct),
        FtRoute("exerciseDetail", "动作详情", "ExerciseDetailPage.ets", "screen-exercise-detail", FtCanvasKind.Direct),
        FtRoute("legal", "法律文档", "LegalDocPage.ets", "screen-legal", FtCanvasKind.Direct),
        FtRoute("trainingPreferences", "训练偏好", "fittracker-training-preferences.html",
            "screen-training-preferences", FtCanvasKind.Direct),
    )

    /** 全部可导航路由：原型 15 条 + [extra] 4 条（NavHost 注册来源）。 */
    val navigable: List<FtRoute> = all + extra

    fun byId(id: String): FtRoute? = navigable.firstOrNull { it.id == id }
}

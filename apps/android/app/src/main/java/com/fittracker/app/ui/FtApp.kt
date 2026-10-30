package com.fittracker.app.ui

import androidx.compose.animation.AnimatedVisibility
import androidx.activity.compose.LocalActivity
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.LinearOutSlowInEasing
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.scaleOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Scaffold
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.TransformOrigin
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.unit.dp
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import androidx.navigationevent.NavigationEventDispatcher
import androidx.navigationevent.NavigationEventDispatcherOwner
import androidx.navigationevent.NavigationEventHandler
import androidx.navigationevent.NavigationEventInfo
import com.fittracker.app.nav.FtNavHost
import com.fittracker.app.nav.FtRoutes
import com.fittracker.app.nav.navigateToTab
import com.fittracker.app.data.persist.JsonStore
import com.fittracker.app.data.persist.appDataStore
import com.fittracker.app.data.service.WorkoutDraftService
import com.fittracker.app.data.service.hasWorkoutDraftProgress
import com.fittracker.app.ui.components.FtBottomTabBar
import com.fittracker.app.ui.components.ResumeDraftSummary
import com.fittracker.app.ui.components.ResumeWorkoutBar
import com.fittracker.app.ui.components.WeightGateDialog
import com.fittracker.app.ui.screens.workout.WorkoutPreviewScreen
import com.fittracker.app.ui.theme.FtColor
import com.fittracker.app.ui.theme.FtMotion
import com.fittracker.app.ui.theme.FtTheme

// ── Tab 切换内容动效令牌（W2-5） ──────────────────────────────────────────
// 取值逐条来自原型 `select()`：`fittracker-welcome-home.html:964-995`
// （`fittracker-plan.html:917-946` 的 `selectTab()` 同构）。本文件是唯一消费点，
// 故就近定义；若出现第二个消费点应上移进 FtMotion（本轮 files 范围未覆盖 theme 层）。

/** 原型 `select()`：内容区回弹 `.16s`。 */
private const val TAB_SHIFT_DURATION_MS = 160

/** 原型 `select()`：起点 `translateX(8 * dir)px` —— 侧偏 8px，方向随 Tab 次序定正负。 */
private const val TAB_SHIFT_DISTANCE_DP = 8

/** 原型 `select()`：起点 `scale(.99)` —— 微缩。 */
private const val TAB_SHIFT_MIN_SCALE = 0.99f

/** 原型 `select()`：起点 `opacity .88` —— 压暗。 */
private const val TAB_SHIFT_MIN_ALPHA = 0.88f

/**
 * 应用外壳。
 *
 * 底部 Tab 栏**仅在 Tab 一级路由上出现**——与原型一致：`fittracker-welcome-home.html`
 * 里 `.appshell`（含 `.tabbar`）只包住 home/plan/workout/review/profile 五个 pane，
 * 而 login / active / settings 等屏是独立整屏，不带 Tab 栏。
 */
@Composable
fun FtApp() {
    FtTheme {
        val navController = rememberNavController()
        val backStackEntry by navController.currentBackStackEntryAsState()
        val currentId = backStackEntry?.destination?.route ?: FtRoutes.START
        // 底栏按**帧**判定，而非按路由的 Tab 属性：
        // `workout` 在 ROUTES 里确实是 Tab 一级入口（tabbar 中央胶囊就是它），
        // 但它加载的 `fittracker-training-preview.html` 是整屏帧
        // （`.pv-frame { position:absolute; inset:0 }`，文件内**没有** `.tabbar`），
        // 故该屏不渲染底栏——否则内容区矮一个底栏高，与原型参照帧对不齐。
        val onTab = FtRoutes.tabs.any { it.id == currentId } && currentId != "workout"

        // ── chrome 收起状态（内容屏写、壳层读） ─────────────────────────────
        // 回顾页向下滚动时置 true：底栏滑出、屏内头部收缩。离开任何 Tab 帧时强制复位，
        // 避免「在回顾页收起后进入设置/登录，底栏状态仍残留」。
        val chrome = remember { FtChromeState() }

        // ── 训练预览覆盖层（对齐鸿蒙：中央 Tab 只叠一层，不切帧） ───────────────
        // 鸿蒙 `PencilAppShell` 里 `showPreview` 只是 `Stack` 上的一个条件分支：底栏不动、
        // 当前 Tab 不变、不产生返回栈。这里用同样的模型，`workout` 路由仅保留给深链。
        var showPreview by remember { mutableStateOf(false) }
    // 首页「开始训练」前置的体重记录弹窗（居中，缩放 + 弹簧进场）。
    // 与 showPreview 同为壳层状态：底栏中央训练键也要走同一个 gate。
    var showWeightGate by remember { mutableStateOf(false) }

        // ── 训练进行中悬浮条（草稿 → 底栏上沿常驻入口） ─────────────────────
        // 每次路由变化（含从训练页返回）重读一次草稿：训练中记录组不推进这里，
        // 因为悬浮条只在训练页之外显示；回到主壳时 currentId 必变，够用。
        val appContext = LocalContext.current
        val draftStore = remember { JsonStore(appContext.appDataStore) }
        var resumeDraft by remember { mutableStateOf<ResumeDraftSummary?>(null) }

        // ── Tab 切换内容动效（W2-5，对齐原型 `select()`） ──────────────────
        // 原型语义：Tab 壳层**瞬时**换屏（`select()` 直接 classList.toggle，无过渡），
        // 动效只发生在**内容区** `#viewport` —— 先瞬时落到「侧偏 8px / 微缩 .99 /
        // 压暗 .88」的起点，再由 160ms 曲线回弹归位（`transition .16s
        // cubic-bezier(0, 0, .2, 1)`，opacity 用 `ease`）。
        //
        // 触发面：仅 Tab 一级路由之间的切换（含中央 workout）；splash 分流出的首屏、
        // 以及屏内跳转（如 home→settings）都不触发——原型里这些不经 `select()`。
        val tabIds = remember { FtRoutes.tabs.map { it.id } }
        var previousTabId by remember { mutableStateOf<String?>(null) }
        var shiftDirection by remember { mutableIntStateOf(1) }
        // 1f = 归位（无视觉效果）；每次 Tab 切换先 snapTo(0f) 落到起点再动画回 1f。
        val contentSettle = remember { Animatable(1f) }

        LaunchedEffect(currentId) {
            // chrome 复位与 Tab 动效共用一次订阅：**任何**帧切换都复位。
            //
            // 旧实现只在「离开 Tab 帧」时复位，漏掉了 Tab↔Tab：在回顾页下滑收起后
            // 切到 home / plan，底栏继续保持收起；而 `<review>` 的 `rememberScrollState`
            // 会把中途位置一起恢复，切回来时头部与底栏双双隐藏，且没有滚动事件能把
            // 它复位（见 ReviewScreen 的 `observeChromeOnScroll`）。用户看到的就是
            // 「回顾页没回顶就切回来，上下直接没了」。
            chrome.updateCollapsed(false)

            // 与 chrome 复位、Tab 动效共用一次订阅：不另起 LaunchedEffect，
            // 否则每次 Tab 切换会多一次协程与一次读盘。
            resumeDraft = loadResumeDraft(draftStore)

            val from = previousTabId
            previousTabId = currentId
            val fromIndex = from?.let { tabIds.indexOf(it) } ?: -1
            val toIndex = tabIds.indexOf(currentId)
            // 非 Tab↔Tab（首次组合、splash 分流、屏内跳转）→ 保持静默。
            if (fromIndex < 0 || toIndex < 0 || fromIndex == toIndex) return@LaunchedEffect
            // 与原型 `ORDER.indexOf(key) >= ORDER.indexOf(current) ? 1 : -1` 同式。
            shiftDirection = if (toIndex > fromIndex) 1 else -1
            // 原型先 `transition='none'` + 强制 reflow 跳到起点，再恢复过渡回弹；
            // 对应 Compose 的「snapTo 起点 → animateTo 终点」。
            contentSettle.snapTo(0f)
            contentSettle.animateTo(
                targetValue = 1f,
                // `cubic-bezier(0, 0, .2, 1)` 即 Compose 内置 LinearOutSlowInEasing。
                animationSpec = tween(
                    durationMillis = TAB_SHIFT_DURATION_MS,
                    easing = LinearOutSlowInEasing,
                ),
            )
        }

        CompositionLocalProvider(LocalFtChrome provides chrome) {
            // 覆盖层必须在 Scaffold **外面**：Scaffold 的 content 受 `.padding(inner)` 与底栏测量约束，
            // 训练预览要像鸿蒙 `PencilAppShell` 那样整屏盖住底栏，只能挂在它之上。
            Box(modifier = Modifier.fillMaxSize()) {
                Scaffold(
                    containerColor = FtColor.bg,
                    // 关键：原型画布是**不含系统栏**的 390×844 整屏。
                    // Scaffold 默认会按 systemBars 内缩内容区，导致 FtCanvas 的可用高变小、
                    // fitScale 被算小（实测有效缩放 0.855 vs 原型 0.90698，且整体下移一个状态栏）。
                    // 故显式清零 insets，让内容真正 edge-to-edge。
                    contentWindowInsets = WindowInsets(0),
                    bottomBar = {
                        // 收起/恢复：底栏整条滑出屏幕并淡出。Scaffold 按测量收缩 `inner` 的下内边距，
                        // 内容区随之自然长高——不会像 `offset` 那样在底部留一条死区。
                        AnimatedVisibility(
                            // 体重 gate 打开时收起主导航栏：面板贴底，底栏必须让位
                            visible = onTab && !chrome.collapsed && !showWeightGate,
                            enter = slideInVertically(
                                animationSpec = tween(FtMotion.DURATION_CHROME, easing = FtMotion.EASE_PANEL),
                                initialOffsetY = { it },
                            ) + fadeIn(tween(FtMotion.DURATION_CHROME)),
                            exit = slideOutVertically(
                                animationSpec = tween(FtMotion.DURATION_CHROME, easing = FtMotion.EASE_PANEL),
                                targetOffsetY = { it },
                            ) + fadeOut(tween(FtMotion.DURATION_COLOR_FAST)),
                        ) {
                            FtBottomTabBar(
                                currentRouteId = currentId,
                                onSelect = { id ->
                                    // 与鸿蒙 `PencilAppShell` 对齐：中央训练键**不开新帧**，只覆盖预览层。
                                    // 走 `navigateToTab` 会先 `popUpTo("home")`，把当前 Tab 重置到首页。
                                    // 中央训练键与首页「开始训练」同一入口语义：先记体重再进预览。
                                    if (id == "workout") showWeightGate = true
                                    else navController.navigateToTab(id)
                                },
                            )
                        }
                    },
                ) { inner ->
                    FtNavHost(
                        navController = navController,
                        onOpenPreview = { showPreview = true },
                        onStartWorkout = { showWeightGate = true },
                        modifier = Modifier
                            .padding(inner)
                            // 动效施加在**内容区**（不含底栏），与原型作用于 `#viewport` 同级：
                            // 底栏不参与位移/缩放，Tab 间也不会出现整屏推入式位移。
                            .graphicsLayer {
                                val away = 1f - contentSettle.value // 1f = 未归位（起点），0f = 已归位
                                translationX = shiftDirection * TAB_SHIFT_DISTANCE_DP.dp.toPx() * away
                                val scale = 1f - (1f - TAB_SHIFT_MIN_SCALE) * away
                                scaleX = scale
                                scaleY = scale
                                alpha = 1f - (1f - TAB_SHIFT_MIN_ALPHA) * away
                            },
                    )
                }

                // ── 训练进行中悬浮条（贴底栏上沿，跨 Tab 常驻） ────────────────────
                // 与鸿蒙 PencilAppShell.resumeWorkoutBar 同构。预览/体重 gate 打开时隐藏：
                // 那两层是覆盖式流程，悬浮条压在上面会遮住它们的底部按钮。
                val draftBar = resumeDraft
                AnimatedVisibility(
                    visible = draftBar != null && onTab && !chrome.collapsed && !showWeightGate && !showPreview,
                    // 出现：自下方上浮 + 缩放回弹 + 淡入。从训练页收起回来时胶囊「长」出来，
                    // 接住上一个动作的注意力，而不是硬切上来。
                    enter = slideInVertically(
                        animationSpec = tween(FtMotion.DURATION_ENTER, easing = FtMotion.EASE_ENTER),
                        initialOffsetY = { it / 2 },
                    ) + fadeIn(tween(FtMotion.DURATION_ENTER)) + scaleIn(
                        animationSpec = tween(FtMotion.DURATION_ENTER, easing = FtMotion.EASE_ENTER),
                        initialScale = RESUME_BAR_ENTER_SCALE,
                        transformOrigin = RESUME_BAR_TRANSFORM_ORIGIN,
                    ),
                    // 消失：比进场快（160ms）。草稿被清空是「状态没了」，不该慢吞吞。
                    exit = slideOutVertically(
                        animationSpec = tween(FtMotion.DURATION_COLOR_FAST, easing = FtMotion.EASE_MOTION),
                        targetOffsetY = { it / 2 },
                    ) + fadeOut(tween(FtMotion.DURATION_COLOR_FAST)),
                    modifier = Modifier
                        .align(Alignment.BottomCenter)
                        .navigationBarsPadding()
                        .padding(bottom = BOTTOM_BAR_STACK_HEIGHT_DP.dp + 10.dp),
                ) {
                    if (draftBar != null) {
                        ResumeWorkoutBar(
                            summary = draftBar,
                            onClick = { navController.navigate("active") },
                        )
                    }
                }

                // ── 体重记录 gate（居中弹窗，遮罩淡入 + 卡片弹簧缩放） ──────────────
                // 压在预览覆盖层之下：确认后 showWeightGate=false → showPreview=true。
                if (showWeightGate) {
                    WeightGateDialog(
                        onCancel = { showWeightGate = false },
                        onConfirmed = {
                            showWeightGate = false
                            showPreview = true
                        },
                    )
                }

                // ── 训练预览覆盖层（对齐鸿蒙 PencilAppShell.ets:208-241） ────────────
                // 遮罩只淡入淡出，面板额外从 0.92 缩放落位、锚点底边中点——两者分开驱动，
                // 合并成一个 AnimatedVisibility 会让遮罩跟着缩。
                AnimatedVisibility(
                    visible = showPreview,
                    enter = fadeIn(tween(FtMotion.DURATION_COLOR_FAST)),
                    exit = fadeOut(tween(FtMotion.DURATION_COLOR_FAST)),
                ) {
                    Box(
                        modifier = Modifier
                            .fillMaxSize()
                            .background(Color.Black.copy(alpha = PREVIEW_SCRIM_ALPHA)),
                    )
                }
                AnimatedVisibility(
                    visible = showPreview,
                    enter = fadeIn(tween(FtMotion.DURATION_MODAL, easing = FtMotion.EASE_PANEL)) +
                        scaleIn(
                            animationSpec = tween(FtMotion.DURATION_MODAL, easing = FtMotion.EASE_PANEL),
                            initialScale = PREVIEW_ENTER_SCALE,
                            transformOrigin = PREVIEW_TRANSFORM_ORIGIN,
                        ),
                    exit = fadeOut(tween(FtMotion.DURATION_MODAL, easing = FtMotion.EASE_PANEL)) +
                        scaleOut(
                            animationSpec = tween(FtMotion.DURATION_MODAL, easing = FtMotion.EASE_PANEL),
                            targetScale = PREVIEW_ENTER_SCALE,
                            transformOrigin = PREVIEW_TRANSFORM_ORIGIN,
                        ),
                ) {
                    WorkoutPreviewScreen(
                        onNavigate = { target ->
                            // 先关覆盖层再跳转（同鸿蒙 PencilPreviewPage 的 requestClose → pushUrl）：
                            // 覆盖层压在 Scaffold 之上，不关会盖住训练执行页直到退出动画结束。
                            showPreview = false
                            navController.navigate(target)
                        },
                        onBack = { showPreview = false },
                        modifier = Modifier.fillMaxSize(),
                    )
                }

                // 返回键优先级：覆盖层打开时，返回只关覆盖层，**不能**让底下的 NavHost 回退。
                //
                // 实测结论（navigationevent 1.1.2 反编译）：`NavigationEventProcessor` 把
                // handler 分成两档 —— `PRIORITY_OVERLAY(0)` 先于 `PRIORITY_DEFAULT(1)`；
                // 同档内后注册先执行。`NavHost` 注册的是默认档，而 compose 的
                // `NavigationBackHandler` **不暴露 priority 参数**，只能落在默认档，
                // 于是事件先被 NavHost 吃掉（真机表现：返回键把底层 Tab 从「计划」退回
                // 「首页」、预览不动；加日志后确认我们的回调一次都没触发）。
                // 故这里绕开 compose 封装，直接用核心库注册到 overlay 档。
                if (showPreview || showWeightGate) {
                    val dispatcherOwner = LocalActivity.current as NavigationEventDispatcherOwner
                    DisposableEffect(dispatcherOwner) {
                        val overlayBackHandler = object : NavigationEventHandler<NavigationEventInfo>(
                            NavigationEventInfo.None,
                            true,
                            false,
                        ) {
                            override fun onBackCompleted() {
                                // 体重 gate 叠在预览之上：返回键先关它
                                if (showWeightGate) showWeightGate = false else showPreview = false
                            }
                        }
                        overlayBackHandler.setInfo(
                            NavigationEventInfo.None,
                            listOf(NavigationEventInfo.None),
                            emptyList(),
                        )
                        dispatcherOwner.navigationEventDispatcher.addHandler(
                            overlayBackHandler,
                            NavigationEventDispatcher.PRIORITY_OVERLAY,
                        )
                        onDispose { overlayBackHandler.remove() }
                    }
                }
            }
        }
    }
}

/** 底栏整体占位高度：内容 56 + 上下各 8（`FtBottomTabBar` 的 padding）。 */
private const val BOTTOM_BAR_STACK_HEIGHT_DP = 72

/** 悬浮胶囊进场起点缩放（与鸿蒙 `TransitionEffect.scale(0.92)` 同值）。 */
private const val RESUME_BAR_ENTER_SCALE = 0.92f

/** 胶囊缩放锚点：底边中点——从底栏里「长」出来，不是从中心膨胀。 */
private val RESUME_BAR_TRANSFORM_ORIGIN = TransformOrigin(0.5f, 1f)

/**
 * 读取进行中训练的展示摘要；无草稿或无进度时返回 null。
 *
 * 判据用 `hasWorkoutDraftProgress`（与 `ActiveScreen` 恢复草稿同一份实现），
 * 不用 `completedSets > 0`：否则会出现「首页说有、点进去说没有」。
 */
private suspend fun loadResumeDraft(store: JsonStore): ResumeDraftSummary? {
    val draft = WorkoutDraftService.getDraft(store) ?: return null
    if (!hasWorkoutDraftProgress(draft)) return null
    val seconds = ((System.currentTimeMillis() - draft.startedAt) / 1_000L).toInt().coerceAtLeast(0)
    // 当前动作 = 首个未录满的动作（全部录满时退到最后一个）——与 ActiveScreen 的选中口径
    // 同一判据，否则胶囊上的动作名会和点进去看到的那个对不上。
    val current = draft.exercises.firstOrNull { it.completedSets < it.targetSets }
        ?: draft.exercises.lastOrNull()
    return ResumeDraftSummary(
        completedSets = draft.completedSets,
        totalSets = draft.totalTargetSets,
        elapsedSeconds = seconds,
        exerciseName = current?.name ?: draft.currentExerciseName,
        exerciseCompletedSets = current?.completedSets ?: 0,
        exerciseTargetSets = current?.targetSets ?: 0,
    )
}

/** 鸿蒙 `.pv-backdrop { background: rgba(0,0,0,.6) }`。 */
private const val PREVIEW_SCRIM_ALPHA = 0.6f

/** 鸿蒙面板进场起点 `scale(.92)`。 */
private const val PREVIEW_ENTER_SCALE = 0.92f

/** 鸿蒙 `transform-origin: 50% 100%` —— 锚点底边中点。 */
private val PREVIEW_TRANSFORM_ORIGIN = TransformOrigin(0.5f, 1f)

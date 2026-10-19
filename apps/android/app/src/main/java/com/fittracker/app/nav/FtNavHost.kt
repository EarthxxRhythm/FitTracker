package com.fittracker.app.nav

import androidx.activity.compose.LocalActivity
import androidx.compose.animation.AnimatedContentTransitionScope
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.Modifier
import androidx.navigation.NavBackStackEntry
import androidx.navigation.NavHostController
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.navArgument
import androidx.navigation.navDeepLink
import androidx.navigationevent.NavigationEventDispatcherOwner
import androidx.navigationevent.compose.LocalNavigationEventDispatcherOwner
import com.fittracker.app.ui.screens.FtScreen
import com.fittracker.app.ui.screens.exercise.ExerciseDetailScreen
import com.fittracker.app.ui.screens.legal.LegalDocScreen
import com.fittracker.app.ui.screens.plangroup.PlanGroupScreen

/**
 * 导航宿主：原型 15 路由 + 鸿蒙独有 3 条（splash / exerciseDetail / legal）。
 *
 * 注册来源是 [FtRoutes.navigable]；`legal` 因带 `kind` 查询参数单独注册（对齐鸿蒙
 * `LegalDocParams` 的缺失回退语义）。其余路由与原型 `fittracker-webapp.html` 的
 * ROUTE_ORDER 逐项对应（保真断言见 `FtRoutesTest`）。
 *
 * 每条路由同时注册 `fittracker://<routeId>` 深链接，用于外部直达与验收脚本：
 * `adb shell am start -a android.intent.action.VIEW -d "fittracker://home"`
 */
@Composable
fun FtNavHost(
    navController: NavHostController,
    modifier: Modifier = Modifier,
) {
    // 修复（真机启动崩溃 "No NavigationEventDispatcher was provided via LocalNavigationEventDispatcherOwner"）：
    // AppCompat 宿主下 ViewTree 的 owner 不被 navigation-compose 的桥发现 → 显式把 Activity
    // （ComponentActivity 实现 NavigationEventDispatcherOwner）provide 给局部变量；幂等（就近覆盖）。
    val dispatcherOwner = LocalActivity.current as NavigationEventDispatcherOwner
    CompositionLocalProvider(LocalNavigationEventDispatcherOwner provides dispatcherOwner) {
    NavHost(
        navController = navController,
        startDestination = FtRoutes.START,
        modifier = modifier,
        // 三态转场（W2-4）：方向由 [FtNavTransitions.navDir] 判定——
        // forward 推入 / back 镜像 / instant 静止。导航库对所有跳转默认套
        // fadeIn/fadeOut(tween(700))，必须显式覆盖：Tab 切换（instant）若继承默认淡入，
        // 两端底栏会重影，与原型 `.wa-frame[data-nav="instant"]` 的「无位移无淡入」相悖。
        enterTransition = { FtNavTransitions.enter(transitionDirection()) },
        exitTransition = { FtNavTransitions.exit(transitionDirection()) },
        popEnterTransition = { FtNavTransitions.enter(transitionDirection()) },
        popExitTransition = { FtNavTransitions.exit(transitionDirection()) },
    ) {
        FtRoutes.navigable.filter { it.id != "legal" && it.id != "exerciseDetail" && it.id != "planGroup" }.forEach { route ->
            composable(
                route = route.id,
                deepLinks = listOf(navDeepLink { uriPattern = "${FtRoutes.DEEP_LINK_SCHEME}://${route.id}" }),
            ) {
                FtScreen(
                    route = route,
                    onNavigate = { target ->
                        navController.navigate(target) {
                            // 从 splash 出发的跳转 = `replaceUrl` 语义（对齐鸿蒙 PencilSplashPage）：
                            // 分流后 splash 出栈，返回键不会回到启动画面。
                            if (navController.currentDestination?.route == "splash") {
                                popUpTo("splash") { inclusive = true }
                            }
                        }
                    },
                    onBack = { navController.ftBack(route.id) },
                )
            }
        }

        // legal 特判：带 `kind` 查询参数（对齐鸿蒙 `LegalDocPage` 的 `LegalDocParams`——
        // 缺失/非法回退 "privacy"）。其余路由无需参数，保持循环注册。
        composable(
            route = "legal?kind={kind}",
            arguments = listOf(navArgument("kind") { defaultValue = "privacy" }),
            deepLinks = listOf(
                navDeepLink { uriPattern = "${FtRoutes.DEEP_LINK_SCHEME}://legal" },
                navDeepLink { uriPattern = "${FtRoutes.DEEP_LINK_SCHEME}://legal?kind={kind}" },
            ),
        ) { backStackEntry ->
            LegalDocScreen(
                kind = backStackEntry.arguments?.getString("kind") ?: "privacy",
                onBack = { navController.ftBack("legal") },
            )
        }

        // planGroup 特判：带 `planId` 查询参数（缺失回退空串 → 屏内渲染「未找到计划」空态）。
        // 列表页经 `onNavigate("planGroup?planId=preset_ppl")` 传入（对齐鸿蒙
        // `PlansContent.ets:317-321` 的 `pushUrl(params:{planId})`）；深链亦可直达。
        composable(
            route = "planGroup?planId={planId}",
            arguments = listOf(navArgument("planId") { defaultValue = "" }),
            deepLinks = listOf(
                navDeepLink { uriPattern = "${FtRoutes.DEEP_LINK_SCHEME}://planGroup" },
                navDeepLink { uriPattern = "${FtRoutes.DEEP_LINK_SCHEME}://planGroup?planId={planId}" },
            ),
        ) { backStackEntry ->
            PlanGroupScreen(
                planId = backStackEntry.arguments?.getString("planId") ?: "",
                onNavigate = { target ->
                    navController.navigate(target) {
                        if (navController.currentDestination?.route == "splash") {
                            popUpTo("splash") { inclusive = true }
                        }
                    }
                },
                onBack = { navController.ftBack("planGroup") },
            )
        }

        // exerciseDetail 特判：带 `exerciseId` 查询参数（缺失回退空串 → 屏内渲染「未找到动作」空态）。        // 入口说明：源 `ExerciseLibraryPage.ets:5` ——「卡片点击打开底部弹层（不再跳转
        // ExerciseDetailPage）」——本页在源侧为**保留可达页**（Library 的卡片走弹层）；
        // 安卓侧同理：Library 保持弹层，本页经深链 / 未来入口可达。
        composable(
            route = "exerciseDetail?exerciseId={exerciseId}",
            arguments = listOf(navArgument("exerciseId") { defaultValue = "" }),
            deepLinks = listOf(
                navDeepLink { uriPattern = "${FtRoutes.DEEP_LINK_SCHEME}://exerciseDetail" },
                navDeepLink { uriPattern = "${FtRoutes.DEEP_LINK_SCHEME}://exerciseDetail?exerciseId={exerciseId}" },
            ),
        ) { backStackEntry ->
            ExerciseDetailScreen(
                exerciseId = backStackEntry.arguments?.getString("exerciseId") ?: "",
                onBack = { navController.ftBack("exerciseDetail") },
            )
        }
    }
    }
}

/**
 * 本次换屏的方向：由「退出屏 → 进入屏」的路由 id 判定。
 *
 * push 时 `initialState` 是旧屏、`targetState` 是新屏；pop 时 `initialState` 是退出
 * 的子屏、`targetState` 是进入的父屏——两种情形共用同一判定即可自然落到 back
 * （层级返回）/ instant（Tab 间的 pop），无需额外 flag（原型 `navDir` 的 `isBack`
 * 参数由本函数取代）。
 */
private fun AnimatedContentTransitionScope<NavBackStackEntry>.transitionDirection(): FtNavDirection =
    FtNavTransitions.navDir(initialState.ftRouteId(), targetState.ftRouteId())

/**
 * 返回上一屏：优先出栈（与系统返回键行为一致）；栈内无可退（深链直达 / 唯一屏）时
 * 按 `PARENT` 表回退父屏（无父则 `home`），避免直接退出 App。
 */
fun NavHostController.ftBack(currentRouteId: String) {
    if (!popBackStack()) {
        navigate(FtNavTransitions.backTarget(currentRouteId))
    }
}

/**
 * Tab 间切换：单例栈 + 状态保留，回退不产生 Tab 堆叠。
 */
fun NavHostController.navigateToTab(routeId: String) {
    navigate(routeId) {
        // Tab 保栈锚：弹到主壳首屏 `home` 之上全清（单例栈 + 状态保留）。
        // 启动链改由 splash 分流后 startDestination（splash）会被清出栈，原
        // `popUpTo(graph.startDestinationId)` 对已不在栈的目标是空操作（tab 会堆叠），
        // 故锚显式改为主壳常驻首屏 `home`（未及进入主壳时同样为空操作）。
        popUpTo("home") { saveState = true }
        launchSingleTop = true
        restoreState = true
    }
}

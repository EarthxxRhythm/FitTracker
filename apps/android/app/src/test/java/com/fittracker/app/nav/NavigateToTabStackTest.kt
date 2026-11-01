package com.fittracker.app.nav

import android.content.Context
import androidx.navigation.compose.ComposeNavigator
import androidx.navigation.compose.composable
import androidx.navigation.createGraph
import androidx.navigation.testing.TestNavHostController
import androidx.test.core.app.ApplicationProvider
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * `navigateToTab` 栈行为 JVM 反证（bug：底栏点「计划」却显示回顾屏）。
 *
 * 静态接线全链路正确（FtBottomTabBar/FtApp/FtScreens 均按 id 直连），缺陷只可能在
 * `popUpTo("home"){saveState=true}` + `launchSingleTop` + `restoreState=true` 的
 * 运行时栈行为。本探针在真实 NavController 上复现各栈形，任一 RED = H1（栈恢复错帧）成立。
 *
 * 断言两件套（议事会 tianfu 补强）：
 *  - 栈顶 route 是目标 tab；
 *  - back stack 中**不含** review 条目——restoreState 恢复出含 review 的栈时，
 *    仅断言 currentDestination 会误绿。
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class NavigateToTabStackTest {

    private val context: Context = ApplicationProvider.getApplicationContext()

    private val allRoutes: List<String> = listOf(
        "home", "plan", "workout", "review", "profile", "plans", "planGroup", "complete"
    )

    private fun newNav(start: String = "home"): TestNavHostController {
        val nav = TestNavHostController(context)
        nav.navigatorProvider.addNavigator(ComposeNavigator())
        // navigation-testing 2.10 的 setGraph 只收资源 Int，编程式图经 graph 属性挂载。
        nav.graph = nav.createGraph(startDestination = start) {
            allRoutes.forEach { route ->
                composable(route) {}
            }
        }
        return nav
    }

    private fun TestNavHostController.assertTopIs(route: String) {
        assertEquals(
            "栈顶帧应为 $route，实际栈：${currentBackStack.value.map { it.destination.route }}",
            route,
            currentDestination?.route
        )
    }

    private fun TestNavHostController.assertNoRouteInStack(route: String) {
        val routes = currentBackStack.value.map { it.destination.route }
        assertTrue(
            "back stack 不应含 $route，实际栈：$routes",
            routes.none { it == route }
        )
    }

    @Test
    fun `tap plan from home lands on plan without review in stack`() {
        val nav = newNav()
        nav.navigateToTab("plan")
        nav.assertTopIs("plan")
        nav.assertNoRouteInStack("review")
    }

    @Test
    fun `user reported sequence review then plan lands on plan`() {
        val nav = newNav()
        nav.navigateToTab("review")
        nav.navigateToTab("plan")
        nav.assertTopIs("plan")
        nav.assertNoRouteInStack("review")
    }

    @Test
    fun `tap plan after pushing plans from plan lands on plan`() {
        val nav = newNav()
        nav.navigateToTab("plan")
        nav.navigate("plans")
        nav.navigateToTab("review")
        nav.navigateToTab("plan")
        nav.assertTopIs("plan")
        nav.assertNoRouteInStack("review")
    }

    @Test
    fun `reachable chain through complete to review then back to plan lands on plan`() {
        // 议事会 tianquan 补强：review 唯一的非 Tab 入口是 CompleteScreen 那一跳，
        // 这是能造出「review 压在 plan 栈之上」的唯一真实可达栈形。
        val nav = newNav()
        nav.navigateToTab("plan")
        nav.navigate("complete")
        nav.navigate("review")
        nav.navigateToTab("profile")
        nav.navigateToTab("plan")
        nav.assertTopIs("plan")
        nav.assertNoRouteInStack("review")
    }

    @Test
    fun `reverse control switching to profile and back does not misfire`() {
        // 反向对照：同样两条链但只切 profile 再返回，断言不误判（区分
        // 「restoreState 恢复别的 tab 保存栈」与「命中错位」两种机制）。
        val nav = newNav()
        nav.navigateToTab("review")
        nav.navigateToTab("profile")
        nav.navigateToTab("plan")
        nav.assertTopIs("plan")
        nav.assertNoRouteInStack("review")
    }

    @Test
    fun `rapid alternating taps always land on last tapped tab`() {
        val nav = newNav()
        nav.navigateToTab("plan")
        nav.navigateToTab("review")
        nav.navigateToTab("plan")
        nav.navigateToTab("review")
        nav.navigateToTab("plan")
        nav.assertTopIs("plan")
        nav.assertNoRouteInStack("review")
    }
}

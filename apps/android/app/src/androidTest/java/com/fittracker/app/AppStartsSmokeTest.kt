package com.fittracker.app

import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.onAllNodesWithText
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/**
 * 启动链路冒烟（instrumented / connectedDebugAndroidTest）。
 *
 * 目的：证明「真机/模拟器上 MainActivity 能被拉起、Compose 主壳能组合渲染、启动分流能落到终态屏」
 * 这条链路活着——**不是**行为回归覆盖（那需要逐屏用例，另行立项）。
 *
 * 启动分流（`SplashScreen` 的 `LaunchedEffect` → `StartupDecision`）：
 * - 未登录 → `login` 屏（文案 `R.string.auth_login_title`，如「欢迎回来」）；
 * - 已登录 → `home` 主壳（底栏 Tab 文案「首页」等，见 `FtRoutes.tabs`）。
 *
 * 两条分支互斥：本用例断言「任一分支必存在（排除空白/首帧未就绪的 vacuous 通过）且二者不同时成立」，
 * 而非只断言某一条分支——因为设备上的登录态不可预知。
 * 注意：底栏 Tab 文案是 `FtRoutes` 里的字面量（不随系统语言变化），登录标题走资源（随语言变化），
 * 故登录标题用 `getString` 取，Tab 文案用字面量。
 */
@RunWith(AndroidJUnit4::class)
class AppStartsSmokeTest {

    @get:Rule
    val rule = createAndroidComposeRule<MainActivity>()

    /** 登录屏标题（本地化资源）。 */
    private val loginTitle: String
        get() = rule.activity.getString(R.string.auth_login_title)

    /** 主壳底栏一等入口文案（`FtRoutes.tabs` 的字面量：home「首页」/ profile「我的」）。 */
    private val shellTabLabels = listOf("首页", "我的")

    private fun countWithText(text: String): Int =
        rule.onAllNodesWithText(text)
            .fetchSemanticsNodes(atLeastOneRootRequired = false)
            .size

    /** 当前是否停在登录屏。 */
    private fun onLoginScreen(): Boolean = countWithText(loginTitle) > 0

    /** 当前是否停在主壳（底栏出现即为主壳已渲染）。 */
    private fun onMainShell(): Boolean = shellTabLabels.any { countWithText(it) > 0 }

    @Test
    fun startupReachesExactlyOneTerminalScreen() {
        // 等启动分流完成：login 与 shell 恰好出现其一（互斥）。超时未达 = 启动链没走通。
        rule.waitUntil(timeoutMillis = 30_000) {
            onLoginScreen() xor onMainShell()
        }
        rule.waitForIdle()

        val login = onLoginScreen()
        val shell = onMainShell()
        assertTrue("启动后必须落到登录页或主壳之一（不能是空白/首帧未就绪）", login || shell)
        assertFalse("登录页与主壳不应同时出现（启动分流互斥）", login && shell)
        assertEquals("终态屏数量应为 1", 1, listOf(login, shell).count { it })
    }

    @Test
    fun terminalScreenIsStableAfterSettling() {
        rule.waitUntil(timeoutMillis = 30_000) {
            onLoginScreen() xor onMainShell()
        }
        rule.waitForIdle()

        // 稳定后仍停留在同一分支，且 Activity 没有因副作用（WorkManager/内容库预热）崩溃退出。
        assertFalse("主 Activity 不应在启动后进入 finishing", rule.activity.isFinishing)
        assertTrue("settle 后终态屏仍应存在", onLoginScreen() xor onMainShell())
    }
}

package com.fittracker.app.ui.screens.review

import androidx.compose.foundation.ScrollState
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.test.junit4.createComposeRule
import com.fittracker.app.ui.FtChromeState
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * 滚动驱动 chrome 收起的契约（Tab 一级路由的滚动位置恢复回归）。
 *
 * 场景来自真实反馈：「回顾页没回到顶部，从其他 tab 切回来，上下会直接隐藏」。
 *
 * 成因有两层：
 * 1. `FtApp` 只在「离开 Tab 帧」时复位 `collapsed`，Tab↔Tab 切回时收起态仍残留
 *    （在回顾页收起后切到 home / plan，底栏同样是隐藏的）；
 * 2. [observeChromeOnScroll] 若从 0 起算首帧，`rememberScrollState` 恢复的中途位置
 *    会被读成一次大幅下滑（`dy = value - 0`），即使复位过也会立刻被重新收起。
 *
 * 本文件钉住第 2 层：用例 1 在旧实现（`var last = 0`）下必红，是这条回归的判别断言。
 * 第 1 层是 `FtApp` 里的一行无条件复位，入口依赖整条 NavHost + ViewModel 链路，
 * 不在此处用组合测试模拟。
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34], qualifiers = "zh-rCN-w390dp-h844dp-mdpi")
class ReviewChromeScrollTest {

    @get:Rule
    val rule = createComposeRule()

    /**
     * 以 [initial] 当作「切回 Tab 时恢复出来的滚动位置」起一层订阅。
     * [FtChromeState] 起始为常驻态，等价于 `FtApp` 在路由变化时已复位。
     */
    private fun observeFrom(initial: Int): Pair<ScrollState, FtChromeState> {
        val state = ScrollState(initial)
        val chrome = FtChromeState()
        rule.setContent {
            LaunchedEffect(state) { observeChromeOnScroll(state, chrome) }
        }
        rule.waitForIdle()
        return state to chrome
    }

    /** 核心回归：恢复的位置不是一次下滑，不能把头部与底栏收起。 */
    @Test
    fun `切回 Tab 时恢复的中途位置不应收起 chrome`() {
        val (_, chrome) = observeFrom(initial = 800)

        assertFalse(
            "rememberScrollState 恢复的滚动位置不应被当作下滑；否则回到回顾页即上下隐藏",
            chrome.collapsed,
        )
    }

    /** 基准取当前值后，真实的下滑仍要能收起（不能修成「永不收起」）。 */
    @Test
    fun `向下滚动越过阈值后收起`() {
        val (state, chrome) = observeFrom(initial = 0)

        runBlocking { state.scrollTo(800) }
        rule.waitForIdle()

        assertTrue("向下浏览时应收起 chrome（底栏滑出、头部收缩）", chrome.collapsed)
    }

    /** 从恢复位置继续下滑，方向判定仍然成立。 */
    @Test
    fun `从恢复位置继续下滑仍可收起`() {
        val (state, chrome) = observeFrom(initial = 800)

        runBlocking { state.scrollTo(860) }
        rule.waitForIdle()

        assertTrue("恢复位置之后的下滑应正常进入浏览态", chrome.collapsed)
    }

    /** 上滑即恢复常驻态。 */
    @Test
    fun `上滑后恢复展开`() {
        val (state, chrome) = observeFrom(initial = 800)

        runBlocking { state.scrollTo(400) }
        rule.waitForIdle()

        assertFalse("向上浏览应恢复头部与底栏", chrome.collapsed)
    }

    /** 回顶必须恢复常驻态（阈值内即归位）。 */
    @Test
    fun `回到顶部恢复展开`() {
        val (state, chrome) = observeFrom(initial = 800)

        runBlocking { state.scrollTo(0) }
        rule.waitForIdle()

        assertFalse("回到顶部必须恢复常驻态", chrome.collapsed)
    }
}

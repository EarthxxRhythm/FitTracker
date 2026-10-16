package com.fittracker.app.ui.screens.review

import androidx.compose.foundation.ScrollState
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * 回顾页骨架「时间尺度工具条固定 + 居中」的布局契约测试。
 *
 * 产品要求（有意偏离原型：原型 `.review-toolbar` 在 `.pane-scroll` 内、靠左）：
 * 1. **固定**——工具条不随卡片滚动而移动（提为滚动区外的固定头）；
 * 2. **居中**——工具条胶囊相对屏幕水平居中（左右边距相等）。
 *
 * 修复前（工具条是滚动 Column 的第一个子元素、`Row.fillMaxWidth` 左对齐）两条都为红。
 * Robolectric 钉 mdpi 视口，1dp = 1px，整数断言无舍入歧义。
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34], qualifiers = "zh-rCN-w390dp-h844dp-mdpi")
class ReviewToolbarPinTest {

    @get:Rule
    val rule = createComposeRule()

    private val viewportW = 390f

    /** 渲染骨架：高的填充体保证内容可滚动，便于断言「滚动后」的姿态。 */
    @Composable
    private fun Scaffold(scrollState: ScrollState) {
        Box(modifier = Modifier.size(viewportW.dp, 844.dp)) {
            ReviewScaffold(
                scale = ReviewScale.WEEK,
                onScale = {},
                scrollState = scrollState,
            ) {
                Box(modifier = Modifier.fillMaxWidth().height(2000.dp))
            }
        }
    }

    private fun yOf(tag: String): Float =
        rule.onNodeWithTag(tag).fetchSemanticsNode().positionInRoot.y

    /** 固定：内容滚到底后，胶囊的 y 与在顶部时一致。 */
    @Test
    fun `向下滚动到底后工具条胶囊位置不变`() {
        lateinit var state: ScrollState
        rule.setContent {
            state = ScrollState(0)
            Scaffold(state)
        }

        val atTop = yOf("review-scale-pill")
        runBlocking { state.scrollTo(state.maxValue) }
        rule.waitForIdle()
        val atBottom = yOf("review-scale-pill")

        assertEquals("滚动后工具条不应移动（固定头）", atTop, atBottom, 0.5f)
    }

    /** 居中：胶囊相对屏幕左右边距相等。 */
    @Test
    fun `工具条胶囊水平居中`() {
        rule.setContent { Scaffold(ScrollState(0)) }

        val node = rule.onNodeWithTag("review-scale-pill").fetchSemanticsNode()
        val left = node.positionInRoot.x
        val right = viewportW - (left + node.size.width)

        assertEquals("工具条应水平居中：left=$left right=$right", left, right, 1.0f)
    }
}

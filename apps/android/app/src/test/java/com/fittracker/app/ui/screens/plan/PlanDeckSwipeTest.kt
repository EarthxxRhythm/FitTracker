package com.fittracker.app.ui.screens.plan

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performTouchInput
import androidx.compose.ui.test.swipeLeft
import androidx.compose.ui.unit.dp
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * 计划页卡片堆的手势契约测试（Robolectric 在 JVM 上真跑组合与指针输入）。
 *
 * 覆盖的回归：手势闭包若捕获**过期**的 `activeIndex`，第一次滑动看似生效，
 * 其后每次滑动都会把索引算回同一个值——表现为「卡片滑出去又弹回原来那张」。
 * 本测试连续左滑两次，要求索引 0 → 1 → 2 单调前进。
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34], qualifiers = "w390dp-h844dp-mdpi")
class PlanDeckSwipeTest {

    @get:Rule
    val rule = createComposeRule()

    private var active = 0

    private fun setDeck(days: List<FtPlanDay> = FtPlanDefaults.days, initial: Int = 0) {
        active = initial
        rule.setContent {
            var index by remember { mutableIntStateOf(initial) }
            Box(modifier = Modifier.size(390.dp, 500.dp)) {
                TodayPlanDeck(
                    days = days,
                    activeIndex = index,
                    onActiveIndexChange = {
                        index = it
                        active = it
                    },
                    modifier = Modifier.fillMaxSize().testTag(TAG),
                )
            }
        }
    }

    @Test
    fun `连续两次左滑每次都前进一张_第二次不回弹`() {
        setDeck()

        rule.onNodeWithTag(TAG).performTouchInput { swipeLeft() }
        rule.waitForIdle()
        assertEquals("第一次左滑应前进到第 2 张", 1, active)

        rule.onNodeWithTag(TAG).performTouchInput { swipeLeft() }
        rule.waitForIdle()
        assertEquals("第二次左滑应再前进到第 3 张（回弹则仍为 1）", 2, active)
    }

    private companion object {
        const val TAG = "plan-deck"
    }
}

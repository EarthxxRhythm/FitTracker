package com.fittracker.app.ui.screens.review

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.size
import androidx.compose.ui.Modifier
import androidx.compose.ui.test.assertHeightIsEqualTo
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.unit.dp
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * 「努力程度」柱区在**组合期**的布局契约测试（第 5 根柱子错位的回归护栏）。
 *
 * 原型 `.effort-bars { height: 96px }` 的一列要同时容纳**柱子 + 6px 间距 + 序号行**，
 * 柱子可用高度只有 96 − 6 − 12 = **78**（同鸿蒙端 `EFFORT_BAR_TRACK_HEIGHT`）。安卓侧原先
 * 用 `fillMaxHeight(percent / 100f)` 按**列高**取百分比：满量程那根 = 96，连同间距(6) 与
 * 序号(12) 把 96 的列撑到 114，flex 收缩反过来挤压柱子与序号——8 根里只有第 5 根是满量程，
 * 于是只有它错位。
 *
 * 纯数学测试对「被撑开后收缩」一无所知（`FtReviewModelTest` 断言的是 barPercents 数值，
 * 修复前后都绿），因此本文件用 Robolectric 在 JVM 上真跑一次组合与测量。
 * 设备配置钉到参考视口 `w390dp-h844dp-mdpi`（mdpi 下 1dp = 1px，整数断言无舍入歧义）。
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34], qualifiers = "w390dp-h844dp-mdpi")
class EffortBarsLayoutTest {

    @get:Rule
    val rule = createComposeRule()

    /** RIR 视图的 barPercents（`FtReviewModel.effort(RIR).barPercents`）。 */
    private val percents = listOf(50, 75, 25, 50, 100, 25, 75, 50)

    private fun setBars() {
        rule.setContent {
            Box(modifier = Modifier.size(390.dp, 200.dp)) {
                EffortBars(
                    percents = percents,
                    labels = percents.indices.map { (it + 1).toString() },
                )
            }
        }
    }

    /** 满量程柱 78 + 间距 6 + 序号 12 = 96，与列高相等——这是「不再错位」的核心不变量。 */
    @Test
    fun `满量程柱加间距加序号恰好占满整列`() {
        setBars()

        // 修复前：满量程柱按列高百分比算得 96，直接把列撑溢出——此断言即红。
        rule.onNodeWithTag("effort-bar-bar-4").assertHeightIsEqualTo(78.dp)
        rule.onNodeWithTag("effort-bar-label-4").assertHeightIsEqualTo(12.dp)
    }

    /** 半量程柱 39（列高 96 下会算成 48）——除满量程外其余柱同样按轨道换算。 */
    @Test
    fun `半量程柱按轨道而非列高换算`() {
        setBars()

        rule.onNodeWithTag("effort-bar-bar-0").assertHeightIsEqualTo(39.dp)
        rule.onNodeWithTag("effort-bar-bar-7").assertHeightIsEqualTo(39.dp)
    }

    /** 柱高换算函数：把轨道百分比落到固定值，供列内柱子/间距/序号三分而不互相挤压。 */
    @Test
    fun `柱高换算函数与轨道口径一致`() {
        assertEquals(FtReviewModel.EFFORT_BAR_TRACK_HEIGHT, 96 - 6 - 12)
        assertEquals(78f, FtReviewModel.effortBarHeight(100), 1e-3f)
        assertEquals(39f, FtReviewModel.effortBarHeight(50), 1e-3f)
        assertEquals(58.5f, FtReviewModel.effortBarHeight(75), 1e-3f)
        assertEquals(6.24f, FtReviewModel.effortBarHeight(8), 1e-3f)
    }
}

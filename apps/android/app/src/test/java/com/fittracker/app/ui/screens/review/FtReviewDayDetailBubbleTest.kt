package com.fittracker.app.ui.screens.review

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.unit.dp
import androidx.test.core.app.ApplicationProvider
import com.fittracker.app.R
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * 月历热力格「当天详情」气泡的**用户级验收**（Robolectric 真跑一次组合）。
 *
 * 为什么需要本文件：`FtReviewModelTest` 只算摘要数值，`FtReviewStringsTest` 只断言文案，
 * 两者都碰不到「用户点热力格后组合这一层气泡会不会崩」。缺陷正是发生在组合期：
 * 标题资源 `review_day_detail_title` 是三参（月/日/周几），调用点只传两参（日/周几），
 * `String.format` 抛 `MissingFormatArgumentException`，界面直接闪退。本文件渲染真实
 * 气泡内容把这条契约钉住——只传两参的形态在这里必然抛异常。
 *
 * 测的是气泡内容层（[DayDetailBubble]）而不是外层 [DayDetailPopup]：后者是窗口级
 * [androidx.compose.ui.window.Popup]，Robolectric 对独立窗口的语义树支持不稳定；
 * 内容层与浮层机制无关，三参标题这条契约在它上面就已覆盖。
 *
 * 文案期望一律经 `context.getString` 取，不写中文字面量（Robolectric 渲染语言依赖
 * 配置限定符，绑定资源 ID 才与语言无关；逐字真值由 `FtReviewStringsTest` 保证）。
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34], qualifiers = "w390dp-h900dp-mdpi")
class FtReviewDayDetailBubbleTest {

    @get:Rule
    val rule = createComposeRule()

    private val context = ApplicationProvider.getApplicationContext<android.content.Context>()

    private fun text(resId: Int): String = context.getString(resId)

    private val trainedDay = DaySummary(
        day = 16,
        durationMinutes = 42,
        exerciseCount = 3,
        setCount = 12,
        volumeKg = 4200.0,
        hasSession = true,
    )

    private val restDay = DaySummary(
        day = 17,
        durationMinutes = 0,
        exerciseCount = 0,
        setCount = 0,
        volumeKg = 0.0,
        hasSession = false,
    )

    /** 用户点热力格 → 气泡出现且有训练记录时显示标题与四个字段。 */
    @Test
    fun `当天详情气泡渲染不崩溃并显示标题与四个字段`() {
        rule.setContent {
            DayDetailBubble(
                summary = trainedDay,
                month = 10,
                weekdayLabel = "周五",
                above = false,
                arrowLeft = 100.dp,
            )
        }

        // 标题槽位是「月 / 日 / 周几」三参：缺月份这一格时组合期就抛 MissingFormatArgumentException。
        rule.onAllNodesWithText(context.getString(R.string.review_day_detail_title, 10, trainedDay.day, "周五"))[0]
            .assertIsDisplayed()
        rule.onAllNodesWithText(text(R.string.review_day_detail_duration))[0].assertIsDisplayed()
        rule.onAllNodesWithText(text(R.string.review_day_detail_exercises))[0].assertIsDisplayed()
        rule.onAllNodesWithText(text(R.string.review_day_detail_sets))[0].assertIsDisplayed()
        rule.onAllNodesWithText(text(R.string.review_day_detail_volume))[0].assertIsDisplayed()
    }

    /** 无训练日走空态分支，不再渲染四个字段。 */
    @Test
    fun `无训练日气泡显示空态文案`() {
        rule.setContent {
            DayDetailBubble(
                summary = restDay,
                month = 10,
                weekdayLabel = "周六",
                above = true,
                arrowLeft = 40.dp,
            )
        }

        rule.onAllNodesWithText(text(R.string.review_day_detail_empty))[0].assertIsDisplayed()
    }
}

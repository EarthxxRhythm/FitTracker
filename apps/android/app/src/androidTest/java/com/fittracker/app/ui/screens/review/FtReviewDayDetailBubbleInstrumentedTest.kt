package com.fittracker.app.ui.screens.review

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.unit.dp
import androidx.test.platform.app.InstrumentationRegistry
import com.fittracker.app.R
import org.junit.Rule
import org.junit.Test

/**
 * 月历热力格「当天详情」气泡的**真机验收**：在设备 Runtime 上真渲染一次气泡。
 *
 * 为什么另立一份（与 JVM 版 `FtReviewDayDetailBubbleTest` 并存）：JVM 侧用 Robolectric，
 * 真机侧要覆盖 Android 真实 `Resources`/`String.format` 与 Compose 组合路径；同时这也是
 * 本机唯一能自动触达用户路径的通道——ColorOS 会静默丢弃 `adb shell input tap`（实测：Home 键
 * 生效、tap 三处坐标全部无反应），而 Compose 语义动作在 app 进程内派发，不受该策略影响。
 *
 * 测内容层（[DayDetailBubble]）而不是外层 [DayDetailPopup]：后者是窗口级 Popup，
 * 在 instrumentation 下同样能渲染，但气泡内容与浮层机制无关，三参标题这条契约在内容层即可覆盖。
 *
 * 缺陷背景：标题资源 `review_day_detail_title` 是三参（月/日/周几），调用点曾只传两参，
 * `%d` 吃到星期字符串 → `IllegalFormatConversionException` → 用户点热力格即闪退。
 */
class FtReviewDayDetailBubbleInstrumentedTest {

    @get:Rule
    val rule = createComposeRule()

    private val context = InstrumentationRegistry.getInstrumentation().targetContext

    private val trainedDay = DaySummary(
        day = 16,
        durationMinutes = 42,
        exerciseCount = 3,
        setCount = 12,
        volumeKg = 4200.0,
        hasSession = true,
    )

    @Test
    fun 当天详情气泡在设备上渲染不崩溃() {
        rule.setContent {
            DayDetailBubble(
                summary = trainedDay,
                month = 10,
                weekdayLabel = "周五",
                above = false,
                arrowLeft = 100.dp,
            )
        }

        val title = context.getString(R.string.review_day_detail_title, 10, trainedDay.day, "周五")
        rule.onAllNodesWithText(title)[0].assertIsDisplayed()
        rule.onAllNodesWithText(context.getString(R.string.review_day_detail_duration))[0].assertIsDisplayed()
        rule.onAllNodesWithText(context.getString(R.string.review_day_detail_volume))[0].assertIsDisplayed()
    }
}

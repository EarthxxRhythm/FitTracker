package com.fittracker.app.ui.screens.complete

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onAllNodesWithContentDescription
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.performClick
import androidx.test.core.app.ApplicationProvider
import com.fittracker.app.R
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * 完成页 RPE 采集的**用户级行为验收**（Robolectric 真跑一次组合与交互）。
 *
 * 为什么需要本文件：`FtCompleteModelTest` 只断言纯逻辑（选项表 / 状态选择 / 写回守卫），
 * 对「用户能否看到这张卡、能否点、点了有没有反应」一无所知——那是 UI 层的契约。
 * 本文件在 JVM 上真实渲染完成屏，模拟用户点击，断言可观察结果。
 *
 * 验收面（对应 `双端字面值数据改为真数据` Wave 2-W2-3）：
 * 1. 完成页出现「本次训练强度」卡与副文案
 * 2. 未评价时右侧状态显示「未评价」
 * 3. 10 个档位格子全部渲染且各带无障碍描述
 * 4. 点选档位后该格变为选中态，其余保持未选中（单选语义）
 *
 * **文案来源**：断言不写中文字面量，改为经 `context.getString(资源ID)` 解析——
 * Robolectric 的 locale 限定符在此环境不生效（实测渲染为 en），绑定字面量会让测试
 * 依赖运行环境语言；绑定资源 ID 则与语言无关，中文逐字真值由 `FtCompleteStringsTest`
 * （zh 限定符生效的那一层）保证。
 *
 * 视口取 `h1200dp`：完成屏内容（Hero + StreakCard + RpeCard）在 844dp 参考视口下
 * RPE 卡落在可视区外（节点存在但 `isDisplayed` 为假）。抬高视口让整屏内容一次性进入
 * 可视区——本文件验的是卡片与交互，不是滚动行为。
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34], qualifiers = "w390dp-h1200dp-mdpi")
class CompleteRpeCardTest {

    @get:Rule
    val rule = createComposeRule()

    private val context = ApplicationProvider.getApplicationContext<android.content.Context>()

    private fun text(resId: Int): String = context.getString(resId)

    /** 档位格子的无障碍描述（与 UI 层 `complete_a11y_rpe_option` 的拼装一致）。 */
    private fun optionA11y(level: Int, selected: Boolean): String = context.getString(
        R.string.complete_a11y_rpe_option,
        level,
        context.getString(
            if (selected) R.string.complete_a11y_rpe_selected
            else R.string.complete_a11y_rpe_unselected,
        ),
    )

    private fun setCompleteScreen() {
        rule.setContent {
            CompleteScreen(onNavigate = {})
        }
    }

    /** 用户进入完成页 → 看到 RPE 卡标题与副文案。 */
    @Test
    fun `完成页显示本次训练强度卡与副文案`() {
        setCompleteScreen()

        rule.onAllNodesWithText(text(FtCompleteModel.RPE_TITLE_RES))[0].assertIsDisplayed()
        rule.onAllNodesWithText(text(FtCompleteModel.RPE_HINT_RES))[0].assertIsDisplayed()
    }

    /** 用户初次进入（无历史会话）→ 状态显示「未评价」。 */
    @Test
    fun `未评价态显示未评价文案`() {
        setCompleteScreen()

        rule.onAllNodesWithText(text(FtCompleteModel.RPE_UNRATED_RES))[0].assertIsDisplayed()
    }

    /** 10 个档位格子全部渲染，且各带无障碍描述（可被读屏识别）。 */
    @Test
    fun `十个档位格子全部渲染且带无障碍描述`() {
        setCompleteScreen()

        for (level in 1..10) {
            rule.onAllNodesWithContentDescription(optionA11y(level, selected = false))[0]
                .assertIsDisplayed()
        }
    }

    /** 用户点选第 7 档 → 该档变为选中态（无障碍描述随之变化）。 */
    @Test
    fun `点选档位后该格子变为选中态`() {
        setCompleteScreen()

        rule.onAllNodesWithContentDescription(optionA11y(7, selected = false))[0].performClick()

        rule.onAllNodesWithContentDescription(optionA11y(7, selected = true))[0].assertIsDisplayed()
    }

    /** 点选后其他档位保持未选中——选中是单选语义，不是多选。 */
    @Test
    fun `点选档位为单选_其余保持未选中`() {
        setCompleteScreen()

        rule.onAllNodesWithContentDescription(optionA11y(7, selected = false))[0].performClick()

        rule.onAllNodesWithContentDescription(optionA11y(1, selected = false))[0].assertIsDisplayed()
        rule.onAllNodesWithContentDescription(optionA11y(10, selected = false))[0].assertIsDisplayed()
    }
}

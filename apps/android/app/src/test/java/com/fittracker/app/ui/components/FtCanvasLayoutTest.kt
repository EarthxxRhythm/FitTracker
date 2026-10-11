package com.fittracker.app.ui.components

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.size
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.test.assertHeightIsEqualTo
import androidx.compose.ui.test.assertPositionInRootIsEqualTo
import androidx.compose.ui.test.assertWidthIsEqualTo
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.unit.dp
import com.fittracker.app.nav.FtCanvasKind
import com.fittracker.app.nav.FtCanvasSpec
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * 缩放画布在**组合期**的布局契约测试（坑 #27 的回归护栏）。
 *
 * `FtCanvasTest` 只覆盖 `FtCanvasSpec` 的换算数学，而坑 #27 恰恰不在数学里：
 * 那句 `Modifier.size(430.dp, 900.dp)` 的**意图**是对的、算出来的 `scale` 也是对的，
 * 坏在 Android 的布局约束把子节点目标尺寸夹到了父级可用范围内——数学测试对
 * 「被夹」这件事一无所知，所以修复前后它都是 12 项全绿。
 *
 * 本文件用 Robolectric 在 JVM 上真跑一次组合与测量，断言两件事：
 * 1. **尺寸**：内容按设计空间（430×900 / 430×930.56）测量，而不是被夹到可用视口；
 * 2. **摆放**：在参考视口下内容锚在可用区左上（`horizontalInset` 为 0）。
 *
 * **尺寸断言的判别力已用真实回归验证**：把 `FtCanvas` 退回 `Modifier.size(...)` 后本文件立刻
 * 变红，报 `Actual width is 390.0.dp, expected 430.0.dp` —— 正是坑 #27 的病理
 * （设计空间被夹到可用视口）。摆放断言固化的是另一条契约：参考视口下
 * `horizontalInset` 为 0、画布锚在可用区左上——防止将来给画布引入偏移。
 * （注：未验证摆放断言能抓住 `requiredSize` 那种改法；实测它在设备上的 +21dp 偏移
 * 另有来源，尚未定位，不要把它当成已覆盖。）
 *
 * ⚠ 设备配置**必须钉到参考视口** `w390dp-h844dp`：Robolectric 默认屏比参考视口小，
 * 画布会转成高度驱动、按设计产生非零 `horizontalInset`（实测默认配置下左偏
 * 48.0dp / 51.0dp，正是两个设计高度各自的 inset），此时「左上」断言会假红。
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34], qualifiers = "w390dp-h844dp-mdpi")
class FtCanvasLayoutTest {

    @get:Rule
    val rule = createComposeRule()

    /** 固定 390×844 的可用视口（参考视口），内容用 testTag 暴露出来供断言。 */
    private fun setScaledCanvas(designW: Float, designH: Float) {
        rule.setContent {
            Box(modifier = Modifier.size(FtCanvasSpec.REF_W.dp, FtCanvasSpec.REF_H.dp)) {
                FtCanvas(kind = FtCanvasKind.Scaled, designW = designW, designH = designH) {
                    Box(modifier = Modifier.fillMaxSize().testTag(TAG))
                }
            }
        }
    }

    @Test
    fun `缩放画布的内容按设计空间测量_不被夹到可用视口`() {
        setScaledCanvas(430f, 900f)

        // 若退回 Modifier.size(...)，可用区 390×844 会把它夹成 390×844 —— 此断言即红。
        rule.onNodeWithTag(TAG).assertWidthIsEqualTo(430.dp)
        rule.onNodeWithTag(TAG).assertHeightIsEqualTo(900.dp)
    }

    @Test
    fun `缩放画布锚在可用区左上_内容不被父级摆放挪位`() {
        setScaledCanvas(430f, 900f)

        // 若改用 Modifier.requiredSize(...)，尺寸虽对，但节点超出父级约束后会被摆放挪走
        // （实测整体右移约 21dp）—— 此断言即红。
        rule.onNodeWithTag(TAG).assertPositionInRootIsEqualTo(0.dp, 0.dp)
    }

    @Test
    fun `complete 屏的设计高度同样按设计空间测量`() {
        setScaledCanvas(430f, FtCanvasSpec.DESIGN_H_COMPLETE)

        rule.onNodeWithTag(TAG).assertWidthIsEqualTo(430.dp)
        rule.onNodeWithTag(TAG).assertHeightIsEqualTo(FtCanvasSpec.DESIGN_H_COMPLETE.dp)
        rule.onNodeWithTag(TAG).assertPositionInRootIsEqualTo(0.dp, 0.dp)
    }

    private companion object {
        const val TAG = "canvas-content"
    }
}

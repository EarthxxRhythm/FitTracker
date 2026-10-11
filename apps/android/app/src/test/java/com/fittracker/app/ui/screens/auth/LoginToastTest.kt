package com.fittracker.app.ui.screens.auth

import androidx.compose.ui.test.assertCountEquals
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * 登录屏「提示走浮层」的契约测试。
 *
 * 覆盖的回归：发码 / 提交的提示此前渲染成表单内的内联文本行（`phoneHint` / `phoneMessage`），
 * 出现时会顶动表单、把「登录」按钮推走——改为统一走壳层浮层通道 `onToast`。
 * 断言两件事：① 提示确实经 `onToast` 送出；② 表单内不再残留同名内联行
 * （「请输入手机号」在输入框占位符里本就有一份，故用**节点计数**=1 判残留）。
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34], qualifiers = "zh-rCN-w390dp-h844dp-mdpi")
class LoginToastTest {

    @get:Rule
    val rule = createComposeRule()

    private val toasts = mutableListOf<String>()

    private fun setLogin() {
        rule.setContent {
            LoginScreen(
                onSubmitSuccess = { _, _ -> },
                onPhoneCodeSuccess = { _, _ -> },
                onNavigate = {},
                onToast = { toasts += it },
            )
        }
    }

    @Test
    fun `空手机号点获取验证码_提示走浮层且表单内无残留内联行`() {
        setLogin()

        rule.onNodeWithText("获取验证码").performClick()
        rule.waitForIdle()

        assertEquals(listOf("请输入手机号"), toasts)
        // 只有输入框占位符那一份；内联提示行已移除
        rule.onAllNodesWithText("请输入手机号").assertCountEquals(1)
    }
}

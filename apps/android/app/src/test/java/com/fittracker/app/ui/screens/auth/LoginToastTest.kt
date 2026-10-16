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
 * 登录屏「字段级校验走内联错误行、非字段级提示走浮层」的契约测试。
 *
 * 历史（第一版）：字段级校验（如空手机号）此前也走壳层浮层 `onToast`，本测试当时断言
 * 「提示确实经 onToast 送出」+「表单内无同名内联行」。
 *
 * 现状（本次变更）：**字段级**错误回到字段下方的内联错误行——与鸿蒙 `PencilLoginPage`
 * 的 `phoneError` / `codeError` 渲染路径、以及安卓注册页 `RegisterScreen` 的既有做法统一；
 * **非字段级**提示（发码成功、服务端失败、协议未勾选）继续走浮层。
 * 故本测试相应改写为双向契约：
 * ① 字段级错误**不**走 onToast，且在表单内以内联行呈现；
 * ② 非字段级提示仍**只**走 onToast。
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

    /**
     * 字段级错误：空手机号点「获取验证码」→ 内联错误行出现在手机号字段下方。
     *
     * 「请输入手机号」因此有**两处**同名文本：输入框占位符 + 错误行，故断言计数 = 2
     * （第一版断言 1，正是因为它断言内联行不存在）。
     */
    @Test
    fun `空手机号点获取验证码_错误走内联行且不经浮层`() {
        setLogin()

        rule.onNodeWithText("获取验证码").performClick()
        rule.waitForIdle()

        // ① 字段级错误不再经浮层
        assertEquals(emptyList<String>(), toasts)
        // ② 内联错误行已呈现：占位符 1 份 + 错误行 1 份
        rule.onAllNodesWithText("请输入手机号").assertCountEquals(2)
    }

    /**
     * 非字段级提示：协议未勾选时提交 → 仍走浮层（不落进任何字段下方）。
     *
     * 这条同时锁住「字段校验不吞掉协议提示」——提交时协议先判（源 L106-109），
     * 未勾选则直接 return，因此不会同时产生字段错误。
     */
    @Test
    fun `协议未勾选提交_提示仍走浮层`() {
        setLogin()

        rule.onNodeWithText("登录").performClick()
        rule.waitForIdle()

        assertEquals(listOf("请先阅读并同意用户协议与隐私政策"), toasts)
    }
}

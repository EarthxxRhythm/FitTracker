package com.fittracker.app.ui.screens.auth

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import com.fittracker.app.R
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * 账号表单校验的契约测试。
 *
 * 断言的期望文案**逐字取自原型** `fittracker-auth.html` 的 `REQUIRED_MSG` 与 `validate()`
 * （该文件 L~640-700 的内联脚本），不得改写措辞——屏内错误行是与原型逐字节比对的。
 *
 * Wave 7 i18n：错误文案已外置为 `values/strings_auth.xml` 资源（模型层只产出 [AuthError]
 * 资源坐标）；断言改为「**资源值 vs 期望中文**」逐字对比，口径不弱化。
 *
 * `qualifiers = "zh-rCN"` 取 `values/` 中文真源——不钉区域限定符时 Robolectric 默认走 en 资源。
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34], qualifiers = "zh-rCN")
class AuthValidationTest {

    private val context: Context get() = ApplicationProvider.getApplicationContext()

    /** 解析一条错误为最终文案（含参文案走 `getString(resId, args)` 插值）。 */
    private fun message(error: AuthError?): String? = error?.let {
        if (it.args.isEmpty()) {
            context.getString(it.resId)
        } else {
            context.getString(it.resId, *it.args.toTypedArray())
        }
    }

    // ── 登录表单 ──────────────────────────────────────────────

    @Test
    fun `登录表单空值逐字报必填`() {
        val errors = validateAuthForm(AuthForms.login, emptyMap())

        assertEquals("请输入邮箱", message(errors[AuthField.Account]))
        assertEquals("请输入密码", message(errors[AuthField.Password]))
    }

    @Test
    fun `纯空白视同未填`() {
        val errors = validateAuthForm(
            AuthForms.login,
            mapOf(AuthField.Account to "   ", AuthField.Password to "\t"),
        )

        assertEquals("请输入邮箱", message(errors[AuthField.Account]))
        assertEquals("请输入密码", message(errors[AuthField.Password]))
    }

    @Test
    fun `登录表单填全即无错`() {
        val errors = validateAuthForm(
            AuthForms.login,
            mapOf(AuthField.Account to "13800138000", AuthField.Password to "abcd1234"),
        )

        assertTrue("期望无错，实际 $errors", errors.isEmpty())
    }

    // ── 注册表单 · 手机号 ─────────────────────────────────────

    @Test
    fun `注册手机号格式非法报原型文案`() {
        val errors = validateAuthForm(AuthForms.register, registerValues(phone = "12345"))

        assertEquals("请输入正确的手机号", message(errors[AuthField.Phone]))
    }

    @Test
    fun `注册手机号为空报必填而非格式错`() {
        val errors = validateAuthForm(AuthForms.register, registerValues(phone = ""))

        assertEquals("请输入手机号", message(errors[AuthField.Phone]))
    }

    @Test
    fun `注册手机号合法通过`() {
        val errors = validateAuthForm(AuthForms.register, registerValues(phone = "13800138000"))

        assertNull(errors[AuthField.Phone])
    }

    // ── 注册表单 · 密码 ───────────────────────────────────────

    @Test
    fun `密码不足 8 位报原型文案`() {
        val errors = validateAuthForm(
            AuthForms.register,
            registerValues(password = "abcd123", confirm = "abcd123"),
        )

        assertEquals("密码至少 8 位", message(errors[AuthField.RegPassword]))
    }

    @Test
    fun `密码恰为 8 位通过`() {
        val errors = validateAuthForm(
            AuthForms.register,
            registerValues(password = "abcd1234", confirm = "abcd1234"),
        )

        assertNull(errors[AuthField.RegPassword])
    }

    @Test
    fun `密码为空报必填而非位数错`() {
        val errors = validateAuthForm(AuthForms.register, registerValues(password = "", confirm = ""))

        assertEquals("请输入密码", message(errors[AuthField.RegPassword]))
        assertEquals("请再次输入密码", message(errors[AuthField.Confirm]))
    }

    @Test
    fun `两次密码不一致报原型文案`() {
        val errors = validateAuthForm(
            AuthForms.register,
            registerValues(password = "abcd1234", confirm = "abcd9999"),
        )

        assertEquals("两次输入的密码不一致", message(errors[AuthField.Confirm]))
    }

    /**
     * 保真原型 `val !== target.value` 的比较口径：当前字段取 **trim 后**的值，
     * 目标字段取 **原始值**（未 trim）。故仅目标字段带尾空格时判定为不一致。
     */
    @Test
    fun `确认密码与目标字段按原样比较`() {
        val errors = validateAuthForm(
            AuthForms.register,
            registerValues(password = "abcd1234 ", confirm = "abcd1234"),
        )

        assertEquals("两次输入的密码不一致", message(errors[AuthField.Confirm]))
    }

    // ── 整体 ──────────────────────────────────────────────────

    @Test
    fun `合法注册表单无错`() {
        val errors = validateAuthForm(AuthForms.register, registerValues())

        assertTrue("期望无错，实际 $errors", errors.isEmpty())
    }

    @Test
    fun `错误只覆盖出错字段`() {
        val errors = validateAuthForm(AuthForms.register, registerValues(phone = "12345"))

        assertEquals(setOf(AuthField.Phone), errors.keys)
    }

    /** English 资源生效（`values-en/strings_auth.xml`）——方法级区域限定符覆盖类级 `zh-rCN`。 */
    @Test
    @Config(sdk = [34], qualifiers = "en-rUS")
    fun `英文资源在 en 区域生效`() {
        assertEquals("Enter your email", context.getString(R.string.auth_error_required_email))
        assertEquals(
            "Password must be at least 8 characters",
            context.getString(R.string.auth_error_password_min_length, 8),
        )
    }

    /** 全字段合法的注册值，按需覆盖单项。 */
    private fun registerValues(
        nickname: String = "小明",
        phone: String = "13800138000",
        password: String = "abcd1234",
        confirm: String = "abcd1234",
    ): Map<AuthField, String> = mapOf(
        AuthField.Nickname to nickname,
        AuthField.Phone to phone,
        AuthField.RegPassword to password,
        AuthField.Confirm to confirm,
    )
}

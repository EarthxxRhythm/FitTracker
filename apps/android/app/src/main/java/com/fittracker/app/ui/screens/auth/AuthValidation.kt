package com.fittracker.app.ui.screens.auth

import androidx.annotation.StringRes
import com.fittracker.app.R

/**
 * 账号表单的字段标识与校验规则。
 *
 * 规格源：原型 `design/06_prototype_redraw/src/fittracker-auth.html`
 * 内联脚本 `validate()`（L742-785）与 `REQUIRED_MSG`（L713-720）。
 *
 * 本层刻意做成**无 Compose 依赖的纯逻辑**：原型的 `validate()` 是命令式 DOM 代码，
 * 若把规则直接写进 Composable 就无法单测——而这些文案是与原型**逐字节比对**的，
 * 正是最需要被测试钉住的部分。UI 层只负责把 [validateAuthForm] 的结果映射到错误行。
 */
enum class AuthField(
    /** 原型 field 上的 `data-field` 值（L568 / L576 / L648 / L656 / L664 / L676）。 */
    val key: String,
) {
    Account("account"),
    Password("password"),
    Nickname("nickname"),
    Phone("phone"),
    RegPassword("regpassword"),
    Confirm("confirm"),
}

/**
 * 单字段的校验规则，逐项对应原型 field 上的 `data-*` 属性：
 *
 * | 原型属性 | 本类字段 |
 * |---|---|
 * | `data-required`（L568 等） | [required] |
 * | `data-phone`（L656） | [phone] |
 * | `data-min="8"`（L664） | [minLength] |
 * | `data-match="regpassword"`（L676） | [match] |
 */
data class AuthFieldSpec(
    val field: AuthField,
    val required: Boolean = false,
    val phone: Boolean = false,
    val minLength: Int? = null,
    val match: AuthField? = null,
)

/**
 * 两张表单的字段规格。
 *
 * 登录表单 `data-form="login"`（L566-604）：account + password，均 `data-required`。
 * 注册表单 `data-form="register"`（L646-694）：nickname + phone + regpassword(min 8) + confirm(match)。
 */
object AuthForms {

    val login: List<AuthFieldSpec> = listOf(
        AuthFieldSpec(AuthField.Account, required = true),
        AuthFieldSpec(AuthField.Password, required = true),
    )

    val register: List<AuthFieldSpec> = listOf(
        AuthFieldSpec(AuthField.Nickname, required = true),
        AuthFieldSpec(AuthField.Phone, required = true, phone = true),
        AuthFieldSpec(AuthField.RegPassword, required = true, minLength = 8),
        AuthFieldSpec(AuthField.Confirm, required = true, match = AuthField.RegPassword),
    )
}

/** 手机号：原型 `^1[3-9]\d{9}$`（L755）。 */
private val PhonePattern = Regex("^1[3-9]\\d{9}$")

/**
 * 兼容数字型 View：手机号 11 位，故输入上限取 11（原型 `maxlength="11"`，L659）。
 */
const val AUTH_PHONE_MAX_LENGTH: Int = 11

/**
 * 一条校验错误：文案**资源坐标**（资源 ID + 插值参数）。
 *
 * 模型层不持有 `Context`（保持纯逻辑、可单测），故只产出资源坐标；
 * 插值由 UI 层 `context.getString(resId, *args)` 完成（helper 见 `AuthComponents.resolveText`）。
 */
data class AuthError(@StringRes val resId: Int, val args: List<Any> = emptyList())

/**
 * 校验整张表单，返回「出错字段 → 错误资源」；无错字段不出现在结果里。
 *
 * 逐字平移原型 `validate()` 的判定链（L742-785）——**分支顺序即优先级**：
 * 必填未过时不再报格式/位数/一致性错（例如手机号为空给「请输入手机号」，
 * 而非「请输入正确的手机号」）。
 *
 * 两处刻意的口径保真：
 * 1. 取值一律 `trim()` 后判定（原型 `input.value.trim()`，L748）；
 * 2. `data-match` 比较的是**目标字段的原始值**、不是 trim 后的值
 *    （原型 `val !== target.value`，L761），故目标带首尾空白时判为不一致。
 *
 * 文案外置（Wave 7 i18n）：错误文案改为资源 ID（中文真源 `values/strings_auth.xml`），
 * 模型层不再出现文案字面量。
 */
fun validateAuthForm(
    specs: List<AuthFieldSpec>,
    values: Map<AuthField, String>,
): Map<AuthField, AuthError> {
    val errors = LinkedHashMap<AuthField, AuthError>()

    for (spec in specs) {
        val trimmed = values[spec.field].orEmpty().trim()
        val message: AuthError? = when {
            spec.required && trimmed.isEmpty() -> AuthError(requiredMessageRes(spec.field))

            trimmed.isNotEmpty() && spec.phone && !PhonePattern.matches(trimmed) ->
                AuthError(R.string.auth_error_phone_invalid)

            trimmed.isNotEmpty() && spec.minLength != null && trimmed.length < spec.minLength ->
                AuthError(R.string.auth_error_password_min_length, listOf(spec.minLength))

            trimmed.isNotEmpty() && spec.match != null && trimmed != values[spec.match].orEmpty() ->
                AuthError(R.string.auth_error_password_mismatch)

            else -> null
        }
        if (message != null) {
            errors[spec.field] = message
        }
    }

    return errors
}

/**
 * 必填未过时的文案资源，逐字取自原型 `REQUIRED_MSG`（L713-720）；
 * 规格里没有的字段回落「此项为必填」对应的 `auth_error_required_*` 兜底（原型 L754 的
 * `|| '此项为必填'`，安卓侧仅覆盖已有字段）。
 */
private fun requiredMessageRes(field: AuthField): Int = when (field) {
    AuthField.Account -> R.string.auth_error_required_email
    AuthField.Password -> R.string.auth_error_required_password
    AuthField.Nickname -> R.string.auth_error_required_nickname
    AuthField.Phone -> R.string.auth_error_required_phone
    AuthField.RegPassword -> R.string.auth_error_required_password
    AuthField.Confirm -> R.string.auth_error_required_confirm
}

/**
 * 协议未勾选时的提示（原型 L779）。它与字段错误不同——不落在字段下方，
 * 而是走 `.auth-toast` 浮层，故不进 [validateAuthForm] 的返回值。
 */
@StringRes
val AUTH_AGREE_TOAST: Int = R.string.auth_toast_agree_required

/** 提交成功后的浮层文案（原型 L812：`isLogin ? '登录成功 · 原型演示' : '注册成功 · 原型演示'`）。 */
@StringRes
val AUTH_LOGIN_SUCCESS_TOAST: Int = R.string.auth_toast_login_success
@StringRes
val AUTH_REGISTER_SUCCESS_TOAST: Int = R.string.auth_toast_register_success

/**
 * 二级入口的轻量反馈文案（原型 `bindToast` 绑定，L827-831；协议链接见 L834-839）。
 *
 * 「跳转到注册页 / 跳转到登录页」两条（L828-829）**未**列入：它们在原型交互壳里
 * 被 `ft-stage.js` 捕获阶段的监听改写成**真实导航**（`window.FT_APP.routes`，L864），
 * Android 侧同样按导航实现，不弹提示。
 */
@StringRes
val AUTH_FORGOT_TOAST: Int = R.string.auth_toast_forgot
@StringRes
val AUTH_WECHAT_TOAST: Int = R.string.auth_toast_wechat
@StringRes
val AUTH_APPLE_TOAST: Int = R.string.auth_toast_apple
@StringRes
val AUTH_AGREEMENT_TOAST: Int = R.string.auth_toast_agreement

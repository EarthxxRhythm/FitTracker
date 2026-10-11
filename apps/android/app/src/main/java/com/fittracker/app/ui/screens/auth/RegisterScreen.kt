package com.fittracker.app.ui.screens.auth

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalResources
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import com.fittracker.app.R
import com.fittracker.app.ui.components.clickableNoRipple
import com.fittracker.app.ui.theme.FtColor
import com.fittracker.app.ui.theme.FtType

/**
 * 注册屏（原型 `fittracker-auth.html` 的 `screen-register` 帧，L630-700）。
 *
 * 画布口径与坐标约定同 [LoginScreen]：430×900 设计空间 × `scale(0.90698)`。
 *
 * 版式来源（原型标记行号）：`.auth-brand` L635 · `.auth-head` L640-645 ·
 * `form[data-form=register]` L646-694 · `.agree` L688-691 · `cta-register` L693 ·
 * `.auth-switch` L696-698。
 *
 * 提交判定顺序保真原型 `validate()` + 提交处理器（L742-816）：
 * 字段错误与协议勾选**并行判定**（协议未勾时字段错误同样照常显示，只是额外弹浮层），
 * 二者皆过才提交成功。
 */
@Composable
fun RegisterScreen(
    onSubmitSuccess: (account: String, password: String, nickname: String) -> Unit,
    onNavigate: (String) -> Unit,
    onToast: (String) -> Unit,
    modifier: Modifier = Modifier,
) {
    val context = LocalContext.current
    val resources = LocalResources.current
    var nickname by remember { mutableStateOf("") }
    var phone by remember { mutableStateOf("") }
    var password by remember { mutableStateOf("") }
    var confirm by remember { mutableStateOf("") }
    var revealPassword by remember { mutableStateOf(false) }
    var revealConfirm by remember { mutableStateOf(false) }
    var agreed by remember { mutableStateOf(false) }
    var errors by remember { mutableStateOf(emptyMap<AuthField, AuthError>()) }

    AuthPage(modifier = modifier) {
        AuthBrand()
        AuthHead(
            eyebrow = stringResource(R.string.auth_register_eyebrow),
            title = stringResource(R.string.auth_register_title),
            subtitle = stringResource(R.string.auth_register_subtitle),
        )

        Column(
            modifier = Modifier.fillMaxWidth(),
            verticalArrangement = Arrangement.spacedBy(14.dp), // `.auth-form` gap: 14px
        ) {
            AuthField(
                label = stringResource(R.string.auth_field_nickname),
                value = nickname,
                onValueChange = { nickname = it; errors = errors - AuthField.Nickname },
                placeholder = stringResource(R.string.auth_placeholder_nickname),
                error = errors[AuthField.Nickname]?.resolveText(context),
            )
            AuthField(
                label = stringResource(R.string.auth_field_phone),
                value = phone,
                onValueChange = { phone = it; errors = errors - AuthField.Phone },
                placeholder = stringResource(R.string.auth_placeholder_phone),
                error = errors[AuthField.Phone]?.resolveText(context),
                keyboardType = KeyboardType.Phone,
                maxLength = AUTH_PHONE_MAX_LENGTH, // 原型 maxlength="11"（L659）
            )
            AuthField(
                label = stringResource(R.string.auth_field_password),
                value = password,
                onValueChange = { password = it; errors = errors - AuthField.RegPassword },
                placeholder = stringResource(R.string.auth_placeholder_register_password),
                error = errors[AuthField.RegPassword]?.resolveText(context),
                isPassword = true,
                revealed = revealPassword,
                onToggleReveal = { revealPassword = !revealPassword },
            )
            AuthField(
                label = stringResource(R.string.auth_field_confirm_password),
                value = confirm,
                onValueChange = { confirm = it; errors = errors - AuthField.Confirm },
                placeholder = stringResource(R.string.auth_placeholder_confirm_password),
                error = errors[AuthField.Confirm]?.resolveText(context),
                isPassword = true,
                revealed = revealConfirm,
                onToggleReveal = { revealConfirm = !revealConfirm },
            )

            AgreeRow(
                checked = agreed,
                onCheckedChange = { agreed = it },
                onAgreement = { onToast(resources.getString(AUTH_AGREEMENT_TOAST)) },
            )

            AuthCta(text = stringResource(R.string.auth_action_register)) {
                val result = validateAuthForm(
                    AuthForms.register,
                    mapOf(
                        AuthField.Nickname to nickname,
                        AuthField.Phone to phone,
                        AuthField.RegPassword to password,
                        AuthField.Confirm to confirm,
                    ),
                )
                errors = result

                val agreedOk = agreed
                if (!agreedOk) {
                    onToast(resources.getString(AUTH_AGREE_TOAST))
                }
                if (result.isEmpty() && agreedOk) {
                    onSubmitSuccess(phone, password, nickname)
                }
            }
        }

        AuthSwitch(
            prompt = stringResource(R.string.auth_switch_has_account),
            action = stringResource(R.string.auth_switch_login),
            onClick = { onNavigate("login") },
        )
    }
}

/**
 * 协议勾选行（原型 `.agree`，L375-394）。
 *
 * 文案是 `12.5px / line-height 1.55 / color --white-54`，其中两处协议名是强调色链接。
 * 原型用内联 `<a>` 参与同一个文本流，此处以 [FlowRow] 分段承载：
 * 字号放大导致换行时仍按文字流折行，不会把片段挤成孤立元素。
 */
@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun AgreeRow(
    checked: Boolean,
    onCheckedChange: (Boolean) -> Unit,
    onAgreement: () -> Unit,
) {
    val base = FtType.ft(12.5f, 400, 19.375f) // 1.55 × 12.5px

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(top = 4.dp), // `.agree` margin-top: 4px（L380）
        horizontalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        AuthCheck(
            checked = checked,
            onCheckedChange = onCheckedChange,
            modifier = Modifier.padding(top = 1.dp), // `.agree .check` margin-top: 1px（L382）
        )
        FlowRow(
            modifier = Modifier
                .weight(1f)
                .clickableNoRipple { onCheckedChange(!checked) },
        ) {
            Text(
                text = stringResource(R.string.auth_agree_prefix),
                style = base.copy(color = FtColor.white54),
            )
            AgreementLink(text = stringResource(R.string.auth_agree_user_agreement), style = base, onClick = onAgreement)
            Text(text = stringResource(R.string.auth_agree_conjunction), style = base.copy(color = FtColor.white54))
            AgreementLink(text = stringResource(R.string.auth_agree_privacy), style = base, onClick = onAgreement)
        }
    }
}

@Composable
private fun AgreementLink(
    text: String,
    style: TextStyle,
    onClick: () -> Unit,
) {
    Text(
        text = text,
        style = style.copy(color = FtColor.accent, fontWeight = FontWeight.Medium),
        modifier = Modifier.clickableNoRipple(onClick = onClick),
    )
}

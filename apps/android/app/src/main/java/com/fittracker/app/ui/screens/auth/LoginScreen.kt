package com.fittracker.app.ui.screens.auth

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalResources
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.fittracker.app.R
import com.fittracker.app.data.auth.AuthService
import com.fittracker.app.data.auth.WxAuthStore
import com.fittracker.app.data.cloud.SupabaseAuthProvider
import com.fittracker.app.data.cloud.SupabaseConfig
import com.fittracker.app.data.persist.JsonStore
import com.fittracker.app.data.persist.appDataStore
import com.fittracker.app.ui.components.clickableNoRipple
import com.fittracker.app.ui.theme.FtColor
import com.tencent.mm.opensdk.modelmsg.SendAuth
import com.tencent.mm.opensdk.openapi.IWXAPI
import com.tencent.mm.opensdk.openapi.WXAPIFactory
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/**
 * 登录屏——**双模式**：手机验证码 / 邮箱密码（对齐鸿蒙 `features/pencil/pages/PencilLoginPage.ets`；
 * 手机验证码分支为该页的功能 #27「云端化改造」新增，原型 `fittracker-auth.html` 只有邮箱形态）。
 *
 * 画布：430×900 设计空间 × `scale(0.90698)`，由 `FtCanvas` 统一施加——坐标/尺寸为设计空间原始
 * px 值。邮箱模式版式来源同前（原型 `screen-login` 帧 L550-620）；手机验证码模式的版式与文案
 * 来源为源页行号（注释逐处标注）。
 *
 * 与源的已知偏差（记录）：
 * 1. 源的协议勾选为**两模式共用**（`login()` L106-109 先判协议再分支）；安卓侧邮箱模式保持
 *    原型形态（无协议行），协议行仅在手机验证码模式呈现（提交时同样前置校验，文案逐字）。
 * 2. 源把发码成功提示 `hint` 与错误 `message` 渲染为表单内的内联文本行；安卓侧统一改走壳层
 *    **浮层** `onToast`（提示不参与表单布局——内联行出现/消失会顶动「登录」按钮）。
 *    文案仍逐字取自源，仅呈现通道不同。
 * 3. 提交中的 `loading` 禁用态未移植（连续点击风险小，标注待后续）。
 *
 * @param onSubmitSuccess 邮箱模式的校验通过回调（壳层负责认证调用与跳转编排）
 * @param onPhoneCodeSuccess 手机验证码登录成功回调（壳层负责编排；凭据已在 provider 内校验并落会话）
 */
@Composable
fun LoginScreen(
    onSubmitSuccess: (account: String, password: String) -> Unit,
    onPhoneCodeSuccess: (phone: String, code: String) -> Unit,
    onNavigate: (String) -> Unit,
    onToast: (String) -> Unit,
    modifier: Modifier = Modifier,
) {
    val context = LocalContext.current
    val resources = LocalResources.current
    val store = remember { JsonStore(context.appDataStore) }
    val scope = rememberCoroutineScope()

    // 手机验证码模式状态（源 `PencilLoginPage` @State 子集；`loginMode` 初值 'phone' 见源 L17）
    var loginMode by remember { mutableStateOf(LoginMode.Phone) }
    var phone by remember { mutableStateOf("") }
    var code by remember { mutableStateOf("") }
    var countdown by remember { mutableIntStateOf(0) }
    var sendingCode by remember { mutableStateOf(false) }
    var agreed by remember { mutableStateOf(false) }
    val sandboxMode: Boolean = !SupabaseConfig.isConfigured // 源 `sandboxMode`（L44）

    // 邮箱密码模式状态（原型形态，保持）
    var account by remember { mutableStateOf("") }
    var password by remember { mutableStateOf("") }
    var revealed by remember { mutableStateOf(false) }
    var remembered by remember { mutableStateOf(false) }
    var errors by remember { mutableStateOf(emptyMap<AuthField, AuthError>()) }

    // 倒计时（源 `startCountdown` L52-68 的 setInterval(1000) → 递归 effect）
    LaunchedEffect(countdown) {
        if (countdown > 0) {
            delay(1000)
            countdown -= 1
        }
    }

    /** 发码（源 `sendPhoneCode` L66-99：文案与分支逐字对齐）。 */
    fun sendPhoneCode() {
        scope.launch {
            if (phone.isEmpty()) {
                onToast(resources.getString(R.string.auth_placeholder_phone)) // 源 L70-72
                return@launch
            }
            sendingCode = true
            val result = AuthService.requestPhoneCode(store, phone)
            sendingCode = false
            if (!result.success) {
                onToast(result.message)
                return@launch
            }
            countdown = COUNTDOWN_SECONDS
            onToast(
                if (result.devCodeHint.isNotEmpty()) {
                    resources.getString(R.string.auth_toast_code_sent_demo, result.devCodeHint) // 源 L94
                } else {
                    resources.getString(R.string.auth_toast_code_sent) // 源 L96
                },
            )
        }
    }

    /** 提交（源 `login()` L101-140 的分支链；协议先判、各字段文案逐字）。 */
    fun submit() {
        if (loginMode == LoginMode.Phone) {
            scope.launch {
                if (!agreed) {
                    onToast(resources.getString(R.string.auth_toast_login_agree_required)) // 源 L106-109
                    return@launch
                }
                if (phone.isEmpty()) {
                    onToast(resources.getString(R.string.auth_placeholder_phone)) // 源 L114-116
                    return@launch
                }
                if (code.isEmpty()) {
                    onToast(resources.getString(R.string.auth_placeholder_code)) // 源 L117-119
                    return@launch
                }
                val error = AuthService.signInWithPhoneCode(store, phone, code).exceptionOrNull()?.message
                if (error != null) {
                    onToast(error)
                    return@launch
                }
                onPhoneCodeSuccess(phone, code)
            }
        } else {
            val result = validateAuthForm(
                AuthForms.login,
                mapOf(AuthField.Account to account, AuthField.Password to password),
            )
            errors = result
            if (result.isEmpty()) {
                onSubmitSuccess(account, password)
            }
        }
    }

    AuthPage(modifier = modifier) {
        AuthBrand()
        AuthHead(
            eyebrow = stringResource(R.string.auth_login_eyebrow),
            title = stringResource(R.string.auth_login_title),
            subtitle = stringResource(R.string.auth_login_subtitle),
        )

        if (sandboxMode) {
            SandboxBanner() // 源 `buildSandboxBanner` L230-243
        }

        LoginModeSwitch(
            mode = loginMode,
            onModeChange = { next ->
                if (next != loginMode) {
                    loginMode = next
                }
            },
        )

        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(top = 14.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp), // `.auth-form` gap: 14px
        ) {
            if (loginMode == LoginMode.Phone) {
                // 手机号（源 `buildField('手机号', …)`，样式经共享 [AuthField] 承接）
                AuthField(
                    label = stringResource(R.string.auth_field_phone),
                    value = phone,
                    onValueChange = { phone = it },
                    placeholder = stringResource(R.string.auth_placeholder_phone),
                    error = null,
                    keyboardType = KeyboardType.Phone,
                    maxLength = AUTH_PHONE_MAX_LENGTH,
                )
                // 验证码（源 `buildCodeField` L342-404：label + 输入 + 发送按钮）
                AuthField(
                    label = stringResource(R.string.auth_field_code),
                    value = code,
                    onValueChange = { code = it },
                    placeholder = stringResource(R.string.auth_placeholder_code),
                    error = null,
                    keyboardType = KeyboardType.Number,
                    maxLength = 6,
                    trailing = {
                        SendCodeButton(
                            countdown = countdown,
                            enabled = countdown == 0 && !sendingCode,
                            onClick = { sendPhoneCode() },
                        )
                    },
                )
                // 发码 / 提交的提示统一走壳层浮层 `onToast`——不在表单里插内联提示行：
                // 内联行出现/消失会顶动表单（把「登录」按钮上下推移），浮层则不参与布局。
                // 协议行（源 `buildAgreementRow`；链接真实跳转 legal——源 L378-397 的 pushUrl）
                LoginAgreeRow(
                    checked = agreed,
                    onCheckedChange = { agreed = it },
                    onAgreement = { onNavigate("legal?kind=agreement") },
                    onPrivacy = { onNavigate("legal?kind=privacy") },
                )
            } else {
                // 邮箱密码模式（原型形态，保持既有校验链）
                AuthField(
                    label = stringResource(R.string.auth_field_email),
                    value = account,
                    onValueChange = { account = it; errors = errors - AuthField.Account },
                    placeholder = stringResource(R.string.auth_placeholder_email),
                    error = errors[AuthField.Account]?.resolveText(context),
                )
                AuthField(
                    label = stringResource(R.string.auth_field_password),
                    value = password,
                    onValueChange = { password = it; errors = errors - AuthField.Password },
                    placeholder = stringResource(R.string.auth_placeholder_password),
                    error = errors[AuthField.Password]?.resolveText(context),
                    isPassword = true,
                    revealed = revealed,
                    onToggleReveal = { revealed = !revealed },
                )
                AuthAux(
                    remember = remembered,
                    onRememberChange = { remembered = it },
                    onForgot = { onToast(resources.getString(AUTH_FORGOT_TOAST)) },
                )
            }

            AuthCta(text = stringResource(R.string.auth_action_login)) { submit() }

            AuthDivider(text = stringResource(R.string.auth_divider_other_login))
            AuthSocial(
                wechatLabel = stringResource(R.string.auth_social_wechat),
                qqLabel = stringResource(R.string.auth_social_qq),
                onWechat = { startWeChatAuth(context, onToast) },
                onQq = { onToast(resources.getString(AUTH_QQ_TOAST)) },
            )
        }

        AuthSwitch(
            prompt = stringResource(R.string.auth_switch_no_account),
            action = stringResource(R.string.auth_switch_register),
            onClick = { onNavigate("register") },
        )
    }
}

/** 登录模式（源 `loginMode`：`'phone' | 'email'`）。 */
private enum class LoginMode { Phone, Email }

/** 倒计时秒数（源 `PencilLoginPage.ets:12` `COUNTDOWN_SECONDS = 60`）。 */
private const val COUNTDOWN_SECONDS: Int = 60

/**
 * 模式切换（源 `buildModeSwitch` L245-259 / `buildModeButton` L261-272）：
 * 高 44、内边距 3、底 `#0FFFFFFF` + 描边 `#1AFFFFFF`、圆角 14；选中项绿底黑字 13.5/700、圆角 11。
 */
@Composable
private fun LoginModeSwitch(mode: LoginMode, onModeChange: (LoginMode) -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .height(44.dp)
            .clip(RoundedCornerShape(14.dp))
            .background(ModeSwitchFill)
            .border(1.dp, ModeSwitchBorder, RoundedCornerShape(14.dp))
            .padding(3.dp),
        horizontalArrangement = Arrangement.spacedBy(2.dp),
    ) {
        ModeButton(label = stringResource(R.string.auth_mode_phone), active = mode == LoginMode.Phone) { onModeChange(LoginMode.Phone) }
        ModeButton(label = stringResource(R.string.auth_mode_email), active = mode == LoginMode.Email) { onModeChange(LoginMode.Email) }
    }
}

@Composable
private fun RowScope.ModeButton(label: String, active: Boolean, onClick: () -> Unit) {
    Box(
        modifier = Modifier
            .weight(1f)
            .fillMaxHeight()
            .clip(RoundedCornerShape(11.dp))
            .background(if (active) FtColor.accent else Color.Transparent)
            .clickableNoRipple(onClick = onClick),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = label,
            style = natural(13.5f, 700),
            color = if (active) FtColor.onAccent else ModeInactiveText,
        )
    }
}

/**
 * 「获取验证码」按钮（源 `buildCodeField` L363-380）：高 36、水平内边距 14、圆角 12；
 * 倒计时中字色 `#66FFFFFF` 底 `#0FFFFFFF`、文案 `{n}s`；可发时绿底黑字。
 */
@Composable
private fun SendCodeButton(countdown: Int, enabled: Boolean, onClick: () -> Unit) {
    Box(
        modifier = Modifier
            .height(36.dp)
            .clip(RoundedCornerShape(12.dp))
            .background(if (countdown > 0) ModeSwitchFill else FtColor.accent)
            .then(if (enabled) Modifier.clickableNoRipple(onClick = onClick) else Modifier)
            .padding(horizontal = 14.dp),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = if (countdown > 0) {
                stringResource(R.string.auth_code_countdown, countdown)
            } else {
                stringResource(R.string.auth_action_send_code)
            },
            style = natural(12.5f, 700),
            color = if (countdown > 0) CountdownText else FtColor.onAccent,
        )
    }
}

/**
 * 协议勾选行（源 `buildAgreementRow`；形态同 `RegisterScreen.AgreeRow`）：
 * 勾选框 + 文字流，两处协议名强调色且真实跳转（源为 `pushUrl(LEGAL_DOC)`）。
 */
@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun LoginAgreeRow(
    checked: Boolean,
    onCheckedChange: (Boolean) -> Unit,
    onAgreement: () -> Unit,
    onPrivacy: () -> Unit,
) {
    val base = natural(12.5f).copy(lineHeight = 19.sp) // 源 `lineHeight 19`（L410）

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(top = 4.dp),
        horizontalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        AuthCheck(
            checked = checked,
            onCheckedChange = onCheckedChange,
            modifier = Modifier.padding(top = 1.dp),
        )
        FlowRow(
            modifier = Modifier
                .weight(1f)
                .clickableNoRipple { onCheckedChange(!checked) },
        ) {
            Text(text = stringResource(R.string.auth_agree_prefix), style = base.copy(color = FtColor.white54))
            Text(
                text = stringResource(R.string.auth_agree_user_agreement),
                style = base.copy(color = FtColor.accent, fontWeight = FontWeight.Medium),
                modifier = Modifier.clickableNoRipple(onClick = onAgreement),
            )
            Text(text = stringResource(R.string.auth_agree_conjunction), style = base.copy(color = FtColor.white54))
            Text(
                text = stringResource(R.string.auth_agree_privacy),
                style = base.copy(color = FtColor.accent, fontWeight = FontWeight.Medium),
                modifier = Modifier.clickableNoRipple(onClick = onPrivacy),
            )
        }
    }
}

/** 沙盒提示条（源 `buildSandboxBanner` L230-243）：金棕色 12px 文案条。 */
@Composable
private fun SandboxBanner() {
    Text(
        text = stringResource(R.string.auth_login_sandbox_banner),
        modifier = Modifier
            .fillMaxWidth()
            .padding(bottom = 12.dp),
        style = natural(12f),
        color = SandboxText,
        textAlign = androidx.compose.ui.text.style.TextAlign.Center,
    )
}

// ── 屏内色值（源页字面值） ──────────────────────────────────────────────

/**
 * 拉起微信授权。
 *
 * 流程：createWXAPI → SendAuth.Req(scope, state) → api.sendReq(activity)
 * → 微信 App 内授权 → 回到 WXEntryActivity → WxAuthStore 落盘 → 由壳层消费换票。
 *
 * 前置校验与提示（不静默失败）：
 *  - 未配置 AppID（BuildConfig.WECHAT_APP_ID 空）→ 提示「暂未开通」
 *  - 未安装微信 → 提示「未安装微信」
 *  - sendReq 返回 false（跳转失败）→ 提示通用失败
 */
private fun startWeChatAuth(context: android.content.Context, onToast: (String) -> Unit) {
    val appId: String = com.fittracker.app.BuildConfig.WECHAT_APP_ID
    if (appId.isEmpty()) {
        onToast("微信登录暂未开通")
        return
    }
    val activity: android.app.Activity? = context as? android.app.Activity
    if (activity == null) {
        onToast("当前页面不可用，请重试")
        return
    }
    // 每次授权前清理陈旧结果，避免误消费上一次的 code
    WxAuthStore.clear(context)
    val api: IWXAPI = WXAPIFactory.createWXAPI(context, appId, false)
    if (!api.isWXAppInstalled) {
        onToast("未安装微信，无法使用微信登录")
        return
    }
    val req = SendAuth.Req()
    req.scope = "snsapi_userinfo"
    // state 用于防 CSRF（由 WXEntryActivity 回填到 WxAuthStore）
    req.state = System.currentTimeMillis().toString()
    if (!api.sendReq(req)) {
        onToast("微信授权跳转失败，请重试")
    }
}

/** 模式切换条底 `#0FFFFFFF`（源 L251）。 */
private val ModeSwitchFill = Color(0x0FFFFFFF)

/** 模式切换条描边 `#1AFFFFFF`（源 L252）。 */
private val ModeSwitchBorder = Color(0x1AFFFFFF)

/** 模式切换未选中字色 `#9EFFFFFF`（源 L267）。 */
private val ModeInactiveText = Color(0x9EFFFFFF)

/** 倒计时中按钮字色 `#66FFFFFF`（源 L371）。 */
private val CountdownText = Color(0x66FFFFFF)

/** 沙盒提示字色 `#D3B487`（源 L235）。 */
private val SandboxText = Color(0xFFD3B487)

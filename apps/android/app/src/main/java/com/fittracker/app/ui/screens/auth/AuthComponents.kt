package com.fittracker.app.ui.screens.auth

import android.content.Context
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.rotate
import androidx.compose.ui.graphics.drawscope.translate
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.fittracker.app.R
import com.fittracker.app.ui.components.FtBrandMark
import com.fittracker.app.ui.components.FtAppleIcon
import com.fittracker.app.ui.components.FtButton
import com.fittracker.app.ui.components.FtButtonVariant
import com.fittracker.app.ui.components.FtEyeIcon
import com.fittracker.app.ui.components.FtEyeOffIcon
import com.fittracker.app.ui.components.FtWechatIcon
import com.fittracker.app.ui.components.clickableNoRipple
import com.fittracker.app.ui.theme.FtColor
import com.fittracker.app.ui.theme.FtMotion
import com.fittracker.app.ui.theme.FtShape
import com.fittracker.app.ui.theme.FtType

/**
 * 登录 / 注册两屏的共享版式件。
 *
 * 全部尺寸是 **430×900 设计空间的原始 px 值**，与原型 CSS 逐字对应；
 * 画布缩放由 `FtCanvas` 统一施加，此处不得再乘缩放系数。
 *
 * 版式来源（原型 `fittracker-auth.html` 的 CSS 行号）：
 * `.auth-frame` L176-184 · `.auth-scroll` L186-191 · `.auth-content` L194-200 ·
 * `.auth-brand` L202-228 · `.auth-head` L229-252 · `.auth-form` L253 ·
 * `.field` L254-320 · `.auth-aux` L322-348 · `.check` L350-373 · `.agree` L375-394 ·
 * `.auth-cta` L396-414 · `.auth-divider` L416-423 · `.auth-social` L425-446 ·
 * `.auth-switch` L448-462 · `.auth-toast` L465-490。
 */

/**
 * 原型**未声明** `line-height` 的文本样式，即 CSS 的 `normal`（字体自然行高）。
 *
 * 与 [FtType.ft] 的缺省 `1.4 × size` 不同：那 1.4 是本工程给共享组件的刻度化默认值，
 * 而这里要的恰恰是「什么都不设」。强加 1.4 会让每一行多出 2–4px，
 * 十余处叠加后实测累积成整屏下移（登录页 CTA 位置较原型低 29px）。
 *
 * 原型**显式**声明了 `line-height` 的地方仍按字面值给定，不走本函数。
 */
internal fun natural(
    size: Float,
    weight: Int = 400,
    family: FontFamily = FtType.cn,
): TextStyle = TextStyle(
    fontFamily = family,
    fontSize = size.sp,
    fontWeight = FontWeight(weight),
    lineHeight = TextUnit.Unspecified,
)

/**
 * 解析一条校验错误为最终文案（UI 层入口）。
 *
 * 模型层（[AuthValidation]）只产出资源坐标 [AuthError.resId] / [AuthError.args]，
 * 插值在 UI 层完成——与设置域 `context.getString(resId, args)` 的口径一致。
 */
fun AuthError.resolveText(context: Context): String =
    if (args.isEmpty()) context.getString(resId) else context.getString(resId, *args.toTypedArray())

/**
 * 页面骨架（原型 `.auth-scroll` > `.auth-content`，L186-200）。
 *
 * `padding: 76px 24px 28px` 是 `.auth-content` 的声明；滚动容器是外层的 `.auth-scroll`，
 * 故内边距随内容滚动——Compose 侧对应「[verticalScroll] 在前、padding 在后」的顺序。
 */
@Composable
fun AuthPage(
    modifier: Modifier = Modifier,
    content: @Composable ColumnScope.() -> Unit,
) {
    Column(
        modifier = modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(start = 24.dp, end = 24.dp, top = 76.dp, bottom = 28.dp),
        content = content,
    )
}

/** `.auth-brand` L202-228：48 图标底 + 13 字标，居中，上下外边距 8 / 22。 */
@Composable
fun AuthBrand() {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(top = 8.dp, bottom = 22.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(13.dp),
    ) {
        Box(
            modifier = Modifier
                .size(48.dp)
                .clip(FtShape.xl) // border-radius: 16px
                .background(AuthMarkFill)
                .border(1.dp, AuthMarkBorder, FtShape.xl),
            contentAlignment = Alignment.Center,
        ) {
            FtBrandMark(modifier = Modifier.size(26.dp)) // 2026-10-09：换为用户设计稿品牌标志（原 FtActivityIcon）
        }
        Text(
            text = stringResource(R.string.auth_brand_wordmark),
            style = natural(13f, 700, FtType.num),
            color = FtColor.txtHi,
            letterSpacing = 2.4.sp,
        )
    }
}

/** `.auth-head` L229-252：眉题 11 mono / 标题 35 / 副题 15，居中。 */
@Composable
fun AuthHead(
    eyebrow: String,
    title: String,
    subtitle: String,
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(bottom = 26.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(
            text = eyebrow,
            style = natural(11f, 600, FtType.mono),
            modifier = Modifier.padding(bottom = 11.dp),
            color = FtColor.accent,
            letterSpacing = 1.5.sp,
        )
        Text(
            text = title,
            color = FtColor.txtHi,
            fontSize = 35.sp,
            lineHeight = 41.3.sp, // 1.18 × 35px
            fontWeight = FontWeight.Bold,
            letterSpacing = (-0.35).sp, // -.01em × 35px
            textAlign = TextAlign.Center,
        )
        Text(
            text = subtitle,
            modifier = Modifier.padding(top = 11.dp),
            color = FtColor.white65,
            fontSize = 15.sp,
            lineHeight = 24.sp, // 1.6 × 15px
            textAlign = TextAlign.Center,
        )
    }
}

/**
 * 单个字段（原型 `.field`，L254-320）：标签 + 控件 + 错误行。
 *
 * 错误行只在 [error] 非空时占位显示——原型用 `.field-error { display: none }`
 * 与 `.has-error .field-error { display: block }` 切换（L309-320），
 * 故无错时**不占高度**，Compose 侧对应「条件插入」而非「预留空位」。
 */
@Composable
fun AuthField(
    label: String,
    value: String,
    onValueChange: (String) -> Unit,
    placeholder: String,
    error: String?,
    modifier: Modifier = Modifier,
    isPassword: Boolean = false,
    revealed: Boolean = false,
    onToggleReveal: (() -> Unit)? = null,
    keyboardType: KeyboardType = KeyboardType.Text,
    maxLength: Int = Int.MAX_VALUE,
    trailing: (@Composable () -> Unit)? = null,
) {
    Column(modifier = modifier.fillMaxWidth()) {
        Text(
            text = label,
            style = natural(13f, 500),
            modifier = Modifier.padding(bottom = 8.dp),
            color = FtColor.white62,
        )
        AuthControl(
            value = value,
            onValueChange = onValueChange,
            placeholder = placeholder,
            hasError = error != null,
            isPassword = isPassword,
            revealed = revealed,
            onToggleReveal = onToggleReveal,
            keyboardType = keyboardType,
            maxLength = maxLength,
            trailing = trailing,
        )
        if (error != null) {
            Text(
                text = error,
                modifier = Modifier.padding(top = 7.dp),
                color = FtColor.warn,
                fontSize = 12.sp,
                lineHeight = 16.8.sp, // 1.4 × 12px
            )
        }
    }
}

/**
 * 输入控件（原型 `.control`，L261-307）：52 高 / 圆角 18 / 1px 描边 / 内边距 16。
 *
 * 三态换色逐条对应 CSS：默认 `rgba(255,255,255,.078)` 描边 + `rgba(255,255,255,.031)` 底；
 * `:focus-within` 换强调描边与底（L273-276）；`.has-error` 换警示描边与底（L316-319）。
 * 原型的 `:hover` 态（L272）在触屏上无对应，不移植。
 */
@Composable
private fun AuthControl(
    value: String,
    onValueChange: (String) -> Unit,
    placeholder: String,
    hasError: Boolean,
    isPassword: Boolean,
    revealed: Boolean,
    onToggleReveal: (() -> Unit)?,
    keyboardType: KeyboardType,
    maxLength: Int,
    trailing: (@Composable () -> Unit)?,
) {
    var focused by remember { mutableStateOf(false) }

    val borderColor = when {
        hasError -> FtColor.warnBorder
        focused -> AuthFocusBorder
        else -> FtColor.line14
    }
    val fill = when {
        hasError -> AuthErrorFill
        focused -> AuthFocusFill
        else -> AuthControlFill
    }

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .height(52.dp)
            .clip(FtShape.xxl) // border-radius: 18px
            .background(fill)
            .border(1.dp, borderColor, FtShape.xxl)
            // `.control .toggle` 的 `margin-right: -10px`：眼睛按钮右边缘探出内边距 10px，
            // 即距控件右边 6px；等价于把控件右内边距收到 6（L289-302）。
            // 尾部槽（验证码「获取验证码」按钮）对齐源 `buildCodeField` 的 `padding right: 10`。
            .padding(
                start = 16.dp,
                end = when {
                    trailing != null -> 10.dp
                    onToggleReveal != null -> 6.dp
                    else -> 16.dp
                },
            ),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        BasicTextField(
            value = value,
            onValueChange = { next -> onValueChange(next.take(maxLength)) },
            modifier = Modifier
                .weight(1f)
                .onFocusChanged { focused = it.isFocused },
            singleLine = true,
            textStyle = natural(16f).copy(color = FtColor.txtHi),
            cursorBrush = SolidColor(FtColor.accent),
            keyboardOptions = KeyboardOptions(keyboardType = keyboardType),
            visualTransformation = if (isPassword && !revealed) {
                PasswordVisualTransformation()
            } else {
                VisualTransformation.None
            },
            decorationBox = { innerTextField ->
                Box(contentAlignment = Alignment.CenterStart) {
                    if (value.isEmpty()) {
                        Text(
                            text = placeholder,
                            style = natural(16f),
                            color = FtColor.white40,
                        )
                    }
                    innerTextField()
                }
            },
        )
        if (onToggleReveal != null) {
            Box(
                modifier = Modifier
                    .size(44.dp)
                    .clip(FtShape.sm) // border-radius: 10px
                    .clickableNoRipple(onClick = onToggleReveal),
                contentAlignment = Alignment.Center,
            ) {
                // `.field.reveal` 时切到 eye-off（L305-307）；
                // 无障碍标签随状态切换，逐字取自原型 `aria-label`（L580 初值 / L794 切换）
                if (revealed) {
                    FtEyeOffIcon(
                        modifier = Modifier.size(20.dp),
                        color = FtColor.white54,
                        contentDescription = stringResource(R.string.auth_a11y_hide_password),
                    )
                } else {
                    FtEyeIcon(
                        modifier = Modifier.size(20.dp),
                        color = FtColor.white54,
                        contentDescription = stringResource(R.string.auth_a11y_show_password),
                    )
                }
            }
        }
        trailing?.invoke()
    }
}

/** `.auth-aux` L322-348：左「记住我」勾选、右「忘记密码？」文字按钮。 */
@Composable
fun AuthAux(
    remember: Boolean,
    onRememberChange: (Boolean) -> Unit,
    onForgot: () -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(top = 2.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.SpaceBetween,
    ) {
        Row(
            modifier = Modifier.clickableNoRipple { onRememberChange(!remember) },
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            AuthCheck(checked = remember, onCheckedChange = onRememberChange)
            Text(
                text = stringResource(R.string.auth_aux_remember),
                style = natural(13f),
                color = FtColor.white60,
            )
        }
        Box(
            modifier = Modifier
                .clip(FtShape.sm)
                .clickableNoRipple(onClick = onForgot)
                .padding(vertical = 12.dp), // `.auth-link` padding: 12px 0（L337-347）
        ) {
            Text(
                text = stringResource(R.string.auth_aux_forgot),
                style = natural(13f, 600),
                color = FtColor.accent,
            )
        }
    }
}

/**
 * 勾选框（原型 `.check`，L350-373）。
 *
 * 18×18 / 圆角 6 / 1px `rgba(255,255,255,.18)` 描边 / `rgba(255,255,255,.04)` 底；
 * 选中转实心强调色，勾形是 `border-left + border-bottom` 的 L 形，
 * 整体 `rotate(-45deg) translateY(-1px)`（L365-372）——此处逐条平移为
 * [rotate] 内嵌 [translate]，与 CSS 的「先 translate 后 rotate」次序一致。
 */
@Composable
fun AuthCheck(
    checked: Boolean,
    onCheckedChange: (Boolean) -> Unit,
    modifier: Modifier = Modifier,
) {
    val shape = RoundedCornerShape(6.dp)
    Box(
        modifier = modifier
            .size(18.dp)
            .clip(shape)
            .background(if (checked) FtColor.accent else CheckFill)
            .border(1.dp, if (checked) FtColor.accent else CheckBorder, shape)
            .clickableNoRipple { onCheckedChange(!checked) },
        contentAlignment = Alignment.Center,
    ) {
        if (checked) {
            Box(
                modifier = Modifier
                    .size(width = 9.dp, height = 5.dp)
                    .drawBehind {
                        val w = 2.dp.toPx()
                        val cx = 9.dp.toPx()
                        val cy = 5.dp.toPx()
                        rotate(-45f, pivot = Offset(cx / 2f, cy / 2f)) {
                            translate(0f, -(1.dp.toPx())) {
                                // border-left 2px：x = 1，y 0 → 5
                                drawLine(
                                    color = FtColor.onAccent,
                                    start = Offset(w / 2f, 0f),
                                    end = Offset(w / 2f, cy),
                                    strokeWidth = w,
                                    cap = StrokeCap.Square,
                                )
                                // border-bottom 2px：y = 4，x 0 → 9
                                drawLine(
                                    color = FtColor.onAccent,
                                    start = Offset(0f, cy - w / 2f),
                                    end = Offset(cx, cy - w / 2f),
                                    strokeWidth = w,
                                    cap = StrokeCap.Square,
                                )
                            }
                        }
                    },
            )
        }
    }
}

/**
 * 主操作（原型 `.auth-cta`，L396-414）：52 高 / 圆角 18 / 实心强调色 / 16 字重 700，
 * 上外边距 20，按压 `scale(.985)`（由 [FtButton] 承担）。
 *
 * 原型另有 `box-shadow: 0 12px 26px rgba(0,0,0,.38)`，但深色底上该大模糊黑投影不可辨，
 * 而 Compose [shadow] 反在按钮下产生可测暗带（实测底 (15,15,15) → 阴影区 (12~14)，
 * 见 `.rivet/scratch/v3-login.png`）。按项目「真机剖面」判据移除——与 7 处卡片级
 * elevation 阴影同处理。
 */
@Composable
fun AuthCta(
    text: String,
    modifier: Modifier = Modifier,
    onClick: () -> Unit,
) {
    FtButton(
        text = text,
        onClick = onClick,
        modifier = modifier
            .fillMaxWidth()
            .padding(top = 20.dp),
        variant = FtButtonVariant.Primary,
        fontSize = 16f,
        fontWeight = 700,
        height = 52.dp,
        shape = FtShape.xxl,
    )
}

/** `.auth-divider` L416-423：两侧 1px `--line-14` 细线夹 12px 说明文字。 */
@Composable
fun AuthDivider(text: String) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(top = 24.dp, bottom = 16.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Box(
            modifier = Modifier
                .weight(1f)
                .height(1.dp)
                .background(FtColor.line14),
        )
        Text(
            text = text,
            style = natural(12f),
            color = FtColor.white40,
            maxLines = 1,
        )
        Box(
            modifier = Modifier
                .weight(1f)
                .height(1.dp)
                .background(FtColor.line14),
        )
    }
}

/** `.auth-social` L425-446：两枚等宽 50 高 / 圆角 16 的第三方登录按钮。 */
@Composable
fun AuthSocial(
    wechatLabel: String,
    appleLabel: String,
    onWechat: () -> Unit,
    onApple: () -> Unit,
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        SocialButton(
            label = wechatLabel,
            onClick = onWechat,
            modifier = Modifier.weight(1f),
        ) { FtWechatIcon(modifier = Modifier.size(20.dp), color = FtColor.white70) }
        SocialButton(
            label = appleLabel,
            onClick = onApple,
            modifier = Modifier.weight(1f),
        ) { FtAppleIcon(modifier = Modifier.size(20.dp), color = FtColor.white70) }
    }
}

@Composable
private fun SocialButton(
    label: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    icon: @Composable () -> Unit,
) {
    Row(
        modifier = modifier
            .height(50.dp)
            .clip(FtShape.xl) // border-radius: 16px
            .background(AuthControlFill)
            .border(1.dp, FtColor.line10, FtShape.xl)
            .clickableNoRipple(onClick = onClick),
        horizontalArrangement = Arrangement.spacedBy(9.dp, Alignment.CenterHorizontally),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        icon()
        Text(
            text = label,
            style = natural(14f, 600),
            color = FtColor.txtHi,
        )
    }
}

/** `.auth-switch` L448-462：居中提示 + 文字链接（链接带 8×6 内边距以扩大触摸区）。 */
@Composable
fun AuthSwitch(
    prompt: String,
    action: String,
    onClick: () -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(top = 26.dp),
        horizontalArrangement = Arrangement.Center,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            text = prompt,
            style = natural(14f),
            color = FtColor.white60,
        )
        Box(
            modifier = Modifier
                .padding(start = 4.dp) // `.auth-switch a` margin-left: 4px
                .clip(FtShape.sm)
                .clickableNoRipple(onClick = onClick)
                .padding(horizontal = 6.dp, vertical = 8.dp),
        ) {
            Text(
                text = action,
                style = natural(14f, 600),
                color = FtColor.accent,
            )
        }
    }
}

/**
 * 轻量反馈浮层（原型 `.auth-toast`，L465-490）。
 *
 * **不随设计空间缩放**：原型里它是 `.phone` 的子元素、`.auth-frame` 之外，
 * 故位置按设备坐标系（底边内 48px、水平居中、最宽 320）。
 * 调用方应把它挂在 `FtCanvas` **之外**的盒子里。
 *
 * 出入场为 `opacity .18s` + `translateY(12px → 0)`（L474-484），
 * 时长取自 [FtMotion.DURATION_COLOR_BASE]。
 */
@Composable
fun AuthToast(
    message: String?,
    modifier: Modifier = Modifier,
) {
    // 退场动画期间 message 已变 null，需留存最后一次文案作为内容
    var shown by remember { mutableStateOf("") }
    if (message != null && message != shown) {
        shown = message
    }

    // 原型 `translateY(12px)`：入出场位移固定 12px、不随内容高度变化
    val slideOffset = with(LocalDensity.current) { 12.dp.roundToPx() }

    AnimatedVisibility(
        visible = message != null,
        modifier = modifier,
        enter = fadeIn(tween(FtMotion.DURATION_COLOR_BASE)) +
            slideInVertically(tween(FtMotion.DURATION_COLOR_BASE)) { slideOffset },
        exit = fadeOut(tween(FtMotion.DURATION_COLOR_BASE)) +
            slideOutVertically(tween(FtMotion.DURATION_COLOR_BASE)) { slideOffset },
    ) {
        Box(
            modifier = Modifier
                .padding(horizontal = 24.dp)
                .padding(bottom = 48.dp)
                .widthIn(max = 320.dp)
                .shadow(14.dp, FtShape.pill)
                .clip(FtShape.pill)
                .background(AuthToastFill)
                .border(1.dp, FtColor.line10, FtShape.pill)
                .padding(horizontal = 17.dp, vertical = 11.dp),
        ) {
            Text(
                text = shown,
                color = FtColor.txtHi,
                fontSize = 13.sp,
                lineHeight = 18.2.sp, // 1.4 × 13px
                textAlign = TextAlign.Center,
            )
        }
    }
}

// ── 屏内色值（原型 `:root` 无对应令牌，按 FtColorUtil 规则就地换算） ──
//
// 换算规则 AA = round(alpha × 255)

/** `.auth-brand .mark` 底 `rgba(80,236,167,.102)` → round(26.01) = 26 = 0x1A */
private val AuthMarkFill = Color(0x1A50ECA7)

/** `.auth-brand .mark` 描边 `rgba(80,236,167,.302)` → round(77.01) = 77 = 0x4D */
private val AuthMarkBorder = Color(0x4D50ECA7)

/** `.control` / `.soc` 底 `rgba(255,255,255,.031)` → round(7.905) = 8 = 0x08 */
private val AuthControlFill = Color(0x08FFFFFF)

/** `.control:focus-within` 底 `rgba(80,236,167,.05)` → round(12.75) = 13 = 0x0D */
private val AuthFocusFill = Color(0x0D50ECA7)

/** `.control:focus-within` 描边 `rgba(80,236,167,.45)` → round(114.75) = 115 = 0x73 */
private val AuthFocusBorder = Color(0x7350ECA7)

/** `.field.has-error .control` 底 `rgba(255,176,150,.04)` → round(10.2) = 10 = 0x0A */
private val AuthErrorFill = Color(0x0AFFB096)

/** `.check` 底 `rgba(255,255,255,.04)` → round(10.2) = 10 = 0x0A */
private val CheckFill = Color(0x0AFFFFFF)

/** `.check` 描边 `rgba(255,255,255,.18)` → round(45.9) = 46 = 0x2E */
private val CheckBorder = Color(0x2EFFFFFF)

/** `.auth-toast` 底 `rgba(13,17,23,.92)` → round(234.6) = 235 = 0xEB */
private val AuthToastFill = Color(0xEB0D1117)

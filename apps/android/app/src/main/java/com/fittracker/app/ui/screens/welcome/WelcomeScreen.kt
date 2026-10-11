package com.fittracker.app.ui.screens.welcome

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.scale
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.fittracker.app.R
import com.fittracker.app.ui.components.FtBrandMark
import com.fittracker.app.ui.components.FtButton
import com.fittracker.app.ui.components.FtButtonVariant
import com.fittracker.app.ui.theme.FtColor
import com.fittracker.app.ui.theme.FtShape
import com.fittracker.app.ui.theme.FtType

/**
 * 启动欢迎页（原型 `fittracker-welcome-home.html` 的 `screen-welcome` 帧）。
 *
 * 画布：430×900 设计空间 × scale(0.90698)，由 `FtCanvas` 统一施加——
 * 本文件内所有坐标/尺寸均为**设计空间的原始 px 值**，与原型 CSS 逐字对应，不得再乘缩放。
 *
 * 版式来源（原型 CSS 行号）：
 * `.w-logo` L201-206 · `.w-eyebrow` L219-226 · `.w-headline` L228-234 ·
 * `.w-sub` L236-242 · `.w-visual` L244-256 · `.w-cta` L264-289 · `.w-foot` L305-312。
 */
@Composable
fun WelcomeScreen(
    onStart: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Box(
        modifier = modifier
            .fillMaxSize()
            .background(FtColor.inkWelcome0),
    ) {
        // ── 品牌行：图标 + 字标 ────────────────────────────────
        Row(
            modifier = Modifier
                .offset(x = 24.dp, y = 118.dp)
                .width(382.dp)
                .height(42.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Box(
                modifier = Modifier
                    .size(34.dp)
                    .clip(FtShape.md)
                    .background(LogoMarkBg)
                    .border(1.dp, LogoMarkBorder, FtShape.md),
                contentAlignment = Alignment.Center,
            ) {
                FtBrandMark(modifier = Modifier.size(18.dp)) // 2026-10-09：换为用户设计稿品牌标志（原 FtActivityIcon）
            }
            Text(
                text = stringResource(R.string.auth_brand_wordmark),
                modifier = Modifier.padding(start = 10.dp),
                color = FtColor.txtHi,
                fontFamily = FtType.num,
                fontSize = 14.sp,
                fontWeight = FontWeight.Bold,
                letterSpacing = 1.8.sp,
            )
        }

        // ── 眉题 ──────────────────────────────────────────────
        Text(
            text = stringResource(R.string.auth_welcome_eyebrow),
            modifier = Modifier.offset(x = 24.dp, y = 196.dp),
            color = FtColor.accent,
            fontFamily = FtType.mono,
            fontSize = 11.sp,
            fontWeight = FontWeight.SemiBold,
            letterSpacing = 1.3.sp,
        )

        // ── 主标题 ────────────────────────────────────────────
        Text(
            text = stringResource(R.string.auth_welcome_headline),
            modifier = Modifier
                .offset(x = 24.dp, y = 224.dp)
                .width(382.dp),
            color = FtColor.txtHi,
            fontSize = 42.sp,
            lineHeight = 54.6.sp, // 原型 line-height 1.3 × 42px
            fontWeight = FontWeight.Bold,
        )

        // ── 副标题 ────────────────────────────────────────────
        Text(
            text = stringResource(R.string.auth_welcome_subtitle),
            modifier = Modifier
                .offset(x = 24.dp, y = 336.dp)
                .width(346.dp),
            color = FtColor.white65,
            fontSize = 16.sp,
            lineHeight = 25.6.sp, // 1.6 × 16px
        )

        // ── 训练视觉卡 ────────────────────────────────────────
        Box(
            modifier = Modifier
                .offset(x = 24.dp, y = 420.dp)
                .size(width = 382.dp, height = 208.dp)
                .clip(FtShape.section30)
                .background(FtColor.visualA)
                .border(1.dp, FtColor.line14, FtShape.section30),
        ) {
            WelcomeVisualArt(modifier = Modifier.fillMaxSize())
            Text(
                text = stringResource(R.string.auth_welcome_visual_caption),
                modifier = Modifier.offset(x = 24.dp, y = 168.dp),
                color = FtColor.white40,
                fontFamily = FtType.mono,
                fontSize = 10.sp,
                fontWeight = FontWeight.SemiBold,
                letterSpacing = 1.1.sp,
            )
        }

        // ── 主 CTA ────────────────────────────────────────────
        FtButton(
            text = stringResource(R.string.auth_welcome_cta),
            onClick = onStart,
            modifier = Modifier
                .offset(x = 24.dp, y = 684.dp)
                .width(382.dp),
            variant = FtButtonVariant.Primary,
            fontSize = 16f,
            fontWeight = 700,
            shape = FtShape.xxl, // 原型 border-radius 18px
        )

        // ── 页脚 ──────────────────────────────────────────────
        Text(
            text = stringResource(R.string.auth_welcome_foot),
            modifier = Modifier
                .offset(x = 24.dp, y = 852.dp)
                .width(382.dp),
            color = FtColor.white32,
            fontSize = 11.sp,
            lineHeight = 15.95.sp, // 1.45 × 11px
            textAlign = TextAlign.Center,
        )
    }
}

/** 原型 `.w-logo .mark` 背景 `rgba(80,236,167,.102)` → AA = round(.102×255) = 26 = 0x1A */
private val LogoMarkBg = Color(0x1A50ECA7)

/** 原型 `.w-logo .mark` 描边 `rgba(80,236,167,.302)` → AA = round(.302×255) = 77 = 0x4D */
private val LogoMarkBorder = Color(0x4D50ECA7)

/**
 * 视觉卡插画（原型 `fittracker-welcome-home.html:775-799` 的内联 SVG，viewBox `0 0 382 208`）。
 *
 * 三组元素逐字移植：
 * 1. 同心圆：圆心 (265,85)，半径 80 / 58 / 38，描边 1.5，强调色透明度 .10 / .17 / .14；
 * 2. 人形：`translate(164,34) scale(3.2)`，描边 1.7（放大后 5.44），圆头圆角；
 * 3. 哑铃：`translate(42,92) scale(1.8)`，描边 1.8（放大后 3.24），opacity .9；
 * 4. 星芒：锚点 (310,118) 的四角星，描边 1.4，色 #8CEBCC，opacity .92。
 */
@Composable
private fun WelcomeVisualArt(modifier: Modifier = Modifier) {
    Canvas(modifier = modifier) {
        scale(scaleX = size.width / 382f, scaleY = size.height / 208f, pivot = Offset.Zero) {
            // 1. 同心圆
            drawCircle(Color(0x1A50ECA7), radius = 80f, center = Offset(265f, 85f), style = Stroke(1.5f))
            drawCircle(Color(0x2B50ECA7), radius = 58f, center = Offset(265f, 85f), style = Stroke(1.5f))
            drawCircle(Color(0x2450ECA7), radius = 38f, center = Offset(265f, 85f), style = Stroke(1.5f))

            // 2. 人形（局部 24 单位空间 → translate(164,34) + scale(3.2)）
            val figStroke = Stroke(width = 5.44f, cap = StrokeCap.Round, join = StrokeJoin.Round)
            fun fx(x: Float) = 164f + 3.2f * x
            fun fy(y: Float) = 34f + 3.2f * y

            drawCircle(Color(0xFF50ECA7), radius = 2.2f * 3.2f, center = Offset(fx(12f), fy(4.6f)), style = figStroke)
            val body = Path().apply {
                moveTo(fx(12f), fy(7.2f))
                cubicTo(fx(11.6f), fy(9.4f), fx(11.7f), fy(11.8f), fx(12f), fy(14.2f))
            }
            val armL = Path().apply {
                moveTo(fx(12f), fy(10.4f))
                cubicTo(fx(11.1f), fy(9.4f), fx(9.7f), fy(8.6f), fx(8.5f), fy(7.8f))
            }
            val armR = Path().apply {
                moveTo(fx(12f), fy(10.4f))
                cubicTo(fx(12.9f), fy(9.4f), fx(14.3f), fy(8.6f), fx(15.5f), fy(7.8f))
            }
            val legL = Path().apply {
                moveTo(fx(12f), fy(14.2f))
                cubicTo(fx(11.1f), fy(16.3f), fx(10.2f), fy(18.5f), fx(9.5f), fy(20.6f))
            }
            val legR = Path().apply {
                moveTo(fx(12f), fy(14.2f))
                cubicTo(fx(12.9f), fy(16.3f), fx(13.8f), fy(18.5f), fx(14.5f), fy(20.6f))
            }
            listOf(body, armL, armR, legL, legR).forEach {
                drawPath(it, Color(0xFF50ECA7), style = figStroke)
            }

            // 3. 哑铃（translate(42,92) + scale(1.8)）
            val dStroke = Stroke(width = 3.24f, cap = StrokeCap.Round)
            fun dx(x: Float) = 42f + 1.8f * x
            fun dy(y: Float) = 92f + 1.8f * y
            val dumbbell = Color(0xE650ECA7) // opacity .9 → round(.9×255) = 230 = 0xE6
            drawLine(dumbbell, Offset(dx(6.8f), dy(7.2f)), Offset(dx(6.8f), dy(16.8f)), strokeWidth = 3.24f, cap = StrokeCap.Round)
            drawLine(dumbbell, Offset(dx(17.2f), dy(7.2f)), Offset(dx(17.2f), dy(16.8f)), strokeWidth = 3.24f, cap = StrokeCap.Round)
            drawLine(dumbbell, Offset(dx(6.8f), dy(12f)), Offset(dx(17.2f), dy(12f)), strokeWidth = 3.24f, cap = StrokeCap.Round)
            drawLine(dumbbell, Offset(dx(3f), dy(9.2f)), Offset(dx(3f), dy(14.8f)), strokeWidth = 3.24f, cap = StrokeCap.Round)
            drawLine(dumbbell, Offset(dx(21f), dy(9.2f)), Offset(dx(21f), dy(14.8f)), strokeWidth = 3.24f, cap = StrokeCap.Round)

            // 4. 星芒
            val spark = Path().apply {
                moveTo(310f, 118f)
                lineTo(311.8f, 124f); lineTo(317.8f, 125.8f)
                lineTo(311.8f, 127.6f); lineTo(310f, 133.6f)
                lineTo(308.2f, 127.6f); lineTo(302.2f, 125.8f)
                lineTo(308.2f, 124f)
                close()
            }
            drawPath(
                spark,
                Color(0xEB8CEBCC), // opacity .92 → round(.92×255) = 235 = 0xEB
                style = Stroke(width = 1.4f, join = StrokeJoin.Round),
            )
        }
    }
}

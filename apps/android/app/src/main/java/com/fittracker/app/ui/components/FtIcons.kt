package com.fittracker.app.ui.components

import androidx.compose.foundation.Canvas
import androidx.compose.material3.Icon
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.res.painterResource
import com.fittracker.app.R
import com.fittracker.app.ui.theme.FtColor

/**
 * 原型内联 SVG 图标的 Compose 等价实现。
 *
 * 路径数据逐字取自原型 `<symbol>` 定义，viewBox 均为 `0 0 24 24`，
 * 按 `size.minDimension / 24` 等比换算，描边宽度同步缩放。
 */
private const val VIEW = 24f

private fun androidx.compose.ui.graphics.drawscope.DrawScope.strokeLine(
    color: Color,
    x1: Float, y1: Float, x2: Float, y2: Float,
    width: Float,
) {
    drawLine(
        color = color,
        start = Offset(x1, y1),
        end = Offset(x2, y2),
        strokeWidth = width,
        cap = StrokeCap.Round,
    )
}

/**
 * 训练握铃（原型 `#i-dumbbell`，`fittracker-welcome-home.html:703-709`）。
 *
 * 五笔：两侧配重竖线 x=6.8 / 17.2（y 7.2→16.8）、中间横杠 y=12（x 6.8→17.2）、
 * 两端把手竖线 x=3 / 21（y 9.2→14.8）。描边 1.8，圆头。
 */
@Composable
fun FtDumbbellIcon(
    modifier: Modifier = Modifier,
    color: Color = FtColor.onAccent,
) {
    Canvas(modifier = modifier) {
        val k = size.minDimension / VIEW
        val w = 1.8f * k
        strokeLine(color, 6.8f * k, 7.2f * k, 6.8f * k, 16.8f * k, w)
        strokeLine(color, 17.2f * k, 7.2f * k, 17.2f * k, 16.8f * k, w)
        strokeLine(color, 6.8f * k, 12f * k, 17.2f * k, 12f * k, w)
        strokeLine(color, 3f * k, 9.2f * k, 3f * k, 14.8f * k, w)
        strokeLine(color, 21f * k, 9.2f * k, 21f * k, 14.8f * k, w)
    }
}

/**
 * 活动/节律图标（原型 `#i-activity`，`fittracker-welcome-home.html:697-702`）。
 *
 * 两笔：折线柱状「7 20.5 → 7 6.5 → 19 6.5」与脉冲线
 * 「7 13.5 → 10.2 13.5 → 12 8.6 → 14 17.4 → 16 12.4 → 19 13.5」，描边 2.6，圆头圆角。
 */
@Composable
fun FtActivityIcon(
    modifier: Modifier = Modifier,
    color: Color = FtColor.accent,
) {
    Canvas(modifier = modifier) {
        val k = size.minDimension / VIEW
        val w = 2.6f * k
        val p = Path().apply {
            moveTo(7f * k, 20.5f * k)
            lineTo(7f * k, 6.5f * k)
            lineTo(19f * k, 6.5f * k)
        }
        drawPath(p, color, style = Stroke(width = w, cap = StrokeCap.Round, join = StrokeJoin.Round))

        val q = Path().apply {
            moveTo(7f * k, 13.5f * k)
            lineTo(10.2f * k, 13.5f * k)
            lineTo(12f * k, 8.6f * k)
            lineTo(14f * k, 17.4f * k)
            lineTo(16f * k, 12.4f * k)
            lineTo(19f * k, 13.5f * k)
        }
        drawPath(q, color, style = Stroke(width = w, cap = StrokeCap.Round, join = StrokeJoin.Round))
    }
}

/**
 * 时钟（原型 `#i-clock`，`fittracker-welcome-home.html:710-713`）。
 * 圆 r8.5 + 指针 `M12 7.5V12l3 2`，描边 1.8。
 */
@Composable
fun FtClockIcon(modifier: Modifier = Modifier, color: Color = FtColor.accent) {
    Canvas(modifier = modifier) {
        val k = size.minDimension / VIEW
        val w = 1.8f * k
        drawCircle(color, radius = 8.5f * k, center = Offset(12f * k, 12f * k), style = Stroke(w))
        val hand = Path().apply {
            moveTo(12f * k, 7.5f * k)
            lineTo(12f * k, 12f * k)
            lineTo(15f * k, 14f * k)
        }
        drawPath(hand, color, style = Stroke(w, cap = StrokeCap.Round, join = StrokeJoin.Round))
    }
}

/**
 * 靶心（原型 `#i-target`，`fittracker-welcome-home.html:731-735`）。
 * 双圆 r8.5 / r4.6（描边 1.8）+ 实心圆心 r1.2。
 */
@Composable
fun FtTargetIcon(modifier: Modifier = Modifier, color: Color = FtColor.accent) {
    Canvas(modifier = modifier) {
        val k = size.minDimension / VIEW
        val w = 1.8f * k
        val c = Offset(12f * k, 12f * k)
        drawCircle(color, radius = 8.5f * k, center = c, style = Stroke(w))
        drawCircle(color, radius = 4.6f * k, center = c, style = Stroke(w))
        drawCircle(color, radius = 1.2f * k, center = c)
    }
}

/**
 * 用户（原型 `#i-user`，`fittracker-welcome-home.html:718-721`）。
 * 头圆 r3.8 + 肩弧 `M4.5 20.2c0-3.7 3.2-5.6 7.5-5.6s7.5 1.9 7.5 5.6`，描边 1.8。
 */
@Composable
fun FtUserIcon(modifier: Modifier = Modifier, color: Color = FtColor.accent) {
    Canvas(modifier = modifier) {
        val k = size.minDimension / VIEW
        val w = 1.8f * k
        drawCircle(color, radius = 3.8f * k, center = Offset(12f * k, 8f * k), style = Stroke(w))
        val shoulder = Path().apply {
            moveTo(4.5f * k, 20.2f * k)
            cubicTo(4.5f * k, 16.5f * k, 7.7f * k, 14.6f * k, 12f * k, 14.6f * k)
            cubicTo(16.3f * k, 14.6f * k, 19.5f * k, 16.5f * k, 19.5f * k, 20.2f * k)
        }
        drawPath(shoulder, color, style = Stroke(w, cap = StrokeCap.Round))
    }
}

/**
 * 计划（原型 `#i-plan`，`fittracker-welcome-home.html:722-726`）。
 * 外框圆角矩形 16×16 rx3 + 顶部装订线 + 内文短线，描边 1.8。
 */
@Composable
fun FtPlanIcon(modifier: Modifier = Modifier, color: Color = FtColor.accent) {
    Canvas(modifier = modifier) {
        val k = size.minDimension / VIEW
        val w = 1.8f * k
        drawRoundRect(
            color = color,
            topLeft = Offset(4f * k, 4f * k),
            size = androidx.compose.ui.geometry.Size(16f * k, 16f * k),
            cornerRadius = androidx.compose.ui.geometry.CornerRadius(3f * k, 3f * k),
            style = Stroke(w),
        )
        val top = Path().apply {
            moveTo(8f * k, 4.5f * k); lineTo(8f * k, 7.5f * k)
            moveTo(16f * k, 4.5f * k); lineTo(16f * k, 7.5f * k)
            moveTo(4.5f * k, 9f * k); lineTo(19.5f * k, 9f * k)
            moveTo(8f * k, 13f * k); lineTo(11f * k, 13f * k)
            moveTo(8f * k, 16.5f * k); lineTo(14f * k, 16.5f * k)
        }
        drawPath(top, color, style = Stroke(w, cap = StrokeCap.Round))
    }
}

/**
 * 回顾（原型 `#i-review`，`fittracker-welcome-home.html:727-730`）。
 * 折线 `M3.5 17.5 L9 12 L12.2 15.2 L20.5 7` + 箭头 `M15.5 7h5v5`，描边 1.8。
 */
@Composable
fun FtReviewIcon(modifier: Modifier = Modifier, color: Color = FtColor.accent) {
    Canvas(modifier = modifier) {
        val k = size.minDimension / VIEW
        val w = 1.8f * k
        val line = Path().apply {
            moveTo(3.5f * k, 17.5f * k)
            lineTo(9f * k, 12f * k)
            lineTo(12.2f * k, 15.2f * k)
            lineTo(20.5f * k, 7f * k)
        }
        drawPath(line, color, style = Stroke(w, cap = StrokeCap.Round, join = StrokeJoin.Round))
        val arrow = Path().apply {
            moveTo(15.5f * k, 7f * k)
            lineTo(20.5f * k, 7f * k)
            lineTo(20.5f * k, 12f * k)
        }
        drawPath(arrow, color, style = Stroke(w, cap = StrokeCap.Round, join = StrokeJoin.Round))
    }
}

// ── 账号屏图标 ────────────────────────────────────────────────────────────
//
// 这四个与上面的 Canvas 图标机制不同：它们由 `res/drawable/ic_auth_*.xml`
// 的 VectorDrawable 承载。原因是路径复杂度——眼形是四段平滑贝塞尔、
// 微信气泡与 Apple 标含十余段相对贝塞尔与椭圆弧，手工展开成 Compose Path
// 既冗长又极易失真；而 VectorDrawable 原生支持 SVG 路径语法，
// 把原型 `<symbol>` 的 `d` 逐字贴进 `android:pathData` 即可无损移植。
// 描边宽度写在 24×24 的 viewport 坐标系内，随 Icon 尺寸等比缩放，
// 与 Canvas 版 `size.minDimension / 24` 的换算等价。

/**
 * 显示密码（原型 `#i-eye`，`fittracker-auth.html:512-515`）。
 *
 * [contentDescription] 对应原型 `[data-toggle]` 按钮的 `aria-label`（L580），
 * 它随显隐状态在「显示密码 / 隐藏密码」之间切换（L794）。
 */
@Composable
fun FtEyeIcon(
    modifier: Modifier = Modifier,
    color: Color = FtColor.white54,
    contentDescription: String? = null,
) {
    Icon(
        painter = painterResource(R.drawable.ic_auth_eye),
        contentDescription = contentDescription,
        modifier = modifier,
        tint = color,
    )
}

/** 隐藏密码（原型 `#i-eye-off`，`fittracker-auth.html:516-520`）。 */
@Composable
fun FtEyeOffIcon(
    modifier: Modifier = Modifier,
    color: Color = FtColor.white54,
    contentDescription: String? = null,
) {
    Icon(
        painter = painterResource(R.drawable.ic_auth_eye_off),
        contentDescription = contentDescription,
        modifier = modifier,
        tint = color,
    )
}

/** 微信（原型 `#i-wechat`，`fittracker-auth.html:521-526`）。 */
@Composable
fun FtWechatIcon(
    modifier: Modifier = Modifier,
    color: Color = FtColor.white70,
) {
    Icon(
        painter = painterResource(R.drawable.ic_auth_wechat),
        contentDescription = null,
        modifier = modifier,
        tint = color,
    )
}

/** Apple（原型 `#i-apple`，`fittracker-auth.html:527-529`）。 */
@Composable
fun FtAppleIcon(
    modifier: Modifier = Modifier,
    color: Color = FtColor.white70,
) {
    Icon(
        painter = painterResource(R.drawable.ic_auth_apple),
        contentDescription = null,
        modifier = modifier,
        tint = color,
    )
}

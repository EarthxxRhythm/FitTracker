package com.fittracker.app.ui.components

import androidx.compose.foundation.Canvas
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke

/**
 * 品牌标志（2026-10-09 按用户设计稿）：C 形圆环（开口朝上约 90°、圆头端点）+ 缺口中央实心圆点。
 *
 * 比例与启动图标（`ic_launcher_foreground.xml`）一致（基于 108 视口的同参数）：
 * 环外半径 ≈ 画布 48%（26/54）、环粗 ≈ 外径 14%（7.3）、点半径 ≈ 外径 20%（5.2）、
 * 点圆心距环心 ≈ 外径 45%（23.4）。默认品牌绿 #50ECA7。
 *
 * @param modifier 尺寸由调用方给定（正方形区域，绘制自适应短边）
 */
@Composable
fun FtBrandMark(
    modifier: Modifier = Modifier,
    color: Color = Color(0xFF50ECA7),
) {
    Canvas(modifier = modifier) {
        val k = size.minDimension / 108f // 与矢量资源同坐标系
        val cx = size.width / 2f
        val cy = size.height / 2f
        val outerR = 26f * k
        val strokeW = 7.3f * k
        val ringR = outerR - strokeW / 2f // 弧的中心线半径
        val dotR = 5.2f * k
        val dotC = 23.4f * k

        // 环：Compose 角度 0°=3 点钟、顺时针；缺口朝上 90° → 自 315°（右上）顺时针扫 270° 至 225°（左上）
        drawArc(
            color = color,
            startAngle = 315f,
            sweepAngle = 270f,
            useCenter = false,
            topLeft = Offset(cx - ringR, cy - ringR),
            size = Size(ringR * 2f, ringR * 2f),
            style = Stroke(width = strokeW, cap = StrokeCap.Round),
        )
        // 点：缺口中央（环心正上方 dotC 处）
        drawCircle(color = color, radius = dotR, center = Offset(cx, cy - dotC))
    }
}

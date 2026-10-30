package com.fittracker.app.ui.components

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.fittracker.app.ui.theme.FtColor
import com.fittracker.app.ui.theme.FtMotion
import kotlinx.coroutines.launch

/**
 * 悬浮胶囊持有的最小草稿摘要。
 *
 * 只带展示需要的六个数，不把整个 `WorkoutDraftSnapshot` 传进 UI——胶囊不该知道草稿的结构，
 * 否则将来草稿加字段时这里会被动跟着改。
 */
data class ResumeDraftSummary(
    /** 全场已完成组数（计数器分子）。 */
    val completedSets: Int,
    /** 全场目标组数（计数器分母）。 */
    val totalSets: Int,
    /** 已训练分钟数；0 表示不满一分钟，副行不显示时长段。 */
    val elapsedMinutes: Int,
    /** 当前动作名（首个未录满动作，与训练页选中口径同源）。 */
    val exerciseName: String,
    /** 当前动作内已完成组数。 */
    val exerciseCompletedSets: Int,
    /** 当前动作目标组数。 */
    val exerciseTargetSets: Int,
)

/**
 * 「训练进行中」悬浮胶囊。
 *
 * 信息分三层，与训练页的阅读顺序一致（整体 → 当前 → 局部）：
 *   ① 环内 3/12 —— 全场组数计数器。环的角度给比例、环内数字给精确值；
 *      只给数字会丢掉「还剩多少」的直觉，只给环会丢掉「到底几组」。
 *   ② 当前动作名 —— 告诉用户点进去会看到哪个动作。
 *   ③ 第 2 组 / 共 4 组 · 32 分钟 —— 动作内位置 + 已训练时长。
 *
 * 点按先收束 110ms 再回调：让「胶囊被按下」与「训练页推入」读成一次连续动作，
 * 而不是「点了没反应 → 突然换屏」。
 */
@Composable
fun ResumeWorkoutBar(
    summary: ResumeDraftSummary,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val scope = rememberCoroutineScope()
    // 0 = 常态，1 = 被按下收束到底。只在点按后到页面推入之间的 110ms 里非 0。
    val sink = remember { Animatable(0f) }

    Row(
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = 18.dp)
            .height(68.dp)
            .graphicsLayer {
                scaleX = 1f - 0.03f * sink.value
                scaleY = 1f - 0.08f * sink.value
                alpha = 1f - 0.55f * sink.value
                translationY = 6.dp.toPx() * sink.value
            }
            .shadow(elevation = 14.dp, shape = RoundedCornerShape(20.dp), clip = false)
            .clip(RoundedCornerShape(20.dp))
            .background(FtColor.surface)
            .border(width = 1.dp, color = FtColor.accent12, shape = RoundedCornerShape(20.dp))
            .clickable {
                scope.launch {
                    sink.animateTo(1f, tween(FtMotion.DURATION_PRESS, easing = FtMotion.EASE_MOTION))
                    onClick()
                    // 页面已切走，复位不可见；下次回来必须从 0 开始，否则胶囊是「压扁」的
                    sink.snapTo(0f)
                }
            }
            .padding(horizontal = 14.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        ResumeRing(
            completedSets = summary.completedSets,
            totalSets = summary.totalSets,
        )

        Column(
            modifier = Modifier.weight(1f),
            verticalArrangement = Arrangement.spacedBy(3.dp),
        ) {
            Text(
                text = summary.exerciseName.ifEmpty { "训练进行中" },
                color = FtColor.txtHi,
                fontSize = 14.sp,
                fontWeight = FontWeight.Bold,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
            Text(
                text = captionOf(summary),
                color = FtColor.navInactive,
                fontSize = 11.sp,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
        }

        // 只留一条极淡的箭头提示「可进入」，不放按钮：整条胶囊本身就是点击区
        // （与列表行的 › 同一语汇），加按钮会让它读成「卡片 + 两个操作」。
        Canvas(modifier = Modifier.size(width = 9.dp, height = 14.dp)) {
            val stroke = 1.6.dp.toPx()
            drawLine(
                color = FtColor.navInactive,
                start = Offset(1.dp.toPx(), 1.dp.toPx()),
                end = Offset(size.width - 1.dp.toPx(), size.height / 2f),
                strokeWidth = stroke,
                cap = StrokeCap.Round,
            )
            drawLine(
                color = FtColor.navInactive,
                start = Offset(size.width - 1.dp.toPx(), size.height / 2f),
                end = Offset(1.dp.toPx(), size.height - 1.dp.toPx()),
                strokeWidth = stroke,
                cap = StrokeCap.Round,
            )
        }
    }
}

/**
 * 左侧环形计数器：环角度 = 全场完成比例，环内给精确数字（3 在上、/12 在下）。
 *
 * 用 Canvas 自绘而不是 `CircularProgressIndicator`：后者在 Material3 各版本间
 * `progress` 参数的形状变过（Float vs lambda），自绘不随依赖升级漂移。
 */
@Composable
private fun ResumeRing(completedSets: Int, totalSets: Int) {
    val total = if (totalSets > 0) totalSets else 1
    val ratio = (completedSets.toFloat() / total.toFloat()).coerceIn(0f, 1f)

    Box(modifier = Modifier.size(44.dp), contentAlignment = Alignment.Center) {
        Canvas(modifier = Modifier.size(44.dp)) {
            val strokePx = 3.dp.toPx()
            val inset = strokePx / 2f
            val arcSize = Size(size.width - strokePx, size.height - strokePx)
            val topLeft = Offset(inset, inset)
            // 轨道：整圈，淡白
            drawArc(
                color = FtColor.accent12,
                startAngle = -90f,
                sweepAngle = 360f,
                useCenter = false,
                topLeft = topLeft,
                size = arcSize,
                style = Stroke(width = strokePx, cap = StrokeCap.Round),
            )
            // 进度：从 12 点顺时针扫过
            if (ratio > 0f) {
                drawArc(
                    color = FtColor.accent,
                    startAngle = -90f,
                    sweepAngle = 360f * ratio,
                    useCenter = false,
                    topLeft = topLeft,
                    size = arcSize,
                    style = Stroke(width = strokePx, cap = StrokeCap.Round),
                )
            }
        }
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Text(
                text = completedSets.toString(),
                color = FtColor.txtHi,
                fontSize = 15.sp,
                fontWeight = FontWeight.Bold,
            )
            Text(
                text = "/$totalSets",
                color = FtColor.navInactive,
                fontSize = 9.sp,
            )
        }
    }
}

/**
 * 副行文案。
 *
 * 三种形态互斥：该动作未满 → 「第 N 组 / 共 M 组」；已满 → 「本动作已完成 · 共 M 组」；
 * 拿不到动作组数（旧草稿）→ 退回全局「已做 N 组」。时长只在非 0 时追加。
 */
private fun captionOf(summary: ResumeDraftSummary): String {
    val target = summary.exerciseTargetSets
    val completed = summary.exerciseCompletedSets
    val base = when {
        target > 0 && completed >= target -> "本动作已完成 · 共 $target 组"
        target > 0 -> "第 ${completed + 1} 组 / 共 $target 组"
        else -> "已做 ${summary.completedSets} 组"
    }
    return if (summary.elapsedMinutes > 0) "$base · ${summary.elapsedMinutes} 分钟" else base
}

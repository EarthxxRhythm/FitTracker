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
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.fittracker.app.ui.theme.FtColor
import com.fittracker.app.ui.theme.FtMotion
import kotlinx.coroutines.delay
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
    /**
     * 草稿开练时刻（epoch ms，与 `ActiveScreen` 恢复分支同一字段）。
     *
     * 胶囊中栏的时钟由它派生（`now - startedAt`），不拿落盘快照的秒数静态显示：
     * 快照只在草稿写入时更新，停在首页时秒数会冻住。
     */
    val startedAt: Long,
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

    // 每秒一次的「现在」：中栏时钟由 now - startedAt 派生，与训练页恢复分支同一锚点
    // （ActiveScreen 恢复时也从 draft.startedAt 播种），因此不会像累加计数那样累积漂移；
    // 后台挂起回来后下一次 tick 直接跳到真实墙钟时间，不会慢慢追。
    var nowTick by remember { mutableLongStateOf(System.currentTimeMillis()) }
    LaunchedEffect(Unit) {
        while (true) {
            delay(1_000L)
            nowTick = System.currentTimeMillis()
        }
    }
    // 秒数永远从 startedAt 现算，不在状态里留快照：tick 只提供「现在变了」这个信号。
    // `startedAt <= 0` 的旧草稿由 helper 兜底成 0，不需要第二份数据来判断。
    val elapsedSeconds = elapsedSecondsSince(summary.startedAt, nowTick)

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
            .background(
                // 顶部一层极淡的品牌色微光过渡到卡面纯色：让这条浮起来，
                // 而不是一块平的中性色块。accent 8% 叠在 surface 上，不引入新色值。
                Brush.verticalGradient(
                    colors = listOf(FtColor.accent.copy(alpha = 0.08f), FtColor.surface),
                ),
            )
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
        // 左：我在练什么 + 这一动作做到第几组
        Column(
            modifier = Modifier.weight(1f),
            verticalArrangement = Arrangement.spacedBy(4.dp),
        ) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                // 与训练页顶栏计时点同一个绿点（静态版，不呼吸——为一条装饰动画挂常驻动画
                // 不划算）：一眼看出这条是「正在进行的训练」，不是一条历史记录。
                Box(
                    modifier = Modifier
                        .size(6.dp)
                        .clip(CircleShape)
                        .background(FtColor.accent),
                )
                Text(
                    text = summary.exerciseName.ifEmpty { "训练进行中" },
                    color = FtColor.txtHi,
                    fontSize = 14.sp,
                    fontWeight = FontWeight.Bold,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
            }
            // 组数降到中性色：accent 只留给「时间在走」和「整场进度」，
            // 三个数字同色会互相抢注意力。
            Text(
                text = setProgressOf(summary),
                color = FtColor.navInactive,
                fontSize = 12.sp,
                fontWeight = FontWeight.Bold,
                maxLines = 1,
            )
        }

        // 中：已经练了多久。与训练页「同源不同机制」——两处都锚定 draft.startedAt，
        // 训练页是恢复后累加，这里是 now - startedAt 绝对派生；显示格式（mm:ss）也一致。
        // 固定宽度 + 居中：秒数每跳一次不会把左右两栏推来推去。
        Text(
            text = formatElapsedClock(elapsedSeconds),
            color = FtColor.accent,
            fontSize = 22.sp,
            fontWeight = FontWeight.Bold,
            textAlign = TextAlign.Center,
            maxLines = 1,
            modifier = Modifier.width(88.dp),
        )

        // 右：整场还剩多少（环给比例、环内数字给精确值）
        ResumeRing(
            completedSets = summary.completedSets,
            totalSets = summary.totalSets,
        )
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

    Box(modifier = Modifier.size(46.dp), contentAlignment = Alignment.Center) {
        Canvas(modifier = Modifier.size(46.dp)) {
            val strokePx = 3.dp.toPx()
            val inset = strokePx / 2f
            val arcSize = Size(size.width - strokePx, size.height - strokePx)
            val topLeft = Offset(inset, inset)
            // 轨道：整圈，淡白
            drawArc(
                color = FtColor.accent07,
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
        Text(
            text = "$completedSets/$totalSets",
            color = FtColor.accent,
            fontSize = 10.sp,
            fontWeight = FontWeight.Bold,
        )
    }
}

/** 左栏第二行：「2 / 4」——第几组 / 本动作共几组；练满时停在 4 / 4。 */
private fun setProgressOf(summary: ResumeDraftSummary): String {
    val target = summary.exerciseTargetSets
    val completed = summary.exerciseCompletedSets
    if (target <= 0) {
        // 旧草稿拿不到动作组数：退回全局计数，不显示一个假的 x / 0
        return "已做 ${summary.completedSets} 组"
    }
    val currentSet = if (completed >= target) target else completed + 1
    return "$currentSet / $target"
}

/**
 * 从草稿 `startedAt` 派生「已训练秒数」——墙钟绝对派生，不是 `elapsed += 1` 累加计数。
 *
 * 两处兜底各自对应一种会把显示搞错的真实输入：
 * - `startedAt <= 0`：旧版本/异常写入的草稿缺 `startedAt`，`(now - 0)/1000` 会显示天文数字；
 * - `now <= startedAt`：设备时钟回拨或刚开练，直接相减会出负数。
 * 两种都退化为 0（等价「刚开始」），不把错误值原样喂给 [formatElapsedClock]。
 *
 * 抽成独立函数而非内联：胶囊（每秒 tick）与训练页（恢复后累加的回填）用的是同一口径，
 * 两处各写一遍迟早分叉；单测也只需钉这一个纯函数。
 */
internal fun elapsedSecondsSince(startedAtMillis: Long, nowMillis: Long): Int {
    if (startedAtMillis <= 0L) {
        return 0
    }
    if (nowMillis <= startedAtMillis) {
        return 0
    }
    return ((nowMillis - startedAtMillis) / 1_000L).toInt()
}

/**
 * 与训练页顶栏同一格式：mm:ss，两位补零。
 *
 * `internal` 而非 `private`：纯字符串换算，值得被单测直接钉住边界
 * （0s / 59s / 60s / 大分钟），不必为测它去渲染一整条 Composable。
 */
internal fun formatElapsedClock(totalSeconds: Int): String {
    val minutes = totalSeconds / 60
    val seconds = totalSeconds % 60
    return "%02d:%02d".format(minutes, seconds)
}

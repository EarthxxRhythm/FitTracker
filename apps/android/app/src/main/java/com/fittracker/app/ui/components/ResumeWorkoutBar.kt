package com.fittracker.app.ui.components

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
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.fittracker.app.ui.theme.FtColor

/**
 * 悬浮条持有的最小草稿摘要。
 *
 * 只带展示需要的三个数，不把整个 `WorkoutDraftSnapshot` 传进 UI——悬浮条不该知道
 * 草稿的结构，否则将来草稿加字段时这里会被动跟着改。
 */
data class ResumeDraftSummary(
    val completedSets: Int,
    val totalSets: Int,
    val elapsedMinutes: Int,
)

/**
 * 「训练进行中」悬浮入口：贴在底栏上方，跨 Tab 常驻。
 *
 * 存在的理由（与鸿蒙 `PencilAppShell.resumeWorkoutBar` 同构）：首页卡片里的「开始训练」
 * 会随内容滚动移出视口，而「有一场没做完的训练」是需要持续可见的状态。
 *
 * 形态：胶囊贴底栏上沿、左右各 18 留白。底色用不透明的 `FtColor.surface`——
 * 半透明会让下面的 Tab 内容透上来，在深色页上读成脏色。
 */
@Composable
fun ResumeWorkoutBar(
    summary: ResumeDraftSummary,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = 18.dp)
            .height(56.dp)
            .shadow(elevation = 12.dp, shape = RoundedCornerShape(18.dp), clip = false)
            .clip(RoundedCornerShape(18.dp))
            .background(FtColor.surface)
            .border(width = 1.dp, color = FtColor.accent12, shape = RoundedCornerShape(18.dp))
            .clickable(onClick = onClick)
            .padding(horizontal = 14.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        // 呼吸点：与训练页顶栏计时点同一语汇——绿色实心小圆，表示「还在跑」
        Box(
            modifier = Modifier
                .size(6.dp)
                .clip(CircleShape)
                .background(FtColor.accent),
        )

        Column(
            modifier = Modifier.weight(1f),
            verticalArrangement = Arrangement.spacedBy(2.dp),
        ) {
            Text(
                text = "训练进行中",
                color = FtColor.txtHi,
                fontSize = 13.sp,
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

        Text(
            text = "继续",
            color = FtColor.onAccent,
            fontSize = 12.sp,
            fontWeight = FontWeight.Bold,
            modifier = Modifier
                .clip(RoundedCornerShape(999.dp))
                .background(FtColor.accent)
                .padding(horizontal = 14.dp, vertical = 7.dp),
        )
    }
}

/** 副行文案：「已做 3/12 组 · 32 分钟」；时长为 0 时只报组数。 */
private fun captionOf(summary: ResumeDraftSummary): String {
    val sets = "已做 ${summary.completedSets}/${summary.totalSets} 组"
    return if (summary.elapsedMinutes > 0) "$sets · ${summary.elapsedMinutes} 分钟" else sets
}

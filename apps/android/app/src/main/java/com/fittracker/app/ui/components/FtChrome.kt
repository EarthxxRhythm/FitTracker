package com.fittracker.app.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.fittracker.app.ui.theme.FtColor
import com.fittracker.app.ui.theme.FtShape
import com.fittracker.app.ui.theme.FtSpace

/**
 * 页头（见 `design/04_component_specs/page_headers.md`）。
 *
 * 高度纪律：页头不得占掉首屏过多空间，任务型页面（如训练执行）尤其要收紧。
 * 各屏按需组合元素；不使用的部分传 `null` 即可。
 */
@Composable
fun FtPageHeader(
    title: String,
    modifier: Modifier = Modifier,
    eyebrow: String? = null,
    support: String? = null,
    status: String? = null,
) {
    Column(modifier = modifier) {
        if (eyebrow != null) {
            Text(
                text = eyebrow,
                color = FtColor.white54,
                fontSize = 13.sp,
                lineHeight = 18.sp,
                letterSpacing = 0.26.sp,
            )
        }
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(FtSpace.sm),
            modifier = Modifier.padding(top = if (eyebrow != null) 6.dp else 0.dp),
        ) {
            Text(
                text = title,
                color = FtColor.txtHi,
                fontSize = 18.sp,
                lineHeight = 24.sp,
                fontWeight = FontWeight.Bold,
            )
            if (status != null) {
                FtChip(text = status, tone = FtChipTone.Accent)
            }
        }
        if (support != null) {
            Text(
                text = support,
                color = FtColor.white60,
                fontSize = 15.sp,
                lineHeight = 24.sp, // 原型 line-height 1.6 × 15px
                modifier = Modifier.padding(top = FtSpace.sm),
            )
        }
    }
}

/** 标签语气。 */
enum class FtChipTone {
    /** 中性面 */
    Neutral,

    /** 强调（青翠） */
    Accent,

    /** 稀有 / 高价值（金） */
    Gold,
}

/** 小标签 / 徽章。 */
@Composable
fun FtChip(
    text: String,
    modifier: Modifier = Modifier,
    tone: FtChipTone = FtChipTone.Neutral,
) {
    val shape = RoundedCornerShape(999.dp)
    val (bg, fg, border) = when (tone) {
        FtChipTone.Neutral -> Triple(FtColor.glass6, FtColor.white70, FtColor.hairline)
        FtChipTone.Accent -> Triple(FtColor.accent12, FtColor.accent, Color.Transparent)
        FtChipTone.Gold -> Triple(FtColor.gold12, FtColor.gold, Color.Transparent)
    }
    Row(
        modifier = modifier
            .clip(shape)
            .background(bg)
            .then(if (border != Color.Transparent) Modifier.border(1.dp, border, shape) else Modifier)
            .padding(horizontal = FtSpace.md, vertical = 4.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            text = text,
            color = fg,
            fontSize = 11.sp,
            lineHeight = 14.sp,
            fontWeight = FontWeight.SemiBold,
        )
    }
}

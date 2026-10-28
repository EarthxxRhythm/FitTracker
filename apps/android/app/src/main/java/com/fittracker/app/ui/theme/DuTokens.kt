package com.fittracker.app.ui.theme

import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp

/**
 * 按钮物理厚度令牌（Duolingo 形态语汇）——与 Harmony 侧 `DuTokens.ets` 同值。
 *
 * ── 作用边界 ──────────────────────────────────────────────────
 * **只承载「厚度」这一个维度**，不持有任何颜色值。
 *
 * 配色**刻意保持原型基线**：主色仍是 `FtColor.accent`（`#50ECA7` 冷翡翠），
 * 厚底取同色系深阶 `FtColor.accentDeep`（`#45C9A1`）。
 *
 * Duolingo 的「可按的 3D 按钮」本质是**形态**，亮绿只是它的配色选型；
 * 本项目已有经 13 屏原型对齐验证的配色基线，故只借形态、不动配色。
 *
 * ── 为什么用 drawBehind 而不是 border ─────────────────────────
 * Compose 的 `Modifier.border` 只能四边同宽，无法只画底边。
 * 故用 `drawBehind` 绘制底部色条 + `padding(bottom = depth)` 让内容避让，
 * 等价于 CSS `border-bottom: 4px solid`。
 */
object DuTokens {

    /**
     * 常态底部实心厚度。
     * 主操作按钮用此值；按下时收平至 0，形成"被按进面板"的观感。
     */
    val PRESS_DEPTH: Dp = 4.dp

    /** 按下时整体下移量：与厚边收平配合 */
    val PRESS_SHIFT: Dp = 2.dp

    /** 次要按钮的厚底厚度（本档未启用，预留） */
    val PRESS_DEPTH_SOFT: Dp = 3.dp
}

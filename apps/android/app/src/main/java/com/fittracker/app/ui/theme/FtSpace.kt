package com.fittracker.app.ui.theme

import androidx.compose.ui.unit.dp

/**
 * 间距与触摸尺寸令牌。
 *
 * 数值取自原型 13 个屏的 CSS 实测分布（`gap` / `padding` 字面值）：
 * `gap` 高频值 8 / 10 / 12 / 40 / 14 / 6 / 7 / 5 / 16 / 36；
 * `padding` 高频值 8 / 10 / 48 / 12 / 32 / 16 / 24 / 6 / 30 / 4 / 20。
 * 此处收敛为可用刻度，屏内个别特殊值就地直写，不强塞进刻度。
 */
object FtSpace {

    /** 页面左右 gutter（还原规则 `SpacingTokens.PAGE_GUTTER`） */
    val pageGutter = 16.dp

    val xxs = 2.dp
    val xs = 4.dp
    val s = 6.dp
    val sm = 8.dp
    val md = 10.dp
    val ml = 12.dp
    val lg = 14.dp
    val xl = 16.dp
    val xxl = 20.dp
    val xxxl = 24.dp

    /** 区块间大分隔 */
    val section = 30.dp
    val sectionLg = 36.dp
    val sectionXl = 40.dp

    /** 触摸目标最小边长（Material 无障碍下限） */
    val touchMin = 48.dp

    /** 常见可点击行高 */
    val rowMin = 44.dp
}

package com.fittracker.app.ui.theme

import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.ui.unit.dp

/**
 * 圆角令牌。
 *
 * 数值取自原型 13 个屏的 `border-radius` 实测分布：
 * 999（胶囊，56 次）、18、54（整机圆角）、16、44、14、12、22、3、9、26、25.4、10、28。
 */
object FtShape {

    /** 微圆角（热力图格、进度条端） */
    val xs = RoundedCornerShape(3.dp)

    /** 小组件（图标底、小标签） */
    val s = RoundedCornerShape(9.dp)
    val sm = RoundedCornerShape(10.dp)

    /** 标准卡片 / 按钮 */
    val md = RoundedCornerShape(12.dp)
    val lg = RoundedCornerShape(14.dp)

    /** 强调卡片 / 面板 */
    val xl = RoundedCornerShape(16.dp)
    val xxl = RoundedCornerShape(18.dp)

    /** 大面板 / 弹层 */
    val panel = RoundedCornerShape(22.dp)
    val panelLg = RoundedCornerShape(26.dp)

    /** 底栏中央胶囊 */
    val centerPill = RoundedCornerShape(18.dp)

    /** 大视觉卡（原型 `.w-visual` 的 `border-radius: 30px`） */
    val section30 = RoundedCornerShape(30.dp)

    /** 整机画布圆角（原型 `.phone` 为 54px） */
    val device = RoundedCornerShape(54.dp)

    /** 胶囊 */
    val pill = RoundedCornerShape(999.dp)
}

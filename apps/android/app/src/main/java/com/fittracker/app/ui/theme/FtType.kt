package com.fittracker.app.ui.theme

import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.sp

/**
 * 字体令牌。
 *
 * 字号/字重/行高取自原型 13 个屏的 CSS 实测分布：
 * 字号高频 13 / 12 / 11 / 15 / 14 / 10 / 16 / 17 / 18 / 20 / 21；
 * 字重仅 400 / 500 / 600 / 700；行高 1.0 / 1.18 / 1.2 / 1.4 / 1.5 / 1.6 / 1.7。
 *
 * 字体族的已知差异（未消解，属诚实标注的遗留项）：
 * - `--font-cn` 原型首选 Noto Sans SC；Android 中文默认即 Noto Sans CJK，**近似一致**。
 * - `--font-num` 原型首选 Inter；本工程**未内嵌** Inter，回落系统默认（Roboto），字形有细微差异。
 * - `--font-mono` 原型首选 Geist Mono；回落 `FontFamily.Monospace`。
 */
object FtType {

    /** 中文正文族 */
    val cn: FontFamily = FontFamily.Default

    /** 数字族（原型 Inter；未内嵌，回落系统默认） */
    val num: FontFamily = FontFamily.Default

    /** 等宽族 */
    val mono: FontFamily = FontFamily.Monospace

    /**
     * 保真优先的构造器：直接使用原型 CSS 的字面值，不做刻度归一。
     * 屏内特殊字号一律走这里，避免「看起来差不多」的近似。
     */
    fun ft(
        size: Float,
        weight: Int = 400,
        lineHeight: Float? = null,
        family: FontFamily = cn,
    ): TextStyle = TextStyle(
        fontFamily = family,
        fontSize = size.sp,
        fontWeight = FontWeight(weight),
        lineHeight = (lineHeight ?: (size * 1.4f)).sp,
    )

    /**
     * 原型**未声明** `line-height` 的文本样式，即 CSS 的 `normal`（字体自然行高）。
     *
     * [ft] 的缺省 `1.4 × size` 是给共享组件的刻度化默认值，**不可**用于屏内逐字还原：
     * 每行多出 2–4px，十余处叠加即累积成整屏下移（login 屏实测 +29px、plan 屏 +21px）。
     * 原型显式声明了行高处仍按字面值给定，不走本函数。
     *
     * 注：`ui/screens/auth/AuthComponents.kt` 与 `ui/screens/plan/PlanScreen.kt` 各有一份
     * 等价的 private 实现——那是抽象之前的重复，待后续波次统一收编到此处。
     */
    fun natural(
        size: Float,
        weight: Int = 400,
        family: FontFamily = cn,
    ): TextStyle = TextStyle(
        fontFamily = family,
        fontSize = size.sp,
        fontWeight = FontWeight(weight),
        lineHeight = TextUnit.Unspecified,
    )

    // ── 语义角色（供共享组件使用） ────────────────────────────
    /** 微型标签：10px */
    val micro: TextStyle = ft(10f, 700, 12f)
    /** 标签：11px */
    val label: TextStyle = ft(11f, 500, 14f)
    /** 说明文字：12px */
    val caption: TextStyle = ft(12f, 400, 16f)
    /** 强调说明：13px */
    val captionStrong: TextStyle = ft(13f, 600, 18f)
    /** 正文：14px */
    val body: TextStyle = ft(14f, 400, 20f)
    /** 正文加强：15px */
    val bodyLg: TextStyle = ft(15f, 500, 22f)
    /** 标题：16px */
    val title: TextStyle = ft(16f, 600, 22f)
    /** 大标题：17px */
    val titleLg: TextStyle = ft(17f, 700, 24f)
    /** 页头：18px */
    val headline: TextStyle = ft(18f, 700, 24f)
    /** 展示数字：21px */
    val display: TextStyle = ft(21f, 700, 26f, num)

    /** 便捷：把 `sp` 值显式传入（屏内直写时用） */
    fun sp(value: Float): TextUnit = value.sp
}

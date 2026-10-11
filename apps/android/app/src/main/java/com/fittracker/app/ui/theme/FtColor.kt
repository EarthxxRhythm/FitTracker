package com.fittracker.app.ui.theme

import androidx.compose.ui.graphics.Color

/**
 * CSS 颜色换算工具。
 *
 * 原型以 `rgba(r,g,b,a)` 声明颜色，Compose 需要 `0xAARRGGBB`。
 * 换算规则：`AA = round(a * 255)`。
 */
object FtColorUtil {

    /** `a` 通道（0.0–1.0）换算为 0–255 整数，四舍五入。 */
    fun alpha(a: Double): Int = Math.round(a * 255.0).toInt()

    /** `rgba(r,g,b,a)` → `0xAARRGGBB` 长整型。 */
    fun rgba(r: Int, g: Int, b: Int, a: Double): Long =
        (alpha(a).toLong() shl 24) or
            (r.toLong() shl 16) or
            (g.toLong() shl 8) or
            b.toLong()
}

/**
 * FitTracker 颜色令牌。
 *
 * 取值来源：原型各屏 `:root` 的 CSS 变量，规范值汇总见
 * `design/06_prototype_redraw/TOKENS.md`。
 * 跨屏存在极少数漂移（`--bg` / `--hairline` / `--surface` 等），此处一律取**多数屏的规范值**；
 * 单屏专属值以屏名前缀命名，避免污染全局语义。
 */
object FtColor {

    // ── 强调色 ────────────────────────────────────────────────
    val accent: Color = Color(0xFF50ECA7)
    val accentDeep: Color = Color(0xFF45C9A1)
    val accentSoft: Color = Color(0xFF8CEBCC)
    val onAccent: Color = Color(0xFF07100B)
    val onAccent2: Color = Color(0xFF08110D)

    val accent07: Color = Color(FtColorUtil.rgba(80, 236, 167, 0.07))
    val accent10: Color = Color(FtColorUtil.rgba(80, 236, 167, 0.10))
    val accent12: Color = Color(FtColorUtil.rgba(80, 236, 167, 0.12))
    val accent17: Color = Color(FtColorUtil.rgba(80, 236, 167, 0.17))
    val accent18: Color = Color(FtColorUtil.rgba(69, 201, 161, 0.18))
    val accent20: Color = Color(FtColorUtil.rgba(80, 236, 167, 0.20))
    val accent32: Color = Color(FtColorUtil.rgba(69, 201, 161, 0.32))
    val accent40: Color = Color(FtColorUtil.rgba(80, 236, 167, 0.40))

    // ── CTA 渐变 ──────────────────────────────────────────────
    val ctaA: Color = Color(0xFF47D994)
    val ctaB: Color = Color(0xFF53E7A5)
    val ctaHoverA: Color = Color(0xFF5BE3A5)
    val ctaHoverB: Color = Color(0xFF6BEDB5)

    // ── 背景层 ────────────────────────────────────────────────
    // 用户要求（全部屏）：深色去色相（R=G=B），保留明度阶梯
    val bg: Color = Color(0xFF0F0F0F)
    val ink0: Color = Color(0xFF0F0F0F)
    val ink1: Color = Color(0xFF0F0F0F)
    val inkWelcome0: Color = Color(0xFF0F0F0F)
    val surface: Color = Color(0xFF171717)
    val surface2: Color = Color(0xFF1C1C1C)

    // ── 文本 ──────────────────────────────────────────────────
    val txtHi: Color = Color(0xFFF7FBF8)
    val txtBody: Color = Color(0xFFEDF6F2)

    // ── 导航 ──────────────────────────────────────────────────
    val navActive: Color = Color(0xFFF3FBF7)
    val navInactive: Color = Color(FtColorUtil.rgba(243, 251, 247, 0.56))

    // ── 视觉卡 / 装饰 ─────────────────────────────────────────
    val visualA: Color = Color(0xFF1E1E1E)
    val visualB: Color = Color(0xFF141414)
    val ringInner: Color = Color(0xFF111111)

    // ── 玻璃与描边 ────────────────────────────────────────────
    val hairline: Color = Color(FtColorUtil.rgba(255, 255, 255, 0.06))
    val line10: Color = Color(FtColorUtil.rgba(255, 255, 255, 0.10))
    val line14: Color = Color(FtColorUtil.rgba(255, 255, 255, 0.078))
    val line16: Color = Color(FtColorUtil.rgba(255, 255, 255, 0.16))
    val glass4: Color = Color(FtColorUtil.rgba(255, 255, 255, 0.04))
    val glass6: Color = Color(FtColorUtil.rgba(255, 255, 255, 0.06))
    val glass8: Color = Color(FtColorUtil.rgba(255, 255, 255, 0.08))
    val glass10: Color = Color(FtColorUtil.rgba(255, 255, 255, 0.10))

    // ── 半透明白阶 ────────────────────────────────────────────
    val white32: Color = Color(FtColorUtil.rgba(255, 255, 255, 0.32))
    val white40: Color = Color(FtColorUtil.rgba(255, 255, 255, 0.40))
    val white48: Color = Color(FtColorUtil.rgba(255, 255, 255, 0.478))
    val white54: Color = Color(FtColorUtil.rgba(255, 255, 255, 0.54))
    val white56: Color = Color(FtColorUtil.rgba(255, 255, 255, 0.561))
    val white60: Color = Color(FtColorUtil.rgba(255, 255, 255, 0.60))
    val white62: Color = Color(FtColorUtil.rgba(255, 255, 255, 0.62))
    val white65: Color = Color(FtColorUtil.rgba(255, 255, 255, 0.65))
    val white70: Color = Color(FtColorUtil.rgba(255, 255, 255, 0.70))
    val white87: Color = Color(FtColorUtil.rgba(255, 255, 255, 0.87))
    val white90: Color = Color(FtColorUtil.rgba(243, 251, 247, 0.90))

    // ── 训练完成页专属 ────────────────────────────────────────
    val completeBg: Color = Color(0xFF0D0D0D)
    val completeCheck: Color = Color(0xFF7EF0CB)
    val completeCircle: Color = Color(0xFF242424)
    val completeCircleBorder: Color = Color(FtColorUtil.rgba(80, 236, 167, 0.23))
    val completeSub: Color = Color(FtColorUtil.rgba(255, 255, 255, 0.72))

    // ── 首页 / 回顾页专属 ─────────────────────────────────────
    val tabPill: Color = Color(0xFF1D1D1D)
    val tabPillActive: Color = Color(0xFF232323)
    val statBg: Color = Color(0xFF181818)
    val streakBg: Color = Color(0xFF1C1C1C)
    val streakSurface: Color = Color(0xFF1C1C1C)
    val streakDayOn: Color = Color(0xFF50ECA7)
    val streakDayOff: Color = Color(FtColorUtil.rgba(255, 255, 255, 0.078))
    val surfaceStat: Color = Color(0xFF1D1D1D)

    // ── 状态 / 稀有强调 ───────────────────────────────────────
    val warn: Color = Color(0xFFFFD7C5)
    val warnBorder: Color = Color(FtColorUtil.rgba(255, 176, 150, 0.55))
    val gold: Color = Color(0xFFD3B487)
    val gold12: Color = Color(FtColorUtil.rgba(211, 180, 135, 0.12))
}

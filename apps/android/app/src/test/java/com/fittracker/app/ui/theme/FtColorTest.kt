package com.fittracker.app.ui.theme

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * 令牌色值换算测试。
 *
 * 原型的颜色以 CSS `rgba(r,g,b,a)` 声明，Compose 需要 `0xAARRGGBB`。
 * 换算规则（见计划）：`AA = round(a * 255)`。
 * 这些断言把「换算规则」与「若干关键令牌的最终字面值」同时钉住。
 */
class FtColorTest {

    @Test
    fun `alpha 通道按四舍五入换算`() {
        assertEquals(0, FtColorUtil.alpha(0.0))
        assertEquals(255, FtColorUtil.alpha(1.0))
        assertEquals(15, FtColorUtil.alpha(0.06))   // 15.30
        assertEquals(31, FtColorUtil.alpha(0.12))   // 30.60
        assertEquals(46, FtColorUtil.alpha(0.18))   // 45.90
        assertEquals(51, FtColorUtil.alpha(0.20))   // 51.00
        assertEquals(102, FtColorUtil.alpha(0.40))  // 102.00
        assertEquals(143, FtColorUtil.alpha(0.56))  // 142.80
        assertEquals(179, FtColorUtil.alpha(0.70))  // 178.50，半值向上
        assertEquals(230, FtColorUtil.alpha(0.90))  // 229.50
    }

    @Test
    fun `rgba 合成 ARGB 长整型`() {
        assertEquals(0x8FFFFFFFL, FtColorUtil.rgba(255, 255, 255, 0.56))
        assertEquals(0x1F50ECA7L, FtColorUtil.rgba(80, 236, 167, 0.12))
        assertEquals(0x0FFFFFFFL, FtColorUtil.rgba(255, 255, 255, 0.06))
        assertEquals(0x8AF3FBF7L, FtColorUtil.rgba(243, 251, 247, 0.54))
        assertEquals(0x2E45C9A1L, FtColorUtil.rgba(69, 201, 161, 0.18))
        assertEquals(0xE6F3FBF7L, FtColorUtil.rgba(243, 251, 247, 0.90))
    }

    @Test
    fun `核心不透明令牌取值与原型 root 变量一致`() {
        assertEquals(0xFF50ECA7L, FtColor.accent.value.toLong() ushr 32)
        assertEquals(0xFF45C9A1L, FtColor.accentDeep.value.toLong() ushr 32)
        assertEquals(0xFF8CEBCCL, FtColor.accentSoft.value.toLong() ushr 32)
        assertEquals(0xFF07100BL, FtColor.onAccent.value.toLong() ushr 32)
        assertEquals(0xFF0F0F0FL, FtColor.ink0.value.toLong() ushr 32)
        assertEquals(0xFF0F0F0FL, FtColor.ink1.value.toLong() ushr 32)
        assertEquals(0xFF0F0F0FL, FtColor.bg.value.toLong() ushr 32)
        assertEquals(0xFF171717L, FtColor.surface.value.toLong() ushr 32)
        assertEquals(0xFF1C1C1CL, FtColor.surface2.value.toLong() ushr 32)
        assertEquals(0xFFF7FBF8L, FtColor.txtHi.value.toLong() ushr 32)
        assertEquals(0xFFEDF6F2L, FtColor.txtBody.value.toLong() ushr 32)
        assertEquals(0xFFF3FBF7L, FtColor.navActive.value.toLong() ushr 32)
        assertEquals(0xFF1E1E1EL, FtColor.visualA.value.toLong() ushr 32)
        assertEquals(0xFF141414L, FtColor.visualB.value.toLong() ushr 32)
        assertEquals(0xFF47D994L, FtColor.ctaA.value.toLong() ushr 32)
        assertEquals(0xFF53E7A5L, FtColor.ctaB.value.toLong() ushr 32)
    }

    @Test
    fun `半透明白与描边令牌取值与原型 root 变量一致`() {
        assertEquals(0xB3FFFFFFL, FtColor.white70.value.toLong() ushr 32)
        assertEquals(0x8AFFFFFFL, FtColor.white54.value.toLong() ushr 32)
        assertEquals(0x66FFFFFFL, FtColor.white40.value.toLong() ushr 32)
        assertEquals(0x52FFFFFFL, FtColor.white32.value.toLong() ushr 32)
        assertEquals(0x0FFFFFFFL, FtColor.hairline.value.toLong() ushr 32)
        assertEquals(0x1AFFFFFFL, FtColor.line10.value.toLong() ushr 32)
        assertEquals(0x14FFFFFFL, FtColor.line14.value.toLong() ushr 32)
        assertEquals(0x29FFFFFFL, FtColor.line16.value.toLong() ushr 32)
        assertEquals(0x1F50ECA7L, FtColor.accent12.value.toLong() ushr 32)
        assertEquals(0x3350ECA7L, FtColor.accent20.value.toLong() ushr 32)
        assertEquals(0x6650ECA7L, FtColor.accent40.value.toLong() ushr 32)
        assertEquals(0x8FF3FBF7L, FtColor.navInactive.value.toLong() ushr 32)
    }
}

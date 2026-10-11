package com.fittracker.app.ui.screens.review

import androidx.compose.ui.graphics.Color
import com.fittracker.app.ui.theme.FtColor

/**
 * 回顾屏的**预计算色值**——原型的 `color-mix()` 一律不运行时混色，全部算成静态常量。
 *
 * 换算规则：`color-mix(in srgb, A p%, B (100−p)%)` 按 **premultiplied alpha** 插值
 * （CSS Color 5 的默认），即先 `(r·a, g·a, b·a, a)` 加权、再除回 alpha。
 * 两个操作数都不透明时它就退化成普通加权平均（本文件多数取值属于这种）；
 * 只有月历格子那几处第二操作数是 `rgba(255,255,255,.055)`（近透明），
 * premultiply 才有实质差别——那些值我按 premultiply 算并单独标注。
 *
 * 来源：原型 `fittracker-review.html` 的 `.openstats` 作用域 token（L905-940 区段）与
 * `.month-cal` 规则（L380-430）。
 */
internal object FtReviewColors {

    // ── openstats 作用域 token（原型 L905-940） ──────────────────
    /** `--surface`（`--bg-el` 之上的分层底色） */
    val surface = Color(0xFF171D24)

    /** `--surface-2` */
    val surface2 = Color(0xFF20272F)

    /** `--label` */
    val label = Color(0xFFF7FBF8)

    /** `--label-2` = rgba(243,251,247,.62) */
    val label2 = Color(0x9EF3FBF7)

    /** `--label-3` = rgba(243,251,247,.40) */
    val label3 = Color(0x66F3FBF7)

    val acc = FtColor.accent
    val red = Color(0xFFF0A48A)
    val orange = Color(0xFFE5B878)
    val yellow = Color(0xFFD9C86B)

    // ── 肌肉地图填充 ──────────────────────────────────────────────

    /** `--bm-base: color-mix(label 11%, surface)` → (48,53,59) */
    val bmBase = Color(0xFF30353B)

    /** `.bm-sil: color-mix(label 18%, surface)` → (63,69,74) */
    val bmSil = Color(0xFF3F454A)

    /** 肌肉轮廓描边 `.bm-v path { stroke: var(--surface) }` */
    val bmStroke = surface

    /** 选中描边 `.bm-m.sel { stroke: var(--label); stroke-width: 7 }` */
    val bmSelStroke = label

    /** `.bm-v path { stroke-width: 2.5 }`（设计空间单位） */
    const val BM_STROKE_W = 2.5f

    /** `.bm-m.sel { stroke-width: 7 }` */
    const val BM_SEL_STROKE_W = 7f

    /**
     * 四个等级的肌肉填充色。
     *
     * `balance` / `strength` 共用 l1–l3 的翡翠梯度，唯一差别在 l4；
     * `fatigue` 整套换成暖色（红/橙/黄）。
     */
    fun muscleFill(mode: MuscleMode, level: Int): Color = when (mode) {
        MuscleMode.BALANCE -> balanceLevels[level.coerceIn(0, 4)]
        MuscleMode.STRENGTH -> strengthLevels[level.coerceIn(0, 4)]
        MuscleMode.FATIGUE -> fatigueLevels[level.coerceIn(0, 4)]
    }

    /** `l1 = color-mix(acc 32%, --bm-base)` → (58,112,94) */
    private val l1 = Color(0xFF3A705E)

    /** `l2 = color-mix(acc 56%, --bm-base)` → (66,155,119) */
    private val l2 = Color(0xFF429B77)

    /** `l3 = color-mix(acc 78%, --bm-base)` → (73,196,143) */
    private val l3 = Color(0xFF49C48F)

    private val balanceLevels = listOf(bmBase, l1, l2, l3, acc)

    /** strength 只把 l4 换成黄色（`.hm-strength .bm-m.l4 { fill: var(--yellow) }`）。 */
    private val strengthLevels = listOf(bmBase, l1, l2, l3, yellow)

    /** `hm-fatigue`：l1 = color-mix(yellow 32%, --bm-base) → (102,100,74)。 */
    private val fatigueLevels = listOf(bmBase, Color(0xFF66644A), yellow, orange, red)

    // ── 肌肉地图图例方块（`.openstats .hm-c`，10×10） ────────────

    /** 底 `.hm-c { background: var(--surface-2) }` */
    val legendBase = surface2

    fun legendFill(mode: MuscleMode, level: Int): Color = when (mode) {
        MuscleMode.BALANCE -> legendBalance[level.coerceIn(0, 4)]
        MuscleMode.STRENGTH -> legendStrength[level.coerceIn(0, 4)]
        MuscleMode.FATIGUE -> legendFatigue[level.coerceIn(0, 4)]
    }

    /** `l1 = color-mix(acc 32%, --surface-2)` → (47,102,85) */
    private val legendL1 = Color(0xFF2F6655)

    /** `l2 = color-mix(acc 56%, --surface-2)` → (59,149,114) */
    private val legendL2 = Color(0xFF3B9572)

    /** `l3 = color-mix(acc 78%, --surface-2)` → (69,193,141) */
    private val legendL3 = Color(0xFF45C18D)

    private val legendBalance = listOf(legendBase, legendL1, legendL2, legendL3, acc)

    /** `.hm-strength .hm-c.l4 { background: var(--yellow) }`（l1–l3 与 balance 同）。 */
    private val legendStrength = listOf(legendBase, legendL1, legendL2, legendL3, yellow)

    /** `.hm-fatigue`：l4→red、l3→orange、l2→yellow；**l1 未覆盖，仍取翡翠档**。 */
    private val legendFatigue = listOf(legendBase, legendL1, yellow, orange, red)

    // ── 月历格子（`.month-cal .mcal-cell`，L372-405） ────────────

    /** 底 `.mcal-cell { background: rgba(255,255,255,.035); border: 1px solid rgba(255,255,255,.06) }` */
    val mcalBg = Color(0x09FFFFFF)
    val mcalBorder = Color(0x0FFFFFFF)
    val mcalText = FtColor.white70
    val mcalTextOn = FtColor.onAccent

    /**
     * l1–l3 的第二操作数是 `rgba(255,255,255,.055)`（**近透明**），
     * 按 premultiplied 插值算出来的结果与「普通加权」差很远——这里用的是 premultiplied。
     */
    fun mcalFill(level: Int): Color = mcalLevels[level.coerceIn(0, 4)]

    private val mcalLevels = listOf(
        mcalBg,
        Color(0x4D68EFB3), // l1 = color-mix(acc 26%, rgba(255,255,255,.055)) premult → (104,239,179,α77)
        Color(0x8759EDAC), // l2 = 50% → (89,237,172,α135)
        Color(0xC053ECA9), // l3 = 74% → (83,236,169,α192)
        acc,               // l4 = var(--accent)
    )

    /**
     * 月历图例方块。
     *
     * ⚠ 原型里这五个方块**都是同一个浅白色**：`.month-cal .month-legend .ml .hm-c`
     * （4 个类，特异性 0,4,0）压过了 `.month-cal .hm-c.lN`（3 个类）的 `background`，
     * 于是等级色根本没生效。这是层叠结果、不是笔误——如实还原，并在此标注。
     */
    val monthLegendSwatch = Color(0x0DFFFFFF)
}

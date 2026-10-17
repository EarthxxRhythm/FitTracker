/**
 * Pencil 主线视觉令牌（集中声明层）。
 *
 * 存在理由：项目约束写着「通用组件优先使用 DesignTokens；**Pencil 主线允许使用 feature 内
 * 集中声明的视觉 token**，不要在单个组件中散落魔法值」。此前这一集中层并不存在——
 * `features/pencil/` 下 11 个 UI 文件散落着 600 处十六进制字面量，无一处可追溯。
 *
 * ── 取值纪律：值一字不改 ───────────────────────────────────────────
 * 本文件只做「名 -> 值」的集中，不做归一化、不调色、不改动任何像素。
 * 全部取值来自冻结原型 `design/06_prototype_redraw/src/*.html` 的 `:root`（规范值汇总见
 * 同目录 `TOKENS.md`）。替换后视觉必须零变化，这是本重构唯一的验收前提。
 *
 * ── 与 common/styles/DesignTokens.ets 的关系（重要）─────────────────
 * 两者**不同值且不应合并**：
 *   - `DesignTokens` 是通用组件令牌，其 BG/TEXT 族存的是**旧值**（BG_PRIMARY #09100F、
 *     TEXT_ON_DARK #F3FBF7）。
 *   - 本主线用的是**原型规范值**（BG_INK #0B0F13、TEXT_HI #F7FBF8）。
 *   `TOKENS.md` §5 已裁决「还原屏时优先页面级直写，不做全局覆盖」——因为全局覆盖会冲击
 *   通用组件与既有像素基线。故本主线持有自己的原值副本。
 *
 * 因此 `PencilTokens.ACCENT` 与 `ColorTokens.ACCENT_PRIMARY` **同值**（都是 #50ECA7），
 * 但 `PencilTokens.BG_INK` 与 `ColorTokens.BG_PRIMARY` **不同值**——这是已知且**有意**的，
 * 不是漂移缺陷。**不要**把本文件的值"对齐"到 DesignTokens，也不要反向覆盖 DesignTokens。
 *
 * ── 覆盖范围 ──────────────────────────────────────────────────────
 * 37 个成员覆盖 pencil 全部 600 处字面量的 82.5%；其余为出现 <2 次的屏内专属值
 * （个别动画关键帧色、单屏特例），按原约束「屏内特殊值就地直写」保留，不强塞进本表。
 */

export class PencilTokens {

  // ── 强调色族（原型 --accent / --accent-deep / --accent-soft）──────
  /** `--accent` 主强调色——能源信号，只用于焦点信息与激活态 */
  static readonly ACCENT: string = '#50ECA7'
  /** `--accent-deep` 深强调（按压态、次级强调） */
  static readonly ACCENT_DEEP: string = '#45C9A1'
  /** `--accent-soft` 柔强调（辉光、高亮） */
  static readonly ACCENT_SOFT: string = '#8CEBCC'

  // ── 强调色 alpha 阶（#AARRGGBB，前缀两位为 alpha）─────────────────
  /** alpha 0.00 */
  static readonly ACCENT_A00: string = '#0050ECA7'
  /** alpha 0.05 */
  static readonly ACCENT_A05: string = '#0D50ECA7'
  /** alpha 0.07 */
  static readonly ACCENT_A07: string = '#1250ECA7'
  /** alpha 0.10 */
  static readonly ACCENT_A10: string = '#1A50ECA7'
  /** alpha 0.12 */
  static readonly ACCENT_A12: string = '#1F50ECA7'
  /** alpha 0.20 */
  static readonly ACCENT_A20: string = '#3350ECA7'
  /** alpha 0.24 */
  static readonly ACCENT_A24: string = '#3D50ECA7'
  /** alpha 0.30 */
  static readonly ACCENT_A30: string = '#4D50ECA7'
  /** alpha 0.45 */
  static readonly ACCENT_A45: string = '#7350ECA7'

  // ── 文本基色 ────────────────────────────────────────────────────
  /** `--txt-hi` 最高层级文本（标题、关键数值） */
  static readonly TEXT_HI: string = '#F7FBF8'
  /** `--on-accent` 强调色面之上的深色文本 */
  static readonly TEXT_ON_ACCENT: string = '#07100B'

  // ── 背景 / 表面基色 ─────────────────────────────────────────────
  /** `--ink-0` 页面背景主色 */
  static readonly BG_INK: string = '#0B0F13'
  /** `--ink-welcome-0` 欢迎页背景 */
  static readonly BG_INK_WELCOME: string = '#10171B'
  /** `--ring-inner` 进度环内圈 */
  static readonly BG_RING_INNER: string = '#0D1117'

  // ── 白阶（半透明叠加层级，前缀两位为 alpha）───────────────────────
  /** alpha 0.00 */
  static readonly WHITE_A00: string = '#00FFFFFF'
  /** alpha 0.03 */
  static readonly WHITE_A03: string = '#08FFFFFF'
  /** alpha 0.05 */
  static readonly WHITE_A05: string = '#0CFFFFFF'
  /** alpha 0.05（与 A05 同值、原型中并存，保留原写法不合并） */
  static readonly WHITE_A05_ALT: string = '#0DFFFFFF'
  /** alpha 0.06 */
  static readonly WHITE_A06: string = '#0FFFFFFF'
  /** alpha 0.08 */
  static readonly WHITE_A08: string = '#14FFFFFF'
  /** alpha 0.10 */
  static readonly WHITE_A10: string = '#1AFFFFFF'
  /** alpha 0.40 */
  static readonly WHITE_A40: string = '#66FFFFFF'
  /** alpha 0.48 */
  static readonly WHITE_A48: string = '#7AFFFFFF'
  /** alpha 0.54 */
  static readonly WHITE_A54: string = '#8AFFFFFF'
  /** alpha 0.60 */
  static readonly WHITE_A60: string = '#99FFFFFF'
  /** alpha 0.62 */
  static readonly WHITE_A62: string = '#9EFFFFFF'
  /** alpha 0.70 */
  static readonly WHITE_A70: string = '#B3FFFFFF'
  /** alpha 0.82 */
  static readonly WHITE_A82: string = '#D1FFFFFF'

  // ── 黑阶与遮罩 ──────────────────────────────────────────────────
  /** 黑 alpha 0.24（分隔、压暗） */
  static readonly BLACK_A24: string = '#3D000000'
  /** 深层遮罩（原型 #F50A0D12：alpha 0.96 / 基色 #0A0D12） */
  static readonly SCRIM_DEEP: string = '#F50A0D12'
  /** 遮罩（原型 #D1080D11：alpha 0.82 / 基色 #080D11） */
  static readonly SCRIM_DARK: string = '#D1080D11'
  /** 全透明——同时收编原型的 `#00000000` 与 `rgba(0,0,0,0)` 两种写法 */
  static readonly TRANSPARENT: string = '#00000000'

  // ── 稀有 / 高价值强调（原型 --gold 系，仅用于 PR 与里程碑）─────────
  /** `--gold` 稀有强调 */
  static readonly GOLD: string = '#D3B487'
  /** 高亮金（PR 达成、庆祝态） */
  static readonly GOLD_BRIGHT: string = '#D9C86B'
}

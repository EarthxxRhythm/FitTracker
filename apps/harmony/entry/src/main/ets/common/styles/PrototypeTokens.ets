/**
 * 原型规范令牌（全应用共用的视觉基线层）。
 *
 * ── 为什么需要这一层 ──────────────────────────────────────────────
 * 冻结原型 `design/06_prototype_redraw/src/*.html` 的 `:root` 是唯一视觉规格源
 * （规范值汇总见 `TOKENS.md`）。但 `ColorTokens`（DesignTokens.ets）里的 BG/TEXT 族
 * 存的是**旧值**（BG_PRIMARY #09100F、TEXT_ON_DARK #F3FBF7），与原型已经漂移。
 * `TOKENS.md` §5 的裁决是「还原屏时优先页面级直写，**不做全局覆盖**」——因为全局覆盖会
 * 冲击通用组件与既有像素基线。于是各 feature 只能各自直写原型值，散落且不可追溯。
 *
 * 本文件把那些**原型规范值**集中成一层，供所有 feature 引用。它是原型的镜像，
 * 不是新的设计决策。
 *
 * ── 与 DesignTokens.ets 的关系（重要，勿"修复"）───────────────────
 * 两者**不同值且不应合并**：
 *   - `PrototypeTokens.ACCENT` 与 `ColorTokens.ACCENT_PRIMARY` **同值**（都是 #50ECA7）；
 *   - `PrototypeTokens.BG_INK`(#0B0F13) 与 `ColorTokens.BG_PRIMARY`(#09100F) **不同值**。
 * 这是已知且**有意**的，不是漂移缺陷——它正是 §5 裁决的直接后果。
 * **不要**把本文件的值"对齐"到 DesignTokens，也不要反向覆盖 DesignTokens。
 *
 * ── 取值纪律：值一字不改 ──────────────────────────────────────────
 * 本文件只做「名 -> 值」的集中，不做归一化、不调色、不改动任何像素。
 * 任何引用方的替换都必须是**语义零变化**的，这是该重构唯一的验收前提。
 *
 * ── 覆盖范围与来源 ────────────────────────────────────────────────
 * 成员取自冻结原型 `:root`，并在 `features/pencil/`（600 处字面量）上完成首次落地，
 * 覆盖其中 82.5%；其余为出现 <2 次的屏内专属值（个别动画关键帧色、单屏特例），
 * 按原约束「屏内特殊值就地直写」保留。
 *
 * ── 「提 token」的判据（勿与屏内特殊值混淆）────────────────────────
 * 判据是**原型跨屏分布**，不是鸿蒙代码里的复用频次：
 *   - 原型 `:root` 在多个屏共用，或某组件的规范变量 → 收进本表，即使鸿蒙侧当前
 *     只有 1 处引用（如 `WARN`、`SURFACE_2`）；
 *   - 只在单屏出现一次、且无原型变量名的局部色 → 就地直写，配注释说明来源。
 *
 * 跨目录复用实测（命中率 = 同值字面量可映射到本表成员的比例）：
 *   body 85% / settings 81% / workout 71% / welcome 70%；合计 196/269 = 73%。
 * 其余 feature 尚未迁移，新增 UI 请直接引用本表。
 */

export class PrototypeTokens {

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

  // ── 强调色 alpha 阶（补充，Wave 1 由 body/workout 实测反推）────────
  /** alpha 0.06（原型 rgba(80,236,167,.06)） */
  static readonly ACCENT_A06: string = '#0F50ECA7'
  /** alpha 0.22（原型 rgba(80,236,167,.22)） */
  static readonly ACCENT_A22: string = '#3850ECA7'
  /** alpha 0.23（原型 `--complete-circle-border` rgba(80,236,167,.23)） */
  static readonly ACCENT_A23: string = '#3B50ECA7'
  /** alpha 0.50（原型 rgba(80,236,167,.50)） */
  static readonly ACCENT_A50: string = '#8050ECA7'

  // ── 文本基色 ────────────────────────────────────────────────────
  /** `--txt-hi` 最高层级文本（标题、关键数值） */
  static readonly TEXT_HI: string = '#F7FBF8'
  /** `--on-accent` 强调色面之上的深色文本 */
  static readonly TEXT_ON_ACCENT: string = '#07100B'

  // ── 警示色（原型 `--warn`，14 个原型屏文件 `:root` 同值共用）─────────
  /**
   * `--warn` 警示色：告警文本与告警填充。
   *
   * **原型分布**：原型 `src/` 中 14 个屏文件（auth / body-data / brand-identity /
   * exercise-library / personal / plan-detail / plan-group-detail / review / settings /
   * training-complete / training-preferences / training-preview / training / welcome-home）
   * 的 `:root` **全部**定义 `--warn: #FFD7C5`，值逐字节一致——属跨屏语义警告色，
   * 不是屏内特例；`TOKENS.md:68` 已收录该规范值。
   *
   * **鸿蒙唯一落地场景**：注册页错误消息文本 `PencilRegisterPage.ets:557`
   * （`.fontColor(PrototypeTokens.WARN)`，`this.message` 非空时渲染）。全仓仅此 1 处。
   *
   * **提 token 判据（勿误读为「单次使用不该提」）**：本成员的依据是**原型跨屏规范值**，
   * 而非鸿蒙侧的复用频次——二者在鸿蒙代码中各仅 1 处使用（`WARN` / `SURFACE_2`）。
   * 文件头「出现 <2 次的屏内专属值就地直写」针对的是**无原型变量名的单屏局部色**，
   * 不适用于本成员；后续 review 请勿因「只用了一次」把它回退成内联字面量。
   *
   * 派生描边 `--warn-border`（rgba(255,176,150,.55)）不在本表，需要时另行提取。
   */
  static readonly WARN: string = '#FFD7C5'

  // ── 背景 / 表面基色 ─────────────────────────────────────────────
  /** `--ink-0` 页面背景主色 */
  static readonly BG_INK: string = '#0B0F13'
  /** `--ink-1` 页面背景次级（原型 5 屏均有，如 settings.html:15） */
  static readonly BG_INK_1: string = '#0A0D12'
  /** `--ink-welcome-0` 欢迎页背景 */
  static readonly BG_INK_WELCOME: string = '#10171B'
  /** `--ring-inner` 进度环内圈 */
  static readonly BG_RING_INNER: string = '#0D1117'

  // ── 表面 / 面底（原型 --visual-* / --stat-bg / --streak-* / --complete-*）──
  /** `--visual-a` 视觉卡底（原型 14 屏均有） */
  static readonly VISUAL_A: string = '#14241F'
  /** `--stat-bg` 统计卡底 */
  static readonly STAT_BG: string = '#14181E'
  /** `--streak-bg` / `--streak-surface` 连续天数卡底 */
  static readonly STREAK_BG: string = '#171C23'
  /** `--surface-stat` 回顾统计面 */
  static readonly SURFACE_STAT: string = '#171D24'
  /**
   * `--surface-2` 次层表面（回顾页肌肉详情进度条轨道底）。
   *
   * **原型分布**：`--surface-2` 是规范 surface 色族成员，原型 `src/` 内跨 6 个文件、
   * 共 51 处出现（含定义与 `var(--surface-2)` 引用；`fittracker-review.html` 单文件
   * 7 处引用）。同族另有 `--surface-stat`(#171D24，已收为 `SURFACE_STAT`)。
   *
   * **取值来源**：`fittracker-review.html:825` 的 openstats 作用域内
   * `--surface-2: #20272F`——本成员取的就是这一份。
   * **同名不同值的坑（勿「对齐」）**：
   *   - `fittracker-webapp.html:13` 的 `:root --surface-2` 是 `#121A1E`；
   *   - `fittracker-review-openstats-1to1.html` 是 `#2c2c2e`；
   *   - `fittracker-brand-identity.html` 是 `#14241F`。
   * 三者与本成员同名异值，不可相互替代。
   *
   * **鸿蒙唯一落地场景**：review 肌肉详情进度条轨道底 `ReviewContent.ets:2204`
   * （`.backgroundColor(PrototypeTokens.SURFACE_2)`；轨道 Row 宽 74 高 5，上层填充条为
   * `ACCENT`）。全仓仅此 1 处。
   *
   * **提 token 判据（勿误读为「单次使用不该提」）**：依据是**原型跨屏规范值**，而非
   * 鸿蒙侧复用频次——它与 `WARN` 在鸿蒙各仅 1 处使用。文件头「出现 <2 次的屏内专属值
   * 就地直写」针对无原型变量名的单屏局部色，本成员有原型变量名与跨文件分布，不适用。
   */
  static readonly SURFACE_2: string = '#20272F'
  /** `--complete-bg` / `--canvas` 完成页底 */
  static readonly COMPLETE_BG: string = '#07100F'
  /** `--complete-circle` 完成勾选圆池底 */
  static readonly COMPLETE_CIRCLE: string = '#122D28'
  /** `--complete-check` 完成勾选高光（亦作 confetti c3） */
  static readonly COMPLETE_CHECK: string = '#7EF0CB'

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
  /** alpha 0.32（原型 `--white-32` rgba(255,255,255,.32)） */
  static readonly WHITE_A32: string = '#52FFFFFF'
  /** alpha 0.40 */
  static readonly WHITE_A40: string = '#66FFFFFF'
  /** alpha 0.48 */
  static readonly WHITE_A48: string = '#7AFFFFFF'
  /** alpha 0.54 */
  static readonly WHITE_A54: string = '#8AFFFFFF'
  /** alpha 0.56（原型 `--white-56` rgba(255,255,255,.561)） */
  static readonly WHITE_A56: string = '#8FFFFFFF'
  /** alpha 0.60 */
  static readonly WHITE_A60: string = '#99FFFFFF'
  /** alpha 0.62 */
  static readonly WHITE_A62: string = '#9EFFFFFF'
  /** alpha 0.65（原型 `--white-65` rgba(255,255,255,.65)） */
  static readonly WHITE_A65: string = '#A6FFFFFF'
  /** alpha 0.70 */
  static readonly WHITE_A70: string = '#B3FFFFFF'
  /** alpha 0.82 */
  static readonly WHITE_A82: string = '#D1FFFFFF'
  /** alpha 0.87（原型 `--white-87` rgba(255,255,255,.87)） */
  static readonly WHITE_A87: string = '#DEFFFFFF'
  /**
   * alpha 0.90，**基色为 F3FBF7（偏绿白）而非 FFFFFF**。
   * 来源原型 `--white-90` rgba(243,251,247,.90)。
   * 命名用 `_TINT` 后缀以区别于纯白阶族——**不可**与 `WHITE_A82`(#D1FFFFFF) 或
   * `TEXT_HI`(#F7FBF8) 相互替代。
   */
  static readonly WHITE_90_TINT: string = '#E6F3FBF7'

  // ── 黑阶（浮动层底 / 遮罩）───────────────────────────────────────
  /** 黑 alpha 0.22（原型 rgba(0,0,0,.22)） */
  static readonly BLACK_A22: string = '#38000000'
  /** 黑 alpha 0.24（分隔、压暗） */
  static readonly BLACK_A24: string = '#3D000000'
  /** 黑 alpha 0.32（原型 rgba(0,0,0,.32)，浮动按钮底） */
  static readonly BLACK_A32: string = '#52000000'
  /** 黑 alpha 0.40（原型 rgba(0,0,0,.40)，欢迎页遮罩） */
  static readonly BLACK_A40: string = '#66000000'
  /** 黑 alpha 0.45（原型 rgba(0,0,0,.45)） */
  static readonly BLACK_A45: string = '#73000000'
  /** 黑 alpha 0.50（原型 rgba(0,0,0,.50)） */
  static readonly BLACK_A50: string = '#80000000'

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

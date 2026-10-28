import { curves } from '@kit.ArkUI'

/**
 * DesignTokens -- global visual design tokens.
 * Function #26
 */

export class ColorTokens {
  static readonly APP_BG_HOME: string = '#0A1110'
  static readonly APP_BG_HOME_ELEVATED: string = '#0D1615'
  static readonly APP_BG_HOME_ACCENT: string = 'rgba(69,201,161,0.08)'

  static readonly ACCENT_PRIMARY: string = '#50ECA7'
  static readonly ACCENT_HOVER: string = '#53E7A5'
  static readonly ACCENT_SOFT: string = '#8CEBCC'
  static readonly ACCENT_DEEP: string = '#45C9A1'
  static readonly ACCENT_METAL: string = '#7E8F96'
  static readonly ACCENT_GOLD: string = '#B59869'

  static readonly PRIMARY: string = ColorTokens.ACCENT_PRIMARY
  static readonly PRIMARY_HOVER: string = ColorTokens.ACCENT_HOVER
  static readonly PRIMARY_PRESSED: string = ColorTokens.ACCENT_DEEP
  static readonly PRIMARY_DISABLED: string = '#34584F'
  static readonly ACCENT_GLOW: string = 'rgba(69,201,161,0.18)'

  static readonly ACCENT: string = ColorTokens.ACCENT_GOLD
  static readonly ACCENT_LIGHT: string = '#C8AF84'

  static readonly WHITE: string = '#FFFFFF'
  static readonly NEUTRAL_0: string = '#FFFFFF'
  static readonly NEUTRAL_50: string = '#EDF6F2'
  static readonly NEUTRAL_100: string = '#C8D5CF'
  static readonly NEUTRAL_200: string = '#A3B3AD'
  static readonly NEUTRAL_300: string = '#7A8D85'
  static readonly NEUTRAL_400: string = '#2A3934'
  static readonly NEUTRAL_500: string = '#000000'

  static readonly SUCCESS: string = '#54C89C'
  static readonly SUCCESS_LIGHT: string = ColorTokens.ACCENT_SOFT
  static readonly WARNING: string = ColorTokens.ACCENT_GOLD
  static readonly ERROR: string = '#D77C78'
  /**
   * 错误态底（退出登录按钮）：`#14D77C78` = alpha 0x14≈0.08 / 基色 ERROR。
   * 原为 `SettingsContent.ets` 内直写，Wave 3 收编——错误态语义归 DesignTokens。
   */
  static readonly ERROR_A08: string = '#14D77C78'
  /**
   * 错误态描边（退出登录按钮）：`#4DD77C78` = alpha 0x4D≈0.30 / 基色 ERROR。
   */
  static readonly ERROR_A30: string = '#4DD77C78'
  static readonly INFO: string = ColorTokens.ACCENT_METAL
  static readonly NEW_RECORD: string = ColorTokens.ACCENT_GOLD
  static readonly NEW_RECORD_BG: string = 'rgba(181,152,105,0.18)'
  static readonly SUCCESS_BG: string = 'rgba(69,201,161,0.16)'
  static readonly WARNING_BG: string = 'rgba(181,152,105,0.16)'
  static readonly ERROR_BG: string = 'rgba(215,124,120,0.16)'
  static readonly INFO_BG: string = 'rgba(126,143,150,0.16)'
  static readonly DATA_HIGHLIGHT: string = ColorTokens.ACCENT_SOFT
  static readonly DATA_HIGHLIGHT_BG: string = 'rgba(140,235,204,0.14)'

  static readonly BG_PRIMARY: string = '#09100F'
  static readonly BG_SECONDARY: string = '#0F1716'
  static readonly BG_TERTIARY: string = '#141F1D'
  static readonly BG_ELEVATED: string = '#1A2825'
  static readonly SURFACE_PRIMARY: string = '#16211F'
  static readonly SURFACE_SECONDARY: string = '#1B2A27'
  static readonly SURFACE_STRONG: string = '#20332E'
  static readonly SURFACE_INPUT: string = '#1A2623'
  static readonly SURFACE_DISABLED: string = '#121A18'
  static readonly SURFACE_ELEVATED: string = '#20332E'
  static readonly SURFACE_TERTIARY: string = '#243B35'
  static readonly SURFACE_PANEL: string = '#101816'
  static readonly SURFACE_PANEL_RAISED: string = '#141F1D'
  static readonly SURFACE_HEADER: string = '#0D1413'
  static readonly SURFACE_GLASS: string = 'rgba(255,255,255,0.06)'
  static readonly SURFACE_GLASS_STRONG: string = 'rgba(255,255,255,0.10)'
  static readonly SURFACE_GLASS_SOFT: string = 'rgba(255,255,255,0.04)'
  static readonly SURFACE_CARD_HERO: string = '#141F1D'
  static readonly SURFACE_CARD_HERO_RAISED: string = '#182422'
  static readonly SURFACE_CARD_SUBTLE: string = '#111918'
  static readonly SURFACE_CARD_MUTED: string = '#0F1716'
  static readonly SURFACE_NAV: string = 'rgba(8,12,15,0.97)'
  static readonly SURFACE_BUTTON_SECONDARY: string = '#1A2825'
  static readonly SURFACE_BUTTON_SECONDARY_PRESSED: string = '#20332E'
  static readonly CTA_SECONDARY_BG: string = 'rgba(255,255,255,0.08)'
  static readonly CTA_SECONDARY_BG_HOVER: string = 'rgba(255,255,255,0.11)'
  static readonly CTA_SECONDARY_BORDER: string = 'rgba(255,255,255,0.10)'
  static readonly SURFACE_BUTTON_GHOST_PRESSED: string = 'rgba(69,201,161,0.10)'
  static readonly BORDER_DEFAULT: string = '#2A3934'
  static readonly BORDER_SUBTLE: string = 'rgba(42,57,52,0.55)'
  static readonly BORDER_STRONG: string = 'rgba(42,57,52,0.92)'
  static readonly BORDER_GLASS: string = 'rgba(255,255,255,0.08)'
  static readonly BORDER_GLASS_STRONG: string = 'rgba(255,255,255,0.12)'
  static readonly BORDER_HAIRLINE: string = 'rgba(255,255,255,0.06)'
  static readonly BORDER_ACCENT_SOFT: string = 'rgba(69,201,161,0.18)'
  static readonly BORDER_WARN_SOFT: string = 'rgba(181,152,105,0.18)'
  static readonly BORDER_ACCENT: string = 'rgba(69,201,161,0.32)'
  static readonly DIVIDER: string = 'rgba(42,57,52,0.48)'
  static readonly FOCUS_RING: string = 'rgba(69,201,161,0.20)'

  static readonly TEXT_PRIMARY: string = '#EDF6F2'
  static readonly TEXT_SECONDARY: string = '#A3B3AD'
  // 由 #6E8078 提亮：11-14px 正文在 SURFACE_PRIMARY(#16211F) 上原为 3.95:1、BG_TERTIARY(#141F1D) 4.04:1，
  // 均未达 WCAG AA 正文 4.5:1（消费点 ExerciseDetailPage 的 label/description/infoRow，字号 11/13/14）。
  // #7A8D85 实测：BG_PRIMARY 5.47 / SURFACE_PRIMARY 4.70 / BG_TERTIARY 4.81，三背景全达标；
  // 与原值色差 12/255，低于 compare.py 阈值 16，不改动已收敛的像素基线。
  static readonly TEXT_TERTIARY: string = '#7A8D85'
  static readonly TEXT_ON_DARK: string = '#F3FBF7'
  static readonly TEXT_ON_DARK_SECONDARY: string = 'rgba(243,251,247,0.74)'
  static readonly TEXT_ON_DARK_TERTIARY: string = 'rgba(243,251,247,0.56)'
  static readonly TEXT_ON_DARK_FAINT: string = 'rgba(243,251,247,0.40)'
  static readonly TEXT_DISABLED: string = '#53625D'
  static readonly TEXT_ON_PRIMARY: string = '#09100F'

  static readonly OVERLAY_PRIMARY: string = 'rgba(69,201,161,0.12)'
  static readonly OVERLAY_SUCCESS: string = 'rgba(84,200,156,0.12)'
  static readonly OVERLAY_ACCENT: string = 'rgba(181,152,105,0.14)'
  static readonly NAV_ACTIVE: string = '#45C9A1'
  static readonly NAV_INACTIVE: string = 'rgba(243,251,247,0.56)'
  static readonly NAV_TEXT_ACTIVE: string = '#F3FBF7'
  static readonly NAV_TEXT_INACTIVE: string = 'rgba(243,251,247,0.56)'
  static readonly STATE_SUCCESS_BORDER: string = 'rgba(69,201,161,0.22)'
  static readonly STATE_WARN_BORDER: string = 'rgba(181,152,105,0.22)'
  static readonly STATE_ERROR_BORDER: string = 'rgba(215,124,120,0.22)'

  /**
   * 表单字段错误态三色（输入框描边 / 填充 / 提示文字）。
   *
   * 用于「字段校验失败时输入框转红 + 字段名位置显示红色错误提示」这一统一交互，
   * 登录页、注册页、身体数据体重输入、回顾目标输入共用，避免各组件各自声明魔法值。
   */
  static readonly FIELD_ERROR_BORDER: string = '#FFFF5A52'
  static readonly FIELD_ERROR_FILL: string = '#14FF5A52'
  static readonly FIELD_ERROR_TEXT: string = '#FFFF7A72'

  static readonly PROGRESS_TRACK: string = 'rgba(255,255,255,0.08)'
  static readonly PROGRESS_FILL: string = '#45C9A1'
  static readonly PROGRESS_FILL_SOFT: string = '#8CEBCC'

  static readonly MUSCLE_CHEST: string = '#49C39D'
  static readonly MUSCLE_BACK: string = '#3CA282'
  static readonly MUSCLE_LEGS: string = '#B59869'
  static readonly MUSCLE_SHOULDERS: string = '#7E8F96'
  static readonly MUSCLE_ARMS: string = '#C97E77'
  static readonly MUSCLE_ABS: string = '#60C2AC'
  static readonly MUSCLE_DEFAULT: string = '#73867F'
}

export class FontTokens {
  static readonly FAMILY_BASE: string = 'HarmonyOS Sans'
  static readonly FAMILY_MONO: string = 'HarmonyOS Sans Mono'

  static readonly DISPLAY_SIZE: number = 28
  static readonly DISPLAY_LINE_HEIGHT: number = 36
  static readonly DISPLAY_WEIGHT: number = FontWeight.Bold

  static readonly HEADLINE_SIZE: number = 20
  static readonly HEADLINE_LINE_HEIGHT: number = 28
  static readonly HEADLINE_WEIGHT: number = FontWeight.Bold

  static readonly TITLE_SIZE: number = 18
  static readonly TITLE_LINE_HEIGHT: number = 24
  static readonly TITLE_WEIGHT: number = FontWeight.Medium

  static readonly BODY_SIZE: number = 16
  static readonly BODY_LINE_HEIGHT: number = 22
  static readonly BODY_WEIGHT: number = FontWeight.Normal

  static readonly BODY_BOLD_SIZE: number = 16
  static readonly BODY_BOLD_LINE_HEIGHT: number = 22
  static readonly BODY_BOLD_WEIGHT: number = FontWeight.Medium

  static readonly CAPTION_SIZE: number = 14
  static readonly CAPTION_LINE_HEIGHT: number = 18
  static readonly CAPTION_WEIGHT: number = FontWeight.Normal

  static readonly SMALL_SIZE: number = 13
  static readonly SMALL_LINE_HEIGHT: number = 18
  static readonly SMALL_WEIGHT: number = FontWeight.Normal

  static readonly TIMER_SIZE: number = 48
  static readonly TIMER_LINE_HEIGHT: number = 56
  static readonly TIMER_WEIGHT: number = FontWeight.Bold

  static readonly HERO_SIZE: number = 30
  static readonly HERO_LINE_HEIGHT: number = 48
  static readonly HERO_WEIGHT: number = FontWeight.Bold

  static readonly MICRO_SIZE: number = 11
  static readonly MICRO_LINE_HEIGHT: number = 14
  static readonly MICRO_WEIGHT: number = FontWeight.Normal

  static readonly DISPLAY_HOME_SIZE: number = 36
  static readonly DISPLAY_HOME_LINE_HEIGHT: number = 38
  static readonly DISPLAY_HOME_WEIGHT: number = FontWeight.Bold

  static readonly HERO_TITLE_SIZE: number = 32
  static readonly HERO_TITLE_LINE_HEIGHT: number = 34
  static readonly HERO_TITLE_WEIGHT: number = FontWeight.Bold

  static readonly SECTION_TITLE_SIZE: number = 22
  static readonly SECTION_TITLE_LINE_HEIGHT: number = 24
  static readonly SECTION_TITLE_WEIGHT: number = FontWeight.Medium

  static readonly CARD_TITLE_SIZE: number = 17
  static readonly CARD_TITLE_LINE_HEIGHT: number = 20
  static readonly CARD_TITLE_WEIGHT: number = FontWeight.Medium

  static readonly METRIC_VALUE_SIZE: number = 26
  static readonly METRIC_VALUE_LINE_HEIGHT: number = 28
  static readonly COMPLETE_METRIC_VALUE_SIZE: number = 24
  static readonly COMPLETE_METRIC_VALUE_LINE_HEIGHT: number = 26
  static readonly METRIC_VALUE_WEIGHT: number = FontWeight.Bold

  static readonly NAV_LABEL_SIZE: number = 13
  static readonly NAV_LABEL_LINE_HEIGHT: number = 16
  static readonly NAV_LABEL_WEIGHT: number = FontWeight.Medium

  static readonly META_LABEL_SIZE: number = 11
  static readonly META_LABEL_LINE_HEIGHT: number = 14
  static readonly META_LABEL_WEIGHT: number = FontWeight.Medium

  static readonly STATUS_PILL_SIZE: number = 11
  static readonly STATUS_PILL_LINE_HEIGHT: number = 14
  static readonly STATUS_PILL_WEIGHT: number = FontWeight.Medium
}

export class SpacingTokens {
  static readonly XXXS: number = 2
  static readonly XS: number = 4
  static readonly SM: number = 8
  static readonly MD: number = 16
  static readonly LG: number = 24
  static readonly XL: number = 32
  static readonly XXL: number = 48
  static readonly XXXL: number = 64
  static readonly PAGE_GUTTER: number = 16
  static readonly PAGE_GUTTER_WIDE: number = 20
  static readonly STACK_GAP_XS: number = 8
  static readonly STACK_GAP_SM: number = 12
  static readonly STACK_GAP_MD: number = 16
  static readonly STACK_GAP_LG: number = 24
  static readonly CARD_PADDING_SM: number = 16
  static readonly CARD_PADDING_MD: number = 20
  static readonly CARD_PADDING_LG: number = 24
  static readonly COMPLETE_METRIC_CARD_HEIGHT: number = 132
  static readonly SECTION_SPACING: number = 24
  static readonly MODULE_SPACING: number = 16
}

export class RadiusTokens {
  static readonly XS: number = 4
  static readonly SM: number = 8
  static readonly MD: number = 12
  static readonly LG: number = 16
  static readonly XL: number = 16
  static readonly FULL: number = 9999
  static readonly CONTROL: number = 18
  static readonly CARD_SM: number = 22
  static readonly CARD_MD: number = 24
  static readonly PANEL: number = 28
  static readonly TAB_ACTIVE: number = 18
  static readonly STATUS_PILL: number = 9999
}

export interface ShadowConfig {
  radius: number
  color: string
  offsetX: number
  offsetY: number
}

export class ShadowTokens {
  static readonly SM: ShadowConfig = {
    radius: 12,
    color: 'rgba(3,8,8,0.28)',
    offsetX: 0,
    offsetY: 4
  }

  static readonly MD: ShadowConfig = {
    radius: 20,
    color: 'rgba(3,8,8,0.34)',
    offsetX: 0,
    offsetY: 8
  }

  static readonly LG: ShadowConfig = {
    radius: 28,
    color: 'rgba(3,8,8,0.40)',
    offsetX: 0,
    offsetY: 12
  }

  static readonly ACCENT: ShadowConfig = {
    radius: 18,
    color: 'rgba(69,201,161,0.16)',
    offsetX: 0,
    offsetY: 8
  }

  static readonly GLASS: ShadowConfig = {
    radius: 20,
    color: 'rgba(0,0,0,0.18)',
    offsetX: 0,
    offsetY: 10
  }

  static readonly GLASS_STRONG: ShadowConfig = {
    radius: 28,
    color: 'rgba(0,0,0,0.24)',
    offsetX: 0,
    offsetY: 14
  }

  static readonly CTA: ShadowConfig = {
    radius: 22,
    color: 'rgba(69,201,161,0.22)',
    offsetX: 0,
    offsetY: 12
  }

  static readonly NAV: ShadowConfig = {
    radius: 28,
    color: 'rgba(0,0,0,0.28)',
    offsetX: 0,
    offsetY: -8
  }

  // Bottom tab center pill elevation (HTML: 0 6px 14px rgba(0,0,0,.30) / active 0 8px 20px rgba(0,0,0,.34))
  static readonly TAB_PILL: ShadowConfig = {
    radius: 14,
    color: 'rgba(0,0,0,0.30)',
    offsetX: 0,
    offsetY: 6
  }

  static readonly TAB_PILL_ACTIVE: ShadowConfig = {
    radius: 20,
    color: 'rgba(0,0,0,0.34)',
    offsetX: 0,
    offsetY: 8
  }

  static readonly FOCUS: ShadowConfig = {
    radius: 14,
    color: 'rgba(69,201,161,0.12)',
    offsetX: 0,
    offsetY: 0
  }

  static readonly NONE: ShadowConfig = {
    radius: 0,
    color: 'rgba(0,0,0,0)',
    offsetX: 0,
    offsetY: 0
  }
}

export class MotionTokens {
  // Base durations (kept for compatibility)
  static readonly DURATION_MICRO: number = 120
  static readonly DURATION_FAST: number = 150
  static readonly DURATION_BASE: number = 250
  static readonly DURATION_SLOW: number = 400

  // Press / interaction durations
  static readonly DURATION_PRESS: number = 120
  static readonly DURATION_COLOR_FAST: number = 160
  static readonly DURATION_COLOR_BASE: number = 180
  static readonly DURATION_OVERLAY: number = 220
  static readonly DURATION_PANEL: number = 280

  // Training in-page keyframes
  static readonly DURATION_RECORD: number = 180
  static readonly DURATION_MARKER: number = 300
  static readonly DURATION_CORE: number = 460
  static readonly DELAY_CORE: number = 60
  static readonly DURATION_SEG_POP: number = 460
  // 段 pop 拆两段（与 Android `DURATION_SEG_POP*40/100` / `*60/100` 同构）：
  // 放大 184 + 回落 276 = 总 460ms。此前把总时长同时用作单程时长，
  // 实际放大 460 再回缩 460，总长 920ms——同一交互双端观感差一倍。
  static readonly DURATION_SEG_POP_UP: number = 184
  static readonly DURATION_SEG_POP_DOWN: number = 276

  // Confetti
  static readonly DURATION_CONFETTI_FLY: number = 1100
  static readonly DURATION_CONFETTI_FALL: number = 2600

  // Ambient pulse
  static readonly DURATION_PULSE: number = 1600

  // Progress / gauge fill (HTML `.35s` width fill on goals/rings)
  static readonly DURATION_PROGRESS: number = 350

  // Completion page
  static readonly DURATION_CF_POP: number = 500
  static readonly DELAY_CF_POP: number = 50
  static readonly DURATION_CF_RISE_FAST: number = 450
  static readonly DURATION_CF_RISE_BASE: number = 500

  // Easing curves (ArkUI ICurve). Background/color transitions use Curve.EaseInOut.
  static readonly EASE_MOTION: ICurve = curves.cubicBezierCurve(0.2, 0.7, 0.2, 1)
  static readonly EASE_PANEL: ICurve = curves.cubicBezierCurve(0.32, 0.72, 0.3, 1)
  static readonly EASE_FLY: ICurve = curves.cubicBezierCurve(0.16, 0.7, 0.3, 1)
  static readonly EASE_FALL: ICurve = curves.cubicBezierCurve(0.2, 0.55, 0.35, 1)

  /**
   * 过冲曲线（Duolingo 的 back-out）：`cubic-bezier(0.34, 1.56, 0.64, 1)`。
   * 控制点 y 上界 1.56 → 约 +6% 过冲，但仍是「定时」曲线，`duration` 照常生效。
   * 用于「弹一下再落定」的解锁/达成反馈（段 pop、数值跳动）。
   *
   * 待验证假设：ArkUI 是否允许 `cubicBezierCurve` 的 y > 1 并真实渲染过冲。
   * 若被裁剪成普通 ease，段 pop 会退化为无过冲——届时改用它
   * `curves.springMotion(0.35, 0.62)`（物理弹簧，duration 不生效）。
   */
  static readonly EASE_BACK_OUT: ICurve = curves.cubicBezierCurve(0.34, 1.56, 0.64, 1)

  /**
   * 通用 ease-out，取自 **Duolingo Web 端实测**：`cubic-bezier(0.22, 1, 0.36, 1)`
   * （designlang 从 duolingo.com 逐条抓取 CSS 得到）。与项目既有 `EASE_MOTION`
   * `(.2, .7, .2, 1)` 相比：起手更干脆、收尾更缓。
   */
  static readonly EASE_OUT_DUO: ICurve = curves.cubicBezierCurve(0.22, 1, 0.36, 1)

  /**
   * 物理弹簧（`springMotion`）。**注意**：按 ArkUI 官方《弹簧曲线》指南，
   * 该类曲线的 `duration` 参数**不生效**，时长由物理参数与属性变化量自动计算；
   * 因此不要塞进需要精确时序的编舞里，只用于可中断场景（按压回弹、拖拽松手回位）。
   *
   * **参数为项目自定**——Duolingo 未公开其弹簧数值（只有 "ease-out spring" 这类
   * 形容词）。dampingFraction < 1 才有回弹，值越小越弹。
   */
  static readonly SPRING_PRESS: ICurve = curves.springMotion(0.28, 0.85)
  static readonly SPRING_SETTLE: ICurve = curves.springMotion(0.40, 0.90)

  // ── 入场语汇（与 Android `FtMotion.DURATION_ENTER / DURATION_STAGGER / EASE_ENTER` 同值）──
  // 卡片按块错峰上浮淡入。此前 Harmony 缺这组 token，首页/个人页是硬切，而 Android 有节奏。
  static readonly DURATION_ENTER: number = 320
  static readonly DURATION_STAGGER: number = 40
  // 曲线复用文件底部既有的 `EASE_ENTER`（string 版，值同为 cubic-bezier(0.2, 0.8, 0.2, 1)）。
  // 不再定义 ICurve 版本——同名会触发 ArkTS 的 Duplicate identifier。

  // 全模态弹出转场（训练预览页）：中心缩放的起始比例
  static readonly MODAL_POP_SCALE: number = 0.92
  // 弹出转场时长——比 sheet 面板语汇（DURATION_PANEL/OVERLAY）更短更利落，
  // 故单独取值，不动共享 token，避免连带改到动作库/身体数据的 sheet。
  static readonly DURATION_MODAL_POP: number = 200
  static readonly DURATION_MODAL_SCRIM: number = 160

  // Duolingo 硬边厚底（按钮形态语汇）：底部实心厚度与按下下沉量（vp）。
  // 用 border 分边宽实现——ArkUI 的 shadow 无法表达零模糊硬边（radius 最小 12）。
  // 厚底颜色取按压深阶 ColorTokens.PRIMARY_PRESSED / PrototypeTokens.ACCENT_DEEP。
  static readonly PRESS_DEPTH: number = 4
  static readonly PRESS_SHIFT: number = 2

  // Press scale factors
  static readonly PRESS_PRIMARY: number = 0.985
  static readonly PRESS_CHIP: number = 0.97
  static readonly PRESS_ICON: number = 0.96
  static readonly PRESS_SHORTCUT: number = 0.98
  static readonly PRESS_SEGMENT: number = 0.97
  static readonly PRESS_TAB_PILL: number = 0.96
  static readonly PRESS_BACK: number = 0.94

  // 字段错误「左右抖动」——输入框在 X 轴上来回位移，用于校验失败的即时反馈。
  // 规格逐字对应设计给出的 CSS `@keyframes shake`：峰值 10px、10 段 × 50ms（总 500ms）。
  // 设计基准 390vp 屏下 1px = 1vp（原型画布 390×844，见 CanvasScale.ets 注释）。
  static readonly SHAKE_AMPLITUDE: number = 10
  static readonly DURATION_SHAKE_STEP: number = 50
  // 抖动曲线：CSS `ease-in-out` 的等价贝塞尔 (0.42, 0, 0.58, 1)。
  // 不复用 EASE_MOTION——那是按压语汇（更快收束），抖动需在每段关键帧间隔内缓入缓出。
  static readonly EASE_SHAKE: ICurve = curves.cubicBezierCurve(0.42, 0, 0.58, 1)

  static readonly EASE_IN_OUT: string = 'cubic-bezier(0.4, 0.0, 0.2, 1.0)'
  static readonly EASE_OUT: string = 'cubic-bezier(0.0, 0.0, 0.2, 1.0)'
  static readonly EASE_STANDARD: string = 'cubic-bezier(0.28, 0, 0.22, 1)'
  static readonly EASE_ENTER: string = 'cubic-bezier(0.2, 0.8, 0.2, 1)'
  static readonly EASE_PRESS: string = 'cubic-bezier(0.4, 0.0, 0.2, 1.0)'
}

export class TouchTokens {
  static readonly MIN_TARGET: number = 48
  static readonly TAB_ICON: number = 24
  static readonly TAB_BAR_HEIGHT: number = 56
  static readonly INPUT_HEIGHT: number = 48
  static readonly BUTTON_HEIGHT_DEFAULT: number = 48
  static readonly BUTTON_HEIGHT_SMALL: number = 36
  static readonly BUTTON_HEIGHT_LARGE: number = 56
  static readonly BUTTON_HEIGHT_HERO: number = 56
  static readonly SEGMENT_HEIGHT: number = 40
  static readonly STATUS_PILL_HEIGHT: number = 28
  static readonly MINI_BUTTON_HEIGHT: number = 36
  static readonly CARD_MEDIA_HEIGHT: number = 120
  static readonly CARD_COVER_SIZE: number = 64
  static readonly CARD_MIN_HEIGHT_SM: number = 104
  static readonly CARD_MIN_HEIGHT_MD: number = 118
  static readonly HERO_CARD_MIN_HEIGHT: number = 220
  static readonly AVATAR_SIZE: number = 56
  static readonly HERO_HEIGHT: number = 200
  static readonly TAB_BAR_HEIGHT_HOME: number = 56
  static readonly TAB_ACTIVE_DOT: number = 44
  static readonly TOP_CONTEXT_BUTTON: number = 44
  static readonly CALENDAR_CELL: number = 32
  static readonly PROGRESS_BAR_HEIGHT: number = 12
  static readonly TIMELINE_COL_WIDTH: number = 20
  static readonly MUSCLE_TAG_PADDING_V: number = 1
  static readonly MUSCLE_TAG_PADDING_H: number = 6
}

export class GridTokens {
  static readonly BREAKPOINT_SM: number = 320
  static readonly BREAKPOINT_MD: number = 600
  static readonly BREAKPOINT_LG: number = 840
  static readonly COLUMNS_SM: number = 4
  static readonly COLUMNS_MD: number = 8
  static readonly COLUMNS_LG: number = 12
  static readonly GUTTER: number = 12
  static readonly MARGIN: number = 16
  static readonly PAGE_MAX_WIDTH_MOBILE: number = 430
  static readonly PAGE_MARGIN_MOBILE: number = 16
  static readonly PAGE_MARGIN_WIDE: number = 20
  static readonly CARD_GAP: number = 16
}

export class MuscleColorMap {
  static getColor(muscle: string): string {
    if (muscle === '胸') { return ColorTokens.MUSCLE_CHEST }
    if (muscle === '背') { return ColorTokens.MUSCLE_BACK }
    if (muscle === '腿') { return ColorTokens.MUSCLE_LEGS }
    if (muscle === '肩') { return ColorTokens.MUSCLE_SHOULDERS }
    if (muscle === '臂') { return ColorTokens.MUSCLE_ARMS }
    if (muscle === '腹') { return ColorTokens.MUSCLE_ABS }
    return ColorTokens.MUSCLE_DEFAULT
  }
}

export class StopwatchTokens {
  static readonly DIAL_BASE: string = '#141F1D'
  static readonly DIAL_OVERLAY: string = 'rgba(69,201,161,0.04)'
  static readonly DIAL_INNER: string = 'rgba(69,201,161,0.02)'
  static readonly BEZEL_STROKE: string = 'rgba(42,57,52,0.60)'
  static readonly SECOND_HAND: string = '#45C9A1'
  static readonly MINUTE_HAND: string = '#EDF6F2'
  static readonly TICK_MAJOR: string = 'rgba(237,246,242,0.92)'
  static readonly TICK_MINOR: string = 'rgba(237,246,242,0.24)'
  static readonly SUBDIAL_FILL: string = '#16211F'
  static readonly SUBDIAL_STROKE: string = 'rgba(42,57,52,0.60)'
  static readonly CENTER_RING: string = 'rgba(69,201,161,0.24)'
  static readonly RUNNING_GLOW: string = 'rgba(181,152,105,0.24)'
  static readonly CASE_SIZE: number = 280
  static readonly CONTAINER_HEIGHT: number = 320
}

/**
 * 图标口径 v1。
 *
 * 视框/描边/端点三项取自既有 pencil-lucide-* 族实测规格（24 视框、stroke-width 2、
 * round cap 与 join），是当前唯一风格自洽的一族，故以其为基准而不再新造第三套。
 *
 * 尺寸梯度对齐 TouchTokens.TAB_ICON = 24，避免两处各自声明图标边长。
 *
 * ⚠ 染色边界：ArkUI 的 Image.fillColor 只替换 SVG 的 fill，对 stroke 无效。
 *   - stroke-based 图标（pencil-lucide-* 这批）色彩写死在文件里，无法运行时改色；
 *   - 需要随状态/主题变色的图标，必须是 fill-based（如 pencil-tab-workout.svg）。
 *   详见 apps/harmony/tools/check-icon-assets.mjs 的文档头。
 */
export class IconTokens {
  static readonly VIEWBOX: number = 24
  static readonly STROKE_WIDTH: number = 2
  static readonly SIZE_XS: number = 12
  static readonly SIZE_SM: number = 16
  static readonly SIZE_MD: number = 20
  static readonly SIZE_LG: number = 24
  static readonly SIZE_XL: number = 30
}

/**
 * 媒体口径 —— 动作演示图/卡的圆角、比例与加载过渡。
 *
 * 两个圆角值来自实测现状而非拍脑袋：列表卡 14（原 ExerciseLibraryPage.ets:62 的
 * LIB_MEDIA_RADIUS）、内联卡 16（原 ActiveContent.ets 的 DEMO_PHOTO_RADIUS，注释
 * 写明与 demoCard 标题条对齐）。本波只做收编、不改数值——改数值等于改像素基线。
 *
 * 为什么圆角要分两档而不统一：列表卡在 4:3 网格里、内联卡在正方形容器里，
 * 视觉圆角半径需与各自的卡面尺寸成比例；统一成一个值必然有一侧显得过钝或过方。
 */
export class MediaTokens {
  static readonly RADIUS_GRID: number = 14
  static readonly RADIUS_INLINE: number = 16
  static readonly ASPECT_CARD: number = 4 / 3
  static readonly FADE_DURATION: number = 180
  static readonly PLACEHOLDER_ICON: number = 30
  static readonly PLACEHOLDER_BG: string = 'rgba(255,255,255,0.04)'
  static readonly PLACEHOLDER_ICON_COLOR: string = 'rgba(255,255,255,0.32)'
}

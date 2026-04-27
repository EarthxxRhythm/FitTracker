/**
 * FitTracker Design Tokens
 * 全局设计令牌 —— 所有视觉属性均定义于此，组件禁止硬编码色值/字号/间距。
 * 暗黑模式通过 [data-theme="dark"] 覆盖变量实现。
 */

// ============================================================
// 1. 颜色 Token
// ============================================================
export class ColorTokens {
  /* 品牌主色 */
  static readonly PRIMARY: string = '#00C853'
  static readonly PRIMARY_HOVER: string = '#00E676'
  static readonly PRIMARY_PRESSED: string = '#009624'
  static readonly PRIMARY_DISABLED: string = '#A5D6A7'

  /* 中性色 */
  static readonly NEUTRAL_0: string = '#FFFFFF'
  static readonly NEUTRAL_50: string = '#F5F5F5'
  static readonly NEUTRAL_100: string = '#E0E0E0'
  static readonly NEUTRAL_200: string = '#BDBDBD'
  static readonly NEUTRAL_300: string = '#9E9E9E'
  static readonly NEUTRAL_400: string = '#424242'
  static readonly NEUTRAL_500: string = '#000000'

  /* 语义色 */
  static readonly SUCCESS: string = '#4CAF50'
  static readonly WARNING: string = '#FF9800'
  static readonly ERROR: string = '#F44336'
  static readonly NEW_RECORD: string = '#FFD700'

  /* 背景与表面 */
  static readonly SURFACE_PRIMARY: string = ColorTokens.NEUTRAL_0
  static readonly SURFACE_SECONDARY: string = ColorTokens.NEUTRAL_50
  static readonly SURFACE_ELEVATED: string = ColorTokens.NEUTRAL_0

  /* 文字色 */
  static readonly TEXT_PRIMARY: string = ColorTokens.NEUTRAL_500
  static readonly TEXT_SECONDARY: string = ColorTokens.NEUTRAL_300
  static readonly TEXT_DISABLED: string = ColorTokens.NEUTRAL_200
  static readonly TEXT_ON_PRIMARY: string = '#FFFFFF'

  /* 新纪录半透明背景 */
  static readonly NEW_RECORD_BG: string = 'rgba(255,215,0,0.15)'
  static readonly SUCCESS_BG: string = 'rgba(76,175,80,0.15)'
}

// ============================================================
// 2. 字体 Token
// ============================================================
export class FontTokens {
  static readonly FAMILY_BASE: string = 'HarmonyOS Sans'
  static readonly FAMILY_MONO: string = 'HarmonyOS Sans Mono'

  static readonly DISPLAY_SIZE: number = 28
  static readonly DISPLAY_LINE_HEIGHT: number = 36
  static readonly DISPLAY_WEIGHT: number = FontWeight.Bold

  static readonly HEADLINE_SIZE: number = 20
  static readonly HEADLINE_LINE_HEIGHT: number = 28
  static readonly HEADLINE_WEIGHT: number = FontWeight.Medium

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

  static readonly SMALL_SIZE: number = 12
  static readonly SMALL_LINE_HEIGHT: number = 16
  static readonly SMALL_WEIGHT: number = FontWeight.Normal

  static readonly TIMER_SIZE: number = 32
  static readonly TIMER_LINE_HEIGHT: number = 40
  static readonly TIMER_WEIGHT: number = FontWeight.Bold
}

// ============================================================
// 3. 间距 Token（单位 vp）
// ============================================================
export class SpacingTokens {
  static readonly XS: number = 4
  static readonly SM: number = 8
  static readonly MD: number = 16
  static readonly LG: number = 24
  static readonly XL: number = 32
  static readonly XXL: number = 48
  static readonly XXXL: number = 64
}

// ============================================================
// 4. 圆角 Token（单位 vp）
// ============================================================
export class RadiusTokens {
  static readonly SM: number = 8
  static readonly MD: number = 12
  static readonly LG: number = 16
  static readonly FULL: number = 9999
}

// ============================================================
// 5. 阴影 Token
// ============================================================
export class ShadowTokens {
  static readonly SM = {
    radius: 3,
    color: 'rgba(0,0,0,0.1)',
    offsetX: 0,
    offsetY: 1
  } as const
  static readonly MD = {
    radius: 8,
    color: 'rgba(0,0,0,0.08)',
    offsetX: 0,
    offsetY: 4
  } as const
  static readonly LG = {
    radius: 24,
    color: 'rgba(0,0,0,0.12)',
    offsetX: 0,
    offsetY: 8
  } as const
}

// ============================================================
// 6. 动效 Token
// ============================================================
export class MotionTokens {
  static readonly DURATION_FAST: number = 150
  static readonly DURATION_BASE: number = 250
  static readonly DURATION_SLOW: number = 400
  static readonly EASE_IN_OUT: string = 'cubic-bezier(0.4, 0.0, 0.2, 1.0)'
  static readonly EASE_OUT: string = 'cubic-bezier(0.0, 0.0, 0.2, 1.0)'
}

// ============================================================
// 7. 触摸热区 Token
// ============================================================
export class TouchTokens {
  static readonly MIN_TARGET: number = 48
  static readonly TAB_ICON: number = 24
  static readonly TAB_BAR_HEIGHT: number = 56
  static readonly INPUT_HEIGHT: number = 48
  static readonly BUTTON_HEIGHT_DEFAULT: number = 48
  static readonly BUTTON_HEIGHT_SMALL: number = 36
}

// ============================================================
// 8. 栅格 Token
// ============================================================
export class GridTokens {
  static readonly BREAKPOINT_SM: number = 320
  static readonly BREAKPOINT_MD: number = 600
  static readonly BREAKPOINT_LG: number = 840

  static readonly COLUMNS_SM: number = 4
  static readonly COLUMNS_MD: number = 8
  static readonly COLUMNS_LG: number = 12

  static readonly GUTTER_SM: number = 16
  static readonly GUTTER_MD_LG: number = 24

  static readonly MARGIN_SM: number = 16
  static readonly MARGIN_MD: number = 24
  static readonly MARGIN_LG: number = 32
}

// ============================================================
// 9. 暗黑模式颜色覆盖
// ============================================================
export class DarkColorTokens {
  static readonly NEUTRAL_0: string = '#000000'
  static readonly NEUTRAL_50: string = '#121212'
  static readonly NEUTRAL_100: string = '#2C2C2C'
  static readonly NEUTRAL_200: string = '#444444'
  static readonly NEUTRAL_300: string = '#B0B0B0'
  static readonly NEUTRAL_400: string = '#E0E0E0'
  static readonly NEUTRAL_500: string = '#FFFFFF'

  static readonly SURFACE_PRIMARY: string = '#121212'
  static readonly SURFACE_SECONDARY: string = '#1E1E1E'
  static readonly SURFACE_ELEVATED: string = '#2C2C2C'

  static readonly TEXT_PRIMARY: string = '#FFFFFF'
  static readonly TEXT_SECONDARY: string = '#B0B0B0'
  static readonly TEXT_DISABLED: string = '#666666'
}

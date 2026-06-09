/**
 * DesignTokens —— 全局视觉设计令牌
 * 功能 #26
 */
// ============================================================
// 1. 颜色 Token
// ============================================================
export class ColorTokens {
  /* 品牌主色 */
  static readonly PRIMARY: string = '#4D9DFF'
  static readonly PRIMARY_HOVER: string = '#66ABFF'
  static readonly PRIMARY_PRESSED: string = '#3D82D8'
  static readonly PRIMARY_DISABLED: string = '#5C7294'

  /* 强调色 */
  static readonly ACCENT: string = '#F6B356'
  static readonly ACCENT_LIGHT: string = '#F9C97F'

  /* 中性色 */
  static readonly WHITE: string = '#FFFFFF'
  static readonly NEUTRAL_0: string = '#FFFFFF'
  static readonly NEUTRAL_50: string = '#F5F5F5'
  static readonly NEUTRAL_100: string = '#E0E0E0'
  static readonly NEUTRAL_200: string = '#BDBDBD'
  static readonly NEUTRAL_300: string = '#9E9E9E'
  static readonly NEUTRAL_400: string = '#424242'
  static readonly NEUTRAL_500: string = '#000000'

  /* 语义色 */
  static readonly SUCCESS: string = '#53C48A'
  static readonly SUCCESS_LIGHT: string = '#78D6A3'
  static readonly WARNING: string = '#E9A847'
  static readonly ERROR: string = '#F06A6A'
  static readonly INFO: string = '#67B2FF'
  static readonly NEW_RECORD: string = '#F4D36D'
  static readonly NEW_RECORD_BG: string = 'rgba(244,211,109,0.16)'
  static readonly SUCCESS_BG: string = 'rgba(83,196,138,0.16)'
  static readonly WARNING_BG: string = 'rgba(233,168,71,0.16)'
  static readonly ERROR_BG: string = 'rgba(240,106,106,0.16)'
  static readonly INFO_BG: string = 'rgba(103,178,255,0.16)'
  static readonly DATA_HIGHLIGHT: string = '#7DE6AA'
  static readonly DATA_HIGHLIGHT_BG: string = 'rgba(125,230,170,0.16)'

  /* 背景与表面 */
  static readonly BG_PRIMARY: string = '#091018'
  static readonly BG_SECONDARY: string = '#0E1620'
  static readonly SURFACE_PRIMARY: string = '#121B26'
  static readonly SURFACE_SECONDARY: string = '#182331'
  static readonly SURFACE_ELEVATED: string = '#223246'
  static readonly SURFACE_TERTIARY: string = '#26384F'
  static readonly SURFACE_PANEL: string = '#101923'
  static readonly SURFACE_PANEL_RAISED: string = '#172231'
  static readonly SURFACE_HEADER: string = '#0F1721'
  static readonly SURFACE_BUTTON_SECONDARY: string = '#162131'
  static readonly SURFACE_BUTTON_SECONDARY_PRESSED: string = '#1E2C40'
  static readonly SURFACE_BUTTON_GHOST_PRESSED: string = 'rgba(103,178,255,0.12)'
  static readonly BORDER_SUBTLE: string = 'rgba(196,214,255,0.10)'
  static readonly BORDER_STRONG: string = 'rgba(196,214,255,0.18)'
  static readonly BORDER_ACCENT: string = 'rgba(103,178,255,0.28)'
  static readonly DIVIDER: string = 'rgba(196,214,255,0.08)'
  static readonly FOCUS_RING: string = 'rgba(103,178,255,0.22)'

  /* 文字色 */
  static readonly TEXT_PRIMARY: string = '#F5F8FC'
  static readonly TEXT_SECONDARY: string = '#9CACBE'
  static readonly TEXT_TERTIARY: string = '#6E8094'
  static readonly TEXT_DISABLED: string = '#5D6B7B'
  static readonly TEXT_ON_PRIMARY: string = '#F5F8FC'

  /* 半透明背景 */
  static readonly OVERLAY_PRIMARY: string = 'rgba(103,178,255,0.14)'
  static readonly OVERLAY_SUCCESS: string = 'rgba(83,196,138,0.14)'
  static readonly OVERLAY_ACCENT: string = 'rgba(233,168,71,0.14)'

  /* 肌群标签色 */
  static readonly MUSCLE_CHEST: string = '#5EA5F7'
  static readonly MUSCLE_BACK: string = '#5ABF7D'
  static readonly MUSCLE_LEGS: string = '#F0A65C'
  static readonly MUSCLE_SHOULDERS: string = '#A37EF3'
  static readonly MUSCLE_ARMS: string = '#E77A7A'
  static readonly MUSCLE_ABS: string = '#52BEB0'
  static readonly MUSCLE_DEFAULT: string = '#7F93AA'
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

  static readonly SMALL_SIZE: number = 12
  static readonly SMALL_LINE_HEIGHT: number = 16
  static readonly SMALL_WEIGHT: number = FontWeight.Normal

  static readonly TIMER_SIZE: number = 48
  static readonly TIMER_LINE_HEIGHT: number = 56
  static readonly TIMER_WEIGHT: number = FontWeight.Bold

  static readonly HERO_SIZE: number = 30
  static readonly HERO_LINE_HEIGHT: number = 48
  static readonly HERO_WEIGHT: number = FontWeight.Bold

  static readonly MICRO_SIZE: number = 8
  static readonly MICRO_LINE_HEIGHT: number = 14
  static readonly MICRO_WEIGHT: number = FontWeight.Normal
}

// ============================================================
// 3. 间距 Token（单位 vp）
// ============================================================
export class SpacingTokens {
  static readonly XXXS: number = 2
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
  static readonly XS: number = 4
  static readonly SM: number = 6
  static readonly MD: number = 8
  static readonly LG: number = 12
  static readonly XL: number = 16
  static readonly FULL: number = 9999
}

// ============================================================
// 5. 阴影 Token
// ============================================================
export interface ShadowConfig {
  radius: number
  color: string
  offsetX: number
  offsetY: number
}

export class ShadowTokens {
  static readonly SM: ShadowConfig = {
    radius: 10,
    color: 'rgba(0,0,0,0.22)',
    offsetX: 0,
    offsetY: 2
  }
  static readonly MD: ShadowConfig = {
    radius: 18,
    color: 'rgba(0,0,0,0.28)',
    offsetX: 0,
    offsetY: 6
  }
  static readonly LG: ShadowConfig = {
    radius: 24,
    color: 'rgba(0,0,0,0.34)',
    offsetX: 0,
    offsetY: 10
  }
  static readonly NONE: ShadowConfig = {
    radius: 0,
    color: 'rgba(0,0,0,0)',
    offsetX: 0,
    offsetY: 0
  }
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
  static readonly BUTTON_HEIGHT_LARGE: number = 56
  static readonly SEGMENT_HEIGHT: number = 40
  static readonly CARD_MEDIA_HEIGHT: number = 120
  static readonly CARD_COVER_SIZE: number = 64
  static readonly AVATAR_SIZE: number = 56
  static readonly HERO_HEIGHT: number = 200
  static readonly CALENDAR_CELL: number = 32
  static readonly PROGRESS_BAR_HEIGHT: number = 12
  static readonly TIMELINE_COL_WIDTH: number = 20
  static readonly MUSCLE_TAG_PADDING_V: number = 1
  static readonly MUSCLE_TAG_PADDING_H: number = 6
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
  static readonly GUTTER: number = 12
  static readonly MARGIN: number = 16
}

// ============================================================
// 9. 肌群颜色映射
// ============================================================
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

// ============================================================
// 10. 秒表计时器 Token
// ============================================================
export class StopwatchTokens {
  static readonly DIAL_BASE: string = '#161E2B'
  static readonly DIAL_OVERLAY: string = 'rgba(103,178,255,0.04)'
  static readonly DIAL_INNER: string = 'rgba(103,178,255,0.025)'
  static readonly BEZEL_STROKE: string = 'rgba(196,214,255,0.08)'
  static readonly SECOND_HAND: string = '#67B2FF'
  static readonly MINUTE_HAND: string = '#F5F8FC'
  static readonly TICK_MAJOR: string = 'rgba(245,248,252,0.90)'
  static readonly TICK_MINOR: string = 'rgba(245,248,252,0.20)'
  static readonly SUBDIAL_FILL: string = '#121A26'
  static readonly SUBDIAL_STROKE: string = 'rgba(196,214,255,0.08)'
  static readonly CENTER_RING: string = 'rgba(103,178,255,0.24)'
  static readonly RUNNING_GLOW: string = 'rgba(233,168,71,0.30)'
  static readonly CASE_SIZE: number = 280
  static readonly CONTAINER_HEIGHT: number = 320
}

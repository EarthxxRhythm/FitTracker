/**
 * DesignTokens -- global visual design tokens.
 * Function #26
 */

export class ColorTokens {
  static readonly ACCENT_PRIMARY: string = '#45C9A1'
  static readonly ACCENT_HOVER: string = '#61E0B5'
  static readonly ACCENT_SOFT: string = '#8CEBCC'
  static readonly ACCENT_DEEP: string = '#287A63'
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
  static readonly NEUTRAL_300: string = '#6E8078'
  static readonly NEUTRAL_400: string = '#2A3934'
  static readonly NEUTRAL_500: string = '#000000'

  static readonly SUCCESS: string = '#54C89C'
  static readonly SUCCESS_LIGHT: string = ColorTokens.ACCENT_SOFT
  static readonly WARNING: string = ColorTokens.ACCENT_GOLD
  static readonly ERROR: string = '#D77C78'
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
  static readonly SURFACE_BUTTON_SECONDARY: string = '#1A2825'
  static readonly SURFACE_BUTTON_SECONDARY_PRESSED: string = '#20332E'
  static readonly SURFACE_BUTTON_GHOST_PRESSED: string = 'rgba(69,201,161,0.10)'
  static readonly BORDER_DEFAULT: string = '#2A3934'
  static readonly BORDER_SUBTLE: string = 'rgba(42,57,52,0.55)'
  static readonly BORDER_STRONG: string = 'rgba(42,57,52,0.92)'
  static readonly BORDER_ACCENT: string = 'rgba(69,201,161,0.32)'
  static readonly DIVIDER: string = 'rgba(42,57,52,0.48)'
  static readonly FOCUS_RING: string = 'rgba(69,201,161,0.20)'

  static readonly TEXT_PRIMARY: string = '#EDF6F2'
  static readonly TEXT_SECONDARY: string = '#A3B3AD'
  static readonly TEXT_TERTIARY: string = '#6E8078'
  static readonly TEXT_DISABLED: string = '#53625D'
  static readonly TEXT_ON_PRIMARY: string = '#09100F'

  static readonly OVERLAY_PRIMARY: string = 'rgba(69,201,161,0.12)'
  static readonly OVERLAY_SUCCESS: string = 'rgba(84,200,156,0.12)'
  static readonly OVERLAY_ACCENT: string = 'rgba(181,152,105,0.14)'

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
}

export class RadiusTokens {
  static readonly XS: number = 4
  static readonly SM: number = 8
  static readonly MD: number = 12
  static readonly LG: number = 16
  static readonly XL: number = 16
  static readonly FULL: number = 9999
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
  static readonly DURATION_FAST: number = 150
  static readonly DURATION_BASE: number = 250
  static readonly DURATION_SLOW: number = 400
  static readonly EASE_IN_OUT: string = 'cubic-bezier(0.4, 0.0, 0.2, 1.0)'
  static readonly EASE_OUT: string = 'cubic-bezier(0.0, 0.0, 0.2, 1.0)'
}

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

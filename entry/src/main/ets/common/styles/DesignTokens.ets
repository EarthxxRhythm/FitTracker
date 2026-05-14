/**
 * FitTracker Design Tokens
 * 全局设计令牌 —— 所有视觉属性均定义于此，组件禁止硬编码色值/字号/间距。
 * 产品原型主色调：蓝色 (#1E88E5)，深色主题为默认模式。
 */
// ============================================================
// 1. 颜色 Token
// ============================================================
export class ColorTokens {
  /* 品牌主色 — 蓝色系 */
  static readonly PRIMARY: string = '#1E88E5'
  static readonly PRIMARY_HOVER: string = '#42A5F5'
  static readonly PRIMARY_PRESSED: string = '#1565C0'
  static readonly PRIMARY_DISABLED: string = '#90CAF9'

  /* 强调色 — 橙色 (统计数据、星标) */
  static readonly ACCENT: string = '#FF9800'
  static readonly ACCENT_LIGHT: string = '#FFB74D'

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
  static readonly SUCCESS: string = '#4cd964'
  static readonly SUCCESS_LIGHT: string = '#81C784'
  static readonly WARNING: string = '#FF9800'
  static readonly ERROR: string = '#F44336'
  static readonly INFO: string = '#1E88E5'
  static readonly NEW_RECORD: string = '#FFD700'
  static readonly NEW_RECORD_BG: string = 'rgba(255,215,0,0.15)'
  static readonly SUCCESS_BG: string = 'rgba(76,175,80,0.15)'

  /* 背景与表面 — 深色主题为默认 */
  static readonly BG_PRIMARY: string = '#0D1117'
  static readonly BG_SECONDARY: string = '#161B22'
  static readonly SURFACE_PRIMARY: string = '#2c2c2e'
  static readonly SURFACE_SECONDARY: string = '#212838'
  static readonly SURFACE_ELEVATED: string = '#2A3245'

  /* 文字色 */
  static readonly TEXT_PRIMARY: string = '#FFFFFF'
  static readonly TEXT_SECONDARY: string = '#A0AEC0'
  static readonly TEXT_DISABLED: string = '#555555'
  static readonly TEXT_ON_PRIMARY: string = '#FFFFFF'

  /* 半透明背景 */
  static readonly OVERLAY_PRIMARY: string = 'rgba(30,136,229,0.15)'
  static readonly OVERLAY_SUCCESS: string = 'rgba(76,175,80,0.15)'
  static readonly OVERLAY_ACCENT: string = 'rgba(255,152,0,0.15)'

  /* 肌群标签色 — 装饰性标识色 */
  static readonly MUSCLE_CHEST: string = '#1E88E5'
  static readonly MUSCLE_BACK: string = '#43A047'
  static readonly MUSCLE_LEGS: string = '#FB8C00'
  static readonly MUSCLE_SHOULDERS: string = '#8E24AA'
  static readonly MUSCLE_ARMS: string = '#E53935'
  static readonly MUSCLE_ABS: string = '#00897B'
  static readonly MUSCLE_DEFAULT: string = '#999999'
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
  static readonly SM: number = 8
  static readonly MD: number = 12
  static readonly LG: number = 16
  static readonly XL: number = 24
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
    radius: 4,
    color: 'rgba(0,0,0,0.3)',
    offsetX: 0,
    offsetY: 2
  }
  static readonly MD: ShadowConfig = {
    radius: 8,
    color: 'rgba(0,0,0,0.4)',
    offsetX: 0,
    offsetY: 4
  }
  static readonly LG: ShadowConfig = {
    radius: 16,
    color: 'rgba(0,0,0,0.5)',
    offsetX: 0,
    offsetY: 8
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
// 10. 秒表计时器 Token — Precision Instrument 风格
// ============================================================
export class StopwatchTokens {
  // 表盘深度层次
  static readonly DIAL_BASE: string = '#1a1e2b'
  static readonly DIAL_OVERLAY: string = 'rgba(30,136,229,0.04)'
  static readonly DIAL_INNER: string = 'rgba(30,136,229,0.025)'
  // 外表圈
  static readonly BEZEL_STROKE: string = 'rgba(255,255,255,0.06)'
  // 指针
  static readonly SECOND_HAND: string = '#4FC3F7'
  static readonly MINUTE_HAND: string = '#FFFFFF'
  // 刻度
  static readonly TICK_MAJOR: string = 'rgba(255,255,255,0.90)'
  static readonly TICK_MINOR: string = 'rgba(255,255,255,0.20)'
  // 子表盘
  static readonly SUBDIAL_FILL: string = '#1e2130'
  static readonly SUBDIAL_STROKE: string = 'rgba(255,255,255,0.06)'
  // 中心枢纽
  static readonly CENTER_RING: string = 'rgba(30,136,229,0.25)'
  static readonly RUNNING_GLOW: string = 'rgba(255,152,0,0.30)'
  // 布局
  static readonly CASE_SIZE: number = 280
  static readonly CONTAINER_HEIGHT: number = 320
}

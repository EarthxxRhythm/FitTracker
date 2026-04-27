/**
 * FitTracker Typography Styles
 * 通过 @Extend 装饰器复用的文字样式函数，遵循 BEM 命名：block_element-modifier
 */
import { FontTokens, ColorTokens } from './DesignTokens'

// ── 大标题（Display）───────────────────────────────────────
@Extend(Text)
function textDisplay() {
  .fontSize(FontTokens.DISPLAY_SIZE)
  .lineHeight(FontTokens.DISPLAY_LINE_HEIGHT)
  .fontWeight(FontTokens.DISPLAY_WEIGHT)
  .fontColor(ColorTokens.TEXT_PRIMARY)
  .fontFamily(FontTokens.FAMILY_BASE)
}

// ── 页面标题（Headline）─────────────────────────────────────
@Extend(Text)
function textHeadline() {
  .fontSize(FontTokens.HEADLINE_SIZE)
  .lineHeight(FontTokens.HEADLINE_LINE_HEIGHT)
  .fontWeight(FontTokens.HEADLINE_WEIGHT)
  .fontColor(ColorTokens.TEXT_PRIMARY)
  .fontFamily(FontTokens.FAMILY_BASE)
}

// ── 卡片/对话框标题（Title）─────────────────────────────────
@Extend(Text)
function textTitle() {
  .fontSize(FontTokens.TITLE_SIZE)
  .lineHeight(FontTokens.TITLE_LINE_HEIGHT)
  .fontWeight(FontTokens.TITLE_WEIGHT)
  .fontColor(ColorTokens.TEXT_PRIMARY)
  .fontFamily(FontTokens.FAMILY_BASE)
}

// ── 正文（Body）─────────────────────────────────────────────
@Extend(Text)
function textBody() {
  .fontSize(FontTokens.BODY_SIZE)
  .lineHeight(FontTokens.BODY_LINE_HEIGHT)
  .fontWeight(FontTokens.BODY_WEIGHT)
  .fontColor(ColorTokens.TEXT_PRIMARY)
  .fontFamily(FontTokens.FAMILY_BASE)
}

// ── 正文加粗（Body-Bold）────────────────────────────────────
@Extend(Text)
function textBodyBold() {
  .fontSize(FontTokens.BODY_BOLD_SIZE)
  .lineHeight(FontTokens.BODY_BOLD_LINE_HEIGHT)
  .fontWeight(FontTokens.BODY_BOLD_WEIGHT)
  .fontColor(ColorTokens.TEXT_PRIMARY)
  .fontFamily(FontTokens.FAMILY_BASE)
}

// ── 辅助说明（Caption）─────────────────────────────────────
@Extend(Text)
function textCaption() {
  .fontSize(FontTokens.CAPTION_SIZE)
  .lineHeight(FontTokens.CAPTION_LINE_HEIGHT)
  .fontWeight(FontTokens.CAPTION_WEIGHT)
  .fontColor(ColorTokens.TEXT_SECONDARY)
  .fontFamily(FontTokens.FAMILY_BASE)
}

// ── 标签/时间戳（Small）─────────────────────────────────────
@Extend(Text)
function textSmall() {
  .fontSize(FontTokens.SMALL_SIZE)
  .lineHeight(FontTokens.SMALL_LINE_HEIGHT)
  .fontWeight(FontTokens.SMALL_WEIGHT)
  .fontColor(ColorTokens.TEXT_SECONDARY)
  .fontFamily(FontTokens.FAMILY_BASE)
}

// ── 计时器（Timer）─────────────────────────────────────────
@Extend(Text)
function textTimer() {
  .fontSize(FontTokens.TIMER_SIZE)
  .lineHeight(FontTokens.TIMER_LINE_HEIGHT)
  .fontWeight(FontTokens.TIMER_WEIGHT)
  .fontColor(ColorTokens.TEXT_PRIMARY)
  .fontFamily(FontTokens.FAMILY_MONO)
}

// ── 卡片标题（复用在 AppCard 等场景）────────────────────────
@Extend(Text)
function cardTitle() {
  .fontSize(FontTokens.TITLE_SIZE)
  .lineHeight(FontTokens.TITLE_LINE_HEIGHT)
  .fontWeight(FontTokens.TITLE_WEIGHT)
  .fontColor(ColorTokens.TEXT_PRIMARY)
  .fontFamily(FontTokens.FAMILY_BASE)
}

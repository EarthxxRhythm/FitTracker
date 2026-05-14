/**
 * StatBadge —— 数据标签组件
 *
 * 用途: “新纪录”、“约115kg”等轻量标记
 *
 * 变体: gold（新纪录金色）| positive（正向绿色）| neutral（默认灰色）
 * 尺寸: small | medium
 *
 * 禁止: 背景和文字颜色必须从语义 token 派生
 */
import { ColorTokens, FontTokens, RadiusTokens, SpacingTokens } from '../common/styles/DesignTokens'

@Component
export struct StatBadge {
  @Prop text: string = ''
  @Prop color: 'gold' | 'positive' | 'neutral' = 'neutral'
  @Prop badgeSize: 'small' | 'medium' = 'small'

  build() {
    Text(this.text)
      .fontSize(this.badgeSize === 'small'
        ? FontTokens.SMALL_SIZE
        : FontTokens.BODY_SIZE)
      .fontColor(this.color === 'gold'
        ? ColorTokens.NEW_RECORD
        : this.color === 'positive'
          ? ColorTokens.SUCCESS
          : ColorTokens.TEXT_SECONDARY)
      .backgroundColor(this.color === 'gold'
        ? ColorTokens.NEW_RECORD_BG
        : this.color === 'positive'
          ? ColorTokens.SUCCESS_BG
          : ColorTokens.SURFACE_SECONDARY)
      .borderRadius(RadiusTokens.SM)
      .padding({
        left: SpacingTokens.XS,
        right: SpacingTokens.XS,
        top: 2,
        bottom: 2
      })
  }
}

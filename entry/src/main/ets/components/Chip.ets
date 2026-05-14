/**
 * Chip —— 标签/徽章组件
 */
import { ColorTokens, FontTokens, SpacingTokens, RadiusTokens } from '../common/styles/DesignTokens'

@Component
export struct Chip {
  @Prop label: string = ''
  @Prop color: string = ColorTokens.MUSCLE_DEFAULT
  @Prop chipSize: string = 'sm'

  build() {
    Text(this.label)
      .fontSize(this.chipSize === 'sm' ? FontTokens.MICRO_SIZE : FontTokens.CAPTION_SIZE)
      .fontColor(ColorTokens.TEXT_ON_PRIMARY)
      .padding({
        top: SpacingTokens.XXXS,
        bottom: SpacingTokens.XXXS,
        left: SpacingTokens.SM,
        right: SpacingTokens.SM
      })
      .backgroundColor(this.color)
      .borderRadius(RadiusTokens.FULL)
  }
}

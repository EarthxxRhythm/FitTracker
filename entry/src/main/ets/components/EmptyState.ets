/**
 * EmptyState —— 空状态占位组件
 */
import { ColorTokens, FontTokens, SpacingTokens, RadiusTokens } from '../common/styles/DesignTokens'

@Component
export struct EmptyState {
  @Prop icon: string = '📋'
  @Prop title: string = ''
  @Prop subtitle: string = ''
  @BuilderParam action?: () => void

  build() {
    // DESIGN: EmptyState presents an icon, a title, optional subtitle and an optional action slot.
    Column() {
      Text(this.icon)
        .fontSize(FontTokens.HERO_SIZE)
        .fontColor(ColorTokens.TEXT_PRIMARY)
        .margin({ bottom: SpacingTokens.MD })

      Text(this.title)
        .fontSize(FontTokens.TITLE_SIZE)
        .fontWeight(FontWeight.Medium)
        .fontColor(ColorTokens.TEXT_PRIMARY)

      if (this.subtitle) {
        Text(this.subtitle)
          .fontSize(FontTokens.CAPTION_SIZE)
          .fontColor(ColorTokens.TEXT_SECONDARY)
          .textAlign(TextAlign.Center)
          .margin({ top: SpacingTokens.XS })
      }

      if (this.action) {
        Column() {
          this.action()
        }
        .margin({ top: SpacingTokens.MD })
      }
    }
    .width('100%')
    .padding(SpacingTokens.LG)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }
}

/**
 * SectionHeader -- shared title row with optional trailing action.
 */
import { ColorTokens, FontTokens, SpacingTokens } from '../common/styles/DesignTokens'

@Component
export struct SectionHeader {
  @Prop title: string = ''
  @Prop actionText: string = ''
  onActionClick?: () => void

  build() {
    Row() {
      Text(this.title)
        .fontSize(FontTokens.SECTION_TITLE_SIZE)
        .lineHeight(FontTokens.SECTION_TITLE_LINE_HEIGHT)
        .fontWeight(FontTokens.SECTION_TITLE_WEIGHT)
        .fontColor(ColorTokens.TEXT_ON_DARK)
        .layoutWeight(1)

      if (this.actionText.length > 0) {
        Button({ type: ButtonType.Normal }) {
          Row({ space: SpacingTokens.XS }) {
            Text(this.actionText)
              .fontSize(FontTokens.SMALL_SIZE)
              .fontWeight(FontWeight.Medium)
              .fontColor(ColorTokens.TEXT_ON_DARK_SECONDARY)

            Text('\u203a')
              .fontSize(FontTokens.BODY_SIZE)
              .fontColor(ColorTokens.TEXT_ON_DARK_FAINT)
          }
        }
        .padding({ left: 0, right: 0 })
        .backgroundColor('rgba(0,0,0,0)')
        .onClick(() => {
          this.onActionClick?.()
        })
      }
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }
}

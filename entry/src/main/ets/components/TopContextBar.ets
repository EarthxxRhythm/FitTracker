/**
 * TopContextBar -- compact home header with date, greeting, and utility action.
 */
import { ColorTokens, FontTokens, RadiusTokens, SpacingTokens, TouchTokens } from '../common/styles/DesignTokens'

@Component
export struct TopContextBar {
  @Prop dateText: string = ''
  @Prop greetingText: string = ''
  @Prop actionLabel: string = '\u56de\u987e'
  onActionClick?: () => void

  build() {
    Row() {
      Column({ space: SpacingTokens.XS }) {
        Text(this.dateText)
          .fontSize(FontTokens.SMALL_SIZE)
          .fontColor(ColorTokens.TEXT_ON_DARK_SECONDARY)
          .maxLines(1)

        Text(this.greetingText)
          .fontSize(FontTokens.DISPLAY_HOME_SIZE)
          .lineHeight(FontTokens.DISPLAY_HOME_LINE_HEIGHT)
          .fontWeight(FontTokens.DISPLAY_HOME_WEIGHT)
          .fontColor(ColorTokens.TEXT_ON_DARK)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Button({ type: ButtonType.Normal }) {
        Text(this.actionLabel)
          .fontSize(FontTokens.SMALL_SIZE)
          .fontWeight(FontWeight.Medium)
          .fontColor(ColorTokens.TEXT_ON_DARK)
      }
      .width(TouchTokens.TOP_CONTEXT_BUTTON)
      .height(TouchTokens.TOP_CONTEXT_BUTTON)
      .backgroundColor(ColorTokens.SURFACE_GLASS)
      .border({ width: 1, color: ColorTokens.BORDER_GLASS })
      .borderRadius(RadiusTokens.FULL)
      .onClick(() => {
        this.onActionClick?.()
      })
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }
}

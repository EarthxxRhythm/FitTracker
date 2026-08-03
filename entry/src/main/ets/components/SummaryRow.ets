/**
 * SummaryRow -- compact summary item for plan boundary and settings-like cards.
 */
import { ColorTokens, FontTokens, SpacingTokens, TouchTokens } from '../common/styles/DesignTokens'

@Component
export struct SummaryRow {
  @Prop markerText: string = ''
  @Prop label: string = ''
  @Prop value: string = ''
  @Prop showChevron: boolean = true
  onRowClick?: () => void

  build() {
    Button({ type: ButtonType.Normal }) {
      Row({ space: SpacingTokens.SM }) {
        Row() {
          Text(this.markerText)
            .fontSize(FontTokens.SMALL_SIZE)
            .fontWeight(FontWeight.Medium)
            .fontColor(ColorTokens.TEXT_ON_DARK)
        }
        .width(32)
        .height(32)
        .justifyContent(FlexAlign.Center)
        .backgroundColor(ColorTokens.SURFACE_GLASS)
        .border({ width: 1, color: ColorTokens.BORDER_GLASS })
        .borderRadius(10)

        Text(this.label)
          .fontSize(FontTokens.CARD_TITLE_SIZE)
          .lineHeight(FontTokens.CARD_TITLE_LINE_HEIGHT)
          .fontWeight(FontTokens.CARD_TITLE_WEIGHT)
          .fontColor(ColorTokens.TEXT_ON_DARK)
          .layoutWeight(1)
          .maxLines(1)

        Column() {
          Text(this.value)
            .fontSize(FontTokens.SMALL_SIZE)
            .fontColor(ColorTokens.TEXT_ON_DARK_SECONDARY)
            .maxLines(1)
            .textAlign(TextAlign.End)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .width('40%')
        .alignItems(HorizontalAlign.End)

        if (this.showChevron) {
          Text('\u203a')
            .fontSize(FontTokens.BODY_SIZE)
            .fontColor(ColorTokens.TEXT_ON_DARK_FAINT)
        }
      }
      .width('100%')
      .padding({
        left: SpacingTokens.MD,
        right: SpacingTokens.MD,
        top: SpacingTokens.SM,
        bottom: SpacingTokens.SM
      })
      .justifyContent(FlexAlign.Start)
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .constraintSize({ minHeight: TouchTokens.MIN_TARGET })
    .padding({ left: 0, right: 0 })
    .backgroundColor('rgba(0,0,0,0)')
    .onClick(() => {
      this.onRowClick?.()
    })
  }
}

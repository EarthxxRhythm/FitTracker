/**
 * PlanDayDetailPage -- plan day placeholder
 * Function #5: Routes and placeholder pages
 */
import { ColorTokens, FontTokens, SpacingTokens } from '../../../common/styles/DesignTokens'

@Entry
@Component
export struct PlanDayDetailPage {
  build() {
    Column() {
      Text('Plan Day')
        .fontSize(FontTokens.DISPLAY_SIZE)
        .fontWeight(FontTokens.DISPLAY_WEIGHT)
        .fontColor(ColorTokens.TEXT_PRIMARY)

      Text('Plan Day placeholder')
        .fontSize(FontTokens.BODY_SIZE)
        .fontColor(ColorTokens.TEXT_SECONDARY)
        .margin({ top: SpacingTokens.SM })
    }
    .width('100%')
    .height('100%')
    .padding(SpacingTokens.LG)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor(ColorTokens.BG_PRIMARY)
  }
}

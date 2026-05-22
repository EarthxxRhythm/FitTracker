/**
 * ActiveWorkoutPage -- active workout placeholder
 * Function #5: Routes and placeholder pages
 */
import { ColorTokens, FontTokens, SpacingTokens } from '../../../common/styles/DesignTokens'

@Entry
@Component
export struct ActiveWorkoutPage {
  build() {
    Column() {
      Text('Active Workout')
        .fontSize(FontTokens.DISPLAY_SIZE)
        .fontWeight(FontTokens.DISPLAY_WEIGHT)
        .fontColor(ColorTokens.TEXT_PRIMARY)

      Text('Active Workout placeholder')
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

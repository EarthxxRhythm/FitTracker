/**
 * StartupPage -- application startup placeholder
 * Function #5: Routes and placeholder pages
 */
import { router } from '@kit.ArkUI'
import { ColorTokens, FontTokens, SpacingTokens } from '../common/styles/DesignTokens'
import { StartupDecision } from './AppState'

@Entry
@Component
export struct StartupPage {
  aboutToAppear(): void {
    try {
      router.replaceUrl({ url: StartupDecision.getInitialRoute(false) })
    } catch (e) {
      // Keep the startup placeholder visible if route replacement fails.
    }
  }

  build() {
    Column() {
      Text('FitTracker')
        .fontSize(FontTokens.DISPLAY_SIZE)
        .fontWeight(FontTokens.DISPLAY_WEIGHT)
        .fontColor(ColorTokens.TEXT_PRIMARY)

      Text('Startup placeholder')
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

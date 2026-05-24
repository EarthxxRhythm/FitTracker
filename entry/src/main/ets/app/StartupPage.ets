/**
 * StartupPage -- application startup router.
 * Function #8: target-driven workout loop.
 */
import { router } from '@kit.ArkUI'
import { ColorTokens, FontTokens, SpacingTokens } from '../common/styles/DesignTokens'
import { StartupDecision } from './AppState'
import GoalRepository from '../shared/services/GoalRepository'

@Entry
@Component
export struct StartupPage {
  async aboutToAppear(): Promise<void> {
    try {
      const hasGoal: boolean = await GoalRepository.hasSavedGoal(getContext(this))
      router.replaceUrl({ url: StartupDecision.getInitialRoute(hasGoal) })
    } catch (e) {
      // Keep the startup screen visible if route replacement fails.
    }
  }

  build() {
    Column() {
      Text('FitTracker')
        .fontSize(FontTokens.DISPLAY_SIZE)
        .fontWeight(FontTokens.DISPLAY_WEIGHT)
        .fontColor(ColorTokens.TEXT_PRIMARY)

      Text('正在准备今日训练')
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

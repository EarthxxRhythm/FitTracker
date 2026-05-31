/**
 * StartupPage -- application startup router.
 * Function #8: target-driven workout loop.
 */
import { router } from '@kit.ArkUI'
import { ColorTokens, FontTokens, SpacingTokens } from '../common/styles/DesignTokens'
import { StartupDecision } from './AppState'
import { AppRoutes } from './AppRoutes'
import ContentDatabaseService from '../shared/services/ContentDatabaseService'
import GoalRepository from '../shared/services/GoalRepository'
import PersistenceFallbackService from '../shared/services/PersistenceFallbackService'
import SessionManager from '../common/services/SessionManager'

@Entry
@Component
export struct StartupPage {
  async aboutToAppear(): Promise<void> {
    try {
      const isLoggedIn: boolean = await SessionManager.isLoggedIn(getContext(this))
      if (!isLoggedIn) {
        router.replaceUrl({ url: AppRoutes.LOGIN })
        return
      }
      const contentLoaded: boolean = await ContentDatabaseService.loadDatabaseAndUse(getContext(this))
      if (!contentLoaded) {
        await ContentDatabaseService.importSeedAndUseDatabase(getContext(this))
      }
      const hasGoal: boolean = await GoalRepository.hasSavedGoal(getContext(this))
      if (!hasGoal && GoalRepository.getLastPersistenceError().length > 0) {
        PersistenceFallbackService.recordFallback(
          'goal',
          GoalRepository.getLastPersistenceError(),
          'default_goal',
          Date.now()
        )
        GoalRepository.saveLocalGoal(PersistenceFallbackService.createDefaultGoal(Date.now()))
        router.replaceUrl({ url: StartupDecision.getInitialRoute(true) })
        return
      }
      const initialRoute: string = StartupDecision.getInitialRoute(hasGoal)
      router.replaceUrl({ url: initialRoute })
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

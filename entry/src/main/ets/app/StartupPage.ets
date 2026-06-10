/**
 * StartupPage -- application startup router.
 * Function #8: target-driven workout loop.
 */
import { Context } from '@kit.AbilityKit'
import { ColorTokens, FontTokens, SpacingTokens } from '../common/styles/DesignTokens'
import { StartupDecision } from './AppState'
import { AppRoutes } from './AppRoutes'
import ContentRepository from '../shared/services/ContentRepository'
import GoalRepository from '../shared/services/GoalRepository'
import PersistenceFallbackService from '../shared/services/PersistenceFallbackService'
import StartupContentSyncService from '../shared/services/StartupContentSyncService'
import SessionManager from '../common/services/SessionManager'

@Entry
@Component
export struct StartupPage {
  private getHostContextOrNull(): Context | null {
    const hostContext = this.getUIContext().getHostContext()
    if (hostContext === undefined || hostContext === null) {
      return null
    }
    return hostContext as Context
  }

  async aboutToAppear(): Promise<void> {
    try {
      const context: Context | null = this.getHostContextOrNull()
      if (context === null) {
        return
      }
      const pageRouter = this.getUIContext().getRouter()
      const isLoggedIn: boolean = await SessionManager.isLoggedIn(context)
      if (!isLoggedIn) {
        pageRouter.replaceUrl({ url: AppRoutes.LOGIN })
        return
      }
      try {
        await StartupContentSyncService.prepareContent(context)
      } catch (error) {
        ContentRepository.useJsonlSeedSource()
      }
      const hasGoal: boolean = await GoalRepository.hasSavedGoal(context)
      if (!hasGoal && GoalRepository.getLastPersistenceError().length > 0) {
        PersistenceFallbackService.recordFallback(
          'goal',
          GoalRepository.getLastPersistenceError(),
          'default_goal',
          Date.now()
        )
        GoalRepository.saveLocalGoal(PersistenceFallbackService.createDefaultGoal(Date.now()))
        pageRouter.replaceUrl({ url: StartupDecision.getInitialRoute(true) })
        return
      }
      const initialRoute: string = StartupDecision.getInitialRoute(hasGoal)
      pageRouter.replaceUrl({ url: initialRoute })
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

/**
 * StartupPage -- application startup router.
 * Function #8: target-driven workout loop.
 */
import { Context } from '@kit.AbilityKit'
import { ColorTokens, FontTokens, RadiusTokens, SpacingTokens } from '../common/styles/DesignTokens'
import { AppCard } from '../components/AppCard'
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
  @State currentStage: number = 0
  @State statusTitle: string = '准备启动'
  @State statusDetail: string = '正在检查登录状态、本地内容和今日训练入口。'

  private getHostContextOrNull(): Context | null {
    const hostContext = this.getUIContext().getHostContext()
    if (hostContext === undefined || hostContext === null) {
      return null
    }
    return hostContext as Context
  }

  private setStartupState(stage: number, title: string, detail: string): void {
    this.currentStage = stage
    this.statusTitle = title
    this.statusDetail = detail
  }

  private isCurrentStage(index: number): boolean {
    return this.currentStage === index
  }

  private isCompletedStage(index: number): boolean {
    return this.currentStage > index
  }

  private getStageStatusLabel(index: number): string {
    if (this.isCompletedStage(index)) {
      return '已就绪'
    }
    if (this.isCurrentStage(index)) {
      return '进行中'
    }
    return '待处理'
  }

  async aboutToAppear(): Promise<void> {
    try {
      const context: Context | null = this.getHostContextOrNull()
      if (context === null) {
        this.setStartupState(0, '等待宿主上下文', '当前还没有可用的应用上下文，稍后会继续进入训练入口。')
        return
      }
      const pageRouter = this.getUIContext().getRouter()
      this.setStartupState(0, '校验登录状态', '先确认当前设备上的本地账号状态，再决定进入登录还是继续恢复训练数据。')
      const isLoggedIn: boolean = await SessionManager.isLoggedIn(context)
      if (!isLoggedIn) {
        this.setStartupState(0, '准备进入登录', '还没有检测到可恢复的登录态，正在跳转到本地登录入口。')
        pageRouter.replaceUrl({ url: AppRoutes.LOGIN })
        return
      }
      this.setStartupState(1, '同步本地内容', '正在加载动作库和本地同步包，确保训练详情与媒体入口使用同一份内容基线。')
      try {
        await StartupContentSyncService.prepareContent(context)
      } catch (error) {
        ContentRepository.useJsonlSeedSource()
        this.setStartupState(1, '已回退到本地种子内容', '内容同步没有完成，先用应用内置内容继续启动，不阻塞今天的训练。')
      }
      this.setStartupState(2, '整理今日入口', '正在恢复目标与训练状态，准备把你带回今天应该进入的页面。')
      const hasGoal: boolean = await GoalRepository.hasSavedGoal(context)
      if (!hasGoal && GoalRepository.getLastPersistenceError().length > 0) {
        PersistenceFallbackService.recordFallback(
          'goal',
          GoalRepository.getLastPersistenceError(),
          'default_goal',
          Date.now()
        )
        GoalRepository.saveLocalGoal(PersistenceFallbackService.createDefaultGoal(Date.now()))
        this.setStartupState(2, '已生成默认目标', '本地目标读取失败，先用恢复目标兜底，保证你仍能直接进入主流程。')
        pageRouter.replaceUrl({ url: StartupDecision.getInitialRoute(true) })
        return
      }
      const initialRoute: string = StartupDecision.getInitialRoute(hasGoal)
      this.setStartupState(2, '即将进入训练主线', hasGoal
        ? '今日训练入口已准备完成，正在跳转到首页。'
        : '还没有完成目标设定，正在跳转到目标设置入口。')
      pageRouter.replaceUrl({ url: initialRoute })
    } catch (e) {
      this.setStartupState(2, '启动暂时停留在当前页', '路由切换没有成功完成。可以稍候重试，当前训练数据不会丢失。')
    }
  }

  @Builder
  buildStageChip(index: number, label: string) {
    Text(label)
      .fontSize(FontTokens.SMALL_SIZE)
      .fontWeight(this.isCurrentStage(index) ? FontWeight.Medium : FontTokens.SMALL_WEIGHT)
      .fontColor(this.isCurrentStage(index) || this.isCompletedStage(index) ?
        ColorTokens.TEXT_PRIMARY : ColorTokens.TEXT_TERTIARY)
      .padding({
        top: SpacingTokens.XS,
        bottom: SpacingTokens.XS,
        left: SpacingTokens.SM,
        right: SpacingTokens.SM
      })
      .backgroundColor(this.isCurrentStage(index) ? ColorTokens.SURFACE_ELEVATED :
        (this.isCompletedStage(index) ? ColorTokens.OVERLAY_PRIMARY : ColorTokens.SURFACE_SECONDARY))
      .borderRadius(RadiusTokens.FULL)
      .border({
        width: 1,
        color: this.isCurrentStage(index) || this.isCompletedStage(index) ?
          ColorTokens.BORDER_ACCENT : ColorTokens.BORDER_SUBTLE
      })
  }

  @Builder
  buildStatusRow(index: number, title: string, description: string) {
    Row({ space: SpacingTokens.SM }) {
      Text(this.getStageStatusLabel(index))
        .fontSize(FontTokens.CAPTION_SIZE)
        .fontColor(this.isCompletedStage(index) ? ColorTokens.SUCCESS :
          (this.isCurrentStage(index) ? ColorTokens.PRIMARY : ColorTokens.TEXT_TERTIARY))
        .padding({
          top: SpacingTokens.XS,
          bottom: SpacingTokens.XS,
          left: SpacingTokens.SM,
          right: SpacingTokens.SM
        })
        .backgroundColor(this.isCompletedStage(index) ? ColorTokens.SUCCESS_BG :
          (this.isCurrentStage(index) ? ColorTokens.OVERLAY_PRIMARY : ColorTokens.SURFACE_SECONDARY))
        .borderRadius(RadiusTokens.FULL)

      Column({ space: SpacingTokens.XS }) {
        Text(title)
          .fontSize(FontTokens.BODY_SIZE)
          .fontWeight(FontWeight.Medium)
          .fontColor(ColorTokens.TEXT_PRIMARY)
          .width('100%')

        Text(description)
          .fontSize(FontTokens.CAPTION_SIZE)
          .fontColor(ColorTokens.TEXT_SECONDARY)
          .width('100%')
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
  }

  build() {
    Column() {
      AppCard({ variant: 'panel', cardPadding: 'default' }) {
        Column({ space: SpacingTokens.LG }) {
          Column({ space: SpacingTokens.XS }) {
            Text('FitTracker')
              .fontSize(FontTokens.DISPLAY_SIZE)
              .fontWeight(FontTokens.DISPLAY_WEIGHT)
              .fontColor(ColorTokens.TEXT_PRIMARY)

            Text('Performance Lab')
              .fontSize(FontTokens.CAPTION_SIZE)
              .fontColor(ColorTokens.PRIMARY)
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)

          Row({ space: SpacingTokens.SM }) {
            this.buildStageChip(0, '登录')
            this.buildStageChip(1, '同步')
            this.buildStageChip(2, '进入')
          }
          .width('100%')

          Column({ space: SpacingTokens.XS }) {
            Text(this.statusTitle)
              .fontSize(FontTokens.TITLE_SIZE)
              .fontWeight(FontTokens.TITLE_WEIGHT)
              .fontColor(ColorTokens.TEXT_PRIMARY)
              .width('100%')

            Text(this.statusDetail)
              .fontSize(FontTokens.BODY_SIZE)
              .fontColor(ColorTokens.TEXT_SECONDARY)
              .lineHeight(FontTokens.BODY_LINE_HEIGHT)
              .width('100%')
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)

          Column({ space: SpacingTokens.MD }) {
            this.buildStatusRow(0, '登录状态', '确认本地账号是否可直接恢复，避免重复进入注册或登录。')
            this.buildStatusRow(1, '内容基线', '优先加载数据库或同步包，确保动作详情、媒体与训练预览口径一致。')
            this.buildStatusRow(2, '今日入口', '按目标与恢复状态选择首页或目标设置页，不让启动停在空白入口。')
          }
          .width('100%')
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }
    }
    .width('100%')
    .height('100%')
    .padding(SpacingTokens.LG)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor(ColorTokens.BG_PRIMARY)
  }
}

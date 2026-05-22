/**
 * WorkoutSummaryPage -- post-workout summary review.
 * Function #11: workout summary review.
 */
import { router } from '@kit.ArkUI'
import { AppRoutes } from '../../../app/AppRoutes'
import { ColorTokens, FontTokens, RadiusTokens, SpacingTokens, TouchTokens } from '../../../common/styles/DesignTokens'
import { WorkoutSession } from '../../../shared/models/TrainingModels'
import WorkoutRepository from '../../../shared/services/WorkoutRepository'
import WorkoutSummaryService, { WorkoutSummary } from '../../../shared/services/WorkoutSummaryService'

@Entry
@Component
export struct WorkoutSummaryPage {
  @State loading: boolean = true
  @State hasSession: boolean = false
  @State sessionId: string = ''
  @State dayId: string = ''
  @State durationText: string = '0 分钟'
  @State completedSets: number = 0
  @State targetSets: number = 0
  @State completionRate: number = 0
  @State totalVolume: number = 0

  aboutToAppear(): void {
    this.loading = true
    const session: WorkoutSession | undefined = this.findSession()
    if (session === undefined) {
      this.applySummary(WorkoutSummaryService.createEmptySummary())
      this.loading = false
      return
    }

    const summary: WorkoutSummary = WorkoutSummaryService.createSummary(session)
    this.applySummary(summary)
    this.loading = false
  }

  findSession(): WorkoutSession | undefined {
    const routeSessionId: string = this.getRouteSessionId()
    if (routeSessionId.length > 0) {
      const session: WorkoutSession | undefined = WorkoutRepository.getSessionById(routeSessionId)
      if (session !== undefined) {
        return session
      }
    }
    return WorkoutRepository.getLatestSession()
  }

  getRouteSessionId(): string {
    try {
      const params = router.getParams() as Record<string, string>
      if (params.sessionId !== undefined) {
        return params.sessionId
      }
    } catch (e) {
      return ''
    }
    return ''
  }

  applySummary(summary: WorkoutSummary): void {
    this.hasSession = summary.hasSession
    this.sessionId = summary.sessionId
    this.dayId = summary.dayId
    this.durationText = summary.durationText
    this.completedSets = summary.completedSets
    this.targetSets = summary.targetSets
    this.completionRate = summary.completionRate
    this.totalVolume = summary.totalVolume
  }

  openHome(): void {
    try {
      router.replaceUrl({ url: AppRoutes.HOME })
    } catch (e) {
      // stay on summary
    }
  }

  openReview(): void {
    try {
      router.pushUrl({ url: AppRoutes.REVIEW_HOME })
    } catch (e) {
      // stay on summary
    }
  }

  getCompletionText(): string {
    return this.completionRate.toString() + '%'
  }

  getProgressWidth(): string {
    if (this.completionRate <= 0) {
      return '1%'
    }
    if (this.completionRate > 100) {
      return '100%'
    }
    return this.completionRate.toString() + '%'
  }

  @Builder
  buildMetric(label: string, value: string) {
    Column({ space: SpacingTokens.XS }) {
      Text(value)
        .fontSize(FontTokens.HEADLINE_SIZE)
        .fontWeight(FontTokens.HEADLINE_WEIGHT)
        .fontColor(ColorTokens.TEXT_PRIMARY)

      Text(label)
        .fontSize(FontTokens.CAPTION_SIZE)
        .fontColor(ColorTokens.TEXT_SECONDARY)
    }
    .layoutWeight(1)
    .padding(SpacingTokens.MD)
    .borderRadius(RadiusTokens.SM)
    .backgroundColor(ColorTokens.SURFACE_PRIMARY)
    .alignItems(HorizontalAlign.Center)
  }

  build() {
    Scroll() {
      Column({ space: SpacingTokens.LG }) {
        Column({ space: SpacingTokens.SM }) {
          Text('训练复盘')
            .fontSize(FontTokens.DISPLAY_SIZE)
            .fontWeight(FontTokens.DISPLAY_WEIGHT)
            .fontColor(ColorTokens.TEXT_PRIMARY)

          Text(this.loading ? '正在整理本次训练' : '本次训练已经保存到本地记录')
            .fontSize(FontTokens.BODY_SIZE)
            .fontColor(ColorTokens.TEXT_SECONDARY)
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)

        if (!this.loading && !this.hasSession) {
          Column({ space: SpacingTokens.MD }) {
            Text('没有找到训练记录')
              .fontSize(FontTokens.TITLE_SIZE)
              .fontWeight(FontTokens.TITLE_WEIGHT)
              .fontColor(ColorTokens.TEXT_PRIMARY)

            Text('可能是从复盘页直接进入，先回到首页开始一次训练。')
              .fontSize(FontTokens.BODY_SIZE)
              .fontColor(ColorTokens.TEXT_SECONDARY)

            Button('回到首页')
              .width('100%')
              .height(TouchTokens.BUTTON_HEIGHT_LARGE)
              .fontSize(FontTokens.BODY_SIZE)
              .fontColor(ColorTokens.TEXT_ON_PRIMARY)
              .backgroundColor(ColorTokens.PRIMARY)
              .borderRadius(RadiusTokens.FULL)
              .onClick(() => {
                this.openHome()
              })
          }
          .width('100%')
          .padding(SpacingTokens.MD)
          .borderRadius(RadiusTokens.SM)
          .backgroundColor(ColorTokens.BG_SECONDARY)
        }

        if (!this.loading && this.hasSession) {
          Column({ space: SpacingTokens.MD }) {
            Column({ space: SpacingTokens.SM }) {
              Row() {
                Text('完成度')
                  .fontSize(FontTokens.TITLE_SIZE)
                  .fontWeight(FontTokens.TITLE_WEIGHT)
                  .fontColor(ColorTokens.TEXT_PRIMARY)
                  .layoutWeight(1)

                Text(this.getCompletionText())
                  .fontSize(FontTokens.TITLE_SIZE)
                  .fontWeight(FontTokens.TITLE_WEIGHT)
                  .fontColor(ColorTokens.PRIMARY)
              }
              .width('100%')

              Stack({ alignContent: Alignment.Start }) {
                Row()
                  .width('100%')
                  .height(TouchTokens.PROGRESS_BAR_HEIGHT)
                  .backgroundColor(ColorTokens.SURFACE_ELEVATED)
                  .borderRadius(RadiusTokens.FULL)

                Row()
                  .width(this.getProgressWidth())
                  .height(TouchTokens.PROGRESS_BAR_HEIGHT)
                  .backgroundColor(ColorTokens.PRIMARY)
                  .borderRadius(RadiusTokens.FULL)
              }
              .width('100%')
              .height(TouchTokens.PROGRESS_BAR_HEIGHT)
            }
            .width('100%')
            .padding(SpacingTokens.MD)
            .borderRadius(RadiusTokens.SM)
            .backgroundColor(ColorTokens.BG_SECONDARY)

            Row({ space: SpacingTokens.SM }) {
              this.buildMetric('完成组数', this.completedSets.toString() + '/' + this.targetSets.toString())
              this.buildMetric('训练时长', this.durationText)
            }
            .width('100%')

            Row({ space: SpacingTokens.SM }) {
              this.buildMetric('训练日', this.dayId)
              this.buildMetric('训练容量', this.totalVolume.toString())
            }
            .width('100%')

            Column({ space: SpacingTokens.SM }) {
              Text('记录编号')
                .fontSize(FontTokens.CAPTION_SIZE)
                .fontColor(ColorTokens.TEXT_SECONDARY)

              Text(this.sessionId)
                .fontSize(FontTokens.CAPTION_SIZE)
                .fontColor(ColorTokens.TEXT_PRIMARY)
            }
            .width('100%')
            .padding(SpacingTokens.MD)
            .borderRadius(RadiusTokens.SM)
            .backgroundColor(ColorTokens.SURFACE_PRIMARY)
            .alignItems(HorizontalAlign.Start)

            Button('回到首页')
              .width('100%')
              .height(TouchTokens.BUTTON_HEIGHT_LARGE)
              .fontSize(FontTokens.BODY_SIZE)
              .fontColor(ColorTokens.TEXT_ON_PRIMARY)
              .backgroundColor(ColorTokens.PRIMARY)
              .borderRadius(RadiusTokens.FULL)
              .onClick(() => {
                this.openHome()
              })

            Button('查看训练回顾')
              .width('100%')
              .height(TouchTokens.BUTTON_HEIGHT_LARGE)
              .fontSize(FontTokens.BODY_SIZE)
              .fontColor(ColorTokens.TEXT_PRIMARY)
              .backgroundColor(ColorTokens.SURFACE_ELEVATED)
              .borderRadius(RadiusTokens.FULL)
              .onClick(() => {
                this.openReview()
              })
          }
          .width('100%')
        }
      }
      .width('100%')
      .padding(SpacingTokens.LG)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ColorTokens.BG_PRIMARY)
  }
}

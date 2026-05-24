/**
 * ReviewHomePage -- training review dashboard.
 * Function #12: review dashboard and next adjustment hint.
 * Function #14: recent workout records and historical training trend.
 */
import { router } from '@kit.ArkUI'
import { AppRoutes } from '../../../app/AppRoutes'
import { ColorTokens, FontTokens, RadiusTokens, SpacingTokens, TouchTokens } from '../../../common/styles/DesignTokens'
import ReviewDashboardService, {
  ReviewGoalAdjustmentAction,
  ReviewDashboardSummary,
  ReviewPlanRegenerationResult,
  ReviewRecentSessionRecord,
  ReviewTrendSummary
} from '../../../shared/services/ReviewDashboardService'
import GoalRepository from '../../../shared/services/GoalRepository'
import WorkoutRepository from '../../../shared/services/WorkoutRepository'
import { UserGoal, WorkoutSession } from '../../../shared/models/TrainingModels'

@Entry
@Component
export struct ReviewHomePage {
  @State loading: boolean = true
  @State hasSessions: boolean = false
  @State sessionCount: number = 0
  @State totalCompletedSets: number = 0
  @State totalTargetSets: number = 0
  @State averageCompletionRate: number = 0
  @State totalDurationText: string = '0 分钟'
  @State latestSessionId: string = ''
  @State latestDayId: string = ''
  @State adjustmentText: string = ''
  @State adjustmentTitle: string = ''
  @State adjustmentDescription: string = ''
  @State adjustmentButtonText: string = '暂无可应用调整'
  @State canApplyAdjustment: boolean = false
  @State applyingAdjustment: boolean = false
  @State adjustmentStatusText: string = ''
  @State recentRecords: ReviewRecentSessionRecord[] = []
  @State trendSummary: ReviewTrendSummary = ReviewDashboardService.createEmptyTrendSummary()
  currentGoal: UserGoal | undefined = undefined
  currentAdjustmentAction: ReviewGoalAdjustmentAction = ReviewDashboardService.createEmptyGoalAdjustmentAction()

  async aboutToAppear(): Promise<void> {
    this.loading = true
    const sessions: WorkoutSession[] = WorkoutRepository.getSessions()
    const summary: ReviewDashboardSummary = ReviewDashboardService.createSummary(sessions)
    this.applySummary(summary)
    try {
      const goal: UserGoal | undefined = await GoalRepository.loadGoal(getContext(this))
      this.currentGoal = goal
      if (goal !== undefined) {
        this.applyAdjustmentAction(ReviewDashboardService.createGoalAdjustmentAction(summary, goal))
      } else {
        this.applyAdjustmentAction(ReviewDashboardService.createEmptyGoalAdjustmentAction())
      }
    } catch (e) {
      this.currentGoal = undefined
      this.applyAdjustmentAction(ReviewDashboardService.createEmptyGoalAdjustmentAction())
    }
    this.loading = false
  }

  applySummary(summary: ReviewDashboardSummary): void {
    this.hasSessions = summary.hasSessions
    this.sessionCount = summary.sessionCount
    this.totalCompletedSets = summary.totalCompletedSets
    this.totalTargetSets = summary.totalTargetSets
    this.averageCompletionRate = summary.averageCompletionRate
    this.totalDurationText = summary.totalDurationText
    this.latestSessionId = summary.latestSessionId
    this.latestDayId = summary.latestDayId
    this.adjustmentText = summary.adjustmentText
    this.recentRecords = summary.recentRecords
    this.trendSummary = summary.trendSummary
  }

  applyAdjustmentAction(action: ReviewGoalAdjustmentAction): void {
    this.currentAdjustmentAction = action
    this.adjustmentTitle = action.title
    this.adjustmentDescription = action.description
    this.adjustmentButtonText = action.buttonText
    this.canApplyAdjustment = action.canApply
  }

  openHome(): void {
    try {
      router.replaceUrl({ url: AppRoutes.HOME })
    } catch (e) {
      // stay on review
    }
  }

  openGoalSetup(): void {
    try {
      router.pushUrl({ url: AppRoutes.GOAL_SETUP })
    } catch (e) {
      // stay on review
    }
  }

  openLatestSummary(): void {
    if (this.latestSessionId.length === 0) {
      return
    }
    try {
      router.pushUrl({ url: AppRoutes.WORKOUT_SUMMARY, params: { sessionId: this.latestSessionId } })
    } catch (e) {
      // stay on review
    }
  }

  async applyGoalAdjustment(): Promise<void> {
    if (this.applyingAdjustment || !this.canApplyAdjustment || this.currentGoal === undefined) {
      return
    }
    this.applyingAdjustment = true
    this.adjustmentStatusText = ''
    try {
      const result: ReviewPlanRegenerationResult = ReviewDashboardService.createPlanRegenerationResult(
        this.currentGoal,
        this.currentAdjustmentAction,
        Date.now()
      )
      await GoalRepository.saveGoal(getContext(this), result.adjustedGoal)
      this.currentGoal = result.adjustedGoal
      this.adjustmentStatusText = result.statusText
      this.applyAdjustmentAction(ReviewDashboardService.createGoalAdjustmentAction(this.createCurrentSummary(), result.adjustedGoal))
    } catch (e) {
      this.adjustmentStatusText = '保存调整失败，请稍后重试'
    }
    this.applyingAdjustment = false
  }

  createCurrentSummary(): ReviewDashboardSummary {
    const summary: ReviewDashboardSummary = {
      hasSessions: this.hasSessions,
      sessionCount: this.sessionCount,
      totalCompletedSets: this.totalCompletedSets,
      totalTargetSets: this.totalTargetSets,
      averageCompletionRate: this.averageCompletionRate,
      totalDurationSeconds: 0,
      totalDurationText: this.totalDurationText,
      latestSessionId: this.latestSessionId,
      latestDayId: this.latestDayId,
      adjustmentHint: this.currentAdjustmentAction.actionType,
      adjustmentText: this.adjustmentText,
      recentRecords: this.recentRecords,
      trendSummary: this.trendSummary
    }
    return summary
  }

  getCompletionText(): string {
    return this.averageCompletionRate.toString() + '%'
  }

  getProgressWidth(): string {
    if (this.averageCompletionRate <= 0) {
      return '1%'
    }
    if (this.averageCompletionRate > 100) {
      return '100%'
    }
    return this.averageCompletionRate.toString() + '%'
  }

  @Builder
  buildMetric(label: string, value: string) {
    Column({ space: SpacingTokens.XS }) {
      Text(value)
        .fontSize(FontTokens.HEADLINE_SIZE)
        .fontWeight(FontTokens.HEADLINE_WEIGHT)
        .fontColor(ColorTokens.TEXT_PRIMARY)
        .textAlign(TextAlign.Center)

      Text(label)
        .fontSize(FontTokens.CAPTION_SIZE)
        .fontColor(ColorTokens.TEXT_SECONDARY)
        .textAlign(TextAlign.Center)
    }
    .layoutWeight(1)
    .padding(SpacingTokens.MD)
    .borderRadius(RadiusTokens.SM)
    .backgroundColor(ColorTokens.SURFACE_PRIMARY)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  buildRecentRecord(record: ReviewRecentSessionRecord) {
    Column({ space: SpacingTokens.SM }) {
      Row() {
        Column({ space: SpacingTokens.XS }) {
          Text(record.dayId)
            .fontSize(FontTokens.BODY_SIZE)
            .fontWeight(FontWeight.Medium)
            .fontColor(ColorTokens.TEXT_PRIMARY)

          Text(record.dateText + ' · ' + record.durationText)
            .fontSize(FontTokens.CAPTION_SIZE)
            .fontColor(ColorTokens.TEXT_SECONDARY)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Text(record.completionRate.toString() + '%')
          .fontSize(FontTokens.TITLE_SIZE)
          .fontWeight(FontTokens.TITLE_WEIGHT)
          .fontColor(ColorTokens.PRIMARY)
      }
      .width('100%')

      Row() {
        Text(record.completionText)
          .fontSize(FontTokens.CAPTION_SIZE)
          .fontColor(ColorTokens.TEXT_SECONDARY)
          .layoutWeight(1)

        Text(record.volumeText)
          .fontSize(FontTokens.CAPTION_SIZE)
          .fontColor(ColorTokens.ACCENT_LIGHT)
      }
      .width('100%')
    }
    .width('100%')
    .padding(SpacingTokens.MD)
    .borderRadius(RadiusTokens.SM)
    .backgroundColor(ColorTokens.SURFACE_PRIMARY)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  buildTrendSummary() {
    Column({ space: SpacingTokens.SM }) {
      Text('历史训练趋势')
        .fontSize(FontTokens.TITLE_SIZE)
        .fontWeight(FontTokens.TITLE_WEIGHT)
        .fontColor(ColorTokens.TEXT_PRIMARY)

      Text(this.trendSummary.summaryText)
        .fontSize(FontTokens.BODY_SIZE)
        .fontColor(ColorTokens.TEXT_SECONDARY)

      Row({ space: SpacingTokens.SM }) {
        this.buildMetric('训练量趋势', this.trendSummary.volumeTrendText)
        this.buildMetric('完成率趋势', this.trendSummary.completionTrendText)
      }
      .width('100%')
    }
    .width('100%')
    .padding(SpacingTokens.MD)
    .borderRadius(RadiusTokens.SM)
    .backgroundColor(ColorTokens.BG_SECONDARY)
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    Scroll() {
      Column({ space: SpacingTokens.LG }) {
        Column({ space: SpacingTokens.SM }) {
          Text('训练回顾')
            .fontSize(FontTokens.DISPLAY_SIZE)
            .fontWeight(FontTokens.DISPLAY_WEIGHT)
            .fontColor(ColorTokens.TEXT_PRIMARY)

          Text(this.loading ? '正在整理训练记录' : '用完成率决定下次如何调整')
            .fontSize(FontTokens.BODY_SIZE)
            .fontColor(ColorTokens.TEXT_SECONDARY)
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)

        if (!this.loading && !this.hasSessions) {
          Column({ space: SpacingTokens.MD }) {
            Text('还没有训练记录')
              .fontSize(FontTokens.TITLE_SIZE)
              .fontWeight(FontTokens.TITLE_WEIGHT)
              .fontColor(ColorTokens.TEXT_PRIMARY)

            Text(this.adjustmentText)
              .fontSize(FontTokens.BODY_SIZE)
              .fontColor(ColorTokens.TEXT_SECONDARY)

            Button('开始今日训练')
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

        if (!this.loading && this.hasSessions) {
          Column({ space: SpacingTokens.MD }) {
            Column({ space: SpacingTokens.SM }) {
              Row() {
                Text('平均完成率')
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
              this.buildMetric('训练次数', this.sessionCount.toString())
              this.buildMetric('完成组数', this.totalCompletedSets.toString() + '/' + this.totalTargetSets.toString())
            }
            .width('100%')

            Row({ space: SpacingTokens.SM }) {
              this.buildMetric('累计时长', this.totalDurationText)
              this.buildMetric('最近训练日', this.latestDayId)
            }
            .width('100%')

            Column({ space: SpacingTokens.SM }) {
              Text('最近训练记录')
                .fontSize(FontTokens.TITLE_SIZE)
                .fontWeight(FontTokens.TITLE_WEIGHT)
                .fontColor(ColorTokens.TEXT_PRIMARY)

              ForEach(this.recentRecords, (record: ReviewRecentSessionRecord) => {
                this.buildRecentRecord(record)
              }, (record: ReviewRecentSessionRecord) => record.sessionId)
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)

            this.buildTrendSummary()

            Column({ space: SpacingTokens.SM }) {
              Text('下次调整建议')
                .fontSize(FontTokens.TITLE_SIZE)
                .fontWeight(FontTokens.TITLE_WEIGHT)
                .fontColor(ColorTokens.TEXT_PRIMARY)

              Text(this.adjustmentText)
                .fontSize(FontTokens.BODY_SIZE)
                .fontColor(ColorTokens.TEXT_SECONDARY)

              Text(this.adjustmentTitle)
                .fontSize(FontTokens.BODY_SIZE)
                .fontWeight(FontWeight.Medium)
                .fontColor(ColorTokens.TEXT_PRIMARY)

              Text(this.adjustmentDescription)
                .fontSize(FontTokens.CAPTION_SIZE)
                .fontColor(ColorTokens.TEXT_SECONDARY)

              if (this.adjustmentStatusText.length > 0) {
                Text(this.adjustmentStatusText)
                  .fontSize(FontTokens.CAPTION_SIZE)
                  .fontColor(ColorTokens.PRIMARY)
              }

              Button(this.applyingAdjustment ? '保存调整中' : this.adjustmentButtonText)
                .width('100%')
                .height(TouchTokens.BUTTON_HEIGHT_DEFAULT)
                .fontSize(FontTokens.BODY_SIZE)
                .fontColor(ColorTokens.TEXT_ON_PRIMARY)
                .backgroundColor(this.canApplyAdjustment ? ColorTokens.PRIMARY : ColorTokens.PRIMARY_DISABLED)
                .borderRadius(RadiusTokens.FULL)
                .enabled(this.canApplyAdjustment && !this.applyingAdjustment)
                .onClick(() => {
                  this.applyGoalAdjustment()
                })
            }
            .width('100%')
            .padding(SpacingTokens.MD)
            .borderRadius(RadiusTokens.SM)
            .backgroundColor(ColorTokens.SURFACE_PRIMARY)
            .alignItems(HorizontalAlign.Start)

            Button('调整下次计划')
              .width('100%')
              .height(TouchTokens.BUTTON_HEIGHT_LARGE)
              .fontSize(FontTokens.BODY_SIZE)
              .fontColor(ColorTokens.TEXT_ON_PRIMARY)
              .backgroundColor(ColorTokens.PRIMARY)
              .borderRadius(RadiusTokens.FULL)
              .onClick(() => {
                this.openGoalSetup()
              })

            Button('查看最近复盘')
              .width('100%')
              .height(TouchTokens.BUTTON_HEIGHT_LARGE)
              .fontSize(FontTokens.BODY_SIZE)
              .fontColor(ColorTokens.TEXT_PRIMARY)
              .backgroundColor(ColorTokens.SURFACE_ELEVATED)
              .borderRadius(RadiusTokens.FULL)
              .onClick(() => {
                this.openLatestSummary()
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

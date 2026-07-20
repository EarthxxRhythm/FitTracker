/**
 * HomePage -- training dashboard home.
 * Function #4: home goal summary.
 * Function #5: weekly plan rows.
 * Function #8: today training entry.
 * Function #19: current preset plan today view.
 * Function #20: current preset plan rest-day view.
 */
import { Context } from '@kit.AbilityKit'
import { AppRoutes } from '../app/AppRoutes'
import TrainingPlanService, { PresetPlan, UserPlan } from '../common/services/TrainingPlanService'
import WorkoutDraftService, { hasWorkoutDraftProgress, WorkoutDraftSnapshot } from '../common/services/WorkoutDraftService'
import { ColorTokens, FontTokens, RadiusTokens, SpacingTokens, TouchTokens } from '../common/styles/DesignTokens'
import { AppButton } from '../components/AppButton'
import { AppCard } from '../components/AppCard'
import { PrimaryDestinationStrip } from '../components/PrimaryDestinationStrip'
import { createStageRailItem, StageRail, StageRailItem } from '../components/StageRail'
import { TrainingPlan, UserGoal } from '../shared/models/TrainingModels'
import GoalRepository from '../shared/services/GoalRepository'
import HomePlanService, {
  HomePlanSummary,
  HomeRecommendedExercise,
  HomeWeeklyPlanDay
} from '../shared/services/HomePlanService'
import PlanEngine from '../shared/services/PlanEngine'

interface HomePresetPlanCard {
  presetPlanId: string
  name: string
  targetAudience: string
  weeklyFrequency: string
  trainingDayCount: number
  coverColor: string
}

@Entry
@Component
export struct HomePage {
  @State loading: boolean = true
  @State hasGoal: boolean = false
  @State planId: string = ''
  @State planName: string = ''
  @State weeklyDays: number = 0
  @State sessionMinutes: number = 0
  @State primaryMetaText: string = ''
  @State secondaryMetaText: string = ''
  @State goalSummary: string = ''
  @State equipmentSummary: string = ''
  @State restrictionSummary: string = ''
  @State todayDayId: string = ''
  @State todayTitle: string = ''
  @State todayLabel: string = ''
  @State hasTodayWorkout: boolean = false
  @State todayRestMessage: string = ''
  @State todayExerciseCount: number = 0
  @State recommendedExercises: HomeRecommendedExercise[] = []
  @State startButtonText: string = ''
  @State startRoute: string = ''
  @State weeklyPlanDays: HomeWeeklyPlanDay[] = []
  @State presetPlanCards: HomePresetPlanCard[] = []
  @State hasRecoverableDraft: boolean = false
  @State recoverDraftSummary: string = ''

  private getHostContextOrNull(): Context | null {
    const hostContext = this.getUIContext().getHostContext()
    if (hostContext === undefined || hostContext === null) {
      return null
    }
    return hostContext as Context
  }

  async aboutToAppear(): Promise<void> {
    this.loading = true
    try {
      const context: Context | null = this.getHostContextOrNull()
      if (context === null) {
        this.hasGoal = false
        this.loading = false
        return
      }
      this.loadPresetPlanCards()
      await this.loadWorkoutDraft(context)

      const currentPlan: UserPlan | null = await TrainingPlanService.getCurrentPlan(context)
      if (currentPlan !== null) {
        const summary: HomePlanSummary = HomePlanService.createSummaryFromCurrentPlan(
          currentPlan,
          TrainingPlanService.getTodayLabel(),
          TrainingPlanService.getTodayTraining(currentPlan)
        )
        this.applySummary(summary)
        this.loading = false
        return
      }

      const goal: UserGoal | undefined = await GoalRepository.loadGoal(context)
      if (goal === undefined) {
        this.hasGoal = false
        this.loading = false
        return
      }

      const plan: TrainingPlan = PlanEngine.generatePlan(goal)
      const todaySeed: number = this.getTodaySeed()
      const summary: HomePlanSummary = HomePlanService.createSummary(goal, plan, todaySeed)
      this.applySummary(summary)
    } catch (e) {
      this.hasGoal = false
    }
    this.loading = false
  }

  loadPresetPlanCards(): void {
    this.presetPlanCards = this.copyPresetPlanCards(TrainingPlanService.getAllPresetPlans())
  }

  async loadWorkoutDraft(context: Context): Promise<void> {
    const snapshot: WorkoutDraftSnapshot | null = await WorkoutDraftService.getDraft(context)
    if (snapshot === null || !hasWorkoutDraftProgress(snapshot)) {
      this.hasRecoverableDraft = false
      this.recoverDraftSummary = ''
      return
    }

    this.hasRecoverableDraft = true
    this.recoverDraftSummary = snapshot.dayLabel + ' | ' + snapshot.completedSets.toString() + '/' +
      snapshot.totalTargetSets.toString() + ' \u7ec4\u5df2\u5b8c\u6210'
  }

  applySummary(summary: HomePlanSummary): void {
    this.hasGoal = summary.hasGoal
    this.planId = summary.planId
    this.planName = summary.planName
    this.weeklyDays = summary.weeklyDays
    this.sessionMinutes = summary.sessionMinutes
    this.primaryMetaText = summary.primaryMetaText
    this.secondaryMetaText = summary.secondaryMetaText
    this.goalSummary = summary.goalSummary
    this.equipmentSummary = summary.equipmentSummary
    this.restrictionSummary = summary.restrictionSummary
    this.todayDayId = summary.todayDayId
    this.todayTitle = summary.todayTitle
    this.todayLabel = summary.todayLabel
    this.hasTodayWorkout = summary.hasTodayWorkout
    this.todayRestMessage = summary.todayRestMessage
    this.todayExerciseCount = summary.todayExerciseCount
    this.recommendedExercises = this.copyRecommendedExercises(summary.recommendedExercises)
    this.startButtonText = this.resolveStartButtonText(summary)
    this.startRoute = summary.startRoute
    this.weeklyPlanDays = this.copyWeeklyPlanDays(summary.weeklyPlanDays)
  }

  getTodaySeed(): number {
    const today: Date = new Date()
    const day: number = today.getDay()
    if (day === 0) {
      return 7
    }
    return day
  }

  openGoalSetup(): void {
    try {
      this.getUIContext().getRouter().replaceUrl({ url: AppRoutes.GOAL_SETUP })
    } catch (e) {
      // stay on home
    }
  }

  openWorkoutPreview(): void {
    if (this.startRoute.length === 0) {
      return
    }
    try {
      this.getUIContext().getRouter().pushUrl({
        url: this.startRoute,
        params: {
          dayId: this.todayDayId,
          flowSource: this.isCurrentPlanDayId(this.todayDayId) ? 'current_plan' : 'goal_plan'
        }
      })
    } catch (e) {
      // stay on home
    }
  }

  isCurrentPlanDayId(dayId: string): boolean {
    return dayId.indexOf('current_plan_day_') === 0
  }

  resolveStartButtonText(summary: HomePlanSummary): string {
    if (summary.startRoute.length > 0 && this.isCurrentPlanDayId(summary.todayDayId)) {
      return '\u5f00\u59cb\u8bad\u7ec3'
    }
    return summary.startButtonText
  }

  openReviewHome(): void {
    try {
      this.getUIContext().getRouter().pushUrl({ url: AppRoutes.REVIEW_HOME })
    } catch (e) {
      // stay on home
    }
  }

  openActiveWorkout(): void {
    try {
      this.getUIContext().getRouter().pushUrl({ url: AppRoutes.ACTIVE_WORKOUT })
    } catch (e) {
      // stay on home
    }
  }

  openExerciseLibrary(): void {
    try {
      this.getUIContext().getRouter().pushUrl({ url: AppRoutes.EXERCISE_LIBRARY })
    } catch (e) {
      // stay on home
    }
  }

  openTrainingPlanDetail(presetPlanId: string): void {
    try {
      this.getUIContext().getRouter().pushUrl({ url: AppRoutes.TRAINING_PLAN_DETAIL, params: { presetPlanId: presetPlanId } })
    } catch (e) {
      // stay on home
    }
  }

  copyRecommendedExercises(source: HomeRecommendedExercise[]): HomeRecommendedExercise[] {
    const values: HomeRecommendedExercise[] = []
    for (let index = 0; index < source.length; index++) {
      const exercise: HomeRecommendedExercise = source[index]
      const item: HomeRecommendedExercise = {
        exerciseId: exercise.exerciseId,
        name: exercise.name,
        prescription: exercise.prescription,
        intensityNote: exercise.intensityNote
      }
      values.push(item)
    }
    return values
  }

  copyWeeklyPlanDays(source: HomeWeeklyPlanDay[]): HomeWeeklyPlanDay[] {
    const days: HomeWeeklyPlanDay[] = []
    for (let index = 0; index < source.length; index++) {
      const sourceDay: HomeWeeklyPlanDay = source[index]
      const day: HomeWeeklyPlanDay = {
        dayId: sourceDay.dayId,
        title: sourceDay.title,
        exerciseCount: sourceDay.exerciseCount,
        isToday: sourceDay.isToday
      }
      days.push(day)
    }
    return days
  }

  copyPresetPlanCards(source: PresetPlan[]): HomePresetPlanCard[] {
    const cards: HomePresetPlanCard[] = []
    for (let index = 0; index < source.length; index++) {
      const sourcePlan: PresetPlan = source[index]
      const card: HomePresetPlanCard = {
        presetPlanId: sourcePlan.id,
        name: sourcePlan.name,
        targetAudience: sourcePlan.targetAudience,
        weeklyFrequency: sourcePlan.weeklyFrequency,
        trainingDayCount: sourcePlan.days.length,
        coverColor: sourcePlan.coverColor
      }
      cards.push(card)
    }
    return cards
  }

  resolveHeroTitle(): string {
    if (this.loading) {
      return '\u6b63\u5728\u51c6\u5907\u4eca\u5929\u7684\u8bad\u7ec3'
    }
    if (this.hasRecoverableDraft) {
      return '\u4ece\u4e0a\u6b21\u4e2d\u65ad\u5904\u7ee7\u7eed'
    }
    if (!this.hasGoal) {
      return '\u5148\u786e\u5b9a\u4f60\u7684\u8bad\u7ec3\u76ee\u6807'
    }
    if (this.hasTodayWorkout) {
      return this.todayLabel
    }
    return '\u4eca\u5929\u4ee5\u6062\u590d\u548c\u8c03\u6574\u4e3a\u4e3b'
  }

  resolveHeroDescription(): string {
    if (this.loading) {
      return '\u6b63\u5728\u8bfb\u53d6\u5f53\u524d\u8bad\u7ec3\u8ba1\u5212\u3001\u4eca\u65e5\u5b89\u6392\u548c\u6062\u590d\u8fdb\u5ea6\u3002'
    }
    if (this.hasRecoverableDraft) {
      return this.recoverDraftSummary
    }
    if (!this.hasGoal) {
      return '\u5b8c\u6210\u76ee\u6807\u8bbe\u7f6e\u540e\uff0c\u9996\u9875\u4f1a\u76f4\u63a5\u544a\u8bc9\u4f60\u4eca\u5929\u7ec3\u4ec0\u4e48\u3001\u4ece\u54ea\u91cc\u5f00\u59cb\u3002'
    }
    if (this.hasTodayWorkout) {
      return this.planName + ' | ' + this.todayExerciseCount.toString() + ' \u4e2a\u52a8\u4f5c\uff0c\u9884\u8ba1 ' +
        this.sessionMinutes.toString() + ' \u5206\u949f\u5b8c\u6210\u3002'
    }
    return this.todayRestMessage
  }

  resolvePrimaryActionText(): string {
    if (this.loading) {
      return '\u6b63\u5728\u51c6\u5907'
    }
    if (this.hasRecoverableDraft) {
      return '\u6062\u590d\u8bad\u7ec3'
    }
    if (!this.hasGoal) {
      return '\u8bbe\u7f6e\u8bad\u7ec3\u76ee\u6807'
    }
    return this.startButtonText
  }

  isPrimaryActionEnabled(): boolean {
    if (this.loading) {
      return false
    }
    if (this.hasRecoverableDraft) {
      return true
    }
    if (!this.hasGoal) {
      return true
    }
    return this.startRoute.length > 0
  }

  handlePrimaryAction(): void {
    if (this.loading) {
      return
    }
    if (this.hasRecoverableDraft) {
      this.openActiveWorkout()
      return
    }
    if (!this.hasGoal) {
      this.openGoalSetup()
      return
    }
    this.openWorkoutPreview()
  }

  getVisibleRecommendedExercises(): HomeRecommendedExercise[] {
    const items: HomeRecommendedExercise[] = []
    let count: number = 0
    for (let index = 0; index < this.recommendedExercises.length; index++) {
      if (count >= 3) {
        break
      }
      items.push(this.recommendedExercises[index])
      count += 1
    }
    return items
  }

  resolveHeroEyebrow(): string {
    if (this.loading) {
      return '正在准备'
    }
    if (this.hasRecoverableDraft) {
      return '恢复训练'
    }
    if (!this.hasGoal) {
      return '开始配置'
    }
    if (this.hasTodayWorkout) {
      return '今日主线'
    }
    return '恢复日'
  }

  resolveWeeklySectionDescription(): string {
    if (this.hasTodayWorkout) {
      return '先完成今天这组，再回到回顾页看趋势和动作表现。'
    }
    return '今天以恢复和调整为主，下一次训练已经排进本周节奏。'
  }

  @Builder
  buildHomeMetaPill(text: string) {
    Text(text)
      .fontSize(FontTokens.SMALL_SIZE)
      .fontColor(ColorTokens.TEXT_SECONDARY)
      .padding({
        top: SpacingTokens.XS,
        bottom: SpacingTokens.XS,
        left: SpacingTokens.SM,
        right: SpacingTokens.SM
      })
      .backgroundColor(ColorTokens.SURFACE_SECONDARY)
      .borderRadius(RadiusTokens.FULL)
      .border({
        width: 1,
        color: ColorTokens.BORDER_DEFAULT
      })
  }

  hasSecondaryMetaText(): boolean {
    return this.secondaryMetaText.length > 0
  }

  hasEquipmentSummary(): boolean {
    return this.equipmentSummary.length > 0
  }

  hasRestrictionSummary(): boolean {
    return this.restrictionSummary.length > 0
  }

  getStageRailItems(): StageRailItem[] {
    const items: StageRailItem[] = []
    items.push(createStageRailItem('目标', !this.hasGoal, false))
    items.push(createStageRailItem('预览', this.hasGoal && !this.hasRecoverableDraft && !this.hasTodayWorkout, false))
    items.push(createStageRailItem('执行', this.hasRecoverableDraft || this.hasTodayWorkout, false))
    items.push(createStageRailItem('回顾', false, false))
    return items
  }

  @Builder
  buildLaneHeader(title: string, description: string) {
    Column({ space: SpacingTokens.XS }) {
      Text(title)
        .fontSize(FontTokens.TITLE_SIZE)
        .fontWeight(FontTokens.TITLE_WEIGHT)
        .fontColor(ColorTokens.TEXT_PRIMARY)

      Text(description)
        .fontSize(FontTokens.CAPTION_SIZE)
        .fontColor(ColorTokens.TEXT_SECONDARY)
        .lineHeight(FontTokens.CAPTION_LINE_HEIGHT)
        .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  resolveCommandStatusValue(): string {
    if (this.loading) {
      return '\u51c6\u5907\u4e2d'
    }
    if (this.hasRecoverableDraft) {
      return '\u53ef\u6062\u590d'
    }
    if (!this.hasGoal) {
      return '\u672a\u8bbe\u5b9a'
    }
    if (this.hasTodayWorkout) {
      return '\u53ef\u6267\u884c'
    }
    return '\u6062\u590d\u65e5'
  }

  resolveCommandStatusNote(): string {
    if (this.loading) {
      return '\u6b63\u5728\u6821\u51c6\u4eca\u65e5\u5b89\u6392'
    }
    if (this.hasRecoverableDraft) {
      return '\u4ece\u4e0a\u6b21\u4e2d\u65ad\u5904\u7ee7\u7eed'
    }
    if (!this.hasGoal) {
      return '\u5b8c\u6210\u8bbe\u5b9a\u540e\u81ea\u52a8\u751f\u6210'
    }
    if (this.hasTodayWorkout) {
      return '\u4eca\u5929\u6709\u660e\u786e\u4e3b\u7ebf\u8bad\u7ec3'
    }
    return '\u4ee5\u6062\u590d\u548c\u8c03\u6574\u4e3a\u4e3b'
  }

  resolveFocusPanelTitle(): string {
    if (this.loading) {
      return '\u6b63\u5728\u6574\u7406\u4eca\u65e5\u8bad\u7ec3'
    }
    if (this.hasRecoverableDraft) {
      return '\u7ee7\u7eed\u4e0a\u6b21\u8bad\u7ec3'
    }
    if (!this.hasGoal) {
      return '\u5148\u5b8c\u6210\u76ee\u6807\u8bbe\u5b9a'
    }
    if (this.hasTodayWorkout) {
      return this.todayTitle
    }
    return '\u4eca\u5929\u8fdb\u5165\u6062\u590d\u4e0e\u8c03\u6574'
  }

  resolveFocusPanelDescription(): string {
    if (this.loading) {
      return '\u8bad\u7ec3\u8ba1\u5212\u3001\u4eca\u65e5\u72b6\u6001\u548c\u4e0a\u6b21\u8fdb\u5ea6\u6b63\u5728\u540c\u6b65\u3002'
    }
    if (this.hasRecoverableDraft) {
      return this.recoverDraftSummary
    }
    if (!this.hasGoal) {
      return '\u8bbe\u5b9a\u76ee\u6807\u540e\uff0c\u9996\u9875\u4f1a\u76f4\u63a5\u544a\u8bc9\u4f60\u4eca\u5929\u8be5\u7ec3\u4ec0\u4e48\u3002'
    }
    if (this.hasTodayWorkout) {
      return this.planName + ' | ' + this.todayExerciseCount.toString() + ' \u4e2a\u52a8\u4f5c | \u9884\u8ba1 ' +
        this.sessionMinutes.toString() + ' \u5206\u949f'
    }
    return this.todayRestMessage
  }

  @Builder
  buildHomeMetricTile(label: string, value: string, note: string, emphasize: boolean) {
    Column({ space: SpacingTokens.XS }) {
      Text(label)
        .fontSize(FontTokens.MICRO_SIZE)
        .fontWeight(FontTokens.MICRO_WEIGHT)
        .fontColor(ColorTokens.TEXT_TERTIARY)

      Text(value)
        .fontSize(FontTokens.TITLE_SIZE)
        .fontWeight(FontTokens.TITLE_WEIGHT)
        .fontColor(emphasize ? ColorTokens.ACCENT_SOFT : ColorTokens.TEXT_PRIMARY)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Text(note)
        .fontSize(FontTokens.CAPTION_SIZE)
        .fontColor(ColorTokens.TEXT_SECONDARY)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .layoutWeight(1)
    .padding(SpacingTokens.MD)
    .backgroundColor(emphasize ? ColorTokens.SURFACE_STRONG : ColorTokens.BG_ELEVATED)
    .borderRadius(RadiusTokens.MD)
    .border({
      width: 1,
      color: emphasize ? ColorTokens.BORDER_ACCENT : ColorTokens.BORDER_SUBTLE
    })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  buildCommandFocusContent() {
    if (!this.loading && this.hasGoal && this.hasTodayWorkout) {
      Column({ space: SpacingTokens.SM }) {
        ForEach(this.getVisibleRecommendedExercises(), (exercise: HomeRecommendedExercise, index: number) => {
          Row({ space: SpacingTokens.SM }) {
            Text((index + 1).toString())
              .fontSize(FontTokens.SMALL_SIZE)
              .fontWeight(FontWeight.Medium)
              .fontColor(ColorTokens.TEXT_ON_PRIMARY)
              .width(24)
              .height(24)
              .textAlign(TextAlign.Center)
              .backgroundColor(ColorTokens.PRIMARY)
              .borderRadius(RadiusTokens.FULL)

            Column({ space: SpacingTokens.XS }) {
              Text(exercise.name)
                .fontSize(FontTokens.BODY_SIZE)
                .fontWeight(FontWeight.Medium)
                .fontColor(ColorTokens.TEXT_PRIMARY)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })

              Text(exercise.prescription + ' | ' + exercise.intensityNote)
                .fontSize(FontTokens.CAPTION_SIZE)
                .fontColor(ColorTokens.TEXT_SECONDARY)
                .lineHeight(FontTokens.CAPTION_LINE_HEIGHT)
                .maxLines(2)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)
          }
          .width('100%')
        }, (exercise: HomeRecommendedExercise) => exercise.exerciseId)

        if (this.recommendedExercises.length > 3) {
          Text('\u5176\u4f59\u52a8\u4f5c\u4f1a\u5728\u8bad\u7ec3\u9884\u89c8\u91cc\u7ee7\u7eed\u5c55\u5f00\u3002')
            .fontSize(FontTokens.CAPTION_SIZE)
            .fontColor(ColorTokens.TEXT_TERTIARY)
            .width('100%')
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    } else {
      Text(this.loading ? this.resolveFocusPanelDescription() : this.todayRestMessage.length > 0 ? this.todayRestMessage :
        this.resolveFocusPanelDescription())
        .fontSize(FontTokens.BODY_SIZE)
        .fontColor(ColorTokens.TEXT_SECONDARY)
        .lineHeight(FontTokens.BODY_LINE_HEIGHT)
        .width('100%')
    }
  }

  @Builder
  buildCommandSurface() {
    AppCard({ variant: 'panel', cardPadding: 'default' }) {
      Column({ space: SpacingTokens.MD }) {
        Row() {
          Text(this.resolveHeroEyebrow())
            .fontSize(FontTokens.SMALL_SIZE)
            .fontWeight(FontWeight.Medium)
            .fontColor(ColorTokens.TEXT_ON_PRIMARY)
            .padding({
              top: SpacingTokens.XS,
              bottom: SpacingTokens.XS,
              left: SpacingTokens.SM,
              right: SpacingTokens.SM
            })
            .backgroundColor(ColorTokens.PRIMARY)
            .borderRadius(RadiusTokens.FULL)

          if (!this.loading && this.hasRecoverableDraft) {
            Text('\u672a\u5b8c\u6210\u8fdb\u5ea6')
              .fontSize(FontTokens.SMALL_SIZE)
              .fontWeight(FontWeight.Medium)
              .fontColor(ColorTokens.ACCENT_GOLD)
              .padding({
                top: SpacingTokens.XS,
                bottom: SpacingTokens.XS,
                left: SpacingTokens.SM,
                right: SpacingTokens.SM
              })
              .backgroundColor(ColorTokens.OVERLAY_ACCENT)
              .borderRadius(RadiusTokens.FULL)
              .border({ width: 1, color: ColorTokens.ACCENT_GOLD })
              .margin({ left: SpacingTokens.SM })
          }
        }
        .width('100%')

        Text(this.resolveHeroTitle())
          .fontSize(FontTokens.HERO_SIZE)
          .fontWeight(FontTokens.HERO_WEIGHT)
          .fontColor(ColorTokens.TEXT_PRIMARY)
          .width('100%')

        Text(this.resolveHeroDescription())
          .fontSize(FontTokens.BODY_SIZE)
          .fontColor(ColorTokens.TEXT_SECONDARY)
          .lineHeight(FontTokens.BODY_LINE_HEIGHT)
          .width('100%')

        Row({ space: SpacingTokens.SM }) {
          this.buildHomeMetricTile(
            '\u5f53\u524d\u72b6\u6001',
            this.resolveCommandStatusValue(),
            this.resolveCommandStatusNote(),
            true
          )
          this.buildHomeMetricTile(
            '\u672c\u5468\u9891\u7387',
            this.hasGoal ? this.weeklyDays.toString() + ' \u5929/\u5468' : '--',
            this.hasGoal ? this.primaryMetaText : '\u5b8c\u6210\u76ee\u6807\u8bbe\u5b9a\u540e\u751f\u6210',
            false
          )
          this.buildHomeMetricTile(
            '\u9884\u8ba1\u65f6\u957f',
            this.hasGoal ? this.sessionMinutes.toString() + ' \u5206\u949f' : '--',
            this.hasGoal ? '\u4eca\u65e5\u6267\u884c\u7a97\u53e3' : '\u7528\u4e8e\u751f\u6210\u4eca\u65e5\u8bad\u7ec3',
            false
          )
        }
        .width('100%')

        Column({ space: SpacingTokens.MD }) {
          Row() {
            Column({ space: SpacingTokens.XS }) {
              Text('\u4eca\u65e5\u4e3b\u7ebf')
                .fontSize(FontTokens.MICRO_SIZE)
                .fontWeight(FontTokens.MICRO_WEIGHT)
                .fontColor(ColorTokens.TEXT_TERTIARY)

              Text(this.resolveFocusPanelTitle())
                .fontSize(FontTokens.HEADLINE_SIZE)
                .fontWeight(FontTokens.HEADLINE_WEIGHT)
                .fontColor(ColorTokens.TEXT_PRIMARY)
                .width('100%')

              Text(this.resolveFocusPanelDescription())
                .fontSize(FontTokens.CAPTION_SIZE)
                .fontColor(ColorTokens.TEXT_SECONDARY)
                .lineHeight(FontTokens.CAPTION_LINE_HEIGHT)
                .width('100%')
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)

            if (!this.loading && this.hasGoal) {
              Text(this.primaryMetaText)
                .fontSize(FontTokens.SMALL_SIZE)
                .fontColor(ColorTokens.TEXT_ON_PRIMARY)
                .padding({
                  top: SpacingTokens.XS,
                  bottom: SpacingTokens.XS,
                  left: SpacingTokens.SM,
                  right: SpacingTokens.SM
                })
                .backgroundColor(ColorTokens.PRIMARY)
                .borderRadius(RadiusTokens.FULL)
            }
          }
          .width('100%')
          .alignItems(VerticalAlign.Top)

          this.buildCommandFocusContent()

          AppButton({
            text: this.resolvePrimaryActionText(),
            type: 'primary',
            buttonSize: 'large',
            block: true,
            disabled: !this.isPrimaryActionEnabled(),
            onButtonClick: () => {
              this.handlePrimaryAction()
            }
          })

          if (!this.loading && this.hasGoal) {
            Row({ space: SpacingTokens.SM }) {
              Column() {
                AppButton({
                  text: '\u67e5\u770b\u9884\u89c8',
                  type: 'secondary',
                  buttonSize: 'medium',
                  block: true,
                  onButtonClick: () => {
                    this.openWorkoutPreview()
                  }
                })
              }
              .layoutWeight(1)

              Column() {
                AppButton({
                  text: '\u8bad\u7ec3\u56de\u987e',
                  type: 'ghost',
                  buttonSize: 'medium',
                  block: true,
                  onButtonClick: () => {
                    this.openReviewHome()
                  }
                })
              }
              .layoutWeight(1)
            }
            .width('100%')
          }

          if (!this.loading && !this.hasGoal) {
            AppButton({
              text: '\u5148\u770b\u52a8\u4f5c\u5e93',
              type: 'secondary',
              buttonSize: 'medium',
              block: true,
              onButtonClick: () => {
                this.openExerciseLibrary()
              }
            })
          }
        }
        .width('100%')
        .padding(SpacingTokens.MD)
        .backgroundColor(ColorTokens.SURFACE_SECONDARY)
        .borderRadius(RadiusTokens.LG)
        .border({ width: 1, color: ColorTokens.BORDER_STRONG })
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
  }

  @Builder
  buildCommandUtilitySection() {
    AppCard({ variant: 'outlined', cardPadding: 'default' }) {
      Column({ space: SpacingTokens.SM }) {
        Row() {
          Column({ space: SpacingTokens.XS }) {
            Text('\u6b21\u7ea7\u5165\u53e3')
              .fontSize(FontTokens.MICRO_SIZE)
              .fontWeight(FontTokens.MICRO_WEIGHT)
              .fontColor(ColorTokens.TEXT_TERTIARY)

            Text('\u8c03\u6574\u8ba1\u5212\u8fb9\u754c')
              .fontSize(FontTokens.TITLE_SIZE)
              .fontWeight(FontTokens.TITLE_WEIGHT)
              .fontColor(ColorTokens.TEXT_PRIMARY)

            Text('\u628a\u76ee\u6807\u4fee\u6b63\u548c\u52a8\u4f5c\u5e93\u653e\u5728\u6b21\u7ea7\u533a\uff0c\u4e0d\u6253\u65ad\u4eca\u65e5\u4e3b\u7ebf\u8bad\u7ec3\u3002')
              .fontSize(FontTokens.CAPTION_SIZE)
              .fontColor(ColorTokens.TEXT_SECONDARY)
              .lineHeight(FontTokens.CAPTION_LINE_HEIGHT)
              .width('100%')
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)

          if (this.hasSecondaryMetaText()) {
            this.buildHomeMetaPill(this.secondaryMetaText)
          }
        }
        .width('100%')
        .alignItems(VerticalAlign.Top)

        Row({ space: SpacingTokens.SM }) {
          Column() {
            AppButton({
              text: '\u8c03\u6574\u76ee\u6807',
              type: 'ghost',
              buttonSize: 'medium',
              block: true,
              onButtonClick: () => {
                this.openGoalSetup()
              }
            })
          }
          .layoutWeight(1)

          Column() {
            AppButton({
              text: '\u52a8\u4f5c\u5e93',
              type: 'secondary',
              buttonSize: 'medium',
              block: true,
              onButtonClick: () => {
                this.openExerciseLibrary()
              }
            })
          }
          .layoutWeight(1)
        }
        .width('100%')
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
  }

  build() {
    Scroll() {
      Column({ space: SpacingTokens.LG }) {
        PrimaryDestinationStrip({ currentKey: 'home' })

        if (!this.loading) {
          StageRail({ items: this.getStageRailItems() })
        }

        this.buildCommandSurface()

        if (!this.loading && !this.hasGoal) {
          AppCard({ variant: 'outlined', cardPadding: 'default' }) {
            Column({ space: SpacingTokens.SM }) {
              Text('\u5148\u5b8c\u6210\u8bad\u7ec3\u76ee\u6807\u8bbe\u7f6e')
                .fontSize(FontTokens.TITLE_SIZE)
                .fontWeight(FontTokens.TITLE_WEIGHT)
                .fontColor(ColorTokens.TEXT_PRIMARY)

              Text('\u8bbe\u7f6e\u5b8c\u6210\u540e\uff0c\u9996\u9875\u4f1a\u76f4\u63a5\u627f\u63a5\u4eca\u65e5\u8bad\u7ec3\u3001\u6062\u590d\u5165\u53e3\u548c\u672c\u5468\u8282\u594f\uff1b\u52a8\u4f5c\u5e93\u5165\u53e3\u4f1a\u7ee7\u7eed\u4fdd\u7559\u5728\u4e0b\u65b9\u3002')
                .fontSize(FontTokens.BODY_SIZE)
                .fontColor(ColorTokens.TEXT_SECONDARY)
                .lineHeight(FontTokens.BODY_LINE_HEIGHT)
                .width('100%')
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
          }
        }

        if (!this.loading && this.hasGoal) {
          this.buildCommandUtilitySection()
        }

        if (!this.loading && this.hasGoal) {
          this.buildLaneHeader('本周节奏', '先看今天在本周的位置，再进入详情或继续调整计划边界。')

          AppCard({ variant: 'outlined', cardPadding: 'default' }) {
            Column({ space: SpacingTokens.MD }) {
              Row() {
                Column({ space: SpacingTokens.XS }) {
                  Text('\u672c\u5468\u5b89\u6392')
                    .fontSize(FontTokens.TITLE_SIZE)
                    .fontWeight(FontTokens.TITLE_WEIGHT)
                    .fontColor(ColorTokens.TEXT_PRIMARY)

                  Text(this.resolveWeeklySectionDescription())
                    .fontSize(FontTokens.CAPTION_SIZE)
                    .fontColor(ColorTokens.TEXT_SECONDARY)
                    .lineHeight(FontTokens.CAPTION_LINE_HEIGHT)
                    .width('100%')
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)

                Text(this.primaryMetaText)
                  .fontSize(FontTokens.SMALL_SIZE)
                  .fontColor(ColorTokens.TEXT_ON_PRIMARY)
                  .padding({
                    top: SpacingTokens.XS,
                    bottom: SpacingTokens.XS,
                    left: SpacingTokens.SM,
                    right: SpacingTokens.SM
                  })
                  .backgroundColor(ColorTokens.PRIMARY)
                  .borderRadius(RadiusTokens.FULL)
              }
              .width('100%')

              ForEach(this.weeklyPlanDays, (day: HomeWeeklyPlanDay) => {
                Row() {
                  Column({ space: SpacingTokens.XS }) {
                    Text(day.title)
                      .fontSize(FontTokens.BODY_SIZE)
                      .fontWeight(FontWeight.Medium)
                      .fontColor(ColorTokens.TEXT_PRIMARY)

                    Text(day.exerciseCount.toString() + ' \u4e2a\u52a8\u4f5c')
                      .fontSize(FontTokens.CAPTION_SIZE)
                      .fontColor(ColorTokens.TEXT_SECONDARY)
                  }
                  .layoutWeight(1)
                  .alignItems(HorizontalAlign.Start)

                  Text(day.isToday ? '\u4eca\u5929' : '\u8ba1\u5212')
                    .fontSize(FontTokens.SMALL_SIZE)
                    .fontColor(day.isToday ? ColorTokens.TEXT_ON_PRIMARY : ColorTokens.TEXT_PRIMARY)
                    .padding({
                      top: SpacingTokens.XS,
                      bottom: SpacingTokens.XS,
                      left: SpacingTokens.SM,
                      right: SpacingTokens.SM
                    })
                    .backgroundColor(day.isToday ? ColorTokens.SUCCESS : ColorTokens.SURFACE_ELEVATED)
                    .borderRadius(RadiusTokens.FULL)
                }
                .width('100%')
                .padding(SpacingTokens.MD)
                .borderRadius(RadiusTokens.SM)
                .backgroundColor(ColorTokens.SURFACE_PRIMARY)
              }, (day: HomeWeeklyPlanDay) => day.dayId)
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
          }

          this.buildLaneHeader('计划边界', '把目标、器械和限制条件压成一层，方便快速核对是否还适合当前阶段。')

          AppCard({ variant: 'outlined', cardPadding: 'default' }) {
            Column({ space: SpacingTokens.SM }) {
              Text('\u8ba1\u5212\u8fb9\u754c')
                .fontSize(FontTokens.TITLE_SIZE)
                .fontWeight(FontTokens.TITLE_WEIGHT)
                .fontColor(ColorTokens.TEXT_PRIMARY)

              Text(this.goalSummary)
                .fontSize(FontTokens.BODY_SIZE)
                .fontColor(ColorTokens.TEXT_SECONDARY)
                .lineHeight(FontTokens.BODY_LINE_HEIGHT)
                .width('100%')

              Column({ space: SpacingTokens.SM }) {
                if (this.hasSecondaryMetaText()) {
                  this.buildHomeMetaPill(this.secondaryMetaText)
                }
                if (this.hasEquipmentSummary()) {
                  this.buildHomeMetaPill(this.equipmentSummary)
                }
                if (this.hasRestrictionSummary()) {
                  this.buildHomeMetaPill(this.restrictionSummary)
                }
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
          }
        }

        if (!this.loading) {
          this.buildLaneHeader('扩展计划', '预置计划继续保留在次级区，适合切换训练风格时再展开浏览。')

          Column({ space: SpacingTokens.MD }) {
            Row() {
              Column({ space: SpacingTokens.XS }) {
                Text('\u66f4\u591a\u8bad\u7ec3\u8ba1\u5212')
                  .fontSize(FontTokens.TITLE_SIZE)
                  .fontWeight(FontTokens.TITLE_WEIGHT)
                  .fontColor(ColorTokens.TEXT_PRIMARY)

                Text('\u4f5c\u4e3a\u6b21\u7ea7\u5165\u53e3\u4fdd\u7559\u5728\u9996\u5c4f\u4e0b\u65b9\uff0c\u9700\u8981\u65f6\u518d\u5c55\u5f00\u3002')
                  .fontSize(FontTokens.BODY_SIZE)
                  .fontColor(ColorTokens.TEXT_SECONDARY)
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start)

              AppButton({
                text: '动作库',
                type: 'secondary',
                buttonSize: 'small',
                onButtonClick: () => {
                  this.openExerciseLibrary()
                }
              })
            }
            .width('100%')

            Text('\u5305\u542b\u4e94\u5206\u5316\u3001\u4e0a\u4e0b\u80a2\u5206\u88c2\u3001\u63a8\u62c9\u817f\u3001\u5168\u8eab 3x \u548c\u529b\u91cf\u57fa\u7840\u3002')
              .fontSize(FontTokens.BODY_SIZE)
              .fontColor(ColorTokens.TEXT_SECONDARY)
              .width('100%')

            ForEach(this.presetPlanCards, (plan: HomePresetPlanCard) => {
              AppCard({ variant: 'outlined', cardPadding: 'compact' }) {
                Column({ space: SpacingTokens.SM }) {
                  Row() {
                    Column({ space: SpacingTokens.XS }) {
                      Text(plan.name)
                        .fontSize(FontTokens.BODY_SIZE)
                        .fontWeight(FontWeight.Medium)
                        .fontColor(ColorTokens.TEXT_PRIMARY)
                        .width('100%')

                      Text(plan.targetAudience)
                        .fontSize(FontTokens.CAPTION_SIZE)
                        .fontColor(ColorTokens.TEXT_SECONDARY)
                        .width('100%')
                    }
                    .layoutWeight(1)
                    .alignItems(HorizontalAlign.Start)

                    Text(plan.trainingDayCount.toString() + ' \u5929')
                      .fontSize(FontTokens.SMALL_SIZE)
                      .fontColor(ColorTokens.TEXT_ON_PRIMARY)
                      .padding({
                        top: SpacingTokens.XS,
                        bottom: SpacingTokens.XS,
                        left: SpacingTokens.SM,
                        right: SpacingTokens.SM
                      })
                      .backgroundColor(plan.coverColor)
                      .borderRadius(RadiusTokens.FULL)
                  }
                  .width('100%')

                  Text(plan.weeklyFrequency)
                    .fontSize(FontTokens.CAPTION_SIZE)
                    .fontColor(ColorTokens.TEXT_SECONDARY)
                    .width('100%')

                  AppButton({
                    text: '\u67e5\u770b\u8ba1\u5212\u8be6\u60c5',
                    type: 'secondary',
                    buttonSize: 'medium',
                    block: true,
                    onButtonClick: () => {
                      this.openTrainingPlanDetail(plan.presetPlanId)
                    }
                  })
                }
                .width('100%')
                .alignItems(HorizontalAlign.Start)
              }
            }, (plan: HomePresetPlanCard) => plan.presetPlanId)
          }
          .width('100%')
          .padding(SpacingTokens.MD)
          .borderRadius(RadiusTokens.LG)
          .backgroundColor(ColorTokens.BG_SECONDARY)
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

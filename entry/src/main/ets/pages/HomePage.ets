/**
 * HomePage -- today training entry.
 * Function #4: home goal summary.
 * Function #5: weekly plan rows.
 * Function #8: today training entry.
 * Function #19: current preset plan today view.
 * Function #20: current preset plan rest-day view.
 */
import { router } from '@kit.ArkUI'
import { AppRoutes } from '../app/AppRoutes'
import TrainingPlanService, { PresetPlan, UserPlan } from '../common/services/TrainingPlanService'
import WorkoutDraftService, { hasWorkoutDraftProgress, WorkoutDraftSnapshot } from '../common/services/WorkoutDraftService'
import { ColorTokens, FontTokens, RadiusTokens, SpacingTokens, TouchTokens } from '../common/styles/DesignTokens'
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

  async aboutToAppear(): Promise<void> {
    this.loading = true
    try {
      this.loadPresetPlanCards()
      await this.loadWorkoutDraft()

      const currentPlan: UserPlan | null = await TrainingPlanService.getCurrentPlan(getContext(this))
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

      const goal: UserGoal | undefined = await GoalRepository.loadGoal(getContext(this))
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

  async loadWorkoutDraft(): Promise<void> {
    const snapshot: WorkoutDraftSnapshot | null = await WorkoutDraftService.getDraft(getContext(this))
    if (snapshot === null || !hasWorkoutDraftProgress(snapshot)) {
      this.hasRecoverableDraft = false
      this.recoverDraftSummary = ''
      return
    }

    this.hasRecoverableDraft = true
    this.recoverDraftSummary = snapshot.dayLabel + ' | ' + snapshot.completedSets.toString() + '/' +
      snapshot.totalTargetSets.toString() + ' 组'
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
    this.startButtonText = summary.startButtonText
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
      router.replaceUrl({ url: AppRoutes.GOAL_SETUP })
    } catch (e) {
      // stay on home
    }
  }

  openWorkoutPreview(): void {
    if (this.startRoute.length === 0) {
      return
    }
    try {
      router.pushUrl({ url: this.startRoute, params: { dayId: this.todayDayId } })
    } catch (e) {
      // stay on home
    }
  }

  openReviewHome(): void {
    try {
      router.pushUrl({ url: AppRoutes.REVIEW_HOME })
    } catch (e) {
      // stay on home
    }
  }

  openActiveWorkout(): void {
    try {
      router.pushUrl({ url: AppRoutes.ACTIVE_WORKOUT })
    } catch (e) {
      // stay on home
    }
  }

  openExerciseLibrary(): void {
    try {
      router.pushUrl({ url: AppRoutes.EXERCISE_LIBRARY })
    } catch (e) {
      // stay on home
    }
  }

  openTrainingPlanDetail(presetPlanId: string): void {
    try {
      router.pushUrl({ url: AppRoutes.TRAINING_PLAN_DETAIL, params: { presetPlanId: presetPlanId } })
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

  build() {
    Scroll() {
      Column({ space: SpacingTokens.LG }) {
        Column({ space: SpacingTokens.SM }) {
          Text('今日训练入口')
            .fontSize(FontTokens.DISPLAY_SIZE)
            .fontWeight(FontTokens.DISPLAY_WEIGHT)
            .fontColor(ColorTokens.TEXT_PRIMARY)

          Text(this.loading ? '正在读取训练安排' : '根据当前训练计划展示今天的训练或恢复状态')
            .fontSize(FontTokens.BODY_SIZE)
            .fontColor(ColorTokens.TEXT_SECONDARY)
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)

        if (!this.loading && this.hasRecoverableDraft) {
          Column({ space: SpacingTokens.SM }) {
            Text('继续未完成训练')
              .fontSize(FontTokens.TITLE_SIZE)
              .fontWeight(FontTokens.TITLE_WEIGHT)
              .fontColor(ColorTokens.TEXT_PRIMARY)

            Text(this.recoverDraftSummary)
              .fontSize(FontTokens.BODY_SIZE)
              .fontColor(ColorTokens.TEXT_SECONDARY)

            Button('恢复训练')
              .width('100%')
              .height(TouchTokens.BUTTON_HEIGHT_LARGE)
              .fontSize(FontTokens.BODY_SIZE)
              .fontWeight(FontWeight.Medium)
              .fontColor(ColorTokens.TEXT_ON_PRIMARY)
              .backgroundColor(ColorTokens.ACCENT)
              .borderRadius(RadiusTokens.FULL)
              .onClick(() => {
                this.openActiveWorkout()
              })
          }
          .width('100%')
          .padding(SpacingTokens.MD)
          .borderRadius(RadiusTokens.SM)
          .backgroundColor(ColorTokens.BG_SECONDARY)
        }

        if (!this.loading && !this.hasGoal) {
          Column({ space: SpacingTokens.MD }) {
            Text('还没有训练目标')
              .fontSize(FontTokens.TITLE_SIZE)
              .fontWeight(FontTokens.TITLE_WEIGHT)
              .fontColor(ColorTokens.TEXT_PRIMARY)

            Text('先完成目标设置，FitTracker 会基于目标生成本周训练计划。')
              .fontSize(FontTokens.BODY_SIZE)
              .fontColor(ColorTokens.TEXT_SECONDARY)

            Button('设置训练目标')
              .width('100%')
              .height(TouchTokens.BUTTON_HEIGHT_LARGE)
              .fontSize(FontTokens.BODY_SIZE)
              .fontColor(ColorTokens.TEXT_ON_PRIMARY)
              .backgroundColor(ColorTokens.PRIMARY)
              .borderRadius(RadiusTokens.FULL)
              .onClick(() => {
                this.openGoalSetup()
              })
          }
          .width('100%')
          .padding(SpacingTokens.MD)
          .borderRadius(RadiusTokens.SM)
          .backgroundColor(ColorTokens.BG_SECONDARY)
        }

        if (!this.loading && this.hasGoal) {
          Column({ space: SpacingTokens.MD }) {
            Text(this.planName)
              .fontSize(FontTokens.TITLE_SIZE)
              .fontWeight(FontTokens.TITLE_WEIGHT)
              .fontColor(ColorTokens.TEXT_PRIMARY)

            Text(this.goalSummary)
              .fontSize(FontTokens.BODY_SIZE)
              .fontColor(ColorTokens.TEXT_SECONDARY)

            Row() {
              Text(this.primaryMetaText)
                .fontSize(FontTokens.CAPTION_SIZE)
                .fontColor(ColorTokens.TEXT_ON_PRIMARY)
                .padding({
                  top: SpacingTokens.XS,
                  bottom: SpacingTokens.XS,
                  left: SpacingTokens.SM,
                  right: SpacingTokens.SM
                })
                .backgroundColor(ColorTokens.PRIMARY)
                .borderRadius(RadiusTokens.FULL)

              Text(this.secondaryMetaText)
                .fontSize(FontTokens.CAPTION_SIZE)
                .fontColor(ColorTokens.TEXT_ON_PRIMARY)
                .padding({
                  top: SpacingTokens.XS,
                  bottom: SpacingTokens.XS,
                  left: SpacingTokens.SM,
                  right: SpacingTokens.SM
                })
                .backgroundColor(ColorTokens.ACCENT)
                .borderRadius(RadiusTokens.FULL)
                .margin({ left: SpacingTokens.SM })
            }
            .width('100%')

            Column({ space: SpacingTokens.XS }) {
              Text(this.equipmentSummary)
                .fontSize(FontTokens.CAPTION_SIZE)
                .fontColor(ColorTokens.TEXT_SECONDARY)

              Text(this.restrictionSummary)
                .fontSize(FontTokens.CAPTION_SIZE)
                .fontColor(ColorTokens.TEXT_SECONDARY)
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)

            Column({ space: SpacingTokens.SM }) {
              Text(this.todayLabel)
                .fontSize(FontTokens.HEADLINE_SIZE)
                .fontWeight(FontTokens.HEADLINE_WEIGHT)
                .fontColor(ColorTokens.TEXT_PRIMARY)

              if (this.hasTodayWorkout) {
                Text(this.todayExerciseCount.toString() + ' 个动作')
                  .fontSize(FontTokens.BODY_SIZE)
                  .fontColor(ColorTokens.TEXT_SECONDARY)

                Text('今日动作')
                  .fontSize(FontTokens.CAPTION_SIZE)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(ColorTokens.TEXT_PRIMARY)

                ForEach(this.recommendedExercises, (exercise: HomeRecommendedExercise, index: number) => {
                  Row() {
                    Text((index + 1).toString())
                      .fontSize(FontTokens.SMALL_SIZE)
                      .fontColor(ColorTokens.TEXT_ON_PRIMARY)
                      .width(24)
                      .height(24)
                      .textAlign(TextAlign.Center)
                      .backgroundColor(ColorTokens.SURFACE_ELEVATED)
                      .borderRadius(RadiusTokens.FULL)

                    Column({ space: SpacingTokens.XS }) {
                      Text(exercise.name)
                        .fontSize(FontTokens.BODY_SIZE)
                        .fontWeight(FontWeight.Medium)
                        .fontColor(ColorTokens.TEXT_PRIMARY)

                      Text(exercise.prescription + ' | ' + exercise.intensityNote)
                        .fontSize(FontTokens.CAPTION_SIZE)
                        .fontColor(ColorTokens.TEXT_SECONDARY)
                    }
                    .layoutWeight(1)
                    .alignItems(HorizontalAlign.Start)
                    .margin({ left: SpacingTokens.SM })
                  }
                  .width('100%')
                }, (exercise: HomeRecommendedExercise) => exercise.exerciseId)
              } else {
                Text(this.todayRestMessage)
                  .fontSize(FontTokens.BODY_SIZE)
                  .fontColor(ColorTokens.TEXT_SECONDARY)
              }
            }
            .width('100%')
            .padding(SpacingTokens.MD)
            .borderRadius(RadiusTokens.SM)
            .backgroundColor(ColorTokens.SURFACE_PRIMARY)

            Button(this.startButtonText)
              .width('100%')
              .height(TouchTokens.BUTTON_HEIGHT_LARGE)
              .fontSize(FontTokens.BODY_SIZE)
              .fontWeight(FontWeight.Medium)
              .fontColor(ColorTokens.TEXT_ON_PRIMARY)
              .backgroundColor(this.startRoute.length > 0 ? ColorTokens.PRIMARY : ColorTokens.PRIMARY_DISABLED)
              .borderRadius(RadiusTokens.FULL)
              .onClick(() => {
                this.openWorkoutPreview()
              })

            Button('查看训练回顾')
              .width('100%')
              .height(TouchTokens.BUTTON_HEIGHT_LARGE)
              .fontSize(FontTokens.BODY_SIZE)
              .fontColor(ColorTokens.TEXT_PRIMARY)
              .backgroundColor(ColorTokens.SURFACE_ELEVATED)
              .borderRadius(RadiusTokens.FULL)
              .onClick(() => {
                this.openReviewHome()
              })

            Button('查看动作库')
              .width('100%')
              .height(TouchTokens.BUTTON_HEIGHT_LARGE)
              .fontSize(FontTokens.BODY_SIZE)
              .fontColor(ColorTokens.TEXT_PRIMARY)
              .backgroundColor(ColorTokens.SURFACE_ELEVATED)
              .borderRadius(RadiusTokens.FULL)
              .onClick(() => {
                this.openExerciseLibrary()
              })
          }
          .width('100%')
          .padding(SpacingTokens.MD)
          .borderRadius(RadiusTokens.SM)
          .backgroundColor(ColorTokens.BG_SECONDARY)

          Column({ space: SpacingTokens.MD }) {
            Text('本周计划')
              .fontSize(FontTokens.TITLE_SIZE)
              .fontWeight(FontTokens.TITLE_WEIGHT)
              .fontColor(ColorTokens.TEXT_PRIMARY)

            ForEach(this.weeklyPlanDays, (day: HomeWeeklyPlanDay) => {
              Row() {
                Column() {
                  Text(day.title)
                    .fontSize(FontTokens.BODY_SIZE)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(ColorTokens.TEXT_PRIMARY)

                  Text(day.exerciseCount.toString() + ' 个动作')
                    .fontSize(FontTokens.CAPTION_SIZE)
                    .fontColor(ColorTokens.TEXT_SECONDARY)
                    .margin({ top: SpacingTokens.XS })
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)

                Text(day.isToday ? '今天' : '计划')
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
          .padding(SpacingTokens.MD)
          .borderRadius(RadiusTokens.SM)
          .backgroundColor(ColorTokens.BG_SECONDARY)
        }

        if (!this.loading) {
          Column({ space: SpacingTokens.MD }) {
            Text('预置训练计划')
              .fontSize(FontTokens.TITLE_SIZE)
              .fontWeight(FontTokens.TITLE_WEIGHT)
              .fontColor(ColorTokens.TEXT_PRIMARY)

            Text('至少包含五分化、上下肢分裂、推拉腿、全身训练 3x 和力量举基础。')
              .fontSize(FontTokens.BODY_SIZE)
              .fontColor(ColorTokens.TEXT_SECONDARY)

            ForEach(this.presetPlanCards, (plan: HomePresetPlanCard) => {
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

                  Text(plan.trainingDayCount.toString() + ' 天')
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

                Button('查看计划详情')
                  .width('100%')
                  .height(TouchTokens.BUTTON_HEIGHT_DEFAULT)
                  .fontSize(FontTokens.BODY_SIZE)
                  .fontColor(ColorTokens.TEXT_PRIMARY)
                  .backgroundColor(ColorTokens.SURFACE_ELEVATED)
                  .borderRadius(RadiusTokens.FULL)
                  .onClick(() => {
                    this.openTrainingPlanDetail(plan.presetPlanId)
                  })
              }
              .width('100%')
              .padding(SpacingTokens.MD)
              .borderRadius(RadiusTokens.SM)
              .backgroundColor(ColorTokens.SURFACE_PRIMARY)
              .border({
                width: 1,
                color: plan.coverColor
              })
            }, (plan: HomePresetPlanCard) => plan.presetPlanId)
          }
          .width('100%')
          .padding(SpacingTokens.MD)
          .borderRadius(RadiusTokens.SM)
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

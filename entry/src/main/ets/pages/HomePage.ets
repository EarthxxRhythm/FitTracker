/**
 * HomePage -- today training entry.
 * Function #4: home goal summary.
 * Function #5: weekly plan rows.
 * Function #8: today training entry.
 */
import { router } from '@kit.ArkUI'
import { AppRoutes } from '../app/AppRoutes'
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

@Entry
@Component
export struct HomePage {
  @State loading: boolean = true
  @State hasGoal: boolean = false
  @State planId: string = ''
  @State planName: string = ''
  @State weeklyDays: number = 0
  @State sessionMinutes: number = 0
  @State goalSummary: string = ''
  @State equipmentSummary: string = ''
  @State restrictionSummary: string = ''
  @State todayDayId: string = ''
  @State todayTitle: string = ''
  @State todayLabel: string = ''
  @State todayExerciseCount: number = 0
  @State recommendedExercises: HomeRecommendedExercise[] = []
  @State startButtonText: string = ''
  @State startRoute: string = ''
  @State weeklyPlanDays: HomeWeeklyPlanDay[] = []
  @State hasRecoverableDraft: boolean = false
  @State recoverDraftSummary: string = ''

  async aboutToAppear(): Promise<void> {
    this.loading = true
    try {
      await this.loadWorkoutDraft()
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

  async loadWorkoutDraft(): Promise<void> {
    const snapshot: WorkoutDraftSnapshot | null = await WorkoutDraftService.getDraft(getContext(this))
    if (snapshot === null || !hasWorkoutDraftProgress(snapshot)) {
      this.hasRecoverableDraft = false
      this.recoverDraftSummary = ''
      return
    }

    this.hasRecoverableDraft = true
    this.recoverDraftSummary = snapshot.dayLabel + ' | ' + snapshot.completedSets.toString() + '/' + snapshot.totalTargetSets.toString() + ' 组'
  }

  applySummary(summary: HomePlanSummary): void {
    this.hasGoal = summary.hasGoal
    this.planId = summary.planId
    this.planName = summary.planName
    this.weeklyDays = summary.weeklyDays
    this.sessionMinutes = summary.sessionMinutes
    this.goalSummary = summary.goalSummary
    this.equipmentSummary = summary.equipmentSummary
    this.restrictionSummary = summary.restrictionSummary
    this.todayDayId = summary.todayDayId
    this.todayTitle = summary.todayTitle
    this.todayLabel = summary.todayLabel
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

  build() {
    Scroll() {
      Column({ space: SpacingTokens.LG }) {
        Column({ space: SpacingTokens.SM }) {
          Text('今日训练入口')
            .fontSize(FontTokens.DISPLAY_SIZE)
            .fontWeight(FontTokens.DISPLAY_WEIGHT)
            .fontColor(ColorTokens.TEXT_PRIMARY)

          Text(this.loading ? '正在读取训练目标' : '目标驱动的本周训练入口')
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
              Text('每周 ' + this.weeklyDays.toString() + ' 天')
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

              Text('单次 ' + this.sessionMinutes.toString() + ' 分钟')
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

              Text(this.todayExerciseCount.toString() + ' 个动作')
                .fontSize(FontTokens.BODY_SIZE)
                .fontColor(ColorTokens.TEXT_SECONDARY)

              Text('推荐动作')
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
                  .fontColor(ColorTokens.TEXT_ON_PRIMARY)
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
      }
      .width('100%')
      .padding(SpacingTokens.LG)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ColorTokens.BG_PRIMARY)
  }
}

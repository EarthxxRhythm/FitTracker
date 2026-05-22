/**
 * HomePage -- today training entry.
 * Function #8: today training entry.
 */
import { router } from '@kit.ArkUI'
import { AppRoutes } from '../app/AppRoutes'
import { ColorTokens, FontTokens, RadiusTokens, SpacingTokens, TouchTokens } from '../common/styles/DesignTokens'
import { PlanDay, TrainingPlan, UserGoal } from '../shared/models/TrainingModels'
import GoalRepository from '../shared/services/GoalRepository'
import HomePlanService, { HomePlanSummary } from '../shared/services/HomePlanService'
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
  @State todayDayId: string = ''
  @State todayTitle: string = ''
  @State todayExerciseCount: number = 0
  @State todayExerciseNames: string[] = []
  @State planDays: PlanDay[] = []

  async aboutToAppear(): Promise<void> {
    this.loading = true
    try {
      const goal: UserGoal | undefined = await GoalRepository.loadGoal(getContext(this))
      if (goal === undefined) {
        this.hasGoal = false
        this.loading = false
        return
      }

      const plan: TrainingPlan = PlanEngine.generatePlan(goal)
      const todaySeed: number = this.getTodaySeed()
      const summary: HomePlanSummary = HomePlanService.createSummary(goal, plan, todaySeed)
      this.applySummary(summary, plan.days)
    } catch (e) {
      this.hasGoal = false
    }
    this.loading = false
  }

  applySummary(summary: HomePlanSummary, days: PlanDay[]): void {
    this.hasGoal = summary.hasGoal
    this.planId = summary.planId
    this.planName = summary.planName
    this.weeklyDays = summary.weeklyDays
    this.sessionMinutes = summary.sessionMinutes
    this.todayDayId = summary.todayDayId
    this.todayTitle = summary.todayTitle
    this.todayExerciseCount = summary.todayExerciseCount
    this.todayExerciseNames = this.copyStringArray(summary.todayExerciseNames)
    this.planDays = this.copyPlanDays(days)
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
    try {
      router.pushUrl({ url: AppRoutes.WORKOUT_PREVIEW })
    } catch (e) {
      // stay on home
    }
  }

  copyStringArray(source: string[]): string[] {
    const values: string[] = []
    for (let index = 0; index < source.length; index++) {
      values.push(source[index])
    }
    return values
  }

  copyPlanDays(source: PlanDay[]): PlanDay[] {
    const days: PlanDay[] = []
    for (let index = 0; index < source.length; index++) {
      days.push(source[index])
    }
    return days
  }

  build() {
    Scroll() {
      Column({ space: SpacingTokens.LG }) {
        Column({ space: SpacingTokens.SM }) {
          Text('今日训练')
            .fontSize(FontTokens.DISPLAY_SIZE)
            .fontWeight(FontTokens.DISPLAY_WEIGHT)
            .fontColor(ColorTokens.TEXT_PRIMARY)

          Text(this.loading ? '正在读取训练目标' : '目标驱动的本周训练入口')
            .fontSize(FontTokens.BODY_SIZE)
            .fontColor(ColorTokens.TEXT_SECONDARY)
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)

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

            Column({ space: SpacingTokens.SM }) {
              Text(this.todayTitle)
                .fontSize(FontTokens.HEADLINE_SIZE)
                .fontWeight(FontTokens.HEADLINE_WEIGHT)
                .fontColor(ColorTokens.TEXT_PRIMARY)

              Text(this.todayExerciseCount.toString() + ' 个动作')
                .fontSize(FontTokens.BODY_SIZE)
                .fontColor(ColorTokens.TEXT_SECONDARY)

              ForEach(this.todayExerciseNames, (name: string, index: number) => {
                Row() {
                  Text((index + 1).toString())
                    .fontSize(FontTokens.SMALL_SIZE)
                    .fontColor(ColorTokens.TEXT_ON_PRIMARY)
                    .width(24)
                    .height(24)
                    .textAlign(TextAlign.Center)
                    .backgroundColor(ColorTokens.SURFACE_ELEVATED)
                    .borderRadius(RadiusTokens.FULL)

                  Text(name)
                    .fontSize(FontTokens.BODY_SIZE)
                    .fontColor(ColorTokens.TEXT_PRIMARY)
                    .margin({ left: SpacingTokens.SM })
                }
                .width('100%')
              }, (name: string, index: number) => name + index.toString())
            }
            .width('100%')
            .padding(SpacingTokens.MD)
            .borderRadius(RadiusTokens.SM)
            .backgroundColor(ColorTokens.SURFACE_PRIMARY)

            Button('开始今日训练')
              .width('100%')
              .height(TouchTokens.BUTTON_HEIGHT_LARGE)
              .fontSize(FontTokens.BODY_SIZE)
              .fontWeight(FontWeight.Medium)
              .fontColor(ColorTokens.TEXT_ON_PRIMARY)
              .backgroundColor(ColorTokens.PRIMARY)
              .borderRadius(RadiusTokens.FULL)
              .onClick(() => {
                this.openWorkoutPreview()
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

            ForEach(this.planDays, (day: PlanDay) => {
              Row() {
                Column() {
                  Text(day.title)
                    .fontSize(FontTokens.BODY_SIZE)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(ColorTokens.TEXT_PRIMARY)

                  Text(day.exercises.length.toString() + ' 个动作')
                    .fontSize(FontTokens.CAPTION_SIZE)
                    .fontColor(ColorTokens.TEXT_SECONDARY)
                    .margin({ top: SpacingTokens.XS })
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)

                Text(day.dayId === this.todayDayId ? '今天' : '计划')
                  .fontSize(FontTokens.SMALL_SIZE)
                  .fontColor(ColorTokens.TEXT_ON_PRIMARY)
                  .padding({
                    top: SpacingTokens.XS,
                    bottom: SpacingTokens.XS,
                    left: SpacingTokens.SM,
                    right: SpacingTokens.SM
                  })
                  .backgroundColor(day.dayId === this.todayDayId ? ColorTokens.SUCCESS : ColorTokens.SURFACE_ELEVATED)
                  .borderRadius(RadiusTokens.FULL)
              }
              .width('100%')
              .padding(SpacingTokens.MD)
              .borderRadius(RadiusTokens.SM)
              .backgroundColor(ColorTokens.SURFACE_PRIMARY)
            }, (day: PlanDay) => day.dayId)
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

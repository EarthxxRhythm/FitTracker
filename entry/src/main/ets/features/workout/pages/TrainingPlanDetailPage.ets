/**
 * TrainingPlanDetailPage -- preset training plan detail and activation entry.
 * Function #15: preset plan detail with grouped training days.
 * Function #16: each training day shows exercise list and prescription.
 * Function #17: enable preset plan and set it as current plan.
 */
import { router } from '@kit.ArkUI'
import { AppRoutes } from '../../../app/AppRoutes'
import TrainingPlanService, {
  ExerciseRef,
  PresetPlan,
  TrainingDay
} from '../../../common/services/TrainingPlanService'
import { ColorTokens, FontTokens, RadiusTokens, SpacingTokens, TouchTokens } from '../../../common/styles/DesignTokens'

@Entry
@Component
export struct TrainingPlanDetailPage {
  @State loading: boolean = true
  @State enabling: boolean = false
  @State hasPlan: boolean = false
  @State presetPlanId: string = ''
  @State title: string = ''
  @State targetAudience: string = ''
  @State weeklyFrequency: string = ''
  @State coverColor: string = ColorTokens.PRIMARY
  @State days: TrainingDay[] = []
  @State actionMessage: string = ''

  aboutToAppear(): void {
    const presetPlanId: string = this.getPresetPlanId()
    if (presetPlanId.length === 0) {
      this.loading = false
      this.hasPlan = false
      return
    }

    const presetPlan: PresetPlan | undefined = TrainingPlanService.getPresetPlanById(presetPlanId)
    if (presetPlan === undefined) {
      this.loading = false
      this.hasPlan = false
      return
    }

    this.applyPlan(presetPlan)
    this.loading = false
  }

  getPresetPlanId(): string {
    try {
      const params = router.getParams() as Record<string, string>
      if (params.presetPlanId !== undefined) {
        return params.presetPlanId
      }
    } catch (e) {
      return ''
    }
    return ''
  }

  applyPlan(plan: PresetPlan): void {
    this.hasPlan = true
    this.presetPlanId = plan.id
    this.title = plan.name
    this.targetAudience = plan.targetAudience
    this.weeklyFrequency = plan.weeklyFrequency
    this.coverColor = plan.coverColor
    this.days = this.copyTrainingDays(plan.days)
  }

  copyTrainingDays(source: TrainingDay[]): TrainingDay[] {
    const days: TrainingDay[] = []
    for (let index = 0; index < source.length; index++) {
      const sourceDay: TrainingDay = source[index]
      const item: TrainingDay = {
        dayLabel: sourceDay.dayLabel,
        dayOfWeek: this.copyNumbers(sourceDay.dayOfWeek),
        exercises: this.copyExercises(sourceDay.exercises)
      }
      days.push(item)
    }
    return days
  }

  copyExercises(source: ExerciseRef[]): ExerciseRef[] {
    const exercises: ExerciseRef[] = []
    for (let index = 0; index < source.length; index++) {
      const sourceExercise: ExerciseRef = source[index]
      const item: ExerciseRef = {
        name: sourceExercise.name,
        targetMuscle: sourceExercise.targetMuscle,
        sets: sourceExercise.sets,
        reps: sourceExercise.reps
      }
      exercises.push(item)
    }
    return exercises
  }

  copyNumbers(source: number[] | undefined): number[] | undefined {
    if (source === undefined) {
      return undefined
    }
    const values: number[] = []
    for (let index = 0; index < source.length; index++) {
      values.push(source[index])
    }
    return values
  }

  async enablePlan(): Promise<void> {
    if (this.enabling || this.presetPlanId.length === 0) {
      return
    }

    this.enabling = true
    this.actionMessage = ''
    const enabledPlan = await TrainingPlanService.enablePlan(getContext(this), this.presetPlanId)
    this.enabling = false
    if (enabledPlan === null) {
      this.actionMessage = '\u542f\u7528\u8ba1\u5212\u5931\u8d25\uff0c\u8bf7\u7a0d\u540e\u91cd\u8bd5\u3002'
      return
    }

    this.actionMessage = '\u8ba1\u5212\u5df2\u542f\u7528\uff0c\u6b63\u5728\u8fd4\u56de\u9996\u9875\u3002'
    try {
      router.replaceUrl({ url: AppRoutes.HOME })
    } catch (e) {
      // stay on current page with success message
    }
  }

  openBack(): void {
    try {
      router.back()
    } catch (e) {
      try {
        router.replaceUrl({ url: AppRoutes.HOME })
      } catch (innerError) {
        // stay on current page
      }
    }
  }

  build() {
    Scroll() {
      Column({ space: SpacingTokens.LG }) {
        Row() {
          Text('返回')
            .fontSize(FontTokens.BODY_SIZE)
            .fontColor(ColorTokens.PRIMARY)
            .onClick(() => {
              this.openBack()
            })

          Blank()
        }
        .width('100%')

        if (!this.loading && !this.hasPlan) {
          Column({ space: SpacingTokens.SM }) {
            Text('训练计划详情')
              .fontSize(FontTokens.DISPLAY_SIZE)
              .fontWeight(FontTokens.DISPLAY_WEIGHT)
              .fontColor(ColorTokens.TEXT_PRIMARY)

            Text('没有找到这个预置计划，请返回首页重新选择。')
              .fontSize(FontTokens.BODY_SIZE)
              .fontColor(ColorTokens.TEXT_SECONDARY)
          }
          .width('100%')
          .padding(SpacingTokens.MD)
          .borderRadius(RadiusTokens.SM)
          .backgroundColor(ColorTokens.BG_SECONDARY)
          .alignItems(HorizontalAlign.Start)
        }

        if (this.loading) {
          Column({ space: SpacingTokens.SM }) {
            Text('训练计划详情')
              .fontSize(FontTokens.DISPLAY_SIZE)
              .fontWeight(FontTokens.DISPLAY_WEIGHT)
              .fontColor(ColorTokens.TEXT_PRIMARY)

            Text('正在加载预置计划...')
              .fontSize(FontTokens.BODY_SIZE)
              .fontColor(ColorTokens.TEXT_SECONDARY)
          }
          .width('100%')
          .padding(SpacingTokens.MD)
          .borderRadius(RadiusTokens.SM)
          .backgroundColor(ColorTokens.BG_SECONDARY)
          .alignItems(HorizontalAlign.Start)
        }

        if (!this.loading && this.hasPlan) {
          Column({ space: SpacingTokens.MD }) {
            Column({ space: SpacingTokens.SM }) {
              Text(this.title)
                .fontSize(FontTokens.DISPLAY_SIZE)
                .fontWeight(FontTokens.DISPLAY_WEIGHT)
                .fontColor(ColorTokens.TEXT_PRIMARY)

              Text('适用人群：' + this.targetAudience)
                .fontSize(FontTokens.BODY_SIZE)
                .fontColor(ColorTokens.TEXT_SECONDARY)

              Text('训练频率：' + this.weeklyFrequency)
                .fontSize(FontTokens.BODY_SIZE)
                .fontColor(ColorTokens.TEXT_SECONDARY)
            }
            .width('100%')
            .padding(SpacingTokens.MD)
            .borderRadius(RadiusTokens.SM)
            .backgroundColor(ColorTokens.BG_SECONDARY)
            .border({
              width: 1,
              color: this.coverColor
            })
            .alignItems(HorizontalAlign.Start)

            ForEach(this.days, (day: TrainingDay, dayIndex: number) => {
              Column({ space: SpacingTokens.SM }) {
                Text(day.dayLabel)
                  .fontSize(FontTokens.TITLE_SIZE)
                  .fontWeight(FontTokens.TITLE_WEIGHT)
                  .fontColor(ColorTokens.TEXT_PRIMARY)
                  .width('100%')

                ForEach(day.exercises, (exercise: ExerciseRef, exerciseIndex: number) => {
                  Row() {
                    Text((exerciseIndex + 1).toString())
                      .fontSize(FontTokens.SMALL_SIZE)
                      .fontColor(ColorTokens.TEXT_ON_PRIMARY)
                      .width(24)
                      .height(24)
                      .textAlign(TextAlign.Center)
                      .backgroundColor(this.coverColor)
                      .borderRadius(RadiusTokens.FULL)

                    Column({ space: SpacingTokens.XS }) {
                      Text(exercise.name)
                        .fontSize(FontTokens.BODY_SIZE)
                        .fontWeight(FontWeight.Medium)
                        .fontColor(ColorTokens.TEXT_PRIMARY)
                        .width('100%')

                      Text(exercise.targetMuscle + ' | ' + exercise.sets.toString() + ' 组 x ' + exercise.reps)
                        .fontSize(FontTokens.CAPTION_SIZE)
                        .fontColor(ColorTokens.TEXT_SECONDARY)
                        .width('100%')
                    }
                    .layoutWeight(1)
                    .alignItems(HorizontalAlign.Start)
                    .margin({ left: SpacingTokens.SM })
                  }
                  .width('100%')
                  .alignItems(VerticalAlign.Top)
                }, (exercise: ExerciseRef, exerciseIndex: number) => day.dayLabel + exercise.name + exerciseIndex.toString())
              }
              .width('100%')
              .padding(SpacingTokens.MD)
              .borderRadius(RadiusTokens.SM)
              .backgroundColor(ColorTokens.SURFACE_PRIMARY)
              .alignItems(HorizontalAlign.Start)
            }, (day: TrainingDay, dayIndex: number) => day.dayLabel + dayIndex.toString())

            Button(this.enabling ? '启用中...' : '开始此计划')
              .width('100%')
              .height(TouchTokens.BUTTON_HEIGHT_LARGE)
              .fontSize(FontTokens.BODY_SIZE)
              .fontWeight(FontWeight.Medium)
              .fontColor(ColorTokens.TEXT_ON_PRIMARY)
              .backgroundColor(this.enabling ? ColorTokens.PRIMARY_DISABLED : this.coverColor)
              .borderRadius(RadiusTokens.FULL)
              .enabled(!this.enabling)
              .onClick(() => {
                this.enablePlan()
              })

            if (this.actionMessage.length > 0) {
              Text(this.actionMessage)
                .fontSize(FontTokens.CAPTION_SIZE)
                .fontColor(ColorTokens.TEXT_SECONDARY)
                .width('100%')
            }
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

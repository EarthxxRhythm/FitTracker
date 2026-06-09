/**
 * WorkoutPreviewPage -- workout preview before active training.
 * Function #9: workout preview before active training.
 */
import { router } from '@kit.ArkUI'
import { AppRoutes } from '../../../app/AppRoutes'
import TrainingPlanService, { UserPlan } from '../../../common/services/TrainingPlanService'
import { ColorTokens, FontTokens, RadiusTokens, SpacingTokens, TouchTokens } from '../../../common/styles/DesignTokens'
import { AppButton } from '../../../components/AppButton'
import { AppCard } from '../../../components/AppCard'
import { TrainingPlan, UserGoal } from '../../../shared/models/TrainingModels'
import GoalRepository from '../../../shared/services/GoalRepository'
import PlanEngine from '../../../shared/services/PlanEngine'
import WorkoutPreviewService, {
  WorkoutPreviewExercise,
  WorkoutPreviewSummary
} from '../../../shared/services/WorkoutPreviewService'

@Entry
@Component
export struct WorkoutPreviewPage {
  @State loading: boolean = true
  @State hasGoal: boolean = false
  @State hasWorkout: boolean = false
  @State planId: string = ''
  @State planName: string = ''
  @State dayId: string = ''
  @State title: string = ''
  @State goalSummary: string = ''
  @State scheduleSummary: string = ''
  @State exerciseCount: number = 0
  @State exercises: WorkoutPreviewExercise[] = []
  @State hasFallback: boolean = false
  @State fallbackNote: string = ''
  @State usesCurrentPlan: boolean = false

  async aboutToAppear(): Promise<void> {
    this.loading = true
    try {
      const currentPlan: UserPlan | null = await TrainingPlanService.getCurrentPlan(getContext(this))
      if (currentPlan !== null) {
        const preview: WorkoutPreviewSummary = WorkoutPreviewService.createPreviewForCurrentPlan(
          currentPlan,
          this.getDayIdParam(),
          TrainingPlanService.getTodayLabel(),
          TrainingPlanService.getTodayTraining(currentPlan)
        )
        this.applyPreview(preview)
        this.hasGoal = true
        this.usesCurrentPlan = true
        this.loading = false
        return
      }

      const goal: UserGoal | undefined = await GoalRepository.loadGoal(getContext(this))
      if (goal === undefined) {
        this.hasGoal = false
        this.hasWorkout = false
        this.usesCurrentPlan = false
        this.loading = false
        return
      }

      const plan: TrainingPlan = PlanEngine.generatePlan(goal)
      const preview: WorkoutPreviewSummary = WorkoutPreviewService.createPreviewForGoal(goal, plan, this.getTodaySeed())
      this.applyPreview(preview)
      this.hasGoal = true
      this.usesCurrentPlan = false
    } catch (e) {
      this.hasGoal = false
      this.hasWorkout = false
      this.usesCurrentPlan = false
    }
    this.loading = false
  }

  applyPreview(preview: WorkoutPreviewSummary): void {
    this.hasWorkout = preview.hasWorkout
    this.planId = preview.planId
    this.planName = preview.planName
    this.dayId = preview.dayId
    this.title = preview.title
    this.goalSummary = preview.goalSummary
    this.scheduleSummary = preview.scheduleSummary
    this.exerciseCount = preview.exerciseCount
    this.exercises = this.copyPreviewExercises(preview.exercises)
    this.hasFallback = preview.hasFallback
    this.fallbackNote = preview.fallbackNote
  }

  getTodaySeed(): number {
    const today: Date = new Date()
    const day: number = today.getDay()
    if (day === 0) {
      return 7
    }
    return day
  }

  getDayIdParam(): string {
    try {
      const params = router.getParams() as Record<string, string>
      if (params.dayId !== undefined) {
        return params.dayId
      }
    } catch (e) {
      return ''
    }
    return ''
  }

  openGoalSetup(): void {
    try {
      router.replaceUrl({ url: AppRoutes.GOAL_SETUP })
    } catch (e) {
      // stay on preview
    }
  }

  startWorkout(): void {
    const preview: WorkoutPreviewSummary = {
      hasWorkout: this.hasWorkout,
      planId: this.planId,
      planName: this.planName,
      dayId: this.dayId,
      title: this.title,
      goalSummary: this.goalSummary,
      scheduleSummary: this.scheduleSummary,
      exerciseCount: this.exerciseCount,
      exercises: this.copyPreviewExercises(this.exercises),
      hasFallback: this.hasFallback,
      fallbackNote: this.fallbackNote
    }
    const targetRoute: string = WorkoutPreviewService.getStartWorkoutRoute(preview)
    if (targetRoute.length === 0) {
      return
    }

    try {
      router.pushUrl({
        url: targetRoute,
        params: {
          dayId: this.dayId,
          flowSource: this.usesCurrentPlan ? 'current_plan' : 'goal_plan'
        }
      })
    } catch (e) {
      // stay on preview
    }
  }

  openAlternative(exerciseId: string): void {
    try {
      router.pushUrl({ url: AppRoutes.EXERCISE_DETAIL, params: { exerciseId: exerciseId } })
    } catch (e) {
      // stay on preview
    }
  }

  copyPreviewExercises(source: WorkoutPreviewExercise[]): WorkoutPreviewExercise[] {
    const values: WorkoutPreviewExercise[] = []
    for (let index = 0; index < source.length; index++) {
      const exercise: WorkoutPreviewExercise = source[index]
      const item: WorkoutPreviewExercise = {
        plannedExerciseId: exercise.plannedExerciseId,
        exerciseId: exercise.exerciseId,
        name: exercise.name,
        hasExerciseDetail: exercise.hasExerciseDetail,
        targetSets: exercise.targetSets,
        targetReps: exercise.targetReps,
        intensityNote: exercise.intensityNote,
        alternativeExerciseIds: this.copyStringArray(exercise.alternativeExerciseIds),
        alternativeNames: this.copyStringArray(exercise.alternativeNames),
        selectionNote: exercise.selectionNote
      }
      values.push(item)
    }
    return values
  }

  copyStringArray(source: string[]): string[] {
    const values: string[] = []
    for (let index = 0; index < source.length; index++) {
      values.push(source[index])
    }
    return values
  }

  getPreviewSubtitle(): string {
    if (this.loading) {
      return '正在整理今天的训练安排与动作明细'
    }
    if (!this.hasGoal) {
      return '先设定训练目标，系统才会生成今天的训练预览'
    }
    if (!this.hasWorkout) {
      return '当前计划没有可执行动作，先回到目标设置调整范围'
    }
    return '开始前先确认主动作、组数、强度和替代动作'
  }

  getPlanSourceText(): string {
    if (this.usesCurrentPlan) {
      return '当前启用计划'
    }
    return '今日生成计划'
  }

  getPreviewStatusText(): string {
    if (this.hasFallback) {
      return '存在替代提示'
    }
    return '可直接开始'
  }

  getPreviewStatusColor(): string {
    if (this.hasFallback) {
      return ColorTokens.WARNING
    }
    return ColorTokens.SUCCESS
  }

  getPreviewStatusBackgroundColor(): string {
    if (this.hasFallback) {
      return ColorTokens.OVERLAY_ACCENT
    }
    return ColorTokens.OVERLAY_SUCCESS
  }

  getDayBadgeText(): string {
    if (this.dayId.indexOf('current_plan_day_') === 0) {
      return '第 ' + this.dayId.substring('current_plan_day_'.length) + ' 天'
    }
    if (this.dayId.indexOf('day_') === 0) {
      return '第 ' + this.dayId.substring('day_'.length) + ' 天'
    }
    if (this.dayId.length > 0) {
      return this.dayId
    }
    return this.title
  }

  getFallbackBannerText(): string {
    if (this.fallbackNote === '预置计划动作暂未映射到动作库，将按名称记录') {
      return '部分动作暂未收录详情，本次可先按计划完成记录。'
    }
    return this.fallbackNote
  }

  getExerciseSelectionText(exercise: WorkoutPreviewExercise): string {
    if (exercise.selectionNote === '预置计划动作暂未映射到动作库，将按名称记录') {
      return '动作详情整理中，本次可先按计划完成记录。'
    }
    if (exercise.selectionNote === '预置计划动作已映射到动作库，可继续查看动作详情') {
      return ''
    }
    return exercise.selectionNote
  }

  shouldShowExerciseDetailButton(exercise: WorkoutPreviewExercise): boolean {
    return exercise.hasExerciseDetail
  }

  build() {
    Scroll() {
      Column({ space: SpacingTokens.LG }) {
        AppCard({ variant: 'panel', cardPadding: 'default' }) {
          Column({ space: SpacingTokens.SM }) {
            Text('训练前确认')
              .fontSize(FontTokens.MICRO_SIZE)
              .fontWeight(FontTokens.MICRO_WEIGHT)
              .fontColor(ColorTokens.TEXT_TERTIARY)

            Text('训练预览')
              .fontSize(FontTokens.DISPLAY_SIZE)
              .fontWeight(FontTokens.DISPLAY_WEIGHT)
              .fontColor(ColorTokens.TEXT_PRIMARY)

            Text(this.getPreviewSubtitle())
              .fontSize(FontTokens.BODY_SIZE)
              .fontColor(ColorTokens.TEXT_SECONDARY)
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
        }

        if (!this.loading && !this.hasGoal) {
          AppCard({ variant: 'outlined', cardPadding: 'default' }) {
            Column({ space: SpacingTokens.MD }) {
              Text('还没有训练目标')
                .fontSize(FontTokens.TITLE_SIZE)
                .fontWeight(FontWeight.Bold)
                .fontColor(ColorTokens.TEXT_PRIMARY)

              Text('先完成目标设置，再生成今天的训练预览。')
                .fontSize(FontTokens.BODY_SIZE)
                .fontColor(ColorTokens.TEXT_SECONDARY)

              AppButton({
                text: '设置训练目标',
                type: 'primary',
                buttonSize: 'large',
                block: true,
                onButtonClick: () => {
                  this.openGoalSetup()
                }
              })
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
          }
        }

        if (!this.loading && this.hasGoal && !this.hasWorkout) {
          AppCard({ variant: 'outlined', cardPadding: 'default' }) {
            Column({ space: SpacingTokens.MD }) {
              Text('今天没有可用训练')
                .fontSize(FontTokens.TITLE_SIZE)
                .fontWeight(FontWeight.Bold)
                .fontColor(ColorTokens.TEXT_PRIMARY)

              Text('当前目标生成的计划没有匹配动作，可以先回到目标设置调整训练范围。')
                .fontSize(FontTokens.BODY_SIZE)
                .fontColor(ColorTokens.TEXT_SECONDARY)

              AppButton({
                text: '调整目标',
                type: 'primary',
                buttonSize: 'large',
                block: true,
                onButtonClick: () => {
                  this.openGoalSetup()
                }
              })
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
          }
        }

        if (!this.loading && this.hasGoal && this.hasWorkout) {
          Column({ space: SpacingTokens.MD }) {
            AppCard({ variant: 'panel', cardPadding: 'default' }) {
              Column({ space: SpacingTokens.MD }) {
                Row() {
                  Column({ space: SpacingTokens.XS }) {
                    Text(this.getPlanSourceText())
                      .fontSize(FontTokens.MICRO_SIZE)
                      .fontWeight(FontTokens.MICRO_WEIGHT)
                      .fontColor(ColorTokens.TEXT_TERTIARY)

                    Text(this.planName)
                      .fontSize(FontTokens.TITLE_SIZE)
                      .fontWeight(FontWeight.Bold)
                      .fontColor(ColorTokens.TEXT_PRIMARY)

                    Text(this.goalSummary)
                      .fontSize(FontTokens.BODY_SIZE)
                      .fontColor(ColorTokens.TEXT_SECONDARY)

                    Text(this.scheduleSummary)
                      .fontSize(FontTokens.SMALL_SIZE)
                      .fontColor(ColorTokens.TEXT_TERTIARY)
                  }
                  .layoutWeight(1)
                  .alignItems(HorizontalAlign.Start)

                  Text(this.getPreviewStatusText())
                    .fontSize(FontTokens.SMALL_SIZE)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(this.getPreviewStatusColor())
                    .padding({
                      top: SpacingTokens.XS,
                      bottom: SpacingTokens.XS,
                      left: SpacingTokens.SM,
                      right: SpacingTokens.SM
                    })
                    .backgroundColor(this.getPreviewStatusBackgroundColor())
                    .borderRadius(RadiusTokens.FULL)
                }
                .width('100%')

                Column({ space: SpacingTokens.XS }) {
                  Text(this.title)
                    .fontSize(FontTokens.HERO_SIZE)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(ColorTokens.TEXT_PRIMARY)

                  Text('确认今天的训练安排后再进入正式记录')
                    .fontSize(FontTokens.SMALL_SIZE)
                    .fontColor(ColorTokens.TEXT_TERTIARY)
                }
                .width('100%')
                .alignItems(HorizontalAlign.Start)

                Row({ space: SpacingTokens.SM }) {
                  Column({ space: SpacingTokens.XS }) {
                    Text(this.exerciseCount.toString())
                      .fontSize(FontTokens.TITLE_SIZE)
                      .fontWeight(FontWeight.Bold)
                      .fontColor(ColorTokens.DATA_HIGHLIGHT)

                    Text('计划动作数')
                      .fontSize(FontTokens.SMALL_SIZE)
                      .fontColor(ColorTokens.TEXT_TERTIARY)
                  }
                  .layoutWeight(1)
                  .padding(SpacingTokens.MD)
                  .backgroundColor(ColorTokens.SURFACE_SECONDARY)
                  .borderRadius(RadiusTokens.MD)
                  .border({ width: 1, color: ColorTokens.BORDER_SUBTLE })
                  .alignItems(HorizontalAlign.Start)

                  Column({ space: SpacingTokens.XS }) {
                    Text(this.getDayBadgeText())
                      .fontSize(FontTokens.TITLE_SIZE)
                      .fontWeight(FontWeight.Bold)
                      .fontColor(ColorTokens.TEXT_PRIMARY)
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })

                    Text('训练日')
                      .fontSize(FontTokens.SMALL_SIZE)
                      .fontColor(ColorTokens.TEXT_TERTIARY)
                  }
                  .layoutWeight(1)
                  .padding(SpacingTokens.MD)
                  .backgroundColor(ColorTokens.SURFACE_SECONDARY)
                  .borderRadius(RadiusTokens.MD)
                  .border({ width: 1, color: ColorTokens.BORDER_SUBTLE })
                  .alignItems(HorizontalAlign.Start)
                }
                .width('100%')

                if (this.hasFallback) {
                  Column({ space: SpacingTokens.XS }) {
                    Text('替代动作提示')
                      .fontSize(FontTokens.MICRO_SIZE)
                      .fontWeight(FontTokens.MICRO_WEIGHT)
                      .fontColor(ColorTokens.WARNING)

                    Text(this.getFallbackBannerText())
                      .fontSize(FontTokens.CAPTION_SIZE)
                      .fontColor(ColorTokens.TEXT_SECONDARY)
                  }
                  .width('100%')
                  .padding(SpacingTokens.MD)
                  .backgroundColor(ColorTokens.SURFACE_SECONDARY)
                  .borderRadius(RadiusTokens.MD)
                  .border({ width: 1, color: ColorTokens.BORDER_SUBTLE })
                  .alignItems(HorizontalAlign.Start)
                }

                AppButton({
                  text: '开始训练',
                  type: 'primary',
                  buttonSize: 'large',
                  block: true,
                  onButtonClick: () => {
                    this.startWorkout()
                  }
                })
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)
            }

            ForEach(this.exercises, (exercise: WorkoutPreviewExercise, index: number) => {
              AppCard({ variant: 'outlined', cardPadding: 'default' }) {
                Column({ space: SpacingTokens.SM }) {
                  Row() {
                    Text((index + 1).toString())
                      .fontSize(FontTokens.SMALL_SIZE)
                      .fontColor(ColorTokens.TEXT_ON_PRIMARY)
                      .width(28)
                      .height(28)
                      .textAlign(TextAlign.Center)
                      .backgroundColor(ColorTokens.PRIMARY)
                      .borderRadius(RadiusTokens.FULL)

                    Column({ space: SpacingTokens.XS }) {
                      Text(exercise.name)
                        .fontSize(FontTokens.BODY_SIZE)
                        .fontWeight(FontWeight.Medium)
                        .fontColor(ColorTokens.TEXT_PRIMARY)

                      Text(exercise.targetSets.toString() + ' 组 x ' + exercise.targetReps + ' | ' + exercise.intensityNote)
                        .fontSize(FontTokens.CAPTION_SIZE)
                        .fontColor(ColorTokens.TEXT_SECONDARY)
                    }
                    .layoutWeight(1)
                    .alignItems(HorizontalAlign.Start)
                    .margin({ left: SpacingTokens.SM })
                  }
                  .width('100%')

                  if (this.getExerciseSelectionText(exercise).length > 0) {
                    Column({ space: SpacingTokens.XS }) {
                      Text('动作说明')
                        .fontSize(FontTokens.MICRO_SIZE)
                        .fontWeight(FontTokens.MICRO_WEIGHT)
                        .fontColor(ColorTokens.TEXT_TERTIARY)

                      Text(this.getExerciseSelectionText(exercise))
                        .fontSize(FontTokens.CAPTION_SIZE)
                        .fontColor(ColorTokens.TEXT_SECONDARY)
                    }
                    .width('100%')
                    .padding(SpacingTokens.MD)
                    .backgroundColor(ColorTokens.SURFACE_PRIMARY)
                    .borderRadius(RadiusTokens.MD)
                    .border({ width: 1, color: ColorTokens.BORDER_SUBTLE })
                    .alignItems(HorizontalAlign.Start)
                  }

                  if (exercise.alternativeNames.length > 0) {
                    Column({ space: SpacingTokens.XS }) {
                      Text('替代动作')
                        .fontSize(FontTokens.MICRO_SIZE)
                        .fontWeight(FontTokens.MICRO_WEIGHT)
                        .fontColor(ColorTokens.TEXT_TERTIARY)

                      Flex({ wrap: FlexWrap.Wrap }) {
                        ForEach(exercise.alternativeNames, (name: string, alternativeIndex: number) => {
                          Button(name)
                            .height(TouchTokens.BUTTON_HEIGHT_SMALL)
                            .fontSize(FontTokens.SMALL_SIZE)
                            .fontColor(ColorTokens.TEXT_PRIMARY)
                            .backgroundColor(ColorTokens.SURFACE_SECONDARY)
                            .borderRadius(RadiusTokens.MD)
                            .border({ width: 1, color: ColorTokens.BORDER_SUBTLE })
                            .margin({ right: SpacingTokens.SM, bottom: SpacingTokens.SM })
                            .onClick(() => {
                              if (alternativeIndex < exercise.alternativeExerciseIds.length) {
                                this.openAlternative(exercise.alternativeExerciseIds[alternativeIndex])
                              }
                            })
                        }, (name: string, alternativeIndex: number) => name + alternativeIndex.toString())
                      }
                      .width('100%')
                    }
                    .width('100%')
                    .alignItems(HorizontalAlign.Start)
                  }

                  AppButton({
                    text: '查看动作详情',
                    type: 'secondary',
                    buttonSize: 'small',
                    disabled: !this.shouldShowExerciseDetailButton(exercise),
                    onButtonClick: () => {
                      if (this.shouldShowExerciseDetailButton(exercise)) {
                        this.openAlternative(exercise.exerciseId)
                      }
                    }
                  })
                }
                .width('100%')
                .alignItems(HorizontalAlign.Start)
              }
            }, (exercise: WorkoutPreviewExercise) => exercise.plannedExerciseId)
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

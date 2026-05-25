/**
 * WorkoutPreviewPage -- workout preview before active training.
 * Function #9: workout preview before active training.
 */
import { router } from '@kit.ArkUI'
import { AppRoutes } from '../../../app/AppRoutes'
import { ColorTokens, FontTokens, RadiusTokens, SpacingTokens, TouchTokens } from '../../../common/styles/DesignTokens'
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

  async aboutToAppear(): Promise<void> {
    this.loading = true
    try {
      const goal: UserGoal | undefined = await GoalRepository.loadGoal(getContext(this))
      if (goal === undefined) {
        this.hasGoal = false
        this.hasWorkout = false
        this.loading = false
        return
      }

      const plan: TrainingPlan = PlanEngine.generatePlan(goal)
      const preview: WorkoutPreviewSummary = WorkoutPreviewService.createPreviewForGoal(goal, plan, this.getTodaySeed())
      this.applyPreview(preview)
      this.hasGoal = true
    } catch (e) {
      this.hasGoal = false
      this.hasWorkout = false
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
      router.pushUrl({ url: targetRoute })
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

  build() {
    Scroll() {
      Column({ space: SpacingTokens.LG }) {
        Column({ space: SpacingTokens.SM }) {
          Text('训练预览')
            .fontSize(FontTokens.DISPLAY_SIZE)
            .fontWeight(FontTokens.DISPLAY_WEIGHT)
            .fontColor(ColorTokens.TEXT_PRIMARY)

          Text(this.loading ? '正在准备今日训练' : '开始前确认动作、组数和替代动作')
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

            Text('先完成目标设置，再生成今日训练预览。')
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

        if (!this.loading && this.hasGoal && !this.hasWorkout) {
          Column({ space: SpacingTokens.MD }) {
            Text('今天没有可用训练')
              .fontSize(FontTokens.TITLE_SIZE)
              .fontWeight(FontTokens.TITLE_WEIGHT)
              .fontColor(ColorTokens.TEXT_PRIMARY)

            Text('当前目标生成的计划没有匹配动作，可以回到目标设置调整器械。')
              .fontSize(FontTokens.BODY_SIZE)
              .fontColor(ColorTokens.TEXT_SECONDARY)

            Button('调整目标')
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

        if (!this.loading && this.hasGoal && this.hasWorkout) {
          Column({ space: SpacingTokens.MD }) {
            Column({ space: SpacingTokens.SM }) {
              Text(this.planName)
                .fontSize(FontTokens.TITLE_SIZE)
                .fontWeight(FontTokens.TITLE_WEIGHT)
                .fontColor(ColorTokens.TEXT_PRIMARY)

              Text(this.goalSummary)
                .fontSize(FontTokens.BODY_SIZE)
                .fontColor(ColorTokens.TEXT_SECONDARY)

              Text(this.scheduleSummary)
                .fontSize(FontTokens.BODY_SIZE)
                .fontColor(ColorTokens.TEXT_SECONDARY)
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
            .padding(SpacingTokens.MD)
            .borderRadius(RadiusTokens.SM)
            .backgroundColor(ColorTokens.SURFACE_PRIMARY)

            Text(this.title)
              .fontSize(FontTokens.HEADLINE_SIZE)
              .fontWeight(FontTokens.HEADLINE_WEIGHT)
              .fontColor(ColorTokens.TEXT_PRIMARY)

            Row() {
              Text(this.exerciseCount.toString() + ' 个动作')
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

              Text(this.dayId)
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

            if (this.hasFallback) {
              Text(this.fallbackNote)
                .fontSize(FontTokens.CAPTION_SIZE)
                .fontColor(ColorTokens.TEXT_SECONDARY)
                .width('100%')
                .padding(SpacingTokens.SM)
                .borderRadius(RadiusTokens.SM)
                .backgroundColor(ColorTokens.SURFACE_PRIMARY)
            }

            ForEach(this.exercises, (exercise: WorkoutPreviewExercise, index: number) => {
              Column({ space: SpacingTokens.SM }) {
                Row() {
                  Text((index + 1).toString())
                    .fontSize(FontTokens.SMALL_SIZE)
                    .fontColor(ColorTokens.TEXT_ON_PRIMARY)
                    .width(26)
                    .height(26)
                    .textAlign(TextAlign.Center)
                    .backgroundColor(ColorTokens.PRIMARY)
                    .borderRadius(RadiusTokens.FULL)

                  Column() {
                    Text(exercise.name)
                      .fontSize(FontTokens.BODY_SIZE)
                      .fontWeight(FontWeight.Medium)
                      .fontColor(ColorTokens.TEXT_PRIMARY)

                    Text(exercise.targetSets.toString() + ' 组 x ' + exercise.targetReps + ' | ' + exercise.intensityNote)
                      .fontSize(FontTokens.CAPTION_SIZE)
                      .fontColor(ColorTokens.TEXT_SECONDARY)
                      .margin({ top: SpacingTokens.XS })
                  }
                  .layoutWeight(1)
                  .alignItems(HorizontalAlign.Start)
                  .margin({ left: SpacingTokens.SM })
                }
                .width('100%')

                if (exercise.alternativeNames.length > 0) {
                  Column({ space: SpacingTokens.XS }) {
                    Text('替代动作')
                      .fontSize(FontTokens.SMALL_SIZE)
                      .fontColor(ColorTokens.TEXT_SECONDARY)

                    Flex({ wrap: FlexWrap.Wrap }) {
                      ForEach(exercise.alternativeNames, (name: string, alternativeIndex: number) => {
                        Button(name)
                          .height(TouchTokens.BUTTON_HEIGHT_SMALL)
                          .fontSize(FontTokens.SMALL_SIZE)
                          .fontColor(ColorTokens.TEXT_PRIMARY)
                          .backgroundColor(ColorTokens.SURFACE_ELEVATED)
                          .borderRadius(RadiusTokens.FULL)
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
                }

                Button('查看动作详情')
                  .height(TouchTokens.BUTTON_HEIGHT_SMALL)
                  .fontSize(FontTokens.SMALL_SIZE)
                  .fontColor(ColorTokens.TEXT_PRIMARY)
                  .backgroundColor(ColorTokens.SURFACE_ELEVATED)
                  .borderRadius(RadiusTokens.FULL)
                  .onClick(() => {
                    this.openAlternative(exercise.exerciseId)
                  })
              }
              .width('100%')
              .padding(SpacingTokens.MD)
              .borderRadius(RadiusTokens.SM)
              .backgroundColor(ColorTokens.SURFACE_PRIMARY)
            }, (exercise: WorkoutPreviewExercise) => exercise.plannedExerciseId)

            Button('开始训练')
              .width('100%')
              .height(TouchTokens.BUTTON_HEIGHT_LARGE)
              .fontSize(FontTokens.BODY_SIZE)
              .fontWeight(FontWeight.Medium)
              .fontColor(ColorTokens.TEXT_ON_PRIMARY)
              .backgroundColor(ColorTokens.PRIMARY)
              .borderRadius(RadiusTokens.FULL)
              .onClick(() => {
                this.startWorkout()
              })
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

/**
 * ActiveWorkoutPage -- active workout execution.
 * Function #10: active workout execution.
 */
import { router } from '@kit.ArkUI'
import { AppRoutes } from '../../../app/AppRoutes'
import { ColorTokens, FontTokens, RadiusTokens, SpacingTokens, TouchTokens } from '../../../common/styles/DesignTokens'
import { TrainingPlan, UserGoal, WorkoutSession } from '../../../shared/models/TrainingModels'
import ActiveWorkoutService, {
  ActiveWorkoutExercise,
  ActiveWorkoutState
} from '../../../shared/services/ActiveWorkoutService'
import GoalRepository from '../../../shared/services/GoalRepository'
import PlanEngine from '../../../shared/services/PlanEngine'
import WorkoutPreviewService, { WorkoutPreviewSummary } from '../../../shared/services/WorkoutPreviewService'
import WorkoutRepository from '../../../shared/services/WorkoutRepository'

@Entry
@Component
export struct ActiveWorkoutPage {
  @State loading: boolean = true
  @State hasGoal: boolean = false
  @State hasWorkout: boolean = false
  @State startedAt: number = 0
  @State planId: string = ''
  @State dayId: string = ''
  @State title: string = ''
  @State totalTargetSets: number = 0
  @State completedSets: number = 0
  @State exercises: ActiveWorkoutExercise[] = []

  async aboutToAppear(): Promise<void> {
    this.loading = true
    this.startedAt = Date.now()
    try {
      const goal: UserGoal | undefined = await GoalRepository.loadGoal(getContext(this))
      if (goal === undefined) {
        this.hasGoal = false
        this.hasWorkout = false
        this.loading = false
        return
      }

      const plan: TrainingPlan = PlanEngine.generatePlan(goal)
      const preview: WorkoutPreviewSummary = WorkoutPreviewService.createPreview(plan, this.getTodaySeed())
      const state: ActiveWorkoutState = ActiveWorkoutService.createState(preview)
      this.applyState(state)
      this.hasGoal = true
    } catch (e) {
      this.hasGoal = false
      this.hasWorkout = false
    }
    this.loading = false
  }

  applyState(state: ActiveWorkoutState): void {
    this.hasWorkout = state.hasWorkout
    this.planId = state.planId
    this.dayId = state.dayId
    this.title = state.title
    this.totalTargetSets = state.totalTargetSets
    this.completedSets = state.completedSets
    this.exercises = this.copyActiveExercises(state.exercises)
  }

  getTodaySeed(): number {
    const today: Date = new Date()
    const day: number = today.getDay()
    if (day === 0) {
      return 7
    }
    return day
  }

  increaseSet(exercise: ActiveWorkoutExercise): void {
    this.exercises = ActiveWorkoutService.updateExerciseCompletedSets(
      this.exercises,
      exercise.plannedExerciseId,
      exercise.completedSets + 1
    )
    this.completedSets = ActiveWorkoutService.countCompletedSets(this.exercises)
  }

  decreaseSet(exercise: ActiveWorkoutExercise): void {
    this.exercises = ActiveWorkoutService.updateExerciseCompletedSets(
      this.exercises,
      exercise.plannedExerciseId,
      exercise.completedSets - 1
    )
    this.completedSets = ActiveWorkoutService.countCompletedSets(this.exercises)
  }

  finishCurrentProgress(): void {
    this.saveWorkout(this.exercises, this.completedSets)
  }

  finishAllSets(): void {
    const completedExercises: ActiveWorkoutExercise[] = ActiveWorkoutService.markAllComplete(this.exercises)
    const completedSets: number = ActiveWorkoutService.countCompletedSets(completedExercises)
    this.exercises = completedExercises
    this.completedSets = completedSets
    this.saveWorkout(completedExercises, completedSets)
  }

  saveWorkout(exercises: ActiveWorkoutExercise[], completedSets: number): void {
    if (!this.hasWorkout || completedSets <= 0) {
      return
    }

    const endedAt: number = Date.now()
    const state: ActiveWorkoutState = {
      hasWorkout: this.hasWorkout,
      planId: this.planId,
      dayId: this.dayId,
      title: this.title,
      totalTargetSets: this.totalTargetSets,
      completedSets: completedSets,
      exercises: this.copyActiveExercises(exercises)
    }
    const sessionId: string = 'session_' + endedAt.toString()
    const session: WorkoutSession = ActiveWorkoutService.createCompletedSession(
      sessionId,
      state,
      this.startedAt,
      endedAt,
      completedSets
    )
    WorkoutRepository.saveSession(session)
    this.openSummary(sessionId)
  }

  openGoalSetup(): void {
    try {
      router.replaceUrl({ url: AppRoutes.GOAL_SETUP })
    } catch (e) {
      // stay on active workout
    }
  }

  openSummary(sessionId: string): void {
    try {
      router.replaceUrl({ url: AppRoutes.WORKOUT_SUMMARY, params: { sessionId: sessionId } })
    } catch (e) {
      // stay on active workout
    }
  }

  getProgressText(): string {
    return this.completedSets.toString() + '/' + this.totalTargetSets.toString() + ' 组'
  }

  getProgressWidth(): string {
    if (this.totalTargetSets <= 0 || this.completedSets <= 0) {
      return '1%'
    }
    const percent: number = Math.floor((this.completedSets * 100) / this.totalTargetSets)
    return percent.toString() + '%'
  }

  copyActiveExercises(source: ActiveWorkoutExercise[]): ActiveWorkoutExercise[] {
    const values: ActiveWorkoutExercise[] = []
    for (let index = 0; index < source.length; index++) {
      const exercise: ActiveWorkoutExercise = source[index]
      const item: ActiveWorkoutExercise = {
        plannedExerciseId: exercise.plannedExerciseId,
        exerciseId: exercise.exerciseId,
        name: exercise.name,
        targetSets: exercise.targetSets,
        targetReps: exercise.targetReps,
        intensityNote: exercise.intensityNote,
        completedSets: exercise.completedSets
      }
      values.push(item)
    }
    return values
  }

  build() {
    Scroll() {
      Column({ space: SpacingTokens.LG }) {
        Column({ space: SpacingTokens.SM }) {
          Text('训练执行')
            .fontSize(FontTokens.DISPLAY_SIZE)
            .fontWeight(FontTokens.DISPLAY_WEIGHT)
            .fontColor(ColorTokens.TEXT_PRIMARY)

          Text(this.loading ? '正在准备今日训练' : '按计划完成组数，训练结束后进入复盘')
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

            Text('先完成目标设置，再开始今日训练。')
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
            Text('今天没有可执行训练')
              .fontSize(FontTokens.TITLE_SIZE)
              .fontWeight(FontTokens.TITLE_WEIGHT)
              .fontColor(ColorTokens.TEXT_PRIMARY)

            Text('当前计划没有匹配到动作，可以返回目标设置调整器械。')
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
              Row() {
                Text(this.title)
                  .fontSize(FontTokens.HEADLINE_SIZE)
                  .fontWeight(FontTokens.HEADLINE_WEIGHT)
                  .fontColor(ColorTokens.TEXT_PRIMARY)
                  .layoutWeight(1)

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
              }
              .width('100%')

              Text(this.getProgressText())
                .fontSize(FontTokens.CAPTION_SIZE)
                .fontColor(ColorTokens.TEXT_SECONDARY)

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

            ForEach(this.exercises, (exercise: ActiveWorkoutExercise, index: number) => {
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

                Row() {
                  Button('-')
                    .width(TouchTokens.BUTTON_HEIGHT_SMALL)
                    .height(TouchTokens.BUTTON_HEIGHT_SMALL)
                    .fontSize(FontTokens.BODY_SIZE)
                    .fontColor(ColorTokens.TEXT_PRIMARY)
                    .backgroundColor(ColorTokens.SURFACE_ELEVATED)
                    .borderRadius(RadiusTokens.FULL)
                    .onClick(() => {
                      this.decreaseSet(exercise)
                    })

                  Text(exercise.completedSets.toString() + '/' + exercise.targetSets.toString())
                    .fontSize(FontTokens.TITLE_SIZE)
                    .fontWeight(FontTokens.TITLE_WEIGHT)
                    .fontColor(ColorTokens.TEXT_PRIMARY)
                    .textAlign(TextAlign.Center)
                    .layoutWeight(1)

                  Button('+')
                    .width(TouchTokens.BUTTON_HEIGHT_SMALL)
                    .height(TouchTokens.BUTTON_HEIGHT_SMALL)
                    .fontSize(FontTokens.BODY_SIZE)
                    .fontColor(ColorTokens.TEXT_ON_PRIMARY)
                    .backgroundColor(ColorTokens.PRIMARY)
                    .borderRadius(RadiusTokens.FULL)
                    .onClick(() => {
                      this.increaseSet(exercise)
                    })
                }
                .width('100%')
                .height(TouchTokens.BUTTON_HEIGHT_DEFAULT)
              }
              .width('100%')
              .padding(SpacingTokens.MD)
              .borderRadius(RadiusTokens.SM)
              .backgroundColor(ColorTokens.SURFACE_PRIMARY)
            }, (exercise: ActiveWorkoutExercise) => exercise.plannedExerciseId)

            Button('保存当前进度')
              .width('100%')
              .height(TouchTokens.BUTTON_HEIGHT_LARGE)
              .fontSize(FontTokens.BODY_SIZE)
              .fontColor(ColorTokens.TEXT_ON_PRIMARY)
              .backgroundColor(this.completedSets > 0 ? ColorTokens.PRIMARY : ColorTokens.PRIMARY_DISABLED)
              .borderRadius(RadiusTokens.FULL)
              .onClick(() => {
                this.finishCurrentProgress()
              })

            Button('完成全部并保存')
              .width('100%')
              .height(TouchTokens.BUTTON_HEIGHT_LARGE)
              .fontSize(FontTokens.BODY_SIZE)
              .fontColor(ColorTokens.TEXT_PRIMARY)
              .backgroundColor(ColorTokens.SURFACE_ELEVATED)
              .borderRadius(RadiusTokens.FULL)
              .onClick(() => {
                this.finishAllSets()
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

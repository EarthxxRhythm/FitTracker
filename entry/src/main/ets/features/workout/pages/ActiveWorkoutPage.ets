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
  ActiveWorkoutSetEntry,
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
  @State currentExerciseName: string = ''
  @State currentExerciseSetProgress: string = '0/0'
  @State elapsedSeconds: number = 0
  @State exercises: ActiveWorkoutExercise[] = []
  private timerId: number = -1

  async aboutToAppear(): Promise<void> {
    this.loading = true
    this.startedAt = Date.now()
    this.startTimer()
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

  aboutToDisappear(): void {
    this.stopTimer()
  }

  applyState(state: ActiveWorkoutState): void {
    this.hasWorkout = state.hasWorkout
    this.planId = state.planId
    this.dayId = state.dayId
    this.title = state.title
    this.totalTargetSets = state.totalTargetSets
    this.completedSets = state.completedSets
    this.currentExerciseName = state.currentExerciseName
    this.currentExerciseSetProgress = state.currentExerciseSetProgress
    this.exercises = this.copyActiveExercises(state.exercises)
  }

  startTimer(): void {
    this.stopTimer()
    this.elapsedSeconds = 0
    this.timerId = setInterval(() => {
      const now: number = Date.now()
      if (now <= this.startedAt) {
        this.elapsedSeconds = 0
      } else {
        this.elapsedSeconds = Math.floor((now - this.startedAt) / 1000)
      }
    }, 1000)
  }

  stopTimer(): void {
    if (this.timerId !== -1) {
      clearInterval(this.timerId)
      this.timerId = -1
    }
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
    const nextExercises: ActiveWorkoutExercise[] = ActiveWorkoutService.updateExerciseCompletedSets(
      this.exercises,
      exercise.plannedExerciseId,
      exercise.completedSets + 1
    )
    this.applyProgressExercises(nextExercises)
  }

  decreaseSet(exercise: ActiveWorkoutExercise): void {
    const nextExercises: ActiveWorkoutExercise[] = ActiveWorkoutService.updateExerciseCompletedSets(
      this.exercises,
      exercise.plannedExerciseId,
      exercise.completedSets - 1
    )
    this.applyProgressExercises(nextExercises)
  }

  updateSetWeight(exercise: ActiveWorkoutExercise, setEntry: ActiveWorkoutSetEntry, weightText: string): void {
    const nextExercises: ActiveWorkoutExercise[] = ActiveWorkoutService.updateSetWeight(
      this.exercises,
      exercise.plannedExerciseId,
      setEntry.setIndex,
      weightText
    )
    this.applyProgressExercises(nextExercises)
  }

  updateSetReps(exercise: ActiveWorkoutExercise, setEntry: ActiveWorkoutSetEntry, repsText: string): void {
    const nextExercises: ActiveWorkoutExercise[] = ActiveWorkoutService.updateSetReps(
      this.exercises,
      exercise.plannedExerciseId,
      setEntry.setIndex,
      repsText
    )
    this.applyProgressExercises(nextExercises)
  }

  applyProgressExercises(exercises: ActiveWorkoutExercise[]): void {
    const state: ActiveWorkoutState = {
      hasWorkout: this.hasWorkout,
      planId: this.planId,
      dayId: this.dayId,
      title: this.title,
      totalTargetSets: this.totalTargetSets,
      completedSets: this.completedSets,
      currentExerciseName: this.currentExerciseName,
      currentExerciseSetProgress: this.currentExerciseSetProgress,
      exercises: this.copyActiveExercises(this.exercises)
    }
    const nextState: ActiveWorkoutState = ActiveWorkoutService.createStateWithProgress(state, exercises)
    this.applyState(nextState)
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
      currentExerciseName: this.currentExerciseName,
      currentExerciseSetProgress: this.currentExerciseSetProgress,
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

  getElapsedText(): string {
    const minutes: number = Math.floor(this.elapsedSeconds / 60)
    const seconds: number = this.elapsedSeconds % 60
    let secondText: string = seconds.toString()
    if (seconds < 10) {
      secondText = '0' + secondText
    }
    return minutes.toString() + ':' + secondText
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
        completedSets: exercise.completedSets,
        sets: this.copySetEntries(exercise.sets)
      }
      values.push(item)
    }
    return values
  }

  copySetEntries(source: ActiveWorkoutSetEntry[]): ActiveWorkoutSetEntry[] {
    const values: ActiveWorkoutSetEntry[] = []
    for (let index = 0; index < source.length; index++) {
      const entry: ActiveWorkoutSetEntry = source[index]
      const item: ActiveWorkoutSetEntry = {
        setIndex: entry.setIndex,
        weightText: entry.weightText,
        repsText: entry.repsText,
        estimatedOneRepMax: entry.estimatedOneRepMax,
        oneRepMaxText: entry.oneRepMaxText,
        isComplete: entry.isComplete
      }
      values.push(item)
    }
    return values
  }

  createExerciseRenderKey(exercise: ActiveWorkoutExercise): string {
    let key: string = exercise.plannedExerciseId + '_' + exercise.completedSets.toString()
    for (let index = 0; index < exercise.sets.length; index++) {
      key += '_' + this.createSetEntryRenderKey(exercise.sets[index])
    }
    return key
  }

  createSetEntryRenderKey(setEntry: ActiveWorkoutSetEntry): string {
    return setEntry.setIndex.toString() + '_' + setEntry.weightText + '_' + setEntry.repsText + '_' +
      setEntry.oneRepMaxText
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

              Row() {
                Column({ space: SpacingTokens.XS }) {
                  Text('训练计时')
                    .fontSize(FontTokens.CAPTION_SIZE)
                    .fontColor(ColorTokens.TEXT_SECONDARY)

                  Text(this.getElapsedText())
                    .fontSize(FontTokens.HEADLINE_SIZE)
                    .fontWeight(FontTokens.HEADLINE_WEIGHT)
                    .fontColor(ColorTokens.TEXT_PRIMARY)
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)

                Column({ space: SpacingTokens.XS }) {
                  Text('当前动作')
                    .fontSize(FontTokens.CAPTION_SIZE)
                    .fontColor(ColorTokens.TEXT_SECONDARY)

                  Text(this.currentExerciseName)
                    .fontSize(FontTokens.BODY_SIZE)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(ColorTokens.TEXT_PRIMARY)

                  Text(this.currentExerciseSetProgress)
                    .fontSize(FontTokens.CAPTION_SIZE)
                    .fontColor(ColorTokens.PRIMARY)
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)
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

                Text('已录入 ' + exercise.completedSets.toString() + '/' + exercise.targetSets.toString() + ' 组')
                  .fontSize(FontTokens.CAPTION_SIZE)
                  .fontColor(ColorTokens.PRIMARY)

                ForEach(exercise.sets, (setEntry: ActiveWorkoutSetEntry) => {
                  Column({ space: SpacingTokens.XS }) {
                    Row({ space: SpacingTokens.SM }) {
                      Text('第 ' + (setEntry.setIndex + 1).toString() + ' 组')
                        .fontSize(FontTokens.CAPTION_SIZE)
                        .fontColor(ColorTokens.TEXT_SECONDARY)

                      TextInput({ text: setEntry.weightText, placeholder: '重量kg' })
                        .type(InputType.Number)
                        .fontSize(FontTokens.CAPTION_SIZE)
                        .fontColor(ColorTokens.TEXT_PRIMARY)
                        .placeholderColor(ColorTokens.TEXT_DISABLED)
                        .backgroundColor(ColorTokens.SURFACE_ELEVATED)
                        .borderRadius(RadiusTokens.SM)
                        .height(TouchTokens.INPUT_HEIGHT)
                        .layoutWeight(1)
                        .onChange((value: string) => {
                          this.updateSetWeight(exercise, setEntry, value)
                        })

                      TextInput({ text: setEntry.repsText, placeholder: '次数' })
                        .type(InputType.Number)
                        .fontSize(FontTokens.CAPTION_SIZE)
                        .fontColor(ColorTokens.TEXT_PRIMARY)
                        .placeholderColor(ColorTokens.TEXT_DISABLED)
                        .backgroundColor(ColorTokens.SURFACE_ELEVATED)
                        .borderRadius(RadiusTokens.SM)
                        .height(TouchTokens.INPUT_HEIGHT)
                        .layoutWeight(1)
                        .onChange((value: string) => {
                          this.updateSetReps(exercise, setEntry, value)
                        })
                    }
                    .width('100%')

                    Text(setEntry.oneRepMaxText)
                      .fontSize(FontTokens.SMALL_SIZE)
                      .fontColor(setEntry.isComplete ? ColorTokens.ACCENT_LIGHT : ColorTokens.TEXT_SECONDARY)
                  }
                  .width('100%')
                }, (setEntry: ActiveWorkoutSetEntry) => this.createSetEntryRenderKey(setEntry))
              }
              .width('100%')
              .padding(SpacingTokens.MD)
              .borderRadius(RadiusTokens.SM)
              .backgroundColor(ColorTokens.SURFACE_PRIMARY)
            }, (exercise: ActiveWorkoutExercise) => this.createExerciseRenderKey(exercise))

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

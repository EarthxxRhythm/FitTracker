/**
 * ActiveWorkoutPage -- active workout execution.
 * Function #10: active workout execution.
 */
import { router } from '@kit.ArkUI'
import { AppRoutes } from '../../../app/AppRoutes'
import { AppButton } from '../../../components/AppButton'
import { AppCard } from '../../../components/AppCard'
import TrainingPlanService, { UserPlan } from '../../../common/services/TrainingPlanService'
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
      const flowSource: string = this.getRouteParam('flowSource')
      const currentPlan: UserPlan | null = await TrainingPlanService.getCurrentPlan(getContext(this))
      if (currentPlan !== null && flowSource !== 'goal_plan') {
        const preview: WorkoutPreviewSummary = WorkoutPreviewService.createPreviewForCurrentPlan(
          currentPlan,
          this.getDayIdParam(),
          TrainingPlanService.getTodayLabel(),
          TrainingPlanService.getTodayTraining(currentPlan)
        )
        const currentPlanState: ActiveWorkoutState = ActiveWorkoutService.createState(preview)
        this.applyState(currentPlanState)
        this.hasGoal = true
        this.loading = false
        return
      }

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

  getRouteParam(name: string): string {
    try {
      const params = router.getParams() as Record<string, string>
      if (name === 'flowSource' && params.flowSource !== undefined) {
        return params.flowSource
      }
    } catch (e) {
      return ''
    }
    return ''
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

  getPageSubtitle(): string {
    if (this.loading) {
      return '正在校准训练面板与当前动作'
    }
    if (!this.hasGoal) {
      return '先完成目标设定，再进入训练执行'
    }
    if (!this.hasWorkout) {
      return '当前没有可执行训练，请先调整目标或计划'
    }
    return '保持节奏，逐组记录，训练结束后进入复盘'
  }

  getCurrentExerciseIndexText(): string {
    if (this.exercises.length === 0) {
      return '0/0'
    }
    for (let index = 0; index < this.exercises.length; index++) {
      if (this.exercises[index].completedSets < this.exercises[index].targetSets) {
        return (index + 1).toString() + '/' + this.exercises.length.toString()
      }
    }
    return this.exercises.length.toString() + '/' + this.exercises.length.toString()
  }

  getSessionStatusText(): string {
    if (!this.hasWorkout) {
      return '待校准'
    }
    if (this.completedSets >= this.totalTargetSets && this.totalTargetSets > 0) {
      return '可收官'
    }
    return '进行中'
  }

  getSessionStatusColor(): string {
    if (!this.hasWorkout) {
      return ColorTokens.ACCENT_LIGHT
    }
    if (this.completedSets >= this.totalTargetSets && this.totalTargetSets > 0) {
      return ColorTokens.SUCCESS_LIGHT
    }
    return ColorTokens.PRIMARY_HOVER
  }

  getSessionStatusBackground(): string {
    if (!this.hasWorkout) {
      return ColorTokens.OVERLAY_ACCENT
    }
    if (this.completedSets >= this.totalTargetSets && this.totalTargetSets > 0) {
      return ColorTokens.OVERLAY_SUCCESS
    }
    return ColorTokens.OVERLAY_PRIMARY
  }

  getExerciseStatusText(exercise: ActiveWorkoutExercise): string {
    return exercise.completedSets.toString() + '/' + exercise.targetSets.toString() + ' 组'
  }

  getExerciseProgressWidth(exercise: ActiveWorkoutExercise): string {
    if (exercise.targetSets <= 0 || exercise.completedSets <= 0) {
      return '1%'
    }
    const percent: number = Math.floor((exercise.completedSets * 100) / exercise.targetSets)
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

  build() {
    Scroll() {
      Column({ space: SpacingTokens.LG }) {
        Column({ space: SpacingTokens.XS }) {
          Text('训练执行')
            .fontSize(FontTokens.MICRO_SIZE)
            .fontWeight(FontTokens.MICRO_WEIGHT)
            .fontColor(ColorTokens.TEXT_TERTIARY)

          Text('训练控制台')
            .fontSize(FontTokens.DISPLAY_SIZE)
            .fontWeight(FontTokens.DISPLAY_WEIGHT)
            .fontColor(ColorTokens.TEXT_PRIMARY)

          Text(this.getPageSubtitle())
            .fontSize(FontTokens.BODY_SIZE)
            .fontColor(ColorTokens.TEXT_SECONDARY)
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)

        if (!this.loading && !this.hasGoal) {
          AppCard({ variant: 'outlined', cardPadding: 'default' }) {
            Column({ space: SpacingTokens.MD }) {
              Text('还没有训练目标')
                .fontSize(FontTokens.TITLE_SIZE)
                .fontWeight(FontWeight.Bold)
                .fontColor(ColorTokens.TEXT_PRIMARY)

              Text('先完成目标设置，再开始今天的训练执行。')
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
          }
        }

        if (!this.loading && this.hasGoal && !this.hasWorkout) {
          AppCard({ variant: 'outlined', cardPadding: 'default' }) {
            Column({ space: SpacingTokens.MD }) {
              Text('今天没有可执行训练')
                .fontSize(FontTokens.TITLE_SIZE)
                .fontWeight(FontWeight.Bold)
                .fontColor(ColorTokens.TEXT_PRIMARY)

              Text('当前计划没有匹配到动作，可以返回目标设置调整器械与安排。')
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
          }
        }

        if (!this.loading && this.hasGoal && this.hasWorkout) {
          Column({ space: SpacingTokens.MD }) {
            AppCard({ variant: 'panel', cardPadding: 'default' }) {
              Column({ space: SpacingTokens.MD }) {
                Row() {
                  Column({ space: SpacingTokens.XS }) {
                    Text(this.title)
                      .fontSize(FontTokens.HEADLINE_SIZE)
                      .fontWeight(FontWeight.Bold)
                      .fontColor(ColorTokens.TEXT_PRIMARY)

                    Text('当前第 ' + this.getCurrentExerciseIndexText() + ' 个动作')
                      .fontSize(FontTokens.CAPTION_SIZE)
                      .fontColor(ColorTokens.TEXT_TERTIARY)
                  }
                  .layoutWeight(1)
                  .alignItems(HorizontalAlign.Start)

                  Text(this.getSessionStatusText())
                    .fontSize(FontTokens.SMALL_SIZE)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(this.getSessionStatusColor())
                    .padding({
                      top: SpacingTokens.XS,
                      bottom: SpacingTokens.XS,
                      left: SpacingTokens.SM,
                      right: SpacingTokens.SM
                    })
                    .backgroundColor(this.getSessionStatusBackground())
                    .borderRadius(RadiusTokens.FULL)
                }
                .width('100%')

                Row({ space: SpacingTokens.SM }) {
                  Column({ space: SpacingTokens.XS }) {
                    Text('训练计时')
                      .fontSize(FontTokens.MICRO_SIZE)
                      .fontWeight(FontTokens.MICRO_WEIGHT)
                      .fontColor(ColorTokens.TEXT_TERTIARY)

                    Text(this.getElapsedText())
                      .fontSize(FontTokens.HERO_SIZE)
                      .fontWeight(FontWeight.Bold)
                      .fontColor(ColorTokens.TEXT_PRIMARY)
                  }
                  .layoutWeight(1)
                  .padding(SpacingTokens.MD)
                  .backgroundColor(ColorTokens.SURFACE_SECONDARY)
                  .borderRadius(RadiusTokens.MD)
                  .alignItems(HorizontalAlign.Start)

                  Column({ space: SpacingTokens.XS }) {
                    Text('完成组数')
                      .fontSize(FontTokens.MICRO_SIZE)
                      .fontWeight(FontTokens.MICRO_WEIGHT)
                      .fontColor(ColorTokens.TEXT_TERTIARY)

                    Text(this.getProgressText())
                      .fontSize(FontTokens.TITLE_SIZE)
                      .fontWeight(FontWeight.Bold)
                      .fontColor(ColorTokens.DATA_HIGHLIGHT)
                  }
                  .layoutWeight(1)
                  .padding(SpacingTokens.MD)
                  .backgroundColor(ColorTokens.SURFACE_SECONDARY)
                  .borderRadius(RadiusTokens.MD)
                  .alignItems(HorizontalAlign.Start)
                }
                .width('100%')

                Column({ space: SpacingTokens.XS }) {
                  Text('当前动作')
                    .fontSize(FontTokens.MICRO_SIZE)
                    .fontWeight(FontTokens.MICRO_WEIGHT)
                    .fontColor(ColorTokens.TEXT_TERTIARY)

                  Text(this.currentExerciseName)
                    .fontSize(FontTokens.TITLE_SIZE)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(ColorTokens.TEXT_PRIMARY)
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })

                  Text(this.currentExerciseSetProgress)
                    .fontSize(FontTokens.CAPTION_SIZE)
                    .fontColor(ColorTokens.PRIMARY_HOVER)
                }
                .width('100%')
                .padding(SpacingTokens.MD)
                .backgroundColor(ColorTokens.SURFACE_SECONDARY)
                .borderRadius(RadiusTokens.MD)

                Row() {
                  Text(this.getDayBadgeText())
                    .fontSize(FontTokens.SMALL_SIZE)
                    .fontColor(ColorTokens.ACCENT_LIGHT)
                    .padding({
                      top: SpacingTokens.XS,
                      bottom: SpacingTokens.XS,
                      left: SpacingTokens.SM,
                      right: SpacingTokens.SM
                    })
                    .backgroundColor(ColorTokens.OVERLAY_ACCENT)
                    .borderRadius(RadiusTokens.FULL)

                  Text(this.getProgressText())
                    .fontSize(FontTokens.SMALL_SIZE)
                    .fontColor(ColorTokens.TEXT_TERTIARY)
                    .margin({ left: SpacingTokens.SM })
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
                    .backgroundColor(ColorTokens.DATA_HIGHLIGHT)
                    .borderRadius(RadiusTokens.FULL)
                }
                .width('100%')
                .height(TouchTokens.PROGRESS_BAR_HEIGHT)
              }
              .width('100%')
            }

            ForEach(this.exercises, (exercise: ActiveWorkoutExercise, index: number) => {
              AppCard({ variant: 'outlined', cardPadding: 'default' }) {
                Column({ space: SpacingTokens.SM }) {
                  Row() {
                    Text((index + 1).toString())
                      .fontSize(FontTokens.SMALL_SIZE)
                      .fontWeight(FontWeight.Medium)
                      .fontColor(ColorTokens.DATA_HIGHLIGHT)
                      .width(26)
                      .height(26)
                      .textAlign(TextAlign.Center)
                      .backgroundColor(ColorTokens.DATA_HIGHLIGHT_BG)
                      .borderRadius(RadiusTokens.FULL)

                    Column({ space: SpacingTokens.XXXS }) {
                      Text(exercise.name)
                        .fontSize(FontTokens.BODY_SIZE)
                        .fontWeight(FontWeight.Medium)
                        .fontColor(ColorTokens.TEXT_PRIMARY)

                      Text(exercise.targetSets.toString() + ' 组 x ' + exercise.targetReps + ' | ' + exercise.intensityNote)
                        .fontSize(FontTokens.CAPTION_SIZE)
                        .fontColor(ColorTokens.TEXT_SECONDARY)
                        .maxLines(1)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                    }
                    .layoutWeight(1)
                    .alignItems(HorizontalAlign.Start)
                    .margin({ left: SpacingTokens.SM })

                    Text(this.getExerciseStatusText(exercise))
                      .fontSize(FontTokens.SMALL_SIZE)
                      .fontColor(exercise.completedSets > 0 ? ColorTokens.PRIMARY_HOVER : ColorTokens.TEXT_TERTIARY)
                  }
                  .width('100%')

                  Stack({ alignContent: Alignment.Start }) {
                    Row()
                      .width('100%')
                      .height(6)
                      .backgroundColor(ColorTokens.SURFACE_ELEVATED)
                      .borderRadius(RadiusTokens.FULL)

                    Row()
                      .width(this.getExerciseProgressWidth(exercise))
                      .height(6)
                      .backgroundColor(ColorTokens.PRIMARY)
                      .borderRadius(RadiusTokens.FULL)
                  }
                  .width('100%')
                  .height(6)

                  ForEach(exercise.sets, (setEntry: ActiveWorkoutSetEntry) => {
                    Column({ space: SpacingTokens.XS }) {
                      Row({ space: SpacingTokens.SM }) {
                        Text('第 ' + (setEntry.setIndex + 1).toString() + ' 组')
                          .fontSize(FontTokens.CAPTION_SIZE)
                          .fontColor(ColorTokens.TEXT_SECONDARY)
                          .width(44)

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
              }
            }, (exercise: ActiveWorkoutExercise) => this.createExerciseRenderKey(exercise))

            Column({ space: SpacingTokens.SM }) {
              AppButton({
                text: '保存当前进度',
                type: 'primary',
                buttonSize: 'large',
                block: true,
                disabled: this.completedSets <= 0,
                onButtonClick: () => {
                  this.finishCurrentProgress()
                }
              })

              AppButton({
                text: '完成全部并保存',
                type: 'secondary',
                buttonSize: 'large',
                block: true,
                onButtonClick: () => {
                  this.finishAllSets()
                }
              })
            }
            .width('100%')
          }
          .width('100%')
        }
      }
      .width('100%')
      .padding({
        left: SpacingTokens.MD,
        right: SpacingTokens.MD,
        top: SpacingTokens.LG,
        bottom: SpacingTokens.XL
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ColorTokens.BG_PRIMARY)
    .scrollBar(BarState.Off)
  }
}

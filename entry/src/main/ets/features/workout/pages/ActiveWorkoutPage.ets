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
import WorkoutSessionPersistenceBridgeService from '../services/WorkoutSessionPersistenceBridgeService'

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

  async finishCurrentProgress(): Promise<void> {
    await this.saveWorkout(this.exercises, this.completedSets)
  }

  async finishAllSets(): Promise<void> {
    const completedExercises: ActiveWorkoutExercise[] = ActiveWorkoutService.markAllComplete(this.exercises)
    const completedSets: number = ActiveWorkoutService.countCompletedSets(completedExercises)
    this.exercises = completedExercises
    this.completedSets = completedSets
    await this.saveWorkout(completedExercises, completedSets)
  }

  async saveWorkout(exercises: ActiveWorkoutExercise[], completedSets: number): Promise<void> {
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
    try {
      await WorkoutSessionPersistenceBridgeService.persistActiveWorkoutCompletion(getContext(this), session)
    } catch (e) {
      WorkoutRepository.saveSession(session)
    }
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
    return this.completedSets.toString() + '/' + this.totalTargetSets.toString() + ' \u7ec4'
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
      return '\u6b63\u5728\u6821\u51c6\u8bad\u7ec3\u9762\u677f\u4e0e\u5f53\u524d\u52a8\u4f5c'
    }
    if (!this.hasGoal) {
      return '\u5148\u5b8c\u6210\u76ee\u6807\u8bbe\u5b9a\uff0c\u518d\u8fdb\u5165\u8bad\u7ec3\u6267\u884c'
    }
    if (!this.hasWorkout) {
      return '\u5f53\u524d\u6ca1\u6709\u53ef\u6267\u884c\u8bad\u7ec3\uff0c\u8bf7\u5148\u8c03\u6574\u76ee\u6807\u6216\u8ba1\u5212'
    }
    return '\u4fdd\u6301\u8282\u594f\uff0c\u9010\u7ec4\u8bb0\u5f55\uff0c\u8bad\u7ec3\u7ed3\u675f\u540e\u8fdb\u5165\u590d\u76d8'
  }

  getHeroEyebrow(): string {
    if (this.loading) {
      return '\u6b63\u5728\u51c6\u5907'
    }
    if (!this.hasGoal) {
      return '\u8bad\u7ec3\u6267\u884c'
    }
    if (!this.hasWorkout) {
      return '\u4eca\u65e5\u8c03\u6574'
    }
    return '\u8bad\u7ec3\u8fdb\u884c\u4e2d'
  }

  getHeroTitle(): string {
    if (this.loading) {
      return '\u8bad\u7ec3\u63a7\u5236\u53f0'
    }
    if (!this.hasGoal) {
      return '\u5148\u8bbe\u5b9a\u4eca\u65e5\u8bad\u7ec3'
    }
    if (!this.hasWorkout) {
      return '\u4eca\u5929\u6682\u65e0\u53ef\u6267\u884c\u52a8\u4f5c'
    }
    return this.title
  }

  getHeroDescription(): string {
    if (this.loading) {
      return '\u6b63\u5728\u8bfb\u53d6\u4eca\u65e5\u8bad\u7ec3\u5b89\u6392\u3001\u8fdb\u5ea6\u548c\u5f53\u524d\u52a8\u4f5c\u3002'
    }
    if (!this.hasGoal) {
      return '\u5b8c\u6210\u76ee\u6807\u8bbe\u7f6e\u540e\uff0c\u7cfb\u7edf\u624d\u4f1a\u751f\u6210\u8bad\u7ec3\u6267\u884c\u9762\u677f\u3002'
    }
    if (!this.hasWorkout) {
      return '\u5f53\u524d\u8ba1\u5212\u6ca1\u6709\u5339\u914d\u5230\u53ef\u6267\u884c\u52a8\u4f5c\uff0c\u53ef\u4ee5\u8fd4\u56de\u8c03\u6574\u76ee\u6807\u4e0e\u5668\u68b0\u8303\u56f4\u3002'
    }
    return '\u5f53\u524d\u91cd\u70b9\uff1a' + this.getCurrentExerciseNameText() + ' | ' +
      this.getCurrentExerciseGuidanceText()
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

  getCurrentExerciseNameText(): string {
    if (this.currentExerciseName.length > 0) {
      return this.currentExerciseName
    }
    if (this.completedSets >= this.totalTargetSets && this.totalTargetSets > 0) {
      return '\u5168\u90e8\u52a8\u4f5c\u5df2\u5b8c\u6210'
    }
    return '\u6b63\u5728\u8bfb\u53d6\u5f53\u524d\u52a8\u4f5c'
  }

  getCurrentExerciseGuidanceText(): string {
    if (this.currentExerciseSetProgress.length > 0) {
      return this.currentExerciseSetProgress
    }
    if (this.completedSets >= this.totalTargetSets && this.totalTargetSets > 0) {
      return '\u53ef\u4ee5\u76f4\u63a5\u4fdd\u5b58\u672c\u6b21\u8bad\u7ec3'
    }
    return '\u4ece\u7b2c\u4e00\u7ec4\u5f00\u59cb\u8bb0\u5f55'
  }

  getSessionStatusText(): string {
    if (!this.hasWorkout) {
      return '\u5f85\u6821\u51c6'
    }
    if (this.completedSets >= this.totalTargetSets && this.totalTargetSets > 0) {
      return '\u53ef\u6536\u5b98'
    }
    return '\u8fdb\u884c\u4e2d'
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
    return exercise.completedSets.toString() + '/' + exercise.targetSets.toString() + ' \u7ec4'
  }

  getExerciseProgressWidth(exercise: ActiveWorkoutExercise): string {
    if (exercise.targetSets <= 0 || exercise.completedSets <= 0) {
      return '1%'
    }
    const percent: number = Math.floor((exercise.completedSets * 100) / exercise.targetSets)
    return percent.toString() + '%'
  }

  getExerciseSectionTitle(): string {
    return '\u9010\u7ec4\u8bb0\u5f55'
  }

  getExerciseSectionSubtitle(): string {
    if (this.completedSets >= this.totalTargetSets && this.totalTargetSets > 0) {
      return '\u6240\u6709\u52a8\u4f5c\u5df2\u5230\u6536\u5c3e\u9636\u6bb5\uff0c\u786e\u8ba4\u6570\u636e\u540e\u53ef\u76f4\u63a5\u4fdd\u5b58\u3002'
    }
    return '\u4f18\u5148\u586b\u5199\u91cd\u91cf\u4e0e\u6b21\u6570\uff0c\u987a\u5e8f\u5b8c\u6210\u5404\u7ec4\u8bb0\u5f55\u3002'
  }

  getExercisePrescriptionText(exercise: ActiveWorkoutExercise): string {
    return exercise.targetSets.toString() + ' \u7ec4 x ' + exercise.targetReps + ' \u6b21 | ' + exercise.intensityNote
  }

  getSetLabelText(setEntry: ActiveWorkoutSetEntry): string {
    return '\u7b2c ' + (setEntry.setIndex + 1).toString() + ' \u7ec4'
  }

  getWeightPlaceholderText(): string {
    return '\u91cd\u91cf kg'
  }

  getRepsPlaceholderText(): string {
    return '\u6b21\u6570'
  }

  getSaveSectionTitle(): string {
    if (this.completedSets >= this.totalTargetSets && this.totalTargetSets > 0) {
      return '\u8bad\u7ec3\u5b8c\u6210'
    }
    return '\u8bad\u7ec3\u6536\u53e3'
  }

  getSaveSectionSubtitle(): string {
    if (this.completedSets <= 0) {
      return '\u81f3\u5c11\u5b8c\u6210\u4e00\u7ec4\u540e\u624d\u53ef\u4fdd\u5b58\u672c\u6b21\u8fdb\u5ea6\u3002'
    }
    if (this.completedSets >= this.totalTargetSets && this.totalTargetSets > 0) {
      return '\u672c\u6b21\u8bad\u7ec3\u5df2\u8fbe\u5230\u76ee\u6807\u7ec4\u6570\uff0c\u53ef\u4ee5\u76f4\u63a5\u5b8c\u6210\u5e76\u8fdb\u5165\u590d\u76d8\u3002'
    }
    return '\u53ef\u5148\u4fdd\u5b58\u5f53\u524d\u8fdb\u5ea6\uff0c\u4e5f\u53ef\u76f4\u63a5\u8865\u5168\u5168\u90e8\u76ee\u6807\u7ec4\u6570\u540e\u4fdd\u5b58\u3002'
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
      return '\u7b2c ' + this.dayId.substring('current_plan_day_'.length) + ' \u5929'
    }
    if (this.dayId.indexOf('day_') === 0) {
      return '\u7b2c ' + this.dayId.substring('day_'.length) + ' \u5929'
    }
    if (this.dayId.length > 0) {
      return this.dayId
    }
    return this.title
  }

  build() {
    Scroll() {
      Column({ space: SpacingTokens.LG }) {
        AppCard({ variant: 'panel', cardPadding: 'default' }) {
          Column({ space: SpacingTokens.SM }) {
            Text(this.getHeroEyebrow())
              .fontSize(FontTokens.MICRO_SIZE)
              .fontWeight(FontTokens.MICRO_WEIGHT)
              .fontColor(ColorTokens.TEXT_TERTIARY)

            Text(this.getHeroTitle())
              .fontSize(FontTokens.DISPLAY_SIZE)
              .fontWeight(FontTokens.DISPLAY_WEIGHT)
              .fontColor(ColorTokens.TEXT_PRIMARY)

            Text(this.getHeroDescription())
              .fontSize(FontTokens.BODY_SIZE)
              .fontColor(ColorTokens.TEXT_SECONDARY)
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
        }

        if (!this.loading && !this.hasGoal) {
          AppCard({ variant: 'outlined', cardPadding: 'default' }) {
            Column({ space: SpacingTokens.MD }) {
              Text('\u8fd8\u6ca1\u6709\u8bad\u7ec3\u76ee\u6807')
                .fontSize(FontTokens.TITLE_SIZE)
                .fontWeight(FontWeight.Bold)
                .fontColor(ColorTokens.TEXT_PRIMARY)

              Text('\u5148\u5b8c\u6210\u76ee\u6807\u8bbe\u7f6e\uff0c\u518d\u5f00\u59cb\u4eca\u5929\u7684\u8bad\u7ec3\u6267\u884c\u3002')
                .fontSize(FontTokens.BODY_SIZE)
                .fontColor(ColorTokens.TEXT_SECONDARY)

              AppButton({
                text: '\u8bbe\u7f6e\u8bad\u7ec3\u76ee\u6807',
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
              Text('\u4eca\u5929\u6ca1\u6709\u53ef\u6267\u884c\u8bad\u7ec3')
                .fontSize(FontTokens.TITLE_SIZE)
                .fontWeight(FontWeight.Bold)
                .fontColor(ColorTokens.TEXT_PRIMARY)

              Text('\u5f53\u524d\u8ba1\u5212\u6ca1\u6709\u5339\u914d\u5230\u52a8\u4f5c\uff0c\u53ef\u4ee5\u8fd4\u56de\u76ee\u6807\u8bbe\u7f6e\u8c03\u6574\u5668\u68b0\u4e0e\u5b89\u6392\u3002')
                .fontSize(FontTokens.BODY_SIZE)
                .fontColor(ColorTokens.TEXT_SECONDARY)

              AppButton({
                text: '\u8c03\u6574\u76ee\u6807',
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
                    Text('\u5f53\u524d\u6267\u884c')
                      .fontSize(FontTokens.MICRO_SIZE)
                      .fontWeight(FontTokens.MICRO_WEIGHT)
                      .fontColor(ColorTokens.TEXT_TERTIARY)

                    Text(this.title)
                      .fontSize(FontTokens.HEADLINE_SIZE)
                      .fontWeight(FontWeight.Bold)
                      .fontColor(ColorTokens.TEXT_PRIMARY)

                    Text('\u7b2c ' + this.getCurrentExerciseIndexText() + ' \u4e2a\u52a8\u4f5c')
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

                Column({ space: SpacingTokens.XS }) {
                  Text('\u5f53\u524d\u52a8\u4f5c')
                    .fontSize(FontTokens.MICRO_SIZE)
                    .fontWeight(FontTokens.MICRO_WEIGHT)
                    .fontColor(ColorTokens.TEXT_TERTIARY)

                  Text(this.getCurrentExerciseNameText())
                    .fontSize(FontTokens.TITLE_SIZE)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(ColorTokens.TEXT_PRIMARY)
                    .maxLines(2)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })

                  Text(this.getCurrentExerciseGuidanceText())
                    .fontSize(FontTokens.CAPTION_SIZE)
                    .fontColor(ColorTokens.PRIMARY_HOVER)
                }
                .width('100%')
                .padding(SpacingTokens.MD)
                .backgroundColor(ColorTokens.SURFACE_SECONDARY)
                .borderRadius(RadiusTokens.MD)
                .alignItems(HorizontalAlign.Start)

                Row({ space: SpacingTokens.SM }) {
                  Column({ space: SpacingTokens.XS }) {
                    Text('\u8bad\u7ec3\u8ba1\u65f6')
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
                  .border({ width: 1, color: ColorTokens.BORDER_SUBTLE })
                  .alignItems(HorizontalAlign.Start)

                  Column({ space: SpacingTokens.XS }) {
                    Text('\u5b8c\u6210\u7ec4\u6570')
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
                  .border({ width: 1, color: ColorTokens.BORDER_SUBTLE })
                  .alignItems(HorizontalAlign.Start)
                }
                .width('100%')

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
              .alignItems(HorizontalAlign.Start)
            }

            Column({ space: SpacingTokens.XS }) {
              Text(this.getExerciseSectionTitle())
                .fontSize(FontTokens.TITLE_SIZE)
                .fontWeight(FontWeight.Bold)
                .fontColor(ColorTokens.TEXT_PRIMARY)

              Text(this.getExerciseSectionSubtitle())
                .fontSize(FontTokens.SMALL_SIZE)
                .fontColor(ColorTokens.TEXT_TERTIARY)
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)

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

                      Text(this.getExercisePrescriptionText(exercise))
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
                        Text(this.getSetLabelText(setEntry))
                          .fontSize(FontTokens.CAPTION_SIZE)
                          .fontColor(ColorTokens.TEXT_SECONDARY)
                          .width(52)

                        TextInput({ text: setEntry.weightText, placeholder: this.getWeightPlaceholderText() })
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

                        TextInput({ text: setEntry.repsText, placeholder: this.getRepsPlaceholderText() })
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
                    .padding(SpacingTokens.SM)
                    .backgroundColor(ColorTokens.SURFACE_PRIMARY)
                    .borderRadius(RadiusTokens.MD)
                    .border({ width: 1, color: ColorTokens.BORDER_SUBTLE })
                  }, (setEntry: ActiveWorkoutSetEntry) => this.createSetEntryRenderKey(setEntry))
                }
                .width('100%')
                .alignItems(HorizontalAlign.Start)
              }
            }, (exercise: ActiveWorkoutExercise) => this.createExerciseRenderKey(exercise))

            AppCard({ variant: 'panel', cardPadding: 'default' }) {
              Column({ space: SpacingTokens.SM }) {
                Text(this.getSaveSectionTitle())
                  .fontSize(FontTokens.TITLE_SIZE)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(ColorTokens.TEXT_PRIMARY)

                Text(this.getSaveSectionSubtitle())
                  .fontSize(FontTokens.SMALL_SIZE)
                  .fontColor(ColorTokens.TEXT_TERTIARY)

                AppButton({
                  text: '\u4fdd\u5b58\u5f53\u524d\u8fdb\u5ea6',
                  type: 'primary',
                  buttonSize: 'large',
                  block: true,
                  disabled: this.completedSets <= 0,
                  onButtonClick: () => {
                    this.finishCurrentProgress()
                  }
                })

                AppButton({
                  text: '\u5b8c\u6210\u5168\u90e8\u5e76\u4fdd\u5b58',
                  type: 'secondary',
                  buttonSize: 'large',
                  block: true,
                  onButtonClick: () => {
                    this.finishAllSets()
                  }
                })
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)
            }
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

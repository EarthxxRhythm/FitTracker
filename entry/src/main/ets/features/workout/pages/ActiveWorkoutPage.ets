/**
 * ActiveWorkoutPage -- active workout execution.
 * Function #10: active workout execution.
 */
import { Context } from '@kit.AbilityKit'
import { AppRoutes } from '../../../app/AppRoutes'
import { AppButton } from '../../../components/AppButton'
import { AppCard } from '../../../components/AppCard'
import { createStageRailItem, StageRail, StageRailItem } from '../../../components/StageRail'
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
import TrainingDayLabelService from '../../../shared/services/TrainingDayLabelService'
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
  @State savingWorkout: boolean = false
  @State saveStatusText: string = ''
  @State saveStatusTone: string = 'info'
  private timerId: number = -1

  private getHostContextOrNull(): Context | null {
    const hostContext = this.getUIContext().getHostContext()
    if (hostContext === undefined || hostContext === null) {
      return null
    }
    return hostContext as Context
  }

  async aboutToAppear(): Promise<void> {
    this.loading = true
    this.startedAt = Date.now()
    this.startTimer()
    try {
      const flowSource: string = this.getRouteParam('flowSource')
      const context: Context | null = this.getHostContextOrNull()
      if (context === null) {
        this.hasGoal = false
        this.hasWorkout = false
        this.loading = false
        return
      }
      const currentPlan: UserPlan | null = await TrainingPlanService.getCurrentPlan(context)
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

      const goal: UserGoal | undefined = await GoalRepository.loadGoal(context)
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
      const params = this.getUIContext().getRouter().getParams() as Record<string, string>
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
      const params = this.getUIContext().getRouter().getParams() as Record<string, string>
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

  toggleSetWarmup(exercise: ActiveWorkoutExercise, setEntry: ActiveWorkoutSetEntry, isWarmup: boolean): void {
    const nextExercises: ActiveWorkoutExercise[] = ActiveWorkoutService.updateSetWarmup(
      this.exercises,
      exercise.plannedExerciseId,
      setEntry.setIndex,
      isWarmup
    )
    this.applyProgressExercises(nextExercises)
  }

  addSetEntry(exercise: ActiveWorkoutExercise): void {
    const nextExercises: ActiveWorkoutExercise[] = ActiveWorkoutService.addSetEntry(
      this.exercises,
      exercise.plannedExerciseId
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
    await this.saveWorkout(this.exercises)
  }

  async finishWorkout(): Promise<void> {
    await this.saveWorkout(this.exercises)
  }

  async saveWorkout(exercises: ActiveWorkoutExercise[]): Promise<void> {
    if (!this.hasWorkout || this.savingWorkout) {
      return
    }

    this.savingWorkout = true
    this.saveStatusText = '正在保存本次训练记录...'
    this.saveStatusTone = 'info'
    const endedAt: number = Date.now()
    const completedSets: number = ActiveWorkoutService.countCompletedSets(exercises)
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
    if (session.sets.length <= 0) {
      this.saveStatusText = '至少录入一组重量或次数后，才能结束训练。'
      this.saveStatusTone = 'warning'
      this.savingWorkout = false
      return
    }
    let persistedToDevice: boolean = true
    try {
      const context: Context | null = this.getHostContextOrNull()
      if (context !== null) {
        await WorkoutSessionPersistenceBridgeService.persistActiveWorkoutCompletion(context, session)
      } else {
        persistedToDevice = false
        WorkoutRepository.saveSession(session)
      }
    } catch (e) {
      persistedToDevice = false
      WorkoutRepository.saveSession(session)
    }
    this.saveStatusText = persistedToDevice ? '训练记录已保存，正在进入复盘。' : '训练记录已保存到本地缓存，旧持久层同步稍后再试。'
    this.saveStatusTone = persistedToDevice ? 'success' : 'warning'
    this.savingWorkout = false
    this.openSummary(sessionId)
  }

  getRecordedSetCount(): number {
    return ActiveWorkoutService.countRecordedSets(this.exercises)
  }

  openGoalSetup(): void {
    try {
      this.getUIContext().getRouter().replaceUrl({ url: AppRoutes.GOAL_SETUP })
    } catch (e) {
      // stay on active workout
    }
  }

  openSummary(sessionId: string): void {
    try {
      this.getUIContext().getRouter().replaceUrl({ url: AppRoutes.WORKOUT_COMPLETE, params: { sessionId: sessionId } })
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
      return '\u6b63\u5f0f\u7ec4\u76ee\u6807\u5df2\u5b8c\u6210\uff0c\u786e\u8ba4\u6570\u636e\u540e\u53ef\u76f4\u63a5\u7ed3\u675f\u8bad\u7ec3\u3002'
    }
    return '\u70ed\u8eab\u7ec4\u4f1a\u4fdd\u5b58\uff0c\u4f46\u4e0d\u8ba1\u5165\u5b8c\u6210\u7387\u3001PR \u548c\u8bad\u7ec3\u91cf\u3002'
  }

  getExercisePrescriptionText(exercise: ActiveWorkoutExercise): string {
    return '\u76ee\u6807 ' + exercise.targetSets.toString() + ' \u7ec4 x ' + exercise.targetReps + ' \u6b21 | ' +
      exercise.intensityNote
  }

  getSetLabelText(setEntry: ActiveWorkoutSetEntry): string {
    return '第 ' + (setEntry.setIndex + 1).toString() + ' 组'
  }

  isCurrentExercise(exercise: ActiveWorkoutExercise): boolean {
    for (let index = 0; index < this.exercises.length; index++) {
      const currentExercise: ActiveWorkoutExercise = this.exercises[index]
      if (currentExercise.completedSets < currentExercise.targetSets) {
        return currentExercise.plannedExerciseId === exercise.plannedExerciseId
      }
    }
    return false
  }

  getCurrentInputSetIndex(exercise: ActiveWorkoutExercise): number {
    for (let index = 0; index < exercise.sets.length; index++) {
      if (!exercise.sets[index].isComplete) {
        return exercise.sets[index].setIndex
      }
    }
    return -1
  }

  isCurrentSetEntry(exercise: ActiveWorkoutExercise, setEntry: ActiveWorkoutSetEntry): boolean {
    if (!this.isCurrentExercise(exercise)) {
      return false
    }
    if (setEntry.isComplete) {
      return false
    }
    return setEntry.setIndex === this.getCurrentInputSetIndex(exercise)
  }

  getSetKindText(setEntry: ActiveWorkoutSetEntry): string {
    if (setEntry.isWarmup) {
      return '\u70ed\u8eab'
    }
    return '\u6b63\u5f0f'
  }

  getSetKindTextColor(setEntry: ActiveWorkoutSetEntry): string {
    if (setEntry.isWarmup) {
      return ColorTokens.ACCENT_GOLD
    }
    return ColorTokens.PRIMARY_HOVER
  }

  getSetKindBackgroundColor(setEntry: ActiveWorkoutSetEntry): string {
    if (setEntry.isWarmup) {
      return ColorTokens.WARNING_BG
    }
    return ColorTokens.OVERLAY_PRIMARY
  }

  getSetKindBorderColor(setEntry: ActiveWorkoutSetEntry): string {
    if (setEntry.isWarmup) {
      return ColorTokens.WARNING
    }
    return ColorTokens.BORDER_ACCENT
  }

  getSetAnalysisLabel(setEntry: ActiveWorkoutSetEntry): string {
    if (setEntry.isWarmup) {
      return '\u7ec4\u522b\u8bf4\u660e'
    }
    return '\u53c2\u8003 1RM'
  }

  getSetAnalysisText(setEntry: ActiveWorkoutSetEntry): string {
    return setEntry.oneRepMaxText
  }

  countExerciseRecordedSets(exercise: ActiveWorkoutExercise): number {
    let count: number = 0
    for (let index = 0; index < exercise.sets.length; index++) {
      if (exercise.sets[index].isComplete) {
        count++
      }
    }
    return count
  }

  getSetEntryStatusText(exercise: ActiveWorkoutExercise, setEntry: ActiveWorkoutSetEntry): string {
    if (setEntry.isComplete) {
      if (setEntry.isWarmup) {
        return '\u70ed\u8eab\u5df2\u8bb0\u5f55'
      }
      return '\u5df2\u8bb0\u5f55'
    }
    if (this.isCurrentSetEntry(exercise, setEntry)) {
      return '\u5f53\u524d\u5f55\u5165'
    }
    if (setEntry.isWarmup) {
      return '\u5f85\u5f55\u5165\u70ed\u8eab'
    }
    return '\u5f85\u5f55\u5165'
  }

  getSetEntryStatusColor(exercise: ActiveWorkoutExercise, setEntry: ActiveWorkoutSetEntry): string {
    if (setEntry.isComplete) {
      return ColorTokens.SUCCESS_LIGHT
    }
    if (this.isCurrentSetEntry(exercise, setEntry)) {
      return ColorTokens.TEXT_ON_PRIMARY
    }
    return ColorTokens.TEXT_SECONDARY
  }

  getSetEntryStatusBackgroundColor(exercise: ActiveWorkoutExercise, setEntry: ActiveWorkoutSetEntry): string {
    if (setEntry.isComplete) {
      return ColorTokens.OVERLAY_SUCCESS
    }
    if (this.isCurrentSetEntry(exercise, setEntry)) {
      return ColorTokens.PRIMARY
    }
    return ColorTokens.SURFACE_SECONDARY
  }

  getSetEntryBackgroundColor(exercise: ActiveWorkoutExercise, setEntry: ActiveWorkoutSetEntry): string {
    if (setEntry.isComplete) {
      return ColorTokens.SURFACE_PRIMARY
    }
    if (this.isCurrentSetEntry(exercise, setEntry)) {
      return ColorTokens.SURFACE_STRONG
    }
    return ColorTokens.SURFACE_SECONDARY
  }

  getSetEntryBorderColor(exercise: ActiveWorkoutExercise, setEntry: ActiveWorkoutSetEntry): string {
    if (setEntry.isComplete) {
      return ColorTokens.BORDER_SUBTLE
    }
    if (this.isCurrentSetEntry(exercise, setEntry)) {
      return ColorTokens.BORDER_ACCENT
    }
    return ColorTokens.BORDER_DEFAULT
  }

  getSetInputBackgroundColor(exercise: ActiveWorkoutExercise, setEntry: ActiveWorkoutSetEntry): string {
    if (this.isCurrentSetEntry(exercise, setEntry)) {
      return ColorTokens.SURFACE_INPUT
    }
    return ColorTokens.BG_ELEVATED
  }

  getSetInputBorderColor(exercise: ActiveWorkoutExercise, setEntry: ActiveWorkoutSetEntry): string {
    if (setEntry.isComplete) {
      return ColorTokens.BORDER_ACCENT
    }
    if (this.isCurrentSetEntry(exercise, setEntry)) {
      return ColorTokens.ACCENT_PRIMARY
    }
    return ColorTokens.BORDER_SUBTLE
  }

  getWeightPlaceholderText(): string {
    return '\u91cd\u91cf kg'
  }

  getRepsPlaceholderText(): string {
    return '\u6b21\u6570'
  }

  getSaveSectionTitle(): string {
    if (this.completedSets >= this.totalTargetSets && this.totalTargetSets > 0) {
      return '\u672c\u6b21\u53ef\u6536\u53e3'
    }
    return '\u6309\u5b9e\u9645\u8bb0\u5f55\u4fdd\u5b58'
  }

  getSaveSectionSubtitle(): string {
    const recordedSetCount: number = this.getRecordedSetCount()
    if (recordedSetCount <= 0) {
      return '\u81f3\u5c11\u5f55\u5165\u4e00\u7ec4\u6570\u636e\u540e\u624d\u53ef\u7ed3\u675f\u8bad\u7ec3\u3002'
    }
    if (this.completedSets >= this.totalTargetSets && this.totalTargetSets > 0) {
      return '\u5c06\u6309\u5df2\u5f55\u5165\u6570\u636e\u4fdd\u5b58\u672c\u6b21\u4f1a\u8bdd\uff0c\u70ed\u8eab\u7ec4\u4e5f\u4f1a\u968f\u4f1a\u8bdd\u4e00\u8d77\u843d\u5e93\u3002'
    }
    return '\u5f53\u524d\u5df2\u8bb0\u5f55 ' + recordedSetCount.toString() + ' \u7ec4\uff0c\u5176\u4e2d\u6b63\u5f0f\u7ec4 ' +
      this.completedSets.toString() + ' / ' + this.totalTargetSets.toString() + ' \u7ec4\u3002'
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
        isWarmup: entry.isWarmup,
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
      setEntry.oneRepMaxText + '_' + (setEntry.isWarmup ? 'warmup' : 'working')
  }

  getStageRailItems(): StageRailItem[] {
    const items: StageRailItem[] = []
    items.push(createStageRailItem('\u786e\u8ba4', false, false))
    items.push(createStageRailItem('\u6267\u884c', true, false))
    items.push(createStageRailItem('\u603b\u7ed3', false, false))
    return items
  }

  @Builder
  buildSessionMetricTile(label: string, value: string, note: string, accentColor: string) {
    Column({ space: SpacingTokens.XS }) {
      Text(label)
        .fontSize(FontTokens.SMALL_SIZE)
        .fontColor(ColorTokens.TEXT_TERTIARY)

      Text(value)
        .fontSize(FontTokens.TITLE_SIZE)
        .fontWeight(FontWeight.Bold)
        .fontColor(accentColor)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Text(note)
        .fontSize(FontTokens.CAPTION_SIZE)
        .fontColor(ColorTokens.TEXT_SECONDARY)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .layoutWeight(1)
    .padding(SpacingTokens.MD)
    .backgroundColor(ColorTokens.SURFACE_SECONDARY)
    .borderRadius(RadiusTokens.MD)
    .border({ width: 1, color: ColorTokens.BORDER_SUBTLE })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  buildMetaPill(text: string, useAccent: boolean) {
    Text(text)
      .fontSize(FontTokens.CAPTION_SIZE)
      .fontColor(useAccent ? ColorTokens.ACCENT_LIGHT : ColorTokens.TEXT_SECONDARY)
      .padding({
        top: SpacingTokens.XS,
        bottom: SpacingTokens.XS,
        left: SpacingTokens.SM,
        right: SpacingTokens.SM
      })
      .backgroundColor(useAccent ? ColorTokens.OVERLAY_ACCENT : ColorTokens.BG_ELEVATED)
      .borderRadius(RadiusTokens.FULL)
      .border({
        width: 1,
        color: useAccent ? ColorTokens.WARNING : ColorTokens.BORDER_SUBTLE
      })
  }

  getDayBadgeText(): string {
    return TrainingDayLabelService.formatCompact(this.dayId, this.title)
  }

  getSaveStatusColor(): string {
    if (this.saveStatusTone === 'success') {
      return ColorTokens.SUCCESS
    }
    if (this.saveStatusTone === 'warning') {
      return ColorTokens.WARNING
    }
    return ColorTokens.TEXT_TERTIARY
  }

  getCurrentSetLabelText(): string {
    for (let exerciseIndex = 0; exerciseIndex < this.exercises.length; exerciseIndex++) {
      const exercise: ActiveWorkoutExercise = this.exercises[exerciseIndex]
      if (exercise.completedSets < exercise.targetSets) {
        const currentInputSetIndex: number = this.getCurrentInputSetIndex(exercise)
        if (currentInputSetIndex >= 0) {
          const currentSetEntry: ActiveWorkoutSetEntry = exercise.sets[currentInputSetIndex]
          return '当前录入 第 ' + (currentSetEntry.setIndex + 1).toString() + ' 组 · ' +
            this.getSetKindText(currentSetEntry)
        }
        return '当前动作待补组'
      }
    }
    if (this.completedSets >= this.totalTargetSets && this.totalTargetSets > 0) {
      return '正式组目标已完成'
    }
    return '等待开始'
  }

  getNextActionText(): string {
    if (this.completedSets >= this.totalTargetSets && this.totalTargetSets > 0) {
      return '确认数据后可直接结束训练并进入复盘，热身组会随会话一起保存。'
    }
    for (let exerciseIndex = 0; exerciseIndex < this.exercises.length; exerciseIndex++) {
      const exercise: ActiveWorkoutExercise = this.exercises[exerciseIndex]
      if (exercise.completedSets < exercise.targetSets) {
        const currentInputSetIndex: number = this.getCurrentInputSetIndex(exercise)
        if (currentInputSetIndex < 0) {
          return '当前动作的正式组目标还没达成，可先新增一组再继续记录。'
        }
        const currentSetEntry: ActiveWorkoutSetEntry = exercise.sets[currentInputSetIndex]
        if (currentSetEntry.isWarmup) {
          return '先录入当前热身组；热身组会保存，但不会计入完成率、PR 和训练量。'
        }
        return '先录入当前正式组的重量和次数，再继续下一组。'
      }
    }
    return '按已录入数据结束本次训练。'
  }

  @Builder
  buildExecutionControlSurface() {
    AppCard({ variant: 'panel', cardPadding: 'default' }) {
      Column({ space: SpacingTokens.MD }) {
        Row({ space: SpacingTokens.SM }) {
          this.buildSessionMetricTile('训练计时', this.getElapsedText(), '当前节奏', ColorTokens.TEXT_PRIMARY)
          this.buildSessionMetricTile('完成组数', this.getProgressText(), '正式记录进度', ColorTokens.DATA_HIGHLIGHT)
          this.buildSessionMetricTile('当前阶段', this.getCurrentExerciseIndexText(), '动作推进', ColorTokens.ACCENT_SOFT)
        }
        .width('100%')

        Column({ space: SpacingTokens.SM }) {
          Row() {
            Column({ space: SpacingTokens.XS }) {
              Text('当前录入焦点')
                .fontSize(FontTokens.SMALL_SIZE)
                .fontWeight(FontWeight.Medium)
                .fontColor(ColorTokens.TEXT_TERTIARY)

              Text(this.getCurrentExerciseNameText())
                .fontSize(FontTokens.HEADLINE_SIZE)
                .fontWeight(FontTokens.HEADLINE_WEIGHT)
                .fontColor(ColorTokens.TEXT_PRIMARY)
                .width('100%')
                .maxLines(2)
                .textOverflow({ overflow: TextOverflow.Ellipsis })

              Text(this.getCurrentExerciseGuidanceText())
                .fontSize(FontTokens.CAPTION_SIZE)
                .fontColor(ColorTokens.TEXT_SECONDARY)
                .lineHeight(FontTokens.CAPTION_LINE_HEIGHT)
                .width('100%')
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)

            Text(this.getCurrentSetLabelText())
              .fontSize(FontTokens.SMALL_SIZE)
              .fontColor(ColorTokens.TEXT_ON_PRIMARY)
              .padding({
                top: SpacingTokens.XS,
                bottom: SpacingTokens.XS,
                left: SpacingTokens.SM,
                right: SpacingTokens.SM
              })
              .backgroundColor(ColorTokens.PRIMARY)
              .borderRadius(RadiusTokens.FULL)
          }
          .width('100%')
          .alignItems(VerticalAlign.Top)

          Flex({ wrap: FlexWrap.Wrap }) {
            this.buildMetaPill(this.getDayBadgeText(), true)
            this.buildMetaPill('进度 ' + this.getCurrentExerciseIndexText(), false)
            this.buildMetaPill(this.getProgressText(), false)
          }
          .width('100%')

          Text(this.getNextActionText())
            .fontSize(FontTokens.BODY_SIZE)
            .fontColor(ColorTokens.TEXT_PRIMARY)
            .lineHeight(FontTokens.BODY_LINE_HEIGHT)
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
        .padding(SpacingTokens.MD)
        .backgroundColor(ColorTokens.SURFACE_SECONDARY)
        .borderRadius(RadiusTokens.LG)
        .border({ width: 1, color: ColorTokens.BORDER_STRONG })
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
  }

  build() {
    Scroll() {
      Column({ space: SpacingTokens.LG }) {
        AppCard({ variant: 'panel', cardPadding: 'default' }) {
          Column({ space: SpacingTokens.MD }) {
            Row() {
              Column({ space: SpacingTokens.XS }) {
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
                  .lineHeight(FontTokens.BODY_LINE_HEIGHT)
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start)

              if (this.hasGoal && this.hasWorkout) {
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
            }
            .width('100%')
            .alignItems(VerticalAlign.Top)

            if (this.hasGoal && this.hasWorkout) {
              StageRail({ items: this.getStageRailItems() })
            }
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
            this.buildExecutionControlSurface()

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

                    Column({ space: SpacingTokens.XXXS }) {
                      Text(this.getExerciseStatusText(exercise))
                        .fontSize(FontTokens.SMALL_SIZE)
                        .fontColor(exercise.completedSets > 0 ? ColorTokens.PRIMARY_HOVER : ColorTokens.TEXT_TERTIARY)

                      Text('已录 ' + this.countExerciseRecordedSets(exercise).toString() + ' 组')
                        .fontSize(FontTokens.CAPTION_SIZE)
                        .fontColor(ColorTokens.TEXT_TERTIARY)
                    }
                    .alignItems(HorizontalAlign.End)
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
                    Column({ space: SpacingTokens.SM }) {
                      Row() {
                        Column({ space: SpacingTokens.XS }) {
                          Text(this.getSetLabelText(setEntry))
                            .fontSize(FontTokens.BODY_SIZE)
                            .fontWeight(FontWeight.Medium)
                            .fontColor(ColorTokens.TEXT_PRIMARY)

                          Row({ space: SpacingTokens.XS }) {
                            Text(this.getSetKindText(setEntry))
                              .fontSize(FontTokens.CAPTION_SIZE)
                              .fontWeight(FontWeight.Medium)
                              .fontColor(this.getSetKindTextColor(setEntry))
                              .padding({
                                top: SpacingTokens.XS,
                                bottom: SpacingTokens.XS,
                                left: SpacingTokens.SM,
                                right: SpacingTokens.SM
                              })
                              .backgroundColor(this.getSetKindBackgroundColor(setEntry))
                              .borderRadius(RadiusTokens.FULL)
                              .border({ width: 1, color: this.getSetKindBorderColor(setEntry) })
                              .onClick(() => {
                                this.toggleSetWarmup(exercise, setEntry, !setEntry.isWarmup)
                              })

                            Text(this.getSetEntryStatusText(exercise, setEntry))
                              .fontSize(FontTokens.CAPTION_SIZE)
                              .fontWeight(FontWeight.Medium)
                              .fontColor(this.getSetEntryStatusColor(exercise, setEntry))
                              .padding({
                                top: SpacingTokens.XS,
                                bottom: SpacingTokens.XS,
                                left: SpacingTokens.SM,
                                right: SpacingTokens.SM
                              })
                              .backgroundColor(this.getSetEntryStatusBackgroundColor(exercise, setEntry))
                              .borderRadius(RadiusTokens.FULL)
                          }
                        }
                        .layoutWeight(1)

                        Column({ space: SpacingTokens.XS }) {
                          Text('点按切换')
                            .fontSize(FontTokens.MICRO_SIZE)
                            .fontWeight(FontTokens.MICRO_WEIGHT)
                            .fontColor(ColorTokens.TEXT_TERTIARY)

                          Text(setEntry.isWarmup ? '切到正式组' : '切到热身组')
                            .fontSize(FontTokens.CAPTION_SIZE)
                            .fontColor(ColorTokens.TEXT_SECONDARY)
                        }
                        .alignItems(HorizontalAlign.End)
                      }
                      .width('100%')

                      Row({ space: SpacingTokens.SM }) {
                        Column({ space: SpacingTokens.XS }) {
                          Text('重量 kg')
                            .fontSize(FontTokens.MICRO_SIZE)
                            .fontWeight(FontTokens.MICRO_WEIGHT)
                            .fontColor(ColorTokens.TEXT_TERTIARY)

                          TextInput({ text: setEntry.weightText, placeholder: this.getWeightPlaceholderText() })
                            .type(InputType.Number)
                            .fontSize(FontTokens.CAPTION_SIZE)
                            .fontColor(ColorTokens.TEXT_PRIMARY)
                            .placeholderColor(ColorTokens.TEXT_DISABLED)
                            .backgroundColor(this.getSetInputBackgroundColor(exercise, setEntry))
                            .borderRadius(RadiusTokens.SM)
                            .border({ width: 1, color: this.getSetInputBorderColor(exercise, setEntry) })
                            .height(TouchTokens.INPUT_HEIGHT)
                            .layoutWeight(1)
                            .onChange((value: string) => {
                              this.updateSetWeight(exercise, setEntry, value)
                            })
                        }
                        .layoutWeight(1)
                        .alignItems(HorizontalAlign.Start)

                        Column({ space: SpacingTokens.XS }) {
                          Text('次数')
                            .fontSize(FontTokens.MICRO_SIZE)
                            .fontWeight(FontTokens.MICRO_WEIGHT)
                            .fontColor(ColorTokens.TEXT_TERTIARY)

                          TextInput({ text: setEntry.repsText, placeholder: this.getRepsPlaceholderText() })
                            .type(InputType.Number)
                            .fontSize(FontTokens.CAPTION_SIZE)
                            .fontColor(ColorTokens.TEXT_PRIMARY)
                            .placeholderColor(ColorTokens.TEXT_DISABLED)
                            .backgroundColor(this.getSetInputBackgroundColor(exercise, setEntry))
                            .borderRadius(RadiusTokens.SM)
                            .border({ width: 1, color: this.getSetInputBorderColor(exercise, setEntry) })
                            .height(TouchTokens.INPUT_HEIGHT)
                            .layoutWeight(1)
                            .onChange((value: string) => {
                              this.updateSetReps(exercise, setEntry, value)
                            })
                        }
                        .layoutWeight(1)
                        .alignItems(HorizontalAlign.Start)
                      }
                      .width('100%')

                      Column({ space: SpacingTokens.XS }) {
                        Text(this.getSetAnalysisLabel(setEntry))
                          .fontSize(FontTokens.MICRO_SIZE)
                          .fontWeight(FontTokens.MICRO_WEIGHT)
                          .fontColor(ColorTokens.TEXT_TERTIARY)

                        Text(this.getSetAnalysisText(setEntry))
                          .fontSize(FontTokens.SMALL_SIZE)
                          .fontWeight(FontWeight.Medium)
                          .fontColor(setEntry.isComplete && !setEntry.isWarmup ? ColorTokens.ACCENT_LIGHT : ColorTokens.TEXT_SECONDARY)
                      }
                      .width('100%')
                      .alignItems(HorizontalAlign.Start)
                    }
                    .width('100%')
                    .padding(SpacingTokens.MD)
                    .backgroundColor(this.getSetEntryBackgroundColor(exercise, setEntry))
                    .borderRadius(RadiusTokens.MD)
                    .border({ width: 1, color: this.getSetEntryBorderColor(exercise, setEntry) })
                  }, (setEntry: ActiveWorkoutSetEntry) => this.createSetEntryRenderKey(setEntry))

                  AppButton({
                    text: '新增一组',
                    type: 'ghost',
                    buttonSize: 'small',
                    onButtonClick: () => {
                      this.addSetEntry(exercise)
                    }
                  })

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
                  text: this.savingWorkout ? '正在保存...' : '\u7ed3\u675f\u8bad\u7ec3\u5e76\u8fdb\u5165\u590d\u76d8',
                  type: 'primary',
                  buttonSize: 'large',
                  block: true,
                  disabled: this.getRecordedSetCount() <= 0 || this.savingWorkout,
                  onButtonClick: () => {
                    this.finishCurrentProgress()
                  }
                })

                if (this.saveStatusText.length > 0) {
                  Text(this.saveStatusText)
                    .fontSize(FontTokens.CAPTION_SIZE)
                    .fontColor(this.getSaveStatusColor())
                    .width('100%')
                }

                Text('\u53ea\u4f1a\u57fa\u4e8e\u5df2\u5f55\u5165\u6570\u636e\u4fdd\u5b58\uff0c\u4e0d\u4f1a\u81ea\u52a8\u8865\u9f50\u672a\u5f55\u5165\u7ec4\u6b21\u3002')
                  .fontSize(FontTokens.CAPTION_SIZE)
                  .fontColor(ColorTokens.TEXT_TERTIARY)
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

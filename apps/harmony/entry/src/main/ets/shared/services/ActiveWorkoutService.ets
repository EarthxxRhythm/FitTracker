/**
 * ActiveWorkoutService - prepares active workout state and completion sessions.
 *
 * Feature #10: active workout execution.
 */
import {
  estimateOneRepMax,
  WorkoutSession,
  WorkoutSet,
  createWorkoutSession,
  createWorkoutSet
} from '../models/TrainingModels'
import {
  WorkoutPreviewExercise,
  WorkoutPreviewSummary
} from './WorkoutPreviewService'

export interface ActiveWorkoutExercise {
  plannedExerciseId: string
  exerciseId: string
  name: string
  /**
   * 计划组数（进入训练时定下，永不收缩）。
   *
   * 提前结束只把 targetSets 压到 completedSets，差值就是被放弃的组数；
   * 少了这个字段，「真的练满」与「提前结束」在渲染层无法区分（两者都满足
   * completedSets >= targetSets），进度胶囊会从 N 格缩成 M 格后拉宽铺满整行。
   */
  plannedTargetSets: number
  targetSets: number
  targetReps: string
  intensityNote: string
  completedSets: number
  sets: ActiveWorkoutSetEntry[]
}

export interface ActiveWorkoutSetEntry {
  setIndex: number
  weightText: string
  repsText: string
  estimatedOneRepMax: number
  oneRepMaxText: string
  isWarmup: boolean
  isComplete: boolean
}

export interface ActiveWorkoutState {
  hasWorkout: boolean
  planId: string
  dayId: string
  title: string
  totalTargetSets: number
  completedSets: number
  currentExerciseName: string
  currentExerciseSetProgress: string
  exercises: ActiveWorkoutExercise[]
}

class ActiveWorkoutService {
  createState(preview: WorkoutPreviewSummary): ActiveWorkoutState {
    const exercises: ActiveWorkoutExercise[] = []
    let totalTargetSets: number = 0

    for (let index = 0; index < preview.exercises.length; index++) {
      const previewExercise: WorkoutPreviewExercise = preview.exercises[index]
      totalTargetSets += previewExercise.targetSets
      exercises.push(this.createActiveExercise(previewExercise))
    }

    const state: ActiveWorkoutState = {
      hasWorkout: preview.hasWorkout && exercises.length > 0,
      planId: preview.planId,
      dayId: preview.dayId,
      title: preview.title,
      totalTargetSets: totalTargetSets,
      completedSets: this.countCompletedSets(exercises),
      currentExerciseName: this.findCurrentExerciseName(exercises),
      currentExerciseSetProgress: this.createCurrentExerciseSetProgress(exercises),
      exercises: exercises
    }
    return state
  }

  createStateWithProgress(
    state: ActiveWorkoutState,
    exercises: ActiveWorkoutExercise[]
  ): ActiveWorkoutState {
    const nextExercises: ActiveWorkoutExercise[] = this.copyActiveExercises(exercises)
    const nextState: ActiveWorkoutState = {
      hasWorkout: state.hasWorkout,
      planId: state.planId,
      dayId: state.dayId,
      title: state.title,
      totalTargetSets: state.totalTargetSets,
      completedSets: this.countCompletedSets(nextExercises),
      currentExerciseName: this.findCurrentExerciseName(nextExercises),
      currentExerciseSetProgress: this.createCurrentExerciseSetProgress(nextExercises),
      exercises: nextExercises
    }
    return nextState
  }

  createCompletedSession(
    sessionId: string,
    state: ActiveWorkoutState,
    startedAt: number,
    endedAt: number,
    completedSets: number
  ): WorkoutSession {
    const sets: WorkoutSet[] = this.createWorkoutSets(state.exercises)
    const actualCompletedSets: number = this.countCompletedSets(state.exercises)
    const session: WorkoutSession = createWorkoutSession(
      sessionId,
      state.planId,
      state.dayId,
      startedAt,
      endedAt,
      this.calculateDurationSeconds(startedAt, endedAt),
      actualCompletedSets,
      this.calculateTotalVolume(sets),
      0,
      this.createSessionNotes(actualCompletedSets, state.totalTargetSets),
      sets
    )
    return session
  }

  /**
   * 下一个待填组的动作：首个 completedSets < targetSets 的动作。
   *
   * 全部录满返回 undefined——训练页据此判定收尾，而不是依赖页面里写死的段数常量。
   */
  nextExercise(state: ActiveWorkoutState): ActiveWorkoutExercise | undefined {
    for (let index = 0; index < state.exercises.length; index++) {
      const exercise: ActiveWorkoutExercise = state.exercises[index]
      if (exercise.completedSets < exercise.targetSets) {
        return exercise
      }
    }
    return undefined
  }

  /** 下一个待填组所属动作的 plannedExerciseId；全部录满返回空串。 */
  nextPlannedExerciseId(state: ActiveWorkoutState): string {
    const exercise: ActiveWorkoutExercise | undefined = this.nextExercise(state)
    if (exercise === undefined) {
      return ''
    }
    return exercise.plannedExerciseId
  }

  /** 下一个待填组在该动作内的序号（0 起）；全部录满返回 0。 */
  nextSetIndex(state: ActiveWorkoutState): number {
    const exercise: ActiveWorkoutExercise | undefined = this.nextExercise(state)
    if (exercise === undefined) {
      return 0
    }
    return exercise.completedSets
  }

  /** 训练总组数（跨动作求和）；state 里已算好时直接用，异常态回退重算。 */
  totalTargetSets(state: ActiveWorkoutState): number {
    if (state.totalTargetSets > 0) {
      return state.totalTargetSets
    }
    let total: number = 0
    for (let index = 0; index < state.exercises.length; index++) {
      total += state.exercises[index].targetSets
    }
    return total
  }

  /**
   * 记录一组：写入「当前待填动作的下一组」并返回推进后的 state。
   *
   * 训练页每次「完成本组」都只走这一个写入口——目标动作与组下标都由 state 推导，
   * 不依赖界面上的序号，因此第一个动作录满后会自动落到下一个动作的第 1 组。
   * 已全部录满时原样返回（调用方应先看 nextExercise 决定是否收尾）。
   */
  recordSet(state: ActiveWorkoutState, weightText: string, repsText: string): ActiveWorkoutState {
    const exercise: ActiveWorkoutExercise | undefined = this.nextExercise(state)
    if (exercise === undefined) {
      return state
    }
    const updated: ActiveWorkoutExercise[] = this.updateSetEntry(
      state.exercises,
      exercise.plannedExerciseId,
      exercise.completedSets,
      weightText,
      repsText
    )
    return this.createStateWithProgress(state, updated)
  }

  /**
   * 记录一组到指定动作（训练页顶部动作切换条的唯一写入口）。
   *
   * 与 recordSet 的差别只在目标：recordSet 写「首个未录满动作」，本方法写界面选中的动作。
   * 目标动作没有空组时原样返回——调用方须先用 nextEmptySetIndex 判定可写，
   * 否则一组会记到用户没在看的动作上。
   */
  recordSetFor(
    state: ActiveWorkoutState,
    plannedExerciseId: string,
    weightText: string,
    repsText: string
  ): ActiveWorkoutState {
    const index: number = this.findExerciseIndexById(state.exercises, plannedExerciseId)
    if (index < 0) {
      return state
    }
    const setIndex: number = this.nextEmptySetIndex(state.exercises[index])
    if (setIndex < 0) {
      return state
    }
    const updated: ActiveWorkoutExercise[] = this.updateSetEntry(
      state.exercises,
      plannedExerciseId,
      setIndex,
      weightText,
      repsText
    )
    return this.createStateWithProgress(state, updated)
  }

  /** 动作内首个未填组的下标（0 起）；全部填完返回 -1。热身组按「已填」处理——补录不该覆盖它。 */
  nextEmptySetIndex(exercise: ActiveWorkoutExercise): number {
    for (let index = 0; index < exercise.sets.length; index++) {
      if (!exercise.sets[index].isComplete) {
        return index
      }
    }
    return -1
  }

  private findExerciseIndexById(exercises: ActiveWorkoutExercise[], plannedExerciseId: string): number {
    for (let index = 0; index < exercises.length; index++) {
      if (exercises[index].plannedExerciseId === plannedExerciseId) {
        return index
      }
    }
    return -1
  }

  /**
   * 提前结束某个动作：把它收缩到「已完成的组数」。
   *
   * 为什么不加 endedEarly 标记：收尾判据（nextExercise）与组胶囊渲染都以
   * completedSets < targetSets 为口径，收缩 targetSets 让所有下游逻辑零改动地跳过它；
   * 而 WorkoutSession 只记录实际组数（totalSets），没有计划组数，因此不丢落库信息。
   *
   * 已录满时原样返回同一引用——调用方据此判定无需结束。
   */
  endExercise(state: ActiveWorkoutState, plannedExerciseId: string): ActiveWorkoutState {
    const index: number = this.findExerciseIndexById(state.exercises, plannedExerciseId)
    if (index < 0) {
      return state
    }
    const exercise: ActiveWorkoutExercise = state.exercises[index]
    if (exercise.completedSets >= exercise.targetSets) {
      return state
    }
    const nextExercises: ActiveWorkoutExercise[] = this.copyActiveExercises(state.exercises)
    nextExercises[index] = this.copyExerciseEndedEarly(exercise)
    const base: ActiveWorkoutState = this.withTotalTargetSets(state, this.sumTargetSets(nextExercises))
    return this.createStateWithProgress(base, nextExercises)
  }

  /** 收缩：targetSets 对齐 completedSets，sets 裁到已完成部分（未完成的空组直接丢弃）。 */
  private copyExerciseEndedEarly(exercise: ActiveWorkoutExercise): ActiveWorkoutExercise {
    const kept: ActiveWorkoutSetEntry[] = []
    for (let index = 0; index < exercise.sets.length; index++) {
      if (index < exercise.completedSets) {
        kept.push(this.copySetEntry(exercise.sets[index]))
      }
    }
    const item: ActiveWorkoutExercise = {
      plannedExerciseId: exercise.plannedExerciseId,
      exerciseId: exercise.exerciseId,
      name: exercise.name,
      plannedTargetSets: exercise.plannedTargetSets,
      targetSets: exercise.completedSets,
      targetReps: exercise.targetReps,
      intensityNote: exercise.intensityNote,
      completedSets: exercise.completedSets,
      sets: kept
    }
    return item
  }

  private sumTargetSets(exercises: ActiveWorkoutExercise[]): number {
    let total: number = 0
    for (let index = 0; index < exercises.length; index++) {
      total += exercises[index].targetSets
    }
    return total
  }

  /** 复制 state 并替换 totalTargetSets（createStateWithProgress 不重算该字段）。 */
  private withTotalTargetSets(state: ActiveWorkoutState, totalTargetSets: number): ActiveWorkoutState {
    const copy: ActiveWorkoutState = {
      hasWorkout: state.hasWorkout,
      planId: state.planId,
      dayId: state.dayId,
      title: state.title,
      totalTargetSets: totalTargetSets,
      completedSets: state.completedSets,
      currentExerciseName: state.currentExerciseName,
      currentExerciseSetProgress: state.currentExerciseSetProgress,
      exercises: state.exercises
    }
    return copy
  }

  countCompletedSets(exercises: ActiveWorkoutExercise[]): number {
    let completedSets: number = 0
    for (let index = 0; index < exercises.length; index++) {
      completedSets += this.countCompleteWorkingSetEntries(exercises[index].sets)
    }
    return completedSets
  }

  countRecordedSets(exercises: ActiveWorkoutExercise[]): number {
    let recordedSets: number = 0
    for (let index = 0; index < exercises.length; index++) {
      recordedSets += this.countCompleteRecordedSetEntries(exercises[index].sets)
    }
    return recordedSets
  }

  updateExerciseCompletedSets(
    exercises: ActiveWorkoutExercise[],
    plannedExerciseId: string,
    completedSets: number
  ): ActiveWorkoutExercise[] {
    const values: ActiveWorkoutExercise[] = []
    for (let index = 0; index < exercises.length; index++) {
      const exercise: ActiveWorkoutExercise = exercises[index]
      let nextCompletedSets: number = exercise.completedSets
      if (exercise.plannedExerciseId === plannedExerciseId) {
        nextCompletedSets = this.clampCompletedSets(completedSets, exercise.targetSets)
      }
      values.push(this.copyActiveExerciseWithCompletedSets(exercise, nextCompletedSets))
    }
    return values
  }

  updateSetEntry(
    exercises: ActiveWorkoutExercise[],
    plannedExerciseId: string,
    setIndex: number,
    weightText: string,
    repsText: string
  ): ActiveWorkoutExercise[] {
    const values: ActiveWorkoutExercise[] = []
    for (let index = 0; index < exercises.length; index++) {
      const exercise: ActiveWorkoutExercise = exercises[index]
      if (exercise.plannedExerciseId === plannedExerciseId) {
        values.push(this.copyActiveExerciseWithSetEntry(exercise, setIndex, weightText, repsText))
      } else {
        values.push(this.copyActiveExercise(exercise))
      }
    }
    return values
  }

  updateSetWeight(
    exercises: ActiveWorkoutExercise[],
    plannedExerciseId: string,
    setIndex: number,
    weightText: string
  ): ActiveWorkoutExercise[] {
    const repsText: string = this.findSetRepsText(exercises, plannedExerciseId, setIndex)
    return this.updateSetEntry(exercises, plannedExerciseId, setIndex, weightText, repsText)
  }

  updateSetReps(
    exercises: ActiveWorkoutExercise[],
    plannedExerciseId: string,
    setIndex: number,
    repsText: string
  ): ActiveWorkoutExercise[] {
    const weightText: string = this.findSetWeightText(exercises, plannedExerciseId, setIndex)
    return this.updateSetEntry(exercises, plannedExerciseId, setIndex, weightText, repsText)
  }

  updateSetWarmup(
    exercises: ActiveWorkoutExercise[],
    plannedExerciseId: string,
    setIndex: number,
    isWarmup: boolean
  ): ActiveWorkoutExercise[] {
    const values: ActiveWorkoutExercise[] = []
    for (let index = 0; index < exercises.length; index++) {
      const exercise: ActiveWorkoutExercise = exercises[index]
      if (exercise.plannedExerciseId === plannedExerciseId) {
        values.push(this.copyActiveExerciseWithWarmupState(exercise, setIndex, isWarmup))
      } else {
        values.push(this.copyActiveExercise(exercise))
      }
    }
    return values
  }

  addSetEntry(exercises: ActiveWorkoutExercise[], plannedExerciseId: string): ActiveWorkoutExercise[] {
    const values: ActiveWorkoutExercise[] = []
    for (let index = 0; index < exercises.length; index++) {
      const exercise: ActiveWorkoutExercise = exercises[index]
      if (exercise.plannedExerciseId === plannedExerciseId) {
        values.push(this.copyActiveExerciseWithAdditionalSet(exercise))
      } else {
        values.push(this.copyActiveExercise(exercise))
      }
    }
    return values
  }

  markAllComplete(exercises: ActiveWorkoutExercise[]): ActiveWorkoutExercise[] {
    return this.copyActiveExercises(exercises)
  }

  private copyActiveExercises(source: ActiveWorkoutExercise[]): ActiveWorkoutExercise[] {
    const values: ActiveWorkoutExercise[] = []
    for (let index = 0; index < source.length; index++) {
      const exercise: ActiveWorkoutExercise = source[index]
      values.push(this.copyActiveExercise(exercise))
    }
    return values
  }

  private findCurrentExerciseName(exercises: ActiveWorkoutExercise[]): string {
    const exercise: ActiveWorkoutExercise | undefined = this.findCurrentExercise(exercises)
    if (exercise === undefined) {
      return ''
    }
    return exercise.name
  }

  private createCurrentExerciseSetProgress(exercises: ActiveWorkoutExercise[]): string {
    const exercise: ActiveWorkoutExercise | undefined = this.findCurrentExercise(exercises)
    if (exercise === undefined) {
      return '0/0 正式组'
    }
    return exercise.completedSets.toString() + '/' + exercise.targetSets.toString() + ' 正式组'
  }

  private findCurrentExercise(exercises: ActiveWorkoutExercise[]): ActiveWorkoutExercise | undefined {
    for (let index = 0; index < exercises.length; index++) {
      const exercise: ActiveWorkoutExercise = exercises[index]
      if (exercise.completedSets < exercise.targetSets) {
        return exercise
      }
    }

    if (exercises.length === 0) {
      return undefined
    }
    return exercises[exercises.length - 1]
  }

  private createActiveExercise(previewExercise: WorkoutPreviewExercise): ActiveWorkoutExercise {
    const exercise: ActiveWorkoutExercise = {
      plannedExerciseId: previewExercise.plannedExerciseId,
      exerciseId: previewExercise.exerciseId,
      name: previewExercise.name,
      plannedTargetSets: previewExercise.targetSets,
      targetSets: previewExercise.targetSets,
      targetReps: previewExercise.targetReps,
      intensityNote: previewExercise.intensityNote,
      completedSets: 0,
      sets: this.createSetEntries(previewExercise.targetSets)
    }
    return exercise
  }

  private copyActiveExercise(exercise: ActiveWorkoutExercise): ActiveWorkoutExercise {
    const item: ActiveWorkoutExercise = {
      plannedExerciseId: exercise.plannedExerciseId,
      exerciseId: exercise.exerciseId,
      name: exercise.name,
      plannedTargetSets: exercise.plannedTargetSets,
      targetSets: exercise.targetSets,
      targetReps: exercise.targetReps,
      intensityNote: exercise.intensityNote,
      completedSets: this.countCompleteWorkingSetEntries(exercise.sets),
      sets: this.copySetEntries(exercise.sets)
    }
    return item
  }

  private copyActiveExerciseWithCompletedSets(
    exercise: ActiveWorkoutExercise,
    completedSets: number
  ): ActiveWorkoutExercise {
    const item: ActiveWorkoutExercise = {
      plannedExerciseId: exercise.plannedExerciseId,
      exerciseId: exercise.exerciseId,
      name: exercise.name,
      plannedTargetSets: exercise.plannedTargetSets,
      targetSets: exercise.targetSets,
      targetReps: exercise.targetReps,
      intensityNote: exercise.intensityNote,
      completedSets: completedSets,
      sets: this.copySetEntries(exercise.sets)
    }
    return item
  }

  private copyActiveExerciseWithSetEntry(
    exercise: ActiveWorkoutExercise,
    setIndex: number,
    weightText: string,
    repsText: string
  ): ActiveWorkoutExercise {
    const sets: ActiveWorkoutSetEntry[] = []
    for (let index = 0; index < exercise.sets.length; index++) {
      const entry: ActiveWorkoutSetEntry = exercise.sets[index]
      if (entry.setIndex === setIndex) {
        sets.push(this.createSetEntry(setIndex, weightText, repsText, entry.isWarmup))
      } else {
        sets.push(this.copySetEntry(entry))
      }
    }

    const item: ActiveWorkoutExercise = {
      plannedExerciseId: exercise.plannedExerciseId,
      exerciseId: exercise.exerciseId,
      name: exercise.name,
      plannedTargetSets: exercise.plannedTargetSets,
      targetSets: exercise.targetSets,
      targetReps: exercise.targetReps,
      intensityNote: exercise.intensityNote,
      completedSets: this.countCompleteWorkingSetEntries(sets),
      sets: sets
    }
    return item
  }

  private copyActiveExerciseWithWarmupState(
    exercise: ActiveWorkoutExercise,
    setIndex: number,
    isWarmup: boolean
  ): ActiveWorkoutExercise {
    const sets: ActiveWorkoutSetEntry[] = []
    for (let index = 0; index < exercise.sets.length; index++) {
      const entry: ActiveWorkoutSetEntry = exercise.sets[index]
      if (entry.setIndex === setIndex) {
        sets.push(this.createSetEntry(entry.setIndex, entry.weightText, entry.repsText, isWarmup))
      } else {
        sets.push(this.copySetEntry(entry))
      }
    }

    const item: ActiveWorkoutExercise = {
      plannedExerciseId: exercise.plannedExerciseId,
      exerciseId: exercise.exerciseId,
      name: exercise.name,
      plannedTargetSets: exercise.plannedTargetSets,
      targetSets: exercise.targetSets,
      targetReps: exercise.targetReps,
      intensityNote: exercise.intensityNote,
      completedSets: this.countCompleteWorkingSetEntries(sets),
      sets: sets
    }
    return item
  }

  private copyActiveExerciseWithAdditionalSet(exercise: ActiveWorkoutExercise): ActiveWorkoutExercise {
    const sets: ActiveWorkoutSetEntry[] = this.copySetEntries(exercise.sets)
    sets.push(this.createSetEntry(this.getNextSetIndex(sets), '', '', false))
    const item: ActiveWorkoutExercise = {
      plannedExerciseId: exercise.plannedExerciseId,
      exerciseId: exercise.exerciseId,
      name: exercise.name,
      plannedTargetSets: exercise.plannedTargetSets,
      targetSets: exercise.targetSets,
      targetReps: exercise.targetReps,
      intensityNote: exercise.intensityNote,
      completedSets: this.countCompleteWorkingSetEntries(sets),
      sets: sets
    }
    return item
  }

  private findSetWeightText(
    exercises: ActiveWorkoutExercise[],
    plannedExerciseId: string,
    setIndex: number
  ): string {
    const entry: ActiveWorkoutSetEntry | undefined = this.findSetEntry(exercises, plannedExerciseId, setIndex)
    if (entry === undefined) {
      return ''
    }
    return entry.weightText
  }

  private findSetRepsText(
    exercises: ActiveWorkoutExercise[],
    plannedExerciseId: string,
    setIndex: number
  ): string {
    const entry: ActiveWorkoutSetEntry | undefined = this.findSetEntry(exercises, plannedExerciseId, setIndex)
    if (entry === undefined) {
      return ''
    }
    return entry.repsText
  }

  private findSetEntry(
    exercises: ActiveWorkoutExercise[],
    plannedExerciseId: string,
    setIndex: number
  ): ActiveWorkoutSetEntry | undefined {
    for (let exerciseIndex = 0; exerciseIndex < exercises.length; exerciseIndex++) {
      const exercise: ActiveWorkoutExercise = exercises[exerciseIndex]
      if (exercise.plannedExerciseId !== plannedExerciseId) {
        continue
      }
      for (let setEntryIndex = 0; setEntryIndex < exercise.sets.length; setEntryIndex++) {
        const entry: ActiveWorkoutSetEntry = exercise.sets[setEntryIndex]
        if (entry.setIndex === setIndex) {
          return entry
        }
      }
    }
    return undefined
  }

  private createSetEntries(targetSets: number): ActiveWorkoutSetEntry[] {
    const values: ActiveWorkoutSetEntry[] = []
    for (let index = 0; index < targetSets; index++) {
      values.push(this.createSetEntry(index, '', '', false))
    }
    return values
  }

  private copySetEntries(source: ActiveWorkoutSetEntry[]): ActiveWorkoutSetEntry[] {
    const values: ActiveWorkoutSetEntry[] = []
    for (let index = 0; index < source.length; index++) {
      values.push(this.copySetEntry(source[index]))
    }
    return values
  }

  private copySetEntry(entry: ActiveWorkoutSetEntry): ActiveWorkoutSetEntry {
    const item: ActiveWorkoutSetEntry = {
      setIndex: entry.setIndex,
      weightText: entry.weightText,
      repsText: entry.repsText,
      estimatedOneRepMax: entry.estimatedOneRepMax,
      oneRepMaxText: entry.oneRepMaxText,
      isWarmup: entry.isWarmup,
      isComplete: entry.isComplete
    }
    return item
  }

  private createSetEntry(setIndex: number, weightText: string, repsText: string, isWarmup: boolean): ActiveWorkoutSetEntry {
    const weight: number = Number(weightText)
    const reps: number = Number(repsText)
    let estimatedOneRepMax: number = 0
    let oneRepMaxText: string = isWarmup ? '热身组不参与 PR 与训练量' : '录入重量和次数后显示 1RM'
    let isComplete: boolean = false

    if (!Number.isNaN(weight) && !Number.isNaN(reps) && weight > 0 && reps > 0) {
      estimatedOneRepMax = Math.round(estimateOneRepMax(weight, reps))
      if (isWarmup) {
        oneRepMaxText = '热身组已记录，不参与 PR 与训练量'
      } else {
        oneRepMaxText = '参考 1RM ' + estimatedOneRepMax.toString() + ' kg'
      }
      isComplete = true
    }

    const item: ActiveWorkoutSetEntry = {
      setIndex: setIndex,
      weightText: weightText,
      repsText: repsText,
      estimatedOneRepMax: estimatedOneRepMax,
      oneRepMaxText: oneRepMaxText,
      isWarmup: isWarmup,
      isComplete: isComplete
    }
    return item
  }

  private countCompleteWorkingSetEntries(sets: ActiveWorkoutSetEntry[]): number {
    let count: number = 0
    for (let index = 0; index < sets.length; index++) {
      if (sets[index].isComplete && !sets[index].isWarmup) {
        count++
      }
    }
    return count
  }

  private countCompleteRecordedSetEntries(sets: ActiveWorkoutSetEntry[]): number {
    let count: number = 0
    for (let index = 0; index < sets.length; index++) {
      if (sets[index].isComplete) {
        count++
      }
    }
    return count
  }

  private getNextSetIndex(sets: ActiveWorkoutSetEntry[]): number {
    let nextSetIndex: number = sets.length
    for (let index = 0; index < sets.length; index++) {
      if (sets[index].setIndex >= nextSetIndex) {
        nextSetIndex = sets[index].setIndex + 1
      }
    }
    return nextSetIndex
  }

  private createWorkoutSets(exercises: ActiveWorkoutExercise[]): WorkoutSet[] {
    const values: WorkoutSet[] = []
    for (let exerciseIndex = 0; exerciseIndex < exercises.length; exerciseIndex++) {
      const exercise: ActiveWorkoutExercise = exercises[exerciseIndex]
      for (let setIndex = 0; setIndex < exercise.sets.length; setIndex++) {
        const setEntry: ActiveWorkoutSetEntry = exercise.sets[setIndex]
        if (setEntry.isComplete) {
          values.push(this.createWorkoutSetFromEntry(exercise, setEntry))
        }
      }
    }
    return values
  }

  private createWorkoutSetFromEntry(
    exercise: ActiveWorkoutExercise,
    setEntry: ActiveWorkoutSetEntry
  ): WorkoutSet {
    return createWorkoutSet(
      exercise.plannedExerciseId + '_set_' + (setEntry.setIndex + 1).toString(),
      exercise.exerciseId,
      this.parsePositiveNumber(setEntry.weightText),
      Math.floor(this.parsePositiveNumber(setEntry.repsText)),
      0,
      setEntry.isWarmup
    )
  }

  private calculateTotalVolume(sets: WorkoutSet[]): number {
    let totalVolume: number = 0
    for (let index = 0; index < sets.length; index++) {
      const set: WorkoutSet = sets[index]
      if (!set.isWarmup) {
        totalVolume += set.weight * set.reps
      }
    }
    return Math.round(totalVolume * 100) / 100
  }

  private parsePositiveNumber(value: string): number {
    const parsed: number = Number(value)
    if (Number.isNaN(parsed) || parsed <= 0) {
      return 0
    }
    return parsed
  }

  private clampCompletedSets(completedSets: number, targetSets: number): number {
    if (completedSets < 0) {
      return 0
    }
    if (completedSets > targetSets) {
      return targetSets
    }
    return completedSets
  }

  private calculateDurationSeconds(startedAt: number, endedAt: number): number {
    if (endedAt <= startedAt) {
      return 0
    }
    return Math.floor((endedAt - startedAt) / 1000)
  }

  private createSessionNotes(completedSets: number, totalTargetSets: number): string {
    return 'completed_sets=' + completedSets.toString() + ';target_sets=' + totalTargetSets.toString()
  }
}

export default new ActiveWorkoutService()

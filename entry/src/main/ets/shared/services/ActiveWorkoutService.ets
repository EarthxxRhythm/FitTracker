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
      completedSets: 0,
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
    let totalSets: number = completedSets
    if (sets.length > 0) {
      totalSets = sets.length
    }
    const session: WorkoutSession = createWorkoutSession(
      sessionId,
      state.planId,
      state.dayId,
      startedAt,
      endedAt,
      this.calculateDurationSeconds(startedAt, endedAt),
      totalSets,
      this.calculateTotalVolume(sets),
      0,
      this.createSessionNotes(totalSets, state.totalTargetSets),
      sets
    )
    return session
  }

  countCompletedSets(exercises: ActiveWorkoutExercise[]): number {
    let completedSets: number = 0
    for (let index = 0; index < exercises.length; index++) {
      completedSets += exercises[index].completedSets
    }
    return completedSets
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

  markAllComplete(exercises: ActiveWorkoutExercise[]): ActiveWorkoutExercise[] {
    const values: ActiveWorkoutExercise[] = []
    for (let index = 0; index < exercises.length; index++) {
      const exercise: ActiveWorkoutExercise = exercises[index]
      values.push(this.copyActiveExerciseWithCompletedSets(exercise, exercise.targetSets))
    }
    return values
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
      return '0/0'
    }
    return exercise.completedSets.toString() + '/' + exercise.targetSets.toString()
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
      targetSets: exercise.targetSets,
      targetReps: exercise.targetReps,
      intensityNote: exercise.intensityNote,
      completedSets: exercise.completedSets,
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
        sets.push(this.createSetEntry(setIndex, weightText, repsText))
      } else {
        sets.push(this.copySetEntry(entry))
      }
    }

    const item: ActiveWorkoutExercise = {
      plannedExerciseId: exercise.plannedExerciseId,
      exerciseId: exercise.exerciseId,
      name: exercise.name,
      targetSets: exercise.targetSets,
      targetReps: exercise.targetReps,
      intensityNote: exercise.intensityNote,
      completedSets: this.countCompleteSetEntries(sets),
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
      values.push(this.createSetEntry(index, '', ''))
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
      isComplete: entry.isComplete
    }
    return item
  }

  private createSetEntry(setIndex: number, weightText: string, repsText: string): ActiveWorkoutSetEntry {
    const weight: number = Number(weightText)
    const reps: number = Number(repsText)
    let estimatedOneRepMax: number = 0
    let oneRepMaxText: string = '录入重量和次数后显示 1RM'
    let isComplete: boolean = false

    if (!Number.isNaN(weight) && !Number.isNaN(reps) && weight > 0 && reps > 0) {
      estimatedOneRepMax = Math.round(estimateOneRepMax(weight, reps))
      oneRepMaxText = '1RM 参考 ' + estimatedOneRepMax.toString() + ' kg'
      isComplete = true
    }

    const item: ActiveWorkoutSetEntry = {
      setIndex: setIndex,
      weightText: weightText,
      repsText: repsText,
      estimatedOneRepMax: estimatedOneRepMax,
      oneRepMaxText: oneRepMaxText,
      isComplete: isComplete
    }
    return item
  }

  private countCompleteSetEntries(sets: ActiveWorkoutSetEntry[]): number {
    let count: number = 0
    for (let index = 0; index < sets.length; index++) {
      if (sets[index].isComplete) {
        count++
      }
    }
    return count
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
      false
    )
  }

  private calculateTotalVolume(sets: WorkoutSet[]): number {
    let totalVolume: number = 0
    for (let index = 0; index < sets.length; index++) {
      const set: WorkoutSet = sets[index]
      totalVolume += set.weight * set.reps
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

/**
 * ActiveWorkoutService - prepares active workout state and completion sessions.
 *
 * Feature #10: active workout execution.
 */
import {
  WorkoutSession,
  WorkoutSet,
  createWorkoutSession
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
}

export interface ActiveWorkoutState {
  hasWorkout: boolean
  planId: string
  dayId: string
  title: string
  totalTargetSets: number
  completedSets: number
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
      exercises: exercises
    }
    return state
  }

  createCompletedSession(
    sessionId: string,
    state: ActiveWorkoutState,
    startedAt: number,
    endedAt: number,
    completedSets: number
  ): WorkoutSession {
    const sets: WorkoutSet[] = []
    const session: WorkoutSession = createWorkoutSession(
      sessionId,
      state.planId,
      state.dayId,
      startedAt,
      endedAt,
      this.calculateDurationSeconds(startedAt, endedAt),
      completedSets,
      0,
      0,
      this.createSessionNotes(completedSets, state.totalTargetSets),
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

  markAllComplete(exercises: ActiveWorkoutExercise[]): ActiveWorkoutExercise[] {
    const values: ActiveWorkoutExercise[] = []
    for (let index = 0; index < exercises.length; index++) {
      const exercise: ActiveWorkoutExercise = exercises[index]
      values.push(this.copyActiveExerciseWithCompletedSets(exercise, exercise.targetSets))
    }
    return values
  }

  private createActiveExercise(previewExercise: WorkoutPreviewExercise): ActiveWorkoutExercise {
    const exercise: ActiveWorkoutExercise = {
      plannedExerciseId: previewExercise.plannedExerciseId,
      exerciseId: previewExercise.exerciseId,
      name: previewExercise.name,
      targetSets: previewExercise.targetSets,
      targetReps: previewExercise.targetReps,
      intensityNote: previewExercise.intensityNote,
      completedSets: 0
    }
    return exercise
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
      completedSets: completedSets
    }
    return item
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

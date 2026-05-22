/**
 * WorkoutPreviewService - transforms generated plan days into workout preview data.
 *
 * Feature #9: workout preview before active training.
 */
import {
  ExerciseContent,
  PlanDay,
  PlannedExercise,
  TrainingPlan
} from '../models/TrainingModels'
import ContentRepository from './ContentRepository'

export interface WorkoutPreviewExercise {
  plannedExerciseId: string
  exerciseId: string
  name: string
  targetSets: number
  targetReps: string
  intensityNote: string
  alternativeExerciseIds: string[]
  alternativeNames: string[]
}

export interface WorkoutPreviewSummary {
  hasWorkout: boolean
  planId: string
  dayId: string
  title: string
  exerciseCount: number
  exercises: WorkoutPreviewExercise[]
}

class WorkoutPreviewService {
  createPreview(plan: TrainingPlan, daySeed: number): WorkoutPreviewSummary {
    const day: PlanDay | undefined = this.pickDay(plan, daySeed)
    if (day === undefined) {
      const emptyExercises: WorkoutPreviewExercise[] = []
      const emptySummary: WorkoutPreviewSummary = {
        hasWorkout: false,
        planId: plan.planId,
        dayId: '',
        title: 'Rest Day',
        exerciseCount: 0,
        exercises: emptyExercises
      }
      return emptySummary
    }

    const exercises: WorkoutPreviewExercise[] = []
    for (let index = 0; index < day.exercises.length; index++) {
      exercises.push(this.createPreviewExercise(day.exercises[index]))
    }

    const summary: WorkoutPreviewSummary = {
      hasWorkout: exercises.length > 0,
      planId: plan.planId,
      dayId: day.dayId,
      title: day.title,
      exerciseCount: exercises.length,
      exercises: exercises
    }
    return summary
  }

  private pickDay(plan: TrainingPlan, daySeed: number): PlanDay | undefined {
    if (plan.days.length === 0) {
      return undefined
    }

    let normalizedSeed: number = daySeed
    if (normalizedSeed <= 0) {
      normalizedSeed = 1
    }
    const index: number = (normalizedSeed - 1) % plan.days.length
    return plan.days[index]
  }

  private createPreviewExercise(planned: PlannedExercise): WorkoutPreviewExercise {
    const content: ExerciseContent | undefined = ContentRepository.getExerciseById(planned.exerciseId)
    let name: string = planned.exerciseId
    if (content !== undefined) {
      name = content.nameZh
    }

    const alternativeIds: string[] = this.copyStringArray(planned.alternativeExerciseIds)
    const alternativeNames: string[] = this.getAlternativeNames(alternativeIds)
    const item: WorkoutPreviewExercise = {
      plannedExerciseId: planned.plannedExerciseId,
      exerciseId: planned.exerciseId,
      name: name,
      targetSets: planned.targetSets,
      targetReps: planned.targetReps,
      intensityNote: planned.intensityNote,
      alternativeExerciseIds: alternativeIds,
      alternativeNames: alternativeNames
    }
    return item
  }

  private getAlternativeNames(alternativeExerciseIds: string[]): string[] {
    const names: string[] = []
    for (let index = 0; index < alternativeExerciseIds.length; index++) {
      const exerciseId: string = alternativeExerciseIds[index]
      const content: ExerciseContent | undefined = ContentRepository.getExerciseById(exerciseId)
      if (content !== undefined) {
        names.push(content.nameZh)
      }
    }
    return names
  }

  private copyStringArray(source: string[]): string[] {
    const values: string[] = []
    for (let index = 0; index < source.length; index++) {
      values.push(source[index])
    }
    return values
  }
}

export default new WorkoutPreviewService()

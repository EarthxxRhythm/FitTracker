/**
 * WorkoutSessionPersistenceBridgeService -- sync shared workout sessions into the legacy persistence store.
 *
 * Function #11: keep workout summary edit and undo flows consistent with the legacy session store.
 */
import { ExerciseContent, WorkoutSession, WorkoutSet } from '../../../shared/models/TrainingModels'
import ContentRepository from '../../../shared/services/ContentRepository'
import WorkoutSessionService, {
  SavedExercise,
  SavedSet,
  WorkoutSession as LegacyWorkoutSession
} from '../../../common/services/WorkoutSessionService'

class WorkoutSessionPersistenceBridgeService {
  async saveOrUpdateSession(context: Context, session: WorkoutSession): Promise<void> {
    const legacySession: LegacyWorkoutSession = this.createLegacySession(session)
    const updated: boolean = await WorkoutSessionService.updateSession(context, legacySession)
    if (!updated) {
      await WorkoutSessionService.saveSession(context, legacySession)
    }
  }

  async removeSession(context: Context, sessionId: string): Promise<void> {
    await WorkoutSessionService.removeSession(context, sessionId)
  }

  async restoreSession(context: Context, session: WorkoutSession): Promise<void> {
    const legacySession: LegacyWorkoutSession = this.createLegacySession(session)
    const restored: boolean = await WorkoutSessionService.restoreSession(context, legacySession)
    if (!restored) {
      await WorkoutSessionService.updateSession(context, legacySession)
    }
  }

  private createLegacySession(session: WorkoutSession): LegacyWorkoutSession {
    const legacySession: LegacyWorkoutSession = {
      id: session.sessionId,
      planId: session.planId,
      planName: session.planId,
      dayLabel: session.dayId,
      startTime: session.startedAt,
      endTime: session.endedAt,
      durationSeconds: session.durationSeconds,
      totalSets: session.totalSets,
      totalVolume: session.totalVolume,
      notes: session.notes,
      exercises: this.createLegacyExercises(session.sets),
      createdAt: this.formatDate(session.startedAt)
    }
    return legacySession
  }

  private createLegacyExercises(sets: WorkoutSet[]): SavedExercise[] {
    const exercises: SavedExercise[] = []
    for (let index = 0; index < sets.length; index++) {
      const set: WorkoutSet = sets[index]
      const exercise: SavedExercise = this.findOrCreateExercise(exercises, set.exerciseId)
      exercise.sets.push(this.createLegacySet(set))
    }
    return exercises
  }

  private findOrCreateExercise(exercises: SavedExercise[], exerciseId: string): SavedExercise {
    for (let index = 0; index < exercises.length; index++) {
      const exercise: SavedExercise = exercises[index]
      if (exercise.name === exerciseId || this.matchesExerciseName(exercise, exerciseId)) {
        return exercise
      }
    }

    const created: SavedExercise = this.createLegacyExercise(exerciseId)
    exercises.push(created)
    return created
  }

  private matchesExerciseName(exercise: SavedExercise, exerciseId: string): boolean {
    const content: ExerciseContent | undefined = ContentRepository.getExerciseById(exerciseId)
    if (content === undefined) {
      return exercise.name === exerciseId
    }
    return exercise.name === content.nameZh
  }

  private createLegacyExercise(exerciseId: string): SavedExercise {
    const content: ExerciseContent | undefined = ContentRepository.getExerciseById(exerciseId)
    let exerciseName: string = exerciseId
    let targetMuscle: string = ''

    if (content !== undefined) {
      exerciseName = content.nameZh
      if (content.primaryMuscleIds.length > 0) {
        targetMuscle = ContentRepository.getMuscleName(content.primaryMuscleIds[0])
      }
    }

    const exercise: SavedExercise = {
      name: exerciseName,
      targetMuscle: targetMuscle,
      sets: []
    }
    return exercise
  }

  private createLegacySet(set: WorkoutSet): SavedSet {
    const legacySet: SavedSet = {
      weight: set.weight,
      reps: set.reps
    }
    return legacySet
  }

  private formatDate(timestamp: number): string {
    const date: Date = new Date(timestamp)
    return date.getFullYear().toString() + '-' + this.padTwoDigits(date.getMonth() + 1) + '-' +
      this.padTwoDigits(date.getDate())
  }

  private padTwoDigits(value: number): string {
    if (value < 10) {
      return '0' + value.toString()
    }
    return value.toString()
  }
}

export default new WorkoutSessionPersistenceBridgeService()

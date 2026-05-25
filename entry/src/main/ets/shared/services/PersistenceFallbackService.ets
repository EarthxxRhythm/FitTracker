/**
 * PersistenceFallbackService -- storage failure fallback state and defaults.
 *
 * Feature #26: keep usable default data and record degradation state when local preferences fail.
 */
import { UserGoal, WorkoutSession, createUserGoal, createWorkoutSession } from '../models/TrainingModels'

export interface PersistenceFallbackStatus {
  degraded: boolean
  scope: string
  errorCode: string
  fallbackDataName: string
  updatedAt: number
}

class PersistenceFallbackService {
  private status: PersistenceFallbackStatus = this.createEmptyStatus()

  recordFallback(scope: string, errorCode: string, fallbackDataName: string, updatedAt: number): void {
    const status: PersistenceFallbackStatus = {
      degraded: true,
      scope: scope,
      errorCode: errorCode,
      fallbackDataName: fallbackDataName,
      updatedAt: updatedAt
    }
    this.status = status
  }

  clearStatus(): void {
    this.status = this.createEmptyStatus()
  }

  hasFallback(): boolean {
    return this.status.degraded
  }

  getStatus(): PersistenceFallbackStatus {
    return this.copyStatus(this.status)
  }

  createDefaultGoal(now: number): UserGoal {
    const equipmentIds: string[] = ['eq_bodyweight']
    const restrictedMuscleIds: string[] = []
    return createUserGoal(
      'goal_default_fallback',
      'hypertrophy',
      'beginner',
      3,
      45,
      equipmentIds,
      restrictedMuscleIds,
      now,
      now
    )
  }

  createDefaultWorkoutSessions(): WorkoutSession[] {
    const sessions: WorkoutSession[] = []
    return sessions
  }

  createDefaultWorkoutSession(now: number): WorkoutSession {
    return createWorkoutSession(
      'session_default_fallback',
      'plan_default_fallback',
      'fallback_day',
      now,
      now,
      0,
      0,
      0,
      0,
      'storage_fallback',
      []
    )
  }

  private createEmptyStatus(): PersistenceFallbackStatus {
    const status: PersistenceFallbackStatus = {
      degraded: false,
      scope: '',
      errorCode: '',
      fallbackDataName: '',
      updatedAt: 0
    }
    return status
  }

  private copyStatus(source: PersistenceFallbackStatus): PersistenceFallbackStatus {
    const status: PersistenceFallbackStatus = {
      degraded: source.degraded,
      scope: source.scope,
      errorCode: source.errorCode,
      fallbackDataName: source.fallbackDataName,
      updatedAt: source.updatedAt
    }
    return status
  }
}

export default new PersistenceFallbackService()

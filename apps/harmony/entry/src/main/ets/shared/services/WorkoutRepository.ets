/**
 * WorkoutRepository - skeleton local workout repository.
 *
 * Feature #4: local repositories and app state.
 */
import { WorkoutSession, WorkoutSet, createWorkoutSession } from '../models/TrainingModels'

class WorkoutRepository {
  private sessions: WorkoutSession[] = []

  createSession(
    sessionId: string,
    planId: string,
    dayId: string,
    startedAt: number,
    endedAt: number,
    durationSeconds: number,
    totalSets: number,
    totalVolume: number,
    fatigueScore: number,
    notes: string,
    sets: WorkoutSet[]
  ): WorkoutSession {
    return createWorkoutSession(
      sessionId,
      planId,
      dayId,
      startedAt,
      endedAt,
      durationSeconds,
      totalSets,
      totalVolume,
      fatigueScore,
      notes,
      this.copyWorkoutSets(sets)
    )
  }

  saveSession(session: WorkoutSession): void {
    this.sessions.push(this.copyWorkoutSession(session))
  }

  updateSession(session: WorkoutSession): boolean {
    for (let index = 0; index < this.sessions.length; index++) {
      if (this.sessions[index].sessionId === session.sessionId) {
        this.sessions[index] = this.copyWorkoutSession(session)
        return true
      }
    }
    return false
  }

  removeSession(sessionId: string): WorkoutSession | undefined {
    for (let index = this.sessions.length - 1; index >= 0; index--) {
      const session: WorkoutSession = this.sessions[index]
      if (session.sessionId === sessionId) {
        this.sessions.splice(index, 1)
        return this.copyWorkoutSession(session)
      }
    }
    return undefined
  }

  restoreSession(session: WorkoutSession): boolean {
    for (let index = 0; index < this.sessions.length; index++) {
      if (this.sessions[index].sessionId === session.sessionId) {
        return false
      }
    }
    this.sessions.push(this.copyWorkoutSession(session))
    return true
  }

  getSessions(): WorkoutSession[] {
    const sessions: WorkoutSession[] = []
    for (let index = 0; index < this.sessions.length; index++) {
      sessions.push(this.copyWorkoutSession(this.sessions[index]))
    }
    return sessions
  }

  getSessionById(sessionId: string): WorkoutSession | undefined {
    for (let index = this.sessions.length - 1; index >= 0; index--) {
      const session: WorkoutSession = this.sessions[index]
      if (session.sessionId === sessionId) {
        return this.copyWorkoutSession(session)
      }
    }
    return undefined
  }

  getLatestSession(): WorkoutSession | undefined {
    if (this.sessions.length === 0) {
      return undefined
    }
    return this.copyWorkoutSession(this.sessions[this.sessions.length - 1])
  }

  clear(): void {
    this.sessions = []
  }

  private copyWorkoutSession(source: WorkoutSession): WorkoutSession {
    return createWorkoutSession(
      source.sessionId,
      source.planId,
      source.dayId,
      source.startedAt,
      source.endedAt,
      source.durationSeconds,
      source.totalSets,
      source.totalVolume,
      source.fatigueScore,
      source.notes,
      this.copyWorkoutSets(source.sets)
    )
  }

  private copyWorkoutSets(source: WorkoutSet[]): WorkoutSet[] {
    const sets: WorkoutSet[] = []
    for (let index = 0; index < source.length; index++) {
      const set: WorkoutSet = source[index]
      const item: WorkoutSet = {
        setId: set.setId,
        exerciseId: set.exerciseId,
        weight: set.weight,
        reps: set.reps,
        rpe: set.rpe,
        isWarmup: set.isWarmup
      }
      sets.push(item)
    }
    return sets
  }
}

export default new WorkoutRepository()

/**
 * WorkoutSummaryService - creates post-workout review summaries.
 *
 * Feature #11: workout summary review.
 */
import { ExerciseContent, WorkoutSession, WorkoutSet, estimateOneRepMax } from '../models/TrainingModels'
import ContentRepository from './ContentRepository'
import ReviewService from './ReviewService'

const COMPLETED_SETS_PREFIX: string = 'completed_sets='
const TARGET_SETS_PREFIX: string = 'target_sets='

export interface WorkoutSummary {
  hasSession: boolean
  sessionId: string
  planId: string
  dayId: string
  durationSeconds: number
  durationText: string
  completedSets: number
  targetSets: number
  completionRate: number
  totalVolume: number
  fatigueScore: number
  exerciseRecords: WorkoutSummaryExerciseRecord[]
}

export class WorkoutSummaryExerciseRecord {
  exerciseId: string = ''
  exerciseName: string = ''
  bestOneRepMax: number = 0
  bestWeight: number = 0
  bestReps: number = 0
  dateText: string = ''
}

class WorkoutSummaryService {
  createSummary(session: WorkoutSession): WorkoutSummary {
    const sessions: WorkoutSession[] = [session]
    return this.createSummaryWithHistory(session, sessions)
  }

  createSummaryWithHistory(session: WorkoutSession, sessions: WorkoutSession[]): WorkoutSummary {
    const completedSets: number = this.getCompletedSets(session)
    const targetSets: number = this.getTargetSets(session.notes, completedSets)
    const summary: WorkoutSummary = {
      hasSession: true,
      sessionId: session.sessionId,
      planId: session.planId,
      dayId: session.dayId,
      durationSeconds: session.durationSeconds,
      durationText: this.formatDuration(session.durationSeconds),
      completedSets: completedSets,
      targetSets: targetSets,
      completionRate: ReviewService.calculateCompletionRate(completedSets, targetSets),
      totalVolume: this.getTotalVolume(session),
      fatigueScore: session.fatigueScore,
      exerciseRecords: this.createExerciseRecords(session, sessions)
    }
    return summary
  }

  createEmptySummary(): WorkoutSummary {
    const summary: WorkoutSummary = {
      hasSession: false,
      sessionId: '',
      planId: '',
      dayId: '',
      durationSeconds: 0,
      durationText: '0 分钟',
      completedSets: 0,
      targetSets: 0,
      completionRate: 0,
      totalVolume: 0,
      fatigueScore: 0,
      exerciseRecords: []
    }
    return summary
  }

  formatDuration(durationSeconds: number): string {
    if (durationSeconds <= 0) {
      return '0 分钟'
    }

    const minutes: number = Math.floor(durationSeconds / 60)
    if (minutes <= 0) {
      return '1 分钟内'
    }

    const hours: number = Math.floor(minutes / 60)
    const restMinutes: number = minutes % 60
    if (hours > 0 && restMinutes > 0) {
      return hours.toString() + ' 小时 ' + restMinutes.toString() + ' 分钟'
    }
    if (hours > 0) {
      return hours.toString() + ' 小时'
    }
    return minutes.toString() + ' 分钟'
  }

  private getCompletedSets(session: WorkoutSession): number {
    const parsed: number = this.getNumberAfterPrefix(session.notes, COMPLETED_SETS_PREFIX)
    if (parsed > 0) {
      return parsed
    }
    return session.totalSets
  }

  private getTargetSets(notes: string, fallbackTargetSets: number): number {
    const parsed: number = this.getNumberAfterPrefix(notes, TARGET_SETS_PREFIX)
    if (parsed > 0) {
      return parsed
    }
    return fallbackTargetSets
  }

  private getTotalVolume(session: WorkoutSession): number {
    if (session.totalVolume > 0) {
      return session.totalVolume
    }
    return ReviewService.calculateVolume(session.sets)
  }

  private createExerciseRecords(currentSession: WorkoutSession, sessions: WorkoutSession[]): WorkoutSummaryExerciseRecord[] {
    const currentExerciseIds: string[] = this.getUniqueExerciseIds(currentSession.sets)
    const records: WorkoutSummaryExerciseRecord[] = []
    for (let index = 0; index < currentExerciseIds.length; index++) {
      const exerciseId: string = currentExerciseIds[index]
      const record: WorkoutSummaryExerciseRecord = this.createEmptyExerciseRecord(exerciseId)
      for (let sessionIndex = 0; sessionIndex < sessions.length; sessionIndex++) {
        this.updateExerciseRecord(record, sessions[sessionIndex])
      }
      records.push(record)
    }
    return records
  }

  private updateExerciseRecord(record: WorkoutSummaryExerciseRecord, session: WorkoutSession): void {
    for (let setIndex = 0; setIndex < session.sets.length; setIndex++) {
      const set: WorkoutSet = session.sets[setIndex]
      if (set.exerciseId !== record.exerciseId || set.isWarmup || set.weight <= 0 || set.reps <= 0) {
        continue
      }
      const oneRepMax: number = Math.round(estimateOneRepMax(set.weight, set.reps))
      if (this.isBetterExerciseRecord(record, oneRepMax, session.startedAt)) {
        record.bestOneRepMax = oneRepMax
        record.bestWeight = set.weight
        record.bestReps = set.reps
        record.dateText = this.formatDate(session.startedAt)
      }
    }
  }

  private isBetterExerciseRecord(record: WorkoutSummaryExerciseRecord, oneRepMax: number, startedAt: number): boolean {
    if (oneRepMax > record.bestOneRepMax) {
      return true
    }
    if (oneRepMax < record.bestOneRepMax) {
      return false
    }
    if (record.dateText.length === 0) {
      return true
    }
    const dateText: string = this.formatDate(startedAt)
    return dateText >= record.dateText
  }

  private createEmptyExerciseRecord(exerciseId: string): WorkoutSummaryExerciseRecord {
    const record: WorkoutSummaryExerciseRecord = {
      exerciseId: exerciseId,
      exerciseName: this.getExerciseName(exerciseId),
      bestOneRepMax: 0,
      bestWeight: 0,
      bestReps: 0,
      dateText: ''
    }
    return record
  }

  private getUniqueExerciseIds(sets: WorkoutSet[]): string[] {
    const exerciseIds: string[] = []
    for (let index = 0; index < sets.length; index++) {
      const exerciseId: string = sets[index].exerciseId
      if (!this.containsString(exerciseIds, exerciseId)) {
        exerciseIds.push(exerciseId)
      }
    }
    return exerciseIds
  }

  private containsString(values: string[], targetValue: string): boolean {
    for (let index = 0; index < values.length; index++) {
      if (values[index] === targetValue) {
        return true
      }
    }
    return false
  }

  private getExerciseName(exerciseId: string): string {
    const exercise: ExerciseContent | undefined = ContentRepository.getExerciseById(exerciseId)
    if (exercise !== undefined) {
      return exercise.nameZh
    }
    return exerciseId
  }

  private formatDate(timestamp: number): string {
    const date: Date = new Date(timestamp)
    const year: number = date.getFullYear()
    const month: number = date.getMonth() + 1
    const day: number = date.getDate()
    return year.toString() + '-' + this.padTwoDigits(month) + '-' + this.padTwoDigits(day)
  }

  private padTwoDigits(value: number): string {
    if (value < 10) {
      return '0' + value.toString()
    }
    return value.toString()
  }

  private getNumberAfterPrefix(source: string, prefix: string): number {
    const startIndex: number = source.indexOf(prefix)
    if (startIndex < 0) {
      return 0
    }

    const valueStartIndex: number = startIndex + prefix.length
    let valueEndIndex: number = source.indexOf(';', valueStartIndex)
    if (valueEndIndex < 0) {
      valueEndIndex = source.length
    }

    const rawValue: string = source.substring(valueStartIndex, valueEndIndex)
    const parsed: number = Number(rawValue)
    if (Number.isNaN(parsed)) {
      return 0
    }
    return Math.floor(parsed)
  }
}

export default new WorkoutSummaryService()

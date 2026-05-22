/**
 * WorkoutSummaryService - creates post-workout review summaries.
 *
 * Feature #11: workout summary review.
 */
import { WorkoutSession } from '../models/TrainingModels'
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
}

class WorkoutSummaryService {
  createSummary(session: WorkoutSession): WorkoutSummary {
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
      totalVolume: session.totalVolume,
      fatigueScore: session.fatigueScore
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
      fatigueScore: 0
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
